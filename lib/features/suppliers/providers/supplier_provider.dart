import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/supplier.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/services/isar_service.dart';



part 'supplier_provider.g.dart';

@riverpod
Stream<List<Supplier>> suppliers(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.suppliers
      .where()
      .sortByName()
      .watch(fireImmediately: true);
}

@riverpod
Stream<List<Purchase>> purchases(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.purchases
      .where()
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);
}

@riverpod
Stream<List<Purchase>> supplierPurchases(Ref ref, int supplierId) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.purchases
      .filter()
      .supplierIdEqualTo(supplierId)
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);
}

@riverpod
Stream<List<Product>> supplierProducts(Ref ref, int supplierId) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.products
      .filter()
      .supplierIdEqualTo(supplierId)
      .and()
      .isActiveEqualTo(true)
      .sortByName()
      .watch(fireImmediately: true);
}

@riverpod
Stream<List<StockMovement>> supplierStockMovements(
    Ref ref, int supplierId) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.stockMovements
      .filter()
      .supplierIdEqualTo(supplierId)
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);
}

@riverpod
class SupplierNotifier extends _$SupplierNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> addSupplier(Supplier supplier) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        await isar.suppliers.put(supplier.copyWith(
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      });
    });
  }

  Future<void> updateSupplier(Supplier supplier) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        await isar.suppliers.put(supplier.copyWith(updatedAt: DateTime.now()));
      });
    });
  }

  Future<void> deleteSupplier(int id) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        // Unlink purchases (keep purchase records but clear supplierId)
        final purchases = await isar.purchases
            .filter()
            .supplierIdEqualTo(id)
            .findAll();
        for (final p in purchases) {
          await isar.purchases.put(p.copyWith(supplierId: 0));
        }
        // Unlink products linked to this supplier (set supplierId = 0)
        final products = await isar.products
            .filter()
            .supplierIdEqualTo(id)
            .findAll();
        for (final p in products) {
          await isar.products.put(p.copyWith(supplierId: 0));
        }
        await isar.suppliers.delete(id);
      });
    });
  }

  /// Create a purchase, update supplier stats (if linked), restock products,
  /// and update product cost price.
  /// Supplier is optional — pass supplierId=0 for purchases with no supplier.
  Future<void> createPurchase(Purchase purchase, {bool restockProducts = true, bool updateCostPrice = true}) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        await isar.purchases.put(purchase.copyWith(createdAt: DateTime.now()));

        // Update supplier stats (only if linked)
        if (purchase.supplierId > 0) {
          final supplier = await isar.suppliers.get(purchase.supplierId);
          if (supplier != null) {
            await isar.suppliers.put(supplier.copyWith(
              totalPurchases: supplier.totalPurchases + 1,
              totalPaid: supplier.totalPaid + purchase.amountPaid,
              totalDue: supplier.totalDue + purchase.balanceDue,
              updatedAt: DateTime.now(),
            ));
          }
        }

        // Restock products + update cost price
        if (restockProducts) {
          final reason = purchase.supplierName.isNotEmpty
              ? 'Purchase from ${purchase.supplierName}'
              : 'Purchase';
          for (final item in purchase.items) {
            if (item.productId <= 0 || item.qty <= 0) continue;
            final product = await isar.products.get(item.productId);
            if (product != null) {
              final updated = product.copyWith(
                stockQty: product.stockQty + item.qty,
                costPrice: updateCostPrice && item.unitCost > 0
                    ? item.unitCost
                    : product.costPrice,
                updatedAt: DateTime.now(),
              );
              await isar.products.put(updated);
              await isar.stockMovements.put(StockMovement(
                productId: item.productId,
                productName: item.productName,
                type: StockMovementType.restock,
                qty: item.qty,
                reason: reason,
                supplierId: purchase.supplierId,
                createdAt: DateTime.now(),
              ));
            }
          }
        }
      });
    });
  }

  Future<void> deletePurchase(int id) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final purchase = await isar.purchases.get(id);
        if (purchase == null) return;

        // Reverse supplier stats
        if (purchase.supplierId > 0) {
          final supplier = await isar.suppliers.get(purchase.supplierId);
          if (supplier != null) {
            await isar.suppliers.put(supplier.copyWith(
              totalPurchases: (supplier.totalPurchases - 1).clamp(0, 999999),
              totalPaid: (supplier.totalPaid - purchase.amountPaid).clamp(0, double.infinity),
              totalDue: (supplier.totalDue - purchase.balanceDue).clamp(0, double.infinity),
              updatedAt: DateTime.now(),
            ));
          }
        }

        // Reverse stock (deduct what was added)
        for (final item in purchase.items) {
          if (item.productId <= 0 || item.qty <= 0) continue;
          final product = await isar.products.get(item.productId);
          if (product != null) {
            await isar.products.put(product.copyWith(
              stockQty: (product.stockQty - item.qty).clamp(0, 999999),
              updatedAt: DateTime.now(),
            ));
            await isar.stockMovements.put(StockMovement(
              productId: item.productId,
              productName: item.productName,
              type: StockMovementType.adjustment,
              qty: -item.qty,
              reason: 'Deleted purchase',
              createdAt: DateTime.now(),
            ));
          }
        }

        await isar.purchases.delete(id);
      });
    });
  }

  Future<void> recordPurchasePayment(int purchaseId, double amount) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final purchase = await isar.purchases.get(purchaseId);
        if (purchase == null) return;
        final newAmountPaid = purchase.amountPaid + amount;
        await isar.purchases.put(purchase.copyWith(amountPaid: newAmountPaid));

        // Update supplier stats
        if (purchase.supplierId > 0) {
          final supplier = await isar.suppliers.get(purchase.supplierId);
          if (supplier != null) {
            await isar.suppliers.put(supplier.copyWith(
              totalPaid: supplier.totalPaid + amount,
              totalDue: (supplier.totalDue - amount).clamp(0, double.infinity),
              updatedAt: DateTime.now(),
            ));
          }
        }
      });
    });
  }

  /// Record a payment to a supplier against their due balance
  Future<void> recordSupplierPayment(int supplierId, double amount) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final supplier = await isar.suppliers.get(supplierId);
        if (supplier == null) return;
        await isar.suppliers.put(supplier.copyWith(
          totalPaid: supplier.totalPaid + amount,
          totalDue: (supplier.totalDue - amount).clamp(0, double.infinity),
          updatedAt: DateTime.now(),
        ));
      });
    });
  }
}
