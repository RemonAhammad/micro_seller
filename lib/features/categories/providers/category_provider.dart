import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/category.dart';
import '../../../data/models/trash_entry.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/trash_service.dart';

part 'category_provider.g.dart';

@riverpod
Stream<List<Category>> categories(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.categories.where().sortByName().watch(fireImmediately: true);
}

@Riverpod(keepAlive: true)
class CategoryNotifier extends _$CategoryNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> addCategory(Category category) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async =>
          isar.categories.put(category.copyWith(createdAt: DateTime.now())));
    });
  }

  Future<void> updateCategory(Category category) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async => isar.categories.put(category));
    });
  }

  /// Moves the category to the trash instead of destroying it. Recoverable
  /// for [kTrashRetention] via the undo snackbar or Settings → Recycle Bin.
  /// Returns the trash entry id, for wiring an UNDO action. Null if the
  /// category was already gone.
  Future<int?> deleteCategory(int id) async {
    int? trashId;
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final trash = TrashService(isar);
      await isar.writeTxn(() async {
        final category = await isar.categories.get(id);
        if (category == null) return;
        trashId = await trash.capture(
          kind: TrashKind.category,
          originalId: id,
          payload: category.toJson(),
          label: category.name,
        );
        await isar.categories.delete(id);
      });
    });
    return trashId;
  }

  /// Ensures the named category exists; creates it if not.
  Future<void> ensureExists(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final isar = await ref.read(isarProvider.future);
    final existing = await isar.categories
        .filter()
        .nameEqualTo(trimmed)
        .findFirst();
    if (existing == null) {
      await isar.writeTxn(() async => isar.categories.put(
            Category(name: trimmed, createdAt: DateTime.now()),
          ));
    }
  }
}
