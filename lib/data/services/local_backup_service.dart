import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/payment.dart';
import 'db_worker.dart';
import 'dues_service.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/stock_movement.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../models/cash_register.dart';
import '../models/trash_entry.dart';
import 'backup_format.dart';

/// The bytes aren't a usable backup: not UTF-8 JSON, not an object, missing
/// the metadata a Drive backup must carry, or missing both products and
/// orders. Always thrown before anything is written.
class InvalidBackupException extends FormatException {
  const InvalidBackupException(super.message);
}

// ── Synchronous core ──
//
// Backup encode and restore are synchronous so they can run on a worker
// isolate ([runDbJob]): with thousands of orders, reading the collections,
// toJson/fromJson, JSON encoding and Isar's put serialization each freeze
// whichever isolate does them. Jobs are built by top-level functions that
// capture only plain values (bytes, a settings map), so they can cross
// isolates.

/// Reads all 10 backed-up collections in one read transaction (a consistent
/// snapshot) and encodes the backup JSON ([buildBackupMap]) straight to UTF-8
/// bytes — the same bytes as `utf8.encode(await encodeAll(...))`.
///
/// Synchronous: for a worker isolate ([backupBytesJob]), or an isolate with
/// no UI (the WorkManager auto-backup).
Uint8List encodeBackupBytesSync(Isar db, {Map<String, dynamic>? settings}) {
  final map = db.txnSync(() => buildBackupMap(
        products: db.products.where().findAllSync(),
        orders: db.orders.where().findAllSync(),
        customers: db.customers.where().findAllSync(),
        expenses: db.expenses.where().findAllSync(),
        stockMovements: db.stockMovements.where().findAllSync(),
        categories: db.categories.where().findAllSync(),
        suppliers: db.suppliers.where().findAllSync(),
        purchases: db.purchases.where().findAllSync(),
        cashRegisters: db.cashRegisters.where().findAllSync(),
        payments: db.payments.where().findAllSync(),
        settings: settings,
      ));
  final bytes = JsonUtf8Encoder().convert(map);
  return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

/// [encodeBackupBytesSync] as a [runDbJob] job.
Uint8List Function(Isar) backupBytesJob(Map<String, dynamic>? settings) =>
    (db) => encodeBackupBytesSync(db, settings: settings);

/// Decodes and validates backup bytes. [requireMetadata] — also require the
/// `version` / `timestamp` envelope (Drive restores check it; local imports
/// never did). Throws [InvalidBackupException].
Map<String, dynamic> parseBackupBytes(Uint8List bytes,
    {bool requireMetadata = false}) {
  final Object? data;
  try {
    // Fused: parses the UTF-8 directly, without an intermediate String.
    data = const Utf8Decoder().fuse(const JsonDecoder()).convert(bytes);
  } on FormatException catch (e) {
    // Not rethrown as-is: its `source` is the whole file, which would be
    // copied back from a worker isolate.
    throw InvalidBackupException(
        'Backup file is corrupted or unreadable: ${e.message}');
  }
  if (data is! Map<String, dynamic>) {
    throw const InvalidBackupException(
        'Backup file is corrupted or unreadable.');
  }
  return validateBackupMap(data, requireMetadata: requireMetadata);
}

/// Throws [InvalidBackupException] if [data] isn't a restorable backup.
Map<String, dynamic> validateBackupMap(Map<String, dynamic> data,
    {bool requireMetadata = false}) {
  if (requireMetadata &&
      (!data.containsKey('version') || !data.containsKey('timestamp'))) {
    throw const InvalidBackupException(
        'Backup file is missing required metadata.');
  }
  if (data['products'] == null && data['orders'] == null) {
    throw const InvalidBackupException(
        'Invalid backup file — missing required collections');
  }
  return data;
}

/// Clears every collection — the 10 backed-up ones *and* the trash. Shared by
/// restore and Clear All Data, so the two can't drift apart. Caller owns the
/// write transaction.
void clearAllCollectionsInTxnSync(Isar db) {
  db.products.clearSync();
  db.orders.clearSync();
  db.customers.clearSync();
  db.expenses.clearSync();
  db.stockMovements.clearSync();
  db.categories.clearSync();
  db.suppliers.clearSync();
  db.purchases.clearSync();
  db.cashRegisters.clearSync();
  db.payments.clearSync();
  // Trash is deliberately NOT part of the backup payload, but it must be
  // cleared anyway: its entries reference ids from the dataset being
  // replaced (or wiped), so restoring one afterwards would write stale rows
  // over unrelated records.
  db.trashEntries.clearSync();
}

/// Clear All Data as a [runDbJob] job: one write transaction.
void clearAllDataJob(Isar db) =>
    db.writeTxnSync(() => clearAllCollectionsInTxnSync(db));

/// Replaces the database with a validated backup [data] in ONE write
/// transaction: clear every collection (trash included), import the 10
/// backed-up ones, recalculate customer balances. Returns the embedded
/// `settings` map, or null if the backup has none.
///
/// Rows are parsed before the transaction opens, so a malformed row fails
/// with nothing written, and the write lock is held only for the writes.
/// Synchronous: run it through [restoreBackupJob] from the UI isolate.
Map<String, dynamic>? restoreBackupSync(Isar db, Map<String, dynamic> data) {
  // Every collection is optional on decode: `payments` is absent in v2/v3
  // backups (before payment history existed) — those restore with an empty
  // history; order.amountPaid still carries the totals.
  List<T> rows<T>(String key, T Function(Map<String, dynamic>) fromJson) => [
        for (final e in (data[key] as List?) ?? const [])
          fromJson(e as Map<String, dynamic>),
      ];
  final products = rows('products', Product.fromJson);
  final orders = rows('orders', Order.fromJson);
  final customers = rows('customers', Customer.fromJson);
  final expenses = rows('expenses', Expense.fromJson);
  final stockMovements = rows('stockMovements', StockMovement.fromJson);
  final categories = rows('categories', Category.fromJson);
  final suppliers = rows('suppliers', Supplier.fromJson);
  final purchases = rows('purchases', Purchase.fromJson);
  final cashRegisters = rows('cashRegisters', CashRegister.fromJson);
  final payments = rows('payments', Payment.fromJson);

  db.writeTxnSync(() {
    clearAllCollectionsInTxnSync(db);
    db.products.putAllSync(products);
    db.orders.putAllSync(orders);
    db.customers.putAllSync(customers);
    db.expenses.putAllSync(expenses);
    db.stockMovements.putAllSync(stockMovements);
    db.categories.putAllSync(categories);
    db.suppliers.putAllSync(suppliers);
    db.purchases.putAllSync(purchases);
    db.cashRegisters.putAllSync(cashRegisters);
    db.payments.putAllSync(payments);
    // Older backups carry counters that drifted before dues were computed
    // from orders; the one-time migration flag won't re-run for them.
    recalculateOutstandingBalancesInTxnSync(db);
  });

  final settings = data['settings'];
  return settings is Map<String, dynamic> ? settings : null;
}

/// Parse + validate + [restoreBackupSync] of backup [bytes] as a [runDbJob]
/// job — nothing of the restore runs on the calling isolate. Only the
/// settings map comes back.
Map<String, dynamic>? Function(Isar) restoreBackupJob(Uint8List bytes,
        {bool requireMetadata = false}) =>
    (db) => restoreBackupSync(
        db, parseBackupBytes(bytes, requireMetadata: requireMetadata));

class LocalBackupService {
  /// Serialize all 10 collections + (optionally) the user's settings to a
  /// JSON string, on the calling isolate. Pass `settings` from
  /// `Settings.exportSettings()` to include preferences (theme, currency,
  /// sidebar order, etc.) in the backup.
  ///
  /// The app's backups use [encodeAllBytes] (worker isolate) instead; this
  /// is kept for callers that need a String.
  Future<String> encodeAll(Isar isar, {Map<String, dynamic>? settings}) async {
    return jsonEncode(buildBackupMap(
      products: await isar.products.where().findAll(),
      orders: await isar.orders.where().findAll(),
      customers: await isar.customers.where().findAll(),
      expenses: await isar.expenses.where().findAll(),
      stockMovements: await isar.stockMovements.where().findAll(),
      categories: await isar.categories.where().findAll(),
      suppliers: await isar.suppliers.where().findAll(),
      purchases: await isar.purchases.where().findAll(),
      cashRegisters: await isar.cashRegisters.where().findAll(),
      payments: await isar.payments.where().findAll(),
      settings: settings,
    ));
  }

  /// The backup as UTF-8 JSON bytes, read and encoded on a worker isolate.
  Future<Uint8List> encodeAllBytes(Isar isar,
          {Map<String, dynamic>? settings}) =>
      runDbJob(isar, backupBytesJob(settings));

  /// Validate + restore backup [bytes] on a worker isolate (see
  /// [restoreBackupSync]). Returns the embedded `settings` map, if any —
  /// the caller applies it via `Settings.importSettings`. Throws
  /// [InvalidBackupException] (nothing written) for a file that isn't a
  /// backup.
  Future<Map<String, dynamic>?> restoreBytes(Isar isar, Uint8List bytes,
          {bool requireMetadata = false}) =>
      runDbJob(isar, restoreBackupJob(bytes, requireMetadata: requireMetadata));

  /// Validate + clear + import all 10 collections from a JSON string, on the
  /// calling isolate (tests and tools; the app restores through
  /// [restoreBytes]). Returns the embedded `settings` map if the backup
  /// contained one (caller is responsible for applying it via
  /// `Settings.importSettings`), otherwise null. Kept decoupled from the
  /// Riverpod settings provider so LocalBackupService stays a leaf-level
  /// service.
  Future<Map<String, dynamic>?> decodeAll(Isar isar, String jsonStr) async =>
      decodeAllFromMap(isar, jsonDecode(jsonStr) as Map<String, dynamic>);

  /// [decodeAll] for an already-parsed backup map.
  Future<Map<String, dynamic>?> decodeAllFromMap(
          Isar isar, Map<String, dynamic> data) async =>
      restoreBackupSync(isar, validateBackupMap(data));

  /// Clear All Data: every collection, trash included, in one write
  /// transaction on a worker isolate.
  Future<void> clearAll(Isar isar) => runDbJob(isar, clearAllDataJob);

  /// Export all data as a JSON file and share it.
  Future<String?> exportBackup(Isar isar,
      {Map<String, dynamic>? settings}) async {
    final bytes = await encodeAllBytes(isar, settings: settings);

    final dir = await Directory.systemTemp.createTemp('microseller_backup');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/microseller_backup_$timestamp.json');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Micro Seller Backup'));

    return file.path;
  }

  /// Export to a specific directory (no share sheet).
  Future<String?> exportToDirectory(Isar isar, String directoryPath,
      {Map<String, dynamic>? settings}) async {
    final bytes = await encodeAllBytes(isar, settings: settings);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('$directoryPath/microseller_backup_$timestamp.json');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Pick a JSON backup file and restore data from it.
  /// Returns the embedded settings map (if any) on success so the caller can
  /// apply preferences via `Settings.importSettings`. Returns null when the
  /// user cancels the file picker.
  Future<Map<String, dynamic>?> importBackup(Isar isar) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null) return null;

    // Content URIs (Android SAF) have no local path — read bytes instead.
    // Decode and restore run on a worker isolate.
    final settings = await restoreBytes(isar, await picked.readAsBytes());
    // A backup without a settings payload (v2) still restored: non-null
    // tells the caller it succeeded.
    return settings ?? <String, dynamic>{};
  }
}
