import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// The platform interface of in_app_review, a dependency of this app's
// dependency: the fake below stands in for the store.
// ignore: depend_on_referenced_packages
import 'package:in_app_review_platform_interface/in_app_review_platform_interface.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/data/services/review_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _o({bool isReturn = false, OrderStatus status = OrderStatus.completed}) =>
    Order(isReturn: isReturn, orderStatus: status);

/// The store's review flow: records each call, and fails with [error].
class _FakeStore extends InAppReviewPlatform {
  /// What `isAvailable` answers.
  bool available = true;

  /// What every call throws, when set.
  Object? error;

  final calls = <String>[];

  void _call(String name) {
    calls.add(name);
    if (error case final e?) throw e;
  }

  @override
  Future<bool> isAvailable() async {
    _call('isAvailable');
    return available;
  }

  @override
  Future<void> requestReview() async => _call('requestReview');

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async =>
      _call('openStoreListing($appStoreId)');
}

void main() {
  group('meetsOrderThreshold', () {
    test('true at exactly 5 real orders', () {
      expect(ReviewService.meetsOrderThreshold(List.generate(4, (_) => _o())), isFalse);
      expect(ReviewService.meetsOrderThreshold(List.generate(5, (_) => _o())), isTrue);
    });

    test('returns and cancelled orders do not count', () {
      final orders = [
        ...List.generate(4, (_) => _o()),
        _o(isReturn: true),
        _o(status: OrderStatus.cancelled),
      ];
      expect(ReviewService.meetsOrderThreshold(orders), isFalse);
    });
  });

  group('back-off', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('eligible with enough orders and no history', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(ReviewService.eligibilityFromPrefs(prefs, orderCount: 5), isTrue);
      expect(ReviewService.eligibilityFromPrefs(prefs, orderCount: 4), isFalse);
    });

    test('Later snoozes ~30 days and counts the ask', () async {
      await ReviewService.markSnoozed();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('review_prompt_ask_count'), 1);
      expect(ReviewService.eligibilityFromPrefs(prefs, orderCount: 50), isFalse);
      final in31Days = DateTime.now().add(const Duration(days: 31));
      expect(
          ReviewService.eligibilityFromPrefs(prefs, orderCount: 50, now: in31Days),
          isTrue);
    });

    test('stops after 3 asks even when the snooze has passed', () async {
      for (var i = 0; i < ReviewService.maxAsks; i++) {
        await ReviewService.markSnoozed();
      }
      final prefs = await SharedPreferences.getInstance();
      final later = DateTime.now().add(const Duration(days: 365));
      expect(ReviewService.eligibilityFromPrefs(prefs, orderCount: 50, now: later),
          isFalse);
    });

    test('declining or rating ends it for good', () async {
      await ReviewService.markDeclined();
      var prefs = await SharedPreferences.getInstance();
      expect(ReviewService.eligibilityFromPrefs(prefs, orderCount: 50), isFalse);

      SharedPreferences.setMockInitialValues({});
      await ReviewService.markRated();
      prefs = await SharedPreferences.getInstance();
      expect(ReviewService.eligibilityFromPrefs(prefs, orderCount: 50), isFalse);
    });
  });

  // Where the app can be rated, and what each platform's ask does. The
  // sideloaded iPhone app has no App Store listing; an APK from GitHub never
  // gets Play's review sheet.
  group('store listing and the ask', () {
    const appStoreId = '1234567890';
    late _FakeStore store;
    late InAppReviewPlatform original;

    setUp(() {
      original = InAppReviewPlatform.instance;
      store = _FakeStore();
      InAppReviewPlatform.instance = store;
    });

    tearDown(() {
      InAppReviewPlatform.instance = original;
      debugDefaultTargetPlatformOverride = null;
    });

    void installedFrom(String? installer) => PackageInfo.setMockInitialValues(
          appName: 'Micro Seller',
          packageName: 'com.blackshadowsoftware.micro_seller',
          version: '1.0.11',
          buildNumber: '19',
          buildSignature: '',
          installerStore: installer,
        );

    test('iOS without an App Store id: no listing, no prompt, no calls',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(ReviewService.hasStoreListing(), isFalse);
      expect(await ReviewService.canPrompt(), isFalse);
      await ReviewService.requestReview();
      expect(store.calls, isEmpty);
    });

    test('iOS with an App Store id: Rate opens its listing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(ReviewService.hasStoreListing(appStoreId: appStoreId), isTrue);
      expect(await ReviewService.canPrompt(appStoreId: appStoreId), isTrue);
      store.calls.clear();
      await ReviewService.requestReview(appStoreId: appStoreId);
      expect(store.calls, ['openStoreListing($appStoreId)']);
    });

    test('Android from Play: the review sheet, as before', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(ReviewService.hasStoreListing(), isTrue);
      expect(await ReviewService.canPrompt(channel: UpdateChannel.play),
          isTrue);
      store.available = false;
      expect(await ReviewService.canPrompt(channel: UpdateChannel.play),
          isFalse);

      store
        ..available = true
        ..calls.clear();
      await ReviewService.requestReview(channel: UpdateChannel.play);
      expect(store.calls, ['isAvailable', 'requestReview']);

      store
        ..available = false
        ..calls.clear();
      await ReviewService.requestReview(channel: UpdateChannel.play);
      expect(store.calls, ['isAvailable', 'openStoreListing(null)']);
    });

    test('Android from Play: failures are swallowed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      store.error = Exception('Play Store missing');
      expect(await ReviewService.canPrompt(channel: UpdateChannel.play),
          isFalse);
      await ReviewService.requestReview(channel: UpdateChannel.play);
      expect(store.calls, ['isAvailable', 'isAvailable']);
    });

    test('Android from GitHub: no prompt; Rate opens the Play listing',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(ReviewService.hasStoreListing(), isTrue);
      expect(await ReviewService.canPrompt(channel: UpdateChannel.github),
          isFalse);
      expect(store.calls, isEmpty);
      await ReviewService.requestReview(channel: UpdateChannel.github);
      expect(store.calls, ['openStoreListing(null)']);
    });

    test('Android without a channel reads it from the installer', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      installedFrom('com.android.vending');
      expect(await ReviewService.canPrompt(), isTrue);
      installedFrom(null);
      expect(await ReviewService.canPrompt(), isFalse);
      store.calls.clear();
      await ReviewService.requestReview();
      expect(store.calls, ['openStoreListing(null)']);
    });

    test('desktop: no listing, no prompt, no calls', () async {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(ReviewService.hasStoreListing(appStoreId: appStoreId), isFalse,
            reason: platform.name);
        expect(await ReviewService.canPrompt(appStoreId: appStoreId), isFalse,
            reason: platform.name);
        await ReviewService.requestReview(appStoreId: appStoreId);
      }
      expect(store.calls, isEmpty);
    });
  });
}
