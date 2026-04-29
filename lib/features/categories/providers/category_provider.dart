import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/category.dart';
import '../../../data/services/isar_service.dart';

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

  Future<void> deleteCategory(int id) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async => isar.categories.delete(id));
    });
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
