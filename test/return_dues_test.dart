import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';

import 'support/isar_core.dart';

/// Issue #11: a return pays off the order's due once its goods are
/// received; only what's left of its value can go back as cash.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(closeTestIsars);

  group('returns and dues', skip: isarSkipReason, () {
    late Isar isar;
    late OrderNotifier notifier;
    late int customerId;
    late int productId;

    Future<void> shop(String name) async {
      isar = await openTestIsar(name);
      await isar.writeTxn(() async {
        productId = await isar.products
            .put(Product(name: 'Eggs', sellingPrice: 10, costPrice: 6, stockQty: 50));
        customerId = await isar.customers.put(Customer(name: 'Rahim', phone: '01700000000'));
      });
      final c = ProviderContainer(overrides: [isarProvider.overrideWith((ref) async => isar)]);
      addTearDown(c.dispose);
      notifier = c.read(orderProvider.notifier);
    }

    OrderItem eggs(double qty) => OrderItem(
          productId: productId,
          productName: 'Eggs',
          qty: qty,
          unitPrice: 10,
          costPrice: 6,
          totalPrice: 10 * qty,
        );

    Future<Order> sell({required double paid}) async {
      final id = await notifier.createOrder(Order(
        orderNumber: 'ORD-001',
        customerId: customerId,
        customerName: 'Rahim',
        items: [eggs(5)],
        subtotal: 50,
        totalAmount: 50,
        amountPaid: paid,
        paymentStatus: paid >= 50
            ? PaymentStatus.paid
            : paid > 0
                ? PaymentStatus.partial
                : PaymentStatus.unpaid,
        orderStatus: OrderStatus.confirmed,
        createdAt: DateTime.now(),
      ));
      return (await isar.orders.get(id))!;
    }

    /// Returns [qty] eggs asking for [refund], approves, refunds.
    Future<Order> returnEggs(Order original, double qty, {double refund = 0}) async {
      await notifier.createReturnOrder(
        originalOrder: original,
        returnItems: [eggs(qty)],
        reason: ReturnReason.damaged,
        refundAmount: refund,
      );
      final ret = (await isar.orders.filter().isReturnEqualTo(true).findFirst())!;
      await notifier.approveReturn(ret.id);
      return ret;
    }

    Future<double> due() async =>
        computeNetDue(await isar.orders.filter().customerIdEqualTo(customerId).findAll());
    Future<double> counter() async => (await isar.customers.get(customerId))!.outstandingBalance;
    Future<double> stock() async => (await isar.products.get(productId))!.stockQty;

    test('owes 25, returns 1 egg: owes 15 on receipt, no cash can go back', () async {
      await shop('ret-owes');
      final ret = await returnEggs(await sell(paid: 25), 1, refund: 10);
      expect(await stock(), 46);
      expect(await due(), 15);
      expect(await counter(), 15);

      await notifier.processRefund(ret.id);
      final r = (await isar.orders.get(ret.id))!;
      expect(r.refundAmount, 0, reason: 'the 10 paid off the due');
      expect((await isar.orders.get(ret.originalOrderId))!.amountPaid, 25);
      expect(await due(), 15);
      expect(await counter(), 15);
    });

    test('owes 5, returns 1 egg: 5 pays the due, 5 back in cash', () async {
      await shop('ret-split');
      final ret = await returnEggs(await sell(paid: 45), 1, refund: 10);
      expect(await due(), 0);
      await notifier.processRefund(ret.id);
      expect((await isar.orders.get(ret.id))!.refundAmount, 5);
      expect(await due(), 0);
      expect(await counter(), 0);
    });

    test('paid in full, returns 1 egg: 10 back in cash', () async {
      await shop('ret-paid');
      final ret = await returnEggs(await sell(paid: 50), 1, refund: 10);
      await notifier.processRefund(ret.id);
      expect((await isar.orders.get(ret.id))!.refundAmount, 10);
      expect(await due(), 0);
      expect(await counter(), 0);
    });

    test('paid 30, 1 egg returned: 10 left, paying it marks the order paid', () async {
      await shop('ret-status');
      final original = await sell(paid: 30);
      final ret = await returnEggs(original, 1);
      await notifier.processRefund(ret.id);
      expect(await due(), 10);
      expect((await isar.orders.get(original.id))!.paymentStatus, PaymentStatus.partial);

      await notifier.recordPayment(original.id, 10);
      final o = (await isar.orders.get(original.id))!;
      expect(o.paymentStatus, PaymentStatus.paid);
      expect(await due(), 0);
    });

    test('a return that clears the rest of the due marks the order paid', () async {
      await shop('ret-clears');
      final original = await sell(paid: 40);
      await returnEggs(original, 1);
      expect((await isar.orders.get(original.id))!.paymentStatus, PaymentStatus.paid);
    });

    test('a received return can no longer be rejected', () async {
      await shop('ret-reject');
      final ret = await returnEggs(await sell(paid: 0), 1);
      await notifier.rejectReturn(ret.id);
      expect((await isar.orders.get(ret.id))!.returnStatus, ReturnStatus.received);
      expect(await due(), 40);
    });
  });
}
