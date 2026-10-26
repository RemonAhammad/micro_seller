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

  /// Resumable upload chunk (must be a multiple of 256 KB). Most backups fit
  /// in one chunk; bigger ones are sent — and retried — 8 MB at a time.
  static const _uploadChunkSize = 8 * 1024 * 1024;

  final LocalBackupService _localBackup = LocalBackupService();

  // ── Google Sign-In (google_sign_in 7) ──
  //
  // v7 splits *authentication* (who the user is — `authenticate()`, needs UI)
  // from *authorization* (Drive access token — `authorizationClient`). Drive
  // only needs authorization, which can be checked without any UI, so the
  // background worker never risks showing a picker.
  //
  // On Android without google-services.json, v7 requires the **web** OAuth
  // client id as `serverClientId` (GOOGLE_OAUTH_WEB_CLIENT_ID in .env).
  //
  // On iOS the app's own iOS OAuth client signs in. No `clientId` is passed
  // here, so the plugin reads it from `GIDClientID` in ios/Runner/Info.plist,
  // the file that also registers its reversed id as the URL scheme Google's
  // sign-in page returns through. Keeping both in one place matters: a
  // missing GIDClientID, or a client id without its URL scheme, makes the
  // interactive sign-in raise a native exception Dart can't catch, which
  // closes the app (test/drive_ios_test.dart checks the pair). With no
  // `clientId`, iOS ignores `serverClientId`; Drive doesn't need it there.
  // Back up to Drive and Restore work on iPhone too; Auto Backup isn't
  // offered there (AutoBackupRunner.isSupported).

  static bool _initialized = false;
  static GoogleSignInAccount? _account;

  /// Forgets that Google Sign-In was initialised, so a test can initialise it
  /// again (as another platform, with another `.env`).
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
      // Never an empty string: unset or blank in .env is no server client.
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

  /// Maps a v7 sign-in failure onto the app's stable [DriveErrorCode]s.
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

  /// Drive API client. With [interactive] false (background worker, app
  /// start) this never shows UI: it only uses an already-granted token and
  /// throws [DriveErrorCode.notSignedIn] otherwise.
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

  /// Interactive sign-in + Drive consent. Returns null if the user cancels.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      await _ensureInitialized();
      final account =
          await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
      // Grant Drive access now so later (and background) backups don't need UI.
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

  /// The signed-in account, restored without a picker when possible (used to
  /// show the email in Settings). May be null even when [hasDriveAccess] is
  /// true — Drive backups only need the latter.
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

  /// True if a Drive token is available without any UI — the check the
  /// auto-backup paths use before running.
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

  /// [settings] — pass the user's exported preferences map (theme, currency,
  /// sidebar order, etc.) to include them in the backup. Pass null to back
  /// up data only.
  ///
  /// [interactive] — when false, the call will NOT show a sign-in picker if
  /// silent sign-in fails (background workers must use `false`). It instead
  /// throws `DriveBackupException(notSignedIn)` so the caller can mark the
  /// auto-backup as paused and prompt the user from the UI.
  ///
  /// [encodeOnWorker] — read and encode the backup on a worker isolate
  /// (default), so the UI isolate never freezes. The WorkManager auto-backup
  /// passes false: it already runs on its own UI-less isolate.
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
        // Resumable rather than the default multipart upload: multipart
        // base64-encodes the whole backup in one go on this isolate, while
        // resumable sends the raw bytes in chunks. Same file on Drive (same
        // metadata, bytes and content type).
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

  /// [currentSettings] — snapshot of the user's current preferences, used
  /// for the rollback safety backup. Pass via `Settings.exportSettings()`.
  /// [onSettingsRestored] — called with the imported settings map (if the
  /// backup contained one) after a successful restore. The caller should
  /// apply it via `Settings.importSettings`.
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

      // copy: false — keeps the received chunks instead of copying each one
      // into a growing list, and joins them once.
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

  /// The part of [restoreFromDrive] after the download: snapshot, restore,
  /// roll back on failure. Decoding, validation, the restore write and the
  /// snapshot all run on worker isolates; only [onSettingsRestored] runs
  /// here.
  ///
  /// Errors: [DriveErrorCode.invalidBackup] — not a backup, nothing touched;
  /// [DriveErrorCode.rolledBack] — the restore failed and the previous data
  /// is back; [DriveErrorCode.restoreFailed] — the rollback failed too.
  @visibleForTesting
  Future<void> restoreFromBytes(
    Isar isar,
    Uint8List bytes, {
    Map<String, dynamic>? currentSettings,
    Future<void> Function(Map<String, dynamic>)? onSettingsRestored,
  }) async {
    // Snapshot current DB + settings so we can roll back if import fails.
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
      // Validated (JSON, `version` + `timestamp`) before anything is written.
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

    // Roll back to the safety snapshot. The outcome is thrown outside the
    // rollback's try, so a successful rollback is reported as rolledBack
    // (it used to be caught by its own catch and reported as restoreFailed).
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
