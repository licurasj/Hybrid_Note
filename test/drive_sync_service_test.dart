import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lucas_tac368_project/app_data.dart';
import 'package:lucas_tac368_project/drive_sync_service.dart';
import 'package:lucas_tac368_project/sync_result.dart';

// Fakes the Drive endpoints used by sync: list, download, copy and upload.
class FakeDrive {
  FakeDrive({required this.remoteBody, this.copyFails = false});

  final String remoteBody;
  final bool copyFails;
  final List<String> calls = [];
  String? copyName;
  String? uploadedBody;

  MockClient get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final String path = request.url.path;
    const Map<String, String> json = {'content-type': 'application/json'};

    if (request.method == 'GET' && path == '/drive/v3/files') {
      calls.add('list');
      return http.Response(
        jsonEncode({
          'files': [
            {'id': 'remote-1', 'name': 'hybrid_note_app_data.json'},
          ],
        }),
        200,
        headers: json,
      );
    }

    if (request.method == 'GET' && path == '/drive/v3/files/remote-1') {
      calls.add('download');
      return http.Response(remoteBody, 200, headers: json);
    }

    if (request.method == 'POST' && path == '/drive/v3/files/remote-1/copy') {
      calls.add('copy');
      if (copyFails) {
        return http.Response(
          jsonEncode({
            'error': {'code': 500, 'message': 'copy failed'},
          }),
          500,
          headers: json,
        );
      }
      copyName =
          (jsonDecode(request.body) as Map<String, dynamic>)['name'] as String?;
      return http.Response(jsonEncode({'id': 'backup-1'}), 200, headers: json);
    }

    if (request.method == 'PATCH' &&
        path == '/upload/drive/v3/files/remote-1') {
      calls.add('upload');
      // Multipart upload: the media part is base64 after its headers.
      final String media = request.body
          .split('Content-Transfer-Encoding: base64\r\n\r\n')
          .last
          .split('\r\n--')
          .first;
      uploadedBody = utf8.decode(base64.decode(media));
      return http.Response(jsonEncode({'id': 'remote-1'}), 200, headers: json);
    }

    return http.Response('unexpected ${request.method} $path', 404);
  }
}

void main() {
  final AppData localData = AppData.empty('local-device');

  test('unreadable remote file is copied aside before being replaced', () async {
    final FakeDrive fake = FakeDrive(remoteBody: 'not json at all');

    final SyncResult result = await DriveSyncService().mergeThenUpload(
      driveApi: drive.DriveApi(fake.client),
      localData: localData,
    );

    expect(result.status, SyncStatus.localNewerUploaded);
    expect(fake.calls, ['list', 'download', 'copy', 'upload']);
    expect(fake.copyName, startsWith('hybrid_note_app_data.json.unreadable-'));
    expect(fake.uploadedBody, contains('local-device'));
  });

  test('remote file is not overwritten when the backup copy fails', () async {
    final FakeDrive fake = FakeDrive(
      remoteBody: 'not json at all',
      copyFails: true,
    );

    await expectLater(
      DriveSyncService().mergeThenUpload(
        driveApi: drive.DriveApi(fake.client),
        localData: localData,
      ),
      throwsA(anything),
    );

    expect(fake.calls, ['list', 'download', 'copy']);
    expect(fake.uploadedBody, isNull);
  });

  test('readable remote file is merged without a backup', () async {
    final FakeDrive fake = FakeDrive(
      remoteBody: jsonEncode(AppData.empty('remote-device').toJson()),
    );

    final SyncResult result = await DriveSyncService().mergeThenUpload(
      driveApi: drive.DriveApi(fake.client),
      localData: localData,
    );

    expect(result.status, SyncStatus.merged);
    expect(fake.calls, ['list', 'download', 'upload']);
  });
}
