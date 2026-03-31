import 'package:isar/isar.dart';
import '../models/stock_movement.dart';

class StockRepository {
  final Isar _isar;
  StockRepository(this._isar);

  Stream<List<StockMovement>> watchAll() {
    return _isar.stockMovements
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  Stream<List<StockMovement>> watchByProduct(int productId) {
    return _isar.stockMovements
        .filter()
        .productIdEqualTo(productId)
        .watch(fireImmediately: true);
  }

  Future<List<StockMovement>> getAll() =>
      _isar.stockMovements.where().sortByCreatedAtDesc().findAll();

  Future<List<StockMovement>> getByProduct(int productId) =>
      _isar.stockMovements
          .filter()
          .productIdEqualTo(productId)
          .sortByCreatedAtDesc()
          .findAll();

  Future<void> save(StockMovement movement) async {
    await _isar.writeTxn(() => _isar.stockMovements.put(movement));
  }
}
