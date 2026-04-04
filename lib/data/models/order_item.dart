import 'package:isar/isar.dart';
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
  });

  int productId;
  String productName;
  String productSku;
  int qty;
  double unitPrice;
  double costPrice;
  double totalPrice;
  String variantName;
  String variantValue;

  @ignore
  bool get hasVariant => variantName.isNotEmpty && variantValue.isNotEmpty;

  @ignore
  String get displayName =>
      hasVariant ? '$productName ($variantName: $variantValue)' : productName;

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
      );

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
}
