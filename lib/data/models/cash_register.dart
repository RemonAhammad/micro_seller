import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cash_register.g.dart';

@collection
@JsonSerializable()
class CashRegister {
  CashRegister({
    this.id = Isar.autoIncrement,
    this.openingAmount = 0.0,
    this.closingAmount,
    this.totalSales = 0.0,
    this.totalExpenses = 0.0,
    this.totalCashIn = 0.0,
    this.totalCashOut = 0.0,
    this.notes = '',
    this.isClosed = false,
    this.openedAt,
    this.closedAt,
  });

  Id id;
  double openingAmount;
  double? closingAmount;
  double totalSales;
  double totalExpenses;
  double totalCashIn;
  double totalCashOut;
  String notes;
  bool isClosed;
  DateTime? openedAt;
  DateTime? closedAt;

  @ignore
  double get expectedClosing =>
      openingAmount + totalCashIn - totalCashOut;

  @ignore
  double get difference =>
      closingAmount != null ? closingAmount! - expectedClosing : 0;

  CashRegister copyWith({
    Id? id,
    double? openingAmount,
    double? closingAmount,
    double? totalSales,
    double? totalExpenses,
    double? totalCashIn,
    double? totalCashOut,
    String? notes,
    bool? isClosed,
    DateTime? openedAt,
    DateTime? closedAt,
  }) =>
      CashRegister(
        id: id ?? this.id,
        openingAmount: openingAmount ?? this.openingAmount,
        closingAmount: closingAmount ?? this.closingAmount,
        totalSales: totalSales ?? this.totalSales,
        totalExpenses: totalExpenses ?? this.totalExpenses,
        totalCashIn: totalCashIn ?? this.totalCashIn,
        totalCashOut: totalCashOut ?? this.totalCashOut,
        notes: notes ?? this.notes,
        isClosed: isClosed ?? this.isClosed,
        openedAt: openedAt ?? this.openedAt,
        closedAt: closedAt ?? this.closedAt,
      );

  factory CashRegister.fromJson(Map<String, dynamic> json) =>
      _$CashRegisterFromJson(json);
  Map<String, dynamic> toJson() => _$CashRegisterToJson(this);
}
