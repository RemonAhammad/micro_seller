import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'promotion.g.dart';

@collection
@JsonSerializable()
class Promotion {
  Promotion({
    this.id = Isar.autoIncrement,
    this.title = '',
    this.type = 'discount',
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.couponCode = '',
    this.productIds = const [],
    this.productNames = const [],
    this.message = '',
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Id id;
  String title;
  String type;
  double discountPercent;
  double discountAmount;
  String couponCode;
  List<int> productIds;
  List<String> productNames;
  String message;
  DateTime? startDate;
  DateTime? endDate;
  bool isActive;
  DateTime? createdAt;
  DateTime? updatedAt;

  @ignore
  bool get isExpired =>
      endDate != null && endDate!.isBefore(DateTime.now());

  @ignore
  String get discountLabel => discountPercent > 0
      ? '${discountPercent.toStringAsFixed(0)}% OFF'
      : discountAmount > 0
          ? '${discountAmount.toStringAsFixed(0)} OFF'
          : '';

  @ignore
  bool get isStoreWide => productIds.isEmpty;

  Promotion copyWith({
    Id? id,
    String? title,
    String? type,
    double? discountPercent,
    double? discountAmount,
    String? couponCode,
    List<int>? productIds,
    List<String>? productNames,
    String? message,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Promotion(
        id: id ?? this.id,
        title: title ?? this.title,
        type: type ?? this.type,
        discountPercent: discountPercent ?? this.discountPercent,
        discountAmount: discountAmount ?? this.discountAmount,
        couponCode: couponCode ?? this.couponCode,
        productIds: productIds ?? this.productIds,
        productNames: productNames ?? this.productNames,
        message: message ?? this.message,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Promotion.fromJson(Map<String, dynamic> json) =>
      _$PromotionFromJson(json);
  Map<String, dynamic> toJson() => _$PromotionToJson(this);
}
