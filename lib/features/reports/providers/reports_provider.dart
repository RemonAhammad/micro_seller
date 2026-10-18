import 'dart:async';
import 'dart:math';

import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/cash_register.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/order.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/product.dart';
import '../../../data/models/purchase.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/models/supplier.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/isar_revisions.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/report_service.dart';
import '../../customers/providers/dues_provider.dart';

part 'reports_provider.g.dart';

/// The reporting window for a picked date range: `[start of first day,
/// start of the day after the last)`.
({DateTime start, DateTime end}) reportWindow(DateTime from, DateTime to) => (
  start: DateTime(from.year, from.month, from.day),
  end: DateTime(to.year, to.month, to.day + 1),
);

List<T> _byId<T>(List<T> rows, int Function(T) id) =>
    rows..sort((a, b) => id(a).compareTo(id(b)));

/// Sales (non-return orders) created in `[start, end)`, in id order. Found
/// through the createdAt index, then put back in id order — the order the
/// builders' sums always added them in.
List<Order> loadSalesSync(Isar db, DateTime start, DateTime end) => _byId(
  db.orders
      .where()
      .createdAtBetween(start, end, includeUpper: false)
      .filter()
      .isReturnEqualTo(false)
      .findAllSync(),
  (o) => o.id,
);

/// Every return order. Returns are dated by when their goods came back
/// (`updatedAt`), which can fall in a period even if the return was created
/// earlier, so they're loaded whole and the builders pick the period's.
List<Order> loadReturnsSync(Isar db) =>
    db.orders.filter().isReturnEqualTo(true).findAllSync();

/// Ids of cancelled orders — returns against them are ignored (the cancel
/// already removed the sale).
Set<int> loadCancelledOrderIdsSync(Isar db) => db.orders
    .filter()
    .orderStatusEqualTo(OrderStatus.cancelled)
    .idProperty()
    .findAllSync()
    .toSet();

List<Expense> _expensesSync(Isar db, DateTime start, DateTime end) => _byId(
  db.expenses
      .where()
      .dateBetween(start, end, includeUpper: false)
      .findAllSync(),
  (e) => e.id,
);

// The report jobs below run on a worker isolate (runDbJob): loading and
// building a "This year" report is thousands of orders of deserialization and
// arithmetic the UI isolate never sees. Each job takes only plain values, so
// it can cross isolates, and returns just the finished report.

SalesReport Function(Isar) salesReportJob(DateTime start, DateTime end) =>
    (db) => db.txnSync(
      () => buildSalesReport(
        orders: [...loadSalesSync(db, start, end), ...loadReturnsSync(db)],
        cancelledOrderIds: loadCancelledOrderIdsSync(db),
        productsById: {
          for (final p in db.products.where().findAllSync()) p.id: p,
        },
        expenses: _expensesSync(db, start, end),
        start: start,
        end: end,
      ),
    );

DuesReport Function(Isar) duesReportJob(DateTime start, DateTime end) => (db) {
  // Its own read transaction (Isar can't nest them) — like the separate
  // Due Book provider the report used to read.
  final dues = loadDuesSync(db);
  return db.txnSync(() {
    final payments = _byId(
      db.payments
          .where()
          .paidAtBetween(start, end, includeUpper: false)
          .findAllSync(),
      (p) => p.id,
    );
    final ordersInPeriod = loadSalesSync(db, start, end);
    // Orders the period's payments belong to (often older than the
    // period) — needed to tell a later "dues collection" from a
    // pay-at-sale.
    final extra = db.orders.getAllSync(
      {...payments.map((p) => p.orderId)}.toList(),
    );
    final ordersById = {
      for (final o in ordersInPeriod) o.id: o,
      for (final o in extra)
        if (o != null) o.id: o,
    };
    // Same-day payments of period orders (for "credit given"). Period
    // orders were created in the window and ids grow with time, so one
    // orderId index range covers them; the set check keeps exactly
    // theirs. (An OR of one condition per order, or one where-clause
    // per order, measured several times slower.)
    final periodIds = {for (final o in ordersInPeriod) o.id};
    final periodPayments = periodIds.isEmpty
        ? const <Payment>[]
        : _byId(
            db.payments
                .where()
                .orderIdBetween(periodIds.reduce(min), periodIds.reduce(max))
                .findAllSync()
                .where((p) => periodIds.contains(p.orderId))
                .toList(),
            (p) => p.id,
          );
    final allPayments = {
      for (final p in [...payments, ...periodPayments]) p.id: p,
    }.values.toList();

    return buildDuesReport(
      payments: allPayments,
      ordersById: ordersById,
      ordersInPeriod: ordersInPeriod,
      dues: dues,
      start: start,
      end: end,
    );
  });
};

InventoryReport Function(Isar) inventoryReportJob(
  DateTime start,
  DateTime end,
) =>
    (db) => db.txnSync(
      () => buildInventoryReport(
        products: db.products.where().findAllSync(),
        movements: _byId(
          db.stockMovements
              .where()
              .createdAtBetween(start, end, includeUpper: false)
              .findAllSync(),
          (m) => m.id,
        ),
        orders: [...loadSalesSync(db, start, end), ...loadReturnsSync(db)],
        cancelledOrderIds: loadCancelledOrderIdsSync(db),
        start: start,
        end: end,
      ),
    );

PurchasesReport Function(Isar) purchasesReportJob(
  DateTime start,
  DateTime end,
) =>
    (db) => db.txnSync(
      () => buildPurchasesReport(
        // All purchases: "owed to suppliers today" spans every purchase.
        purchases: db.purchases.where().findAllSync(),
        suppliers: db.suppliers.where().findAllSync(),
        expenses: _expensesSync(db, start, end),
        registers: db.cashRegisters
            .filter()
            .closedAtBetween(start, end, includeUpper: false)
            .findAllSync(),
        start: start,
        end: end,
      ),
    );

/// Keeps a report for a while after its tab is left, so swiping between the
/// Reports tabs doesn't reload it. Its triggers still invalidate it, and an
/// invalidated report with no listeners only rebuilds when shown again.
void _keepForAWhile(Ref ref) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), link.close);
  ref.onDispose(timer.cancel);
}

@riverpod
Future<SalesReport> salesReport(Ref ref, DateTime from, DateTime to) async {
  // Live, like the Dashboard: the Reports tab stays mounted, and a stale
  // report next to a live Dashboard profit would disagree with it. The
  // revision counters only notice writes; nothing reloads a whole list.
  ref.watch(ordersRevisionProvider);
  ref.watch(expensesRevisionProvider);
  _keepForAWhile(ref);
  final isar = await ref.watch(isarProvider.future);
  final w = reportWindow(from, to);
  return runDbJob(isar, salesReportJob(w.start, w.end));
}

@riverpod
Future<DuesReport> duesReport(Ref ref, DateTime from, DateTime to) async {
  // The same writes that refresh the Due Book (orders, customers).
  ref.watch(ordersRevisionProvider);
  ref.watch(customersRevisionProvider);
  _keepForAWhile(ref);
  final isar = await ref.watch(isarProvider.future);
  final w = reportWindow(from, to);
  return runDbJob(isar, duesReportJob(w.start, w.end));
}

@riverpod
Future<InventoryReport> inventoryReport(
  Ref ref,
  DateTime from,
  DateTime to,
) async {
  ref.watch(ordersRevisionProvider);
  ref.watch(productsRevisionProvider);
  _keepForAWhile(ref);
  final isar = await ref.watch(isarProvider.future);
  final w = reportWindow(from, to);
  return runDbJob(isar, inventoryReportJob(w.start, w.end));
}

@riverpod
Future<PurchasesReport> purchasesReport(
  Ref ref,
  DateTime from,
  DateTime to,
) async {
  final isar = await ref.watch(isarProvider.future);
  final w = reportWindow(from, to);
  return runDbJob(isar, purchasesReportJob(w.start, w.end));
}
