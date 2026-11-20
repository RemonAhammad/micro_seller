import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';

import 'support/isar_core.dart';

/// The order detail screen's "Returns against this order" reference:
/// `returnsForOrderProvider(orderId)` must list the returns created against an
/// order, newest first, and nothing for an order with no returns.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(closeTestIsars);

  group('returnsForOrder provider', skip: isarSkipReason, () {
    late Isar isar;
    late OrderNotifier notifier;
    late ProviderContainer container;
    late int customerId;
    late int productId;

    Future<void> shop(String name) async {
      isar = await openTestIsar(name);
      await isar.writeTxn(() async {
        productId = await isar.products.put(
            Product(name: 'Eggs', sellingPrice: 10, costPrice: 6, stockQty: 50));
        customerId = await isar.customers
            .put(Customer(name: 'Rahim', phone: '01700000000'));
      });
      container = ProviderContainer(
          overrides: [isarProvider.overrideWith((ref) async => isar)]);
      addTearDown(container.dispose);
      notifier = container.read(orderProvider.notifier);
    }

    OrderItem eggs(double qty) => OrderItem(
          productId: productId,
          productName: 'Eggs',
          qty: qty,
          unitPrice: 10,
          costPrice: 6,
          totalPrice: 10 * qty,
        );

    Future<Order> sell(String number) async {
      final id = await notifier.createOrder(Order(
        orderNumber: number,
        customerId: customerId,
        customerName: 'Rahim',
        items: [eggs(5)],
        subtotal: 50,
        totalAmount: 50,
        amountPaid: 50,
        paymentStatus: PaymentStatus.paid,
        orderStatus: OrderStatus.confirmed,
        createdAt: DateTime.now(),
      ));
      return (await isar.orders.get(id))!;
    }

    Future<List<Order>> returnsFor(int orderId) {
      final provider = returnsForOrderProvider(orderId);
      // Recompute from current DB state (a stream provider's `.future` caches
      // its first emission), and keep it listened while the stream loads.
      container.invalidate(provider);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      return container.read(provider.future);
    }

    test('lists a return created against the order', () async {
      await shop('ret-ref-one');
      final order = await sell('ORD-001');
      expect(await returnsFor(order.id), isEmpty);

      await notifier.createReturnOrder(
        originalOrder: order,
        returnItems: [eggs(1)],
        reason: ReturnReason.damaged,
        refundAmount: 10,
      );

      final returns = await returnsFor(order.id);
      expect(returns, hasLength(1));
      expect(returns.single.isReturn, isTrue);
      expect(returns.single.originalOrderId, order.id);
      expect(returns.single.orderNumber, startsWith('RET-'));
      expect(returns.single.refundAmount, 10);
    });

    test('newest first, and scoped to the right order', () async {
      await shop('ret-ref-many');
      final a = await sell('ORD-001');
      final b = await sell('ORD-002');

      await notifier.createReturnOrder(
        originalOrder: a,
        returnItems: [eggs(1)],
        reason: ReturnReason.damaged,
        refundAmount: 10,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await notifier.createReturnOrder(
        originalOrder: a,
        returnItems: [eggs(2)],
        reason: ReturnReason.other,
        refundAmount: 20,
      );

      final forA = await returnsFor(a.id);
      expect(forA, hasLength(2));
      expect(forA.first.createdAt!.isAfter(forA.last.createdAt!), isTrue,
          reason: 'newest return first');
      expect(forA.every((r) => r.originalOrderId == a.id), isTrue);

      expect(await returnsFor(b.id), isEmpty,
          reason: 'an order with no returns has none');
    });
  });
}
