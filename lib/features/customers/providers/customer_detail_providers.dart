import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';

part 'customer_detail_providers.g.dart';

@riverpod
Stream<Customer?> customerById(Ref ref, int id) async* {
  final isar = await ref.watch(isarProvider.future);
  yield isar.customers.getSync(id);

  yield* isar.customers.watchObject(id);
}

const kCustomerOrdersPageSize = 100;

class CustomerOrdersPage {
  const CustomerOrdersPage(this.orders, {required this.hasMore});

  final List<Order> orders;
  final bool hasMore;
}

CustomerOrdersPage Function(Isar) customerOrdersJob(
        int customerId, int limit) =>
    (db) => db.txnSync(() {
          final byCustomer = db.orders.where().customerIdEqualTo(customerId);
          final ids = byCustomer.idProperty().findAllSync();
          final dates = byCustomer.createdAtProperty().findAllSync();
          final newestFirst = List.generate(ids.length, (i) => i)
            ..sort((a, b) {
              final x = dates[a], y = dates[b];
              final byDate = x == null
                  ? (y == null ? 0 : 1)
                  : (y == null ? -1 : y.compareTo(x));
              return byDate != 0 ? byDate : ids[a].compareTo(ids[b]);
            });
          final pageIds = [
            for (final i in newestFirst.take(limit + 1)) ids[i],
          ];
          final rows = [
            for (final o in db.orders.getAllSync(pageIds)) ?o,
          ];
          final hasMore = rows.length > limit;
          return CustomerOrdersPage(
            hasMore ? rows.sublist(0, limit) : rows,
            hasMore: hasMore,
          );
        });

@riverpod
class CustomerOrders extends _$CustomerOrders {
  int _limit = kCustomerOrdersPageSize;
  StreamController<void>? _more;

  @override
  Stream<CustomerOrdersPage> build(int customerId) async* {
    final isar = await ref.watch(isarProvider.future);
    final more = StreamController<void>();
    ref.onDispose(more.close);
    _more = more;
    yield* reloadOn(
      mergeChanges([isar.orders.watchLazy(), more.stream]),
      () => runDbJob(isar, customerOrdersJob(customerId, _limit)),
    );
  }

  void loadMore() {
    final page = state.value;
    if (page == null || !page.hasMore || page.orders.length < _limit) return;
    _limit += kCustomerOrdersPageSize;
    _more?.add(null);
  }
}

@riverpod
Stream<Map<DateTime, double>?> customerMonthlySpending(
    Ref ref, int customerId) async* {
  final isar = await ref.watch(isarProvider.future);

  final query = isar.orders
      .filter()
      .customerIdEqualTo(customerId)
      .not()
      .orderStatusEqualTo(OrderStatus.cancelled)
      .sortByCreatedAt();
  yield* reloadOn(
    isar.orders.watchLazy(),
    () => isar.txn(() async {
      final dates = await query.createdAtProperty().findAll();
      final totals = await query.totalAmountProperty().findAll();
      return spendingByMonth(dates, totals, DateTime.now());
    }),
  );
}

Map<DateTime, double>? spendingByMonth(
    List<DateTime?> dates, List<double> totals, DateTime now) {
  if (dates.isEmpty) return null;
  final spending = <DateTime, double>{
    for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1): 0,
  };
  for (var i = 0; i < dates.length; i++) {
    final at = dates[i];
    if (at == null) continue;
    final key = DateTime(at.year, at.month, 1);
    final sum = spending[key];
    if (sum != null) spending[key] = sum + totals[i];
  }
  return spending;
}
