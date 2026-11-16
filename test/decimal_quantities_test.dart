import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/purchase.dart';
import 'package:micro_seller/data/models/quantity_unit.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/local_backup_service.dart';
import 'package:micro_seller/data/services/migration_service.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:micro_seller/features/suppliers/providers/supplier_provider.dart';

import 'support/isar_core.dart';

/// Decimal quantities on a real Isar database: the one-time migration of
/// the whole-number fields, stock moves in kilograms, and backups from before.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(closeTestIsars);

  ProviderContainer containerFor(Isar isar) {
    final c = ProviderContainer(overrides: [isarProvider.overrideWith((ref) async => isar)]);
    addTearDown(c.dispose);
    return c;
  }

  group('migrateDecimalQuantitiesV1', skip: isarSkipReason, () {
    // A row as an older version left it: the int under its old stored name
    // (still in the schema as legacy…), the decimal field never written.
    Future<Isar> olderDatabase() async {
      final isar = await openTestIsar('migrate');
      await isar.writeTxn(() async {
        await isar.products.put(Product(name: 'Soap', sellingPrice: 40)
          ..legacyStockQty = 7
          ..legacyLowStockThreshold = 3
          ..variantCombinations = [
            VariantCombination(combinationKey: 'Size:L')..legacyStockQty = 4,
          ]);
        await isar.orders.put(Order(
          orderNumber: 'ORD-001',
          items: [OrderItem(productId: 1, productName: 'Soap', unitPrice: 40, totalPrice: 80)..legacyQty = 2],
        ));
        await isar.purchases.put(Purchase(items: [PurchaseItem(productId: 1)..legacyQty = 12]));
        await isar.stockMovements.put(StockMovement(productId: 1)..legacyQty = -2);
      });
      return isar;
    }

    test('moves every whole number into its decimal field', () async {
      final isar = await olderDatabase();
      await migrateDecimalQuantitiesV1(isar);

      final p = (await isar.products.where().findFirst())!;
      expect(p.stockQty, 7.0);
      expect(p.lowStockThreshold, 3.0);
      expect(p.variantCombinations.single.stockQty, 4.0);
      expect(p.unit, QuantityUnit.piece);
      expect(p.legacyStockQty, 0);
      expect(p.legacyLowStockThreshold, 0);

      final o = (await isar.orders.where().findFirst())!;
      expect(o.items.single.qty, 2.0);
      expect(o.items.single.unit, QuantityUnit.piece);
      expect((await isar.purchases.where().findFirst())!.items.single.qty, 12.0);
      expect((await isar.stockMovements.where().findFirst())!.qty, -2.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kDecimalQuantitiesMigrationKey), isTrue);
    });

    test('a second run changes nothing, even with the flag lost', () async {
      final isar = await olderDatabase();
      await migrateDecimalQuantitiesV1(isar);
      // A sale after the update writes decimals and no legacy value.
      await isar.writeTxn(() async {
        final p = (await isar.products.where().findFirst())!;
        await isar.products.put(p..stockQty = 5.75);
      });

      SharedPreferences.setMockInitialValues({});
      await migrateDecimalQuantitiesV1(isar);
      expect((await isar.products.where().findFirst())!.stockQty, 5.75);
    });
  });

  group('stock in kilograms', skip: isarSkipReason, () {
    Future<(Isar, ProviderContainer, int)> shop() async {
      final isar = await openTestIsar('kg');
      late int id;
      await isar.writeTxn(() async {
        id = await isar.products.put(
            Product(name: 'Rui fish', sellingPrice: 600, costPrice: 450, stockQty: 5, unit: QuantityUnit.kg));
      });
      return (isar, containerFor(isar), id);
    }

    Order sale(int productId, double qty, {OrderStatus status = OrderStatus.confirmed}) => Order(
          orderNumber: 'ORD-${qty.hashCode}',
          items: [
            OrderItem(
              productId: productId,
              productName: 'Rui fish',
              qty: qty,
              unit: QuantityUnit.kg,
              unitPrice: 600,
              costPrice: 450,
              totalPrice: lineTotal(600, qty),
            ),
          ],
          subtotal: lineTotal(600, qty),
          totalAmount: lineTotal(600, qty),
          amountPaid: lineTotal(600, qty),
          paymentStatus: PaymentStatus.paid,
          orderStatus: status,
          createdAt: DateTime.now(),
        );

    test('selling 1.25 kg of 5 kg leaves 3.75; cancelling puts it back', () async {
      final (isar, c, id) = await shop();
      final notifier = c.read(orderProvider.notifier);
      final orderId = await notifier.createOrder(sale(id, 1.25));

      expect((await isar.products.get(id))!.stockQty, 3.75);
      final movement = (await isar.stockMovements.where().findFirst())!;
      expect(movement.qty, -1.25);

      await notifier.updateStatus(orderId, OrderStatus.cancelled);
      expect((await isar.products.get(id))!.stockQty, 5.0);
    });

    test('fifty 0.1 kg sales take exactly 5 kg, with no drift', () async {
      final (isar, c, id) = await shop();
      final notifier = c.read(orderProvider.notifier);
      for (var i = 0; i < 50; i++) {
        await notifier.createOrder(sale(id, 0.1));
      }
      expect((await isar.products.get(id))!.stockQty, 0.0);
    });

    test('a 2.5 kg purchase restocks to 7.5 kg, and its delete takes it back', () async {
      final (isar, c, id) = await shop();
      await c.read(supplierProvider.notifier).createPurchase(Purchase(
            items: [PurchaseItem(productId: id, productName: 'Rui fish', qty: 2.5, unit: QuantityUnit.kg, unitCost: 440)],
            totalAmount: 1100,
            createdAt: DateTime.now(),
          ));
      final product = (await isar.products.get(id))!;
      expect(product.stockQty, 7.5);
      expect(product.costPrice, 440);

      final purchase = (await isar.purchases.where().findFirst())!;
      await c.read(supplierProvider.notifier).deletePurchase(purchase.id);
      expect((await isar.products.get(id))!.stockQty, 5.0);
    });
  });

  group('backups', skip: isarSkipReason, () {
    test('a v5 backup (whole numbers, no unit) restores into decimals as pieces', () async {
      final isar = await openTestIsar('v5');
      final v5 = {
        'version': 5,
        'timestamp': '2026-10-01T10:00:00.000',
        'products': [
          {'id': 1, 'name': 'Soap', 'sellingPrice': 40, 'stockQty': 12, 'lowStockThreshold': 3},
        ],
        'orders': [
          {
            'id': 1,
            'orderNumber': 'ORD-001',
            'items': [
              {'productId': 1, 'productName': 'Soap', 'qty': 2, 'unitPrice': 40, 'totalPrice': 80},
            ],
          },
        ],
        'stockMovements': [
          {'id': 1, 'productId': 1, 'type': 'sale', 'qty': -2},
        ],
      };
      restoreBackupSync(isar, parseBackupBytes(utf8.encode(jsonEncode(v5))));

      final p = (await isar.products.get(1))!;
      expect(p.stockQty, 12.0);
      expect(p.lowStockThreshold, 3.0);
      expect(p.unit, QuantityUnit.piece);
      expect((await isar.orders.get(1))!.items.single.qty, 2.0);
      expect((await isar.stockMovements.get(1))!.qty, -2.0);
    });

    test('decimals and units survive a backup round trip', () async {
      final isar = await openTestIsar('roundtrip');
      await isar.writeTxn(() async {
        await isar.products.put(Product(name: 'Cloth', sellingPrice: 250, stockQty: 12.345, unit: QuantityUnit.metre));
      });
      final bytes = encodeBackupBytesSync(isar);
      expect(jsonDecode(utf8.decode(bytes))['version'], 6);

      final other = await openTestIsar('roundtrip2');
      restoreBackupSync(other, parseBackupBytes(bytes));
      final p = (await other.products.where().findFirst())!;
      expect(p.stockQty, 12.345);
      expect(p.unit, QuantityUnit.metre);
    });
  });
}
