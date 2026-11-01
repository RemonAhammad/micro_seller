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

({DateTime start, DateTime end}) reportWindow(DateTime from, DateTime to) => (
  start: DateTime(from.year, from.month, from.day),
  end: DateTime(to.year, to.month, to.day + 1),
);

List<T> _byId<T>(List<T> rows, int Function(T) id) =>
    rows..sort((a, b) => id(a).compareTo(id(b)));

List<Order> loadSalesSync(Isar db, DateTime start, DateTime end) => _byId(
  db.orders
      .where()
      .createdAtBetween(start, end, includeUpper: false)
      .filter()
      .isReturnEqualTo(false)
      .findAllSync(),
  (o) => o.id,
);

List<Order> loadReturnsSync(Isar db) =>
    db.orders.filter().isReturnEqualTo(true).findAllSync();

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

    final extra = db.orders.getAllSync(
      {...payments.map((p) => p.orderId)}.toList(),
    );
    final ordersById = {
      for (final o in ordersInPeriod) o.id: o,
      for (final o in extra)
        if (o != null) o.id: o,
    };

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

void _keepForAWhile(Ref ref) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 3), link.close);
  ref.onDispose(timer.cancel);
}

@riverpod
Future<SalesReport> salesReport(Ref ref, DateTime from, DateTime to) async {

  ref.watch(ordersRevisionProvider);
  ref.watch(expensesRevisionProvider);
  _keepForAWhile(ref);
  final isar = await ref.watch(isarProvider.future);
  final w = reportWindow(from, to);
  return runDbJob(isar, salesReportJob(w.start, w.end));
}

@riverpod
Future<DuesReport> duesReport(Ref ref, DateTime from, DateTime to) async {

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
