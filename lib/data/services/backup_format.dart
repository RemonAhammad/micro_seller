import '../models/cash_register.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/stock_movement.dart';
import '../models/sales_target.dart';
import '../models/supplier.dart';

const kBackupVersion = 5;

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
  required List<SalesTarget> salesTargets,
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
      'salesTargets': salesTargets.map((e) => e.toJson()).toList(),
      if (settings != null) 'settings': settings,
    };
