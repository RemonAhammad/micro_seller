import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/core/utils/quantity.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/purchase.dart';
import 'package:micro_seller/data/models/quantity_unit.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/services/backup_format.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/local_backup_service.dart';
import 'package:micro_seller/data/services/migration_service.dart';
import 'package:micro_seller/data/services/report_service.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';

import 'support/isar_core.dart';

/// Selling a piece product by the dozen (issue #12): a dozen line takes 12
/// pieces from stock, and products once stocked in dozens move to pieces.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(closeTestIsars);

  ProviderContainer containerFor(Isar isar) {
    final c = ProviderContainer(overrides: [isarProvider.overrideWith((ref) async => isar)]);
    addTearDown(c.dispose);
    return c;
  }

  OrderItem pieces(int productId, double qty, {String combo = ''}) => OrderItem(
        productId: productId,
        productName: 'Eggs',
        qty: qty,
        unitPrice: 13,
        costPrice: 10,
        totalPrice: lineTotal(13, qty),
        variantCombinationKey: combo,
      );

  OrderItem dozens(int productId, double qty, {String combo = ''}) => OrderItem(
        productId: productId,
        productName: 'Eggs',
        qty: qty,
        unit: QuantityUnit.dozen,
        unitFactor: kDozen,
        unitPrice: 156,
        costPrice: 120,
        totalPrice: lineTotal(156, qty),
        variantCombinationKey: combo,
      );

  Order sale(List<OrderItem> items, {String number = 'ORD-001'}) {
    final total = items.fold(0.0, (s, i) => s + i.totalPrice);
    return Order(
      orderNumber: number,
      items: items,
      subtotal: total,
      totalAmount: total,
      amountPaid: total,
      paymentStatus: PaymentStatus.paid,
      orderStatus: OrderStatus.confirmed,
      createdAt: DateTime.now(),
    );
  }

  test('OrderItem.factor: null, 0, NaN and negatives read as 1', () {
    expect(OrderItem().factor, 1);
    expect(OrderItem(unitFactor: 0).factor, 1);
    expect(OrderItem(unitFactor: double.nan).factor, 1);
    expect(OrderItem(unitFactor: -12).factor, 1);
    expect(OrderItem(qty: 2, unitFactor: kDozen).baseQty, 24);
  });

  test('Dozen is not offered as a product unit', () {
    expect(QuantityUnit.productUnits, isNot(contains(QuantityUnit.dozen)));
    expect(QuantityUnit.productUnits.length, QuantityUnit.values.length - 1);
  });

  group('stock', skip: isarSkipReason, () {
    Future<(Isar, ProviderContainer, int)> shop({List<VariantCombination> combos = const []}) async {
      final isar = await openTestIsar('dozen');
      late int id;
      await isar.writeTxn(() async {
        id = await isar.products.put(Product(
          name: 'Eggs',
          sellingPrice: 13,
          costPrice: 10,
          stockQty: 100,
          variantCombinations: combos,
        ));
      });
      return (isar, containerFor(isar), id);
    }

    test('1 dozen + 3 pieces take 15; cancelling puts them back', () async {
      final (isar, c, id) = await shop();
      final notifier = c.read(orderProvider.notifier);
      final orderId = await notifier.createOrder(sale([dozens(id, 1), pieces(id, 3)]));

      expect((await isar.products.get(id))!.stockQty, 85);
      final moved = (await isar.stockMovements.where().findAll()).map((m) => m.qty).toList();
      expect(moved, unorderedEquals([-12.0, -3.0]));

      await notifier.updateStatus(orderId, OrderStatus.cancelled);
      expect((await isar.products.get(id))!.stockQty, 100);
    });

    test('deleting the order restores 12 pieces per dozen', () async {
      final (isar, c, id) = await shop();
      final notifier = c.read(orderProvider.notifier);
      final orderId = await notifier.createOrder(sale([dozens(id, 2)]));
      expect((await isar.products.get(id))!.stockQty, 76);
      await notifier.deleteOrder(orderId);
      expect((await isar.products.get(id))!.stockQty, 100);
    });

    test('an approved return of 1 dozen restocks 12 pieces', () async {
      final (isar, c, id) = await shop();
      final notifier = c.read(orderProvider.notifier);
      final orderId = await notifier.createOrder(sale([dozens(id, 2)]));
      final original = (await isar.orders.get(orderId))!;

      await notifier.createReturnOrder(
        originalOrder: original,
        returnItems: [original.items.single.copyWith(qty: 1, totalPrice: 156)],
        reason: ReturnReason.values.first,
        refundAmount: 0,
      );
      final ret = (await isar.orders.filter().isReturnEqualTo(true).findFirst())!;
      expect(ret.items.single.factor, kDozen, reason: 'the return line keeps its unit');
      await notifier.approveReturn(ret.id);
      expect((await isar.products.get(id))!.stockQty, 88);
    });

    test('a variant combination moves 12 per dozen too', () async {
      final (isar, c, id) = await shop(combos: [
        VariantCombination(combinationKey: 'Color:Brown', displayLabel: 'Color: Brown', stockQty: 60, isActive: true),
      ]);
      await c.read(orderProvider.notifier).createOrder(sale([dozens(id, 2, combo: 'Color:Brown')]));
      final p = (await isar.products.get(id))!;
      expect(p.findCombination('Color:Brown')!.stockQty, 36);
      expect(p.stockQty, 76);
    });

    test('a line without a factor still moves its own quantity', () async {
      final (isar, c, id) = await shop();
      await c.read(orderProvider.notifier).createOrder(sale([pieces(id, 7)]));
      expect((await isar.products.get(id))!.stockQty, 93);
    });
  });

  test('report: a dozen line costs 12 × the piece cost, and counts 12 sold', () {
    final product = Product(name: 'Eggs', sellingPrice: 13, costPrice: 10)..id = 1;
    final now = DateTime.now();
    Order o(OrderItem i) => sale([i])..createdAt = now;
    final report = buildSalesReport(
      orders: [
        o(dozens(1, 1)),
        // An older line without its own cost falls back to the product's,
        // per piece, so × 12 for a dozen line.
        o(dozens(1, 1).copyWith(costPrice: 0)),
      ],
      productsById: {1: product},
      expenses: const [],
      start: now.subtract(const Duration(days: 1)),
      end: now.add(const Duration(days: 1)),
    );
    expect(report.cogs, 240);
  });

  group('dozen → piece', skip: isarSkipReason, () {
    Future<Isar> dozenShop(String name) async {
      final isar = await openTestIsar(name);
      await isar.writeTxn(() async {
        await isar.products.put(Product(
          name: 'Eggs',
          sellingPrice: 156,
          costPrice: 120,
          stockQty: 8,
          lowStockThreshold: 2,
          unit: QuantityUnit.dozen,
          variantCombinations: [
            VariantCombination(combinationKey: 'Color:Brown', stockQty: 3, priceAdjustment: 12),
          ],
        )..id = 1);
        await isar.products.put(Product(name: 'Soap', sellingPrice: 40, stockQty: 5)..id = 2);
        await isar.orders.put(Order(orderNumber: 'ORD-001', items: [
          OrderItem(productId: 1, productName: 'Eggs', qty: 1, unit: QuantityUnit.dozen, unitPrice: 156, totalPrice: 156),
          OrderItem(productId: 2, productName: 'Soap', qty: 1, unitPrice: 40, totalPrice: 40),
        ]));
        await isar.purchases.put(Purchase(items: [
          PurchaseItem(productId: 1, productName: 'Eggs', qty: 5, unit: QuantityUnit.dozen, unitCost: 120, totalCost: 600),
        ]));
        await isar.stockMovements.put(StockMovement(productId: 1, qty: -1));
        await isar.stockMovements.put(StockMovement(productId: 2, qty: -1));
      });
      return isar;
    }

    Future<void> expectConverted(Isar isar) async {
      final eggs = (await isar.products.get(1))!;
      expect(eggs.unit, QuantityUnit.piece);
      expect(eggs.stockQty, 96);
      expect(eggs.lowStockThreshold, 24);
      expect(eggs.sellingPrice, 13);
      expect(eggs.costPrice, 10);
      expect(eggs.variantCombinations.single.stockQty, 36);
      expect(eggs.variantCombinations.single.priceAdjustment, 1);
      expect((await isar.products.get(2))!.stockQty, 5, reason: 'other products untouched');

      final items = (await isar.orders.where().findFirst())!.items;
      expect(items[0].unit, QuantityUnit.dozen);
      expect(items[0].factor, kDozen);
      expect(items[0].baseQty, 12);
      expect(items[1].factor, 1);

      final bought = (await isar.purchases.where().findFirst())!.items.single;
      expect(bought.unit, QuantityUnit.piece);
      expect(bought.qty, 60);
      expect(bought.unitCost, 10);

      final moves = await isar.stockMovements.where().findAll();
      expect({for (final m in moves) m.productId: m.qty}, {1: -12.0, 2: -1.0});
    }

    test('the migration converts a dozen product and the rows that count it', () async {
      final isar = await dozenShop('migrate-dozen');
      await migrateDozenToPieceV1(isar);
      await expectConverted(isar);
      expect((await SharedPreferences.getInstance()).getBool(kDozenToPieceMigrationKey), isTrue);
    });

    test('running it again changes nothing', () async {
      final isar = await dozenShop('migrate-dozen-twice');
      await migrateDozenToPieceV1(isar);
      SharedPreferences.setMockInitialValues({});
      await migrateDozenToPieceV1(isar);
      await expectConverted(isar);
    });

    test('a v7 backup with a dozen product restores converted', () async {
      final source = await dozenShop('dozen-backup');
      final map = jsonDecode(utf8.decode(encodeBackupBytesSync(source))) as Map<String, dynamic>;
      expect(map['version'], kBackupVersion);
      map['version'] = 7;

      final other = await openTestIsar('dozen-restore');
      restoreBackupSync(other, parseBackupBytes(utf8.encode(jsonEncode(map))));
      await expectConverted(other);
    });

    test('a dozen line keeps its factor through a backup', () async {
      final isar = await openTestIsar('dozen-roundtrip');
      await isar.writeTxn(() async {
        await isar.products.put(Product(name: 'Eggs', sellingPrice: 13, stockQty: 100)..id = 1);
        await isar.orders.put(Order(orderNumber: 'ORD-001', items: [dozens(1, 2)]));
      });
      final other = await openTestIsar('dozen-roundtrip2');
      restoreBackupSync(other, parseBackupBytes(encodeBackupBytesSync(isar)));
      final item = (await other.orders.where().findFirst())!.items.single;
      expect(item.factor, kDozen);
      expect(item.unit, QuantityUnit.dozen);
    });
  });
}
