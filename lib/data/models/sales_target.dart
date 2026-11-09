import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sales_target.g.dart';

@collection
@JsonSerializable()
class SalesTarget {
  SalesTarget({
    this.id = Isar.autoIncrement,
    required this.year,
    required this.month,
    this.revenueTarget = 0,
    this.profitTarget = 0,
    this.orderCountTarget = 0,
    this.productTargets = const [],
    this.createdAt,
    this.updatedAt,
  });

  Id id;
  int year;
  int month;
  double revenueTarget;
  double profitTarget;
  int orderCountTarget;
  List<ProductTarget> productTargets;
  DateTime? createdAt;
  DateTime? updatedAt;

  bool get hasAnyTarget =>
      revenueTarget > 0 ||
      profitTarget > 0 ||
      orderCountTarget > 0 ||
      productTargets.any((t) => t.targetQty > 0);

  SalesTarget copyWith({
    Id? id,
    int? year,
    int? month,
    double? revenueTarget,
    double? profitTarget,
    int? orderCountTarget,
    List<ProductTarget>? productTargets,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      SalesTarget(
        id: id ?? this.id,
        year: year ?? this.year,
        month: month ?? this.month,
        revenueTarget: revenueTarget ?? this.revenueTarget,
        profitTarget: profitTarget ?? this.profitTarget,
        orderCountTarget: orderCountTarget ?? this.orderCountTarget,
        productTargets: productTargets ?? this.productTargets,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory SalesTarget.fromJson(Map<String, dynamic> json) =>
      _$SalesTargetFromJson(json);
  Map<String, dynamic> toJson() => _$SalesTargetToJson(this);
}

@embedded
@JsonSerializable()
class ProductTarget {
  ProductTarget({
    this.productId = 0,
    this.productName = '',
    this.targetQty = 0,
  });

  int productId;
  String productName;
  int targetQty;

  factory ProductTarget.fromJson(Map<String, dynamic> json) =>
      _$ProductTargetFromJson(json);
  Map<String, dynamic> toJson() => _$ProductTargetToJson(this);
}
