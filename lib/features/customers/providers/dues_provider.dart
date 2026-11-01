import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/models/payment.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/dues_service.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';

part 'dues_provider.g.dart';

class CustomerDue {
  const CustomerDue({
    required this.customer,
    required this.orderDues,
    required this.totalDue,
    this.lastPaymentAt,
  });

  final Customer customer;

  final List<OrderDue> orderDues;
  final DateTime? lastPaymentAt;

  final double totalDue;

  DateTime? get oldestDueDate =>
      orderDues.isEmpty ? null : orderDues.first.order.createdAt;

  int get daysOutstanding {
    final since = oldestDueDate;
    if (since == null) return 0;
    return DateTime.now().difference(since).inDays;
  }
}

List<CustomerDue> loadDuesSync(Isar db) => db.txnSync(() {

      final orders = db.orders.filter().customerIdGreaterThan(0).findAllSync();
      final byCustomer = <int, List<Order>>{};
      for (final o in orders) {
        byCustomer.putIfAbsent(o.customerId, () => []).add(o);
      }

      final debts = <int, double>{};
      for (final entry in byCustomer.entries) {
        final totalDue = computeNetDue(entry.value);
        if (totalDue > 0) debts[entry.key] = totalDue;
      }
      if (debts.isEmpty) return <CustomerDue>[];

      final ids = debts.keys.toList();
      final customers = db.customers.getAllSync(ids);

      final positive = db.payments.filter().amountGreaterThan(0);
      final payer = positive.customerIdProperty().findAllSync();
      final paidAt = positive.paidAtProperty().findAllSync();
      final lastPaidAt = <int, DateTime>{};
      for (var i = 0; i < payer.length; i++) {
        final at = paidAt[i];
        if (at == null || !debts.containsKey(payer[i])) continue;
        final prev = lastPaidAt[payer[i]];
        if (prev == null || at.isAfter(prev)) lastPaidAt[payer[i]] = at;
      }

      final result = <CustomerDue>[];
      for (var i = 0; i < ids.length; i++) {
        final customer = customers[i];
        if (customer == null) continue;
        result.add(CustomerDue(
          customer: customer,
          orderDues: computeOrderDues(byCustomer[ids[i]]!),
          totalDue: debts[ids[i]]!,
          lastPaymentAt: lastPaidAt[ids[i]],
        ));
      }
      result.sort((a, b) => b.daysOutstanding.compareTo(a.daysOutstanding));
      return result;
    });

@riverpod
Stream<List<CustomerDue>> dues(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);

  yield* reloadOn(
    mergeChanges([isar.orders.watchLazy(), isar.customers.watchLazy()]),
    () => runDbJob(isar, loadDuesSync),
  );
}

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

@riverpod
Stream<double> duesCollectedThisMonth(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);

  Future<double> load() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);

    final payments = (await isar.payments
        .where()
        .paidAtBetween(start, end)
        .findAll())
      ..sort((a, b) => a.id.compareTo(b.id));
    final orders = await isar.orders
        .getAll(payments.map((p) => p.orderId).toSet().toList());
    final byId = {
      for (final o in orders)
        if (o != null) o.id: o,
    };
    return duesCollectedBetween(payments, byId, start, end);
  }

  yield* reloadOn(isar.payments.watchLazy(), load);
}

@riverpod
Stream<List<Payment>> customerPayments(Ref ref, int customerId) async* {
  final isar = await ref.watch(isarProvider.future);
  final query =
      isar.payments.where().customerIdEqualTo(customerId).sortByPaidAtDesc()

          .thenById();
  yield* reloadOn(isar.payments.watchLazy(), query.findAll);
}
