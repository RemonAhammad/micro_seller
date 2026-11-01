import 'package:isar_community/isar.dart';
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
    this.transactionId = '',
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
  @Index()
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

  String transactionId;

  @Enumerated(EnumType.name)
  OrderStatus orderStatus;

  String notes;
  String deliveryAddress;
  DateTime? estimatedDeliveryDate;
  DateTime? actualDeliveryDate;

  bool isReturn;
  int originalOrderId;

  @Enumerated(EnumType.name)
  ReturnStatus returnStatus;

  @Enumerated(EnumType.name)
  ReturnReason returnReason;

  String returnNotes;
  double refundAmount;

  bool isRecurring;
  int recurringIntervalDays;
  DateTime? nextRecurringDate;

  @Index()
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

  @ignore
  double get goodsTotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  @ignore
  double get netGoods {
    final net = goodsTotal - discountAmount;
    return net > 0 ? net : 0;
  }

  @ignore
  double get discountFactor {
    final goods = goodsTotal;
    return goods > 0 ? netGoods / goods : 1;
  }

  @ignore
  double get deliveryIncome {
    final rest = totalAmount - taxAmount - netGoods;
    if (rest <= 0) return 0;
    return rest < deliveryFee ? rest : deliveryFee;
  }

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
    String? transactionId,
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
        transactionId: transactionId ?? this.transactionId,
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

double roundMoney(double v) => (v * 100).roundToDouble() / 100;

({double tax, double total}) orderTotals({
  required double subtotal,
  double discount = 0,
  double taxRate = 0,
  double delivery = 0,
}) {
  final taxable = subtotal - discount;
  final tax =
      taxRate > 0 && taxable > 0 ? roundMoney(taxable * taxRate / 100) : 0.0;
  final total = subtotal - discount + tax + delivery;
  return (tax: tax, total: total > 0 ? roundMoney(total) : 0.0);
}

({double subtotal, double discount, double tax, double total}) returnValueFor(
    Order original, List<OrderItem> items) {
  final subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
  final goods = original.goodsTotal;
  final discount = goods > 0
      ? (goods - original.netGoods) * subtotal / goods
      : 0.0;
  final net = subtotal - discount;
  final originalNet = original.netGoods;
  final tax = originalNet > 0 ? original.taxAmount * net / originalNet : 0.0;
  return (subtotal: subtotal, discount: discount, tax: tax, total: net + tax);
}
