import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'expense.g.dart';

enum ExpenseCategory { logistics, packaging, marketing, supplies, other }

@collection
@JsonSerializable()
class Expense {
  Expense({
    this.id = Isar.autoIncrement,
    required this.title,
    required this.amount,
    this.category = ExpenseCategory.other,
    this.date,
    this.notes = '',
    this.createdAt,
  });

  Id id;
  String title;
  double amount;

  @Enumerated(EnumType.name)
  ExpenseCategory category;

  DateTime? date;
  String notes;
  DateTime? createdAt;

  Expense copyWith({
    Id? id,
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
  }) =>
      Expense(
        id: id ?? this.id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        date: date ?? this.date,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
  Map<String, dynamic> toJson() => _$ExpenseToJson(this);
}
