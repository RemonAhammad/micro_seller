import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/report_service.dart';
import '../../orders/providers/order_provider.dart';
import '../../reports/providers/reports_provider.dart';

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

typedef DashboardRange = ({DateTime start, DateTime end, DateRangePreset preset});

/// The dates [range] covers as of [now]. Presets are relative to today, but
/// the notifier keeps the dates from when the preset was picked — stale once
/// the app stays open past midnight (or into a new month). Custom ranges are
/// kept as picked.
({DateTime start, DateTime end}) resolveDashboardRange(
        DashboardRange range, DateTime now) =>
    range.preset == DateRangePreset.custom
        ? (start: range.start, end: range.end)
        : _presetDates(range.preset, now);

({DateTime start, DateTime end}) _presetDates(
    DateRangePreset preset, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final start = switch (preset) {
    DateRangePreset.thisWeek =>
      DateTime(today.year, today.month, today.day - (now.weekday - 1)),
    DateRangePreset.thisMonth => DateTime(now.year, now.month, 1),
    _ => today,
  };
  return (start: start, end: now);
}

@riverpod
class DashboardDateRange extends _$DashboardDateRange {
  @override
  DashboardRange build() => _preset(DateRangePreset.thisMonth);

  DashboardRange _preset(DateRangePreset preset) {
    final r = _presetDates(preset, DateTime.now());
    return (start: r.start, end: r.end, preset: preset);
  }

  void setRange(DateTime start, DateTime end) {
    state = (start: start, end: end, preset: DateRangePreset.custom);
  }

  void setThisMonth() => state = _preset(DateRangePreset.thisMonth);

  void setThisWeek() => state = _preset(DateRangePreset.thisWeek);

  void setToday() => state = _preset(DateRangePreset.today);
}

@riverpod
Future<DashboardStats> dashboardStats(Ref ref) async {
  // Recompute whenever an order changes — the cards used to stay stale
  // until a pull-to-refresh.
  ref.watch(ordersProvider);
  final isar = await ref.watch(isarProvider.future);
  final range =
      resolveDashboardRange(ref.watch(dashboardDateRangeProvider), DateTime.now());

  // One window per card for every number on it, revenue and profit alike:
  // [start of the first day, start of the day after the last).
  final window = reportWindow(range.start, range.end);
  final todayStart = DateTime(range.end.year, range.end.month, range.end.day);
  final today = reportWindow(todayStart, todayStart);
  final week = reportWindow(
      DateTime(todayStart.year, todayStart.month, todayStart.day - 6), todayStart);

  // Profit is Reports → Gross profit for the same window (list price −
  // discounts − returns − cost of goods), from the same builder, so the two
  // screens can't disagree. Returns are loaded the way Reports loads them.
  final products = await isar.products.where().findAll();
  final productsById = {for (final p in products) p.id: p};
  final cancelledIds = await loadCancelledOrderIds(isar);
  Future<SalesReport> salesFor(({DateTime start, DateTime end}) w) async =>
      buildSalesReport(
        orders: await loadOrdersAndReturns(isar, w.start, w.end),
        cancelledOrderIds: cancelledIds,
        productsById: productsById,
        expenses: const [], // gross profit only — expenses have their own card
        start: w.start,
        end: w.end,
      );

  final thisMonthProfit = (await salesFor(window)).grossProfit;
  final weekProfit = {
    for (final p in (await salesFor(week)).profitSeries) p.bucket: p.value,
  };

  // Use targeted Isar queries instead of loading ALL orders
  final totalOrders = await isar.orders.count();

  final nonCancelledFilter = isar.orders.filter().not().orderStatusEqualTo(OrderStatus.cancelled);

  // Today's orders (non-cancelled, created on the range's last day)
  final todayOrders = await nonCancelledFilter
      .createdAtBetween(today.start, today.end, includeUpper: false)
      .findAll();
  final todayRegular = todayOrders.where((o) => !o.isReturn).toList();
  final todayRefunds = todayOrders.where((o) => o.isReturn && o.returnStatus == ReturnStatus.refunded).toList();
  final todayRevenue = todayRegular.fold(0.0, (s, o) => s + o.totalAmount)
      - todayRefunds.fold(0.0, (s, o) => s + o.refundAmount);

  // Range orders (non-cancelled, within the selected date range)
  final rangeOrders = await nonCancelledFilter
      .createdAtBetween(window.start, window.end, includeUpper: false)
      .findAll();
  final rangeRegular = rangeOrders.where((o) => !o.isReturn).toList();
  final rangeRefunds = rangeOrders.where((o) => o.isReturn && o.returnStatus == ReturnStatus.refunded).toList();
  final totalRefunded = rangeRefunds.fold(0.0, (s, o) => s + o.refundAmount);
  final thisMonthRevenue = rangeRegular.fold(0.0, (s, o) => s + o.totalAmount) - totalRefunded;

  // Pending orders count
  final pendingOrders = await isar.orders
      .filter()
      .orderStatusEqualTo(OrderStatus.pending)
      .or()
      .orderStatusEqualTo(OrderStatus.confirmed)
      .count();

  // Low stock products
  final lowStockProducts = products
      .where((p) => p.isActive && (p.isLowStock || p.isOutOfStock))
      .toList();

  // Weekly sales — the 7 days ending on the range's last day, fetched once
  // and bucketed locally
  final weekOrders = await nonCancelledFilter
      .createdAtBetween(week.start, week.end, includeUpper: false)
      .findAll();

  final weeklySales = <DailySales>[];
  for (int i = 6; i >= 0; i--) {
    final dayStart =
        DateTime(todayStart.year, todayStart.month, todayStart.day - i);
    final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);

    final dayOrders = weekOrders.where((o) =>
        o.createdAt != null &&
        !o.createdAt!.isBefore(dayStart) &&
        o.createdAt!.isBefore(dayEnd)).toList();

    final dayRegular = dayOrders.where((o) => !o.isReturn).toList();
    final dayRefunded = dayOrders.where((o) => o.isReturn && o.returnStatus == ReturnStatus.refunded).toList();
    final dayRefundTotal = dayRefunded.fold(0.0, (s, o) => s + o.refundAmount);
    final revenue = dayRegular.fold(0.0, (s, o) => s + o.totalAmount) - dayRefundTotal;

    weeklySales.add(DailySales(
        date: dayStart, revenue: revenue, profit: weekProfit[dayStart] ?? 0));
  }

  // Low-stock / unpaid reminders on first load and pull-to-refresh only —
  // not on every recompute, which now happens whenever an order is saved.
  if (!ref.isReload) NotificationService.checkAndNotify(isar);

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
