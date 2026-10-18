// The order and supplier notifiers batch their per-item reads and writes
// (getAll / putAll) inside each writeTxn. These run every batched write path
// on a real Isar database and check the exact numbers the sequential
// get → put per item produced: base and variant stock, one StockMovement per
// item, Payment rows, customer and supplier stats.
//
// Uses the Isar core library bundled in isar_community_flutter_libs, so it
// runs offline on macOS, Linux and Windows hosts; skipped when not found.
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
import 'package:micro_seller/data/models/supplier.dart';
import 'package:micro_seller/data/models/variant_attribute.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/services/db_worker.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:micro_seller/features/suppliers/providers/supplier_provider.dart';

import 'support/isar_core.dart';

void main() {
  final coreLibrary = isarCoreLibrary();

  late Directory dir;
  late Isar isar;
  late ProviderContainer container;
  late int customerId;
  late int shirtId; // variants Size:M (5) and Size:L (7), base 12
  late int mugId; // plain, 20

  setUpAll(() async {
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dbWorkerCoreLibrary = coreLibrary; // providers load on worker isolates
  });

  setUp(() async {
    if (coreLibrary == null) return;
    dir = await Directory.systemTemp.createTemp('micro_seller_batched');
    isar = await Isar.open(kIsarSchemas,
        directory: dir.path, name: 'batched_writes_test', inspector: false);
    container = ProviderContainer(
        overrides: [isarProvider.overrideWith((ref) async => isar)]);
    await isar.writeTxn(() async {
      customerId =
          await isar.customers.put(Customer(name: 'Rahim', phone: '01711111111'));
      shirtId = await isar.products.put(Product(
        name: 'Shirt',
        sellingPrice: 500,
        costPrice: 300,
        stockQty: 12,
        variantAttributes: [
          VariantAttribute(name: 'Size', options: ['M', 'L']),
        ],
        variantCombinations: [
          VariantCombination(
              combinationKey: 'Size:M', displayLabel: 'Size: M', stockQty: 5),
          VariantCombination(
              combinationKey: 'Size:L', displayLabel: 'Size: L', stockQty: 7),
        ],
      ));
      mugId = await isar.products.put(
          Product(name: 'Mug', sellingPrice: 200, costPrice: 120, stockQty: 20));
    });
  });

  tearDown(() async {
    if (coreLibrary == null) return;
    container.dispose();
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  OrderNotifier orders() => container.read(orderProvider.notifier);
  SupplierNotifier suppliers() => container.read(supplierProvider.notifier);

  // Most notifier methods catch into `state` rather than throw — fail loudly.
  void expectNoErrors() {
    expect(container.read(orderProvider).hasError, isFalse,
        reason: '${container.read(orderProvider).error}');
    expect(container.read(supplierProvider).hasError, isFalse,
        reason: '${container.read(supplierProvider).error}');
  }

  OrderItem shirt(String size, int qty) => OrderItem(
        productId: shirtId,
        productName: 'Shirt',
        qty: qty,
        unitPrice: 500,
        costPrice: 300,
        totalPrice: 500.0 * qty,
        variantCombinationKey: 'Size:$size',
        variantDisplayLabel: 'Size: $size',
      );

  OrderItem mug(int qty) => OrderItem(
        productId: mugId,
        productName: 'Mug',
        qty: qty,
        unitPrice: 200,
        costPrice: 120,
        totalPrice: 200.0 * qty,
      );

  Future<int> placeOrder(
    String number,
    List<OrderItem> items, {
    double paid = 0,
    double? total,
    OrderStatus status = OrderStatus.confirmed,
    DateTime? createdAt,
  }) async {
    final amount = total ?? items.fold<double>(0, (s, i) => s + i.totalPrice);
    final id = await orders().createOrder(Order(
      orderNumber: number,
      customerId: customerId,
      customerName: 'Rahim',
      items: items,
      subtotal: amount,
      totalAmount: amount,
      amountPaid: paid,
      paymentStatus: paid >= amount
          ? PaymentStatus.paid
          : paid > 0
              ? PaymentStatus.partial
              : PaymentStatus.unpaid,
      orderStatus: status,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: createdAt ?? DateTime.now(),
    ));
    expectNoErrors();
    return id;
  }

  /// (shirt base, shirt M, shirt L, mug)
  Future<(int, int, int, int)> stock() async {
    final s = (await isar.products.get(shirtId))!;
    final m = (await isar.products.get(mugId))!;
    return (
      s.stockQty,
      s.findCombination('Size:M')!.stockQty,
      s.findCombination('Size:L')!.stockQty,
      m.stockQty,
    );
  }

  Future<List<(int, int, StockMovementType, String)>> movements() async =>
      [
        for (final m in await isar.stockMovements.where().findAll())
          (m.productId, m.qty, m.type, m.reason),
      ];

  Future<(int, double, double)> customerStats() async {
    final c = (await isar.customers.get(customerId))!;
    return (c.totalOrders, c.totalSpent, c.outstandingBalance);
  }

  Future<List<Payment>> payments() => isar.payments.where().findAll();

  group('batched writes on a real database',
      skip: coreLibrary == null ? 'Isar core library not found' : false, () {
    test('confirmed order: two variants of one product and a plain item',
        () async {
      final id = await placeOrder(
          'ORD-T1', [shirt('M', 2), shirt('L', 3), mug(4)],
          paid: 1000); // total 3300

      expect(await stock(), (7, 3, 4, 16));
      expect(await movements(), [
        (shirtId, -2, StockMovementType.sale, 'Order ORD-T1'),
        (shirtId, -3, StockMovementType.sale, 'Order ORD-T1'),
        (mugId, -4, StockMovementType.sale, 'Order ORD-T1'),
      ]);
      final logged = await payments();
      expect(logged, hasLength(1));
      expect(logged.single.amount, 1000);
      expect(logged.single.orderId, id);
      expect(logged.single.customerId, customerId);
      expect(await customerStats(), (1, 3300.0, 2300.0));
    });

    test('an item whose product is gone is skipped, movement included',
        () async {
      await placeOrder('ORD-T1', [
        mug(1),
        OrderItem(productId: 99999, productName: 'Ghost', qty: 3, totalPrice: 30),
      ]);
      expect((await stock()).$4, 19);
      expect(await movements(),
          [(mugId, -1, StockMovementType.sale, 'Order ORD-T1')]);
      expect(await isar.products.get(99999), isNull);
    });

    test('rollback to pending restores exactly; re-confirming deducts again',
        () async {
      final id = await placeOrder(
          'ORD-T1', [shirt('M', 2), shirt('L', 3), mug(4)],
          paid: 1000);

      await orders().updateStatus(id, OrderStatus.pending);
      expectNoErrors();
      expect(await stock(), (12, 5, 7, 20));
      const rollback = 'Rollback ORD-T1 → pending';
      expect((await movements()).skip(3), [
        (shirtId, 2, StockMovementType.adjustment, rollback),
        (shirtId, 3, StockMovementType.adjustment, rollback),
        (mugId, 4, StockMovementType.adjustment, rollback),
      ]);
      expect(await customerStats(), (1, 3300.0, 2300.0));
      expect(await payments(), hasLength(1));

      await orders().updateStatus(id, OrderStatus.confirmed);
      expectNoErrors();
      expect(await stock(), (7, 3, 4, 16));
      expect((await movements()).skip(6), [
        (shirtId, -2, StockMovementType.sale, 'Order ORD-T1'),
        (shirtId, -3, StockMovementType.sale, 'Order ORD-T1'),
        (mugId, -4, StockMovementType.sale, 'Order ORD-T1'),
      ]);
    });

    test('cancel restores stock, reverses customer stats and the payment',
        () async {
      final id = await placeOrder(
          'ORD-T1', [shirt('M', 2), shirt('L', 3), mug(4)],
          paid: 1000);

      await orders().updateStatus(id, OrderStatus.cancelled);
      expectNoErrors();
      expect(await stock(), (12, 5, 7, 20));
      const rollback = 'Rollback ORD-T1 → cancelled';
      expect((await movements()).skip(3), [
        (shirtId, 2, StockMovementType.adjustment, rollback),
        (shirtId, 3, StockMovementType.adjustment, rollback),
        (mugId, 4, StockMovementType.adjustment, rollback),
      ]);
      expect(await customerStats(), (0, 0.0, 0.0));
      final logged = await payments();
      expect(logged.map((p) => p.amount), [1000, -1000]);
      expect(logged.last.note, kCancelledPaymentNote);
      expect(logged.last.orderId, id);
      final order = (await isar.orders.get(id))!;
      expect(order.orderStatus, OrderStatus.cancelled);
      expect(order.amountPaid, 0);
      expect(order.paymentStatus, PaymentStatus.unpaid);
    });

    test('delete restores stock and customer stats, drops its payments',
        () async {
      final id = await placeOrder(
          'ORD-T1', [shirt('M', 2), shirt('L', 3), mug(4)],
          paid: 1000);
      final keep = await placeOrder('ORD-T2', [mug(1)],
          paid: 200, status: OrderStatus.pending); // no stock moved

      await orders().deleteOrder(id);
      expectNoErrors();
      expect(await stock(), (12, 5, 7, 20));
      const reason = 'Deleted order ORD-T1';
      expect((await movements()).skip(3), [
        (shirtId, 2, StockMovementType.adjustment, reason),
        (shirtId, 3, StockMovementType.adjustment, reason),
        (mugId, 4, StockMovementType.adjustment, reason),
      ]);
      expect(await customerStats(), (1, 200.0, 0.0));
      final logged = await payments();
      expect(logged.map((p) => (p.orderId, p.amount)), [(keep, 200)]);
      expect(await isar.orders.get(id), isNull);
    });

    test('return: approve restores stock, refund logs the negative payment',
        () async {
      final saleId =
          await placeOrder('ORD-T1', [shirt('M', 2), mug(1)], paid: 1200);
      expect(await stock(), (10, 3, 7, 19));

      final sale = (await isar.orders.get(saleId))!;
      final returned = [
        sale.items.first.copyWith(qty: 1, totalPrice: 500),
        sale.items.last,
      ];
      final value = returnValueFor(sale, returned);
      expect(value.total, 700);
      await orders().createReturnOrder(
        originalOrder: sale,
        returnItems: returned,
        reason: ReturnReason.changedMind,
        refundAmount: value.total,
      );
      expectNoErrors();
      final ret =
          (await isar.orders.filter().isReturnEqualTo(true).findAll()).single;
      expect(ret.totalAmount, 700);
      expect(ret.returnStatus, ReturnStatus.requested);
      expect((await isar.orders.get(saleId))!.returnStatus,
          ReturnStatus.requested);
      expect(await stock(), (10, 3, 7, 19)); // not until received

      await orders().approveReturn(ret.id);
      expectNoErrors();
      expect(await stock(), (11, 4, 7, 20));
      final reason = 'Return ${ret.orderNumber}';
      expect((await movements()).skip(2), [
        (shirtId, 1, StockMovementType.restock, reason),
        (mugId, 1, StockMovementType.restock, reason),
      ]);
      expect((await isar.orders.get(saleId))!.returnStatus,
          ReturnStatus.received);

      await orders().processRefund(ret.id, refundMethod: PaymentMethod.mfs);
      expectNoErrors();
      final refunded = (await isar.orders.get(ret.id))!;
      expect(refunded.refundAmount, 700);
      expect(refunded.amountPaid, 700);
      expect(refunded.returnStatus, ReturnStatus.refunded);
      expect(refunded.orderStatus, OrderStatus.completed);
      expect(refunded.paymentMethod, PaymentMethod.mfs);
      final original = (await isar.orders.get(saleId))!;
      expect(original.amountPaid, 500);
      expect(original.paymentStatus, PaymentStatus.partial);
      expect(original.returnStatus, ReturnStatus.refunded);

      final logged = await payments();
      expect(logged.map((p) => (p.orderId, p.amount)),
          [(saleId, 1200), (saleId, -700)]);
      expect(logged.last.note, 'refund ${ret.orderNumber}');
      expect(logged.last.method, PaymentMethod.mfs);
      expect(await customerStats(), (1, 500.0, 0.0));
      expect(
          computeNetDue(await isar.orders
              .filter()
              .customerIdEqualTo(customerId)
              .findAll()),
          0);
    });

    test('collectFromCustomer pays oldest first across several orders',
        () async {
      final now = DateTime.now();
      final o1 = await placeOrder('ORD-T1', [],
          total: 1000, status: OrderStatus.pending,
          createdAt: now.subtract(const Duration(days: 3)));
      final o2 = await placeOrder('ORD-T2', [],
          total: 500, paid: 100, status: OrderStatus.pending,
          createdAt: now.subtract(const Duration(days: 2)));
      final o3 = await placeOrder('ORD-T3', [],
          total: 800, status: OrderStatus.pending,
          createdAt: now.subtract(const Duration(days: 1)));
      expect(await customerStats(), (3, 2300.0, 2200.0));
      final registerId = await isar.writeTxn(() => isar.cashRegisters
          .put(CashRegister(openingAmount: 100, openedAt: now)));

      final applied = await orders().collectFromCustomer(customerId, 1700,
          method: PaymentMethod.mfs,
          transactionId: 'TX-9',
          note: 'baki',
          registerId: registerId);
      expectNoErrors();
      expect(applied, 1700);

      final (p1, p2, p3) = (
        (await isar.orders.get(o1))!,
        (await isar.orders.get(o2))!,
        (await isar.orders.get(o3))!,
      );
      expect((p1.amountPaid, p1.paymentStatus), (1000, PaymentStatus.paid));
      expect((p2.amountPaid, p2.paymentStatus), (500, PaymentStatus.paid));
      expect((p3.amountPaid, p3.paymentStatus), (300, PaymentStatus.partial));
      expect([p1, p2, p3].map((o) => (o.paymentMethod, o.transactionId)),
          everyElement((PaymentMethod.mfs, 'TX-9')));

      final logged = await payments();
      expect(logged.map((p) => (p.orderId, p.amount)),
          [(o2, 100), (o1, 1000), (o2, 400), (o3, 300)]);
      final collected = logged.skip(1).toList();
      expect(collected.map((p) => p.groupId).toSet(), hasLength(1));
      expect(collected.first.groupId, startsWith('col-'));
      expect(
          collected.map((p) => (p.method, p.transactionId, p.note, p.customerId)),
          everyElement((PaymentMethod.mfs, 'TX-9', 'baki', customerId)));
      expect(await customerStats(), (3, 2300.0, 500.0));
      expect((await isar.cashRegisters.get(registerId))!.totalCashIn, 1700);

      // Capped at what's still owed.
      expect(await orders().collectFromCustomer(customerId, 1000), 500);
      expectNoErrors();
      expect((await isar.orders.get(o3))!.paymentStatus, PaymentStatus.paid);
      expect(await customerStats(), (3, 2300.0, 0.0));
      expect((await payments()).map((p) => p.amount),
          [100, 1000, 400, 300, 500]);
    });

    test('recurring: every due copy in one go, numbered and billed in order',
        () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      late int a, b, c;
      await isar.writeTxn(() async {
        Order recurring(String n, double total, DateTime next) => Order(
              orderNumber: n,
              customerId: customerId,
              customerName: 'Rahim',
              totalAmount: total,
              orderStatus: OrderStatus.completed,
              isRecurring: true,
              recurringIntervalDays: 7,
              nextRecurringDate: next,
              createdAt: now.subtract(const Duration(days: 8)),
            );
        a = await isar.orders.put(recurring('ORD-001', 300, yesterday));
        b = await isar.orders.put(recurring('ORD-002', 200, yesterday));
        c = await isar.orders.put(
            recurring('ORD-003', 999, now.add(const Duration(days: 1))));
      });

      await orders().processRecurringOrders();
      expectNoErrors();

      final all = await isar.orders.where().findAll();
      expect(all, hasLength(5));
      final copies = all.where((o) => o.id != a && o.id != b && o.id != c);
      expect(copies.map((o) => (o.orderNumber, o.totalAmount)),
          [('ORD-004', 300), ('ORD-005', 200)]);
      for (final o in copies) {
        expect(o.orderStatus, OrderStatus.pending);
        expect(o.paymentStatus, PaymentStatus.unpaid);
        expect(o.amountPaid, 0);
        expect(o.nextRecurringDate!.isAfter(now), isTrue);
      }
      expect((await isar.orders.get(a))!.nextRecurringDate!.isAfter(now),
          isTrue);
      expect((await isar.orders.get(b))!.nextRecurringDate!.isAfter(now),
          isTrue);
      expect((await isar.orders.get(c))!.updatedAt, isNull); // not due
      expect(await customerStats(), (2, 500.0, 500.0));

      // Nothing due any more: a second run writes nothing.
      await orders().processRecurringOrders();
      expect(await isar.orders.count(), 5);
    });

    test('purchase create + delete: stock, cost price and supplier stats',
        () async {
      final supplierId =
          await isar.writeTxn(() => isar.suppliers.put(Supplier(name: 'Karim')));
      // Mug twice (stock adds up, the last cost wins), a line with no
      // product (skipped) and one with qty 0 (skipped).
      final purchase = Purchase(
        supplierId: supplierId,
        supplierName: 'Karim',
        items: [
          PurchaseItem(productId: mugId, productName: 'Mug', qty: 10, unitCost: 90),
          PurchaseItem(productId: shirtId, productName: 'Shirt', qty: 4, unitCost: 310),
          PurchaseItem(productId: 0, productName: 'Loose', qty: 3, unitCost: 5),
          PurchaseItem(productId: mugId, productName: 'Mug', qty: 2, unitCost: 95),
          PurchaseItem(productId: shirtId, productName: 'Shirt', qty: 0, unitCost: 1),
        ],
        totalAmount: 2330,
        amountPaid: 2000,
      );
      await suppliers().createPurchase(purchase);
      expectNoErrors();

      final mugAfter = (await isar.products.get(mugId))!;
      final shirtAfter = (await isar.products.get(shirtId))!;
      expect((mugAfter.stockQty, mugAfter.costPrice), (32, 95));
      expect((shirtAfter.stockQty, shirtAfter.costPrice), (16, 310));
      const from = 'Purchase from Karim';
      expect(await movements(), [
        (mugId, 10, StockMovementType.restock, from),
        (shirtId, 4, StockMovementType.restock, from),
        (mugId, 2, StockMovementType.restock, from),
      ]);
      expect(
          (await isar.stockMovements.where().findAll())
              .every((m) => m.supplierId == supplierId),
          isTrue);
      var supplier = (await isar.suppliers.get(supplierId))!;
      expect((supplier.totalPurchases, supplier.totalPaid, supplier.totalDue),
          (1, 2000.0, 330.0));

      // Sold down in between: the reversal clamps at 0 per item.
      await isar.writeTxn(() async => isar.products
          .put((await isar.products.get(shirtId))!.copyWith(stockQty: 3)));

      final purchaseId = (await isar.purchases.where().findFirst())!.id;
      await suppliers().deletePurchase(purchaseId);
      expectNoErrors();
      expect((await isar.products.get(mugId))!.stockQty, 20);
      expect((await isar.products.get(shirtId))!.stockQty, 0);
      expect((await isar.products.get(mugId))!.costPrice, 95); // not reverted
      expect((await movements()).skip(3), [
        (mugId, -10, StockMovementType.adjustment, 'Deleted purchase'),
        (shirtId, -4, StockMovementType.adjustment, 'Deleted purchase'),
        (mugId, -2, StockMovementType.adjustment, 'Deleted purchase'),
      ]);
      supplier = (await isar.suppliers.get(supplierId))!;
      expect((supplier.totalPurchases, supplier.totalPaid, supplier.totalDue),
          (0, 0.0, 0.0));
      expect(await isar.purchases.count(), 0);
    });

    test('deleteSupplier unlinks its purchases and products', () async {
      final supplierId =
          await isar.writeTxn(() => isar.suppliers.put(Supplier(name: 'Karim')));
      await isar.writeTxn(() async {
        await isar.products.putAll([
          (await isar.products.get(mugId))!.copyWith(supplierId: supplierId),
          (await isar.products.get(shirtId))!.copyWith(supplierId: supplierId),
        ]);
      });
      await suppliers().createPurchase(
          Purchase(supplierId: supplierId, items: [], totalAmount: 10),
          restockProducts: false);
      await suppliers().createPurchase(
          Purchase(supplierId: supplierId, items: [], totalAmount: 20),
          restockProducts: false);
      expectNoErrors();

      await suppliers().deleteSupplier(supplierId);
      expectNoErrors();
      expect(await isar.suppliers.get(supplierId), isNull);
      final purchases = await isar.purchases.where().findAll();
      expect(purchases.map((p) => (p.supplierId, p.totalAmount)),
          [(0, 10), (0, 20)]);
      expect((await isar.products.where().findAll()).map((p) => p.supplierId),
          [0, 0]);
      expect(await stock(), (12, 5, 7, 20)); // untouched
    });
  });
}
