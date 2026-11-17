import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/core/utils/date_formatter.dart';
import 'package:micro_seller/core/utils/item_notes.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/product_serial.dart';
import 'package:micro_seller/data/models/purchase.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/local_backup_service.dart';
import 'package:micro_seller/data/services/pdf_service.dart';
import 'package:micro_seller/data/services/serial_service.dart';
import 'package:micro_seller/data/services/trash_service.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:micro_seller/features/products/providers/product_provider.dart';
import 'package:micro_seller/features/suppliers/providers/supplier_provider.dart';

import 'support/isar_core.dart';

/// Serial numbers (IMEI) on a real database: stock always equals the
/// serials in stock, through sales, status changes, edits, returns,
/// purchases, stock entries, the recycle bin and backups.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(closeTestIsars);

  ProviderContainer containerFor(Isar isar) {
    final c = ProviderContainer(overrides: [isarProvider.overrideWith((ref) async => isar)]);
    addTearDown(c.dispose);
    return c;
  }

  Future<Product> phone(ProviderContainer c, Isar isar, List<String> serials, {String name = 'Phone X'}) async {
    await c.read(productProvider.notifier).addProduct(
          Product(name: name, sku: name, sellingPrice: 20000, costPrice: 15000, trackSerials: true, warrantyMonths: 12),
          serials: serials,
        );
    return (await isar.products.filter().nameEqualTo(name).findFirst())!;
  }

  OrderItem line(Product p, List<String> serials) => OrderItem(
        productId: p.id,
        productName: p.name,
        qty: serials.length.toDouble(),
        unitPrice: p.sellingPrice,
        totalPrice: p.sellingPrice * serials.length,
        serials: serials,
        warrantyMonths: p.warrantyMonths,
      );

  Order orderOf(List<OrderItem> items, {String number = 'ORD-001', OrderStatus status = OrderStatus.confirmed}) {
    final total = items.fold(0.0, (s, i) => s + i.totalPrice);
    return Order(
      orderNumber: number,
      items: items,
      subtotal: total,
      totalAmount: total,
      amountPaid: total,
      paymentStatus: PaymentStatus.paid,
      orderStatus: status,
      createdAt: DateTime(2026, 11, 1, 10),
    );
  }

  Future<Map<String, SerialStatus>> statuses(Isar isar, int productId) async =>
      {for (final s in await SerialService.ofProduct(isar, productId)) s.serial: s.status};

  Future<double> stock(Isar isar, int id) async => (await isar.products.get(id))!.stockQty;

  group('documents', () {
    final item = OrderItem(
      productName: 'Phone X',
      qty: 2,
      unitPrice: 20000,
      totalPrice: 40000,
      serials: ['IMEI-1', 'IMEI-2'],
      warrantyMonths: 12,
    );

    test('the notes under a line: serials, then the warranty and its end', () {
      expect(documentItemNotes(item, DateTime(2026, 11, 17)),
          ['S/N: IMEI-1, IMEI-2', 'Warranty: 12 months (until ${DateFormatter.format(DateTime(2027, 11, 17))})']);
      expect(documentItemNotes(item.copyWith(warrantyMonths: 1), null), ['S/N: IMEI-1, IMEI-2', 'Warranty: 1 month']);
      expect(documentItemNotes(OrderItem(productName: 'Soap', qty: 1), DateTime(2026)), isEmpty);
    });

    test('the WhatsApp text lists them under the line', () {
      final text = PdfService().generateWhatsAppText(
        Order(orderNumber: 'ORD-001', items: [item], subtotal: 40000, totalAmount: 40000, createdAt: DateTime(2026, 11, 17)),
        currencySymbol: '৳',
      );
      expect(text, contains('• Phone X x2'));
      expect(text, contains('   S/N: IMEI-1, IMEI-2'));
      expect(text, contains('   Warranty: 12 months (until'));
    });
  });

  group('serials', skip: isarSkipReason, () {
    test('splitSerials: lines, commas, blanks and repeats', () {
      expect(splitSerials(' A1 \nb2, B2;\n\nc3\t'), ['A1', 'b2', 'c3']);
    });

    test('warrantyEnd keeps the day, or the month\'s last day', () {
      expect(warrantyEnd(DateTime(2026, 11, 17), 12), DateTime(2027, 11, 17));
      expect(warrantyEnd(DateTime(2027, 1, 31), 1), DateTime(2027, 2, 28));
      expect(warrantyEnd(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(OrderItem(warrantyMonths: 0).warrantyEndsFrom(DateTime(2026)), isNull);
    });

    test('a new product: its serials are its stock; a repeat saves nothing', () async {
      final isar = await openTestIsar('serial_add');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['IMEI-1', 'IMEI-2', 'IMEI-3']);
      expect(p.stockQty, 3);
      expect(p.usesSerials, isTrue);

      await expectLater(
        c.read(productProvider.notifier).addProduct(
            Product(name: 'Dup', sellingPrice: 1, trackSerials: true), serials: ['A', 'a']),
        throwsA(isA<DuplicateSerialException>()),
      );
      expect(await isar.products.filter().nameEqualTo('Dup').count(), 0);
    });

    test('editing a product adds and removes serials; a serial it has is refused', () async {
      final isar = await openTestIsar('serial_edit');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A', 'B']);
      await c.read(productProvider.notifier).updateProduct(p, addedSerials: ['C', 'D'], removedSerials: ['A']);
      expect(await stock(isar, p.id), 3);
      expect(await statuses(isar, p.id), {'A': SerialStatus.removed, 'B': SerialStatus.inStock, 'C': SerialStatus.inStock, 'D': SerialStatus.inStock});
      await expectLater(c.read(productProvider.notifier).updateProduct(p, addedSerials: ['b']), throwsA(isA<DuplicateSerialException>()));
      expect(await stock(isar, p.id), 3);
    });

    test('a confirmed sale sells its serials, dated with the order; cancel puts them back', () async {
      final isar = await openTestIsar('serial_sale');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A', 'B', 'C']);
      final id = await c.read(orderProvider.notifier).createOrder(orderOf([line(p, ['B'])]));
      expect(await stock(isar, p.id), 2);
      final b = (await SerialService.find(isar, 'b')).single;
      expect((b.status, b.orderId, b.soldAt), (SerialStatus.sold, id, DateTime(2026, 11, 1, 10)));

      await c.read(orderProvider.notifier).updateStatus(id, OrderStatus.cancelled);
      expect(await stock(isar, p.id), 3);
      expect((await statuses(isar, p.id))['B'], SerialStatus.inStock);
    });

    test('pending takes nothing; confirming sells; a serial sold elsewhere refuses it', () async {
      final isar = await openTestIsar('serial_pending');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A', 'B']);
      final pending = await c.read(orderProvider.notifier).createOrder(orderOf([line(p, ['A'])], status: OrderStatus.pending));
      expect(await stock(isar, p.id), 2);

      await c.read(orderProvider.notifier).createOrder(orderOf([line(p, ['A'])], number: 'ORD-002'));
      expect(await stock(isar, p.id), 1);

      await c.read(orderProvider.notifier).updateStatus(pending, OrderStatus.confirmed);
      expect(c.read(orderProvider).error, isA<SerialNotAvailableException>());
      expect((await isar.orders.get(pending))!.orderStatus, OrderStatus.pending, reason: 'nothing saved');
      expect(await stock(isar, p.id), 1);
    });

    test('a sale of an unknown serial, or a tracked line without serials, is refused', () async {
      final isar = await openTestIsar('serial_refused');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A']);
      await expectLater(c.read(orderProvider.notifier).createOrder(orderOf([line(p, ['Z'])])),
          throwsA(isA<SerialNotAvailableException>()));
      final noSerials = line(p, ['A']).copyWith(serials: const []);
      await expectLater(c.read(orderProvider.notifier).createOrder(orderOf([noSerials])),
          throwsA(isA<SerialsMissingException>()));
      expect(await isar.orders.count(), 0);
      expect(await stock(isar, p.id), 1);
    });

    test('editing a confirmed order swaps a serial and logs the change', () async {
      final isar = await openTestIsar('serial_swap');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A', 'B', 'C']);
      final id = await c.read(orderProvider.notifier).createOrder(orderOf([line(p, ['A'])]));
      var order = (await isar.orders.get(id))!;

      await c.read(orderProvider.notifier).updateOrder(order.copyWith(items: [line(p, ['B'])]));
      expect(await statuses(isar, p.id), {'A': SerialStatus.inStock, 'B': SerialStatus.sold, 'C': SerialStatus.inStock});
      expect(await stock(isar, p.id), 2);

      order = (await isar.orders.get(id))!;
      await c.read(orderProvider.notifier).updateOrder(order.copyWith(items: [line(p, ['B', 'C'])]));
      expect(await stock(isar, p.id), 1);
      final edits = await isar.stockMovements.filter().reasonEqualTo('Edited ORD-001').findAll();
      expect(edits.map((m) => m.qty), [-1.0]);

      // Edited back to pending: everything returns.
      order = (await isar.orders.get(id))!;
      await c.read(orderProvider.notifier).updateOrder(order.copyWith(orderStatus: OrderStatus.pending));
      expect(await stock(isar, p.id), 3);
    });

    test('deleting a sold order puts its serials back', () async {
      final isar = await openTestIsar('serial_delete_order');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A', 'B']);
      final id = await c.read(orderProvider.notifier).createOrder(orderOf([line(p, ['A', 'B'])]));
      expect(await stock(isar, p.id), 0);
      await c.read(orderProvider.notifier).deleteOrder(id);
      expect(await stock(isar, p.id), 2);
    });

    test('a return of one serial comes back in stock only when approved', () async {
      final isar = await openTestIsar('serial_return');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A', 'B']);
      final id = await c.read(orderProvider.notifier).createOrder(orderOf([line(p, ['A', 'B'])]));
      final original = (await isar.orders.get(id))!;
      await c.read(orderProvider.notifier).createReturnOrder(
            originalOrder: original,
            returnItems: [line(p, ['B'])],
            reason: ReturnReason.values.first,
            refundAmount: 0,
          );
      expect(await stock(isar, p.id), 0);
      final ret = (await isar.orders.filter().isReturnEqualTo(true).findFirst())!;
      await c.read(orderProvider.notifier).approveReturn(ret.id);
      expect(await statuses(isar, p.id), {'A': SerialStatus.sold, 'B': SerialStatus.inStock});
      expect(await stock(isar, p.id), 1);
    });

    test('recurring copies start without serials', () async {
      final isar = await openTestIsar('serial_recurring');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A', 'B']);
      final o = orderOf([line(p, ['A'])]).copyWith(
          isRecurring: true, recurringIntervalDays: 30, nextRecurringDate: DateTime(2020));
      await c.read(orderProvider.notifier).createOrder(o);
      await c.read(orderProvider.notifier).processRecurringOrders();
      final copy = (await isar.orders.filter().orderNumberEqualTo('ORD-002').findFirst())!;
      expect(copy.items.single.serials, isEmpty);
      expect(copy.orderStatus, OrderStatus.pending);
    });

    test('a purchase brings serials; deleting it removes the unsold ones', () async {
      final isar = await openTestIsar('serial_purchase');
      final c = containerFor(isar);
      final p = await phone(c, isar, const []);
      expect(p.stockQty, 0);
      await c.read(supplierProvider.notifier).createPurchase(Purchase(items: [
        PurchaseItem(productId: p.id, productName: p.name, qty: 3, unitCost: 14000, totalCost: 42000, serials: ['P1', 'P2', 'P3']),
      ]));
      expect(await stock(isar, p.id), 3);
      final purchaseId = (await isar.purchases.where().findFirst())!.id;
      expect((await SerialService.ofProduct(isar, p.id)).every((s) => s.purchaseId == purchaseId), isTrue);

      await c.read(orderProvider.notifier).createOrder(orderOf([line(p, ['P2'])]));
      expect(await stock(isar, p.id), 2);

      await c.read(supplierProvider.notifier).deletePurchase(purchaseId);
      expect(await statuses(isar, p.id), {'P2': SerialStatus.sold});
      expect(await stock(isar, p.id), 0);
      final moves = await isar.stockMovements.filter().reasonEqualTo('Deleted purchase').findAll();
      expect(moves.single.qty, -2);
    });

    test('a purchase line without one serial per unit is refused', () async {
      final isar = await openTestIsar('serial_purchase_missing');
      final c = containerFor(isar);
      final p = await phone(c, isar, const []);
      await expectLater(
        c.read(supplierProvider.notifier).createPurchase(Purchase(items: [
          PurchaseItem(productId: p.id, productName: p.name, qty: 2, serials: ['P1']),
        ])),
        throwsA(isA<SerialsMissingException>()),
      );
      expect(await isar.purchases.count(), 0);
    });

    test('stock entries: restock adds serials, damage and sale take them out', () async {
      final isar = await openTestIsar('serial_adjust');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A']);
      final n = c.read(productProvider.notifier);
      await n.adjustStock(p.id, 2, 'Found', StockMovementType.restock, serials: ['B', 'C']);
      expect(await stock(isar, p.id), 3);
      await n.adjustStock(p.id, -1, 'Cracked', StockMovementType.damage, serials: ['A']);
      await n.adjustStock(p.id, -1, '', StockMovementType.sale, serials: ['C']);
      expect(await statuses(isar, p.id), {'A': SerialStatus.removed, 'B': SerialStatus.inStock, 'C': SerialStatus.sold});
      expect(await stock(isar, p.id), 1);
      final moves = await isar.stockMovements.filter().productIdEqualTo(p.id).findAll();
      expect(moves.map((m) => m.qty), [2.0, -1.0, -1.0]);
      expect(moves.first.reason, 'Found · B, C');

      await expectLater(n.adjustStock(p.id, -1, '', StockMovementType.damage, serials: ['A']),
          throwsA(isA<SerialNotAvailableException>()));
      await expectLater(n.adjustStock(p.id, 1, '', StockMovementType.restock), throwsA(isA<SerialsMissingException>()));
    });

    test('a hard-deleted product takes its serials to the bin and back', () async {
      final isar = await openTestIsar('serial_trash');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A', 'B']);
      final trashId = await c.read(productProvider.notifier).deleteProduct(p.id);
      expect(await isar.productSerials.count(), 0);
      await TrashService(isar).restore(trashId!);
      expect(await statuses(isar, p.id), {'A': SerialStatus.inStock, 'B': SerialStatus.inStock});
      expect(await stock(isar, p.id), 2);
    });

    test('backup round trip; an older backup without serials restores', () async {
      final isar = await openTestIsar('serial_backup');
      final c = containerFor(isar);
      final p = await phone(c, isar, ['A', 'B']);
      await c.read(orderProvider.notifier).createOrder(orderOf([line(p, ['A'])]));
      final bytes = encodeBackupBytesSync(isar);
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(map['version'], 7);
      expect((map['productSerials'] as List).length, 2);

      final other = await openTestIsar('serial_backup_2');
      restoreBackupSync(other, map);
      final restored = (await other.products.get(p.id))!;
      expect((restored.trackSerials, restored.warrantyMonths, restored.stockQty), (true, 12, 1.0));
      expect(await statuses(other, p.id), {'A': SerialStatus.sold, 'B': SerialStatus.inStock});
      expect((await other.orders.where().findFirst())!.items.single.serials, ['A']);

      // Before serials: no key, no product fields, no item fields.
      final old = jsonDecode(jsonEncode(map)) as Map<String, dynamic>..remove('productSerials');
      for (final pr in old['products'] as List) {
        (pr as Map).remove('trackSerials');
        pr.remove('warrantyMonths');
      }
      for (final o in old['orders'] as List) {
        for (final i in (o as Map)['items'] as List) {
          (i as Map).remove('serials');
          i.remove('warrantyMonths');
        }
      }
      final third = await openTestIsar('serial_backup_3');
      restoreBackupSync(third, old);
      final plain = (await third.products.get(p.id))!;
      expect((plain.trackSerials, plain.warrantyMonths), (false, 0));
      expect(await third.productSerials.count(), 0);
    });

    test('untracked products are untouched by serial rules', () async {
      final isar = await openTestIsar('serial_untracked');
      final c = containerFor(isar);
      await c.read(productProvider.notifier).addProduct(Product(name: 'Soap', sellingPrice: 20, stockQty: 10));
      final soap = (await isar.products.where().findFirst())!;
      await c.read(orderProvider.notifier).createOrder(orderOf([
        OrderItem(productId: soap.id, productName: 'Soap', qty: 2, unitPrice: 20, totalPrice: 40),
      ]));
      expect(await stock(isar, soap.id), 8);
    });
  });
}
