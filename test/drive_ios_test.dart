// Google Drive backup on iOS. The app's own iOS OAuth client signs in there:
// no client id is passed from Dart, so Google Sign-In reads GIDClientID from
// ios/Runner/Info.plist, next to the reversed-id URL scheme the sign-in
// returns through. Back up to Drive and Restore work as on Android. Auto
// Backup isn't offered on iOS: Settings hides its switch and paused banner,
// and the app-start runner does nothing, even when a backup restored from an
// Android phone turned it on. A failed Google sign-in on iOS also says that a
// sideloaded install may not be able to sign in. Settings words every Drive
// error in the app's language. Android is unchanged.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Google Sign-In's platform side, faked below so the app's real calls run
// without a device. A dependency of google_sign_in, not of the app.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/data/services/auto_backup_runner.dart';
import 'package:micro_seller/data/services/drive_service.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/layout_harness.dart';

/// The iOS OAuth client the owner created for the iOS app
/// (com.blackshadowsoftware.microseller).
const _iosClientId =
    '1084592092620-u1b2d9ubukcg8qut58luo19tm2c7m36t.apps.googleusercontent.com';

/// A web client id, as `.env` names one (GOOGLE_OAUTH_WEB_CLIENT_ID).
const _webClientId = '123456789012-web.apps.googleusercontent.com';

/// Runs the rest of a plain test as on [platform]. (A widget test uses a
/// [TargetPlatformVariant] instead.)
void _runAs(TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}

/// Google Sign-In's platform side without a device: records how the app set
/// it up and what it asked, and signs in as seller@example.com unless
/// [authenticateError] is set.
class _FakeGoogleSignIn extends GoogleSignInPlatform {
  final inits = <InitParameters>[];
  final authentications = <AuthenticateParameters>[];
  final authorizations = <AuthorizationRequestDetails>[];

  /// What the sign-in sheet ends with instead of an account.
  Object? authenticateError;

  bool _signedIn = false;

  static const _results = AuthenticationResults(
    user: GoogleSignInUserData(email: 'seller@example.com', id: '42'),
    authenticationTokens: AuthenticationTokenData(idToken: null),
  );

  @override
  Future<void> init(InitParameters params) async {
    inits.add(params);
  }

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => _signedIn ? _results : null;

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authentications.add(params);
    if (authenticateError case final e?) throw e;
    _signedIn = true;
    return _results;
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    authorizations.add(params.request);
    return _signedIn
        ? const ClientAuthorizationTokenData(accessToken: 'drive-token')
        : null;
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {
    _signedIn = false;
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {
    _signedIn = false;
  }
}

/// Drive without Google: never signed in, failing as told, counting what
/// was asked.
class _FakeDrive extends DriveService {
  /// How many times the signed-in account was looked up.
  int accountChecks = 0;

  /// How many times a backup asked whether it may run.
  int accessChecks = 0;

  /// What Sign in throws.
  Object? signInError;

  /// What listing the backups (Restore from Drive) throws.
  Object? listError;

  @override
  Future<GoogleSignInAccount?> getCurrentUser() async {
    accountChecks++;
    return null;
  }

  @override
  Future<bool> hasDriveAccess() async {
    accessChecks++;
    return false;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    if (signInError case final e?) throw e;
    return null;
  }

  @override
  Future<List<DriveBackupInfo>> listBackups() async {
    if (listError case final e?) throw e;
    return [];
  }
}

/// Everything Settings' Drive and Downloads sections show: Auto Backup on
/// (as a backup restored from an Android phone may leave it), paused by a
/// failure, a download folder, a last backup.
const _prefs = <String, Object>{
  'autoBackup': true,
  'autoBackupError':
      'Google Drive access was revoked. Sign in again to resume automatic '
      'backups.',
  'downloadDirectory': '/storage/emulated/0/Download/Micro Seller',
  'lastBackupTime': '2026-10-19T12:30:00.000',
};

/// Each Drive error, the key of the words Settings shows for it, and whether
/// it is a failed sign-in (which on iOS adds the sideloading hint).
const _driveErrors = [
  (DriveErrorCode.notSignedIn, 'driveErrorNotSignedIn', false),
  (DriveErrorCode.signInCancelled, 'driveErrorSignInCancelled', false),
  (DriveErrorCode.signInFailed, 'driveErrorSignInFailed', true),
  (DriveErrorCode.developerError, 'driveErrorNotConfigured', true),
  (DriveErrorCode.network, 'driveErrorNetwork', false),
  (DriveErrorCode.uploadFailed, 'driveErrorUploadFailed', false),
  (DriveErrorCode.downloadFailed, 'driveErrorDownloadFailed', false),
  (DriveErrorCode.invalidBackup, 'driveErrorInvalidBackup', false),
  (DriveErrorCode.rolledBack, 'driveErrorRolledBack', false),
  (DriveErrorCode.restoreFailed, 'driveErrorRestoreFailed', false),
  (DriveErrorCode.unknown, 'errorOccurred', false),
];

/// Pumps Settings beside the sidebar rail, [width] dp wide and tall enough to
/// build the whole list at once, with [drive] standing in for Google Drive,
/// in [locale] (English when null). Returns a context under it.
Future<BuildContext> _pumpSettings(
  WidgetTester tester,
  _FakeDrive drive, {
  double width = 411,
  double textScale = 1,
  Locale? locale,
}) async {
  SharedPreferences.setMockInitialValues(_prefs);
  setLayoutScreen(tester, width, height: 6000);
  addTearDown(tester.view.reset);
  await pumpLayoutApp(
    tester,
    SettingsScreen(driveService: drive),
    textScale: textScale,
    locale: locale,
  );
  // The saved settings and the version load asynchronously.
  await tester.pumpAndSettle();
  return tester.element(find.byType(SettingsScreen));
}

/// The text of the snackbar on screen.
String _snackBarText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
    )
    .data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google Sign-In', () {
    late _FakeGoogleSignIn google;

    setUp(() {
      google = _FakeGoogleSignIn();
      GoogleSignInPlatform.instance = google;
      DriveService.resetForTesting();
    });

    tearDown(() {
      DriveService.resetForTesting();
      dotenv.clean();
    });

    test('Info.plist names the iOS client and registers its URL scheme', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final clientId = RegExp(
        r'<key>GIDClientID</key>\s*<string>([^<]*)</string>',
      ).firstMatch(plist)?.group(1)?.trim();
      // Read by Google Sign-In, as the app passes no client id.
      expect(clientId, _iosClientId);
      // Sign-in returns to the app through the client id reversed. Without
      // that URL scheme Google Sign-In raises a native exception, which
      // closes the app.
      final schemes = [
        for (final array in RegExp(
          r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>',
          dotAll: true,
        ).allMatches(plist))
          for (final scheme in RegExp(
            r'<string>([^<]*)</string>',
          ).allMatches(array.group(1)!))
            scheme.group(1)!.trim(),
      ];
      final reversed =
          'com.googleusercontent.apps.'
          '${_iosClientId.replaceFirst('.apps.googleusercontent.com', '')}';
      expect(schemes, contains(reversed));
    });

    test('is set up with no client id, and .env\'s web client as the server '
        'client when it names one', () async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final (env, serverClientId) in [
          (null, null), // no .env
          ('GOOGLE_OAUTH_WEB_CLIENT_ID=', null),
          ('GOOGLE_OAUTH_WEB_CLIENT_ID=   ', null),
          ('GOOGLE_OAUTH_WEB_CLIENT_ID=$_webClientId', _webClientId),
        ]) {
          final where = '${platform.name}, .env: $env';
          _runAs(platform);
          dotenv.clean();
          if (env != null) dotenv.loadFromString(envString: env);
          DriveService.resetForTesting();
          google.inits.clear();

          await DriveService().hasDriveAccess();
          final init = google.inits.single;
          // iOS: GIDClientID from Info.plist. Android: found by package name
          // and signing certificate.
          expect(init.clientId, isNull, reason: where);
          // Never an empty string.
          expect(init.serverClientId, serverClientId, reason: where);
        }
      }
    });

    test('on iOS, Sign in grants Drive access, which the silent checks then '
        'find without UI', () async {
      _runAs(TargetPlatform.iOS);
      final service = DriveService();
      expect(await service.hasDriveAccess(), isFalse);

      final account = await service.signIn();
      expect(account?.email, 'seller@example.com');
      expect(google.authentications.single.scopeHint, [
        drive.DriveApi.driveAppdataScope,
      ]);
      // Drive access granted in the same go, where UI may show.
      expect(google.authorizations.last.promptIfUnauthorized, isTrue);
      expect(google.authorizations.last.scopes, [
        drive.DriveApi.driveAppdataScope,
      ]);

      // What Back up, Restore and the account row ask: no UI.
      expect(await service.hasDriveAccess(), isTrue);
      expect(google.authorizations.last.promptIfUnauthorized, isFalse);
      expect((await service.getCurrentUser())?.email, 'seller@example.com');
    });

    test('on iOS, a sign-in Google refuses is an error to show, and a '
        'cancel is none', () async {
      _runAs(TargetPlatform.iOS);
      for (final (code, expected) in [
        // A keychain error is one: sideloaded installs can hit it.
        (
          GoogleSignInExceptionCode.providerConfigurationError,
          DriveErrorCode.developerError,
        ),
        (
          GoogleSignInExceptionCode.clientConfigurationError,
          DriveErrorCode.developerError,
        ),
        (GoogleSignInExceptionCode.unknownError, DriveErrorCode.signInFailed),
        (GoogleSignInExceptionCode.interrupted, DriveErrorCode.signInFailed),
      ]) {
        google.authenticateError = GoogleSignInException(code: code);
        await expectLater(
          DriveService().signIn(),
          throwsA(
            isA<DriveBackupException>().having((e) => e.code, 'code', expected),
          ),
          reason: code.name,
        );
      }
      google.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
      expect(await DriveService().signIn(), isNull);
    });
  });

  group('Auto Backup', () {
    test('is offered everywhere but iOS', () {
      for (final platform in TargetPlatform.values) {
        _runAs(platform);
        expect(
          AutoBackupRunner.isSupported,
          platform != TargetPlatform.iOS,
          reason: platform.name,
        );
      }
    });

    /// How many times a due auto backup (on, never run) asked Drive whether
    /// it may run at app start, on [platform].
    Future<int> driveChecks(TargetPlatform platform) async {
      _runAs(platform);
      SharedPreferences.setMockInitialValues({'autoBackup': true});
      final drive = _FakeDrive();
      final runner = Provider(
        (ref) => AutoBackupRunner(ref, driveService: () => drive),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(settingsProvider);
      await pumpEventQueue();
      expect(container.read(settingsProvider.notifier).autoBackup, isTrue);
      await container.read(runner).runIfDue();
      return drive.accessChecks;
    }

    test('at app start, does nothing on iOS, even when turned on', () async {
      expect(await driveChecks(TargetPlatform.iOS), 0);
    });

    test('at app start, asks Drive elsewhere, as before', () async {
      expect(await driveChecks(TargetPlatform.android), 1);
    });
  });

  group('Settings', () {
    setUpAll(() {
      PackageInfo.setMockInitialValues(
        appName: 'Micro Seller',
        packageName: 'com.blackshadowsoftware.microseller',
        version: '1.0.10',
        buildNumber: '18',
        buildSignature: '',
      );
    });

    setUp(() {
      // Both Security rows shown, as by default.
      dotenv.loadFromString(
        envString: 'ENABLE_FINGERPRINT_GATE=true\nENABLE_PIN_GATE=true',
      );
    });

    tearDown(dotenv.clean);

    testWidgets('on iOS: Drive backup, without Auto Backup or a download '
        'folder', (tester) async {
      final drive = _FakeDrive();
      final s = AppStrings.of(await _pumpSettings(tester, drive));
      expect(tester.takeException(), isNull);

      // Google Drive (its header in capitals): the account (looked up),
      // Back up, Restore.
      expect(find.text(s.googleDriveBackup.toUpperCase()), findsOneWidget);
      expect(find.text(s.googleAccount), findsOneWidget);
      expect(find.widgetWithText(TextButton, s.signIn), findsOneWidget);
      expect(find.text(s.backupToDrive), findsOneWidget);
      expect(find.text(s.restoreFromDrive), findsOneWidget);
      expect(drive.accountChecks, 1);

      // No Auto Backup: neither its switch nor its paused banner.
      expect(find.text(s.tr('autoBackup')), findsNothing);
      expect(find.text(s.tr('autoBackupPaused')), findsNothing);
      // Download PDF asks where to save each time: no folder to set.
      expect(find.text(s.downloads.toUpperCase()), findsNothing);
      expect(find.text(s.pdfDownloadFolder), findsNothing);
      // Local Backup is there as everywhere.
      expect(find.text(s.exportBackup), findsOneWidget);
      expect(find.text(s.importBackup), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('on Android: unchanged', (tester) async {
      final drive = _FakeDrive();
      final s = AppStrings.of(await _pumpSettings(tester, drive));
      expect(tester.takeException(), isNull);

      expect(find.text(s.googleDriveBackup.toUpperCase()), findsOneWidget);
      expect(find.text(s.backupToDrive), findsOneWidget);
      expect(find.text(s.restoreFromDrive), findsOneWidget);
      expect(find.text(s.tr('autoBackup')), findsOneWidget);
      expect(find.text(s.tr('autoBackupPaused')), findsOneWidget);
      expect(find.text(s.pdfDownloadFolder), findsOneWidget);
      expect(find.text(_prefs['downloadDirectory']! as String), findsOneWidget);
      expect(drive.accountChecks, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('on iOS, a failed Google sign-in adds the sideloading hint', (
      tester,
    ) async {
      final drive = _FakeDrive()
        ..signInError = DriveBackupException(
          DriveErrorCode.signInFailed,
          'Sign-in failed. Please try again.',
        );
      final s = AppStrings.of(await _pumpSettings(tester, drive));
      final hint = s.googleSignInSideloadHint(AppStrings.appName);
      expect(hint, contains('Micro Seller'));

      await tester.tap(find.widgetWithText(TextButton, s.signIn));
      await tester.pump();
      expect(_snackBarText(tester), '${s.driveErrorSignInFailed}\n$hint');
      // Long enough to read both.
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(seconds: 8),
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(SettingsScreen)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();

      // Restore signs in too, when needed: the same hint.
      drive.listError = DriveBackupException(
        DriveErrorCode.developerError,
        'Sign-in is not configured correctly.',
      );
      await tester.tap(find.text(s.restoreFromDrive));
      await tester.pump();
      expect(_snackBarText(tester), endsWith('\n$hint'));
      ScaffoldMessenger.of(
        tester.element(find.byType(SettingsScreen)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();

      // Not for a failure that isn't the sign-in's.
      drive.listError = DriveBackupException(
        DriveErrorCode.network,
        'No connection.',
      );
      await tester.tap(find.text(s.restoreFromDrive));
      await tester.pump();
      expect(_snackBarText(tester), s.driveErrorNetwork);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('on Android, a failed Google sign-in shows the error alone', (
      tester,
    ) async {
      final drive = _FakeDrive()
        ..signInError = DriveBackupException(
          DriveErrorCode.developerError,
          'Sign-in is not configured correctly.',
        );
      final s = AppStrings.of(await _pumpSettings(tester, drive));

      await tester.tap(find.widgetWithText(TextButton, s.signIn));
      await tester.pump();
      expect(_snackBarText(tester), s.driveErrorNotConfigured);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('on iOS, every Drive error is in the app\'s language', (
      tester,
    ) async {
      // Every error has its words.
      expect({for (final (code, _, _) in _driveErrors) code}, {
        ...DriveErrorCode.values,
      });
      // Bengali: English words would stand out.
      const bengali = Locale('bn');
      final drive = _FakeDrive();
      final s = AppStrings.of(
        await _pumpSettings(tester, drive, locale: bengali),
      );
      final hint = s.googleSignInSideloadHint(AppStrings.appName);
      for (final (code, key, signIn) in _driveErrors) {
        // The exception's own message is detail for the log, in English.
        drive.listError = DriveBackupException(code, 'Detail for the log.');
        await tester.tap(find.text(s.restoreFromDrive));
        await tester.pump();
        expect(
          _snackBarText(tester),
          signIn ? '${s.tr(key)}\n$hint' : s.tr(key),
          reason: code.name,
        );
        ScaffoldMessenger.of(
          tester.element(find.byType(SettingsScreen)),
        ).removeCurrentSnackBar();
        await tester.pumpAndSettle();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('on iOS, a failed Google sign-in reads in every app language, '
        'the hint too', (tester) async {
      final english = AppLocalizations(const Locale('en'));
      for (final locale in AppLocalizations.supportedLocales) {
        final lang = locale.languageCode;
        final drive = _FakeDrive()
          ..signInError = DriveBackupException(
            DriveErrorCode.signInFailed,
            'Sign-in failed. Please try again.',
          );
        final s = AppStrings.of(
          await _pumpSettings(tester, drive, locale: locale),
        );
        if (lang != 'en') {
          // Each language has its own words for every Drive error and the
          // hint, not English's.
          for (final key in [
            for (final (_, key, _) in _driveErrors) key,
            'googleSignInSideloadHint',
          ]) {
            expect(s.tr(key), isNot(english.tr(key)), reason: '$lang: $key');
          }
        }

        await tester.tap(find.widgetWithText(TextButton, s.signIn));
        await tester.pump();
        expect(
          _snackBarText(tester),
          '${s.driveErrorSignInFailed}\n'
          '${s.googleSignInSideloadHint(AppStrings.appName)}',
          reason: lang,
        );
        // A fresh Settings for the next language.
        await tester.pumpWidget(const SizedBox());
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('on iOS, lays out at every size, the hint included', (
      tester,
    ) async {
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = '${width.toInt()} dp at ${t}x';
          final drive = _FakeDrive()
            ..signInError = DriveBackupException(
              DriveErrorCode.signInFailed,
              'Sign-in failed. Please try again.',
            );
          final s = AppStrings.of(
            await _pumpSettings(tester, drive, width: width, textScale: t),
          );
          expectCleanLayout(tester, where);
          await tester.tap(find.widgetWithText(TextButton, s.signIn));
          await tester.pumpAndSettle();
          expectCleanLayout(tester, where);
          expectWholeText(
            tester,
            find.descendant(
              of: find.byType(SnackBar),
              matching: find.byType(RichText),
            ),
            where,
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
