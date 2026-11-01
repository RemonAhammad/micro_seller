import '../../data/models/variant_attribute.dart';
import '../../data/models/variant_combination.dart';

String buildCombinationKey(Map<String, String> selections) {
  final sorted = selections.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return sorted.map((e) => '${e.key}:${e.value}').join('/');
}

String buildDisplayLabel(Map<String, String> selections) {
  return selections.entries.map((e) => '${e.key}: ${e.value}').join(' / ');
}

List<VariantCombination> generateCombinations(
  List<VariantAttribute> attributes, {
  List<VariantCombination> existing = const [],
  String baseSku = '',
}) {
  if (attributes.isEmpty) return [];

  final validAttrs = attributes
      .where((a) => a.name.isNotEmpty && a.options.isNotEmpty)
      .toList();
  if (validAttrs.isEmpty) return [];

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

  final existingMap = {
    for (final c in existing) c.combinationKey: c,
  };

  return cartesian.map((selections) {
    final key = buildCombinationKey(selections);
    final label = buildDisplayLabel(selections);
    final old = existingMap[key];

    final autoSku = baseSku.isNotEmpty
        ? '$baseSku-${selections.values.map((v) => v.toUpperCase().replaceAll(' ', '')).join('-')}'
        : '';

    if (old != null) {

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
