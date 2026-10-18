import '../models/cash_register.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/stock_movement.dart';
import '../models/supplier.dart';

/// Bumped to v3 when the `settings` payload was added, v4 for `payments`.
/// Older backups still restore — every collection and `settings` are optional
/// on decode.
const kBackupVersion = 4;

/// The backup JSON envelope: all 10 backed-up collections (trash is
/// deliberately excluded) plus optional settings. The single source of truth
/// for the shape — [LocalBackupService.encodeAll] and the dev-only
/// `tool/gen_perf_backup.dart` both build through it.
///
/// Pure Dart (no Flutter, no Isar instance), so a `dart run` script can use it.
Map<String, Object?> buildBackupMap({
  required List<Product> products,
  required List<Order> orders,
  required List<Customer> customers,
  required List<Expense> expenses,
  required List<StockMovement> stockMovements,
  required List<Category> categories,
  required List<Supplier> suppliers,
  required List<Purchase> purchases,
  required List<CashRegister> cashRegisters,
  required List<Payment> payments,
  Map<String, dynamic>? settings,
  DateTime? timestamp,
}) =>
    {
      'version': kBackupVersion,
      'appName': 'Micro Seller',
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
      'products': products.map((e) => e.toJson()).toList(),
      'orders': orders.map((e) => e.toJson()).toList(),
      'customers': customers.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'stockMovements': stockMovements.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'suppliers': suppliers.map((e) => e.toJson()).toList(),
      'purchases': purchases.map((e) => e.toJson()).toList(),
      'cashRegisters': cashRegisters.map((e) => e.toJson()).toList(),
      'payments': payments.map((e) => e.toJson()).toList(),
      if (settings != null) 'settings': settings,
    };
