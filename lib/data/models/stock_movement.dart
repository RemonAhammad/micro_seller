import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'stock_movement.g.dart';

enum StockMovementType { sale, restock, adjustment, damage }

@collection
@JsonSerializable()
class StockMovement {
  StockMovement({
    this.id = Isar.autoIncrement,
    this.productId = 0,
    this.productName = '',
    this.type = StockMovementType.adjustment,
    this.qty = 0,
    this.reason = '',
    this.supplierId = 0,
    this.createdAt,
  });

  Id id;
  @Index()
  int productId;
  String productName;

  @Enumerated(EnumType.name)
  StockMovementType type;

  int qty;
  String reason;

  /// Optional supplier id (0 = not linked to any supplier)
  int supplierId;

  @Index()
  DateTime? createdAt;

  @ignore
  bool get isIncoming => qty > 0;

  StockMovement copyWith({
    Id? id,
    int? productId,
    String? productName,
    StockMovementType? type,
    int? qty,
    String? reason,
    int? supplierId,
    DateTime? createdAt,
  }) =>
      StockMovement(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        type: type ?? this.type,
        qty: qty ?? this.qty,
        reason: reason ?? this.reason,
        supplierId: supplierId ?? this.supplierId,
        createdAt: createdAt ?? this.createdAt,
      );

  factory StockMovement.fromJson(Map<String, dynamic> json) =>
      _$StockMovementFromJson(json);
  Map<String, dynamic> toJson() => _$StockMovementToJson(this);
}
