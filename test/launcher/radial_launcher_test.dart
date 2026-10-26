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

Future<_Log> _pump(WidgetTester tester, {int count = 4, bool withNew = true}) async {
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
        ),
      ),
    ),
  );
  return log;
}

LauncherGeometry _geometry(WidgetTester tester, int count) {
  final Offset hub = tester.getCenter(find.byKey(const ValueKey('launcher-hub')));
  return LauncherGeometry(config: _config, hubCenter: hub, noteCount: count);
}

void main() {
  group('geometry', () {
    final LauncherGeometry geometry = LauncherGeometry(
      config: _config,
      hubCenter: const Offset(200, 700),
      noteCount: 12,
    );

    test('notes sit on the arc above the hub, left to right, "+" last', () {
      final Offset first = geometry.noteCenter(0, 0)!;
      final Offset second = geometry.noteCenter(1, 0)!;

      expect((first - geometry.hubCenter).distance, closeTo(150, 0.01));
      expect(first.dx < second.dx, isTrue);
      expect(geometry.addCenter.dx > second.dx, isTrue);
    });

    test('hit testing finds notes, "+", the hub and nothing', () {
      expect(geometry.hitTest(geometry.noteCenter(2, 0)!, 0),
          const LauncherTarget(LauncherTargetKind.note, 2));
      expect(geometry.hitTest(geometry.addCenter, 0), LauncherTarget.add);
      expect(geometry.hitTest(geometry.hubCenter, 0), LauncherTarget.hub);
      expect(geometry.hitTest(const Offset(200, 300), 0), LauncherTarget.none);
      expect(geometry.hitTest(const Offset(200, 790), 0), LauncherTarget.none);
    });

    test('scrolling shifts which note is under a slot', () {
      final Offset slot0 = geometry.noteCenter(0, 0)!;
      expect(geometry.hitTest(slot0, 3),
          const LauncherTarget(LauncherTargetKind.note, 3));
      expect(geometry.noteCenter(0, 3), isNull);
    });

    test('end zones scroll left and right; the middle does not', () {
      final Offset left = geometry.pointAt(geometry.slotAngle(-0.4));
      final Offset right = geometry.pointAt(geometry.slotAngle(geometry.noteSlotCount - 0.6));
      final Offset middle = geometry.pointAt(geometry.slotAngle(geometry.noteSlotCount / 2));

      expect(geometry.scrollVelocity(left), lessThan(0));
      expect(geometry.scrollVelocity(right), greaterThan(0));
      expect(geometry.scrollVelocity(middle), 0);
      expect(geometry.scrollVelocity(geometry.addCenter), 0);
    });

    test('no scrolling when every note fits', () {
      final LauncherGeometry few = LauncherGeometry(
        config: _config,
        hubCenter: const Offset(200, 700),
        noteCount: 2,
      );
      expect(few.maxScrollOffset, 0);
      expect(few.scrollVelocity(few.pointAt(few.slotAngle(0))), 0);
    });
  });

  group('hold mode', () {
    testWidgets('drag onto a note and release opens it', (tester) async {
      final _Log log = await _pump(tester);
      final LauncherGeometry geometry = _geometry(tester, 4);

      final TestGesture gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(geometry.noteCenter(1, 0)!);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump();

      expect(log.events, ['open n1']);
      expect(find.text('Note 1'), findsNothing);
    });

    testWidgets('resting on a note arms edit', (tester) async {
      final _Log log = await _pump(tester);
      final LauncherGeometry geometry = _geometry(tester, 4);

      final TestGesture gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(geometry.noteCenter(2, 0)!);
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
      final LauncherGeometry geometry = _geometry(tester, 4);
      final Offset note = geometry.noteCenter(2, 0)!;

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
      final LauncherGeometry geometry = _geometry(tester, 4);

      TestGesture gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(geometry.addCenter);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();

      gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(geometry.noteCenter(0, 0)!);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pump();

      expect(log.events, ['new']);
    });

    testWidgets('resting at the right end scrolls the notes', (tester) async {
      final _Log log = await _pump(tester, count: 12);
      final LauncherGeometry geometry = _geometry(tester, 12);
      final Offset rightEnd = geometry.pointAt(geometry.slotAngle(geometry.noteSlotCount - 0.55));

      final TestGesture gesture = await tester.startGesture(geometry.hubCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(rightEnd);
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pump();

      // Scrolled to the end, so the last note is under the finger. Once the
      // notes stop moving, resting there arms Edit as anywhere else.
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
