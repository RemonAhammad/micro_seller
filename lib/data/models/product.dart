import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../core/utils/quantity.dart';
import 'product_variant.dart';
import 'quantity_unit.dart';
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
    this.unit = QuantityUnit.piece,
    this.category = '',
    this.qrCode = '',
    this.tags = const [],
    this.isActive = true,
    this.variants = const [],
    this.variantAttributes = const [],
    this.variantCombinations = const [],
    this.supplierId = 0,
    this.expiryDate,
    this.createdAt,
    this.updatedAt,
  });

  Id id;
  String name;
  String sku;
  String description;
  String imagePath;
  /// Per one [unit]: ৳600 is per kg for a kg product.
  double sellingPrice;
  double costPrice;

  /// In [unit]s, rounded to 3 decimals (`roundQty`). Stored as
  /// `stockQuantity`: the int it replaced kept the name `stockQty`, which
  /// [legacyStockQty] still reads for the one-time migration.
  @Name('stockQuantity')
  double stockQty;

  @Name('lowStockLevel')
  double lowStockThreshold;

  /// What [stockQty] and the prices count. Older products have none: piece.
  @Enumerated(EnumType.name)
  @JsonKey(unknownEnumValue: QuantityUnit.piece)
  QuantityUnit unit;

  /// The whole-number stock of versions before decimal quantities, read only
  /// by `migrateDecimalQuantitiesV1`, which moves it into [stockQty] and
  /// sets it back to 0. Never in JSON: backups carry [stockQty].
  @Name('stockQty')
  @JsonKey(includeFromJson: false, includeToJson: false)
  int legacyStockQty = 0;

  @Name('lowStockThreshold')
  @JsonKey(includeFromJson: false, includeToJson: false)
  int legacyLowStockThreshold = 0;

  String category;
  String qrCode;
  List<String> tags;

  @Index(composite: [CompositeIndex('name', type: IndexType.value)])
  bool isActive;

  List<ProductVariant> variants;

  List<VariantAttribute> variantAttributes;

  List<VariantCombination> variantCombinations;

  int supplierId;

  DateTime? expiryDate;
  DateTime? createdAt;
  DateTime? updatedAt;

  @ignore
  double get profitMargin => sellingPrice > 0
      ? ((sellingPrice - costPrice) / sellingPrice) * 100
      : 0;

  @ignore
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  @ignore
  bool get isNearExpiry => expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(DateTime.now()).inDays <= 30;

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

  @ignore
  double get totalStock => hasVariants
      ? roundQty(variantCombinations.where((c) => c.isActive).fold(0.0, (s, c) => s + c.stockQty))
      : stockQty;

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
    double? stockQty,
    double? lowStockThreshold,
    QuantityUnit? unit,
    String? category,
    String? qrCode,
    List<String>? tags,
    bool? isActive,
    List<ProductVariant>? variants,
    List<VariantAttribute>? variantAttributes,
    List<VariantCombination>? variantCombinations,
    int? supplierId,
    DateTime? expiryDate,
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
        unit: unit ?? this.unit,
        category: category ?? this.category,
        qrCode: qrCode ?? this.qrCode,
        tags: tags ?? this.tags,
        isActive: isActive ?? this.isActive,
        variants: variants ?? this.variants,
        variantAttributes: variantAttributes ?? this.variantAttributes,
        variantCombinations: variantCombinations ?? this.variantCombinations,
        supplierId: supplierId ?? this.supplierId,
        expiryDate: expiryDate ?? this.expiryDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
