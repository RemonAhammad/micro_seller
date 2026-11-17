import 'package:flutter_test/flutter_test.dart';

import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/variant_combination.dart';

/// The variation-based low-stock helpers on Product: which variations are low
/// or out of stock, and whether a product should surface in the low-stock list.
void main() {
  Product variant(List<VariantCombination> combos, {double threshold = 5}) => Product(
      name: 'T-Shirt',
      sellingPrice: 500,
      lowStockThreshold: threshold,
      variantCombinations: combos);

  group('Product low-stock variations', () {
    test('a plain product falls back to isLowStock / isOutOfStock', () {
      final low = Product(name: 'Pen', sellingPrice: 5, stockQty: 2, lowStockThreshold: 5);
      expect(low.lowStockCombinations, isEmpty);
      expect(low.outOfStockCombinations, isEmpty);
      expect(low.needsStockAttention, isTrue);

      final out = Product(name: 'Pen', sellingPrice: 5, stockQty: 0, lowStockThreshold: 5);
      expect(out.needsStockAttention, isTrue);

      final healthy = Product(name: 'Pen', sellingPrice: 5, stockQty: 20, lowStockThreshold: 5);
      expect(healthy.needsStockAttention, isFalse);
    });

    test('names the low and out-of-stock variations, ignores healthy ones', () {
      final p = variant([
        VariantCombination(combinationKey: 'Size:S', displayLabel: 'Size: S', stockQty: 20),
        VariantCombination(combinationKey: 'Size:M', displayLabel: 'Size: M', stockQty: 0),
        VariantCombination(combinationKey: 'Size:L', displayLabel: 'Size: L', stockQty: 2),
      ]);

      expect(p.lowStockCombinations.map((c) => c.displayLabel), ['Size: L']);
      expect(p.outOfStockCombinations.map((c) => c.displayLabel), ['Size: M']);
      expect(p.needsStockAttention, isTrue);
    });

    test('a single out-of-stock variation surfaces even when others are healthy', () {
      // isLowStock is false (no combo in the low band) and isOutOfStock is
      // false (not all out), yet the product must still appear.
      final p = variant([
        VariantCombination(combinationKey: 'Size:S', displayLabel: 'Size: S', stockQty: 30),
        VariantCombination(combinationKey: 'Size:M', displayLabel: 'Size: M', stockQty: 0),
      ]);

      expect(p.isLowStock, isFalse);
      expect(p.isOutOfStock, isFalse);
      expect(p.outOfStockCombinations.map((c) => c.displayLabel), ['Size: M']);
      expect(p.needsStockAttention, isTrue);
    });

    test('inactive combinations are ignored', () {
      final p = variant([
        VariantCombination(combinationKey: 'Size:S', displayLabel: 'Size: S', stockQty: 0, isActive: false),
        VariantCombination(combinationKey: 'Size:M', displayLabel: 'Size: M', stockQty: 20),
      ]);
      expect(p.lowStockCombinations, isEmpty);
      expect(p.outOfStockCombinations, isEmpty);
      expect(p.needsStockAttention, isFalse);
    });

    test('all variations healthy → no attention', () {
      final p = variant([
        VariantCombination(combinationKey: 'Size:S', displayLabel: 'Size: S', stockQty: 10),
        VariantCombination(combinationKey: 'Size:M', displayLabel: 'Size: M', stockQty: 8),
      ]);
      expect(p.needsStockAttention, isFalse);
    });
  });
}
