import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@collection
@JsonSerializable()
class Product {
  Product({
    this.id = Isar.autoIncrement,
    required this.name,
    this.sku = '',
    this.description = '',
    this.imagePath = '',
    required this.sellingPrice,
    this.costPrice = 0.0,
    this.stockQty = 0,
    this.lowStockThreshold = 10,
    this.category = '',
    this.qrCode = '',
    this.tags = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  Id id;
  String name;
  String sku;
  String description;
  String imagePath;
  double sellingPrice;
  double costPrice;
  int stockQty;
  int lowStockThreshold;
  String category;
  String qrCode;
  List<String> tags;
  bool isActive;
  DateTime? createdAt;
  DateTime? updatedAt;

  @ignore
  double get profitMargin => sellingPrice > 0
      ? ((sellingPrice - costPrice) / sellingPrice) * 100
      : 0;

  @ignore
  bool get isLowStock => stockQty > 0 && stockQty <= lowStockThreshold;

  @ignore
  bool get isOutOfStock => stockQty <= 0;

  Product copyWith({
    Id? id,
    String? name,
    String? sku,
    String? description,
    String? imagePath,
    double? sellingPrice,
    double? costPrice,
    int? stockQty,
    int? lowStockThreshold,
    String? category,
    String? qrCode,
    List<String>? tags,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        description: description ?? this.description,
        imagePath: imagePath ?? this.imagePath,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        costPrice: costPrice ?? this.costPrice,
        stockQty: stockQty ?? this.stockQty,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        category: category ?? this.category,
        qrCode: qrCode ?? this.qrCode,
        tags: tags ?? this.tags,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
