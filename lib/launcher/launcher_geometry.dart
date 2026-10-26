import 'dart:math' as math;
import 'dart:ui';

// Tunable numbers for the radial launcher (plan section 5). They need tuning
// on a real phone (Q-3), so they all live here.
class LauncherConfig {
  const LauncherConfig({
    this.arcDegrees = 200,
    this.radius = 150,
    this.noteSize = 64,
    this.hubRadius = 32,
    this.dwell = const Duration(milliseconds: 1000),
    this.moveTolerance = 8,
    this.endZoneFraction = 0.15,
    this.maxScrollSpeed = 4,
    this.tapMaxDuration = const Duration(milliseconds: 250),
  });

  final double arcDegrees;
  final double radius;
  final double noteSize;
  final double hubRadius;
  // How long a finger must rest on a note to arm Edit.
  final Duration dwell;
  // Movement (logical pixels) that still counts as resting.
  final double moveTolerance;
  // Share of the notes area at each end that auto-scrolls.
  final double endZoneFraction;
  // Auto-scroll speed at the very end of a zone, in notes per second.
  final double maxScrollSpeed;
  // A press released on the hub faster than this opens tap mode.
  final Duration tapMaxDuration;
}

enum LauncherTargetKind { none, hub, note, add }

class LauncherTarget {
  const LauncherTarget(this.kind, [this.noteIndex]);

  static const LauncherTarget none = LauncherTarget(LauncherTargetKind.none);
  static const LauncherTarget hub = LauncherTarget(LauncherTargetKind.hub);
  static const LauncherTarget add = LauncherTarget(LauncherTargetKind.add);

  final LauncherTargetKind kind;
  // Index into the full note strip (not the visible slot).
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

// Positions on the arc above the hub. Slots run left to right; the last slot
// is the pinned "+", the others show the note strip from `scrollOffset` on.
// Angles are in radians, 0 = right, positive = up (screen y grows down).
class LauncherGeometry {
  LauncherGeometry({
    required this.config,
    required this.hubCenter,
    required this.noteCount,
  });

  final LauncherConfig config;
  final Offset hubCenter;
  final int noteCount;

  double get _arc => config.arcDegrees * math.pi / 180;
  double get _startAngle => math.pi / 2 + _arc / 2;

  // How many slots fit on the arc, including the "+" slot.
  int get slotCount {
    final double arcLength = config.radius * _arc;
    return math.max(2, (arcLength / (config.noteSize * 1.15)).floor());
  }

  int get noteSlotCount => slotCount - 1;

  double get maxScrollOffset =>
      math.max(0, noteCount - noteSlotCount).toDouble();

  double get _step => _arc / slotCount;

  double slotAngle(double slot) => _startAngle - (slot + 0.5) * _step;

  Offset pointAt(double angle, [double? radius]) {
    return hubCenter +
        Offset(math.cos(angle), -math.sin(angle)) * (radius ?? config.radius);
  }

  // Centre of a note in the strip, or null when scrolled out of view.
  Offset? noteCenter(int noteIndex, double scrollOffset) {
    final double slot = noteIndex - scrollOffset;
    if (slot < -0.5 || slot > noteSlotCount - 0.5) {
      return null;
    }
    return pointAt(slotAngle(slot));
  }

  Offset get addCenter => pointAt(slotAngle(noteSlotCount.toDouble()));

  // Position along the arc: 0 at the left end, 1 at the right end.
  double? _arcPosition(Offset point) {
    final Offset delta = point - hubCenter;
    final double distance = delta.distance;
    if ((distance - config.radius).abs() > config.noteSize * 0.9) {
      return null;
    }

    double angle = math.atan2(-delta.dy, delta.dx);
    // The arc dips below the horizontal on both sides; keep angles continuous.
    if (angle < _startAngle - _arc - math.pi / 2) {
      angle += 2 * math.pi;
    }
    final double position = (_startAngle - angle) / _arc;
    return position < 0 || position > 1 ? null : position;
  }

  LauncherTarget hitTest(Offset point, double scrollOffset) {
    if ((point - hubCenter).distance <= config.hubRadius) {
      return LauncherTarget.hub;
    }

    final double? position = _arcPosition(point);
    if (position == null) {
      return LauncherTarget.none;
    }

    final int slot = (position * slotCount).floor().clamp(0, slotCount - 1);
    if (slot == noteSlotCount) {
      return LauncherTarget.add;
    }

    final int noteIndex = (slot + scrollOffset).round();
    if (noteIndex < 0 || noteIndex >= noteCount) {
      return LauncherTarget.none;
    }
    return LauncherTarget(LauncherTargetKind.note, noteIndex);
  }

  // Auto-scroll velocity (notes per second) for a finger at `point`:
  // negative in the left end zone, positive in the right one, growing with
  // depth into the zone. The "+" slot is not part of a zone.
  double scrollVelocity(Offset point) {
    final double? position = _arcPosition(point);
    if (position == null || maxScrollOffset == 0) {
      return 0;
    }

    final double notesEnd = noteSlotCount / slotCount;
    final double zone = notesEnd * config.endZoneFraction;
    if (position < zone) {
      return -config.maxScrollSpeed * (1 - position / zone);
    }
    if (position > notesEnd - zone && position <= notesEnd) {
      return config.maxScrollSpeed * (position - (notesEnd - zone)) / zone;
    }
    return 0;
  }

  double clampOffset(double offset) {
    return offset.clamp(0, maxScrollOffset).toDouble();
  }
}
