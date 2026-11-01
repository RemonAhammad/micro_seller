import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../models/category.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../models/trash_entry.dart';

const kTrashRetention = Duration(days: 30);

class TrashService {
  final Isar _isar;

  TrashService(this._isar);

  Future<int> capture({
    required TrashKind kind,
    required int originalId,
    required Map<String, dynamic> payload,
    Map<String, dynamic> sidecar = const {},
    required String label,
    String sublabel = '',
  }) {
    return _isar.trashEntries.put(
      TrashEntry(
        kind: kind,
        originalId: originalId,
        payload: jsonEncode(payload),
        sidecar: jsonEncode(sidecar),
        label: label,
        sublabel: sublabel,
        deletedAt: DateTime.now(),
      ),
    );
  }

  Stream<List<TrashEntry>> watchAll() => _isar.trashEntries
      .where()
      .sortByDeletedAtDesc()
      .watch(fireImmediately: true);

  Future<List<TrashEntry>> all() =>
      _isar.trashEntries.where().sortByDeletedAtDesc().findAll();

  Future<int> count() => _isar.trashEntries.count();

  Future<bool> restore(int trashId) async {
    final entry = await _isar.trashEntries.get(trashId);
    if (entry == null) return false;

    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    final sidecar = jsonDecode(entry.sidecar) as Map<String, dynamic>;

    await _isar.writeTxn(() async {
      switch (entry.kind) {
        case TrashKind.expense:
          await _isar.expenses.put(Expense.fromJson(payload));
        case TrashKind.category:
          await _isar.categories.put(Category.fromJson(payload));
        case TrashKind.customer:
          await _restoreCustomer(payload, sidecar);
        case TrashKind.product:
          await _restoreProduct(payload, sidecar);
        case TrashKind.order:
        case TrashKind.purchase:
        case TrashKind.supplier:

          throw UnsupportedError(
            'Restore for ${entry.kind.name} is not implemented yet',
          );
      }
      await _isar.trashEntries.delete(trashId);
    });
    return true;
  }

  Future<void> _restoreCustomer(
    Map<String, dynamic> payload,
    Map<String, dynamic> sidecar,
  ) async {
    final customer = Customer.fromJson(payload);
    await _isar.customers.put(customer);

    final ids = (sidecar['unlinkedOrderIds'] as List?)?.cast<int>() ?? const [];
    for (final orderId in ids) {
      final order = await _isar.orders.get(orderId);

      if (order == null) continue;
      await _isar.orders.put(
        order.copyWith(customerId: customer.id, updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> _restoreProduct(
    Map<String, dynamic> payload,
    Map<String, dynamic> sidecar,
  ) async {
    final product = Product.fromJson(payload);

    if (sidecar['softDeleted'] == true) {

      final current = await _isar.products.get(product.id);
      await _isar.products.put(
        (current ?? product).copyWith(isActive: true, updatedAt: DateTime.now()),
      );
      return;
    }

    await _isar.products.put(product);

    final movements = (sidecar['stockMovements'] as List?) ?? const [];
    if (movements.isNotEmpty) {
      await _isar.stockMovements.putAll(
        movements
            .map((e) => StockMovement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
  }

  Future<void> deleteForever(int trashId) =>
      _isar.writeTxn(() => _isar.trashEntries.delete(trashId));

  Future<void> clearAll() =>
      _isar.writeTxn(() => _isar.trashEntries.clear());

  Future<int> purgeExpired({Duration age = kTrashRetention}) async {
    final cutoff = DateTime.now().subtract(age);
    final stale = await _isar.trashEntries
        .filter()
        .deletedAtLessThan(cutoff)
        .findAll();
    if (stale.isEmpty) return 0;
    await _isar.writeTxn(
      () => _isar.trashEntries.deleteAll(stale.map((e) => e.id).toList()),
    );
    return stale.length;
  }
}
