import 'package:flutter/services.dart';

import '../../data/models/quantity_unit.dart';
import 'number_input.dart';
import 'quantity.dart';

/// A quantity field for [unit]: decimals for weighed and measured goods
/// (1.25 kg), whole numbers for counted ones, as the stock fields always were.
List<TextInputFormatter> qtyFormatters(QuantityUnit unit) => unit.allowsDecimal
    ? const [DecimalInputFormatter.quantity()]
    : const [IntegerInputFormatter()];

TextInputType qtyKeyboard(QuantityUnit unit) => unit.allowsDecimal
    ? const TextInputType.numberWithOptions(decimal: true)
    : TextInputType.number;

/// The field's text as a quantity, rounded to 3 decimals; null when it holds
/// none (or decimals in a counted field, which its validator reports).
double? parseQty(String text, QuantityUnit unit) {
  final value = unit.allowsDecimal
      ? NumberInput.parseDecimal(text)
      : NumberInput.parseInteger(text)?.toDouble();
  return value == null ? null : roundQty(value);
}
