import 'package:isar_community/isar.dart';
import '../../core/utils/barcode.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../models/variant_combination.dart';

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

  /// The product a scanned [raw] code names: its QR code, its SKU or one of
  /// its variants' SKUs (a variant opens its product), in any letter case,
  /// the code trimmed. A UPC-A is asked for in both spellings
  /// ([barcodeLookupForms]): iOS reads it as 13 digits, Android as 12, so a
  /// code saved from one phone's scan is found by the other's. Products in
  /// the Recycle Bin (inactive) don't match. Null when none does.
  Future<Product?> findByScannedCode(String raw) async {
    final forms = barcodeLookupForms(raw);
    if (forms.isEmpty) return null;
    return _isar.products
        .filter()
        .isActiveEqualTo(true)
        .and()
        .anyOf(
            forms,
            (q, code) => q
                .qrCodeEqualTo(code, caseSensitive: false)
                .or()
                .skuEqualTo(code, caseSensitive: false)
                .or()
                .variantCombinationsElement(
                    (c) => c.skuEqualTo(code, caseSensitive: false)))
        .findFirst();
  }

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
