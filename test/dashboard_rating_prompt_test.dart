// The Dashboard's rating prompt asks only where the ask can do something:
// a store listing to rate, and on Android Play's own install (Play never
// shows its review sheet to an APK from GitHub). That is checked first,
// before the database is opened to count orders, so the sideloaded iPhone
// app never asks, and never counts.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The platform interface of in_app_review, a dependency of this app's
// dependency: the fake below stands in for the store.
// ignore: depend_on_referenced_packages
import 'package:in_app_review_platform_interface/in_app_review_platform_interface.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/dashboard/presentation/dashboard_screen.dart';
import 'package:micro_seller/shared/widgets/rate_app_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'layout/dashboard_reports_data.dart';
import 'support/layout_harness.dart';

/// The store's review flow, available everywhere: records each call.
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

void main() {
  late InAppReviewPlatform realStore;
  late _FakeStore store;

  setUpAll(() => realStore = InAppReviewPlatform.instance);
  tearDownAll(() => InAppReviewPlatform.instance = realStore);

  setUp(() {
    // The first-run tour is done, so the prompt may ask.
    SharedPreferences.setMockInitialValues({'tour_completed': true});
    store = _FakeStore();
    InAppReviewPlatform.instance = store;
  });

  /// The Dashboard of an install updating through [channel], after the
  /// prompt's checks had their time. Returns how often the prompt opened the
  /// database to count the orders (a database that never finishes opening,
  /// so the prompt stops there).
  Future<int> pumpDashboard(WidgetTester tester, UpdateChannel channel) async {
    var opened = 0;
    setLayoutScreen(tester, 411);
    addTearDown(tester.view.reset);
    await pumpLayoutApp(
      tester,
      const DashboardScreen(),
      overrides: [
        ...dashboardOverrides(stats: typicalDashboardStats(), updates: channel),
        isarProvider.overrideWith((ref) {
          opened++;
          return Completer<Isar>().future;
        }),
      ],
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    return opened;
  }

  testWidgets('the sideloaded iPhone app: no listing, so no prompt, and no '
      'count', (tester) async {
    expect(await pumpDashboard(tester, UpdateChannel.github), 0);
    expect(store.calls, isEmpty);
    expect(find.byType(RateAppDialog), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'Android, an APK from GitHub: no prompt, and no count',
    (tester) async {
      expect(await pumpDashboard(tester, UpdateChannel.github), 0);
      expect(store.calls, isEmpty);
      expect(find.byType(RateAppDialog), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android, from Play: counts the orders, as before',
    (tester) async {
      expect(await pumpDashboard(tester, UpdateChannel.play), 1);
      expect(store.calls, ['isAvailable']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'desktop: no prompt, and no count',
    (tester) async {
      expect(await pumpDashboard(tester, UpdateChannel.none), 0);
      expect(store.calls, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
