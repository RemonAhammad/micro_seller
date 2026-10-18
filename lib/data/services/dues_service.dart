import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/payment.dart';

/// Amounts below this are treated as settled (floating-point dust).
const kDueEpsilon = 0.005;

/// What one order still owes.
class OrderDue {
  const OrderDue(this.order, this.due);
  final Order order;
  final double due;
}

/// Computes what each order still owes, oldest first, from the orders
/// themselves — never from `Customer.outstandingBalance`, which is a running
/// counter that drifts (`updateOrder` doesn't adjust it).
///
/// Pass every order that could matter, *including return orders*: a refunded
/// return lowers the original order's `amountPaid` by the refund but leaves
/// its `totalAmount` alone, so the original's raw `balanceDue` grows by the
/// refund. Its effective due is `balanceDue − value of its refunded returns`,
/// which is exactly what `processRefund` takes off the customer's counter.
List<OrderDue> computeOrderDues(Iterable<Order> orders) =>
    _effectiveDues(orders).where((d) => d.due > kDueEpsilon).toList();

/// What the customer owes in total: the sum of every order's effective due,
/// *including credits* (an order whose refunded-return value exceeds what was
/// left on it goes negative), floored at 0. This is the number the counter,
/// the statement and a collection cap all agree on — summing only the
/// positive [computeOrderDues] would overstate it.
///
/// Orders within [kDueEpsilon] of settled are left out, as in
/// [computeOrderDues]: otherwise sub-paisa leftovers on several orders add
/// up to a "due" that no order shows — which can't be collected, and left
/// the Due Book with a customer owing money on no order.
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

/// Resets every customer's `outstandingBalance` to what their orders actually
/// owe. Caller owns the transaction.
Future<int> recalculateOutstandingBalancesInTxn(Isar isar) async {
  final customers = await isar.customers.where().findAll();
  // One id-ordered load grouped in Dart, not one full orders scan per
  // customer — each group keeps id order, so the sums are unchanged.
  final orders = await isar.orders.filter().customerIdGreaterThan(0).findAll();
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
  await isar.customers.putAll(updated);
  return updated.length;
}

/// Money collected on dues in `[start, end)` — payments received on a later
/// day than their order was created (so pay-at-sale isn't counted as "dues
/// collected"). Refunds and cancel reversals (negative rows) are ignored: a
/// refund of a pay-at-sale order was never counted here, so subtracting it
/// would understate the figure or drive it negative.
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

/// One-time repair of counters that drifted before the Due Book existed.
Future<void> migrateOutstandingBalancesV1(Isar isar) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_balancesMigrationKey) == true) return;
  final changed =
      await isar.writeTxn(() => recalculateOutstandingBalancesInTxn(isar));
  debugPrint('[Migration] Outstanding balances recalculated ($changed changed)');
  await prefs.setBool(_balancesMigrationKey, true);
}
