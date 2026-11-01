import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/payment.dart';
import 'db_worker.dart';

const kDueEpsilon = 0.005;

class OrderDue {
  const OrderDue(this.order, this.due);
  final Order order;
  final double due;
}

List<OrderDue> computeOrderDues(Iterable<Order> orders) =>
    _effectiveDues(orders).where((d) => d.due > kDueEpsilon).toList();

double computeNetDue(Iterable<Order> orders) {
  final net = _effectiveDues(orders)
      .where((d) => d.due.abs() > kDueEpsilon)
      .fold<double>(0, (s, d) => s + d.due);
  return net > kDueEpsilon ? net : 0;
}

List<OrderDue> _effectiveDues(Iterable<Order> orders) {
  final returnedValue = <int, double>{};
  for (final o in orders) {
    if (o.isReturn &&
        o.returnStatus == ReturnStatus.refunded &&
        o.originalOrderId > 0) {
      returnedValue[o.originalOrderId] =
          (returnedValue[o.originalOrderId] ?? 0) + o.totalAmount;
    }
  }

  final dues = <OrderDue>[];
  for (final o in orders) {
    if (o.isReturn || o.orderStatus == OrderStatus.cancelled) continue;
    dues.add(OrderDue(o, o.balanceDue - (returnedValue[o.id] ?? 0)));
  }
  dues.sort((a, b) => (a.order.createdAt ?? DateTime(0))
      .compareTo(b.order.createdAt ?? DateTime(0)));
  return dues;
}

Query<Customer> _balanceCustomersQuery(Isar isar) =>
    isar.customers.where().build();

Query<Order> _balanceOrdersQuery(Isar isar) =>
    isar.orders.filter().customerIdGreaterThan(0).build();

List<Customer> _correctedBalances(
    List<Customer> customers, List<Order> orders) {
  final byCustomer = <int, List<Order>>{};
  for (final o in orders) {
    byCustomer.putIfAbsent(o.customerId, () => []).add(o);
  }
  final updated = <Customer>[];
  for (final c in customers) {
    final total = computeNetDue(byCustomer[c.id] ?? const []);
    if ((total - c.outstandingBalance).abs() > kDueEpsilon) {
      updated.add(c.copyWith(outstandingBalance: total));
    }
  }
  return updated;
}

Future<int> recalculateOutstandingBalancesInTxn(Isar isar) async {
  final updated = _correctedBalances(
    await _balanceCustomersQuery(isar).findAll(),
    await _balanceOrdersQuery(isar).findAll(),
  );
  await isar.customers.putAll(updated);
  return updated.length;
}

int recalculateOutstandingBalancesInTxnSync(Isar db) {
  final updated = _correctedBalances(
    _balanceCustomersQuery(db).findAllSync(),
    _balanceOrdersQuery(db).findAllSync(),
  );
  db.customers.putAllSync(updated);
  return updated.length;
}

int recalculateOutstandingBalancesJob(Isar db) =>
    db.writeTxnSync(() => recalculateOutstandingBalancesInTxnSync(db));

Future<int> recalculateOutstandingBalances(Isar isar) =>
    runDbJob(isar, recalculateOutstandingBalancesJob);

double duesCollectedBetween(
  List<Payment> payments,
  Map<int, Order> ordersById,
  DateTime start,
  DateTime end,
) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  var total = 0.0;
  for (final p in payments) {
    final paidAt = p.paidAt;
    if (p.amount <= 0) continue;
    if (paidAt == null || paidAt.isBefore(start) || !paidAt.isBefore(end)) {
      continue;
    }
    final orderDate = ordersById[p.orderId]?.createdAt;
    if (orderDate != null && !day(paidAt).isAfter(day(orderDate))) continue;
    total += p.amount;
  }
  return total;
}

const _balancesMigrationKey = 'outstandingBalancesV1Migrated';

Future<void> migrateOutstandingBalancesV1(Isar isar) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_balancesMigrationKey) == true) return;
  final changed =
      await isar.writeTxn(() => recalculateOutstandingBalancesInTxn(isar));
  debugPrint('[Migration] Outstanding balances recalculated ($changed changed)');
  await prefs.setBool(_balancesMigrationKey, true);
}
