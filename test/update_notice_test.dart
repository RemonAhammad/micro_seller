// The update notice of installs no store updates. The iPhone app and
// Android APKs from GitHub hear of a newer GitHub release from a Dashboard
// banner that says how to install it over this install, so the data stays.
// Download opens the release's page; ✕ hides that version until a newer one
// comes out. Settings → Check for updates asks GitHub now and says what it
// found. A Play install keeps Play's own update: no banner, no request, no
// row.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/data/services/drive_service.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/dashboard/presentation/dashboard_screen.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/updates/presentation/update_notice.dart';
import 'package:micro_seller/features/updates/providers/update_notice_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// url_launcher's platform side, faked below so Download's real launchUrl
// runs without a device. A dependency of url_launcher, not of the app.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'layout/dashboard_reports_data.dart';
import 'support/layout_harness.dart';

/// The installed version: the release GitHub offers is newer.
const _installed = '1.0.11';

/// A release's page on GitHub.
String _page(String tag) =>
    'https://github.com/RemonAhammad/micro_seller/releases/tag/$tag';

/// GitHub's API without a network. It answers its latest release, [tag],
/// carrying the iPhone's and Android's files; [status] instead when that
/// isn't 200; [error] thrown instead (no connection). Until [hold]
/// completes, it holds its answer. It counts the requests.
class _GitHub {
  String tag = 'v1.0.12';
  int status = 200;
  Object? error;
  Completer<void>? hold;
  int requests = 0;

  late final client = MockClient((request) async {
    requests++;
    await hold?.future;
    if (error case final e?) throw e;
    if (status != 200) {
      return http.Response('{"message": "Server Error"}', status);
    }
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'tag_name': tag,
          'draft': false,
          'prerelease': false,
          'html_url': _page(tag),
          'assets': [
            {'name': 'micro-seller-$tag-universal.apk'},
            {'name': 'micro-seller-$tag-arm64-v8a.apk'},
            {'name': 'micro-seller-$tag-unsigned.ipa'},
          ],
        }),
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// url_launcher without a device: records what it was asked to open, and
/// answers [opens].
class _FakeLauncher extends UrlLauncherPlatform {
  final launched = <(String, PreferredLaunchMode)>[];
  bool opens = true;

  @override
  get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url, options.mode));
    return opens;
  }
}

/// Drive, signed out, without Google.
class _FakeDrive extends DriveService {
  @override
  Future<GoogleSignInAccount?> getCurrentUser() async => null;
}

/// The GitHub check of this install, asking [github], with the device's
/// (mocked) SharedPreferences and the clock [now].
Future<ReleaseUpdateService> _service(
  _GitHub github, {
  DateTime Function() now = DateTime.now,
}) async => ReleaseUpdateService(
  client: github.client,
  prefs: await SharedPreferences.getInstance(),
  installedVersion: _installed,
  platform: defaultTargetPlatform,
  now: now,
);

/// The Dashboard of an install updating through [channel], with [service]
/// standing in for the GitHub check (the real one when null). Returns a
/// context in it.
Future<BuildContext> _pumpDashboard(
  WidgetTester tester, {
  required UpdateChannel channel,
  ReleaseUpdateService? service,
}) async {
  setLayoutScreen(tester, 411, height: 1600);
  addTearDown(tester.view.reset);
  await pumpLayoutApp(
    tester,
    const DashboardScreen(),
    overrides: [
      ...dashboardOverrides(
        stats: typicalDashboardStats(),
        dues: typicalDues(),
        updates: channel,
      ),
      if (service != null)
        releaseUpdateServiceProvider.overrideWithValue(
          AsyncValue.data(service),
        ),
    ],
  );
  await tester.pumpAndSettle();
  return tester.element(find.byType(DashboardScreen));
}

/// Settings of an install updating through [channel], with [service]
/// standing in for the GitHub check (the real one when null). Returns a
/// context in it.
Future<BuildContext> _pumpSettings(
  WidgetTester tester, {
  required UpdateChannel channel,
  ReleaseUpdateService? service,
}) async {
  setLayoutScreen(tester, 411, height: 6000);
  addTearDown(tester.view.reset);
  await pumpLayoutApp(
    tester,
    SettingsScreen(driveService: _FakeDrive()),
    overrides: [
      updateChannelProvider.overrideWithValue(AsyncValue.data(channel)),
      if (service != null)
        releaseUpdateServiceProvider.overrideWithValue(
          AsyncValue.data(service),
        ),
    ],
  );
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
  late UrlLauncherPlatform realLauncher;
  late _FakeLauncher launcher;
  late _GitHub github;

  setUpAll(() {
    realLauncher = UrlLauncherPlatform.instance;
    // Settings' Security rows read .env; they don't matter here.
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=false\nENABLE_PIN_GATE=false',
    );
    PackageInfo.setMockInitialValues(
      appName: 'Micro Seller',
      packageName: 'com.blackshadowsoftware.microseller',
      version: _installed,
      buildNumber: '19',
      buildSignature: '',
    );
  });

  tearDownAll(() {
    UrlLauncherPlatform.instance = realLauncher;
    dotenv.clean();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
    github = _GitHub();
  });

  group('the Dashboard banner', () {
    testWidgets(
      'on an iPhone: the release, and how to install it there',
      (tester) async {
        final s = AppStrings.of(
          await _pumpDashboard(
            tester,
            channel: UpdateChannel.github,
            service: await _service(github),
          ),
        );
        final banner = find.byType(UpdateNoticeBanner);
        expect(banner, findsOneWidget);
        expect(
          find.descendant(
            of: banner,
            matching: find.text(s.updateAvailable('1.0.12')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: banner, matching: find.text(s.updateHowToIos)),
          findsOneWidget,
        );
        expect(find.text(s.updateHowToAndroid), findsNothing);
        expect(
          find.descendant(
            of: banner,
            matching: find.widgetWithText(FilledButton, s.download),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: banner, matching: find.byTooltip(s.dismiss)),
          findsOneWidget,
        );
        // After the 60+ days banner, with the same margins.
        final overdue = tester.getRect(find.textContaining('60+ days'));
        final notice = tester.getRect(banner);
        expect(notice.top, greaterThan(overdue.bottom));
        expect(notice.left, 56 + 16.0);
        expect(notice.right, 411 - 16.0);
        expect(github.requests, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'on Android, from a GitHub APK: how to install the APK',
      (tester) async {
        final s = AppStrings.of(
          await _pumpDashboard(
            tester,
            channel: UpdateChannel.github,
            service: await _service(github),
          ),
        );
        final banner = find.byType(UpdateNoticeBanner);
        expect(
          find.descendant(
            of: banner,
            matching: find.text(s.updateAvailable('1.0.12')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: banner,
            matching: find.text(s.updateHowToAndroid),
          ),
          findsOneWidget,
        );
        expect(find.text(s.updateHowToIos), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('no newer release: no banner', (tester) async {
      github.tag = 'v$_installed';
      await _pumpDashboard(
        tester,
        channel: UpdateChannel.github,
        service: await _service(github),
      );
      expect(find.byType(UpdateNoticeBanner), findsNothing);
      expect(github.requests, 1);
    });

    testWidgets('Download opens the release page in the browser', (
      tester,
    ) async {
      final s = AppStrings.of(
        await _pumpDashboard(
          tester,
          channel: UpdateChannel.github,
          service: await _service(github),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, s.download));
      await tester.pumpAndSettle();
      expect(launcher.launched, [
        (_page('v1.0.12'), PreferredLaunchMode.externalApplication),
      ]);
      // Still there: the seller may come back to it.
      expect(find.byType(UpdateNoticeBanner), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // No browser to open it: says so.
      launcher.opens = false;
      await tester.tap(find.widgetWithText(FilledButton, s.download));
      await tester.pump();
      expect(_snackBarText(tester), s.errorOccurred);
    });

    testWidgets('✕ hides that version for good, but not a newer one', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 27, 9);
      final s = AppStrings.of(
        await _pumpDashboard(
          tester,
          channel: UpdateChannel.github,
          service: await _service(github, now: () => now),
        ),
      );
      await tester.tap(find.byTooltip(s.dismiss));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateNoticeBanner), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('update_notice_snoozed_tag'), 'v1.0.12');

      // The app opened again, the next day: GitHub still has 1.0.12.
      await tester.pumpWidget(const SizedBox());
      now = now.add(const Duration(days: 1, hours: 1));
      await _pumpDashboard(
        tester,
        channel: UpdateChannel.github,
        service: await _service(github, now: () => now),
      );
      expect(github.requests, 2);
      expect(find.byType(UpdateNoticeBanner), findsNothing);

      // A day later, 1.0.13 is out.
      await tester.pumpWidget(const SizedBox());
      github.tag = 'v1.0.13';
      now = now.add(const Duration(days: 1, hours: 1));
      await _pumpDashboard(
        tester,
        channel: UpdateChannel.github,
        service: await _service(github, now: () => now),
      );
      expect(github.requests, 3);
      expect(find.byType(UpdateNoticeBanner), findsOneWidget);
      expect(find.textContaining('1.0.13'), findsOneWidget);
    });

    testWidgets('remembers the release offline, and asks at most once a day', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 27, 9);
      await _pumpDashboard(
        tester,
        channel: UpdateChannel.github,
        service: await _service(github, now: () => now),
      );
      expect(github.requests, 1);

      // Opened again an hour later, offline: shown, and GitHub not asked.
      await tester.pumpWidget(const SizedBox());
      github.error = const SocketException('Network is unreachable');
      now = now.add(const Duration(hours: 1));
      await _pumpDashboard(
        tester,
        channel: UpdateChannel.github,
        service: await _service(github, now: () => now),
      );
      expect(github.requests, 1);
      expect(find.byType(UpdateNoticeBanner), findsOneWidget);

      // A day later, still offline: asked, failed silently, still shown.
      await tester.pumpWidget(const SizedBox());
      now = now.add(const Duration(days: 1));
      await _pumpDashboard(
        tester,
        channel: UpdateChannel.github,
        service: await _service(github, now: () => now),
      );
      expect(github.requests, 2);
      expect(find.byType(UpdateNoticeBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final channel in [UpdateChannel.play, UpdateChannel.none]) {
      testWidgets('a ${channel.name} install: no banner, no request', (
        tester,
      ) async {
        // The real GitHub check: it isn't set up for this install at all.
        await _pumpDashboard(tester, channel: channel);
        expect(find.byType(UpdateNoticeBanner), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DashboardScreen)),
        );
        expect(
          await container.read(releaseUpdateServiceProvider.future),
          isNull,
        );
        expect(await container.read(updateNoticeProvider.future), isNull);
        // Every request is stamped: none was made.
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where((k) => k.startsWith('update_notice')),
          isEmpty,
        );
      });
    }
  });

  group('Settings → Check for updates', () {
    for (final channel in UpdateChannel.values) {
      final shown = channel == UpdateChannel.github;
      testWidgets('${shown ? 'is' : 'is not'} offered on a ${channel.name} '
          'install', (tester) async {
        final s = AppStrings.of(
          await _pumpSettings(
            tester,
            channel: channel,
            service: shown ? await _service(github) : null,
          ),
        );
        expect(
          find.text(s.checkForUpdates),
          shown ? findsOneWidget : findsNothing,
        );
        // Opening Settings never asks GitHub.
        expect(github.requests, 0);
      });
    }

    testWidgets(
      'a newer release: the dialog, whose Download opens its page',
      (tester) async {
        final s = AppStrings.of(
          await _pumpSettings(
            tester,
            channel: UpdateChannel.github,
            service: await _service(github),
          ),
        );
        await tester.tap(find.text(s.checkForUpdates));
        await tester.pumpAndSettle();
        expect(github.requests, 1);
        final dialog = find.byType(UpdateNoticeDialog);
        expect(dialog, findsOneWidget);
        for (final text in [s.updateAvailable('1.0.12'), s.updateHowToIos]) {
          expect(
            find.descendant(of: dialog, matching: find.text(text)),
            findsOneWidget,
          );
        }

        // Close: nothing opened.
        await tester.tap(find.widgetWithText(OutlinedButton, s.close));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(launcher.launched, isEmpty);

        // Again, even right after: the manual check ignores the daily limit.
        await tester.tap(find.text(s.checkForUpdates));
        await tester.pumpAndSettle();
        expect(github.requests, 2);
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, s.download),
          ),
        );
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(launcher.launched, [
          (_page('v1.0.12'), PreferredLaunchMode.externalApplication),
        ]);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'a dismissed release is still offered',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('update_notice_snoozed_tag', 'v1.0.12');
        final s = AppStrings.of(
          await _pumpSettings(
            tester,
            channel: UpdateChannel.github,
            service: await _service(github),
          ),
        );
        await tester.tap(find.text(s.checkForUpdates));
        await tester.pumpAndSettle();
        expect(find.byType(UpdateNoticeDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(UpdateNoticeDialog),
            matching: find.text(s.updateHowToAndroid),
          ),
          findsOneWidget,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('the latest version installed: says so', (tester) async {
      github.tag = 'v$_installed';
      final s = AppStrings.of(
        await _pumpSettings(
          tester,
          channel: UpdateChannel.github,
          service: await _service(github),
        ),
      );
      await tester.tap(find.text(s.checkForUpdates));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateNoticeDialog), findsNothing);
      expect(_snackBarText(tester), s.upToDate);
    });

    for (final (name, fail) in <(String, void Function(_GitHub))>[
      ('a server error', (g) => g.status = 500),
      ('the rate limit', (g) => g.status = 403),
      ('no connection', (g) => g.error = const SocketException('Offline')),
    ]) {
      testWidgets('GitHub unreachable ($name): says so', (tester) async {
        fail(github);
        final s = AppStrings.of(
          await _pumpSettings(
            tester,
            channel: UpdateChannel.github,
            service: await _service(github),
          ),
        );
        await tester.tap(find.text(s.checkForUpdates));
        await tester.pumpAndSettle();
        expect(github.requests, 1);
        expect(find.byType(UpdateNoticeDialog), findsNothing);
        expect(_snackBarText(tester), s.updateCheckFailed);
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
          Colors.red,
        );
      });
    }

    testWidgets('while it asks: a spinner, and taps are ignored', (
      tester,
    ) async {
      github.hold = Completer<void>();
      final s = AppStrings.of(
        await _pumpSettings(
          tester,
          channel: UpdateChannel.github,
          service: await _service(github),
        ),
      );
      final row = find.widgetWithText(ListTile, s.checkForUpdates);
      final spinner = find.descendant(
        of: row,
        matching: find.byType(CircularProgressIndicator),
      );
      expect(spinner, findsNothing);
      await tester.tap(row);
      await tester.pump();
      expect(spinner, findsOneWidget);
      await tester.tap(row);
      await tester.pump();
      expect(github.requests, 1);

      github.hold!.complete();
      await tester.pumpAndSettle();
      expect(spinner, findsNothing);
      expect(find.byType(UpdateNoticeDialog), findsOneWidget);
      expect(github.requests, 1);
    });

    testWidgets('brings the Dashboard notice up to date', (tester) async {
      final s = AppStrings.of(
        await _pumpSettings(
          tester,
          channel: UpdateChannel.github,
          service: await _service(github),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      await tester.tap(find.text(s.checkForUpdates));
      await tester.pumpAndSettle();
      expect(
        container.read(updateNoticeProvider).value,
        AvailableUpdate(tag: 'v1.0.12', url: Uri.parse(_page('v1.0.12'))),
      );
    });
  });
}
