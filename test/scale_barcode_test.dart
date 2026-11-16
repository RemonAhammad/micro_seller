import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/core/utils/scale_barcode.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/quantity_unit.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/repositories/product_repository.dart';

import 'support/isar_core.dart';

/// [first12] with its EAN-13 check digit appended.
String ean13(String first12) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final d = int.parse(first12[i]);
    sum += i.isEven ? d : d * 3;
  }
  return '$first12${(10 - sum % 10) % 10}';
}

void main() {
  const weight = ScaleLabelSettings(enabled: true);
  const price = ScaleLabelSettings(enabled: true, value: ScaleLabelValue.price);
  const priceWhole = ScaleLabelSettings(enabled: true, value: ScaleLabelValue.priceWhole);

  group('ean13CheckDigitValid', () {
    test('accepts a real EAN-13 and rejects a changed digit', () {
      expect(ean13CheckDigitValid('4006381333931'), isTrue);
      expect(ean13CheckDigitValid('4006381333932'), isFalse);
      expect(ean13CheckDigitValid('400638133393'), isFalse, reason: '12 digits');
    });
  });

  group('parseScaleLabel', () {
    test('weight: 2X | 12345 | 01250 | C is item 12345, 1.25 kg', () {
      final label = parseScaleLabel(ean13('211234501250'), weight)!;
      expect(label.itemCode, '12345');
      expect(label.weightKg, 1.25);
      expect(label.price, isNull);
    });

    test('price with 2 decimals, and whole price', () {
      expect(parseScaleLabel(ean13('211234581250'), price)!.price, 812.5);
      expect(parseScaleLabel(ean13('211234500812'), priceWhole)!.price, 812);
    });

    test('item code length moves the split', () {
      final four = parseScaleLabel(ean13('201234012500'), const ScaleLabelSettings(enabled: true, itemCodeDigits: 4))!;
      expect(four.itemCode, '1234');
      expect(four.weightKg, 12.5);
      final six = parseScaleLabel(ean13('201234560125'), const ScaleLabelSettings(enabled: true, itemCodeDigits: 6))!;
      expect(six.itemCode, '123456');
      expect(six.weightKg, 0.125);
    });

    test('not a label: off, not starting with 2, wrong length or check digit', () {
      final good = ean13('211234501250');
      expect(parseScaleLabel(good, const ScaleLabelSettings()), isNull);
      expect(parseScaleLabel(ean13('401234501250'), weight), isNull);
      expect(parseScaleLabel('21123450125', weight), isNull);
      final badCheck = good.substring(0, 12) + ((int.parse(good[12]) + 1) % 10).toString();
      expect(parseScaleLabel(badCheck, weight), isNull);
      expect(parseScaleLabel('hello', weight), isNull);
    });

    test('spaces and other scripts\' digits are read', () {
      final code = ean13('211234501250');
      const bengali = '০১২৩৪৫৬৭৮৯';
      final inBengali = code.split('').map((d) => bengali[int.parse(d)]).join();
      expect(parseScaleLabel(' $inBengali ', weight)!.weightKg, 1.25);
    });

    test('itemCodeForms adds the code without leading zeros', () {
      expect(const ScaleLabel(itemCode: '00123').itemCodeForms, ['00123', '123']);
      expect(const ScaleLabel(itemCode: '12345').itemCodeForms, ['12345']);
      expect(const ScaleLabel(itemCode: '00000').itemCodeForms, ['00000']);
    });
  });

  group('ScaleLabel.qtyFor', () {
    Product p(QuantityUnit unit, {double price = 650, bool variants = false}) => Product(
          name: 'Fish',
          sellingPrice: price,
          unit: unit,
          variantCombinations: variants ? [VariantCombination(combinationKey: 'Cut:Steak')] : const [],
        );

    test('a weight fills a kg product, and a gram product in grams', () {
      const label = ScaleLabel(itemCode: '1', weightKg: 1.25);
      expect(label.qtyFor(p(QuantityUnit.kg)), 1.25);
      expect(label.qtyFor(p(QuantityUnit.g)), 1250);
      expect(label.qtyFor(p(QuantityUnit.piece)), isNull);
    });

    test('a price buys its weight at the product\'s price', () {
      const label = ScaleLabel(itemCode: '1', price: 812.5);
      expect(label.qtyFor(p(QuantityUnit.kg)), 1.25);
      expect(label.qtyFor(p(QuantityUnit.kg, price: 0)), isNull);
    });

    test('pieces only for a whole number of them', () {
      expect(const ScaleLabel(itemCode: '1', price: 120).qtyFor(p(QuantityUnit.piece, price: 40)), 3);
      expect(const ScaleLabel(itemCode: '1', price: 100).qtyFor(p(QuantityUnit.piece, price: 40)), isNull);
    });

    test('a variant product chooses its combination by hand', () {
      expect(const ScaleLabel(itemCode: '1', weightKg: 1).qtyFor(p(QuantityUnit.kg, variants: true)), isNull);
    });
  });

  group('ScaleLabelSettings', () {
    test('saved and read back; off by default', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ScaleLabelSettings.load(), const ScaleLabelSettings());
      await price.copyWith(itemCodeDigits: 6).save();
      expect(await ScaleLabelSettings.load(), price.copyWith(itemCodeDigits: 6));
    });

    test('wrongly typed or unknown values fall back', () async {
      SharedPreferences.setMockInitialValues({
        ScaleLabelSettings.keyEnabled: 'yes',
        ScaleLabelSettings.keyValue: 'volume',
        ScaleLabelSettings.keyItemCodeDigits: 9,
      });
      expect(await ScaleLabelSettings.load(), const ScaleLabelSettings());
    });
  });

  group('ProductRepository.findByScan', skip: isarSkipReason, () {
    tearDown(closeTestIsars);

    test('a label finds the product by its item code, with or without zeros', () async {
      final isar = await openTestIsar('scan');
      await isar.writeTxn(() async {
        await isar.products.putAll([
          Product(name: 'Rui fish', sellingPrice: 650, qrCode: '12345', unit: QuantityUnit.kg, stockQty: 10),
          Product(name: 'Hilsa', sellingPrice: 1400, sku: '123', unit: QuantityUnit.kg, stockQty: 5),
        ]);
      });
      final repo = ProductRepository(isar);

      final rui = (await repo.findByScan(ean13('211234501250'), weight))!;
      expect(rui.product.name, 'Rui fish');
      expect(rui.label!.qtyFor(rui.product), 1.25);

      final hilsa = (await repo.findByScan(ean13('210012300800'), weight))!;
      expect(hilsa.product.name, 'Hilsa');
      expect(hilsa.label!.qtyFor(hilsa.product), 0.8);

      expect(await repo.findByScan(ean13('211234501250'), const ScaleLabelSettings()), isNull,
          reason: 'labels off: the code is looked up as it is');
    });

    test('a product saved with the whole label code is found as before', () async {
      final isar = await openTestIsar('scan_direct');
      final code = ean13('211234501250');
      await isar.writeTxn(() async {
        await isar.products.put(Product(name: 'Packed rice', sellingPrice: 90, qrCode: code));
      });
      final hit = (await ProductRepository(isar).findByScan(code, weight))!;
      expect(hit.product.name, 'Packed rice');
      expect(hit.label, isNull);
    });
  });
}
