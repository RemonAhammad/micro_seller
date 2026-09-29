import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';
import 'order.dart';

part 'payment.g.dart';

/// One money movement against one order — the history behind
/// `Order.amountPaid`. The order's `amountPaid` stays the source of truth;
/// these rows are the audit trail (who paid what, when, how).
///
/// A single Due Book collection that spans several orders writes one row per
/// order it touched, all sharing the same [groupId]. Refunds are negative.
@collection
@JsonSerializable()
class Payment {
  Payment({
    this.id = Isar.autoIncrement,
    this.customerId = 0,
    this.orderId = 0,
    required this.amount,
    this.method = PaymentMethod.cash,
    this.transactionId = '',
    this.note = '',
    this.groupId = '',
    this.paidAt,
    this.createdAt,
  });

  Id id;

  @Index()
  int customerId;

  @Index()
  int orderId;

  double amount;

  @Enumerated(EnumType.name)
  PaymentMethod method;

  String transactionId;
  String note;
  String groupId;
  DateTime? paidAt;
  DateTime? createdAt;

  @ignore
  bool get isRefund => amount < 0;

  Payment copyWith({
    Id? id,
    int? customerId,
    int? orderId,
    double? amount,
    PaymentMethod? method,
    String? transactionId,
    String? note,
    String? groupId,
    DateTime? paidAt,
    DateTime? createdAt,
  }) =>
      Payment(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        orderId: orderId ?? this.orderId,
        amount: amount ?? this.amount,
        method: method ?? this.method,
        transactionId: transactionId ?? this.transactionId,
        note: note ?? this.note,
        groupId: groupId ?? this.groupId,
        paidAt: paidAt ?? this.paidAt,
        createdAt: createdAt ?? this.createdAt,
      );

  factory Payment.fromJson(Map<String, dynamic> json) =>
      _$PaymentFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentToJson(this);
}
