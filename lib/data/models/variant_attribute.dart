import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'variant_attribute.g.dart';

@embedded
@JsonSerializable()
class VariantAttribute {
  VariantAttribute({
    this.name = '',
    this.options = const [],
  });

  String name; // e.g. "Size", "Color"
  List<String> options; // e.g. ["S", "M", "L", "XL"]

  VariantAttribute copyWith({
    String? name,
    List<String>? options,
  }) =>
      VariantAttribute(
        name: name ?? this.name,
        options: options ?? this.options,
      );

  factory VariantAttribute.fromJson(Map<String, dynamic> json) =>
      _$VariantAttributeFromJson(json);
  Map<String, dynamic> toJson() => _$VariantAttributeToJson(this);
}
