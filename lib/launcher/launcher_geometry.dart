import 'dart:math' as math;
import 'dart:ui';

// Tunable numbers for the radial launcher (plan section 5). They need tuning
// on a real phone (Q-3), so they all live here.
//
// Layout, right-hand mode: the hub sits near the bottom-right corner and the
// list tabs fan out to its upper left as long rectangles, like spokes. The fan
// starts `edgeMarginDegrees` above the bottom edge and turns clockwise until
// the same margin before the right edge. "+" sits right next to the hub, on
// the corner side. Left-hand mode mirrors all of it.
class LauncherConfig {
  const LauncherConfig({
    this.hubRadius = 32,
    this.hubInsetX = 88,
    this.hubInsetY = 64,
    this.addRadius = 20,
    this.addGap = 6,
    this.edgeMarginDegrees = 20,
    this.innerRadius = 180,
    this.tabLength = 150,
    this.tabThickness = 34,
    this.dwell = const Duration(milliseconds: 1000),
    this.moveTolerance = 8,
    this.endZoneFraction = 0.15,
    this.maxScrollSpeed = 4,
    this.tapMaxDuration = const Duration(milliseconds: 250),
  });

  final double hubRadius;
  // Hub centre distance from the side edge and from the bottom edge.
  final double hubInsetX;
  final double hubInsetY;
  final double addRadius;
  final double addGap;
  final double edgeMarginDegrees;
  // Tabs start at this distance from the hub centre and run outward.
  final double innerRadius;
  final double tabLength;
  final double tabThickness;
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

// Works in a right-hand frame and mirrors points for left-hand mode. Angles
// are radians, 0 = pointing right, positive = up (screen y grows down).
class LauncherGeometry {
  LauncherGeometry({
    required this.config,
    required this.size,
    required this.noteCount,
    this.leftHanded = false,
  });

  final LauncherConfig config;
  final Size size;
  final int noteCount;
  final bool leftHanded;

  static const double _degree = math.pi / 180;

  // Right-hand frame: first tab near the bottom edge (pointing left), last
  // near the right edge (pointing up).
  double get startAngle => math.pi - config.edgeMarginDegrees * _degree;
  double get endAngle => math.pi / 2 + config.edgeMarginDegrees * _degree;
  double get _span => startAngle - endAngle;

  Offset get _hubRight =>
      Offset(size.width - config.hubInsetX, size.height - config.hubInsetY);

  Offset _mirror(Offset point) {
    return leftHanded ? Offset(size.width - point.dx, point.dy) : point;
  }

  Offset get hubCenter => _mirror(_hubRight);

  Offset get addCenter => _mirror(
        _hubRight +
            Offset(config.hubRadius + config.addGap + config.addRadius, 0),
      );

  // How many tabs fit side by side at the inner radius.
  int get slotCount {
    final double room = _span * config.innerRadius;
    return math.max(1, (room / (config.tabThickness * 1.15)).floor());
  }

  double get maxScrollOffset => math.max(0, noteCount - slotCount).toDouble();

  double get _step => _span / slotCount;

  // Right-hand-frame angle of a (possibly fractional) slot.
  double slotAngle(double slot) => startAngle - (slot + 0.5) * _step;

  Offset pointAt(double angle, double radius) {
    return _mirror(
      _hubRight + Offset(math.cos(angle), -math.sin(angle)) * radius,
    );
  }

  // Screen rotation (clockwise radians) that lays a tab's text along its
  // spoke, reading towards the hub in right-hand mode and away from it in
  // left-hand mode, so it is never upside down.
  double tabRotation(double angle) {
    return leftHanded
        ? -math.atan2(math.sin(angle), -math.cos(angle))
        : math.atan2(math.sin(angle), -math.cos(angle));
  }

  // Centre of a tab in the strip, or null when scrolled out of view.
  Offset? tabCenter(int noteIndex, double scrollOffset) {
    final double? angle = tabAngle(noteIndex, scrollOffset);
    return angle == null
        ? null
        : pointAt(angle, config.innerRadius + config.tabLength / 2);
  }

  double? tabAngle(int noteIndex, double scrollOffset) {
    final double slot = noteIndex - scrollOffset;
    if (slot < -0.5 || slot > slotCount - 0.5) {
      return null;
    }
    return slotAngle(slot);
  }

  // Position along the fan: 0 at the start, 1 at the end; may run past both
  // ends into the margins. Null outside the band the tabs occupy.
  double? _fanPosition(Offset point) {
    final Offset local = _mirror(point) - _hubRight;
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

    final double? position = _fanPosition(point);
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
    final double? position = _fanPosition(point);
    if (position == null || maxScrollOffset == 0) {
      return 0;
    }

    final double zone = config.endZoneFraction;
    final double margin =
        config.edgeMarginDegrees * _degree / _span;
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
