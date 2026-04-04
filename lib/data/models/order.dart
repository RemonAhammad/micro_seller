import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'order_item.dart';

part 'order.g.dart';

enum PaymentStatus { unpaid, partial, paid }

enum OrderStatus { pending, confirmed, shipped, completed, cancelled }

enum PaymentMethod { cash, card, mfs, bank, other }

enum ReturnStatus { none, requested, approved, received, refunded, rejected }

enum ReturnReason { defective, wrongItem, damaged, changedMind, other }

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
    this.taxAmount = 0.0,
    this.totalAmount = 0.0,
    this.amountPaid = 0.0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.paymentMethod = PaymentMethod.cash,
    this.orderStatus = OrderStatus.pending,
    this.notes = '',
    this.deliveryAddress = '',
    this.estimatedDeliveryDate,
    this.actualDeliveryDate,
    this.isReturn = false,
    this.originalOrderId = 0,
    this.returnStatus = ReturnStatus.none,
    this.returnReason = ReturnReason.other,
    this.returnNotes = '',
    this.refundAmount = 0.0,
    this.isRecurring = false,
    this.recurringIntervalDays = 0,
    this.nextRecurringDate,
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
  double taxAmount;
  double totalAmount;
  double amountPaid;

  @Enumerated(EnumType.name)
  PaymentStatus paymentStatus;

  @Enumerated(EnumType.name)
  PaymentMethod paymentMethod;

  @Enumerated(EnumType.name)
  OrderStatus orderStatus;

  String notes;
  String deliveryAddress;
  DateTime? estimatedDeliveryDate;
  DateTime? actualDeliveryDate;

  // Return order fields
  bool isReturn;
  int originalOrderId;

  @Enumerated(EnumType.name)
  ReturnStatus returnStatus;

  @Enumerated(EnumType.name)
  ReturnReason returnReason;

  String returnNotes;
  double refundAmount;

  // Recurring order fields
  bool isRecurring;
  int recurringIntervalDays;
  DateTime? nextRecurringDate;

  DateTime? createdAt;
  DateTime? updatedAt;

  @ignore
  double get balanceDue => totalAmount - amountPaid;

  @ignore
  bool get isFullyPaid => paymentStatus == PaymentStatus.paid;

  @ignore
  int get totalItems => items.fold(0, (sum, item) => sum + item.qty);

  @ignore
  bool get isRefunded => returnStatus == ReturnStatus.refunded;

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
    double? taxAmount,
    double? totalAmount,
    double? amountPaid,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    OrderStatus? orderStatus,
    String? notes,
    String? deliveryAddress,
    DateTime? estimatedDeliveryDate,
    DateTime? actualDeliveryDate,
    bool? isReturn,
    int? originalOrderId,
    ReturnStatus? returnStatus,
    ReturnReason? returnReason,
    String? returnNotes,
    double? refundAmount,
    bool? isRecurring,
    int? recurringIntervalDays,
    DateTime? nextRecurringDate,
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
        taxAmount: taxAmount ?? this.taxAmount,
        totalAmount: totalAmount ?? this.totalAmount,
        amountPaid: amountPaid ?? this.amountPaid,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        orderStatus: orderStatus ?? this.orderStatus,
        notes: notes ?? this.notes,
        deliveryAddress: deliveryAddress ?? this.deliveryAddress,
        estimatedDeliveryDate:
            estimatedDeliveryDate ?? this.estimatedDeliveryDate,
        actualDeliveryDate: actualDeliveryDate ?? this.actualDeliveryDate,
        isReturn: isReturn ?? this.isReturn,
        originalOrderId: originalOrderId ?? this.originalOrderId,
        returnStatus: returnStatus ?? this.returnStatus,
        returnReason: returnReason ?? this.returnReason,
        returnNotes: returnNotes ?? this.returnNotes,
        refundAmount: refundAmount ?? this.refundAmount,
        isRecurring: isRecurring ?? this.isRecurring,
        recurringIntervalDays:
            recurringIntervalDays ?? this.recurringIntervalDays,
        nextRecurringDate: nextRecurringDate ?? this.nextRecurringDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);
}
