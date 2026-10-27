// Settings → About offers "Rate this app" only where the app has a store
// listing to rate: on Android (Google Play), not on the sideloaded iPhone app
// (no App Store listing yet) nor on desktop. A Play install gets Play's
// review sheet; an APK from GitHub gets the Play listing, since Play shows
// its sheet to Play installs only. "Check for updates" (update_notice_test)
// sits between it and the version.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
// The platform interface of in_app_review, a dependency of this app's
// dependency: the fake below stands in for the store.
// ignore: depend_on_referenced_packages
import 'package:in_app_review_platform_interface/in_app_review_platform_interface.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/data/services/drive_service.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/updates/providers/update_notice_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/layout_harness.dart';

/// The store's review flow: records each call.
class _FakeStore extends InAppReviewPlatform {
  final calls = <String>[];

  @override
  Future<bool> isAvailable() async {
    calls.add('isAvailable');
    return true;
  }

  @override
  Future<void> requestReview() async => calls.add('requestReview');

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async => calls.add('openStoreListing($appStoreId)');
}

/// Drive, signed out, without Google.
class _FakeDrive extends DriveService {
  @override
  Future<GoogleSignInAccount?> getCurrentUser() async => null;
}

/// Settings of an install updating through [channel]. Returns a context in
/// it.
Future<BuildContext> _pumpSettings(
  WidgetTester tester,
  UpdateChannel channel,
) async {
  setLayoutScreen(tester, 411, height: 6000);
  addTearDown(tester.view.reset);
  await pumpLayoutApp(
    tester,
    SettingsScreen(driveService: _FakeDrive()),
    overrides: [
      updateChannelProvider.overrideWithValue(AsyncValue.data(channel)),
    ],
  );
  await tester.pumpAndSettle();
  return tester.element(find.byType(SettingsScreen));
}

/// The About card's rows, top to bottom, by their titles.
List<String> _aboutRows(WidgetTester tester, BuildContext context) {
  final s = AppStrings.of(context);
  final rows = [
    for (final title in [s.rateThisApp, s.checkForUpdates, s.appVersion])
      if (find.text(title).evaluate().isNotEmpty)
        (title, tester.getRect(find.text(title)).top),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (title, _) in rows) title];
}

void main() {
  late InAppReviewPlatform realStore;
  late _FakeStore store;

  setUpAll(() {
    realStore = InAppReviewPlatform.instance;
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=false\nENABLE_PIN_GATE=false',
    );
    PackageInfo.setMockInitialValues(
      appName: 'Micro Seller',
      packageName: 'com.blackshadowsoftware.micro_seller',
      version: '1.0.11',
      buildNumber: '19',
      buildSignature: '',
    );
  });

  tearDownAll(() {
    InAppReviewPlatform.instance = realStore;
    dotenv.clean();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _FakeStore();
    InAppReviewPlatform.instance = store;
  });

  testWidgets(
    'Android, from Play: Rate opens Play\'s review sheet',
    (tester) async {
      final context = await _pumpSettings(tester, UpdateChannel.play);
      final s = AppStrings.of(context);
      expect(_aboutRows(tester, context), [s.rateThisApp, s.appVersion]);
      await tester.tap(find.text(s.rateThisApp));
      await tester.pumpAndSettle();
      expect(store.calls, ['isAvailable', 'requestReview']);
      // Never asked again on the Dashboard.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('review_prompt_done'), isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android, an APK from GitHub: Rate opens the Play listing',
    (tester) async {
      final context = await _pumpSettings(tester, UpdateChannel.github);
      final s = AppStrings.of(context);
      expect(_aboutRows(tester, context), [
        s.rateThisApp,
        s.checkForUpdates,
        s.appVersion,
      ]);
      await tester.tap(find.text(s.rateThisApp));
      await tester.pumpAndSettle();
      expect(store.calls, ['openStoreListing(null)']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'the iPhone app, sideloaded: no App Store listing to rate',
    (tester) async {
      final context = await _pumpSettings(tester, UpdateChannel.github);
      final s = AppStrings.of(context);
      expect(find.text(s.rateThisApp), findsNothing);
      expect(_aboutRows(tester, context), [s.checkForUpdates, s.appVersion]);
      expect(store.calls, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'desktop: nothing to rate, nothing to check',
    (tester) async {
      final context = await _pumpSettings(tester, UpdateChannel.none);
      final s = AppStrings.of(context);
      expect(_aboutRows(tester, context), [s.appVersion]);
      // The version, still in its card.
      expect(find.text('1.0.11 (19)'), findsOneWidget);
      expect(store.calls, isEmpty);
    },
    variant: TargetPlatformVariant.desktop(),
  );
}
