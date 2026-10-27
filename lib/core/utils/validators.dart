import 'number_input.dart';

class Validators {
  Validators._();

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String fieldName = 'Amount']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final parsed = NumberInput.parseDecimal(value);
    if (parsed == null) {
      return 'Please enter a valid number';
    }
    if (parsed < 0) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  static String? nonNegativeInt(String? value,
      [String fieldName = 'Quantity']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final parsed = NumberInput.parseInteger(value);
    if (parsed == null) {
      return 'Please enter a valid whole number';
    }
    if (parsed < 0) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = NumberInput.toAsciiDigits(value)
        .replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.length < 7 || cleaned.length > 15) {
      return 'Please enter a valid phone number';
    }
    if (!RegExp(r'^[+]?\d+$').hasMatch(cleaned)) {
      return 'Phone number can only contain digits, +, -, spaces';
    }
    return null;
  }

  static String? sku(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'SKU is required';
    }
    if (value.trim().length < 2) {
      return 'SKU must be at least 2 characters';
    }
    return null;
  }

  /// Validates that cost price is not greater than selling price.
  static String? costPriceNotExceedingSelling(
      String? costValue, String? sellingValue) {
    if (costValue == null || costValue.trim().isEmpty) return null;
    final cost = NumberInput.parseDecimal(costValue);
    final selling = NumberInput.parseDecimal(sellingValue);
    if (cost == null || selling == null) return null;
    if (cost > selling) {
      return 'Cost price exceeds selling price';
    }
    return null;
  }
}
