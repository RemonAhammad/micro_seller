import 'package:isar/isar.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

class ProductRepository {
  final Isar _isar;
  ProductRepository(this._isar);

  Stream<List<Product>> watchAll({bool activeOnly = true}) {
    var query = _isar.products.where();
    if (activeOnly) {
      return query.filter().isActiveEqualTo(true).watch(fireImmediately: true);
    }
    return query.watch(fireImmediately: true);
  }

  Stream<List<Product>> watchLowStock() {
    return _isar.products
        .where()
        .filter()
        .isActiveEqualTo(true)
        .watch(fireImmediately: true)
        .map((products) => products
            .where((p) => p.isLowStock || p.isOutOfStock)
            .toList());
  }

  Future<List<Product>> getAll() => _isar.products.where().findAll();

  Future<Product?> getById(int id) => _isar.products.get(id);

  Future<Product?> getBySku(String sku) =>
      _isar.products.filter().skuEqualTo(sku).findFirst();

  Future<void> save(Product product) async {
    await _isar.writeTxn(() => _isar.products.put(product));
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.products.delete(id));
  }

  Future<void> adjustStock(int productId, int delta, String reason,
      StockMovementType type) async {
    await _isar.writeTxn(() async {
      final product = await _isar.products.get(productId);
      if (product == null) return;
      final updated = product.copyWith(
        stockQty: product.stockQty + delta,
        updatedAt: DateTime.now(),
      );
      await _isar.products.put(updated);
      await _isar.stockMovements.put(StockMovement(
        productId: productId,
        productName: product.name,
        type: type,
        qty: delta,
        reason: reason,
        createdAt: DateTime.now(),
      ));
    });
  }

  Future<int> generateNextSku(String prefix) async {
    final count = await _isar.products.count();
    return count + 1;
  }
}
