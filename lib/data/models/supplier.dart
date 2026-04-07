import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'supplier.g.dart';

@collection
@JsonSerializable()
class Supplier {
  Supplier({
    this.id = Isar.autoIncrement,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.company = '',
    this.notes = '',
    this.totalPurchases = 0,
    this.totalPaid = 0.0,
    this.totalDue = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  Id id;
  String name;
  String phone;
  String email;
  String address;
  String company;
  String notes;

  /// Number of purchase entries from this supplier
  int totalPurchases;

  /// Total amount paid to this supplier
  double totalPaid;

  /// Total amount still owed to this supplier
  double totalDue;

  DateTime? createdAt;
  DateTime? updatedAt;

  @ignore
  bool get hasOutstanding => totalDue > 0;

  Supplier copyWith({
    Id? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? company,
    String? notes,
    int? totalPurchases,
    double? totalPaid,
    double? totalDue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        company: company ?? this.company,
        notes: notes ?? this.notes,
        totalPurchases: totalPurchases ?? this.totalPurchases,
        totalPaid: totalPaid ?? this.totalPaid,
        totalDue: totalDue ?? this.totalDue,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Supplier.fromJson(Map<String, dynamic> json) =>
      _$SupplierFromJson(json);
  Map<String, dynamic> toJson() => _$SupplierToJson(this);
}
