// Entries dated when they happened, not when they were typed in: orders,
// payments, Due Book collections, purchases and stock changes, on a real
// Isar database (the core library bundled in isar_community_flutter_libs;
// skipped when it isn't found).
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/data/models/cash_register.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/purchase.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/statement_service.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:micro_seller/features/products/providers/product_provider.dart';
import 'package:micro_seller/features/suppliers/providers/supplier_provider.dart';

import 'support/isar_core.dart';

final _labels = StatementLabels(
  title: 'Statement',
  date: 'Date',
  reference: 'Reference',
  debit: 'Debit',
  credit: 'Credit',
  balance: 'Balance',
  closingBalance: 'Closing balance',
  payment: 'Payment',
  refund: 'Refund',
  generatedOn: (d) => d,
  pageOf: (p, t) => '$p/$t',
);

void main() {
  final coreLibrary = isarCoreLibrary();

  late Directory dir;
  late Isar isar;
  late ProviderContainer container;
  late int customerId;
  late Product product;

  setUpAll(() async {
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
  });

  setUp(() async {
    if (coreLibrary == null) return;
    dir = await Directory.systemTemp.createTemp('micro_seller_dates');
    isar = await Isar.open(kIsarSchemas,
        directory: dir.path, name: 'dates_test', inspector: false);
    container = ProviderContainer(
        overrides: [isarProvider.overrideWith((ref) async => isar)]);
    customerId = await isar.writeTxn(
        () => isar.customers.put(Customer(name: 'Rahim', phone: '01711111111')));
    product = Product(
        name: 'Panjabi', sku: 'PJ-1', sellingPrice: 1000, costPrice: 700, stockQty: 10);
    product.id = await isar.writeTxn(() => isar.products.put(product));
  });

  tearDown(() async {
    if (coreLibrary == null) return;
    container.dispose();
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  OrderNotifier orders() => container.read(orderProvider.notifier);

  Future<Order> sell(DateTime at,
      {double paid = 0, String number = 'ORD-001', int qty = 1}) async {
    final total = product.sellingPrice * qty;
    final order = Order(
      orderNumber: number,
      customerId: customerId,
      customerName: 'Rahim',
      items: [
        OrderItem(
          productId: product.id,
          productName: product.name,
          qty: qty,
          unitPrice: product.sellingPrice,
          costPrice: product.costPrice,
          totalPrice: total,
        ),
      ],
      subtotal: total,
      totalAmount: total,
      amountPaid: paid,
      paymentStatus: paid >= total
          ? PaymentStatus.paid
          : paid > 0
              ? PaymentStatus.partial
              : PaymentStatus.unpaid,
      orderStatus: OrderStatus.confirmed,
      createdAt: at,
      updatedAt: DateTime.now(),
    );
    final id = await orders().createOrder(order);
    return (await isar.orders.get(id))!;
  }

  Future<List<Payment>> paymentsOf(Order o) =>
      isar.payments.where().orderIdEqualTo(o.id).findAll();

  Future<List<StockMovement>> salesOf(Order o) => isar.stockMovements
      .filter()
      .typeEqualTo(StockMovementType.sale)
      .reasonEqualTo('Order ${o.orderNumber}')
      .findAll();

  final now = DateTime.now();
  final threeDaysAgo = DateTime(now.year, now.month, now.day - 3, 18, 30, 12);

  group('a backdated order', () {
    test('dates its payment and its stock movement at the order date', () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final before = DateTime.now();
      final order = await sell(threeDaysAgo, paid: 1000);

      final payment = (await paymentsOf(order)).single;
      expect(payment.paidAt, threeDaysAgo);
      expect(payment.createdAt!.isBefore(before), isFalse,
          reason: 'createdAt keeps when it was typed in');
      expect((await salesOf(order)).single.createdAt, threeDaysAgo);

      final payments = await isar.payments.where().findAll();
      final monthStart = DateTime(now.year, now.month);
      expect(
          duesCollectedBetween(payments, {order.id: order}, monthStart,
              DateTime(now.year, now.month + 1)),
          0,
          reason: 'paid at the sale, not a due collected later');
    });

    test('an order dated now still logs its payment at the order time',
        () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final at = DateTime.now();
      final order = await sell(at, paid: 400);
      expect((await paymentsOf(order)).single.paidAt, at);
    });
  });

  group('editing an order\'s date', () {
    test('moves the payment made with the sale and its stock movement',
        () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await sell(threeDaysAgo, paid: 300);
      final earlier = threeDaysAgo.subtract(const Duration(days: 2, hours: 3));

      await orders().updateOrder(order.copyWith(createdAt: earlier));

      expect((await isar.orders.get(order.id))!.createdAt, earlier);
      expect((await paymentsOf(order)).single.paidAt, earlier);
      expect((await salesOf(order)).single.createdAt, earlier);
    });

    test('moves rows an older version stamped moments after the order',
        () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await sell(threeDaysAgo, paid: 300);
      final stamped = threeDaysAgo.add(const Duration(milliseconds: 40));
      await isar.writeTxn(() async {
        final p = (await paymentsOf(order)).single;
        await isar.payments.put(p.copyWith(paidAt: stamped));
        final m = (await salesOf(order)).single;
        await isar.stockMovements.put(m.copyWith(createdAt: stamped));
      });
      final later = threeDaysAgo.add(const Duration(days: 1));

      await orders().updateOrder(order.copyWith(createdAt: later));

      expect((await paymentsOf(order)).single.paidAt, later);
      expect((await salesOf(order)).single.createdAt, later);
    });

    test('leaves later payments and Due Book collections where they are',
        () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await sell(threeDaysAgo, paid: 300);
      final collected = threeDaysAgo.add(const Duration(seconds: 20));
      await orders().collectFromCustomer(customerId, 200, paidAt: collected);
      final paidLater = threeDaysAgo.add(const Duration(days: 1));
      await orders().recordPayment(order.id, 100, paidAt: paidLater);
      final earlier = threeDaysAgo.subtract(const Duration(days: 1));

      await orders().updateOrder(
          (await isar.orders.get(order.id))!.copyWith(createdAt: earlier));

      final byAmount = {
        for (final p in await paymentsOf(order)) p.amount: p.paidAt,
      };
      expect(byAmount, {300.0: earlier, 200.0: collected, 100.0: paidLater});
    });

    test('is refused past a later payment, and nothing changes', () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await sell(threeDaysAgo, paid: 300);
      final paidLater = threeDaysAgo.add(const Duration(days: 1));
      await orders().recordPayment(order.id, 100, paidAt: paidLater);
      final stored = (await isar.orders.get(order.id))!;

      await expectLater(
        orders().updateOrder(
            stored.copyWith(createdAt: paidLater.add(const Duration(hours: 1)))),
        throwsA(isA<OrderDateTooLate>()
            .having((e) => e.latest, 'latest', paidLater)),
      );

      expect((await isar.orders.get(order.id))!.createdAt, threeDaysAgo);
      expect((await paymentsOf(order)).map((p) => p.paidAt),
          containsAll([threeDaysAgo, paidLater]));
      expect((await salesOf(order)).single.createdAt, threeDaysAgo);
    });

    test('is refused past the delivery', () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await sell(threeDaysAgo);
      final delivered = threeDaysAgo.add(const Duration(hours: 5));
      await orders().updateOrder(order.copyWith(actualDeliveryDate: delivered));
      await expectLater(
        orders().updateOrder((await isar.orders.get(order.id))!
            .copyWith(createdAt: delivered.add(const Duration(minutes: 5)))),
        throwsA(isA<OrderDateTooLate>()
            .having((e) => e.latest, 'latest', delivered)),
      );
    });

    test('is refused past a return', () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await sell(threeDaysAgo);
      await orders().createReturnOrder(
        originalOrder: order,
        returnItems: order.items,
        reason: ReturnReason.defective,
        refundAmount: 0,
      );
      final returned = (await isar.orders
              .filter()
              .isReturnEqualTo(true)
              .findFirst())!
          .createdAt!;
      await expectLater(
        orders().updateOrder((await isar.orders.get(order.id))!
            .copyWith(createdAt: returned.add(const Duration(seconds: 1)))),
        throwsA(isA<OrderDateTooLate>()
            .having((e) => e.latest, 'latest', returned)),
      );
    });

    test('leaves a payment recorded after the sale on an unpaid order',
        () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await sell(threeDaysAgo);
      final soon = threeDaysAgo.add(const Duration(seconds: 2));
      await orders().recordPayment(order.id, 100, paidAt: soon);

      await orders().updateOrder((await isar.orders.get(order.id))!
          .copyWith(createdAt: threeDaysAgo.subtract(const Duration(days: 1))));

      expect((await paymentsOf(order)).single.paidAt, soon);
    });

    test('an unchanged date touches nothing else', () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await sell(threeDaysAgo, paid: 300);
      await orders().updateOrder(order.copyWith(notes: 'gift wrap'));
      expect((await paymentsOf(order)).single.paidAt, threeDaysAgo);
      expect((await isar.orders.get(order.id))!.notes, 'gift wrap');
    });
  });

  group('a status changed by editing the order', () {
    Future<Order> pending() async {
      final order = await sell(threeDaysAgo);
      await orders().updateStatus(order.id, OrderStatus.pending);
      return (await isar.orders.get(order.id))!;
    }

    Future<int> stock() async => (await isar.products.get(product.id))!.stockQty;

    test('moves stock in the same save', () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await pending();
      expect(await stock(), 10);

      await orders().updateOrder(order.copyWith(
          orderStatus: OrderStatus.confirmed, notes: 'confirmed by phone'));

      final saved = (await isar.orders.get(order.id))!;
      expect(saved.orderStatus, OrderStatus.confirmed);
      expect(saved.notes, 'confirmed by phone');
      expect(await stock(), 9);
    });

    test('Mark as delivered takes a pending order\'s items out of stock',
        () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await pending();
      await orders().updateOrder(order.copyWith(
          orderStatus: OrderStatus.completed,
          actualDeliveryDate: DateTime.now()));
      expect(await stock(), 9);
      expect((await isar.orders.get(order.id))!.orderStatus,
          OrderStatus.completed);
    });
  });

  group('payments with a date', () {
    test('Record Payment logs the chosen date', () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final order = await sell(threeDaysAgo);
      final at = threeDaysAgo.add(const Duration(days: 1));
      await orders().recordPayment(order.id, 250, paidAt: at);
      expect((await paymentsOf(order)).single.paidAt, at);
      expect((await isar.orders.get(order.id))!.amountPaid, 250);
    });

    test('a backdated collection pays only the orders that existed then',
        () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      final old = await sell(threeDaysAgo, number: 'ORD-001');
      final recent = await sell(threeDaysAgo.add(const Duration(days: 2)),
          number: 'ORD-002');
      final at = threeDaysAgo.add(const Duration(days: 1));

      final applied =
          await orders().collectFromCustomer(customerId, 2000, paidAt: at);

      expect(applied, 1000, reason: 'capped at what was due on that date');
      expect((await isar.orders.get(old.id))!.amountPaid, 1000);
      expect((await isar.orders.get(recent.id))!.amountPaid, 0);
      expect((await paymentsOf(old)).single.paidAt, at);
    });

    test('goes into the cash register only from when it opened', () async {
      if (coreLibrary == null) return markTestSkipped('Isar core not found');
      await sell(threeDaysAgo, number: 'ORD-001');
      final openedAt = DateTime.now().subtract(const Duration(hours: 2));
      final registerId = await isar.writeTxn(() => isar.cashRegisters
          .put(CashRegister(openingAmount: 500, openedAt: openedAt)));

      await orders().collectFromCustomer(customerId, 100,
          registerId: registerId,
          paidAt: openedAt.subtract(const Duration(days: 1)));
      expect((await isar.cashRegisters.get(registerId))!.totalCashIn, 0);

      await orders()
          .collectFromCustomer(customerId, 100, registerId: registerId);
      expect((await isar.cashRegisters.get(registerId))!.totalCashIn, 100);
    });

    test('CashRegister.takesCashAt', () {
      final opened = DateTime(2026, 11, 2, 9);
      final register = CashRegister(openedAt: opened);
      expect(register.takesCashAt(null), isTrue);
      expect(register.takesCashAt(opened), isTrue);
      expect(register.takesCashAt(opened.subtract(const Duration(minutes: 1))),
          isFalse);
      expect(CashRegister().takesCashAt(opened), isTrue);
    });
  });

  test('a purchase and its restock are dated when the stock arrived',
      () async {
    if (coreLibrary == null) return markTestSkipped('Isar core not found');
    await container.read(supplierProvider.notifier).createPurchase(Purchase(
          items: [
            PurchaseItem(
                productId: product.id,
                productName: product.name,
                qty: 5,
                unitCost: 650,
                totalCost: 3250),
          ],
          totalAmount: 3250,
          createdAt: threeDaysAgo,
        ));
    expect((await isar.purchases.where().findFirst())!.createdAt, threeDaysAgo);
    final restock = await isar.stockMovements
        .filter()
        .typeEqualTo(StockMovementType.restock)
        .findFirst();
    expect(restock!.createdAt, threeDaysAgo);
  });

  test('a stock change is dated when it happened', () async {
    if (coreLibrary == null) return markTestSkipped('Isar core not found');
    await container.read(productProvider.notifier).adjustStock(
        product.id, -2, 'Damaged in the rain', StockMovementType.damage,
        at: threeDaysAgo);
    final movement = (await isar.stockMovements.where().findFirst())!;
    expect(movement.createdAt, threeDaysAgo);
    expect((await isar.products.get(product.id))!.stockQty, 8);
  });

  group('equal dates', () {
    Order order(int id, DateTime at, {double paid = 0}) => Order(
          id: id,
          orderNumber: 'ORD-$id',
          customerId: 1,
          items: const [],
          totalAmount: 100,
          amountPaid: paid,
          createdAt: at,
        );

    test('the oldest-first dues order breaks a tie by id', () {
      final at = DateTime(2026, 10, 1, 12);
      final orders = [
        for (var id = 40; id >= 1; id--) order(id, at),
      ];
      expect(computeOrderDues(orders).map((d) => d.order.id),
          [for (var id = 1; id <= 40; id++) id]);
    });

    test('the statement shows the sale before the payment made with it', () {
      final at = DateTime(2026, 10, 1, 12);
      final sale = order(7, at, paid: 100);
      final payment = Payment(
          customerId: 1, orderId: 7, amount: 100, paidAt: at, createdAt: at);
      final rows = StatementService()
          .buildRows([sale], [payment], labels: _labels);
      expect(rows.map((r) => r.debit), [100, 0]);
      expect(rows.map((r) => r.balance), [100, 0]);
    });

    test('duesOpenAt keeps the orders created on or before the date', () {
      final at = DateTime(2026, 10, 2);
      final dues = computeOrderDues([
        order(1, DateTime(2026, 10, 1)),
        order(2, at),
        order(3, DateTime(2026, 10, 3)),
      ]);
      expect(duesOpenAt(dues, at).map((d) => d.order.id), [1, 2]);
      expect(duesOpenAt(dues, null), same(dues));
    });
  });
}
