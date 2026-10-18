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

// Returns are dated by when their goods came back (`updatedAt`), which can
// fall in the period even if the return order was created earlier — so the
// sales/inventory reports (and the Dashboard's profit) load returns
// separately rather than by createdAt.
Future<List<Order>> loadOrdersAndReturns(
    Isar isar, DateTime start, DateTime end) async {
  final sales = await isar.orders
      .filter()
      .isReturnEqualTo(false)
      .createdAtBetween(start, end, includeUpper: false)
      .findAll();
  final returns = await isar.orders.filter().isReturnEqualTo(true).findAll();
  return [...sales, ...returns];
}

/// Ids of cancelled orders — returns against them are ignored (the cancel
/// already removed the sale).
Future<Set<int>> loadCancelledOrderIds(Isar isar) async => (await isar.orders
        .filter()
        .orderStatusEqualTo(OrderStatus.cancelled)
        .idProperty()
        .findAll())
    .toSet();

@riverpod
Future<SalesReport> salesReport(Ref ref, DateTime from, DateTime to) async {
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
      : await isar.payments
          .filter()
          .anyOf(periodIds, (q, int id) => q.orderIdEqualTo(id))
          .findAll();
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
