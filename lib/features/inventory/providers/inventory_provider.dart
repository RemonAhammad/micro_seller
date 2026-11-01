import 'dart:async';

import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';

part 'inventory_provider.g.dart';

@riverpod
Stream<List<StockMovement>> stockMovements(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* reloadOn(
    isar.stockMovements.watchLazy(),
    () => runDbJob(isar, _allMovementsNewestFirst),
  );
}

List<StockMovement> _allMovementsNewestFirst(Isar db) =>
    db.stockMovements.where(sort: Sort.desc).anyCreatedAt().findAllSync();

const kMovementPageSize = 100;

class StockMovementPage {
  const StockMovementPage(this.movements, {required this.hasMore});

  final List<StockMovement> movements;
  final bool hasMore;
}

StockMovementPage Function(Isar) _movementPageJob(int limit) => (db) {

  final rows = db.stockMovements
      .where(sort: Sort.desc)
      .anyCreatedAt()
      .limit(limit + 1)
      .findAllSync();
  final hasMore = rows.length > limit;
  return StockMovementPage(
    hasMore ? rows.sublist(0, limit) : rows,
    hasMore: hasMore,
  );
};

@riverpod
class StockMovementPages extends _$StockMovementPages {
  int _limit = kMovementPageSize;
  StreamController<void>? _more;

  @override
  Stream<StockMovementPage> build() async* {
    final isar = await ref.watch(isarProvider.future);
    final more = StreamController<void>();
    ref.onDispose(more.close);
    _more = more;
    yield* reloadOn(
      mergeChanges([isar.stockMovements.watchLazy(), more.stream]),
      () => runDbJob(isar, _movementPageJob(_limit)),
    );
  }

  void loadMore() {
    final page = state.value;
    if (page == null || !page.hasMore || page.movements.length < _limit) {
      return;
    }
    _limit += kMovementPageSize;
    _more?.add(null);
  }
}

@riverpod
Stream<List<StockMovement>> productStockMovements(
  Ref ref,
  int productId,
) async* {
  final isar = await ref.watch(isarProvider.future);
  final query = isar.stockMovements.filter().productIdEqualTo(productId);
  yield* reloadOn(isar.stockMovements.watchLazy(), () async {
    final list = await query.findAll();
    list.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return list;
  });
}
