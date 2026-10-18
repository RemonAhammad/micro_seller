import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/services/review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Order _o({bool isReturn = false, OrderStatus status = OrderStatus.completed}) =>
    Order(isReturn: isReturn, orderStatus: status);

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
}
