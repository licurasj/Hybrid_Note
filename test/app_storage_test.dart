import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/app_data.dart';
import 'package:hybrid_note/app_storage.dart';

void main() {
  late Directory directory;
  late AppStorage storage;
  late File dataFile;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hybrid_note_storage_');
    storage = AppStorage(getDirectory: () async => directory);
    dataFile = File('${directory.path}/hybrid_note_app_data.json');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  List<File> backupFiles() {
    return directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('.unreadable-'))
        .toList();
  }

  test('unreadable data file is backed up, not wiped', () async {
    const String corrupt = '{"tasks": [ this is not json';
    await dataFile.writeAsString(corrupt);

    final AppData loaded = await storage.loadAppData();

    expect(loaded.tasks, isEmpty);
    final List<File> backups = backupFiles();
    expect(backups, hasLength(1));
    expect(await backups.single.readAsString(), corrupt);

    // The data file was replaced with readable empty data.
    final Map<String, dynamic> saved =
        jsonDecode(await dataFile.readAsString()) as Map<String, dynamic>;
    expect(AppData.fromJson(saved).tasks, isEmpty);
  });

  test('readable data file is loaded and no backup is made', () async {
    final AppData original = AppData.empty('device-1').copyWith(
      isDarkMode: true,
    );
    await storage.saveAppData(original);

    final AppData loaded = await storage.loadAppData();

    expect(loaded.isDarkMode, isTrue);
    expect(backupFiles(), isEmpty);
  });

  test('save replaces the file and leaves no temporary file', () async {
    await storage.saveAppData(AppData.empty('device-1'));
    await storage.saveAppData(
      AppData.empty('device-1').copyWith(isDarkMode: true),
    );

    final AppData loaded = await storage.loadAppData();

    expect(loaded.isDarkMode, isTrue);
    expect(File('${dataFile.path}.tmp').existsSync(), isFalse);
  });

  test('overlapping saves finish in call order and leave the last one', () async {
    // Callers emit before awaiting the save, so saves can overlap (T-1 F1).
    final List<Future<void>> saves = [
      for (int i = 0; i < 20; i++)
        storage.saveAppData(
          AppData.empty('device-$i').copyWith(isDarkMode: i.isOdd),
        ),
    ];
    await Future.wait(saves);

    final Map<String, dynamic> saved =
        jsonDecode(await dataFile.readAsString()) as Map<String, dynamic>;
    expect(AppData.fromJson(saved).deviceId, 'device-19');
    expect(File('${dataFile.path}.tmp').existsSync(), isFalse);
  });

  test('a failed save does not block the saves after it', () async {
    bool fail = true;
    final AppStorage flaky = AppStorage(
      getDirectory: () async {
        if (fail) {
          fail = false;
          throw const FileSystemException('no folder');
        }
        return directory;
      },
    );

    final Future<void> first = flaky.saveAppData(AppData.empty('device-1'));
    final Future<void> second = flaky.saveAppData(AppData.empty('device-2'));

    await expectLater(first, throwsA(isA<FileSystemException>()));
    await second;
    final Map<String, dynamic> saved =
        jsonDecode(await dataFile.readAsString()) as Map<String, dynamic>;
    expect(AppData.fromJson(saved).deviceId, 'device-2');
  });
}
