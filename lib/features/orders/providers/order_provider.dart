import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/services/isar_service.dart';

part 'order_provider.g.dart';

@riverpod
Stream<List<Order>> orders(OrdersRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.orders
      .where()
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);
}

@riverpod
Stream<List<Order>> pendingOrders(PendingOrdersRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.orders
      .filter()
      .orderStatusEqualTo(OrderStatus.pending)
      .or()
      .orderStatusEqualTo(OrderStatus.confirmed)
      .watch(fireImmediately: true);
}

@riverpod
Stream<List<Order>> unpaidOrders(UnpaidOrdersRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.orders
      .filter()
      .paymentStatusEqualTo(PaymentStatus.unpaid)
      .or()
      .paymentStatusEqualTo(PaymentStatus.partial)
      .watch(fireImmediately: true);
}

@riverpod
class OrderNotifier extends _$OrderNotifier {
  @override
  FutureOr<void> build() {}

  Future<String> generateOrderNumber() async {
    final isar = await ref.read(isarProvider.future);
    final count = await isar.orders.count();
    final num = (count + 1).toString().padLeft(3, '0');
    return 'ORD-$num';
  }

  Future<void> createOrder(Order order) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        await isar.orders.put(order);

        // Deduct stock and create movements for confirmed orders
        if (order.orderStatus == OrderStatus.confirmed) {
          for (final item in order.items) {
            final product = await isar.products.get(item.productId);
            if (product != null) {
              final updated = product.copyWith(
                stockQty: product.stockQty - item.qty,
                updatedAt: DateTime.now(),
              );
              await isar.products.put(updated);
              await isar.stockMovements.put(StockMovement(
                productId: item.productId,
                productName: item.productName,
                type: StockMovementType.sale,
                qty: -item.qty,
                reason: 'Order ${order.orderNumber}',
                createdAt: DateTime.now(),
              ));
            }
          }
        }

        // Update customer stats
        if (order.customerId > 0) {
          final customer = await isar.customers.get(order.customerId);
          if (customer != null) {
            final updated = customer.copyWith(
              totalOrders: customer.totalOrders + 1,
              totalSpent: customer.totalSpent + order.totalAmount,
              outstandingBalance: customer.outstandingBalance +
                  (order.totalAmount - order.amountPaid),
            );
            await isar.customers.put(updated);
          }
        }
      });
    });
  }

  Future<void> updateOrder(Order order) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(
          () async => isar.orders.put(order.copyWith(updatedAt: DateTime.now())));
    });
  }

  Future<void> updateStatus(int orderId, OrderStatus status) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final order = await isar.orders.get(orderId);
        if (order == null) return;

        final oldStatus = order.orderStatus;
        if (oldStatus == status) return;

        final wasStockDeducted = oldStatus != OrderStatus.pending &&
            oldStatus != OrderStatus.cancelled;
        final shouldDeductStock =
            status != OrderStatus.pending && status != OrderStatus.cancelled;

        // Restore stock when rolling back to pending/cancelled
        if (wasStockDeducted && !shouldDeductStock) {
          for (final item in order.items) {
            final product = await isar.products.get(item.productId);
            if (product != null) {
              await isar.products.put(product.copyWith(
                stockQty: product.stockQty + item.qty,
                updatedAt: DateTime.now(),
              ));
              await isar.stockMovements.put(StockMovement(
                productId: item.productId,
                productName: item.productName,
                type: StockMovementType.adjustment,
                qty: item.qty,
                reason: 'Rollback ${order.orderNumber} → ${status.name}',
                createdAt: DateTime.now(),
              ));
            }
          }
        }

        // Deduct stock when moving from pending/cancelled to active status
        if (!wasStockDeducted && shouldDeductStock) {
          for (final item in order.items) {
            final product = await isar.products.get(item.productId);
            if (product != null) {
              await isar.products.put(product.copyWith(
                stockQty: product.stockQty - item.qty,
                updatedAt: DateTime.now(),
              ));
              await isar.stockMovements.put(StockMovement(
                productId: item.productId,
                productName: item.productName,
                type: StockMovementType.sale,
                qty: -item.qty,
                reason: 'Order ${order.orderNumber}',
                createdAt: DateTime.now(),
              ));
            }
          }
        }

        await isar.orders.put(order.copyWith(
          orderStatus: status,
          updatedAt: DateTime.now(),
        ));
      });
    });
  }

  Future<void> recordPayment(int orderId, double paymentAmount) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final order = await isar.orders.get(orderId);
        if (order == null) return;

        final newAmountPaid = order.amountPaid + paymentAmount;
        final paymentStatus = newAmountPaid >= order.totalAmount
            ? PaymentStatus.paid
            : PaymentStatus.partial;

        await isar.orders.put(order.copyWith(
          amountPaid: newAmountPaid,
          paymentStatus: paymentStatus,
          updatedAt: DateTime.now(),
        ));

        // Update customer balance
        if (order.customerId > 0) {
          final customer = await isar.customers.get(order.customerId);
          if (customer != null) {
            await isar.customers.put(customer.copyWith(
              outstandingBalance: (customer.outstandingBalance - paymentAmount)
                  .clamp(0, double.infinity),
            ));
          }
        }
      });
    });
  }

  Future<void> deleteOrder(int id) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async => isar.orders.delete(id));
    });
  }
}
