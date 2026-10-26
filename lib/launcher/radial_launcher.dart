import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'launcher_geometry.dart';

class LauncherNote {
  const LauncherNote({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.semanticsLabel,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  // e.g. "Grocery, 4 items".
  final String semanticsLabel;
}

// Radial launcher (plan section 5), with a plain look until the design pass
// (D-3). Fill the screen with it (it sits in a Stack). The hub sits near the
// bottom-right corner (bottom-left in left-hand mode), lists fan out from it
// as long tabs, and "+" sits next to the hub. Layout: LauncherGeometry.
//
// Hold mode: press the hub, drag onto a tab and release to open; rest on a
// tab until it fills, then release to edit; release on "+" for a new list;
// release on the hub or off the fan to cancel. Resting at either end of the
// fan scrolls it.
// Tap mode: a quick tap on the hub keeps the fan open with arrow buttons; tap
// a tab to open, long-press to edit; tap outside, the hub or Esc to close.
// Keys: left/right move focus, Enter opens, E edits, Esc closes.
class RadialLauncher extends StatefulWidget {
  const RadialLauncher({
    super.key,
    required this.notes,
    required this.onOpen,
    required this.onEdit,
    this.onNew,
    this.config = const LauncherConfig(),
    this.leftHanded = false,
    this.hubTooltip = 'Lists',
    this.addLabel = 'New list',
    this.editLabel = 'Edit',
  });

  final List<LauncherNote> notes;
  final ValueChanged<LauncherNote> onOpen;
  final ValueChanged<LauncherNote> onEdit;
  // Null shows the "+" dimmed and inactive.
  final VoidCallback? onNew;
  final LauncherConfig config;
  final bool leftHanded;
  final String hubTooltip;
  final String addLabel;
  final String editLabel;

  @override
  State<RadialLauncher> createState() => RadialLauncherState();
}

enum _Mode { closed, hold, tap }

class RadialLauncherState extends State<RadialLauncher>
    with SingleTickerProviderStateMixin {
  _Mode _mode = _Mode.closed;
  double _scrollOffset = 0;
  LauncherTarget _hover = LauncherTarget.none;
  int _focusIndex = 0;

  // Hold-mode pointer tracking.
  Offset? _pointer;
  Offset? _restAnchor;
  Duration _restStart = Duration.zero;
  Duration _pressStart = Duration.zero;
  bool _leftHub = false;
  double _dwellProgress = 0;
  bool _editArmed = false;

  late final Ticker _ticker;
  Duration _now = Duration.zero;
  Duration _lastTick = Duration.zero;
  final FocusNode _focusNode = FocusNode(debugLabel: 'RadialLauncher');

  LauncherGeometry? _geometry;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get isOpen => _mode != _Mode.closed;

  void _close() {
    _ticker.stop();
    setState(() {
      _mode = _Mode.closed;
      _hover = LauncherTarget.none;
      _pointer = null;
      _dwellProgress = 0;
      _editArmed = false;
    });
  }

  void _openTapMode() {
    setState(() {
      _mode = _Mode.tap;
      _focusIndex = _scrollOffset.round();
    });
    _focusNode.requestFocus();
  }

  void _onTick(Duration elapsed) {
    final double seconds = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _now = elapsed;
    final LauncherGeometry? geometry = _geometry;
    final Offset? pointer = _pointer;
    if (_mode != _Mode.hold || geometry == null || pointer == null) {
      return;
    }

    final double velocity = geometry.scrollVelocity(pointer);
    final bool scrolling = velocity != 0 &&
        geometry.clampOffset(_scrollOffset + velocity * seconds) != _scrollOffset;

    setState(() {
      if (scrolling) {
        _scrollOffset = geometry.clampOffset(_scrollOffset + velocity * seconds);
        _hover = geometry.hitTest(pointer, _scrollOffset);
        // Notes sliding under a resting finger never start Edit.
        _restartDwell(pointer);
        return;
      }

      if (_hover.kind == LauncherTargetKind.note && !_editArmed) {
        final Duration rested = _now - _restStart;
        _dwellProgress = (rested.inMicroseconds /
                widget.config.dwell.inMicroseconds)
            .clamp(0, 1)
            .toDouble();
        if (_dwellProgress >= 1) {
          _editArmed = true;
          HapticFeedback.heavyImpact();
        }
      }
    });
  }

  void _restartDwell(Offset pointer) {
    _restAnchor = pointer;
    _restStart = _now;
    _dwellProgress = 0;
    _editArmed = false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_mode == _Mode.tap) {
      _close();
      return;
    }

    _lastTick = Duration.zero;
    _now = Duration.zero;
    _ticker
      ..stop()
      ..start();
    setState(() {
      _mode = _Mode.hold;
      _pointer = event.position;
      _pressStart = _now;
      _leftHub = false;
      _hover = LauncherTarget.hub;
      _restartDwell(event.position);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final LauncherGeometry? geometry = _geometry;
    if (_mode != _Mode.hold || geometry == null) {
      return;
    }

    final LauncherTarget target = geometry.hitTest(event.position, _scrollOffset);
    setState(() {
      _pointer = event.position;
      if (target != LauncherTarget.hub) {
        _leftHub = true;
      }
      if (target != _hover) {
        _hover = target;
        _restartDwell(event.position);
        if (target.kind == LauncherTargetKind.note ||
            target.kind == LauncherTargetKind.add) {
          HapticFeedback.selectionClick();
        }
      } else if ((event.position - (_restAnchor ?? event.position)).distance >
              widget.config.moveTolerance &&
          !_editArmed) {
        // Moving within the same note restarts the dwell; an armed Edit
        // stays armed until the finger leaves the note.
        _restartDwell(event.position);
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_mode != _Mode.hold) {
      return;
    }

    final LauncherTarget target = _hover;
    final bool quickTap = !_leftHub &&
        target == LauncherTarget.hub &&
        _now - _pressStart <= widget.config.tapMaxDuration;
    final bool edit = _editArmed;
    _ticker.stop();

    if (quickTap) {
      _openTapMode();
      return;
    }

    _close();
    _activate(target, edit: edit);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_mode == _Mode.hold) {
      _close();
    }
  }

  void _activate(LauncherTarget target, {required bool edit}) {
    switch (target.kind) {
      case LauncherTargetKind.note:
        final LauncherNote note = widget.notes[target.noteIndex!];
        edit ? widget.onEdit(note) : widget.onOpen(note);
      case LauncherTargetKind.add:
        widget.onNew?.call();
      case LauncherTargetKind.hub:
      case LauncherTargetKind.none:
        break;
    }
  }

  void _page(int direction) {
    final LauncherGeometry? geometry = _geometry;
    if (geometry == null) {
      return;
    }
    setState(() {
      _scrollOffset = geometry.clampOffset(
        _scrollOffset + direction * geometry.slotCount,
      );
      _focusIndex = _focusIndex.clamp(
        _scrollOffset.round(),
        _scrollOffset.round() + geometry.slotCount - 1,
      );
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_mode != _Mode.tap || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final LauncherGeometry? geometry = _geometry;
    final LogicalKeyboardKey key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (widget.notes.isEmpty || geometry == null) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final int next = (_focusIndex + (key == LogicalKeyboardKey.arrowLeft ? -1 : 1))
          .clamp(0, widget.notes.length - 1);
      setState(() {
        _focusIndex = next;
        if (next < _scrollOffset) {
          _scrollOffset = geometry.clampOffset(next.toDouble());
        } else if (next >= _scrollOffset + geometry.slotCount) {
          _scrollOffset = geometry.clampOffset(
            (next - geometry.slotCount + 1).toDouble(),
          );
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.keyE) {
      final LauncherNote note = widget.notes[_focusIndex];
      _close();
      key == LogicalKeyboardKey.enter ? widget.onOpen(note) : widget.onEdit(note);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _noteWidget(
    LauncherGeometry geometry,
    LauncherNote note,
    int index,
    double angle,
  ) {
    final LauncherConfig config = widget.config;
    final bool hovered = _hover.kind == LauncherTargetKind.note &&
        _hover.noteIndex == index;
    final bool focused = _mode == _Mode.tap && _focusIndex == index;
    final bool lifted = hovered || focused;
    final Offset center =
        geometry.pointAt(angle, config.innerRadius + config.tabLength / 2);

    Widget body = AnimatedScale(
      scale: lifted ? 1.08 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: config.tabLength,
        height: config.tabThickness,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: note.color,
          borderRadius: BorderRadius.circular(6),
          border: focused ? Border.all(color: Colors.black, width: 2) : null,
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
        child: Stack(
          children: [
            // Dwell progress fills the tab from the hub end.
            if (hovered && _dwellProgress > 0)
              Align(
                alignment: widget.leftHanded
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: _dwellProgress,
                  heightFactor: 1,
                  child: const ColoredBox(color: Color(0x55FFFFFF)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(note.icon, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hovered && _editArmed ? widget.editLabel : note.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (_mode == _Mode.tap) {
      body = Semantics(
        button: true,
        label: note.semanticsLabel,
        hint: 'Double-tap to open, long-press to ${widget.editLabel.toLowerCase()}',
        excludeSemantics: true,
        child: GestureDetector(
          key: ValueKey('launcher-note-${note.id}'),
          onTap: () {
            _close();
            widget.onOpen(note);
          },
          onLongPress: () {
            _close();
            widget.onEdit(note);
          },
          onSecondaryTap: () {
            _close();
            widget.onEdit(note);
          },
          child: body,
        ),
      );
    }

    return Positioned(
      left: center.dx - config.tabLength / 2,
      top: center.dy - config.tabThickness / 2,
      child: Transform.rotate(
        angle: geometry.tabRotation(angle),
        child: body,
      ),
    );
  }

  Widget _addWidget(Offset center) {
    final double size = widget.config.addRadius * 2;
    final bool hovered = _hover == LauncherTarget.add;
    final bool enabled = widget.onNew != null;

    Widget body = AnimatedScale(
      scale: hovered ? 1.15 : 1,
      duration: const Duration(milliseconds: 120),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey.shade700,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );

    if (_mode == _Mode.tap) {
      body = Semantics(
        button: true,
        enabled: enabled,
        label: widget.addLabel,
        excludeSemantics: true,
        child: GestureDetector(
          key: const ValueKey('launcher-add'),
          onTap: enabled
              ? () {
                  _close();
                  widget.onNew!();
                }
              : null,
          child: body,
        ),
      );
    }

    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: body,
    );
  }

  Widget _arrow(LauncherGeometry geometry, int direction) {
    final bool enabled = direction < 0
        ? _scrollOffset > 0
        : _scrollOffset < geometry.maxScrollOffset;
    // In the margins just past each end of the fan.
    final Offset spot = geometry.pointAt(
      direction < 0 ? geometry.slotAngle(-0.9) : geometry.slotAngle(geometry.slotCount - 0.1),
      widget.config.innerRadius + widget.config.tabLength / 2,
    );
    return Positioned(
      left: spot.dx - 24,
      top: spot.dy - 24,
      child: IconButton(
        key: ValueKey(direction < 0 ? 'launcher-prev' : 'launcher-next'),
        tooltip: direction < 0 ? 'Previous' : 'Next',
        icon: Icon(direction < 0 ? Icons.chevron_left : Icons.chevron_right),
        onPressed: enabled ? () => _page(direction) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final LauncherGeometry geometry = LauncherGeometry(
          config: widget.config,
          size: constraints.biggest,
          noteCount: widget.notes.length,
          leftHanded: widget.leftHanded,
        );
        final Offset hubCenter = geometry.hubCenter;
        _geometry = geometry;
        _scrollOffset = geometry.clampOffset(_scrollOffset);
        final double hub = widget.config.hubRadius;

        return Focus(
          focusNode: _focusNode,
          onKeyEvent: _onKey,
          child: Stack(
            children: [
              if (_mode == _Mode.tap)
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey('launcher-barrier'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: const ColoredBox(color: Color(0x33000000)),
                  ),
                ),
              if (_mode == _Mode.hold)
                const Positioned.fill(
                  child: IgnorePointer(child: ColoredBox(color: Color(0x33000000))),
                ),
              if (isOpen) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _RingPainter(geometry)),
                  ),
                ),
                for (int index = 0; index < widget.notes.length; index++)
                  if (geometry.tabAngle(index, _scrollOffset) case final double angle)
                    _noteWidget(geometry, widget.notes[index], index, angle),
                _addWidget(geometry.addCenter),
                if (_mode == _Mode.tap && geometry.maxScrollOffset > 0) ...[
                  _arrow(geometry, -1),
                  _arrow(geometry, 1),
                ],
              ],
              Positioned(
                left: hubCenter.dx - hub,
                top: hubCenter.dy - hub,
                child: Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: Semantics(
                    button: true,
                    label: widget.hubTooltip,
                    onTap: () => isOpen ? _close() : _openTapMode(),
                    child: Tooltip(
                      message: widget.hubTooltip,
                      child: Container(
                        key: const ValueKey('launcher-hub'),
                        width: hub * 2,
                        height: hub * 2,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                        ),
                        child: Icon(
                          isOpen ? Icons.close : Icons.apps,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// The circle the tabs start from, drawn across the quarter the fan sits in.
class _RingPainter extends CustomPainter {
  _RingPainter(this.geometry);

  final LauncherGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = geometry.config.innerRadius - 6;
    final Path path = Path();
    const int steps = 48;
    for (int i = 0; i <= steps; i++) {
      // From pointing left (bottom edge) to pointing up (side edge).
      final double angle = 3.141592653589793 * (1 - 0.5 * i / steps);
      final Offset point = geometry.pointAt(angle, radius);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xB3FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.geometry.size != geometry.size ||
        oldDelegate.geometry.leftHanded != geometry.leftHanded;
  }
}
