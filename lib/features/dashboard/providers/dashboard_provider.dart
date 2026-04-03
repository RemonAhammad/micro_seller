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

double _calcProfit(List<Order> orders) {
  double profit = 0;
  for (final order in orders) {
    for (final item in order.items) {
      profit += (item.unitPrice - item.costPrice) * item.qty;
    }
  }
  return profit;
}

@riverpod
Future<DashboardStats> dashboardStats(DashboardStatsRef ref) async {
  final isar = await ref.watch(isarProvider.future);

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month, 1);
  final weekStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

  // Use targeted Isar queries instead of loading ALL orders
  final totalOrders = await isar.orders.count();

  final nonCancelledFilter = isar.orders.filter().not().orderStatusEqualTo(OrderStatus.cancelled);

  // Today's orders (non-cancelled, created today)
  final todayOrders = await nonCancelledFilter
      .createdAtGreaterThan(todayStart)
      .findAll();
  final todayRevenue = todayOrders.fold(0.0, (s, o) => s + o.totalAmount);

  // Month's orders (non-cancelled, created this month)
  final monthOrders = await nonCancelledFilter
      .createdAtGreaterThan(monthStart)
      .findAll();
  final thisMonthRevenue = monthOrders.fold(0.0, (s, o) => s + o.totalAmount);
  final thisMonthProfit = _calcProfit(monthOrders);

  // Pending orders count
  final pendingOrders = await isar.orders
      .filter()
      .orderStatusEqualTo(OrderStatus.pending)
      .or()
      .orderStatusEqualTo(OrderStatus.confirmed)
      .count();

  // Unpaid total
  final unpaidOrders = await isar.orders
      .filter()
      .not()
      .paymentStatusEqualTo(PaymentStatus.paid)
      .not()
      .orderStatusEqualTo(OrderStatus.cancelled)
      .findAll();
  final unpaidTotal = unpaidOrders.fold(0.0, (s, o) => s + o.balanceDue);

  // Low stock products
  final products = await isar.products
      .where()
      .filter()
      .isActiveEqualTo(true)
      .findAll();
  final lowStockProducts =
      products.where((p) => p.isLowStock || p.isOutOfStock).toList();

  // Weekly sales — fetch once, bucket locally
  final weekOrders = await nonCancelledFilter
      .createdAtGreaterThan(weekStart)
      .findAll();

  final weeklySales = <DailySales>[];
  for (int i = 6; i >= 0; i--) {
    final day = now.subtract(Duration(days: i));
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final dayOrders = weekOrders.where((o) =>
        o.createdAt != null &&
        !o.createdAt!.isBefore(dayStart) &&
        o.createdAt!.isBefore(dayEnd)).toList();

    final revenue = dayOrders.fold(0.0, (s, o) => s + o.totalAmount);
    final profit = _calcProfit(dayOrders);

    weeklySales.add(DailySales(date: dayStart, revenue: revenue, profit: profit));
  }

  return DashboardStats(
    todayRevenue: todayRevenue,
    thisMonthRevenue: thisMonthRevenue,
    thisMonthProfit: thisMonthProfit,
    totalOrders: totalOrders,
    pendingOrders: pendingOrders,
    unpaidTotal: unpaidTotal,
    lowStockProducts: lowStockProducts,
    weeklySales: weeklySales,
  );
}
