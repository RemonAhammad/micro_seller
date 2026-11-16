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

  String combinationKey;

  String displayLabel;

  double priceAdjustment;

  /// In the product's unit (see `Product.stockQty` for the stored name).
  @Name('stockQuantity')
  double stockQty;

  /// The whole-number stock of older versions, for the one-time migration.
  @Name('stockQty')
  @JsonKey(includeFromJson: false, includeToJson: false)
  int legacyStockQty = 0;

  String sku;
  bool isActive;

  VariantCombination copyWith({
    String? combinationKey,
    String? displayLabel,
    double? priceAdjustment,
    double? stockQty,
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
