import 'dart:async';

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

/// Sales (non-return orders) created in `[start, end)`.
Future<List<Order>> loadSales(Isar isar, DateTime start, DateTime end) =>
    isar.orders
        .filter()
        .isReturnEqualTo(false)
        .createdAtBetween(start, end, includeUpper: false)
        .findAll();

/// Every return order. Returns are dated by when their goods came back
/// (`updatedAt`), which can fall in a period even if the return was created
/// earlier, so they're loaded whole and the builders pick the period's.
Future<List<Order>> loadReturns(Isar isar) =>
    isar.orders.filter().isReturnEqualTo(true).findAll();

/// What the sales/inventory builders (and the Dashboard's profit) take.
Future<List<Order>> loadOrdersAndReturns(
        Isar isar, DateTime start, DateTime end) async =>
    [...await loadSales(isar, start, end), ...await loadReturns(isar)];

/// Ids of cancelled orders — returns against them are ignored (the cancel
/// already removed the sale).
Future<Set<int>> loadCancelledOrderIds(Isar isar) async => (await isar.orders
        .filter()
        .orderStatusEqualTo(OrderStatus.cancelled)
        .idProperty()
        .findAll())
    .toSet();

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
  final orders = await loadOrdersAndReturns(isar, w.start, w.end);
  final products = await isar.products.where().findAll();
  final expenses = await isar.expenses
      .filter()
      .dateBetween(w.start, w.end, includeUpper: false)
      .findAll();
  return buildSalesReport(
    orders: orders,
    cancelledOrderIds: await loadCancelledOrderIds(isar),
    productsById: {for (final p in products) p.id: p},
    expenses: expenses,
    start: w.start,
    end: w.end,
  );
}

@riverpod
Future<DuesReport> duesReport(Ref ref, DateTime from, DateTime to) async {
  _keepForAWhile(ref);
  final isar = await ref.watch(isarProvider.future);
  final w = reportWindow(from, to);
  final dues = await ref.watch(duesProvider.future);
  final payments = await isar.payments
      .filter()
      .paidAtBetween(w.start, w.end, includeUpper: false)
      .findAll();
  final ordersInPeriod = await isar.orders
      .filter()
      .isReturnEqualTo(false)
      .createdAtBetween(w.start, w.end, includeUpper: false)
      .findAll();
  // Orders the period's payments belong to (often older than the period) —
  // needed to tell a later "dues collection" from a pay-at-sale.
  final ids = {...payments.map((p) => p.orderId)};
  final extra = await isar.orders.getAll(ids.toList());
  final ordersById = {
    for (final o in ordersInPeriod) o.id: o,
    for (final o in extra)
      if (o != null) o.id: o,
  };
  // Same-day payments of period orders (for "credit given").
  final periodIds = ordersInPeriod.map((o) => o.id).toList();
  final periodPayments = periodIds.isEmpty
      ? const <Payment>[]
      // The orderId index finds them directly; sorted back to id order, as
      // a filter scan returned them.
      : (await isar.payments
          .where()
          .anyOf(periodIds, (q, int id) => q.orderIdEqualTo(id))
          .findAll())
        ..sort((a, b) => a.id.compareTo(b.id));
  final allPayments = {
    for (final p in [...payments, ...periodPayments]) p.id: p,
  }.values.toList();

  return buildDuesReport(
    payments: allPayments,
    ordersById: ordersById,
    ordersInPeriod: ordersInPeriod,
    dues: dues,
    start: w.start,
    end: w.end,
  );
}

@riverpod
Future<InventoryReport> inventoryReport(
    Ref ref, DateTime from, DateTime to) async {
  ref.watch(ordersRevisionProvider);
  ref.watch(productsRevisionProvider);
  _keepForAWhile(ref);
  final isar = await ref.watch(isarProvider.future);
  final w = reportWindow(from, to);
  final products = await isar.products.where().findAll();
  final movements = await isar.stockMovements
      .filter()
      .createdAtBetween(w.start, w.end, includeUpper: false)
      .findAll();
  final orders = await loadOrdersAndReturns(isar, w.start, w.end);
  return buildInventoryReport(
    products: products,
    movements: movements,
    orders: orders,
    cancelledOrderIds: await loadCancelledOrderIds(isar),
    start: w.start,
    end: w.end,
  );
}

@riverpod
Future<PurchasesReport> purchasesReport(
    Ref ref, DateTime from, DateTime to) async {
  final isar = await ref.watch(isarProvider.future);
  final w = reportWindow(from, to);
  // All purchases: "owed to suppliers today" spans every purchase.
  final purchases = await isar.purchases.where().findAll();
  final expenses = await isar.expenses
      .filter()
      .dateBetween(w.start, w.end, includeUpper: false)
      .findAll();
  final registers = await isar.cashRegisters
      .filter()
      .closedAtBetween(w.start, w.end, includeUpper: false)
      .findAll();
  return buildPurchasesReport(
    purchases: purchases,
    suppliers: await isar.suppliers.where().findAll(),
    expenses: expenses,
    registers: registers,
    start: w.start,
    end: w.end,
  );
}
