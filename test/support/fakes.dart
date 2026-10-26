import 'package:hybrid_note/app_data.dart';
import 'package:hybrid_note/app_storage.dart';
import 'package:hybrid_note/drive_sync_service.dart';

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

  bool leftHanded = false;

  @override
  Future<bool> loadLeftHanded() async => leftHanded;

  @override
  Future<void> saveLeftHanded(bool leftHanded) async {
    this.leftHanded = leftHanded;
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
