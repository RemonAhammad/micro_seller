import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'trash_entry.g.dart';

/// Which collection a trashed record came from.
///
/// Stored by *name* so adding new kinds later never renumbers existing rows.
enum TrashKind { expense, category, customer, product, order, purchase, supplier }

/// A soft-deleted record awaiting restore or purge.
///
/// Rather than adding a `deletedAt` flag to each of the 13 models (and then
/// teaching every query in the app to filter it out), deleted records are
/// serialised into this one collection. Every model already implements
/// `toJson()`/`fromJson()`, which is what makes the generic approach viable.
///
/// [payload] is the record itself. [sidecar] is the extra bookkeeping needed
/// to *reverse* a delete's side effects — deleting a customer unlinks their
/// orders, deleting a product may wipe its stock movements, and restoring the
/// payload alone would leave those changes in place. See `TrashService`.
// `accessor:` is set explicitly because Isar's default pluralisation of
// "TrashEntry" is "trashEntrys".
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

  /// The Isar id the record had before deletion. Restores reuse it so any
  /// surviving references (order → customerId, product → supplierId) line up.
  int originalId;

  /// `jsonEncode(model.toJson())`.
  String payload;

  /// `jsonEncode({...})` of whatever the restore needs to undo side effects.
  /// `'{}'` for deletes that touch nothing else.
  String sidecar;

  /// Human-readable name for the bin list, e.g. "Order #INV-042".
  String label;

  /// Optional second line, e.g. an amount or a category.
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
