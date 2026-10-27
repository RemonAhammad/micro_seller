import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_distribution.dart';
import '../models/order.dart';
import 'release_update_service.dart';

/// Decides when to ask the seller for a store rating, and performs the ask.
/// Ported from the Fuel Cost app's `ReviewService`.
///
/// A seller qualifies once they have [minOrders] real sales orders (returns
/// and cancelled orders don't count) — that's a habit, not a first try.
/// Back-off: "Later" snoozes [snoozeDuration] (at most [maxAsks] times);
/// rating or declining ends it for good.
///
/// The prompt state is a per-device UI preference, like `tour_completed`, so
/// it is deliberately not part of the backup's `exportSettings()`.
class ReviewService {
  static const String _doneKey = 'review_prompt_done';
  static const String _snoozeUntilKey = 'review_prompt_snooze_until';
  static const String _askCountKey = 'review_prompt_ask_count';

  static const int minOrders = 5;
  static const int maxAsks = 3;
  static const Duration snoozeDuration = Duration(days: 30);

  // ─── Eligibility ───

  /// Pure habit rule — no storage calls, so it stays unit-testable.
  static bool meetsOrderThreshold(Iterable<Order> orders,
      {int threshold = minOrders}) {
    var count = 0;
    for (final o in orders) {
      if (o.isReturn || o.orderStatus == OrderStatus.cancelled) continue;
      if (++count >= threshold) return true;
    }
    return false;
  }

  /// Pure back-off rule over the stored prompt state.
  static bool eligibilityFromPrefs(
    SharedPreferences prefs, {
    required int orderCount,
    DateTime? now,
  }) {
    if (prefs.getBool(_doneKey) ?? false) return false;
    if ((prefs.getInt(_askCountKey) ?? 0) >= maxAsks) return false;
    final snoozeUntil = prefs.getInt(_snoozeUntilKey);
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (snoozeUntil != null && nowMs < snoozeUntil) return false;
    return orderCount >= minOrders;
  }

  /// Whether the automatic prompt should be shown right now.
  static Future<bool> isEligible(Isar isar) async {
    final prefs = await SharedPreferences.getInstance();
    // Cheap prefs checks first; only count orders if they pass.
    if (!eligibilityFromPrefs(prefs, orderCount: minOrders)) return false;
    final orderCount = await isar.orders
        .filter()
        .isReturnEqualTo(false)
        .not()
        .orderStatusEqualTo(OrderStatus.cancelled)
        .count();
    return eligibilityFromPrefs(prefs, orderCount: orderCount);
  }

  /// Whether the app has a store listing to rate on this platform: Google
  /// Play on Android; the App Store on iOS once [appStoreId] is set (the
  /// sideloaded iPhone app has none); none on desktop and the web. Settings
  /// shows "Rate this app" only when true.
  static bool hasStoreListing({
    String? appStoreId = AppDistribution.appStoreId,
  }) {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => appStoreId != null,
      _ => false,
    };
  }

  /// Whether the automatic prompt may ask: the app has a listing
  /// ([hasStoreListing]), the review flow is available, and on Android this
  /// is a Play install ([channel]; read from the installer when null), since
  /// Play never shows its sheet to an APK installed from GitHub. Checked
  /// first, so the prompt never asks and then does nothing.
  ///
  /// `InAppReview.isAvailable` alone isn't enough: it is true on iOS 10.3+
  /// whether or not the app is listed.
  static Future<bool> canPrompt({
    String? appStoreId = AppDistribution.appStoreId,
    UpdateChannel? channel,
  }) async {
    if (!hasStoreListing(appStoreId: appStoreId)) return false;
    if (defaultTargetPlatform == TargetPlatform.android &&
        (channel ?? await readUpdateChannel()) != UpdateChannel.play) {
      return false;
    }
    try {
      return await InAppReview.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  // ─── Outcome recording ───

  /// The user went through the rating flow — never ask again.
  static Future<void> markRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
  }

  /// The user opted out — never ask again.
  static Future<void> markDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
  }

  /// The user deferred — back off for [snoozeDuration] and count the ask.
  static Future<void> markSnoozed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_askCountKey, (prefs.getInt(_askCountKey) ?? 0) + 1);
    await prefs.setInt(
      _snoozeUntilKey,
      DateTime.now().add(snoozeDuration).millisecondsSinceEpoch,
    );
  }

  // ─── The ask itself ───

  /// The seller asked to rate (Rate now, or Settings → Rate this app).
  ///
  /// - No listing ([hasStoreListing]): nothing.
  /// - iOS: the App Store listing ([appStoreId]). Apple's own prompt is
  ///   rationed and may show nothing after the seller tapped.
  /// - Android, a Play install ([channel]; read from the installer when
  ///   null): Google Play's review sheet (stars + optional written review),
  ///   falling back to the store listing. Play also enforces an undisclosed
  ///   quota.
  /// - Android, an APK from GitHub: the Play listing, since Play never shows
  ///   its sheet there.
  ///
  /// Failures are logged rather than surfaced.
  static Future<void> requestReview({
    String? appStoreId = AppDistribution.appStoreId,
    UpdateChannel? channel,
  }) async {
    if (!hasStoreListing(appStoreId: appStoreId)) return;
    final inAppReview = InAppReview.instance;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await inAppReview.openStoreListing(appStoreId: appStoreId);
      } else if ((channel ?? await readUpdateChannel()) != UpdateChannel.play) {
        await inAppReview.openStoreListing();
      } else if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        await inAppReview.openStoreListing();
      }
    } catch (e) {
      debugPrint('[ReviewService] In-app review request failed: $e');
    }
  }
}
