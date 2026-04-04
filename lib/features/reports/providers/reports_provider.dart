import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/models/expense.dart';
import '../../../data/services/isar_service.dart';

part 'reports_provider.g.dart';

@riverpod
Future<ReportData> reportData(
  ReportDataRef ref,
  DateTime startDate,
  DateTime endDate,
) async {
  final isar = await ref.watch(isarProvider.future);

  final orders = await isar.orders
      .filter()
      .not()
      .orderStatusEqualTo(OrderStatus.cancelled)
      .createdAtGreaterThan(startDate.subtract(const Duration(seconds: 1)))
      .createdAtLessThan(endDate.add(const Duration(days: 1)))
      .findAll();

  final expenses = await isar.expenses
      .filter()
      .dateGreaterThan(startDate.subtract(const Duration(seconds: 1)))
      .dateLessThan(endDate.add(const Duration(days: 1)))
      .findAll();

  // Build a productId -> category lookup from the products table
  final products = await isar.products.where().findAll();
  final categoryByProductId = <int, String>{};
  for (final p in products) {
    categoryByProductId[p.id] = p.category.isNotEmpty ? p.category : 'Uncategorized';
  }

  final salesByCategory = <String, double>{};
  final qtyByProduct = <String, double>{};
  final revenueByProduct = <String, double>{};
  final revenueByCustomer = <String, double>{};

  double totalRevenue = 0;
  double totalProfit = 0;
  final double totalExpenses = expenses.fold(0.0, (s, e) => s + e.amount);

  for (final order in orders) {
    totalRevenue += order.totalAmount;

    final customerKey =
        order.customerName.isNotEmpty ? order.customerName : 'Walk-in';
    revenueByCustomer[customerKey] =
        (revenueByCustomer[customerKey] ?? 0) + order.totalAmount;

    for (final item in order.items) {
      final cat = categoryByProductId[item.productId] ?? 'Uncategorized';
      salesByCategory[cat] = (salesByCategory[cat] ?? 0) + item.totalPrice;

      qtyByProduct[item.productName] =
          (qtyByProduct[item.productName] ?? 0) + item.qty.toDouble();
      revenueByProduct[item.productName] =
          (revenueByProduct[item.productName] ?? 0) + item.totalPrice;
      totalProfit += (item.unitPrice - item.costPrice) * item.qty;
    }
  }

  return ReportData(
    totalRevenue: totalRevenue,
    totalProfit: totalProfit,
    totalExpenses: totalExpenses,
    totalOrders: orders.length,
    avgOrderValue: orders.isEmpty ? 0 : totalRevenue / orders.length,
    salesByCategory: _sortedTop(salesByCategory, 10),
    topProducts: _sortedTop(revenueByProduct, 10),
    topProductsByQty: _sortedTop(qtyByProduct, 10),
    topCustomers: _sortedTop(revenueByCustomer, 10),
  );
}

Map<String, double> _sortedTop(Map<String, double> map, int limit) {
  final sorted = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted.take(limit));
}

class ReportData {
  final double totalRevenue;
  final double totalProfit;
  final double totalExpenses;
  final int totalOrders;
  final double avgOrderValue;
  final Map<String, double> salesByCategory;
  final Map<String, double> topProducts;
  final Map<String, double> topProductsByQty;
  final Map<String, double> topCustomers;

  const ReportData({
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalExpenses,
    required this.totalOrders,
    required this.avgOrderValue,
    required this.salesByCategory,
    required this.topProducts,
    required this.topProductsByQty,
    required this.topCustomers,
  });
}
