import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/services/isar_service.dart';

part 'product_provider.g.dart';

@riverpod
ProductRepository productRepository(ProductRepositoryRef ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return ProductRepository(isar);
}

@riverpod
Stream<List<Product>> products(ProductsRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.products
      .where()
      .filter()
      .isActiveEqualTo(true)
      .sortByName()
      .watch(fireImmediately: true);
}

@riverpod
Stream<List<Product>> lowStockProducts(LowStockProductsRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.products
      .where()
      .filter()
      .isActiveEqualTo(true)
      .watch(fireImmediately: true)
      .map((list) => list.where((p) => p.isLowStock || p.isOutOfStock).toList());
}

@riverpod
class ProductNotifier extends _$ProductNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> addProduct(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final now = DateTime.now();
      final p = product.copyWith(createdAt: now, updatedAt: now);
      await isar.writeTxn(() async => isar.products.put(p));
    });
  }

  Future<void> updateProduct(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final p = product.copyWith(updatedAt: DateTime.now());
      await isar.writeTxn(() async => isar.products.put(p));
    });
  }

  Future<void> deleteProduct(int id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async => isar.products.delete(id));
    });
  }

  Future<void> adjustStock(
      int productId, int delta, String reason, StockMovementType type) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final product = await isar.products.get(productId);
        if (product == null) return;
        final updated = product.copyWith(
          stockQty: product.stockQty + delta,
          updatedAt: DateTime.now(),
        );
        await isar.products.put(updated);
        await isar.stockMovements.put(StockMovement(
          productId: productId,
          productName: product.name,
          type: type,
          qty: delta,
          reason: reason,
          createdAt: DateTime.now(),
        ));
      });
    });
  }
}
