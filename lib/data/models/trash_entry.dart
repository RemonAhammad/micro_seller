import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'trash_entry.g.dart';

enum TrashKind { expense, category, customer, product, order, purchase, supplier }

@Collection(accessor: 'trashEntries')
@JsonSerializable()
class TrashEntry {
  TrashEntry({
    this.id = Isar.autoIncrement,
    required this.kind,
    required this.originalId,
    required this.payload,
    this.sidecar = '{}',
    required this.label,
    this.sublabel = '',
    this.deletedAt,
  });

  Id id;

  @Enumerated(EnumType.name)
  @Index()
  TrashKind kind;

  int originalId;

  String payload;

  String sidecar;

  String label;

  String sublabel;

  @Index()
  DateTime? deletedAt;

  TrashEntry copyWith({
    Id? id,
    TrashKind? kind,
    int? originalId,
    String? payload,
    String? sidecar,
    String? label,
    String? sublabel,
    DateTime? deletedAt,
  }) =>
      TrashEntry(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        originalId: originalId ?? this.originalId,
        payload: payload ?? this.payload,
        sidecar: sidecar ?? this.sidecar,
        label: label ?? this.label,
        sublabel: sublabel ?? this.sublabel,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  factory TrashEntry.fromJson(Map<String, dynamic> json) =>
      _$TrashEntryFromJson(json);

  Map<String, dynamic> toJson() => _$TrashEntryToJson(this);
}
