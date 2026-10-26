import 'dart:math' as math;
import 'dart:ui';

// Tunable numbers for the radial launcher (plan section 5). They need tuning
// on a real phone (Q-3), so they all live here.
//
// Layout, described for a hub nearest the bottom-right corner: list tabs fan
// out to the hub's upper left as long, overlapping rectangles along spokes.
// The fan starts `edgeMarginDegrees` above the bottom edge and turns
// clockwise until the same margin before the right edge. "+" sits right next
// to the hub on the corner side. For a hub nearer another corner the whole
// layout is mirrored so the fan always opens away from that corner.
class LauncherConfig {
  const LauncherConfig({
    this.hubRadius = 32,
    this.defaultHubInsetX = 88,
    this.defaultHubInsetY = 64,
    this.screenMargin = 40,
    this.addRadius = 20,
    this.addGap = 6,
    this.edgeMarginDegrees = 20,
    this.innerRadius = 100,
    this.tabLength = 170,
    this.tabThickness = 40,
    this.visibleTabs = 5,
    this.dwell = const Duration(milliseconds: 1000),
    this.moveTolerance = 8,
    this.endZoneFraction = 0.15,
    this.maxScrollSpeed = 4,
    this.tapMaxDuration = const Duration(milliseconds: 250),
    this.hubMoveDelay = const Duration(milliseconds: 600),
  });

  final double hubRadius;
  // Where the hub starts before the user moves it, measured from the
  // bottom-right corner.
  final double defaultHubInsetX;
  final double defaultHubInsetY;
  // A moved hub stays at least this far from every screen edge.
  final double screenMargin;
  final double addRadius;
  final double addGap;
  final double edgeMarginDegrees;
  // Tabs start at this distance from the hub centre and run outward.
  final double innerRadius;
  final double tabLength;
  final double tabThickness;
  // Tabs shown across the fan at once; they overlap near the hub.
  final int visibleTabs;
  // How long a finger must rest on a tab to arm Edit.
  final Duration dwell;
  // Movement (logical pixels) that still counts as resting.
  final double moveTolerance;
  // Share of the fan at each end that auto-scrolls.
  final double endZoneFraction;
  // Auto-scroll speed at the very end of a zone, in tabs per second.
  final double maxScrollSpeed;
  // A press released on the hub faster than this opens tap mode.
  final Duration tapMaxDuration;
  // Resting on the hub this long picks it up to move it.
  final Duration hubMoveDelay;

  double get outerRadius => innerRadius + tabLength;
}

enum LauncherTargetKind { none, hub, note, add }

class LauncherTarget {
  const LauncherTarget(this.kind, [this.noteIndex]);

  static const LauncherTarget none = LauncherTarget(LauncherTargetKind.none);
  static const LauncherTarget hub = LauncherTarget(LauncherTargetKind.hub);
  static const LauncherTarget add = LauncherTarget(LauncherTargetKind.add);

  final LauncherTargetKind kind;
  // Index into the full tab strip (not the visible slot).
  final int? noteIndex;

  @override
  bool operator ==(Object other) {
    return other is LauncherTarget &&
        other.kind == kind &&
        other.noteIndex == noteIndex;
  }

  @override
  int get hashCode => Object.hash(kind, noteIndex);
}

// Computes everything in a frame where the nearest corner is bottom-right,
// then flips points back to the screen. Angles are radians in that frame,
// 0 = pointing right, positive = up (screen y grows down).
class LauncherGeometry {
  LauncherGeometry({
    required this.config,
    required this.size,
    required this.noteCount,
    Offset? hubPosition,
  }) : hubCenter = clampHub(config, size, hubPosition ?? defaultHub(config, size));

  final LauncherConfig config;
  final Size size;
  final int noteCount;
  final Offset hubCenter;

  static const double _degree = math.pi / 180;

  static Offset defaultHub(LauncherConfig config, Size size) {
    return Offset(
      size.width - config.defaultHubInsetX,
      size.height - config.defaultHubInsetY,
    );
  }

  static Offset clampHub(LauncherConfig config, Size size, Offset hub) {
    final double margin = config.screenMargin;
    return Offset(
      hub.dx.clamp(margin, math.max(margin, size.width - margin)).toDouble(),
      hub.dy.clamp(margin, math.max(margin, size.height - margin)).toDouble(),
    );
  }

  // Which corner the hub is nearest decides the mirroring.
  bool get flipX => hubCenter.dx < size.width / 2;
  bool get flipY => hubCenter.dy < size.height / 2;

  Offset _flip(Offset point) {
    return Offset(
      flipX ? size.width - point.dx : point.dx,
      flipY ? size.height - point.dy : point.dy,
    );
  }

  Offset get _hubFrame => _flip(hubCenter);

  double get startAngle => math.pi - config.edgeMarginDegrees * _degree;
  double get endAngle => math.pi / 2 + config.edgeMarginDegrees * _degree;
  double get _span => startAngle - endAngle;

  Offset get addCenter => _flip(
        _hubFrame +
            Offset(config.hubRadius + config.addGap + config.addRadius, 0),
      );

  int get slotCount => math.max(1, config.visibleTabs);

  double get maxScrollOffset => math.max(0, noteCount - slotCount).toDouble();

  double get _step => _span / slotCount;

  // Frame angle of a (possibly fractional) slot.
  double slotAngle(double slot) => startAngle - (slot + 0.5) * _step;

  Offset pointAt(double angle, double radius) {
    return _flip(
      _hubFrame + Offset(math.cos(angle), -math.sin(angle)) * radius,
    );
  }

  // Unit vector on screen pointing from the hub outward along a spoke.
  Offset _outward(double angle) {
    return Offset(
      (flipX ? -1 : 1) * math.cos(angle),
      (flipY ? 1 : -1) * math.sin(angle),
    );
  }

  // True when a tab's text reads from the hub outward, false when it reads
  // towards the hub; whichever keeps the text left-to-right.
  bool readsOutward(double angle) => _outward(angle).dx >= 0;

  // Screen rotation (clockwise radians) laying a tab along its spoke with
  // its text upright.
  double tabRotation(double angle) {
    final Offset out = _outward(angle);
    final Offset reading = readsOutward(angle) ? out : -out;
    return math.atan2(reading.dy, reading.dx);
  }

  double? tabAngle(int noteIndex, double scrollOffset) {
    final double slot = noteIndex - scrollOffset;
    if (slot < -0.5 || slot > slotCount - 0.5) {
      return null;
    }
    return slotAngle(slot);
  }

  // Centre of a tab in the strip, or null when scrolled out of view.
  Offset? tabCenter(int noteIndex, double scrollOffset) {
    final double? angle = tabAngle(noteIndex, scrollOffset);
    return angle == null
        ? null
        : pointAt(angle, config.innerRadius + config.tabLength / 2);
  }

  // Position along the fan: 0 at the start, 1 at the end; may run past both
  // ends into the margins. Null outside the band the tabs occupy.
  double? fanPosition(Offset point) {
    final Offset local = _flip(point) - _hubFrame;
    final double distance = local.distance;
    if (distance < config.innerRadius - config.tabThickness ||
        distance > config.outerRadius + config.tabThickness) {
      return null;
    }

    double angle = math.atan2(-local.dy, local.dx);
    if (angle < -math.pi / 2) {
      angle += 2 * math.pi;
    }
    return (startAngle - angle) / _span;
  }

  LauncherTarget hitTest(Offset point, double scrollOffset) {
    if ((point - hubCenter).distance <= config.hubRadius) {
      return LauncherTarget.hub;
    }
    if ((point - addCenter).distance <= config.addRadius * 1.4) {
      return LauncherTarget.add;
    }

    final double? position = fanPosition(point);
    if (position == null || position < 0 || position > 1) {
      return LauncherTarget.none;
    }

    final int slot = (position * slotCount).floor().clamp(0, slotCount - 1);
    final int noteIndex = (slot + scrollOffset).round();
    if (noteIndex < 0 || noteIndex >= noteCount) {
      return LauncherTarget.none;
    }
    return LauncherTarget(LauncherTargetKind.note, noteIndex);
  }

  // Auto-scroll velocity (tabs per second): negative near the start of the
  // fan, positive near its end, strongest in the margins beyond either end.
  double scrollVelocity(Offset point) {
    final double? position = fanPosition(point);
    if (position == null || maxScrollOffset == 0) {
      return 0;
    }

    final double zone = config.endZoneFraction;
    final double margin = config.edgeMarginDegrees * _degree / _span;
    if (position < -margin || position > 1 + margin) {
      return 0;
    }
    if (position < zone) {
      return -config.maxScrollSpeed * math.min(1, 1 - position / zone);
    }
    if (position > 1 - zone) {
      return config.maxScrollSpeed * math.min(1, (position - (1 - zone)) / zone);
    }
    return 0;
  }

  double clampOffset(double offset) {
    return offset.clamp(0, maxScrollOffset).toDouble();
  }
}
