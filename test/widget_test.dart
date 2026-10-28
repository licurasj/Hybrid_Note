import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/app_cubit.dart';
import 'package:hybrid_note/lists/custom_lists.dart';
import 'package:hybrid_note/lists/local_list_store.dart';
import 'package:hybrid_note/app/hybrid_note_app.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('HybridNoteApp starts on the home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AppCubit(
              storage: FakeAppStorage(),
              driveSyncService: FakeDriveSyncService(),
              deviceId: 'test-device',
            )..loadData(),
          ),
          BlocProvider(create: (_) => CustomListsCubit(FakeCustomListsStorage())..load()),
          LocalListStore.provider(),
        ],
        child: const HybridNoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Pending Tasks'), findsOneWidget);
    expect(find.byKey(const ValueKey('launcher-hub')), findsOneWidget);

    // Tap mode: open the hub and pick Grocery; the list opens as a page.
    await tester.tap(find.byKey(const ValueKey('launcher-hub')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('launcher-note-builtin.grocery')));
    await tester.pumpAndSettle();
    expect(find.text('Grocery List'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hub can be moved and its position is saved', (
    WidgetTester tester,
  ) async {
    final FakeAppStorage storage = FakeAppStorage();
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AppCubit(
              storage: storage,
              driveSyncService: FakeDriveSyncService(),
              deviceId: 'test-device',
            )..loadData(),
          ),
          BlocProvider(create: (_) => CustomListsCubit(FakeCustomListsStorage())..load()),
          LocalListStore.provider(),
        ],
        child: const HybridNoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    final Finder hub = find.byKey(const ValueKey('launcher-hub'));
    final Offset start = tester.getCenter(hub);
    TestGesture gesture = await tester.startGesture(start);
    for (int i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final Offset prompt = tester.getCenter(find.byKey(const ValueKey('launcher-move-prompt')));
    for (int i = 1; i <= 6; i++) {
      await gesture.moveTo(Offset.lerp(start, prompt, i / 6)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    gesture = await tester.startGesture(start);
    await gesture.moveTo(const Offset(120, 200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getCenter(hub).dx, closeTo(120, 1));
    expect(storage.hubPosition, isNotNull);
  });
}
