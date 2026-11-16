import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/order.dart';

/// What a new order starts with: the payment method and status the seller
/// used last. Per device and never in a backup (like Display size): it is a
/// typing convenience, not shop data.
class OrderFormDefaults {
  const OrderFormDefaults({
    this.paymentMethod = PaymentMethod.cash,
    this.orderStatus = OrderStatus.confirmed,
  });

  /// Counter sales are handed over at once, so a new order is Confirmed
  /// (stock leaves now) until the seller picks Pending once.
  static const fallback = OrderFormDefaults();

  static const keyPaymentMethod = 'orderLastPaymentMethod';
  static const keyOrderStatus = 'orderLastStatus';

  /// The statuses the order form offers; anything else stored is ignored.
  static const formStatuses = [OrderStatus.pending, OrderStatus.confirmed];

  final PaymentMethod paymentMethod;
  final OrderStatus orderStatus;

  /// Never throws: a missing or foreign value falls back to the default.
  static Future<OrderFormDefaults> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return fromPrefs(prefs);
    } catch (_) {
      return fallback;
    }
  }

  static OrderFormDefaults fromPrefs(SharedPreferences prefs) {
    final method = prefs.get(keyPaymentMethod);
    final status = prefs.get(keyOrderStatus);
    return OrderFormDefaults(
      paymentMethod: PaymentMethod.values.firstWhere(
        (m) => m.name == method,
        orElse: () => fallback.paymentMethod,
      ),
      orderStatus: formStatuses.firstWhere(
        (s) => s.name == status,
        orElse: () => fallback.orderStatus,
      ),
    );
  }

  /// Remembers a saved new order's choices. Failures are ignored.
  static Future<void> remember({
    required PaymentMethod paymentMethod,
    required OrderStatus orderStatus,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyPaymentMethod, paymentMethod.name);
      if (formStatuses.contains(orderStatus)) {
        await prefs.setString(keyOrderStatus, orderStatus.name);
      }
    } catch (_) {}
  }
}
