import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/order.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';

part 'order_pages_provider.g.dart';

const kOrderPageSize = 100;

enum OrderTab {
  all(null),
  pending([OrderStatus.pending]),
  active([OrderStatus.confirmed, OrderStatus.shipped]),
  completed([OrderStatus.completed]),
  cancelled([OrderStatus.cancelled]);

  const OrderTab(this.statuses);

  final List<OrderStatus>? statuses;
}

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

OrderPage Function(Isar) _pageJob(int tabIndex, int limit) => (db) {
  final tab = OrderTab.values[tabIndex];

  final rows = _ofTab(
    db.orders.where(sort: Sort.desc).anyCreatedAt().filter(),
    tab,
  ).limit(limit + 1).findAllSync();
  final hasMore = rows.length > limit;
  return OrderPage(hasMore ? rows.sublist(0, limit) : rows, hasMore: hasMore);
};

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

  void loadMore() {
    final page = state.value;
    if (page == null || !page.hasMore || page.orders.length < _limit) return;
    _limit += kOrderPageSize;
    _more?.add(null);
  }
}

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

Future<List<Order>> loadAllOrdersNewestFirst(Isar isar) =>
    runDbJob(isar, _allOrdersNewestFirst);

List<Order> _allOrdersNewestFirst(Isar db) =>
    db.orders.where(sort: Sort.desc).anyCreatedAt().findAllSync();
