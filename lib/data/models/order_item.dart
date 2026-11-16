import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

import 'quantity_unit.dart';

part 'order_item.g.dart';

@embedded
@JsonSerializable()
class OrderItem {
  OrderItem({
    this.productId = 0,
    this.productName = '',
    this.productSku = '',
    this.qty = 1,
    this.unit = QuantityUnit.piece,
    this.unitPrice = 0.0,
    this.costPrice = 0.0,
    this.totalPrice = 0.0,
    this.variantName = '',
    this.variantValue = '',
    this.variantCombinationKey = '',
    this.variantDisplayLabel = '',
  });

  int productId;
  String productName;
  String productSku;

  /// In [unit]s, rounded to 3 decimals. Stored as `quantity`; the int it
  /// replaced is still read as [legacyQty] by the one-time migration.
  @Name('quantity')
  double qty;

  /// The product's unit when the order was taken, so the receipt still says
  /// "1.25 kg" if the product's unit is changed later. Older items: piece.
  @Enumerated(EnumType.name)
  @JsonKey(unknownEnumValue: QuantityUnit.piece)
  QuantityUnit unit;

  @Name('qty')
  @JsonKey(includeFromJson: false, includeToJson: false)
  int legacyQty = 0;

  /// Per one [unit].
  double unitPrice;
  double costPrice;
  double totalPrice;

  String variantName;
  String variantValue;

  String variantCombinationKey;

  String variantDisplayLabel;

  @ignore
  bool get hasVariant =>
      variantCombinationKey.isNotEmpty ||
      (variantName.isNotEmpty && variantValue.isNotEmpty);

  @ignore
  String get displayName {
    if (variantDisplayLabel.isNotEmpty) {
      return '$productName ($variantDisplayLabel)';
    }
    if (variantName.isNotEmpty && variantValue.isNotEmpty) {
      return '$productName ($variantName: $variantValue)';
    }
    return productName;
  }

  OrderItem copyWith({
    int? productId,
    String? productName,
    String? productSku,
    double? qty,
    QuantityUnit? unit,
    double? unitPrice,
    double? costPrice,
    double? totalPrice,
    String? variantName,
    String? variantValue,
    String? variantCombinationKey,
    String? variantDisplayLabel,
  }) =>
      OrderItem(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        productSku: productSku ?? this.productSku,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        unitPrice: unitPrice ?? this.unitPrice,
        costPrice: costPrice ?? this.costPrice,
        totalPrice: totalPrice ?? this.totalPrice,
        variantName: variantName ?? this.variantName,
        variantValue: variantValue ?? this.variantValue,
        variantCombinationKey:
            variantCombinationKey ?? this.variantCombinationKey,
        variantDisplayLabel: variantDisplayLabel ?? this.variantDisplayLabel,
      );

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
}
