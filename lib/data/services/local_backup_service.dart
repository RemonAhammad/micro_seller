import 'dart:convert';
import 'dart:io';
import 'package:isar/isar.dart';
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

class LocalBackupService {
  static const _backupVersion = 2;

  /// Serialize all 9 collections to a JSON string.
  Future<String> encodeAll(Isar isar) async {
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
      'appName': 'MicroSeller',
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
    });
  }

  /// Validate + clear + import all 9 collections from a JSON string.
  Future<void> decodeAll(Isar isar, String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    if (data['products'] == null && data['orders'] == null) {
      throw const FormatException(
          'Invalid backup file — missing required collections');
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

      if (data['products'] != null) {
        await isar.products.putAll((data['products'] as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList());
      }
      if (data['orders'] != null) {
        await isar.orders.putAll((data['orders'] as List)
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList());
      }
      if (data['customers'] != null) {
        await isar.customers.putAll((data['customers'] as List)
            .map((e) => Customer.fromJson(e as Map<String, dynamic>))
            .toList());
      }
      if (data['expenses'] != null) {
        await isar.expenses.putAll((data['expenses'] as List)
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList());
      }
      if (data['stockMovements'] != null) {
        await isar.stockMovements.putAll((data['stockMovements'] as List)
            .map((e) => StockMovement.fromJson(e as Map<String, dynamic>))
            .toList());
      }
      if (data['categories'] != null) {
        await isar.categories.putAll((data['categories'] as List)
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList());
      }
      if (data['suppliers'] != null) {
        await isar.suppliers.putAll((data['suppliers'] as List)
            .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
            .toList());
      }
      if (data['purchases'] != null) {
        await isar.purchases.putAll((data['purchases'] as List)
            .map((e) => Purchase.fromJson(e as Map<String, dynamic>))
            .toList());
      }
      if (data['cashRegisters'] != null) {
        await isar.cashRegisters.putAll((data['cashRegisters'] as List)
            .map((e) => CashRegister.fromJson(e as Map<String, dynamic>))
            .toList());
      }
    });
  }

  /// Export all data as a JSON file and share it.
  Future<String?> exportBackup(Isar isar) async {
    final json = await encodeAll(isar);

    final dir = await Directory.systemTemp.createTemp('microseller_backup');
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/microseller_backup_$timestamp.json');
    await file.writeAsString(json);

    await Share.shareXFiles([XFile(file.path)],
        subject: 'MicroSeller Backup');

    return file.path;
  }

  /// Export to a specific directory (no share sheet).
  Future<String?> exportToDirectory(Isar isar, String directoryPath) async {
    final json = await encodeAll(isar);
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('$directoryPath/microseller_backup_$timestamp.json');
    await file.writeAsString(json);
    return file.path;
  }

  /// Pick a JSON backup file and restore data from it.
  /// Returns true if successful.
  Future<bool> importBackup(Isar isar) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return false;

    final filePath = result.files.single.path;
    if (filePath == null) return false;

    final file = File(filePath);
    final jsonStr = await file.readAsString();
    await decodeAll(isar, jsonStr);
    return true;
  }
}
