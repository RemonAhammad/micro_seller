import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'customer.g.dart';

enum CustomerTag { newCustomer, regular, vip }

@collection
@JsonSerializable()
class Customer {
  Customer({
    this.id = Isar.autoIncrement,
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
    this.tag = CustomerTag.newCustomer,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.outstandingBalance = 0.0,
    this.createdAt,
  });

  Id id;
  String name;
  String phone;
  String address;
  String notes;

  @Enumerated(EnumType.name)
  CustomerTag tag;

  int totalOrders;
  double totalSpent;
  double outstandingBalance;
  DateTime? createdAt;

  @ignore
  bool get hasOutstanding => outstandingBalance > 0;

  Customer copyWith({
    Id? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    CustomerTag? tag,
    int? totalOrders,
    double? totalSpent,
    double? outstandingBalance,
    DateTime? createdAt,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        tag: tag ?? this.tag,
        totalOrders: totalOrders ?? this.totalOrders,
        totalSpent: totalSpent ?? this.totalSpent,
        outstandingBalance: outstandingBalance ?? this.outstandingBalance,
        createdAt: createdAt ?? this.createdAt,
      );

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerToJson(this);
}
