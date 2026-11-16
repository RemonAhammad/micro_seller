import 'package:intl/intl.dart';

import '../../data/models/quantity_unit.dart';

/// Quantities are doubles rounded to 3 decimals (a gram of a kilogram, a
/// millimetre of a metre). Every write goes through [roundQty], so sums of
/// many sales don't drift (0.1 + 0.2 = 0.30000000000000004), and every
/// comparison against stock allows [kQtyEpsilon].
const kQtyDecimals = 3;

/// Half the smallest step: two quantities closer than this are equal.
const kQtyEpsilon = 0.0005;

double roundQty(num qty) {
  final rounded = (qty * 1000).round() / 1000;
  // -0.0 prints as "-0"; a quantity that rounds to nothing is 0.
  return rounded == 0 ? 0 : rounded;
}

/// True when [qty] has nothing after the point (within [kQtyEpsilon]).
bool isWholeQty(num qty) => (qty - qty.roundToDouble()).abs() < kQtyEpsilon;

/// [a] ≥ [b], allowing for rounding: selling the last 1.25 kg of 1.25 kg
/// stock must pass.
bool qtyAtLeast(num a, num b) => a > b - kQtyEpsilon;

/// [a] > [b] by more than rounding.
bool qtyExceeds(num a, num b) => a > b + kQtyEpsilon;

final _qtyFormat = NumberFormat('#,##0.###', 'en_US');
final _qtyPlain = NumberFormat('0.###', 'en_US');

/// "3", "1.25", "1,250.5": the number alone, up to 3 decimals, no trailing
/// zeros. ASCII digits, like `CurrencyFormatter`.
String formatQtyNumber(num qty) => _qtyFormat.format(roundQty(qty));

/// "3", "1.25 kg" with the English sign, for the invoice, WhatsApp text and
/// POS slip (see `QuantityUnit.documentSymbol`).
String documentQty(num qty, QuantityUnit unit) {
  final number = formatQtyNumber(qty);
  final symbol = unit.documentSymbol;
  return symbol.isEmpty ? number : '$number $symbol';
}

/// "৳600/kg"; a piece price unchanged.
String documentPricePer(String price, QuantityUnit unit) {
  final symbol = unit.documentSymbol;
  return symbol.isEmpty ? price : '$price/$symbol';
}

/// The text a quantity field starts with: no grouping, so the field's
/// formatter reads it back as the same number.
String qtyFieldText(num qty) => _qtyPlain.format(roundQty(qty));

/// Stock after a change: rounded, never below 0 (a sale can't take more than
/// there is), capped where the stock fields always were.
double clampStock(num qty) => roundQty(qty.clamp(0, 999999));

/// A quantity for a CSV cell: `5`, not `5.0`; `1.25` stays.
num qtyCell(num qty) => isWholeQty(qty) ? wholeQty(qty) : roundQty(qty);

/// A whole quantity as an int, for the places that still count pieces
/// (`+1` steps, item badges); a decimal one rounds to the nearest.
int wholeQty(num qty) => qty.round();
