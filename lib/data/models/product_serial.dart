import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product_serial.g.dart';

/// Where one serial-numbered unit is now.
enum SerialStatus {
  /// On the shelf: counts in the product's stock.
  inStock,

  /// Gone with an order ([ProductSerial.orderId]) or a stock "sale" entry.
  sold,

  /// Written off by a damage entry, or taken out in the product form.
  removed,
}

/// One unit of a product that tracks serial numbers (IMEI): its number,
/// where it came from and where it went. The product's stock is the number
/// of its serials [SerialStatus.inStock]; every write goes through
/// `serial_service.dart`, which keeps the two equal.
@collection
@JsonSerializable()
class ProductSerial {
  ProductSerial({
    this.id = Isar.autoIncrement,
    required this.productId,
    required this.serial,
    this.status = SerialStatus.inStock,
    this.purchaseId = 0,
    this.orderId = 0,
    this.soldAt,
    this.createdAt,
    this.updatedAt,
  });

  Id id;

  @Index()
  int productId;

  /// Trimmed, as typed or scanned. Unique within a product (checked by the
  /// service, not the index, so restoring a backup can never fail on it).
  @Index(caseSensitive: false)
  String serial;

  @Enumerated(EnumType.name)
  @JsonKey(unknownEnumValue: SerialStatus.inStock)
  SerialStatus status;

  /// The purchase it arrived with; 0 = entered in the product form or a
  /// stock entry.
  int purchaseId;

  /// The order it was sold on while [status] is sold; 0 otherwise.
  int orderId;

  /// When it was sold (the order's date), for the warranty.
  DateTime? soldAt;

  DateTime? createdAt;
  DateTime? updatedAt;

  @ignore
  bool get isInStock => status == SerialStatus.inStock;

  ProductSerial copyWith({
    Id? id,
    int? productId,
    String? serial,
    SerialStatus? status,
    int? purchaseId,
    int? orderId,
    DateTime? soldAt,
    bool clearSoldAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ProductSerial(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        serial: serial ?? this.serial,
        status: status ?? this.status,
        purchaseId: purchaseId ?? this.purchaseId,
        orderId: orderId ?? this.orderId,
        soldAt: clearSoldAt ? null : (soldAt ?? this.soldAt),
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory ProductSerial.fromJson(Map<String, dynamic> json) => _$ProductSerialFromJson(json);
  Map<String, dynamic> toJson() => _$ProductSerialToJson(this);
}
