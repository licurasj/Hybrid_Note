import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/launcher/launcher_geometry.dart';
import 'package:hybrid_note/launcher/radial_launcher.dart';

const LauncherConfig _config = LauncherConfig();

List<LauncherNote> _notes(int count) {
  return [
    for (int i = 0; i < count; i++)
      LauncherNote(
        id: 'n$i',
        label: 'Note $i',
        icon: Icons.list,
        color: Colors.blue,
        semanticsLabel: 'Note $i, $i',
      ),
  ];
}

class _Log {
  final List<String> events = [];
}

Future<_Log> _pump(
  WidgetTester tester, {
  int count = 4,
  bool withNew = true,
  bool leftHanded = false,
}) async {
  final _Log log = _Log();
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RadialLauncher(
          notes: _notes(count),
          onOpen: (note) => log.events.add('open ${note.id}'),
          onEdit: (note) => log.events.add('edit ${note.id}'),
          onNew: withNew ? () => log.events.add('new') : null,
          leftHanded: leftHanded,
        ),
      ),
    ),
  );
  return log;
}

LauncherGeometry _geometry(int count, {bool leftHanded = false}) {
  return LauncherGeometry(
    config: _config,
    size: const Size(400, 800),
    noteCount: count,
    leftHanded: leftHanded,
  );
}

Offset _tab(LauncherGeometry geometry, int index, [double offset = 0]) {
  return geometry.tabCenter(index, offset)!;
}

void main() {
  group('geometry', () {
    final LauncherGeometry geometry = _geometry(12);

    test('hub near the bottom-right corner, "+" right next to it', () {
      expect(geometry.hubCenter, const Offset(400 - 88, 800 - 64));
      expect(geometry.addCenter.dy, geometry.hubCenter.dy);
      expect(geometry.addCenter.dx, greaterThan(geometry.hubCenter.dx));
      expect(geometry.addCenter.dx + _config.addRadius, lessThanOrEqualTo(400));
    });

    test('tabs fan from 20 degrees above the bottom to 20 before the right edge', () {
      expect(geometry.startAngle, closeTo(160 * 3.14159265 / 180, 1e-6));
      expect(geometry.endAngle, closeTo(110 * 3.14159265 / 180, 1e-6));

      final Offset first = _tab(geometry, 0);
      final Offset last = _tab(geometry, geometry.slotCount - 1);
      // First tab points mostly left, the last mostly up; all stay on screen.
      expect(first.dx < last.dx && first.dy > last.dy, isTrue);
      for (int i = 0; i < geometry.slotCount; i++) {
        final Offset outer = geometry.pointAt(geometry.slotAngle(i.toDouble()), _config.outerRadius);
        expect(outer.dx, inInclusiveRange(0, 400));
        expect(outer.dy, inInclusiveRange(0, 800));
      }
    });

    test('hit testing finds tabs, "+", the hub and nothing', () {
      expect(geometry.hitTest(_tab(geometry, 2), 0),
          const LauncherTarget(LauncherTargetKind.note, 2));
      // Anywhere along a tab counts, not only its centre.
      expect(
        geometry.hitTest(geometry.pointAt(geometry.slotAngle(1), _config.innerRadius + 10), 0),
        const LauncherTarget(LauncherTargetKind.note, 1),
      );
      expect(geometry.hitTest(geometry.addCenter, 0), LauncherTarget.add);
      expect(geometry.hitTest(geometry.hubCenter, 0), LauncherTarget.hub);
      expect(geometry.hitTest(const Offset(20, 20), 0), LauncherTarget.none);
    });

    test('scrolling shifts which tab is under a slot', () {
      final Offset slot0 = _tab(geometry, 0);
      expect(geometry.hitTest(slot0, 3), const LauncherTarget(LauncherTargetKind.note, 3));
      expect(geometry.tabCenter(0, 3), isNull);
    });

    test('ends of the fan scroll back and forward; the middle does not', () {
      final double mid = _config.innerRadius + _config.tabLength / 2;
      final Offset start = geometry.pointAt(geometry.slotAngle(-0.4), mid);
      final Offset end = geometry.pointAt(geometry.slotAngle(geometry.slotCount - 0.6), mid);
      final Offset middle = geometry.pointAt(geometry.slotAngle((geometry.slotCount - 1) / 2), mid);

      expect(geometry.scrollVelocity(start), lessThan(0));
      expect(geometry.scrollVelocity(end), greaterThan(0));
      expect(geometry.scrollVelocity(middle), 0);
    });

    test('left-hand mode mirrors everything', () {
      final LauncherGeometry left = _geometry(12, leftHanded: true);

      expect(left.hubCenter, const Offset(88, 800 - 64));
      expect(left.addCenter.dx, lessThan(left.hubCenter.dx));
      expect(_tab(left, 2).dx, closeTo(400 - _tab(geometry, 2).dx, 1e-9));
      expect(left.hitTest(_tab(left, 2), 0), const LauncherTarget(LauncherTargetKind.note, 2));
    });

    test('no scrolling when every tab fits', () {
      final LauncherGeometry few = _geometry(2);
      expect(few.maxScrollOffset, 0);
    });
  });

  group('hold mode', () {
    testWidgets('drag onto a note and release opens it', (tester) async {
      final _Log log = await _pump(tester);
      final LauncherGeometry geometry = _geometry(4);

      final TestGesture gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(_tab(geometry, 1));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();

      expect(log.events, ['open n1']);
      expect(find.text('Note 1'), findsNothing);
    });

    testWidgets('resting on a note arms edit', (tester) async {
      final _Log log = await _pump(tester);
      final LauncherGeometry geometry = _geometry(4);

      final TestGesture gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(_tab(geometry, 2));
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Edit'), findsOneWidget);
      await gesture.up();
      await tester.pump();

      expect(log.events, ['edit n2']);
    });

    testWidgets('moving more than the tolerance restarts the dwell', (tester) async {
      final _Log log = await _pump(tester);
      final LauncherGeometry geometry = _geometry(4);
      final Offset note = _tab(geometry, 2);

      final TestGesture gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(note);
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveTo(note + const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump();

      expect(log.events, ['open n2']);
    });

    testWidgets('release on "+" asks for a new list; on the hub cancels', (tester) async {
      final _Log log = await _pump(tester);
      final LauncherGeometry geometry = _geometry(4);

      TestGesture gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(geometry.addCenter);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();

      gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(_tab(geometry, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pump();

      expect(log.events, ['new']);
    });

    testWidgets('resting at the right end scrolls the notes', (tester) async {
      final _Log log = await _pump(tester, count: 12);
      final LauncherGeometry geometry = _geometry(12);
      final Offset rightEnd = geometry.pointAt(
        geometry.slotAngle(geometry.slotCount - 0.55),
        _config.innerRadius + _config.tabLength / 2,
      );

      final TestGesture gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(rightEnd);
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pump();

      // Scrolled to the end, so the last tab is under the finger. Once the
      // tabs stop moving, resting there arms Edit as anywhere else.
      expect(log.events, ['edit n11']);
    });
  });

  group('tap mode', () {
    testWidgets('tap the hub, tap a note to open; long-press to edit', (tester) async {
      final _Log log = await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('launcher-hub')));
      await tester.pump();
      expect(find.text('Note 0'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('launcher-note-n3')));
      await tester.pump();
      expect(log.events, ['open n3']);
      expect(find.text('Note 0'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('launcher-hub')));
      await tester.pump();
      await tester.longPress(find.byKey(const ValueKey('launcher-note-n1')));
      await tester.pump();
      expect(log.events, ['open n3', 'edit n1']);
    });

    testWidgets('tap outside closes; "+" is inactive without onNew', (tester) async {
      final _Log log = await _pump(tester, withNew: false);

      await tester.tap(find.byKey(const ValueKey('launcher-hub')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('launcher-add')));
      await tester.pump();
      expect(log.events, isEmpty);
      expect(find.text('Note 0'), findsOneWidget);

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      expect(find.text('Note 0'), findsNothing);
    });

    testWidgets('arrows page through many notes', (tester) async {
      await _pump(tester, count: 12);

      await tester.tap(find.byKey(const ValueKey('launcher-hub')));
      await tester.pump();
      expect(find.text('Note 0'), findsOneWidget);
      expect(find.text('Note 11'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('launcher-next')));
      await tester.pump();
      expect(find.text('Note 0'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('launcher-next')));
      await tester.pump();
      expect(find.text('Note 11'), findsOneWidget);
    });

    testWidgets('keyboard: arrows move focus, Enter opens, E edits, Esc closes', (tester) async {
      final _Log log = await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('launcher-hub')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(log.events, ['open n2']);

      await tester.tap(find.byKey(const ValueKey('launcher-hub')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(log.events, ['open n2', 'edit n0']);

      await tester.tap(find.byKey(const ValueKey('launcher-hub')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Note 0'), findsNothing);
    });

    testWidgets('notes have screen-reader labels', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('launcher-hub')));
      await tester.pump();

      expect(find.bySemanticsLabel('Note 2, 2'), findsOneWidget);
      handle.dispose();
    });
  });
}
