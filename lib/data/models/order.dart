import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'order_item.dart';

part 'order.g.dart';

enum PaymentStatus { unpaid, partial, paid }

enum OrderStatus { pending, confirmed, shipped, completed, cancelled }

@collection
@JsonSerializable()
class Order {
  Order({
    this.id = Isar.autoIncrement,
    this.orderNumber = '',
    this.customerId = 0,
    this.customerName = '',
    this.customerPhone = '',
    this.items = const [],
    this.subtotal = 0.0,
    this.discountAmount = 0.0,
    this.deliveryFee = 0.0,
    this.totalAmount = 0.0,
    this.amountPaid = 0.0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.orderStatus = OrderStatus.pending,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  Id id;
  String orderNumber;
  int customerId;
  String customerName;
  String customerPhone;
  List<OrderItem> items;
  double subtotal;
  double discountAmount;
  double deliveryFee;
  double totalAmount;
  double amountPaid;

  @Enumerated(EnumType.name)
  PaymentStatus paymentStatus;

  @Enumerated(EnumType.name)
  OrderStatus orderStatus;

  String notes;
  DateTime? createdAt;
  DateTime? updatedAt;

  @ignore
  double get balanceDue => totalAmount - amountPaid;

  @ignore
  bool get isFullyPaid => paymentStatus == PaymentStatus.paid;

  @ignore
  int get totalItems => items.fold(0, (sum, item) => sum + item.qty);

  Order copyWith({
    Id? id,
    String? orderNumber,
    int? customerId,
    String? customerName,
    String? customerPhone,
    List<OrderItem>? items,
    double? subtotal,
    double? discountAmount,
    double? deliveryFee,
    double? totalAmount,
    double? amountPaid,
    PaymentStatus? paymentStatus,
    OrderStatus? orderStatus,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Order(
        id: id ?? this.id,
        orderNumber: orderNumber ?? this.orderNumber,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        items: items ?? this.items,
        subtotal: subtotal ?? this.subtotal,
        discountAmount: discountAmount ?? this.discountAmount,
        deliveryFee: deliveryFee ?? this.deliveryFee,
        totalAmount: totalAmount ?? this.totalAmount,
        amountPaid: amountPaid ?? this.amountPaid,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        orderStatus: orderStatus ?? this.orderStatus,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);
}
