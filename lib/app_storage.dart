import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'app_data.dart';

class AppStorage {
  static const String _dataFileName = 'hybrid_note_app_data.json';
  static const String _deviceFileName = 'hybrid_note_app_device.txt';
  static const String _localeFileName = 'hybrid_note_app_locale.txt';
  static const String _hubFileName = 'hybrid_note_app_hub.txt';

  // Tests pass a temporary directory; the app uses the documents folder.
  final Future<Directory> Function() _getDirectory;

  AppStorage({Future<Directory> Function()? getDirectory})
      : _getDirectory = getDirectory ?? getApplicationDocumentsDirectory;

  Future<File> _getDataFile() async {
    final Directory directory = await _getDirectory();
    return File('${directory.path}/$_dataFileName');
  }

  Future<File> _getDeviceFile() async {
    final Directory directory = await _getDirectory();
    return File('${directory.path}/$_deviceFileName');
  }

  Future<File> _getLocaleFile() async {
    final Directory directory = await _getDirectory();
    return File('${directory.path}/$_localeFileName');
  }

  Future<String> getOrCreateDeviceId() async {
    final File file = await _getDeviceFile();

    if (await file.exists()) {
      final String savedId = await file.readAsString();
      if (savedId.trim().isNotEmpty) {
        return savedId.trim();
      }
    }

    final String newId = const Uuid().v4();
    await file.writeAsString(newId);
    return newId;
  }

  Future<AppData> loadAppData() async {
    final String deviceId = await getOrCreateDeviceId();
    final File file = await _getDataFile();

    if (!await file.exists()) {
      final AppData emptyData = AppData.empty(deviceId);
      await saveAppData(emptyData);
      return emptyData;
    }

    try {
      final String rawJson = await file.readAsString();
      final Map<String, dynamic> decoded =
          jsonDecode(rawJson) as Map<String, dynamic>;

      final AppData loadedData = AppData.fromJson(decoded);

      if (loadedData.deviceId.isEmpty) {
        return loadedData.copyWith(deviceId: deviceId);
      }

      return loadedData;
    } catch (_) {
      // Never overwrite a file we could not read: move it aside first so the
      // data can still be recovered. If the move fails, this throws and the
      // file is left untouched.
      await _backUpUnreadableDataFile(file);
      final AppData emptyData = AppData.empty(deviceId);
      await saveAppData(emptyData);
      return emptyData;
    }
  }

  Future<File> _backUpUnreadableDataFile(File file) async {
    final String timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-');
    return file.rename('${file.path}.unreadable-$timestamp');
  }

  Future<void> saveAppData(AppData data) async {
    final File file = await _getDataFile();
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');

    // Write to a temporary file and rename it over the real one, so a crash
    // mid-write cannot leave a truncated data file behind.
    final File tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(encoder.convert(data.toJson()), flush: true);
    await tempFile.rename(file.path);
  }

  // Where the launcher hub sits, as fractions of the screen ("x,y"). It is a
  // per-device choice, so it is stored here rather than in the synced AppData.
  Future<Offset?> loadHubPosition() async {
    final Directory directory = await _getDirectory();
    final File file = File('${directory.path}/$_hubFileName');
    if (!await file.exists()) {
      return null;
    }
    final List<double?> parts = (await file.readAsString())
        .split(',')
        .map((part) => double.tryParse(part.trim()))
        .toList();
    if (parts.length != 2 || parts.contains(null)) {
      return null;
    }
    return Offset(parts[0]!, parts[1]!);
  }

  Future<void> saveHubPosition(Offset position) async {
    final Directory directory = await _getDirectory();
    await File('${directory.path}/$_hubFileName')
        .writeAsString('${position.dx},${position.dy}');
  }

  Future<String?> loadPreferredLocaleCode() async {
    final File file = await _getLocaleFile();

    if (!await file.exists()) {
      return null;
    }

    final String code = (await file.readAsString()).trim();

    if (code.isEmpty || code == 'system') {
      return null;
    }

    return code;
  }

  Future<void> savePreferredLocaleCode(String? localeCode) async {
    final File file = await _getLocaleFile();
    await file.writeAsString(localeCode == null ? 'system' : localeCode);
  }
}

