import 'package:isar_community/isar.dart';
import '../models/order.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

class OrderRepository {
  final Isar _isar;
  OrderRepository(this._isar);

  Stream<List<Order>> watchAll() {
    return _isar.orders
        .where()
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  Stream<List<Order>> watchByStatus(OrderStatus status) {
    return _isar.orders
        .filter()
        .orderStatusEqualTo(status)
        .watch(fireImmediately: true);
  }

  Future<List<Order>> getAll() =>
      _isar.orders.where().sortByCreatedAtDesc().findAll();

  Future<Order?> getById(int id) => _isar.orders.get(id);

  Future<List<Order>> getByCustomer(int customerId) =>
      _isar.orders.filter().customerIdEqualTo(customerId).findAll();

  Future<List<Order>> getByDateRange(DateTime from, DateTime to) =>
      _isar.orders
          .filter()
          .createdAtBetween(from, to)
          .sortByCreatedAtDesc()
          .findAll();

  Future<String> generateOrderNumber() async {
    final count = await _isar.orders.count();
    final num = (count + 1).toString().padLeft(3, '0');
    return 'ORD-$num';
  }

  /// Creates an order and performs all related side-effects in one transaction:
  /// - Deducts stock from products
  /// - Creates StockMovement records
  /// - Updates customer stats
  Future<void> createOrder(Order order) async {
    await _isar.writeTxn(() async {
      // Save the order
      await _isar.orders.put(order);

      // Deduct stock & create stock movements
      for (final item in order.items) {
        final product = await _isar.products.get(item.productId);
        if (product != null && order.orderStatus == OrderStatus.confirmed) {
          final updated = product.copyWith(
            stockQty: product.stockQty - item.qty,
            updatedAt: DateTime.now(),
          );
          await _isar.products.put(updated);
          await _isar.stockMovements.put(StockMovement(
            productId: item.productId,
            productName: item.productName,
            type: StockMovementType.sale,
            qty: -item.qty,
            reason: 'Order ${order.orderNumber}',
            createdAt: DateTime.now(),
          ));
        }
      }

      // Update customer stats
      if (order.customerId > 0) {
        final customer = await _isar.customers.get(order.customerId);
        if (customer != null) {
          final updated = customer.copyWith(
            totalOrders: customer.totalOrders + 1,
            totalSpent: customer.totalSpent + order.totalAmount,
            outstandingBalance: customer.outstandingBalance +
                (order.totalAmount - order.amountPaid),
          );
          await _isar.customers.put(updated);
        }
      }
    });
  }

  Future<void> updateOrder(Order order) async {
    await _isar.writeTxn(() => _isar.orders.put(order));
  }

  Future<void> markAsPaid(int orderId, double amountPaid) async {
    await _isar.writeTxn(() async {
      final order = await _isar.orders.get(orderId);
      if (order == null) return;

      final prevBalance = order.totalAmount - order.amountPaid;
      final newAmountPaid = order.amountPaid + amountPaid;
      final paymentStatus = newAmountPaid >= order.totalAmount
          ? PaymentStatus.paid
          : PaymentStatus.partial;

      final updated = order.copyWith(
        amountPaid: newAmountPaid,
        paymentStatus: paymentStatus,
        updatedAt: DateTime.now(),
      );
      await _isar.orders.put(updated);

      // Update customer balance
      if (order.customerId > 0) {
        final customer = await _isar.customers.get(order.customerId);
        if (customer != null) {
          final c = customer.copyWith(
            outstandingBalance:
                customer.outstandingBalance - amountPaid.clamp(0, prevBalance),
          );
          await _isar.customers.put(c);
        }
      }
    });
  }

  Future<void> updateStatus(int orderId, OrderStatus status) async {
    await _isar.writeTxn(() async {
      final order = await _isar.orders.get(orderId);
      if (order == null) return;
      final updated = order.copyWith(
        orderStatus: status,
        updatedAt: DateTime.now(),
      );
      await _isar.orders.put(updated);
    });
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.orders.delete(id));
  }
}
