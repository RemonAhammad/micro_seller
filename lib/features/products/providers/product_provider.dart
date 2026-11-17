import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/utils/quantity.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_item.dart';
import '../../../data/models/product.dart';
import '../../../data/models/product_serial.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/models/trash_entry.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/serial_service.dart';
import '../../../data/services/trash_service.dart';

part 'product_provider.g.dart';

@riverpod
ProductRepository productRepository(Ref ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return ProductRepository(isar);
}

@Riverpod(keepAlive: true)
Stream<List<Product>> products(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* reloadOn(
      isar.products.watchLazy(), () => runDbJob(isar, _activeProductsByName));
}

List<Product> _activeProductsByName(Isar db) =>
    db.products.where().isActiveEqualToAnyName(true).findAllSync();

@riverpod
Stream<List<Product>> lowStockProducts(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.products
      .where()
      .filter()
      .isActiveEqualTo(true)
      .watch(fireImmediately: true)
      .map((list) => list.where((p) => p.needsStockAttention).toList());
}

@Riverpod(keepAlive: true)
class ProductNotifier extends _$ProductNotifier {
  @override
  FutureOr<void> build() {}

  /// Saves a new product. For one that tracks serial numbers, [serials]
  /// are its units in stock, written in the same transaction (its stock is
  /// their count). Throws a `DuplicateSerialException` (nothing saved) for a
  /// serial typed twice.
  Future<void> addProduct(Product product, {List<String> serials = const []}) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final now = DateTime.now();
      final p = product.copyWith(createdAt: now, updatedAt: now);
      await isar.writeTxn(() async {
        final id = await isar.products.put(p);
        if (p.usesSerials) await SerialService.add(isar, id, serials, at: now);
      });
    });
    if (state.hasError) throw state.error!;
  }

  /// Saves an edited product. For one that tracks serial numbers,
  /// [addedSerials] go into stock and [removedSerials] (in stock) are taken
  /// out, in the same transaction; its stock is then its serials in stock.
  Future<void> updateProduct(
    Product product, {
    List<String> addedSerials = const [],
    List<String> removedSerials = const [],
  }) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final p = product.copyWith(updatedAt: DateTime.now());
      await isar.writeTxn(() async {
        await isar.products.put(p);
        if (p.usesSerials) {
          await SerialService.takeOut(isar, p.id, removedSerials, productName: p.name);
          await SerialService.add(isar, p.id, addedSerials);
          await SerialService.syncStock(isar, {p.id});
        }
      });
    });
    if (state.hasError) throw state.error!;
  }

  Future<int?> deleteProduct(int id) async {
    int? trashId;
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final trash = TrashService(isar);

      final inUse = await isar.orders
          .filter()
          .itemsElement((q) => q.productIdEqualTo(id))
          .isNotEmpty();
      if (inUse) {

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

        final movements = await isar.stockMovements
            .filter()
            .productIdEqualTo(id)
            .findAll();
        final serials = await SerialService.ofProduct(isar, id);

        trashId = await trash.capture(
          kind: TrashKind.product,
          originalId: id,
          payload: product.toJson(),
          sidecar: {
            'softDeleted': false,
            'stockMovements': movements.map((m) => m.toJson()).toList(),
            if (serials.isNotEmpty) 'productSerials': serials.map((s) => s.toJson()).toList(),
          },
          label: product.name,
          sublabel: product.sku,
        );

        await isar.stockMovements
            .deleteAll(movements.map((m) => m.id).toList());
        await isar.productSerials.deleteAll([for (final s in serials) s.id]);
        await isar.products.delete(id);
      });
    });
    return trashId;
  }

  Future<void> adjustStock(
      int productId, double delta, String reason, StockMovementType type,
      {String combinationKey = '',
      String supplierName = '',
      int supplierId = 0,
      DateTime? at,
      List<String> serials = const []}) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final product = await isar.products.get(productId);
        if (product == null) return;

        // A serial-tracked product moves by serial: a restock adds [serials],
        // a sale or damage takes those in stock out. The count is the delta.
        if (product.usesSerials) {
          if (serials.isEmpty) throw SerialsMissingException(product.name);
          final incoming = type == StockMovementType.restock;
          if (incoming) {
            await SerialService.add(isar, productId, serials, at: at);
          } else {
            await SerialService.takeOut(isar, productId, serials,
                status: type == StockMovementType.sale ? SerialStatus.sold : SerialStatus.removed,
                at: at,
                productName: product.name);
          }
          String fullReason = [
            if (supplierName.isNotEmpty) 'From: $supplierName',
            if (reason.isNotEmpty) reason,
          ].join(' — ');
          await isar.stockMovements.put(StockMovement(
            productId: productId,
            productName: product.name,
            type: type,
            qty: (incoming ? 1 : -1) * serials.length.toDouble(),
            reason: [fullReason, serials.join(', ')].where((t) => t.isNotEmpty).join(' · '),
            supplierId: supplierId,
            createdAt: at ?? DateTime.now(),
          ));
          return;
        }

        var updated = product.copyWith(
          stockQty: clampStock(product.stockQty + delta),
          updatedAt: DateTime.now(),
        );

        if (combinationKey.isNotEmpty) {
          final updatedCombinations = updated.variantCombinations.map((c) {
            if (c.combinationKey == combinationKey) {
              return c.copyWith(stockQty: clampStock(c.stockQty + delta));
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

        String fullReason = reason;
        if (supplierName.isNotEmpty) {
          final prefix = 'From: $supplierName';
          fullReason = reason.isNotEmpty ? '$prefix — $reason' : prefix;
        }

        await isar.stockMovements.put(StockMovement(
          productId: productId,
          productName: movementName,
          type: type,
          qty: roundQty(delta),
          reason: fullReason,
          supplierId: supplierId,
          createdAt: at ?? DateTime.now(),
        ));
      });
    });
    if (state.hasError) throw state.error!;
  }
}
