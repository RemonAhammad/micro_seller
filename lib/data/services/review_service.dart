import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_distribution.dart';
import '../models/order.dart';
import 'release_update_service.dart';

class ReviewService {
  static const String _doneKey = 'review_prompt_done';
  static const String _snoozeUntilKey = 'review_prompt_snooze_until';
  static const String _askCountKey = 'review_prompt_ask_count';

  static const int minOrders = 5;
  static const int maxAsks = 3;
  static const Duration snoozeDuration = Duration(days: 30);

  static bool meetsOrderThreshold(Iterable<Order> orders,
      {int threshold = minOrders}) {
    var count = 0;
    for (final o in orders) {
      if (o.isReturn || o.orderStatus == OrderStatus.cancelled) continue;
      if (++count >= threshold) return true;
    }
    return false;
  }

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

  static Future<bool> isEligible(Isar isar) async {
    final prefs = await SharedPreferences.getInstance();

    if (!eligibilityFromPrefs(prefs, orderCount: minOrders)) return false;
    final orderCount = await isar.orders
        .filter()
        .isReturnEqualTo(false)
        .not()
        .orderStatusEqualTo(OrderStatus.cancelled)
        .count();
    return eligibilityFromPrefs(prefs, orderCount: orderCount);
  }

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

  static Future<void> markRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
  }

  static Future<void> markDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
  }

  static Future<void> markSnoozed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_askCountKey, (prefs.getInt(_askCountKey) ?? 0) + 1);
    await prefs.setInt(
      _snoozeUntilKey,
      DateTime.now().add(snoozeDuration).millisecondsSinceEpoch,
    );
  }

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

  static Future<void> openReviewPage({
    String? appStoreId = AppDistribution.appStoreId,
  }) async {
    if (!hasStoreListing(appStoreId: appStoreId)) return;
    try {
      await InAppReview.instance.openStoreListing(appStoreId: appStoreId);
    } catch (e) {
      debugPrint('[ReviewService] Opening the store page failed: $e');
    }
  }
}
