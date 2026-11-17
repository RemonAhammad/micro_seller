import 'package:isar_community/isar.dart';

import '../../core/utils/quantity.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/product_serial.dart';

/// A serial typed twice, or one the product already has.
class DuplicateSerialException implements Exception {
  const DuplicateSerialException(this.serial);
  final String serial;
  @override
  String toString() => 'DuplicateSerialException: $serial';
}

/// A serial that is not in stock (sold on another order, removed, or never
/// entered) where a sale needs it.
class SerialNotAvailableException implements Exception {
  const SerialNotAvailableException(this.serial, this.productName);
  final String serial;
  final String productName;
  @override
  String toString() => 'SerialNotAvailableException: $productName $serial';
}

/// A line of a serial-tracked product whose serials don't match its
/// quantity (none picked, or a recurring copy).
class SerialsMissingException implements Exception {
  const SerialsMissingException(this.productName);
  final String productName;
  @override
  String toString() => 'SerialsMissingException: $productName';
}

/// Trimmed; what every serial is stored and compared as (case ignored).
String normalizeSerial(String raw) => raw.trim();

String _key(String serial) => normalizeSerial(serial).toLowerCase();

/// Serials typed or pasted in one go: one per line, or separated by commas
/// or semicolons; blanks dropped, repeats kept once (first spelling wins).
List<String> splitSerials(String text) {
  final seen = <String>{};
  return [
    for (final part in text.split(RegExp(r'[\n\r,;\t]+')))
      if (normalizeSerial(part).isNotEmpty && seen.add(_key(part))) normalizeSerial(part),
  ];
}

/// Reading and writing serial numbers. Every write runs inside the caller's
/// `writeTxn` and ends with [syncStock], so a tracked product's `stockQty`
/// is always the number of its serials in stock.
class SerialService {
  const SerialService._();

  // ── reads ──

  static Future<List<ProductSerial>> ofProduct(Isar isar, int productId) async =>
      (await isar.productSerials.where().productIdEqualTo(productId).findAll())
        ..sort((a, b) => a.id.compareTo(b.id));

  static Future<List<ProductSerial>> inStock(Isar isar, int productId) async =>
      [for (final s in await ofProduct(isar, productId)) if (s.isInStock) s];

  /// Every unit with this serial, any product (case ignored), newest first.
  static Future<List<ProductSerial>> find(Isar isar, String code) async {
    final serial = normalizeSerial(code);
    if (serial.isEmpty) return const [];
    return (await isar.productSerials.where().serialEqualTo(serial).findAll())
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  // ── writes (inside a writeTxn) ──

  /// Adds [serials] to [productId] in stock. Throws
  /// [DuplicateSerialException] (and writes nothing) for a blank one, one
  /// repeated in [serials], or one the product already has.
  static Future<List<ProductSerial>> add(
    Isar isar,
    int productId,
    List<String> serials, {
    int purchaseId = 0,
    DateTime? at,
  }) async {
    if (serials.isEmpty) return const [];
    final existing = {for (final s in await ofProduct(isar, productId)) _key(s.serial)};
    final now = DateTime.now();
    final rows = <ProductSerial>[];
    for (final raw in serials) {
      final serial = normalizeSerial(raw);
      if (serial.isEmpty || !existing.add(_key(serial))) throw DuplicateSerialException(serial);
      rows.add(ProductSerial(
        productId: productId,
        serial: serial,
        purchaseId: purchaseId,
        createdAt: at ?? now,
        updatedAt: now,
      ));
    }
    await isar.productSerials.putAll(rows);
    await syncStock(isar, {productId});
    return rows;
  }

  /// Marks the serials of [items] sold on [orderId]. For a product that
  /// tracks serials, every line must carry exactly its quantity of serials
  /// ([SerialsMissingException]) and each must be in stock, or already sold
  /// on this order ([SerialNotAvailableException]). Lines of other products
  /// are skipped.
  static Future<void> sell(
    Isar isar,
    List<OrderItem> items, {
    required int orderId,
    DateTime? soldAt,
  }) async {
    final products = await _trackedProducts(isar, items);
    if (products.isEmpty) return;
    final now = DateTime.now();
    final changed = <ProductSerial>[];
    final used = <String>{};
    for (final item in items) {
      final product = products[item.productId];
      if (product == null) continue;
      if (item.serials.length != roundQty(item.qty).round() || item.serials.isEmpty) {
        throw SerialsMissingException(item.productName);
      }
      final byKey = {for (final s in await ofProduct(isar, product.id)) _key(s.serial): s};
      for (final serial in item.serials) {
        final row = byKey[_key(serial)];
        final ok = row != null &&
            (row.isInStock || (row.status == SerialStatus.sold && row.orderId == orderId));
        if (!ok || !used.add('${product.id}/${_key(serial)}')) {
          throw SerialNotAvailableException(normalizeSerial(serial), item.productName);
        }
        changed.add(row.copyWith(
          status: SerialStatus.sold,
          orderId: orderId,
          soldAt: soldAt ?? now,
          updatedAt: now,
        ));
      }
    }
    await isar.productSerials.putAll(changed);
    await syncStock(isar, products.keys);
  }

  /// Puts back in stock the serials of [items] sold on [orderId] (a
  /// rollback, cancel, delete, or an approved return of that order). Others
  /// are left as they are.
  static Future<void> release(Isar isar, List<OrderItem> items, {required int orderId}) async {
    final withSerials = [for (final i in items) if (i.serials.isNotEmpty) i];
    if (withSerials.isEmpty) return;
    final now = DateTime.now();
    final changed = <ProductSerial>[];
    final touched = <int>{};
    for (final item in withSerials) {
      final keys = {for (final s in item.serials) _key(s)};
      for (final row in await ofProduct(isar, item.productId)) {
        if (row.status == SerialStatus.sold && row.orderId == orderId && keys.contains(_key(row.serial))) {
          changed.add(row.copyWith(status: SerialStatus.inStock, orderId: 0, clearSoldAt: true, updatedAt: now));
          touched.add(item.productId);
        }
      }
    }
    await isar.productSerials.putAll(changed);
    await syncStock(isar, touched);
  }

  /// Takes in-stock serials out of stock: [SerialStatus.removed] (damage, or
  /// removed in the product form) or [SerialStatus.sold] (a stock "sale"
  /// entry, with no order). Throws [SerialNotAvailableException] for one not
  /// in stock.
  static Future<void> takeOut(
    Isar isar,
    int productId,
    List<String> serials, {
    SerialStatus status = SerialStatus.removed,
    DateTime? at,
    String productName = '',
  }) async {
    if (serials.isEmpty) return;
    final byKey = {for (final s in await ofProduct(isar, productId)) _key(s.serial): s};
    final now = DateTime.now();
    final changed = <ProductSerial>[];
    for (final serial in serials) {
      final row = byKey[_key(serial)];
      if (row == null || !row.isInStock) throw SerialNotAvailableException(normalizeSerial(serial), productName);
      changed.add(row.copyWith(
        status: status,
        soldAt: status == SerialStatus.sold ? (at ?? now) : null,
        updatedAt: now,
      ));
    }
    await isar.productSerials.putAll(changed);
    await syncStock(isar, {productId});
  }

  /// Deletes the serials that came with [purchaseId] and are still in stock
  /// (the purchase is being deleted); sold ones keep their history.
  /// Returns how many were deleted per product.
  static Future<Map<int, int>> deleteUnsoldOfPurchase(Isar isar, int purchaseId, Iterable<int> productIds) async {
    final ids = <int>[];
    final removed = <int, int>{};
    for (final productId in productIds.toSet()) {
      for (final row in await ofProduct(isar, productId)) {
        if (row.purchaseId == purchaseId && row.isInStock) {
          ids.add(row.id);
          removed[productId] = (removed[productId] ?? 0) + 1;
        }
      }
    }
    await isar.productSerials.deleteAll(ids);
    await syncStock(isar, removed.keys);
    return removed;
  }

  /// Sets each serial-tracked product's stock to its serials in stock.
  static Future<void> syncStock(Isar isar, Iterable<int> productIds) async {
    final ids = productIds.toSet().toList();
    if (ids.isEmpty) return;
    final updated = <Product>[];
    final products = await isar.products.getAll(ids);
    for (final p in products) {
      if (p == null || !p.usesSerials) continue;
      final count = await isar.productSerials
          .where()
          .productIdEqualTo(p.id)
          .filter()
          .statusEqualTo(SerialStatus.inStock)
          .count();
      if (p.stockQty != count) updated.add(p.copyWith(stockQty: count.toDouble(), updatedAt: DateTime.now()));
    }
    await isar.products.putAll(updated);
  }

  static Future<Map<int, Product>> _trackedProducts(Isar isar, List<OrderItem> items) async {
    final ids = {for (final i in items) i.productId}.toList();
    if (ids.isEmpty) return const {};
    return {
      for (final p in await isar.products.getAll(ids))
        if (p != null && p.usesSerials) p.id: p,
    };
  }
}
