import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

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

  @ignore
  int get totalItems => items.fold(0, (s, i) => s + i.qty);

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
    this.unitCost = 0.0,
    this.totalCost = 0.0,
  });

  int productId;
  String productName;
  int qty;
  double unitCost;
  double totalCost;

  PurchaseItem copyWith({
    int? productId,
    String? productName,
    int? qty,
    double? unitCost,
    double? totalCost,
  }) =>
      PurchaseItem(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        qty: qty ?? this.qty,
        unitCost: unitCost ?? this.unitCost,
        totalCost: totalCost ?? this.totalCost,
      );

  factory PurchaseItem.fromJson(Map<String, dynamic> json) =>
      _$PurchaseItemFromJson(json);
  Map<String, dynamic> toJson() => _$PurchaseItemToJson(this);
}

enum PurchasePaymentMethod { cash, card, bkash, nagad, bank, other }
