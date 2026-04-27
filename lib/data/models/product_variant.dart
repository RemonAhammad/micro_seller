import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product_variant.g.dart';

@embedded
@JsonSerializable()
class ProductVariant {
  ProductVariant({
    this.name = '',
    this.value = '',
    this.priceAdjustment = 0.0,
    this.stockQty = 0,
    this.sku = '',
  });

  String name;    // e.g. "Size", "Color"
  String value;   // e.g. "Large", "Red"
  double priceAdjustment; // +/- from base price
  int stockQty;
  String sku;     // variant-specific SKU

  ProductVariant copyWith({
    String? name,
    String? value,
    double? priceAdjustment,
    int? stockQty,
    String? sku,
  }) =>
      ProductVariant(
        name: name ?? this.name,
        value: value ?? this.value,
        priceAdjustment: priceAdjustment ?? this.priceAdjustment,
        stockQty: stockQty ?? this.stockQty,
        sku: sku ?? this.sku,
      );

  factory ProductVariant.fromJson(Map<String, dynamic> json) =>
      _$ProductVariantFromJson(json);
  Map<String, dynamic> toJson() => _$ProductVariantToJson(this);
}
