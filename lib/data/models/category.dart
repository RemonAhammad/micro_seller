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
  });

  Id id;
  String name;
  DateTime? createdAt;

  Category copyWith({Id? id, String? name, DateTime? createdAt}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}
