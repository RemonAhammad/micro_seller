import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/quantity.dart';
import '../models/product.dart';
import '../models/quantity_unit.dart';
import '../models/order.dart';
import '../models/purchase.dart';
import '../models/stock_movement.dart';
import '../models/variant_attribute.dart';
import '../models/variant_combination.dart';

const _migrationKey = 'variantsV2Migrated';

Future<void> migrateVariantsV2(Isar isar) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_migrationKey) == true) return;

  debugPrint('[Migration] Running variants V2 migration...');

  await isar.writeTxn(() async {

    final products = await isar.products.where().findAll();
    for (final product in products) {
      if (product.variants.isEmpty) continue;
      if (product.variantCombinations.isNotEmpty) continue;

      final grouped = <String, List<String>>{};
      for (final v in product.variants) {
        if (v.name.isEmpty || v.value.isEmpty) continue;
        grouped.putIfAbsent(v.name, () => []).add(v.value);
      }

      final attributes = grouped.entries
          .map((e) => VariantAttribute(name: e.key, options: e.value))
          .toList();

      final combinations = product.variants
          .where((v) => v.name.isNotEmpty && v.value.isNotEmpty)
          .map((v) => VariantCombination(
                combinationKey: '${v.name}:${v.value}',
                displayLabel: '${v.name}: ${v.value}',
                priceAdjustment: v.priceAdjustment,
                stockQty: v.stockQty.toDouble(),
                sku: v.sku,
                isActive: true,
              ))
          .toList();

      await isar.products.put(product.copyWith(
        variantAttributes: attributes,
        variantCombinations: combinations,
      ));
    }

    final orders = await isar.orders.where().findAll();
    for (final order in orders) {
      bool changed = false;
      final updatedItems = order.items.map((item) {
        if (item.variantName.isNotEmpty &&
            item.variantCombinationKey.isEmpty) {
          changed = true;
          return item.copyWith(
            variantCombinationKey: '${item.variantName}:${item.variantValue}',
            variantDisplayLabel: '${item.variantName}: ${item.variantValue}',
          );
        }
        return item;
      }).toList();
      if (changed) {
        await isar.orders.put(order.copyWith(items: updatedItems));
      }
    }
  });

  await prefs.setBool(_migrationKey, true);
  debugPrint('[Migration] Variants V2 migration complete.');
}

const kDecimalQuantitiesMigrationKey = 'decimalQuantitiesV1Migrated';

/// Moves the whole-number quantities of older versions into the decimal
/// fields that replaced them: product and variant stock, the low-stock
/// level, order and purchase item quantities, stock movements.
///
/// Isar can't read a stored int as a double, so the new fields have new
/// stored names and the old ints are still read under theirs (`legacy…`).
/// Each copied int is set back to 0, which makes a second run a no-op even
/// if the flag is lost (rows written since never set a legacy field).
///
/// Must run before [migrateVariantsV2]: that one rebuilds products with
/// `copyWith`, which doesn't carry the legacy fields. Rows are changed in
/// place here for the same reason.
Future<void> migrateDecimalQuantitiesV1(Isar isar) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(kDecimalQuantitiesMigrationKey) == true) return;
  await migrateDecimalQuantitiesInTxn(isar);
  await prefs.setBool(kDecimalQuantitiesMigrationKey, true);
}

/// The migration's work without the flag, for tests and the auto-backup
/// worker (which may open the database before the app has).
Future<void> migrateDecimalQuantitiesInTxn(Isar isar) async {
  debugPrint('[Migration] Running decimal quantities V1 migration...');
  var moved = 0;

  await isar.writeTxn(() async {
    final products = <Product>[];
    for (final p in await isar.products.where().findAll()) {
      var changed = false;
      if (p.legacyStockQty != 0 || p.stockQty.isNaN) {
        p.stockQty = p.legacyStockQty.toDouble();
        p.legacyStockQty = 0;
        changed = true;
      }
      if (p.legacyLowStockThreshold != 0 || p.lowStockThreshold.isNaN) {
        p.lowStockThreshold = p.legacyLowStockThreshold.toDouble();
        p.legacyLowStockThreshold = 0;
        changed = true;
      }
      for (final c in p.variantCombinations) {
        if (c.legacyStockQty != 0 || c.stockQty.isNaN) {
          c.stockQty = c.legacyStockQty.toDouble();
          c.legacyStockQty = 0;
          changed = true;
        }
      }
      if (changed) products.add(p);
    }
    await isar.products.putAll(products);

    final orders = <Order>[];
    for (final o in await isar.orders.where().findAll()) {
      var changed = false;
      for (final item in o.items) {
        if (item.legacyQty != 0 || item.qty.isNaN) {
          item.qty = item.legacyQty.toDouble();
          item.legacyQty = 0;
          changed = true;
        }
      }
      if (changed) orders.add(o);
    }
    await isar.orders.putAll(orders);

    final purchases = <Purchase>[];
    for (final p in await isar.purchases.where().findAll()) {
      var changed = false;
      for (final item in p.items) {
        if (item.legacyQty != 0 || item.qty.isNaN) {
          item.qty = item.legacyQty.toDouble();
          item.legacyQty = 0;
          changed = true;
        }
      }
      if (changed) purchases.add(p);
    }
    await isar.purchases.putAll(purchases);

    final movements = <StockMovement>[];
    for (final m in await isar.stockMovements.where().findAll()) {
      if (m.legacyQty != 0 || m.qty.isNaN) {
        m.qty = m.legacyQty.toDouble();
        m.legacyQty = 0;
        movements.add(m);
      }
    }
    await isar.stockMovements.putAll(movements);

    moved = products.length + orders.length + purchases.length + movements.length;
  });

  debugPrint('[Migration] Decimal quantities V1 migration complete ($moved rows).');
}

const kDozenToPieceMigrationKey = 'dozenToPieceV1Migrated';

/// Dozen is no longer a product unit: a product is stocked in pieces and an
/// order line may be sold in dozens (`OrderItem.unitFactor` = [kDozen]).
/// Turns every product still stocked in dozens into one stocked in pieces.
Future<void> migrateDozenToPieceV1(Isar isar) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(kDozenToPieceMigrationKey) == true) return;
  await isar.writeTxn(() async {
    final products = await isar.products.where().findAll();
    if (!products.any((p) => p.unit == QuantityUnit.dozen)) return;
    final orders = await isar.orders.where().findAll();
    final purchases = await isar.purchases.where().findAll();
    final movements = await isar.stockMovements.where().findAll();
    final changed = convertDozenProducts(
      products: products,
      orders: orders,
      purchases: purchases,
      movements: movements,
    );
    await isar.products.putAll(changed.products);
    await isar.orders.putAll(changed.orders);
    await isar.purchases.putAll(changed.purchases);
    await isar.stockMovements.putAll(changed.movements);
    debugPrint('[Migration] Dozen → piece: ${changed.products.length} products.');
  });
  await prefs.setBool(kDozenToPieceMigrationKey, true);
}

/// Rewrites, in place, every product stocked in dozens as one stocked in
/// pieces, with the rows that count its stock: stock, low-stock level and
/// variant stock × 12, prices ÷ 12; its dozen order lines get factor 12 (so a
/// cancel, delete or return still moves 12 pieces each); its purchase lines
/// and stock movements move to pieces. Returns the rows it changed. Also used
/// on a backup being restored, so an older backup arrives converted.
/// Idempotent: a converted product is no longer in dozens.
({
  List<Product> products,
  List<Order> orders,
  List<Purchase> purchases,
  List<StockMovement> movements,
}) convertDozenProducts({
  required List<Product> products,
  required List<Order> orders,
  required List<Purchase> purchases,
  required List<StockMovement> movements,
}) {
  final ids = <int>{};
  final changedProducts = <Product>[];
  for (final p in products) {
    if (p.unit != QuantityUnit.dozen) continue;
    ids.add(p.id);
    p
      ..unit = QuantityUnit.piece
      ..stockQty = roundQty(p.stockQty * kDozen)
      ..lowStockThreshold = roundQty(p.lowStockThreshold * kDozen)
      ..sellingPrice = p.sellingPrice / kDozen
      ..costPrice = p.costPrice / kDozen;
    for (final c in p.variantCombinations) {
      c
        ..stockQty = roundQty(c.stockQty * kDozen)
        ..priceAdjustment = c.priceAdjustment / kDozen;
    }
    changedProducts.add(p);
  }
  if (ids.isEmpty) {
    return (products: const [], orders: const [], purchases: const [], movements: const []);
  }

  final changedOrders = <Order>[];
  for (final o in orders) {
    var changed = false;
    for (final item in o.items) {
      if (ids.contains(item.productId) &&
          item.unit == QuantityUnit.dozen &&
          item.factor == 1) {
        item.unitFactor = kDozen;
        changed = true;
      }
    }
    if (changed) changedOrders.add(o);
  }

  final changedPurchases = <Purchase>[];
  for (final p in purchases) {
    var changed = false;
    for (final item in p.items) {
      if (ids.contains(item.productId) && item.unit == QuantityUnit.dozen) {
        item
          ..unit = QuantityUnit.piece
          ..qty = roundQty(item.qty * kDozen)
          ..unitCost = item.unitCost / kDozen;
        changed = true;
      }
    }
    if (changed) changedPurchases.add(p);
  }

  final changedMovements = <StockMovement>[];
  for (final m in movements) {
    if (!ids.contains(m.productId)) continue;
    m.qty = roundQty(m.qty * kDozen);
    changedMovements.add(m);
  }

  return (
    products: changedProducts,
    orders: changedOrders,
    purchases: changedPurchases,
    movements: changedMovements,
  );
}
