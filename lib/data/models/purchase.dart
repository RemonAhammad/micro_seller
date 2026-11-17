import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../core/utils/quantity.dart';
import 'quantity_unit.dart';

part 'purchase.g.dart';

@collection
@JsonSerializable()
class Purchase {
  Purchase({
    this.id = Isar.autoIncrement,
    this.supplierId = 0,
    this.supplierName = '',
    required this.items,
    this.totalAmount = 0.0,
    this.amountPaid = 0.0,
    this.paymentMethod = PurchasePaymentMethod.cash,
    this.notes = '',
    this.referenceNumber = '',
    this.createdAt,
  });

  Id id;
  int supplierId;
  String supplierName;
  List<PurchaseItem> items;
  double totalAmount;
  double amountPaid;
  @Enumerated(EnumType.name)
  PurchasePaymentMethod paymentMethod;
  String notes;
  String referenceNumber;
  DateTime? createdAt;

  @ignore
  double get balanceDue => (totalAmount - amountPaid).clamp(0, double.infinity);

  @ignore
  bool get isFullyPaid => amountPaid >= totalAmount;

  /// How many things were bought, for "N items": the units when every line
  /// is whole, else the number of lines (2.5 kg + 3 pieces is 2 items).
  @ignore
  int get totalItems => items.every((i) => isWholeQty(i.qty))
      ? items.fold(0, (s, i) => s + wholeQty(i.qty))
      : items.length;

  Purchase copyWith({
    Id? id,
    int? supplierId,
    String? supplierName,
    List<PurchaseItem>? items,
    double? totalAmount,
    double? amountPaid,
    PurchasePaymentMethod? paymentMethod,
    String? notes,
    String? referenceNumber,
    DateTime? createdAt,
  }) =>
      Purchase(
        id: id ?? this.id,
        supplierId: supplierId ?? this.supplierId,
        supplierName: supplierName ?? this.supplierName,
        items: items ?? this.items,
        totalAmount: totalAmount ?? this.totalAmount,
        amountPaid: amountPaid ?? this.amountPaid,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        notes: notes ?? this.notes,
        referenceNumber: referenceNumber ?? this.referenceNumber,
        createdAt: createdAt ?? this.createdAt,
      );

  factory Purchase.fromJson(Map<String, dynamic> json) =>
      _$PurchaseFromJson(json);
  Map<String, dynamic> toJson() => _$PurchaseToJson(this);
}

@embedded
@JsonSerializable()
class PurchaseItem {
  PurchaseItem({
    this.productId = 0,
    this.productName = '',
    this.qty = 0,
    this.unit = QuantityUnit.piece,
    this.unitCost = 0.0,
    this.totalCost = 0.0,
    this.serials = const [],
  });

  int productId;
  String productName;

  /// The serial numbers received, for a product that tracks them: [qty] is
  /// their count. Empty for every other line.
  List<String> serials;

  /// In [unit]s, rounded to 3 decimals; stored as `quantity` (see
  /// `OrderItem.qty`).
  @Name('quantity')
  double qty;

  /// The product's unit at the time of the purchase. Older items: piece.
  @Enumerated(EnumType.name)
  @JsonKey(unknownEnumValue: QuantityUnit.piece)
  QuantityUnit unit;

  @Name('qty')
  @JsonKey(includeFromJson: false, includeToJson: false)
  int legacyQty = 0;

  /// Per one [unit].
  double unitCost;
  double totalCost;

  PurchaseItem copyWith({
    int? productId,
    String? productName,
    double? qty,
    QuantityUnit? unit,
    double? unitCost,
    double? totalCost,
    List<String>? serials,
  }) =>
      PurchaseItem(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        unitCost: unitCost ?? this.unitCost,
        totalCost: totalCost ?? this.totalCost,
        serials: serials ?? this.serials,
      );

  factory PurchaseItem.fromJson(Map<String, dynamic> json) =>
      _$PurchaseItemFromJson(json);
  Map<String, dynamic> toJson() => _$PurchaseItemToJson(this);
}

enum PurchasePaymentMethod { cash, card, bkash, nagad, bank, other }
