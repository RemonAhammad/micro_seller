import '../../data/models/variant_attribute.dart';
import '../../data/models/variant_combination.dart';

/// Build a canonical combination key from attribute selections.
/// Sorted alphabetically by attribute name to ensure consistency.
/// Example: {"Size": "L", "Color": "Red"} → "Color:Red/Size:L"
String buildCombinationKey(Map<String, String> selections) {
  final sorted = selections.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return sorted.map((e) => '${e.key}:${e.value}').join('/');
}

/// Build a human-readable display label from selections.
/// Example: {"Size": "L", "Color": "Red"} → "Size: L / Color: Red"
String buildDisplayLabel(Map<String, String> selections) {
  return selections.entries.map((e) => '${e.key}: ${e.value}').join(' / ');
}

/// Generate the cartesian product of all variant attributes as combinations.
/// Preserves existing combination values (stock, price, sku) if they match.
List<VariantCombination> generateCombinations(
  List<VariantAttribute> attributes, {
  List<VariantCombination> existing = const [],
  String baseSku = '',
}) {
  if (attributes.isEmpty) return [];

  // Filter out attributes with no valid options
  final validAttrs = attributes
      .where((a) => a.name.isNotEmpty && a.options.isNotEmpty)
      .toList();
  if (validAttrs.isEmpty) return [];

  // Build cartesian product
  List<Map<String, String>> cartesian = [{}];
  for (final attr in validAttrs) {
    final expanded = <Map<String, String>>[];
    for (final combo in cartesian) {
      for (final option in attr.options) {
        if (option.isEmpty) continue;
        expanded.add({...combo, attr.name: option});
      }
    }
    cartesian = expanded;
  }

  // Build existing lookup by key
  final existingMap = {
    for (final c in existing) c.combinationKey: c,
  };

  // Generate combinations, preserving existing values
  return cartesian.map((selections) {
    final key = buildCombinationKey(selections);
    final label = buildDisplayLabel(selections);
    final old = existingMap[key];

    // Auto-generate SKU from base SKU + option values
    final autoSku = baseSku.isNotEmpty
        ? '$baseSku-${selections.values.map((v) => v.toUpperCase().replaceAll(' ', '')).join('-')}'
        : '';

    if (old != null) {
      // Preserve existing values, update label in case attribute order changed
      return old.copyWith(displayLabel: label);
    }
    return VariantCombination(
      combinationKey: key,
      displayLabel: label,
      stockQty: 0,
      priceAdjustment: 0,
      sku: autoSku,
      isActive: true,
    );
  }).toList();
}
