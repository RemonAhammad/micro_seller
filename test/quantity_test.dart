import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:micro_seller/core/utils/number_input.dart';
import 'package:micro_seller/core/utils/quantity.dart';
import 'package:micro_seller/core/utils/quantity_input.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/quantity_unit.dart';

void main() {
  group('roundQty', () {
    test('rounds to grams and never drifts', () {
      expect(roundQty(1.23456), 1.235);
      expect(roundQty(0.1 + 0.2), 0.3);
      var stock = 5.0;
      for (var i = 0; i < 100; i++) {
        stock = roundQty(stock - 0.1);
      }
      expect(stock, -5.0);
    });

    test('a value that rounds to nothing is 0, not -0', () {
      expect(roundQty(-0.0001).isNegative, isFalse);
      expect(formatQtyNumber(-0.0001), '0');
    });
  });

  group('comparisons', () {
    test('the last 1.25 kg of 1.25 kg can be sold', () {
      expect(qtyAtLeast(1.25, 1.25), isTrue);
      expect(qtyExceeds(1.25, 1.25), isFalse);
      expect(qtyExceeds(1.2504, 1.25), isFalse, reason: 'within rounding');
      expect(qtyExceeds(1.251, 1.25), isTrue);
    });

    test('isWholeQty', () {
      expect(isWholeQty(3.0), isTrue);
      expect(isWholeQty(2.9999), isTrue);
      expect(isWholeQty(2.5), isFalse);
    });
  });

  group('text', () {
    test('formatQtyNumber drops trailing zeros and groups thousands', () {
      expect(formatQtyNumber(3), '3');
      expect(formatQtyNumber(1.250), '1.25');
      expect(formatQtyNumber(0.333), '0.333');
      expect(formatQtyNumber(1250.5), '1,250.5');
    });

    test('qtyFieldText has no grouping, so the field reads it back', () {
      expect(qtyFieldText(1250.5), '1250.5');
      expect(NumberInput.parseDecimal(qtyFieldText(1250.5)), 1250.5);
    });

    test('documentQty / documentPricePer', () {
      expect(documentQty(3, QuantityUnit.piece), '3');
      expect(documentQty(1.25, QuantityUnit.kg), '1.25 kg');
      expect(documentQty(2, QuantityUnit.dozen), '2 dozen');
      expect(documentPricePer('৳600', QuantityUnit.kg), '৳600/kg');
      expect(documentPricePer('৳600', QuantityUnit.piece), '৳600');
    });

    test('qtyCell writes whole numbers without .0', () {
      expect(qtyCell(5.0), 5);
      expect(qtyCell(5.0), isA<int>());
      expect(qtyCell(1.25), 1.25);
    });
  });

  group('units', () {
    test('only kg, litre and metre take decimals', () {
      expect(
        QuantityUnit.values.where((u) => u.allowsDecimal),
        [QuantityUnit.kg, QuantityUnit.litre, QuantityUnit.metre],
      );
    });

    test('a decimal field takes 3 decimals, a counted one whole numbers', () {
      TextEditingValue type(List<TextInputFormatter> fs, String text) {
        var value = TextEditingValue.empty;
        for (final ch in text.split('')) {
          final next = TextEditingValue(
            text: value.text + ch,
            selection: TextSelection.collapsed(offset: value.text.length + 1),
          );
          value = fs.fold(next, (v, f) => f.formatEditUpdate(value, v));
        }
        return value;
      }

      expect(type(qtyFormatters(QuantityUnit.kg), '1.2505').text, '1.250');
      expect(type(qtyFormatters(QuantityUnit.piece), '1.5').text, '15');
    });

    test('parseQty', () {
      expect(parseQty('1.25', QuantityUnit.kg), 1.25);
      expect(parseQty('3', QuantityUnit.piece), 3.0);
      expect(parseQty('', QuantityUnit.kg), isNull);
      expect(parseQty('١٫٥', QuantityUnit.kg), 1.5, reason: 'Arabic digits and mark');
    });
  });

  group('money', () {
    test('lineTotal: whole quantities multiply as before, decimals round', () {
      expect(lineTotal(19.99, 3), 19.99 * 3);
      expect(lineTotal(615.5, 1.25), 769.38);
      expect(lineTotal(600, 0.333), 199.8);
    });

    test('by amount: ৳200 of fish at ৳600/kg', () {
      expect(roundQty(200 / 600), 0.333);
    });

    test('cartItemCount: pieces add up, kilograms count as lines', () {
      OrderItem item(double qty) => OrderItem(qty: qty);
      expect(cartItemCount([item(3), item(2)]), 5);
      expect(cartItemCount([item(1.25), item(2)]), 2);
      expect(Order(orderNumber: 'X', items: [item(3), item(2)]).totalItems, 5);
    });
  });
}
