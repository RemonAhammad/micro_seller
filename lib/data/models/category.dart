import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

@Collection(accessor: 'categories')
@JsonSerializable()
class Category {
  Category({
    this.id = Isar.autoIncrement,
    required this.name,
    this.createdAt,
    this.sellByDozen = false,
  });

  Id id;
  String name;
  DateTime? createdAt;

  /// Its piece products can also be sold by the dozen: the order screen
  /// offers them a Pcs | Dozen switch. Off for older categories and backups.
  @JsonKey(defaultValue: false)
  bool sellByDozen;

  Category copyWith({Id? id, String? name, DateTime? createdAt, bool? sellByDozen}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        sellByDozen: sellByDozen ?? this.sellByDozen,
      );

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}
