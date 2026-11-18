import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/models/trash_entry.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/trash_service.dart';

part 'category_provider.g.dart';

@riverpod
Stream<List<Category>> categories(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.categories.where().sortByName().watch(fireImmediately: true);
}

/// Products the order screen may sell by the dozen: those in a category
/// with "Sell by the dozen" on. Live as categories and products change.
@riverpod
Stream<Set<int>> dozenProductIds(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  Future<Set<int>> load() async {
    final names = await isar.categories.filter().sellByDozenEqualTo(true).nameProperty().findAll();
    if (names.isEmpty) return const {};
    final ids = await isar.products
        .filter()
        .anyOf(names, (q, name) => q.categoryEqualTo(name))
        .idProperty()
        .findAll();
    return ids.toSet();
  }

  yield* reloadOn(
    mergeChanges([isar.categories.watchLazy(), isar.products.watchLazy()]),
    load,
  );
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
