import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/variant_attribute.dart';
import '../models/variant_combination.dart';

const _migrationKey = 'variantsV2Migrated';

/// Migrate old flat ProductVariant data to hierarchical VariantAttribute + VariantCombination.
/// Also migrates OrderItem variantName/variantValue → variantCombinationKey/variantDisplayLabel.
/// Runs once, guarded by a SharedPreferences flag.
Future<void> migrateVariantsV2(Isar isar) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_migrationKey) == true) return;

  debugPrint('[Migration] Running variants V2 migration...');

  await isar.writeTxn(() async {
    // ── Migrate Products ──
    final products = await isar.products.where().findAll();
    for (final product in products) {
      if (product.variants.isEmpty) continue;
      if (product.variantCombinations.isNotEmpty) continue; // already done

      // Group old flat variants by attribute name
      final grouped = <String, List<String>>{};
      for (final v in product.variants) {
        if (v.name.isEmpty || v.value.isEmpty) continue;
        grouped.putIfAbsent(v.name, () => []).add(v.value);
      }

      // Build VariantAttributes
      final attributes = grouped.entries
          .map((e) => VariantAttribute(name: e.key, options: e.value))
          .toList();

      // Each old flat variant becomes a single-attribute combination
      final combinations = product.variants
          .where((v) => v.name.isNotEmpty && v.value.isNotEmpty)
          .map((v) => VariantCombination(
                combinationKey: '${v.name}:${v.value}',
                displayLabel: '${v.name}: ${v.value}',
                priceAdjustment: v.priceAdjustment,
                stockQty: v.stockQty,
                sku: v.sku,
                isActive: true,
              ))
          .toList();

      await isar.products.put(product.copyWith(
        variantAttributes: attributes,
        variantCombinations: combinations,
      ));
    }

    // ── Migrate OrderItems ──
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
