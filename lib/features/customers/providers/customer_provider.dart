import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/models/trash_entry.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/trash_service.dart';

part 'customer_provider.g.dart';

@riverpod
Stream<List<Customer>> customers(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  // The name index returns them in name order — no sort per reload.
  final query = isar.customers.where().anyName();
  yield* reloadOn(isar.customers.watchLazy(), query.findAll);
}

@Riverpod(keepAlive: true)
class CustomerNotifier extends _$CustomerNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> addCustomer(Customer customer) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final now = DateTime.now();
      await isar.writeTxn(() async =>
          isar.customers.put(customer.copyWith(createdAt: now)));
    });
  }

  Future<void> updateCustomer(Customer customer) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async => isar.customers.put(customer));
    });
  }

  /// Moves the customer to the trash instead of destroying them. Their orders
  /// are unlinked (not deleted) exactly as before; the unlinked order ids go
  /// into the trash sidecar so a restore can re-link them.
  /// Returns the trash entry id, for wiring an UNDO action. Null if the
  /// customer was already gone.
  Future<int?> deleteCustomer(int id) async {
    int? trashId;
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final trash = TrashService(isar);
      await isar.writeTxn(() async {
        final customer = await isar.customers.get(id);
        if (customer == null) return;

        // Clear customerId on related orders (keep orders, unlink customer)
        final orders = await isar.orders.where().customerIdEqualTo(id).findAll();
        for (final order in orders) {
          await isar.orders.put(order.copyWith(
            customerId: 0,
            updatedAt: DateTime.now(),
          ));
        }

        trashId = await trash.capture(
          kind: TrashKind.customer,
          originalId: id,
          payload: customer.toJson(),
          sidecar: {'unlinkedOrderIds': orders.map((o) => o.id).toList()},
          label: customer.name,
          sublabel: customer.phone,
        );
        await isar.customers.delete(id);
      });
    });
    return trashId;
  }
}
