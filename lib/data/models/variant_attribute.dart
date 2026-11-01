import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'variant_attribute.g.dart';

@embedded
@JsonSerializable()
class VariantAttribute {
  VariantAttribute({
    this.name = '',
    this.options = const [],
  });

  String name;
  List<String> options;

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
