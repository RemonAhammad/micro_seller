import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/order.dart';

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
double computeNetDue(Iterable<Order> orders) {
  final net = _effectiveDues(orders).fold<double>(0, (s, d) => s + d.due);
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
  var changed = 0;
  for (final c in customers) {
    final orders = await isar.orders.filter().customerIdEqualTo(c.id).findAll();
    final total = computeNetDue(orders);
    if ((total - c.outstandingBalance).abs() > kDueEpsilon) {
      await isar.customers.put(c.copyWith(outstandingBalance: total));
      changed++;
    }
  }
  return changed;
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
