import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/services/isar_service.dart';

part 'inventory_provider.g.dart';

@riverpod
Stream<List<StockMovement>> stockMovements(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.stockMovements
      .where()
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);
}

@riverpod
Stream<List<StockMovement>> productStockMovements(
    Ref ref, int productId) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.stockMovements
      .filter()
      .productIdEqualTo(productId)
      .watch(fireImmediately: true)
      .map((list) {
    list.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list;
  });
}
