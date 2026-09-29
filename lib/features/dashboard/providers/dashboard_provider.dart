import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/notification_service.dart';

part 'dashboard_provider.freezed.dart';
part 'dashboard_provider.g.dart';

@freezed
abstract class DailySales with _$DailySales {
  const factory DailySales({
    required DateTime date,
    required double revenue,
    required double profit,
  }) = _DailySales;
}

@freezed
abstract class DashboardStats with _$DashboardStats {
  const factory DashboardStats({
    @Default(0.0) double todayRevenue,
    @Default(0.0) double thisMonthRevenue,
    @Default(0.0) double thisMonthProfit,
    @Default(0) int totalOrders,
    @Default(0) int pendingOrders,
    @Default([]) List<Product> lowStockProducts,
    @Default([]) List<DailySales> weeklySales,
  }) = _DashboardStats;
}

/// Preset filter options for the dashboard date range.
enum DateRangePreset { today, thisWeek, thisMonth, custom }

@riverpod
class DashboardDateRange extends _$DashboardDateRange {
  @override
  ({DateTime start, DateTime end, DateRangePreset preset}) build() {
    final now = DateTime.now();
    return (
      start: DateTime(now.year, now.month, 1),
      end: now,
      preset: DateRangePreset.thisMonth,
    );
  }

  void setRange(DateTime start, DateTime end) {
    state = (start: start, end: end, preset: DateRangePreset.custom);
  }

  void setThisMonth() {
    final now = DateTime.now();
    state = (
      start: DateTime(now.year, now.month, 1),
      end: now,
      preset: DateRangePreset.thisMonth,
    );
  }

  void setThisWeek() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    state = (
      start: DateTime(weekStart.year, weekStart.month, weekStart.day),
      end: now,
      preset: DateRangePreset.thisWeek,
    );
  }

  void setToday() {
    final now = DateTime.now();
    state = (
      start: DateTime(now.year, now.month, now.day),
      end: now,
      preset: DateRangePreset.today,
    );
  }
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
Future<DashboardStats> dashboardStats(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  final dateRange = ref.watch(dashboardDateRangeProvider);
  final startDate = dateRange.start;
  final endDate = dateRange.end;

  final todayStart = DateTime(endDate.year, endDate.month, endDate.day);
  final weekStart = todayStart.subtract(const Duration(days: 6));

  // Use targeted Isar queries instead of loading ALL orders
  final totalOrders = await isar.orders.count();

  final nonCancelledFilter = isar.orders.filter().not().orderStatusEqualTo(OrderStatus.cancelled);

  // Today's orders (non-cancelled, non-return, created on the endDate's day)
  final todayOrders = await nonCancelledFilter
      .createdAtGreaterThan(todayStart)
      .findAll();
  final todayRegular = todayOrders.where((o) => !o.isReturn).toList();
  final todayRefunds = todayOrders.where((o) => o.isReturn && o.returnStatus == ReturnStatus.refunded).toList();
  final todayRevenue = todayRegular.fold(0.0, (s, o) => s + o.totalAmount)
      - todayRefunds.fold(0.0, (s, o) => s + o.refundAmount);

  // Range orders (non-cancelled, within the selected date range)
  final rangeOrders = await nonCancelledFilter
      .createdAtGreaterThan(startDate)
      .createdAtLessThan(endDate.add(const Duration(days: 1)))
      .findAll();
  final rangeRegular = rangeOrders.where((o) => !o.isReturn).toList();
  final rangeRefunds = rangeOrders.where((o) => o.isReturn && o.returnStatus == ReturnStatus.refunded).toList();
  final totalRefunded = rangeRefunds.fold(0.0, (s, o) => s + o.refundAmount);
  final thisMonthRevenue = rangeRegular.fold(0.0, (s, o) => s + o.totalAmount) - totalRefunded;
  final thisMonthProfit = _calcProfit(rangeRegular) - totalRefunded;

  // Pending orders count
  final pendingOrders = await isar.orders
      .filter()
      .orderStatusEqualTo(OrderStatus.pending)
      .or()
      .orderStatusEqualTo(OrderStatus.confirmed)
      .count();

  // Low stock products
  final products = await isar.products
      .where()
      .filter()
      .isActiveEqualTo(true)
      .findAll();
  final lowStockProducts =
      products.where((p) => p.isLowStock || p.isOutOfStock).toList();

  // Weekly sales — last 7 days from endDate, fetch once, bucket locally
  final weekOrders = await nonCancelledFilter
      .createdAtGreaterThan(weekStart)
      .createdAtLessThan(endDate.add(const Duration(days: 1)))
      .findAll();

  final weeklySales = <DailySales>[];
  for (int i = 6; i >= 0; i--) {
    final day = endDate.subtract(Duration(days: i));
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final dayOrders = weekOrders.where((o) =>
        o.createdAt != null &&
        !o.createdAt!.isBefore(dayStart) &&
        o.createdAt!.isBefore(dayEnd)).toList();

    final dayRegular = dayOrders.where((o) => !o.isReturn).toList();
    final dayRefunded = dayOrders.where((o) => o.isReturn && o.returnStatus == ReturnStatus.refunded).toList();
    final dayRefundTotal = dayRefunded.fold(0.0, (s, o) => s + o.refundAmount);
    final revenue = dayRegular.fold(0.0, (s, o) => s + o.totalAmount) - dayRefundTotal;
    final profit = _calcProfit(dayRegular) - dayRefundTotal;

    weeklySales.add(DailySales(date: dayStart, revenue: revenue, profit: profit));
  }

  // Trigger notification check
  NotificationService.checkAndNotify(isar);

  return DashboardStats(
    todayRevenue: todayRevenue,
    thisMonthRevenue: thisMonthRevenue,
    thisMonthProfit: thisMonthProfit,
    totalOrders: totalOrders,
    pendingOrders: pendingOrders,
    lowStockProducts: lowStockProducts,
    weeklySales: weeklySales,
  );
}
