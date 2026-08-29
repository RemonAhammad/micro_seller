import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/models/trash_entry.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/trash_service.dart';

part 'product_provider.g.dart';

@riverpod
ProductRepository productRepository(Ref ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return ProductRepository(isar);
}

@riverpod
Stream<List<Product>> products(Ref ref) async* {
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
Stream<List<Product>> lowStockProducts(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.products
      .where()
      .filter()
      .isActiveEqualTo(true)
      .watch(fireImmediately: true)
      .map((list) => list.where((p) => p.isLowStock || p.isOutOfStock).toList());
}

// keepAlive: a CRUD notifier whose methods do `state = ...` after async writes
// must outlive the call site, otherwise `ref.read(...notifier).method()` from
// a screen disposes the provider during the await and the post-await
// `state = ...` throws UnmountedRefException. Same pattern applied to every
// other CRUD notifier in this project.
@Riverpod(keepAlive: true)
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

  /// Both delete branches are now recoverable. The sidecar records which
  /// branch ran, because undoing a soft-delete means flipping `isActive` back
  /// whereas undoing a hard-delete also has to restore the stock movements
  /// that were wiped alongside the product.
  /// Returns the trash entry id, for wiring an UNDO action. Null if the
  /// product was already gone.
  Future<int?> deleteProduct(int id) async {
    int? trashId;
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final trash = TrashService(isar);

      // Check if product is referenced in any orders
      final orders = await isar.orders.where().findAll();
      final inUse = orders.any(
          (o) => o.items.any((item) => item.productId == id));
      if (inUse) {
        // Soft-delete: mark inactive instead of removing
        final product = await isar.products.get(id);
        if (product != null) {
          await isar.writeTxn(() async {
            trashId = await trash.capture(
              kind: TrashKind.product,
              originalId: id,
              payload: product.toJson(),
              sidecar: const {'softDeleted': true},
              label: product.name,
              sublabel: product.sku,
            );
            await isar.products.put(
              product.copyWith(isActive: false, updatedAt: DateTime.now()),
            );
          });
        }
        return;
      }

      await isar.writeTxn(() async {
        final product = await isar.products.get(id);
        if (product == null) return;

        // Also clean up stock movements — captured first so a restore can
        // put them back.
        final movements = await isar.stockMovements
            .filter()
            .productIdEqualTo(id)
            .findAll();

        trashId = await trash.capture(
          kind: TrashKind.product,
          originalId: id,
          payload: product.toJson(),
          sidecar: {
            'softDeleted': false,
            'stockMovements': movements.map((m) => m.toJson()).toList(),
          },
          label: product.name,
          sublabel: product.sku,
        );

        await isar.stockMovements
            .deleteAll(movements.map((m) => m.id).toList());
        await isar.products.delete(id);
      });
    });
    return trashId;
  }

  Future<void> adjustStock(
      int productId, int delta, String reason, StockMovementType type,
      {String combinationKey = '',
      String supplierName = '',
      int supplierId = 0}) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final product = await isar.products.get(productId);
        if (product == null) return;

        var updated = product.copyWith(
          stockQty: (product.stockQty + delta).clamp(0, 999999),
          updatedAt: DateTime.now(),
        );

        if (combinationKey.isNotEmpty) {
          final updatedCombinations = updated.variantCombinations.map((c) {
            if (c.combinationKey == combinationKey) {
              return c.copyWith(stockQty: (c.stockQty + delta).clamp(0, 999999));
            }
            return c;
          }).toList();
          updated = updated.copyWith(variantCombinations: updatedCombinations);
        }

        await isar.products.put(updated);
        String movementName = product.name;
        if (combinationKey.isNotEmpty) {
          final combo = product.findCombination(combinationKey);
          movementName = combo != null
              ? '${product.name} (${combo.displayLabel})'
              : '${product.name} ($combinationKey)';
        }

        // Compose reason with supplier prefix if provided
        String fullReason = reason;
        if (supplierName.isNotEmpty) {
          final prefix = 'From: $supplierName';
          fullReason = reason.isNotEmpty ? '$prefix — $reason' : prefix;
        }

        await isar.stockMovements.put(StockMovement(
          productId: productId,
          productName: movementName,
          type: type,
          qty: delta,
          reason: fullReason,
          supplierId: supplierId,
          createdAt: DateTime.now(),
        ));
      });
    });
  }
}
