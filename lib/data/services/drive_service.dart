import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import '../../core/utils/date_formatter.dart';
import 'local_backup_service.dart';

class DriveBackupInfo {
  final String fileId;
  final String name;
  final DateTime createdTime;

  DriveBackupInfo({
    required this.fileId,
    required this.name,
    required this.createdTime,
  });
}

/// Stable error codes for the Drive backup pipeline. UI code switches on these
/// instead of substring-matching exception messages.
enum DriveErrorCode {
  notSignedIn,
  signInCancelled,
  signInFailed,
  /// `DEVELOPER_ERROR` (status 10) from Google Play Services. Means the SHA-1
  /// of the running APK + package name don't match any Android OAuth client
  /// in the Cloud project (or Drive API isn't enabled there).
  developerError,
  network,
  invalidBackup,
  uploadFailed,
  downloadFailed,
  restoreFailed,
  rolledBack,
  unknown,
}

class DriveBackupException implements Exception {
  final DriveErrorCode code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  DriveBackupException(
    this.code,
    this.message, {
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() =>
      'DriveBackupException(${code.name}): $message${cause != null ? '\nCause: $cause' : ''}';
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client;

  _AuthClient(this._headers, this._client);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}

class DriveService {
  static const _scopes = [drive.DriveApi.driveAppdataScope];
  static const _maxBackups = 5;
  static const _backupPrefix = 'sellerbook_backup';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);
  final LocalBackupService _localBackup = LocalBackupService();

  void _logError(String tag, Object error, StackTrace stack) {
    developer.log(
      tag,
      name: 'DriveService',
      error: error,
      stackTrace: stack,
    );
    if (kDebugMode) {
      debugPrint('[DriveService] $tag: $error');
      debugPrintStack(stackTrace: stack, label: 'DriveService.$tag');
    }
  }

  Future<drive.DriveApi> _getDriveApi() async {
    GoogleSignInAccount? account;
    try {
      account =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    } catch (e, st) {
      _logError('signIn', e, st);
      throw DriveBackupException(
        DriveErrorCode.signInFailed,
        'Could not sign in to Google. Please try again.',
        cause: e,
        stackTrace: st,
      );
    }

    if (account == null) {
      throw DriveBackupException(
        DriveErrorCode.notSignedIn,
        'You need to sign in to Google before backing up.',
      );
    }

    try {
      final auth = await account.authentication;
      final client = _AuthClient(
        {'Authorization': 'Bearer ${auth.accessToken}'},
        http.Client(),
      );
      return drive.DriveApi(client);
    } catch (e, st) {
      _logError('getAuthHeaders', e, st);
      throw DriveBackupException(
        DriveErrorCode.signInFailed,
        'Could not authorize Google Drive access.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } on PlatformException catch (e, st) {
      _logError('signIn', e, st);
      // ApiException: 10 == DEVELOPER_ERROR — SHA-1 / package / API enablement
      // mismatch in Cloud Console.
      if (e.code == 'sign_in_failed' &&
          (e.message?.contains('ApiException: 10') ?? false)) {
        throw DriveBackupException(
          DriveErrorCode.developerError,
          'Sign-in is not configured correctly. Verify the SHA-1, package name, '
              'and that the Google Drive API is enabled in the Cloud project.',
          cause: e,
          stackTrace: st,
        );
      }
      throw DriveBackupException(
        DriveErrorCode.signInFailed,
        'Sign-in failed. Please try again.',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      _logError('signIn', e, st);
      throw DriveBackupException(
        DriveErrorCode.signInFailed,
        'Sign-in failed. Please try again.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e, st) {
      _logError('signOut', e, st);
    }
  }

  Future<GoogleSignInAccount?> getCurrentUser() async {
    try {
      return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    } catch (e, st) {
      _logError('getCurrentUser', e, st);
      return null;
    }
  }

  Future<void> backupToDrive(Isar isar) async {
    final driveApi = await _getDriveApi();

    final String jsonStr;
    try {
      jsonStr = await _localBackup.encodeAll(isar);
    } catch (e, st) {
      _logError('encodeAll', e, st);
      throw DriveBackupException(
        DriveErrorCode.unknown,
        'Could not prepare backup data.',
        cause: e,
        stackTrace: st,
      );
    }

    final fileName =
        '${_backupPrefix}_${DateFormatter.formatForBackup(DateTime.now())}.json';
    final bytes = utf8.encode(jsonStr);

    final file = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder'];

    try {
      await driveApi.files.create(
        file,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      );
    } catch (e, st) {
      _logError('upload', e, st);
      throw DriveBackupException(
        DriveErrorCode.uploadFailed,
        'Could not upload backup. Check your connection and try again.',
        cause: e,
        stackTrace: st,
      );
    }

    try {
      await _cleanupOldBackups(driveApi);
    } catch (e, st) {
      // Cleanup failure is non-critical — the backup itself succeeded.
      _logError('cleanup', e, st);
    }
  }

  Future<void> _cleanupOldBackups(drive.DriveApi driveApi) async {
    final list = await driveApi.files.list(
      spaces: 'appDataFolder',
      orderBy: 'createdTime',
      q: "name contains '$_backupPrefix'",
    );

    final files = list.files ?? [];
    if (files.length > _maxBackups) {
      final toDelete = files.sublist(0, files.length - _maxBackups);
      for (final f in toDelete) {
        if (f.id != null) {
          await driveApi.files.delete(f.id!);
        }
      }
    }
  }

  Future<List<DriveBackupInfo>> listBackups() async {
    try {
      final driveApi = await _getDriveApi();
      final list = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
        q: "name contains '$_backupPrefix'",
        $fields: 'files(id,name,createdTime)',
      );

      return (list.files ?? [])
          .where((f) => f.id != null && f.name != null)
          .map((f) => DriveBackupInfo(
                fileId: f.id!,
                name: f.name!,
                createdTime: f.createdTime ?? DateTime.now(),
              ))
          .toList();
    } on DriveBackupException {
      rethrow;
    } catch (e, st) {
      _logError('listBackups', e, st);
      throw DriveBackupException(
        DriveErrorCode.network,
        'Could not load backups. Check your connection and try again.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> restoreFromDrive(Isar isar, String fileId) async {
    final driveApi = await _getDriveApi();

    String jsonStr;
    try {
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final chunks = <int>[];
      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
      }
      jsonStr = utf8.decode(chunks);
    } catch (e, st) {
      _logError('download', e, st);
      throw DriveBackupException(
        DriveErrorCode.downloadFailed,
        'Could not download backup. Check your connection and try again.',
        cause: e,
        stackTrace: st,
      );
    }

    // Sanity-check JSON before touching local DB.
    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e, st) {
      _logError('parseJson', e, st);
      throw DriveBackupException(
        DriveErrorCode.invalidBackup,
        'Backup file is corrupted or unreadable.',
        cause: e,
        stackTrace: st,
      );
    }

    if (!data.containsKey('version') || !data.containsKey('timestamp')) {
      throw DriveBackupException(
        DriveErrorCode.invalidBackup,
        'Backup file is missing required metadata.',
      );
    }

    // Snapshot current DB so we can roll back if import fails halfway.
    String safetyBackup;
    try {
      safetyBackup = await _localBackup.encodeAll(isar);
    } catch (e, st) {
      _logError('safetySnapshot', e, st);
      throw DriveBackupException(
        DriveErrorCode.unknown,
        'Could not prepare a safety backup before restoring.',
        cause: e,
        stackTrace: st,
      );
    }

    try {
      await _localBackup.decodeAll(isar, jsonStr);
    } catch (e, st) {
      _logError('restoreImport', e, st);
      // Roll back to the safety snapshot.
      try {
        await _localBackup.decodeAll(isar, safetyBackup);
        throw DriveBackupException(
          DriveErrorCode.rolledBack,
          'Restore failed. Your previous data has been preserved.',
          cause: e,
          stackTrace: st,
        );
      } catch (rollbackErr, rollbackSt) {
        _logError('rollback', rollbackErr, rollbackSt);
        throw DriveBackupException(
          DriveErrorCode.restoreFailed,
          'Restore failed and rollback also failed. Data may be inconsistent.',
          cause: rollbackErr,
          stackTrace: rollbackSt,
        );
      }
    }
  }
}
