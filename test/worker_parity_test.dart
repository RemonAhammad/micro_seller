// The Dashboard, Due Book and Reports now load through Isar indexes inside
// worker-isolate jobs. This checks they produce exactly what the original
// main-isolate code produced — the old filter queries are rebuilt below as the
// reference — on a generated dataset, bit for bit (doubles compared exactly).
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/expense.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/services/db_worker.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/local_backup_service.dart';
import 'package:micro_seller/data/services/report_service.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';
import 'package:micro_seller/features/dashboard/providers/dashboard_provider.dart';
import 'package:micro_seller/features/reports/providers/reports_provider.dart';

import '../tool/perf_dataset.dart';
import 'support/isar_core.dart';

// ── The original (pre-worker, pre-index) loaders, kept as the reference ──

Future<List<Order>> _oldOrdersAndReturns(
        Isar isar, DateTime start, DateTime end) async =>
    [
      ...await isar.orders
          .filter()
          .isReturnEqualTo(false)
          .createdAtBetween(start, end, includeUpper: false)
          .findAll(),
      ...await isar.orders.filter().isReturnEqualTo(true).findAll(),
    ];

Future<Set<int>> _oldCancelled(Isar isar) async => (await isar.orders
        .filter()
        .orderStatusEqualTo(OrderStatus.cancelled)
        .idProperty()
        .findAll())
    .toSet();

Future<SalesReport> _oldSales(Isar isar, DateTime start, DateTime end) async =>
    buildSalesReport(
      orders: await _oldOrdersAndReturns(isar, start, end),
      cancelledOrderIds: await _oldCancelled(isar),
      productsById: {
        for (final p in await isar.products.where().findAll()) p.id: p
      },
      expenses: await isar.expenses
          .filter()
          .dateBetween(start, end, includeUpper: false)
          .findAll(),
      start: start,
      end: end,
    );

Future<List<CustomerDue>> _oldDues(Isar isar) async {
  final orders = await isar.orders.filter().customerIdGreaterThan(0).findAll();
  final byCustomer = <int, List<Order>>{};
  for (final o in orders) {
    byCustomer.putIfAbsent(o.customerId, () => []).add(o);
  }
  final result = <CustomerDue>[];
  for (final entry in byCustomer.entries) {
    final totalDue = computeNetDue(entry.value);
    if (totalDue <= 0) continue;
    final customer = await isar.customers.get(entry.key);
    if (customer == null) continue;
    final last = await isar.payments
        .filter()
        .customerIdEqualTo(entry.key)
        .amountGreaterThan(0)
        .sortByPaidAtDesc()
        .findFirst();
    result.add(CustomerDue(
      customer: customer,
      orderDues: computeOrderDues(entry.value),
      totalDue: totalDue,
      lastPaymentAt: last?.paidAt,
    ));
  }
  result.sort((a, b) => b.daysOutstanding.compareTo(a.daysOutstanding));
  return result;
}

Future<DuesReport> _oldDuesReport(Isar isar, DateTime start, DateTime end) async {
  final payments = await isar.payments
      .filter()
      .paidAtBetween(start, end, includeUpper: false)
      .findAll();
  final ordersInPeriod = await isar.orders
      .filter()
      .isReturnEqualTo(false)
      .createdAtBetween(start, end, includeUpper: false)
      .findAll();
  final extra =
      await isar.orders.getAll({...payments.map((p) => p.orderId)}.toList());
  final ordersById = {
    for (final o in ordersInPeriod) o.id: o,
    for (final o in extra)
      if (o != null) o.id: o,
  };
  final periodIds = ordersInPeriod.map((o) => o.id).toList();
  final periodPayments = periodIds.isEmpty
      ? const <Payment>[]
      : await isar.payments
          .filter()
          .anyOf(periodIds, (q, int id) => q.orderIdEqualTo(id))
          .findAll();
  return buildDuesReport(
    payments: {
      for (final p in [...payments, ...periodPayments]) p.id: p,
    }.values.toList(),
    ordersById: ordersById,
    ordersInPeriod: ordersInPeriod,
    dues: await _oldDues(isar),
    start: start,
    end: end,
  );
}

Future<InventoryReport> _oldInventory(
        Isar isar, DateTime start, DateTime end) async =>
    buildInventoryReport(
      products: await isar.products.where().findAll(),
      movements: await isar.stockMovements
          .filter()
          .createdAtBetween(start, end, includeUpper: false)
          .findAll(),
      orders: await _oldOrdersAndReturns(isar, start, end),
      cancelledOrderIds: await _oldCancelled(isar),
      start: start,
      end: end,
    );

List<Object> _tables(List<ReportTable> ts) =>
    [for (final t in ts) [t.title, t.headers, t.rows]];

List<Object?> _duesKey(List<CustomerDue> dues) => [
      for (final d in dues)
        [
          d.customer.id,
          d.totalDue,
          d.lastPaymentAt,
          [for (final od in d.orderDues) [od.order.id, od.due]],
        ]
    ];

void main() {
  final coreLibrary = isarCoreLibrary();
  late Directory dir;
  late Isar isar;
  final now = DateTime.now();
  String tr(String k) => k;

  final windows = {
    'this month': reportWindow(DateTime(now.year, now.month), now),
    '12 months': reportWindow(DateTime(now.year - 1, now.month, now.day), now),
    'last 3 days': reportWindow(now.subtract(const Duration(days: 2)), now),
    'a past month': reportWindow(
        DateTime(now.year, now.month - 5, 1), DateTime(now.year, now.month - 4, 0)),
  };

  setUpAll(() async {
    if (coreLibrary == null) return;
    dbWorkerCoreLibrary = coreLibrary;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dir = await Directory.systemTemp.createTemp('micro_seller_parity');
    isar = await Isar.open(kIsarSchemas,
        directory: dir.path, name: 'parity_test', inspector: false);
    final data = PerfDataset(
            orderCount: 4000, productCount: 400, customerCount: 800, seed: 11)
        .build();
    await LocalBackupService().decodeAll(isar, jsonEncode(data));
  });

  tearDownAll(() async {
    if (coreLibrary == null) return;
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  test('Due Book: worker job == original per-customer queries', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final worker = await runDbJob(isar, loadDuesSync);
    expect(worker, isNotEmpty);
    expect(_duesKey(worker), _duesKey(await _oldDues(isar)));
  });

  for (final entry in windows.entries) {
    final w = entry.value;
    test('reports (${entry.key}): worker jobs == original loaders', () async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      expect(
          _tables((await runDbJob(isar, salesReportJob(w.start, w.end))).toTables(tr)),
          _tables((await _oldSales(isar, w.start, w.end)).toTables(tr)));
      expect(
          _tables((await runDbJob(isar, duesReportJob(w.start, w.end))).toTables(tr)),
          _tables((await _oldDuesReport(isar, w.start, w.end)).toTables(tr)));
      expect(
          _tables((await runDbJob(isar, inventoryReportJob(w.start, w.end)))
              .toTables(tr)),
          _tables((await _oldInventory(isar, w.start, w.end)).toTables(tr)));
    });
  }

  test('dashboard: worker job == original computation', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final rangeStart = DateTime(now.year, now.month, 1);
    final stats = await runDbJob(isar, dashboardStatsJob(rangeStart, now));

    final window = reportWindow(rangeStart, now);
    final todayStart = DateTime(now.year, now.month, now.day);
    final today = reportWindow(todayStart, todayStart);
    final week = reportWindow(
        DateTime(todayStart.year, todayStart.month, todayStart.day - 6), todayStart);
    final nonCancelled =
        isar.orders.filter().not().orderStatusEqualTo(OrderStatus.cancelled);
    double revenue(List<Order> os) =>
        os.where((o) => !o.isReturn).fold(0.0, (s, o) => s + o.totalAmount) -
        os
            .where((o) => o.isReturn && o.returnStatus == ReturnStatus.refunded)
            .fold(0.0, (s, o) => s + o.refundAmount);

    expect(stats.thisMonthProfit,
        (await _oldSales(isar, window.start, window.end)).grossProfit);
    expect(
        stats.todayRevenue,
        revenue(await nonCancelled
            .createdAtBetween(today.start, today.end, includeUpper: false)
            .findAll()));
    expect(
        stats.thisMonthRevenue,
        revenue(await nonCancelled
            .createdAtBetween(window.start, window.end, includeUpper: false)
            .findAll()));
    expect(stats.totalOrders, await isar.orders.count());
    expect(
        stats.pendingOrders,
        await isar.orders
            .filter()
            .orderStatusEqualTo(OrderStatus.pending)
            .or()
            .orderStatusEqualTo(OrderStatus.confirmed)
            .count());
    final products = await isar.products.where().findAll();
    expect(
        stats.lowStockProducts.map((p) => p.id),
        products
            .where((p) => p.isActive && (p.isLowStock || p.isOutOfStock))
            .map((p) => p.id));
    final weekProfit = {
      for (final p in (await _oldSales(isar, week.start, week.end)).profitSeries)
        p.bucket: p.value,
    };
    final weekOrders = await nonCancelled
        .createdAtBetween(week.start, week.end, includeUpper: false)
        .findAll();
    for (final day in stats.weeklySales) {
      final next = DateTime(day.date.year, day.date.month, day.date.day + 1);
      final dayOrders = weekOrders
          .where((o) => !o.createdAt!.isBefore(day.date) && o.createdAt!.isBefore(next))
          .toList();
      expect(day.revenue, revenue(dayOrders), reason: '${day.date}');
      expect(day.profit, weekProfit[day.date] ?? 0, reason: '${day.date}');
    }
    // Status pie: the old screen counted the full newest-first orders list.
    final counts = <OrderStatus, int>{};
    for (final o in await isar.orders.where().sortByCreatedAtDesc().findAll()) {
      counts[o.orderStatus] = (counts[o.orderStatus] ?? 0) + 1;
    }
    expect(stats.statusCounts.entries.map((e) => [e.key, e.value]),
        counts.entries.map((e) => [e.key, e.value]));
  });

  test('index-backed lists == original sorted filters', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    expect(
        (await isar.products.where().isActiveEqualToAnyName(true).findAll())
            .map((p) => p.id),
        (await isar.products.filter().isActiveEqualTo(true).sortByName().findAll())
            .map((p) => p.id));
    expect((await isar.customers.where().anyName().findAll()).map((c) => c.id),
        (await isar.customers.where().sortByName().findAll()).map((c) => c.id));
    // A single-value index lookup returns the same rows, but NOT in id order
    // (Isar orders equal keys by stored id bytes) — callers that sum money
    // re-sort by id. That re-sorted result must equal the old filter scan.
    final someCustomer = (await isar.customers.where().findFirst())!.id;
    expect(
        ((await isar.orders.where().customerIdEqualTo(someCustomer).findAll())
              ..sort((a, b) => a.id.compareTo(b.id)))
            .map((o) => o.id),
        (await isar.orders.filter().customerIdEqualTo(someCustomer).findAll())
            .map((o) => o.id));
    // Unused-type guards keep the imports honest across refactors.
    expect(<Type>[Expense, StockMovement, Product, Customer], hasLength(4));
  });
}
