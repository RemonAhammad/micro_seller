import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/services/isar_service.dart';

part 'customer_provider.g.dart';

@riverpod
Stream<List<Customer>> customers(CustomersRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.customers.where().sortByName().watch(fireImmediately: true);
}

@riverpod
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

  Future<void> deleteCustomer(int id) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        // Clear customerId on related orders (keep orders, unlink customer)
        final orders = await isar.orders
            .filter()
            .customerIdEqualTo(id)
            .findAll();
        for (final order in orders) {
          await isar.orders.put(order.copyWith(
            customerId: 0,
            updatedAt: DateTime.now(),
          ));
        }
        await isar.customers.delete(id);
      });
    });
  }
}
