import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;
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
import '../models/sales_target.dart';
import '../models/trash_entry.dart';
import 'backup_format.dart';

class InvalidBackupException extends FormatException {
  const InvalidBackupException(super.message);
}

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
        salesTargets: db.salesTargets.where().findAllSync(),
        settings: settings,
      ));
  final bytes = JsonUtf8Encoder().convert(map);
  return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
}

Uint8List Function(Isar) backupBytesJob(Map<String, dynamic>? settings) =>
    (db) => encodeBackupBytesSync(db, settings: settings);

Map<String, dynamic> parseBackupBytes(Uint8List bytes,
    {bool requireMetadata = false}) {
  final Object? data;
  try {

    data = const Utf8Decoder().fuse(const JsonDecoder()).convert(bytes);
  } on FormatException catch (e) {

    throw InvalidBackupException(
        'Backup file is corrupted or unreadable: ${e.message}');
  }
  if (data is! Map<String, dynamic>) {
    throw const InvalidBackupException(
        'Backup file is corrupted or unreadable.');
  }
  return validateBackupMap(data, requireMetadata: requireMetadata);
}

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
  db.salesTargets.clearSync();

  db.trashEntries.clearSync();
}

void clearAllDataJob(Isar db) =>
    db.writeTxnSync(() => clearAllCollectionsInTxnSync(db));

Map<String, dynamic>? restoreBackupSync(Isar db, Map<String, dynamic> data) {

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
  final salesTargets = rows('salesTargets', SalesTarget.fromJson);

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
    db.salesTargets.putAllSync(salesTargets);

    recalculateOutstandingBalancesInTxnSync(db);
  });

  final settings = data['settings'];
  return settings is Map<String, dynamic> ? settings : null;
}

Map<String, dynamic>? Function(Isar) restoreBackupJob(Uint8List bytes,
        {bool requireMetadata = false}) =>
    (db) => restoreBackupSync(
        db, parseBackupBytes(bytes, requireMetadata: requireMetadata));

class LocalBackupService {

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
      salesTargets: await isar.salesTargets.where().findAll(),
      settings: settings,
    ));
  }

  Future<Uint8List> encodeAllBytes(Isar isar,
          {Map<String, dynamic>? settings}) =>
      runDbJob(isar, backupBytesJob(settings));

  Future<Map<String, dynamic>?> restoreBytes(Isar isar, Uint8List bytes,
          {bool requireMetadata = false}) =>
      runDbJob(isar, restoreBackupJob(bytes, requireMetadata: requireMetadata));

  Future<Map<String, dynamic>?> decodeAll(Isar isar, String jsonStr) async =>
      decodeAllFromMap(isar, jsonDecode(jsonStr) as Map<String, dynamic>);

  Future<Map<String, dynamic>?> decodeAllFromMap(
          Isar isar, Map<String, dynamic> data) async =>
      restoreBackupSync(isar, validateBackupMap(data));

  Future<void> clearAll(Isar isar) => runDbJob(isar, clearAllDataJob);

  Future<String?> exportBackup(Isar isar,
      {Map<String, dynamic>? settings, Rect? shareOrigin}) async {
    final bytes = await encodeAllBytes(isar, settings: settings);

    final dir = await Directory.systemTemp.createTemp('microseller_backup');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/microseller_backup_$timestamp.json');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      subject: 'Micro Seller Backup',
      sharePositionOrigin: shareOrigin,
    ));

    return file.path;
  }

  Future<String?> exportToDirectory(Isar isar, String directoryPath,
      {Map<String, dynamic>? settings}) async {
    final bytes = await encodeAllBytes(isar, settings: settings);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('$directoryPath/microseller_backup_$timestamp.json');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<Map<String, dynamic>?> importBackup(Isar isar) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null) return null;

    final settings = await restoreBytes(isar, await picked.readAsBytes());

    return settings ?? <String, dynamic>{};
  }
}
