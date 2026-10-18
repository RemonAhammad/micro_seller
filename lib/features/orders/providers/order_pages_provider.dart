import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/order.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';

part 'order_pages_provider.g.dart';

/// Rows per page of the Orders tabs; [OrderPages.loadMore] adds this many.
const kOrderPageSize = 100;

/// The Orders screen's tabs, in tab order. Every tab lists regular
/// (non-return) orders only.
enum OrderTab {
  all(null),
  pending([OrderStatus.pending]),
  active([OrderStatus.confirmed, OrderStatus.shipped]),
  completed([OrderStatus.completed]),
  cancelled([OrderStatus.cancelled]);

  const OrderTab(this.statuses);

  /// The statuses this tab shows; null = every status.
  final List<OrderStatus>? statuses;
}

/// The first [orders] of a tab, newest first, and whether more exist.
class OrderPage {
  const OrderPage(this.orders, {required this.hasMore});

  final List<Order> orders;
  final bool hasMore;
}

QueryBuilder<Order, Order, QAfterFilterCondition> _ofTab(
  QueryBuilder<Order, Order, QFilterCondition> q,
  OrderTab tab,
) {
  final regular = q.isReturnEqualTo(false);
  final statuses = tab.statuses;
  return statuses == null
      ? regular
      : regular.anyOf(statuses, (q, s) => q.orderStatusEqualTo(s));
}

// Takes the tab's index, not the enum: the job crosses to a worker isolate,
// and an index resolved there can't depend on how enum instances are copied.
OrderPage Function(Isar) _pageJob(int tabIndex, int limit) => (db) {
  final tab = OrderTab.values[tabIndex];
  // createdAt-index order, as ordersProvider reads it; one extra row tells
  // whether more exist.
  final rows = _ofTab(
    db.orders.where(sort: Sort.desc).anyCreatedAt().filter(),
    tab,
  ).limit(limit + 1).findAllSync();
  final hasMore = rows.length > limit;
  return OrderPage(hasMore ? rows.sublist(0, limit) : rows, hasMore: hasMore);
};

/// One Orders tab, paged: the newest [kOrderPageSize] matching orders, more
/// on [loadMore]. Kept alive so switching tabs doesn't reload from scratch;
/// a tab that isn't shown is paused and doesn't reload on writes.
@Riverpod(keepAlive: true)
class OrderPages extends _$OrderPages {
  int _limit = kOrderPageSize;
  StreamController<void>? _more;

  @override
  Stream<OrderPage> build(OrderTab tab) async* {
    final isar = await ref.watch(isarProvider.future);
    final more = StreamController<void>();
    ref.onDispose(more.close);
    _more = more;
    yield* reloadOn(
      mergeChanges([isar.orders.watchLazy(), more.stream]),
      () => runDbJob(isar, _pageJob(tab.index, _limit)),
    );
  }

  /// Extends the page by [kOrderPageSize]. Ignored until the previous
  /// extension has loaded, so repeated calls from a scrolling list are safe.
  void loadMore() {
    final page = state.value;
    if (page == null || !page.hasMore || page.orders.length < _limit) return;
    _limit += kOrderPageSize;
    _more?.add(null);
  }
}

/// The Orders tab badges, in [OrderTab] order — counted natively, without
/// loading any order.
@riverpod
Stream<List<int>> orderTabCounts(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* reloadOn(
    isar.orders.watchLazy(),
    () => isar.txn(
      () async => [
        for (final tab in OrderTab.values)
          await _ofTab(isar.orders.filter(), tab).count(),
      ],
    ),
  );
}

/// Every order (returns included) newest first, loaded on a worker — for the
/// CSV export, which must not depend on how far a list has been scrolled.
Future<List<Order>> loadAllOrdersNewestFirst(Isar isar) =>
    runDbJob(isar, _allOrdersNewestFirst);

List<Order> _allOrdersNewestFirst(Isar db) =>
    db.orders.where(sort: Sort.desc).anyCreatedAt().findAllSync();
