import 'package:isar_community/isar.dart';
import '../../core/utils/barcode.dart';
import '../../core/utils/quantity.dart';
import '../../core/utils/scale_barcode.dart';
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

  /// A scan: the product whose code it is, as [findByScannedCode], else —
  /// when scale labels are on — the product whose code is the label's item
  /// code, with the label (its weight or price) to fill the quantity.
  Future<({Product product, ScaleLabel? label})?> findByScan(
      String raw, ScaleLabelSettings scale) async {
    final direct = await findByScannedCode(raw);
    if (direct != null) return (product: direct, label: null);
    final label = parseScaleLabel(raw, scale);
    if (label == null) return null;
    for (final form in label.itemCodeForms) {
      final product = await findByScannedCode(form);
      if (product != null) return (product: product, label: label);
    }
    return null;
  }

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

  Future<void> adjustStock(int productId, double delta, String reason,
      StockMovementType type) async {
    await _isar.writeTxn(() async {
      final product = await _isar.products.get(productId);
      if (product == null) return;
      final updated = product.copyWith(
        stockQty: roundQty(product.stockQty + delta),
        updatedAt: DateTime.now(),
      );
      await _isar.products.put(updated);
      await _isar.stockMovements.put(StockMovement(
        productId: productId,
        productName: product.name,
        type: type,
        qty: roundQty(delta),
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
