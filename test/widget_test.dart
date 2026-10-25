import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lucas_tac368_project/app_cubit.dart';
import 'package:lucas_tac368_project/app_data.dart';
import 'package:lucas_tac368_project/app_storage.dart';
import 'package:lucas_tac368_project/drive_sync_service.dart';
import 'package:lucas_tac368_project/main.dart';

// In-memory storage so the test never touches path_provider or the disk.
class FakeAppStorage extends AppStorage {
  AppData data = AppData.empty('test-device');
  String? localeCode = 'en';

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<AppData> loadAppData() async => data;

  @override
  Future<void> saveAppData(AppData data) async {
    this.data = data;
  }

  @override
  Future<String?> loadPreferredLocaleCode() async => localeCode;

  @override
  Future<void> savePreferredLocaleCode(String? localeCode) async {
    this.localeCode = localeCode;
  }
}

// Signed-out Drive service so no Google sign-in plugin calls are made.
class FakeDriveSyncService extends DriveSyncService {
  @override
  bool get isSignedIn => false;

  @override
  Future<bool> tryRestorePreviousSignIn() async => false;
}

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
