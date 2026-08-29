import 'dart:convert';
import 'dart:io';
import 'package:isar_community/isar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/stock_movement.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../models/purchase.dart';
import '../models/cash_register.dart';
import '../models/trash_entry.dart';

class LocalBackupService {
  /// Bumped to v3 when the `settings` payload was added. Older v2 backups
  /// (collections only) still restore cleanly — settings field is optional.
  static const _backupVersion = 3;

  /// Serialize all 9 collections + (optionally) the user's settings to a
  /// JSON string. Pass `settings` from `Settings.exportSettings()` to include
  /// preferences (theme, currency, sidebar order, etc.) in the backup.
  Future<String> encodeAll(Isar isar, {Map<String, dynamic>? settings}) async {
    final products = await isar.products.where().findAll();
    final orders = await isar.orders.where().findAll();
    final customers = await isar.customers.where().findAll();
    final expenses = await isar.expenses.where().findAll();
    final movements = await isar.stockMovements.where().findAll();
    final categories = await isar.categories.where().findAll();
    final suppliers = await isar.suppliers.where().findAll();
    final purchases = await isar.purchases.where().findAll();
    final cashRegisters = await isar.cashRegisters.where().findAll();

    return jsonEncode({
      'version': _backupVersion,
      'appName': 'Micro Seller',
      'timestamp': DateTime.now().toIso8601String(),
      'products': products.map((e) => e.toJson()).toList(),
      'orders': orders.map((e) => e.toJson()).toList(),
      'customers': customers.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'stockMovements': movements.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'suppliers': suppliers.map((e) => e.toJson()).toList(),
      'purchases': purchases.map((e) => e.toJson()).toList(),
      'cashRegisters': cashRegisters.map((e) => e.toJson()).toList(),
      if (settings != null) 'settings': settings,
    });
  }

  /// Validate + clear + import all 9 collections from a JSON string.
  /// Returns the embedded `settings` map if the backup contained one
  /// (caller is responsible for applying it via `Settings.importSettings`),
  /// otherwise null. Kept decoupled from the Riverpod settings provider so
  /// LocalBackupService stays a leaf-level service.
  Future<Map<String, dynamic>?> decodeAll(Isar isar, String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    if (data['products'] == null && data['orders'] == null) {
      throw const FormatException('Invalid backup file — missing required collections');
    }

    await isar.writeTxn(() async {
      await isar.products.clear();
      await isar.orders.clear();
      await isar.customers.clear();
      await isar.expenses.clear();
      await isar.stockMovements.clear();
      await isar.categories.clear();
      await isar.suppliers.clear();
      await isar.purchases.clear();
      await isar.cashRegisters.clear();
      // Trash is deliberately NOT part of the backup payload, but it must be
      // cleared here anyway: its entries reference ids from the dataset being
      // replaced, so restoring one afterwards would write stale rows over
      // unrelated records.
      await isar.trashEntries.clear();

      if (data['products'] != null) {
        await isar.products
            .putAll((data['products'] as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (data['orders'] != null) {
        await isar.orders
            .putAll((data['orders'] as List).map((e) => Order.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (data['customers'] != null) {
        await isar.customers
            .putAll((data['customers'] as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (data['expenses'] != null) {
        await isar.expenses
            .putAll((data['expenses'] as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (data['stockMovements'] != null) {
        await isar.stockMovements.putAll(
            (data['stockMovements'] as List).map((e) => StockMovement.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (data['categories'] != null) {
        await isar.categories
            .putAll((data['categories'] as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (data['suppliers'] != null) {
        await isar.suppliers
            .putAll((data['suppliers'] as List).map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (data['purchases'] != null) {
        await isar.purchases
            .putAll((data['purchases'] as List).map((e) => Purchase.fromJson(e as Map<String, dynamic>)).toList());
      }
      if (data['cashRegisters'] != null) {
        await isar.cashRegisters.putAll(
            (data['cashRegisters'] as List).map((e) => CashRegister.fromJson(e as Map<String, dynamic>)).toList());
      }
    });

    final settings = data['settings'];
    if (settings is Map<String, dynamic>) return settings;
    return null;
  }

  /// Export all data as a JSON file and share it.
  Future<String?> exportBackup(Isar isar,
      {Map<String, dynamic>? settings}) async {
    final json = await encodeAll(isar, settings: settings);

    final dir = await Directory.systemTemp.createTemp('microseller_backup');
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/microseller_backup_$timestamp.json');
    await file.writeAsString(json);

    await Share.shareXFiles([XFile(file.path)], subject: 'Micro Seller Backup');

    return file.path;
  }

  /// Export to a specific directory (no share sheet).
  Future<String?> exportToDirectory(Isar isar, String directoryPath,
      {Map<String, dynamic>? settings}) async {
    final json = await encodeAll(isar, settings: settings);
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('$directoryPath/microseller_backup_$timestamp.json');
    await file.writeAsString(json);
    return file.path;
  }

  /// Pick a JSON backup file and restore data from it.
  /// Returns the embedded settings map (if any) on success so the caller can
  /// apply preferences via `Settings.importSettings`. Returns null when the
  /// user cancels the file picker.
  Future<Map<String, dynamic>?> importBackup(Isar isar) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;

    final filePath = result.files.single.path;
    if (filePath == null) return null;

    final file = File(filePath);
    final jsonStr = await file.readAsString();
    return await decodeAll(isar, jsonStr);
  }
}
