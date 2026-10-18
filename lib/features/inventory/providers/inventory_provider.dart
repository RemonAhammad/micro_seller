import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';

part 'inventory_provider.g.dart';

@riverpod
Stream<List<StockMovement>> stockMovements(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  final query = isar.stockMovements.where().sortByCreatedAtDesc();
  yield* reloadOn(isar.stockMovements.watchLazy(), query.findAll);
}

@riverpod
Stream<List<StockMovement>> productStockMovements(
    Ref ref, int productId) async* {
  final isar = await ref.watch(isarProvider.future);
  final query = isar.stockMovements.filter().productIdEqualTo(productId);
  yield* reloadOn(isar.stockMovements.watchLazy(), () async {
    final list = await query.findAll();
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  });
}
