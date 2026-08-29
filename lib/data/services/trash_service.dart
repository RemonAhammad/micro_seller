import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../models/category.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../models/trash_entry.dart';

/// How long a deleted record stays recoverable.
const kTrashRetention = Duration(days: 30);

/// Soft-delete store backing the undo snackbar and the Recycle Bin screen.
///
/// Deletes in this app are not pure — they mutate neighbouring records.
/// Deleting a customer unlinks their orders; deleting a product may also wipe
/// its stock movements. Restoring only the deleted row would leave those
/// side effects in place, so each entry carries a `sidecar` describing what
/// else changed and how to put it back.
///
/// Every restore runs inside a single `writeTxn`, so a partial restore can
/// never be observed.
class TrashService {
  final Isar _isar;

  TrashService(this._isar);

  // ── capture ────────────────────────────────────────────────────────────

  /// Records a deleted item. Call this *inside* the same transaction as the
  /// delete so the two can't diverge.
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

  // ── queries ────────────────────────────────────────────────────────────

  Stream<List<TrashEntry>> watchAll() => _isar.trashEntries
      .where()
      .sortByDeletedAtDesc()
      .watch(fireImmediately: true);

  Future<List<TrashEntry>> all() =>
      _isar.trashEntries.where().sortByDeletedAtDesc().findAll();

  Future<int> count() => _isar.trashEntries.count();

  // ── restore ────────────────────────────────────────────────────────────

  /// Puts a trashed record back, reversing whatever else its delete touched.
  ///
  /// Returns false if the entry no longer exists (already restored, purged,
  /// or emptied from another screen).
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
          // Phase B — these reverse stock, variant stock, movements and
          // supplier/customer stats, and are wired up separately.
          throw UnsupportedError(
            'Restore for ${entry.kind.name} is not implemented yet',
          );
      }
      await _isar.trashEntries.delete(trashId);
    });
    return true;
  }

  /// Re-links the orders whose `customerId` the delete zeroed out.
  Future<void> _restoreCustomer(
    Map<String, dynamic> payload,
    Map<String, dynamic> sidecar,
  ) async {
    final customer = Customer.fromJson(payload);
    await _isar.customers.put(customer);

    final ids = (sidecar['unlinkedOrderIds'] as List?)?.cast<int>() ?? const [];
    for (final orderId in ids) {
      final order = await _isar.orders.get(orderId);
      // The order may itself have been deleted in the meantime — skip rather
      // than resurrecting it.
      if (order == null) continue;
      await _isar.orders.put(
        order.copyWith(customerId: customer.id, updatedAt: DateTime.now()),
      );
    }
  }

  /// Two delete branches to undo: a soft-delete just flipped `isActive`, a
  /// hard-delete also removed the product's stock movements.
  Future<void> _restoreProduct(
    Map<String, dynamic> payload,
    Map<String, dynamic> sidecar,
  ) async {
    final product = Product.fromJson(payload);

    if (sidecar['softDeleted'] == true) {
      // The row is still there with isActive == false; flip it back rather
      // than overwriting whatever edits happened since.
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

  // ── removal ────────────────────────────────────────────────────────────

  Future<void> deleteForever(int trashId) =>
      _isar.writeTxn(() => _isar.trashEntries.delete(trashId));

  Future<void> clearAll() =>
      _isar.writeTxn(() => _isar.trashEntries.clear());

  /// Drops entries past the retention window. Called once on app startup.
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
