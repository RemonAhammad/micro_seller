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
  });

  int productId;
  String productName;
  String productSku;
  int qty;
  double unitPrice;
  double costPrice;
  double totalPrice;

  OrderItem copyWith({
    int? productId,
    String? productName,
    String? productSku,
    int? qty,
    double? unitPrice,
    double? costPrice,
    double? totalPrice,
  }) =>
      OrderItem(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        productSku: productSku ?? this.productSku,
        qty: qty ?? this.qty,
        unitPrice: unitPrice ?? this.unitPrice,
        costPrice: costPrice ?? this.costPrice,
        totalPrice: totalPrice ?? this.totalPrice,
      );

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
}
