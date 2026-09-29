import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/models/payment.dart';
import '../../../data/services/dues_service.dart';
import '../../../data/services/isar_service.dart';

part 'dues_provider.g.dart';

/// One Due Book row: a customer and everything they still owe.
class CustomerDue {
  const CustomerDue({
    required this.customer,
    required this.orderDues,
    required this.totalDue,
    this.lastPaymentAt,
  });

  final Customer customer;

  /// Oldest first.
  final List<OrderDue> orderDues;
  final DateTime? lastPaymentAt;

  /// Net of credits — may be less than the sum of [orderDues].
  final double totalDue;

  DateTime? get oldestDueDate => orderDues.first.order.createdAt;

  int get daysOutstanding {
    final since = oldestDueDate;
    if (since == null) return 0;
    return DateTime.now().difference(since).inDays;
  }
}

/// Every customer who owes money, computed live from orders. Re-emits
/// whenever orders, customers or payments change.
@riverpod
Stream<List<CustomerDue>> dues(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);

  Future<List<CustomerDue>> load() async {
    final orders = await isar.orders.filter().customerIdGreaterThan(0).findAll();
    final byCustomer = <int, List<Order>>{};
    for (final o in orders) {
      byCustomer.putIfAbsent(o.customerId, () => []).add(o);
    }

    final result = <CustomerDue>[];
    for (final entry in byCustomer.entries) {
      final totalDue = computeNetDue(entry.value);
      if (totalDue <= 0) continue;
      final orderDues = computeOrderDues(entry.value);
      final customer = await isar.customers.get(entry.key);
      if (customer == null) continue;
      final lastPayment = await isar.payments
          .filter()
          .customerIdEqualTo(entry.key)
          .amountGreaterThan(0)
          .sortByPaidAtDesc()
          .findFirst();
      result.add(CustomerDue(
        customer: customer,
        orderDues: orderDues,
        totalDue: totalDue,
        lastPaymentAt: lastPayment?.paidAt,
      ));
    }
    result.sort((a, b) => b.daysOutstanding.compareTo(a.daysOutstanding));
    return result;
  }

  yield await load();
  // Payments only change alongside orders, but customers can be renamed or
  // deleted independently — watch both.
  final changes = _merge([
    isar.orders.watchLazy(),
    isar.customers.watchLazy(),
  ]);
  await for (final _ in changes) {
    yield await load();
  }
}

/// Dashboard roll-up of [dues]. Aging is per customer by their oldest unpaid
/// order — the same rule as the Due Book's "How long unpaid" filter — so the
/// three buckets always sum to [total].
class DueSummary {
  const DueSummary({
    this.total = 0,
    this.customerCount = 0,
    this.under30 = 0,
    this.from30to60 = 0,
    this.over60 = 0,
    this.over60Count = 0,
  });

  final double total;
  final int customerCount;
  final double under30;
  final double from30to60;
  final double over60;
  final int over60Count;
}

DueSummary summarizeDues(List<CustomerDue> dues) {
  var total = 0.0, under30 = 0.0, from30to60 = 0.0, over60 = 0.0;
  var over60Count = 0;
  for (final d in dues) {
    total += d.totalDue;
    final days = d.daysOutstanding;
    if (days >= 60) {
      over60 += d.totalDue;
      over60Count++;
    } else if (days >= 30) {
      from30to60 += d.totalDue;
    } else {
      under30 += d.totalDue;
    }
  }
  return DueSummary(
    total: total,
    customerCount: dues.length,
    under30: under30,
    from30to60: from30to60,
    over60: over60,
    over60Count: over60Count,
  );
}

@riverpod
DueSummary? dueSummary(Ref ref) {
  final dues = ref.watch(duesProvider).value;
  return dues == null ? null : summarizeDues(dues);
}

/// Dues collected since the 1st of this month (see [duesCollectedBetween]).
@riverpod
Stream<double> duesCollectedThisMonth(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);

  Future<double> load() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    final payments =
        await isar.payments.filter().paidAtBetween(start, end).findAll();
    final orders = await isar.orders
        .getAll(payments.map((p) => p.orderId).toSet().toList());
    final byId = {
      for (final o in orders)
        if (o != null) o.id: o,
    };
    return duesCollectedBetween(payments, byId, start, end);
  }

  yield await load();
  await for (final _ in isar.payments.watchLazy()) {
    yield await load();
  }
}

/// A customer's payment history, newest first.
@riverpod
Stream<List<Payment>> customerPayments(Ref ref, int customerId) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.payments
      .filter()
      .customerIdEqualTo(customerId)
      .sortByPaidAtDesc()
      .watch(fireImmediately: true);
}

/// Minimal stream merge so we don't pull in package:async for one call.
Stream<void> _merge(List<Stream<void>> streams) {
  final subs = <StreamSubscription<void>>[];
  late final StreamController<void> controller;
  controller = StreamController<void>(
    onListen: () {
      for (final s in streams) {
        subs.add(s.listen(controller.add, onError: controller.addError));
      }
    },
    onCancel: () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    },
  );
  return controller.stream;
}
