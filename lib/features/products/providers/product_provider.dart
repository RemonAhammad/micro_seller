import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/order.dart';
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
  // Debug: print raw DB count
  final allCount = await isar.products.count();
  final activeCount = await isar.products.filter().isActiveEqualTo(true).count();
  debugPrint('[ProductProvider] DB total: $allCount, active: $activeCount');
  await for (final list in isar.products
      .where()
      .filter()
      .isActiveEqualTo(true)
      .sortByName()
      .watch(fireImmediately: true)) {
    debugPrint('[ProductProvider] Stream emitted ${list.length} products: ${list.map((p) => '${p.id}:${p.name}').join(', ')}');
    yield list;
  }
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
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final now = DateTime.now();
      final p = product.copyWith(createdAt: now, updatedAt: now);
      await isar.writeTxn(() async => isar.products.put(p));
    });
  }

  Future<void> updateProduct(Product product) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final p = product.copyWith(updatedAt: DateTime.now());
      await isar.writeTxn(() async => isar.products.put(p));
    });
  }

  Future<void> deleteProduct(int id) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);

      // Check if product is referenced in any orders
      final orders = await isar.orders.where().findAll();
      final inUse = orders.any(
          (o) => o.items.any((item) => item.productId == id));
      if (inUse) {
        // Soft-delete: mark inactive instead of removing
        final product = await isar.products.get(id);
        if (product != null) {
          await isar.writeTxn(() async => isar.products.put(
                product.copyWith(isActive: false, updatedAt: DateTime.now()),
              ));
        }
        return;
      }

      await isar.writeTxn(() async {
        // Also clean up stock movements
        await isar.stockMovements
            .filter()
            .productIdEqualTo(id)
            .deleteAll();
        await isar.products.delete(id);
      });
    });
  }

  Future<void> adjustStock(
      int productId, int delta, String reason, StockMovementType type,
      {String variantName = '', String variantValue = ''}) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final product = await isar.products.get(productId);
        if (product == null) return;
        final hasVariant = variantName.isNotEmpty && variantValue.isNotEmpty;

        var updated = product.copyWith(
          stockQty: (product.stockQty + delta).clamp(0, 999999),
          updatedAt: DateTime.now(),
        );

        if (hasVariant) {
          final updatedVariants = updated.variants.map((v) {
            if (v.name == variantName && v.value == variantValue) {
              return v.copyWith(stockQty: (v.stockQty + delta).clamp(0, 999999));
            }
            return v;
          }).toList();
          updated = updated.copyWith(variants: updatedVariants);
        }

        await isar.products.put(updated);
        final movementName = hasVariant
            ? '${product.name} ($variantName: $variantValue)'
            : product.name;
        await isar.stockMovements.put(StockMovement(
          productId: productId,
          productName: movementName,
          type: type,
          qty: delta,
          reason: reason,
          createdAt: DateTime.now(),
        ));
      });
    });
  }
}
