import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

enum DriveErrorCode {
  notSignedIn,
  signInCancelled,
  signInFailed,

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

  static const _uploadChunkSize = 8 * 1024 * 1024;

  final LocalBackupService _localBackup = LocalBackupService();

  static bool _initialized = false;
  static GoogleSignInAccount? _account;

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _account = null;
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final webClientId = dotenv.isInitialized
        ? dotenv.maybeGet('GOOGLE_OAUTH_WEB_CLIENT_ID')?.trim()
        : null;
    await GoogleSignIn.instance.initialize(

      serverClientId:
          (webClientId?.isNotEmpty ?? false) ? webClientId : null,
    );
    GoogleSignIn.instance.authenticationEvents.listen(
      (e) => _account = switch (e) {
        GoogleSignInAuthenticationEventSignIn() => e.user,
        GoogleSignInAuthenticationEventSignOut() => null,
      },
      onError: (_) {},
    );
    _initialized = true;
  }

  DriveBackupException _mapSignInError(Object e, StackTrace st) {
    if (e is GoogleSignInException) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          return DriveBackupException(
            DriveErrorCode.signInCancelled,
            'Sign-in was cancelled.',
            cause: e,
            stackTrace: st,
          );
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return DriveBackupException(
            DriveErrorCode.developerError,
            'Sign-in is not configured correctly. Verify the SHA-1, package '
                'name, the web client id (serverClientId) and that the Google '
                'Drive API is enabled in the Cloud project.',
            cause: e,
            stackTrace: st,
          );
        default:
          break;
      }
    }
    return DriveBackupException(
      DriveErrorCode.signInFailed,
      'Sign-in failed. Please try again.',
      cause: e,
      stackTrace: st,
    );
  }

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

  Future<drive.DriveApi> _getDriveApi({bool interactive = true}) async {
    GoogleSignInClientAuthorization? authz;
    try {
      await _ensureInitialized();
      final client = GoogleSignIn.instance.authorizationClient;
      authz = await client.authorizationForScopes(_scopes);
      if (authz == null && interactive) {
        authz = await client.authorizeScopes(_scopes);
      }
    } catch (e, st) {
      _logError('authorize', e, st);
      throw _mapSignInError(e, st);
    }

    if (authz == null) {
      throw DriveBackupException(
        DriveErrorCode.notSignedIn,
        'You need to sign in to Google before backing up.',
      );
    }

    final client = _AuthClient(
      {'Authorization': 'Bearer ${authz.accessToken}'},
      http.Client(),
    );
    return drive.DriveApi(client);
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await _ensureInitialized();
      final account =
          await GoogleSignIn.instance.authenticate(scopeHint: _scopes);

      await account.authorizationClient.authorizeScopes(_scopes);
      _account = account;
      return account;
    } catch (e, st) {
      _logError('signIn', e, st);
      final mapped = _mapSignInError(e, st);
      if (mapped.code == DriveErrorCode.signInCancelled) return null;
      throw mapped;
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
      _account = null;
    } catch (e, st) {
      _logError('signOut', e, st);
    }
  }

  Future<GoogleSignInAccount?> getCurrentUser() async {
    try {
      await _ensureInitialized();
      if (_account != null) return _account;
      final restored =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      return _account ?? restored;
    } catch (e, st) {
      _logError('getCurrentUser', e, st);
      return null;
    }
  }

  Future<bool> hasDriveAccess() async {
    try {
      await _ensureInitialized();
      return await GoogleSignIn.instance.authorizationClient
              .authorizationForScopes(_scopes) !=
          null;
    } catch (e, st) {
      _logError('hasDriveAccess', e, st);
      return false;
    }
  }

  Future<void> backupToDrive(
    Isar isar, {
    Map<String, dynamic>? settings,
    bool interactive = true,
    bool encodeOnWorker = true,
  }) async {
    final driveApi = await _getDriveApi(interactive: interactive);

    final Uint8List bytes;
    try {
      bytes = encodeOnWorker
          ? await _localBackup.encodeAllBytes(isar, settings: settings)
          : encodeBackupBytesSync(isar, settings: settings);
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

    final file = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder'];

    try {
      await driveApi.files.create(
        file,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),

        uploadOptions:
            drive.ResumableUploadOptions(chunkSize: _uploadChunkSize),
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

  Future<void> restoreFromDrive(
    Isar isar,
    String fileId, {
    Map<String, dynamic>? currentSettings,
    Future<void> Function(Map<String, dynamic>)? onSettingsRestored,
  }) async {
    final driveApi = await _getDriveApi();

    final Uint8List bytes;
    try {
      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    } catch (e, st) {
      _logError('download', e, st);
      throw DriveBackupException(
        DriveErrorCode.downloadFailed,
        'Could not download backup. Check your connection and try again.',
        cause: e,
        stackTrace: st,
      );
    }

    await restoreFromBytes(
      isar,
      bytes,
      currentSettings: currentSettings,
      onSettingsRestored: onSettingsRestored,
    );
  }

  @visibleForTesting
  Future<void> restoreFromBytes(
    Isar isar,
    Uint8List bytes, {
    Map<String, dynamic>? currentSettings,
    Future<void> Function(Map<String, dynamic>)? onSettingsRestored,
  }) async {

    final Uint8List safetyBackup;
    try {
      safetyBackup =
          await _localBackup.encodeAllBytes(isar, settings: currentSettings);
    } catch (e, st) {
      _logError('safetySnapshot', e, st);
      throw DriveBackupException(
        DriveErrorCode.unknown,
        'Could not prepare a safety backup before restoring.',
        cause: e,
        stackTrace: st,
      );
    }

    final Object restoreError;
    final StackTrace restoreStack;
    try {

      final restoredSettings = await _localBackup.restoreBytes(
        isar,
        bytes,
        requireMetadata: true,
      );
      if (restoredSettings != null && onSettingsRestored != null) {
        await onSettingsRestored(restoredSettings);
      }
      return;
    } on InvalidBackupException catch (e, st) {
      _logError('parseJson', e, st);
      throw DriveBackupException(
        DriveErrorCode.invalidBackup,
        e.message,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      _logError('restoreImport', e, st);
      restoreError = e;
      restoreStack = st;
    }

    try {
      await _localBackup.restoreBytes(isar, safetyBackup);
    } catch (rollbackErr, rollbackSt) {
      _logError('rollback', rollbackErr, rollbackSt);
      throw DriveBackupException(
        DriveErrorCode.restoreFailed,
        'Restore failed and rollback also failed. Data may be inconsistent.',
        cause: rollbackErr,
        stackTrace: rollbackSt,
      );
    }
    throw DriveBackupException(
      DriveErrorCode.rolledBack,
      'Restore failed. Your previous data has been preserved.',
      cause: restoreError,
      stackTrace: restoreStack,
    );
  }
}
