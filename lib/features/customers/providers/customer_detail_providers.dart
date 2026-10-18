import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';

part 'customer_detail_providers.g.dart';

// The customer detail screen's data. Providers rather than streams and
// futures created in build(): go_router rebuilds pages on every push/pop in
// the branch, and each rebuild used to resubscribe, flash a spinner and
// re-query.

/// One customer, live, so collecting a payment from their detail screen
/// refreshes the stats. Null once the customer doesn't exist.
@riverpod
Stream<Customer?> customerById(Ref ref, int id) async* {
  final isar = await ref.watch(isarProvider.future);
  yield isar.customers.getSync(id);
  // No fireImmediately: the current value was just yielded above.
  yield* isar.customers.watchObject(id);
}

/// Rows per page of a customer's purchase history; [CustomerOrders.loadMore]
/// adds this many.
const kCustomerOrdersPageSize = 100;

/// The first [orders] of a customer's purchase history, and whether more
/// exist.
class CustomerOrdersPage {
  const CustomerOrdersPage(this.orders, {required this.hasMore});

  /// Newest first.
  final List<Order> orders;
  final bool hasMore;
}

/// The first [limit] of a customer's orders, newest first — every order,
/// returns and cancelled ones included — as a job for a worker isolate
/// ([runDbJob]). One extra row tells whether more exist.
///
/// Through the customerId index, ordered here rather than by Isar: the index
/// lists equal keys in stored-id byte order, not id order, and Isar can't
/// sort by id to break createdAt ties. Newest first with nulls last, as
/// `sortByCreatedAtDesc` did; ties by id ascending — the order the old
/// id-order scan kept them in for up to 20 orders (Isar sorts longer lists
/// unstably, so beyond that the old tie order was arbitrary). Only the ids
/// and dates are read for every order; whole orders just for the page.
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

/// A customer's purchase history, live and paged: their newest
/// [kCustomerOrdersPageSize] orders, more on [loadMore]. Loaded on a worker
/// isolate.
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

  /// Extends the page by [kCustomerOrdersPageSize]. Ignored until the
  /// previous extension has loaded, so repeated calls from a scrolling list
  /// are safe.
  void loadMore() {
    final page = state.value;
    if (page == null || !page.hasMore || page.orders.length < _limit) return;
    _limit += kCustomerOrdersPageSize;
    _more?.add(null);
  }
}

/// The purchase-history chart: the customer's spending in each of the last
/// six months (oldest first), or null — chart hidden — when they have no
/// orders apart from cancelled ones. Live.
@riverpod
Stream<Map<DateTime, double>?> customerMonthlySpending(
    Ref ref, int customerId) async* {
  final isar = await ref.watch(isarProvider.future);
  // The chart's query as it always was — a scan in id order, then sorted —
  // so the sums add the same orders in the same order (Isar's sort is
  // unstable, so tied createdAt values follow its input order). Only two
  // properties come back, not whole orders. Only cancelled orders are left
  // out: returns and pending orders count, as they always did.
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

/// Sums each order's total (`totals[i]`, placed at `dates[i]`) into the six
/// months up to [now]'s, oldest first. Null when there are no orders at all.
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
