import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'variant_combination.g.dart';

@embedded
@JsonSerializable()
class VariantCombination {
  VariantCombination({
    this.combinationKey = '',
    this.displayLabel = '',
    this.priceAdjustment = 0.0,
    this.stockQty = 0,
    this.sku = '',
    this.isActive = true,
  });

  /// Canonical sorted key: "Color:Red/Size:L"
  String combinationKey;

  /// Human-readable: "Size: L / Color: Red"
  String displayLabel;

  double priceAdjustment;
  int stockQty;
  String sku;
  bool isActive;

  VariantCombination copyWith({
    String? combinationKey,
    String? displayLabel,
    double? priceAdjustment,
    int? stockQty,
    String? sku,
    bool? isActive,
  }) =>
      VariantCombination(
        combinationKey: combinationKey ?? this.combinationKey,
        displayLabel: displayLabel ?? this.displayLabel,
        priceAdjustment: priceAdjustment ?? this.priceAdjustment,
        stockQty: stockQty ?? this.stockQty,
        sku: sku ?? this.sku,
        isActive: isActive ?? this.isActive,
      );

  factory VariantCombination.fromJson(Map<String, dynamic> json) =>
      _$VariantCombinationFromJson(json);
  Map<String, dynamic> toJson() => _$VariantCombinationToJson(this);
}
