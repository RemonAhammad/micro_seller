import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/product.dart';
import '../../data/models/quantity_unit.dart';
import '../../data/models/variant_combination.dart';
import 'number_input.dart';
import 'quantity.dart';

/// What the number on a shop scale's label stands for.
enum ScaleLabelValue {
  /// The weight in grams (01250 = 1.250 kg).
  weight,

  /// The price with 2 decimals (01250 = 12.50).
  price,

  /// The price in whole units (01250 = 1250), as scales set to taka print it.
  priceWhole,
}

/// How this shop's scale prints its labels. Per device (like Display size):
/// it belongs to the scale at this counter, so no backup carries it.
class ScaleLabelSettings {
  const ScaleLabelSettings({
    this.enabled = false,
    this.value = ScaleLabelValue.weight,
    this.itemCodeDigits = 5,
  });

  static const keyEnabled = 'scaleLabelsEnabled';
  static const keyValue = 'scaleLabelsValue';
  static const keyItemCodeDigits = 'scaleLabelsItemCodeDigits';

  /// The item code lengths scales use; the value takes the digits left
  /// between the 2-digit prefix and the check digit.
  static const itemCodeDigitChoices = [4, 5, 6];

  final bool enabled;
  final ScaleLabelValue value;
  final int itemCodeDigits;

  ScaleLabelSettings copyWith({bool? enabled, ScaleLabelValue? value, int? itemCodeDigits}) =>
      ScaleLabelSettings(
        enabled: enabled ?? this.enabled,
        value: value ?? this.value,
        itemCodeDigits: itemCodeDigits ?? this.itemCodeDigits,
      );

  /// Never throws: a missing or foreign value falls back to the default.
  static ScaleLabelSettings fromPrefs(SharedPreferences prefs) {
    final enabled = prefs.get(keyEnabled);
    final value = prefs.get(keyValue);
    final digits = prefs.get(keyItemCodeDigits);
    return ScaleLabelSettings(
      enabled: enabled is bool && enabled,
      value: ScaleLabelValue.values.firstWhere(
        (v) => v.name == value,
        orElse: () => ScaleLabelValue.weight,
      ),
      itemCodeDigits: digits is int && itemCodeDigitChoices.contains(digits) ? digits : 5,
    );
  }

  static Future<ScaleLabelSettings> load() async {
    try {
      return fromPrefs(await SharedPreferences.getInstance());
    } catch (_) {
      return const ScaleLabelSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyEnabled, enabled);
    await prefs.setString(keyValue, value.name);
    await prefs.setInt(keyItemCodeDigits, itemCodeDigits);
  }

  @override
  bool operator ==(Object other) =>
      other is ScaleLabelSettings &&
      other.enabled == enabled &&
      other.value == value &&
      other.itemCodeDigits == itemCodeDigits;

  @override
  int get hashCode => Object.hash(enabled, value, itemCodeDigits);
}

/// A scale label read from its barcode: `2X` + item code + value + check
/// digit, 13 digits (EAN-13 numbers 20–29 are for in-store use).
class ScaleLabel {
  const ScaleLabel({required this.itemCode, this.weightKg, this.price});

  final String itemCode;

  /// Set for a weight label, in kilograms (grams ÷ 1000).
  final double? weightKg;

  /// Set for a price label.
  final double? price;

  /// The spellings a product's code may have: "00123" as printed, and
  /// "123" for a seller who typed the PLU without its leading zeros.
  List<String> get itemCodeForms {
    final trimmed = itemCode.replaceFirst(RegExp('^0+'), '');
    return [itemCode, if (trimmed.isNotEmpty && trimmed != itemCode) trimmed];
  }

  /// How much of [product] the label is for, in the product's unit, or null
  /// when the label can't say (a variant product whose [combination] isn't
  /// known, a piece product on a weight label, a price that isn't a whole
  /// number of pieces, no price). A price label buys at the combination's
  /// price when there is one.
  double? qtyFor(Product product, {VariantCombination? combination}) {
    if (product.hasVariants && combination == null) return null;
    final unit = product.unit;
    final unitPrice = product.sellingPrice + (combination?.priceAdjustment ?? 0);
    double? qty;
    final weight = weightKg;
    final labelPrice = price;
    if (weight != null) {
      qty = switch (unit) {
        QuantityUnit.kg || QuantityUnit.litre || QuantityUnit.metre => weight,
        QuantityUnit.g || QuantityUnit.ml || QuantityUnit.cm => weight * 1000,
        _ => null,
      };
    } else if (labelPrice != null && unitPrice > 0) {
      qty = labelPrice / unitPrice;
      if (unit.isCounted) qty = isWholeQty(qty) ? qty.roundToDouble() : null;
    }
    if (qty == null) return null;
    qty = roundQty(qty);
    return qty > 0 ? qty : null;
  }
}

/// [raw] as a scale label, or null when labels are off or it isn't one:
/// not 13 digits, not starting with 2, or a wrong check digit.
ScaleLabel? parseScaleLabel(String raw, ScaleLabelSettings settings) {
  if (!settings.enabled) return null;
  final code = NumberInput.toAsciiDigits(raw.trim());
  if (!RegExp(r'^2\d{12}$').hasMatch(code)) return null;
  if (!ean13CheckDigitValid(code)) return null;

  final codeEnd = 2 + settings.itemCodeDigits;
  final itemCode = code.substring(2, codeEnd);
  final value = int.parse(code.substring(codeEnd, 12));
  return switch (settings.value) {
    ScaleLabelValue.weight => ScaleLabel(itemCode: itemCode, weightKg: value / 1000),
    ScaleLabelValue.price => ScaleLabel(itemCode: itemCode, price: value / 100),
    ScaleLabelValue.priceWhole => ScaleLabel(itemCode: itemCode, price: value.toDouble()),
  };
}

/// The EAN-13 check: digits weighted 1, 3, 1, 3, … must sum with the check
/// digit to a multiple of 10.
bool ean13CheckDigitValid(String code) {
  if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final d = code.codeUnitAt(i) - 0x30;
    sum += i.isEven ? d : d * 3;
  }
  return (10 - sum % 10) % 10 == code.codeUnitAt(12) - 0x30;
}
