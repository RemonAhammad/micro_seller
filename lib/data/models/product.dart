import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'product_variant.dart';
import 'variant_attribute.dart';
import 'variant_combination.dart';

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
    this.variants = const [],
    this.variantAttributes = const [],
    this.variantCombinations = const [],
    this.supplierId = 0,
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
  // Active products by name — the products list's where-clause.
  // The name part must be a value index (strings default to hash, which
  // has no order).
  @Index(composite: [CompositeIndex('name', type: IndexType.value)])
  bool isActive;

  /// @deprecated — kept for migration from flat variants
  List<ProductVariant> variants;

  /// Hierarchical variant attribute definitions (e.g. Size→[S,M,L], Color→[Red,Blue])
  List<VariantAttribute> variantAttributes;

  /// All sellable combinations with per-combo stock/price/sku
  List<VariantCombination> variantCombinations;

  /// Optional primary supplier id (0 = no supplier linked)
  int supplierId;

  DateTime? createdAt;
  DateTime? updatedAt;

  @ignore
  double get profitMargin => sellingPrice > 0
      ? ((sellingPrice - costPrice) / sellingPrice) * 100
      : 0;

  @ignore
  bool get isLowStock => hasVariants
      ? variantCombinations.any((c) => c.isActive && c.stockQty > 0 && c.stockQty <= lowStockThreshold)
      : stockQty > 0 && stockQty <= lowStockThreshold;

  @ignore
  bool get isOutOfStock => hasVariants
      ? variantCombinations.where((c) => c.isActive).every((c) => c.stockQty <= 0)
      : stockQty <= 0;

  @ignore
  bool get hasVariants => variantCombinations.isNotEmpty;

  /// Total stock across all active combinations (if variants exist) or base stockQty
  @ignore
  int get totalStock => hasVariants
      ? variantCombinations.where((c) => c.isActive).fold(0, (s, c) => s + c.stockQty)
      : stockQty;

  /// Find a specific combination by its canonical key
  VariantCombination? findCombination(String key) =>
      variantCombinations.where((c) => c.combinationKey == key).firstOrNull;

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
    List<ProductVariant>? variants,
    List<VariantAttribute>? variantAttributes,
    List<VariantCombination>? variantCombinations,
    int? supplierId,
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
        variants: variants ?? this.variants,
        variantAttributes: variantAttributes ?? this.variantAttributes,
        variantCombinations: variantCombinations ?? this.variantCombinations,
        supplierId: supplierId ?? this.supplierId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
