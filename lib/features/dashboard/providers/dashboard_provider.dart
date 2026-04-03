import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_service.dart';

part 'dashboard_provider.freezed.dart';
part 'dashboard_provider.g.dart';

@freezed
class DailySales with _$DailySales {
  const factory DailySales({
    required DateTime date,
    required double revenue,
    required double profit,
  }) = _DailySales;
}

@freezed
class DashboardStats with _$DashboardStats {
  const factory DashboardStats({
    @Default(0.0) double todayRevenue,
    @Default(0.0) double thisMonthRevenue,
    @Default(0.0) double thisMonthProfit,
    @Default(0) int totalOrders,
    @Default(0) int pendingOrders,
    @Default(0.0) double unpaidTotal,
    @Default([]) List<Product> lowStockProducts,
    @Default([]) List<DailySales> weeklySales,
  }) = _DashboardStats;
}

@riverpod
Future<DashboardStats> dashboardStats(DashboardStatsRef ref) async {
  final isar = await ref.watch(isarProvider.future);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month, 1);
  final allOrders = await isar.orders.where().findAll();
  final products = await isar.products.where().filter().isActiveEqualTo(true).findAll();

  // Today's revenue
  final todayOrders = allOrders.where((o) =>
      o.createdAt != null && o.createdAt!.isAfter(todayStart) &&
      o.orderStatus != OrderStatus.cancelled).toList();
  final todayRevenue = todayOrders.fold(0.0, (s, o) => s + o.totalAmount);

  // Month's data
  final monthOrders = allOrders.where((o) =>
      o.createdAt != null && o.createdAt!.isAfter(monthStart) &&
      o.orderStatus != OrderStatus.cancelled).toList();
  final thisMonthRevenue = monthOrders.fold(0.0, (s, o) => s + o.totalAmount);

  // Profit = revenue - cost of goods sold (uses stored costPrice from order items)
  double thisMonthProfit = 0;
  for (final order in monthOrders) {
    for (final item in order.items) {
      // Use costPrice stored on the order item; fall back to product lookup for old orders
      double costPrice = item.costPrice;
      if (costPrice == 0) {
        final product = await isar.products.get(item.productId);
        costPrice = product?.costPrice ?? 0;
      }
      thisMonthProfit += (item.unitPrice - costPrice) * item.qty;
    }
  }

  // Pending orders
  final pendingOrders = allOrders.where((o) =>
      o.orderStatus == OrderStatus.pending ||
      o.orderStatus == OrderStatus.confirmed).length;

  // Unpaid total
  final unpaidTotal = allOrders
      .where((o) =>
          o.paymentStatus != PaymentStatus.paid &&
          o.orderStatus != OrderStatus.cancelled)
      .fold(0.0, (s, o) => s + o.balanceDue);

  // Low stock
  final lowStockProducts = products
      .where((p) => p.isLowStock || p.isOutOfStock)
      .toList();

  // Weekly sales (last 7 days)
  final weeklySales = <DailySales>[];
  for (int i = 6; i >= 0; i--) {
    final day = now.subtract(Duration(days: i));
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final dayOrders = allOrders.where((o) =>
        o.createdAt != null &&
        o.createdAt!.isAfter(dayStart) &&
        o.createdAt!.isBefore(dayEnd) &&
        o.orderStatus != OrderStatus.cancelled).toList();

    final revenue = dayOrders.fold(0.0, (s, o) => s + o.totalAmount);

    double profit = 0;
    for (final order in dayOrders) {
      for (final item in order.items) {
        double costPrice = item.costPrice;
        if (costPrice == 0) {
          final product = await isar.products.get(item.productId);
          costPrice = product?.costPrice ?? 0;
        }
        profit += (item.unitPrice - costPrice) * item.qty;
      }
    }

    weeklySales.add(DailySales(date: dayStart, revenue: revenue, profit: profit));
  }

  return DashboardStats(
    todayRevenue: todayRevenue,
    thisMonthRevenue: thisMonthRevenue,
    thisMonthProfit: thisMonthProfit,
    totalOrders: allOrders.length,
    pendingOrders: pendingOrders,
    unpaidTotal: unpaidTotal,
    lowStockProducts: lowStockProducts,
    weeklySales: weeklySales,
  );
}
