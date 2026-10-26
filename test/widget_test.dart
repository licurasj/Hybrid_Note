import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/app_cubit.dart';
import 'package:hybrid_note/main.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('HybridNoteApp starts on the home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => AppCubit(
          storage: FakeAppStorage(),
          driveSyncService: FakeDriveSyncService(),
          deviceId: 'test-device',
        )..loadData(),
        child: const HybridNoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
