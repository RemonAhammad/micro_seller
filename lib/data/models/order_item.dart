import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_item.g.dart';

@embedded
@JsonSerializable()
class OrderItem {
  OrderItem({
    this.productId = 0,
    this.productName = '',
    this.productSku = '',
    this.qty = 1,
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
  int qty;
  double unitPrice;
  double costPrice;
  double totalPrice;

  /// @deprecated — kept for backward compat with old flat variants
  String variantName;
  String variantValue;

  /// Canonical combination key: "Color:Red/Size:L"
  String variantCombinationKey;

  /// Human-readable label stored at order time: "Size: L / Color: Red"
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
    int? qty,
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
