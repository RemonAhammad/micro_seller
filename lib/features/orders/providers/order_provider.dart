import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/models/cash_register.dart';
import '../../../data/models/order_item.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/dues_service.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';

part 'order_provider.g.dart';

@riverpod
Stream<List<Order>> orders(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* reloadOn(
      isar.orders.watchLazy(), () => runDbJob(isar, _allOrdersNewestFirst));
}

List<Order> _allOrdersNewestFirst(Isar db) =>
    db.orders.where(sort: Sort.desc).anyCreatedAt().findAllSync();

@riverpod
Stream<List<Order>> returnOrders(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  final query =
      isar.orders.filter().isReturnEqualTo(true).sortByCreatedAtDesc();
  yield* reloadOn(isar.orders.watchLazy(), query.findAll);
}

@riverpod
Stream<Order?> orderById(Ref ref, int id) async* {
  final isar = await ref.watch(isarProvider.future);
  yield isar.orders.getSync(id);

  yield* isar.orders.watchObject(id);
}

@riverpod
Stream<List<Order>> pendingOrders(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.orders
      .filter()
      .orderStatusEqualTo(OrderStatus.pending)
      .or()
      .orderStatusEqualTo(OrderStatus.confirmed)
      .watch(fireImmediately: true);
}

class OrderDateTooLate implements Exception {
  const OrderDateTooLate(this.latest);
  final DateTime latest;
}

const _atSaleWindow = Duration(seconds: 1);

@Riverpod(keepAlive: true)
class OrderNotifier extends _$OrderNotifier {
  @override
  FutureOr<void> build() {}

  Product _adjustVariantStock(Product product, OrderItem item, int delta) {
    if (!item.hasVariant) return product;

    final key = item.variantCombinationKey.isNotEmpty
        ? item.variantCombinationKey
        : '${item.variantName}:${item.variantValue}';

    final updatedCombinations = product.variantCombinations.map((c) {
      if (c.combinationKey == key) {
        return c.copyWith(stockQty: (c.stockQty + delta).clamp(0, 999999));
      }
      return c;
    }).toList();
    return product.copyWith(variantCombinations: updatedCombinations);
  }

  Future<void> _logPayment(
    Isar isar, {
    required Order order,
    required double amount,
    PaymentMethod? method,
    String transactionId = '',
    String note = '',
    String groupId = '',
    DateTime? paidAt,
  }) async {
    await isar.payments.put(_paymentRow(
      order: order,
      amount: amount,
      method: method,
      transactionId: transactionId,
      note: note,
      groupId: groupId,
      paidAt: paidAt,
    ));
  }

  Payment _paymentRow({
    required Order order,
    required double amount,
    PaymentMethod? method,
    String transactionId = '',
    String note = '',
    String groupId = '',
    DateTime? paidAt,
  }) {
    final now = DateTime.now();
    return Payment(
      customerId: order.customerId,
      orderId: order.id,
      amount: amount,
      method: method ?? order.paymentMethod,
      transactionId: transactionId,
      note: note,
      groupId: groupId,
      paidAt: paidAt ?? now,
      createdAt: now,
    );
  }

  Future<void> _moveStock(
    Isar isar,
    List<OrderItem> items, {
    required int sign,
    required StockMovementType type,
    required String reason,
    DateTime? at,
  }) async {
    if (items.isEmpty) return;
    final ids = {for (final item in items) item.productId}.toList();
    final products = <int, Product>{};
    for (final p in await isar.products.getAll(ids)) {
      if (p != null) products[p.id] = p;
    }
    final changed = <int>{};
    final movements = <StockMovement>[];
    for (final item in items) {
      final product = products[item.productId];
      if (product == null) continue;
      final delta = sign * item.qty;
      var updated = product.copyWith(
        stockQty: product.stockQty + delta,
        updatedAt: DateTime.now(),
      );
      updated = _adjustVariantStock(updated, item, delta);
      products[item.productId] = updated;
      changed.add(item.productId);
      movements.add(StockMovement(
        productId: item.productId,
        productName: item.productName,
        type: type,
        qty: delta,
        reason: reason,
        createdAt: at ?? DateTime.now(),
      ));
    }
    if (changed.isEmpty) return;
    await isar.products.putAll([for (final id in changed) products[id]!]);
    await isar.stockMovements.putAll(movements);
  }

  Future<String> generateOrderNumber() async {
    final isar = await ref.read(isarProvider.future);
    final count = await isar.orders.count();
    final num = (count + 1).toString().padLeft(3, '0');
    return 'ORD-$num';
  }

  Future<int> createOrder(Order order) async {
    final isar = await ref.read(isarProvider.future);
    int newId = 0;
    try {
      await isar.writeTxn(() async {
        newId = await isar.orders.put(order);
        if (order.amountPaid > 0) {
          await _logPayment(isar,
              order: order.copyWith(id: newId),
              amount: order.amountPaid,
              transactionId: order.transactionId,
              paidAt: order.createdAt);
        }

        if (order.orderStatus == OrderStatus.confirmed) {
          await _moveStock(isar, order.items,
              sign: -1,
              type: StockMovementType.sale,
              reason: 'Order ${order.orderNumber}',
              at: order.createdAt);
        }

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
      state = const AsyncValue.data(null);
      return newId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateOrder(Order order) async {
    final isar = await ref.read(isarProvider.future);
    try {
      await isar.writeTxn(() async {
        final stored = await isar.orders.get(order.id);
        var updated = order;
        if (stored != null) {
          final from = stored.createdAt;
          final to = order.createdAt;
          if (from != null && to != null && from != to) {
            await _moveOrderDate(isar, stored, from, to);
          }
          if (stored.orderStatus != order.orderStatus) {
            updated = await _changeStatus(isar, order,
                from: stored.orderStatus, to: order.orderStatus);
          }
        }
        await isar.orders.put(updated.copyWith(updatedAt: DateTime.now()));
      });
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> _moveOrderDate(
      Isar isar, Order stored, DateTime from, DateTime to) async {
    final windowEnd = from.add(_atSaleWindow);
    bool atSale(DateTime? t) =>
        t != null && !t.isBefore(from) && !t.isAfter(windowEnd);

    DateTime? latest;
    void bound(DateTime? t) {
      if (t != null && (latest == null || t.isBefore(latest!))) latest = t;
    }

    final payments =
        (await isar.payments.where().orderIdEqualTo(stored.id).findAll())
          ..sort((a, b) => a.id.compareTo(b.id));
    final moved = <Payment>[];
    for (final p in payments) {
      if (identical(p, payments.first) &&
          p.amount > 0 &&
          p.groupId.isEmpty &&
          atSale(p.paidAt)) {
        moved.add(p.copyWith(paidAt: to));
      } else {
        bound(p.paidAt);
      }
    }
    final returns = await isar.orders
        .filter()
        .isReturnEqualTo(true)
        .originalOrderIdEqualTo(stored.id)
        .findAll();
    for (final r in returns) {
      bound(r.createdAt);
    }
    bound(stored.actualDeliveryDate);
    final limit = latest;
    if (limit != null && to.isAfter(limit)) throw OrderDateTooLate(limit);

    final sales = await isar.stockMovements
        .where()
        .createdAtBetween(from, windowEnd)
        .filter()
        .typeEqualTo(StockMovementType.sale)
        .reasonEqualTo('Order ${stored.orderNumber}')
        .findAll();
    await isar.payments.putAll(moved);
    await isar.stockMovements
        .putAll([for (final m in sales) m.copyWith(createdAt: to)]);
  }

  Future<void> updateStatus(int orderId, OrderStatus status) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final order = await isar.orders.get(orderId);
        if (order == null || order.orderStatus == status) return;
        final updated =
            await _changeStatus(isar, order, from: order.orderStatus, to: status);
        await isar.orders.put(updated.copyWith(updatedAt: DateTime.now()));
      });
    });
  }

  Future<Order> _changeStatus(Isar isar, Order order,
      {required OrderStatus from, required OrderStatus to}) async {
    final wasStockDeducted =
        from != OrderStatus.pending && from != OrderStatus.cancelled;
    final shouldDeductStock =
        to != OrderStatus.pending && to != OrderStatus.cancelled;

    if (wasStockDeducted && !shouldDeductStock) {
      await _moveStock(isar, order.items,
          sign: 1,
          type: StockMovementType.adjustment,
          reason: 'Rollback ${order.orderNumber} → ${to.name}');
    }

    if (!wasStockDeducted && shouldDeductStock) {
      await _moveStock(isar, order.items,
          sign: -1,
          type: StockMovementType.sale,
          reason: 'Order ${order.orderNumber}');
    }

    var cancelledOrder = order;
    if (from != OrderStatus.cancelled && to == OrderStatus.cancelled) {
      if (order.customerId > 0) {
        final customer = await isar.customers.get(order.customerId);
        if (customer != null) {

          await isar.customers.put(customer.copyWith(
            totalOrders: (customer.totalOrders - 1).clamp(0, 999999),
            totalSpent: (customer.totalSpent - order.totalAmount)
                .clamp(0, double.infinity),
            outstandingBalance:
                (customer.outstandingBalance - order.balanceDue)
                    .clamp(0, double.infinity),
          ));
        }
      }
      if (order.amountPaid > 0) {
        await _logPayment(isar,
            order: order, amount: -order.amountPaid, note: kCancelledPaymentNote);
      }
      cancelledOrder = order.copyWith(
        amountPaid: 0,
        paymentStatus: PaymentStatus.unpaid,
      );
    }

    return cancelledOrder.copyWith(orderStatus: to);
  }

  Future<void> recordPayment(
    int orderId,
    double paymentAmount, {
    PaymentMethod? method,
    String transactionId = '',
    DateTime? paidAt,
  }) async {
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
          paymentMethod: method ?? order.paymentMethod,

          transactionId:
              transactionId.isNotEmpty ? transactionId : order.transactionId,
          updatedAt: DateTime.now(),
        ));
        await _logPayment(isar,
            order: order,
            amount: paymentAmount,
            method: method,
            transactionId: transactionId,
            paidAt: paidAt);

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

  Future<double> collectFromCustomer(
    int customerId,
    double amount, {
    PaymentMethod method = PaymentMethod.cash,
    String transactionId = '',
    String note = '',
    int? registerId,
    DateTime? paidAt,
  }) async {
    var applied = 0.0;
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {

        final orders = (await isar.orders
            .where()
            .customerIdEqualTo(customerId)
            .findAll())
          ..sort((a, b) => a.id.compareTo(b.id));
        final groupId = 'col-${DateTime.now().microsecondsSinceEpoch}';

        final dues = duesOpenAt(computeOrderDues(orders), paidAt);
        var remaining = amount.clamp(0.0, collectableDue(orders, dues, paidAt));

        final paidOrders = <Order>[];
        final payments = <Payment>[];
        for (final d in dues) {
          if (remaining <= kDueEpsilon) break;
          final part = remaining < d.due ? remaining : d.due;
          final newPaid = d.order.amountPaid + part;
          paidOrders.add(d.order.copyWith(
            amountPaid: newPaid,

            paymentStatus: newPaid >= d.order.totalAmount - kDueEpsilon
                ? PaymentStatus.paid
                : PaymentStatus.partial,
            paymentMethod: method,
            transactionId: transactionId.isNotEmpty
                ? transactionId
                : d.order.transactionId,
            updatedAt: DateTime.now(),
          ));
          payments.add(_paymentRow(
              order: d.order,
              amount: part,
              method: method,
              transactionId: transactionId,
              note: note,
              groupId: groupId,
              paidAt: paidAt));
          remaining -= part;
          applied += part;
        }
        if (paidOrders.isNotEmpty) {
          await isar.orders.putAll(paidOrders);
          await isar.payments.putAll(payments);
        }
        if (applied <= 0) return;

        final customer = await isar.customers.get(customerId);
        if (customer != null) {
          await isar.customers.put(customer.copyWith(
            outstandingBalance: (customer.outstandingBalance - applied)
                .clamp(0, double.infinity),
          ));
        }

        if (registerId != null) {
          final register = await isar.cashRegisters.get(registerId);
          if (register != null &&
              !register.isClosed &&
              register.takesCashAt(paidAt)) {
            await isar.cashRegisters.put(register.copyWith(
              totalCashIn: register.totalCashIn + applied,
            ));
          }
        }
      });
    });
    if (state.hasError) {
      throw state.error!;
    }
    return applied;
  }

  Future<void> createReturnOrder({
    required Order originalOrder,
    required List<OrderItem> returnItems,
    required ReturnReason reason,
    required double refundAmount,
    String returnNotes = '',
  }) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final count = await isar.orders.count();
        final num = (count + 1).toString().padLeft(3, '0');
        final returnOrderNumber = 'RET-$num';

        final original =
            await isar.orders.get(originalOrder.id) ?? originalOrder;

        final value = returnValueFor(original, returnItems);

        final returnOrder = Order(
          orderNumber: returnOrderNumber,
          customerId: original.customerId,
          customerName: original.customerName,
          customerPhone: original.customerPhone,
          items: returnItems,
          subtotal: value.subtotal,
          discountAmount: value.discount,
          taxAmount: value.tax,
          totalAmount: value.total,
          refundAmount: refundAmount,
          amountPaid: 0,
          paymentStatus: PaymentStatus.unpaid,
          paymentMethod: original.paymentMethod,
          orderStatus: OrderStatus.pending,
          isReturn: true,
          originalOrderId: original.id,
          returnStatus: ReturnStatus.requested,
          returnReason: reason,
          returnNotes: returnNotes,
          notes: 'Return for ${original.orderNumber}',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await isar.orders.putAll([
          returnOrder,
          original.copyWith(
            returnStatus: ReturnStatus.requested,
            updatedAt: DateTime.now(),
          ),
        ]);
      });
    });
  }

  Future<void> approveReturn(int returnOrderId) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final returnOrder = await isar.orders.get(returnOrderId);
        if (returnOrder == null || !returnOrder.isReturn) return;
        if (returnOrder.returnStatus != ReturnStatus.requested) return;

        await isar.orders.put(returnOrder.copyWith(
          returnStatus: ReturnStatus.received,
          updatedAt: DateTime.now(),
        ));

        await _moveStock(isar, returnOrder.items,
            sign: 1,
            type: StockMovementType.restock,
            reason: 'Return ${returnOrder.orderNumber}');

        if (returnOrder.originalOrderId > 0) {
          final original =
              await isar.orders.get(returnOrder.originalOrderId);
          if (original != null) {
            await isar.orders.put(original.copyWith(
              returnStatus: ReturnStatus.received,
              updatedAt: DateTime.now(),
            ));
          }
        }
      });
    });
  }

  Future<void> rejectReturn(int returnOrderId) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final returnOrder = await isar.orders.get(returnOrderId);
        if (returnOrder == null || !returnOrder.isReturn) return;

        await isar.orders.put(returnOrder.copyWith(
          returnStatus: ReturnStatus.rejected,
          orderStatus: OrderStatus.cancelled,
          updatedAt: DateTime.now(),
        ));

        if (returnOrder.originalOrderId > 0) {
          final original =
              await isar.orders.get(returnOrder.originalOrderId);
          if (original != null) {
            await isar.orders.put(original.copyWith(
              returnStatus: ReturnStatus.none,
              updatedAt: DateTime.now(),
            ));
          }
        }
      });
    });
  }

  Future<void> processRefund(
    int returnOrderId, {
    PaymentMethod? refundMethod,
    String refundTransactionId = '',
  }) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final returnOrder = await isar.orders.get(returnOrderId);
        if (returnOrder == null || !returnOrder.isReturn) return;
        if (returnOrder.returnStatus != ReturnStatus.received) return;

        final original = returnOrder.originalOrderId > 0
            ? await isar.orders.get(returnOrder.originalOrderId)
            : null;

        final maxRefundable = original?.amountPaid ?? returnOrder.refundAmount;
        final actualRefund =
            returnOrder.refundAmount.clamp(0.0, maxRefundable);

        final updatedOrders = [
          returnOrder.copyWith(
            refundAmount: actualRefund,
            amountPaid: actualRefund,
            paymentStatus: PaymentStatus.paid,
            paymentMethod: refundMethod ?? returnOrder.paymentMethod,
            transactionId: refundTransactionId.isNotEmpty
                ? refundTransactionId
                : returnOrder.transactionId,
            returnStatus: ReturnStatus.refunded,
            orderStatus: OrderStatus.completed,
            updatedAt: DateTime.now(),
          ),
        ];
        if (original != null) {
          final newAmountPaid =
              (original.amountPaid - actualRefund).clamp(0.0, double.infinity);
          final newPaymentStatus = newAmountPaid >= original.totalAmount
              ? PaymentStatus.paid
              : newAmountPaid > 0
                  ? PaymentStatus.partial
                  : PaymentStatus.unpaid;
          updatedOrders.add(original.copyWith(
            amountPaid: newAmountPaid,
            paymentStatus: newPaymentStatus,
            returnStatus: ReturnStatus.refunded,
            updatedAt: DateTime.now(),
          ));
        }
        await isar.orders.putAll(updatedOrders);

        if (original != null && actualRefund > 0) {
          await _logPayment(isar,
              order: original,
              amount: -actualRefund,
              method: refundMethod,
              transactionId: refundTransactionId,
              note: 'refund ${returnOrder.orderNumber}');
        }

        if (returnOrder.customerId > 0) {
          final customer =
              await isar.customers.get(returnOrder.customerId);
          if (customer != null) {
            final balanceChange = returnOrder.totalAmount - actualRefund;
            await isar.customers.put(customer.copyWith(
              totalSpent: (customer.totalSpent - returnOrder.totalAmount)
                  .clamp(0, double.infinity),
              outstandingBalance:
                  (customer.outstandingBalance - balanceChange)
                      .clamp(0, double.infinity),
            ));
          }
        }
      });
    });
  }

  Future<void> processRecurringOrders() async {
    final isar = await ref.read(isarProvider.future);
    final now = DateTime.now();

    final recurringOrders = await isar.orders
        .filter()
        .isRecurringEqualTo(true)
        .not()
        .orderStatusEqualTo(OrderStatus.cancelled)
        .findAll();

    final due = recurringOrders
        .where((o) =>
            o.nextRecurringDate != null && o.nextRecurringDate!.isBefore(now))
        .toList();
    if (due.isEmpty) return;

    await isar.writeTxn(() async {
      var count = await isar.orders.count();
      final customers = <int, Customer>{};
      final customerIds = {
        for (final o in due)
          if (o.customerId > 0) o.customerId,
      }.toList();
      for (final c in await isar.customers.getAll(customerIds)) {
        if (c != null) customers[c.id] = c;
      }
      final billed = <int>{};
      final writes = <Order>[];

      for (final order in due) {

        count++;
        final num = count.toString().padLeft(3, '0');

        final newOrder = order.copyWith(
          id: Isar.autoIncrement,
          orderNumber: 'ORD-$num',
          orderStatus: OrderStatus.pending,
          paymentStatus: PaymentStatus.unpaid,
          amountPaid: 0,
          createdAt: now,
          updatedAt: now,
          nextRecurringDate:
              now.add(Duration(days: order.recurringIntervalDays)),
        );
        writes.add(newOrder);

        if (newOrder.customerId > 0) {
          final customer = customers[newOrder.customerId];
          if (customer != null) {
            customers[newOrder.customerId] = customer.copyWith(
              totalOrders: customer.totalOrders + 1,
              totalSpent: customer.totalSpent + newOrder.totalAmount,
              outstandingBalance:
                  customer.outstandingBalance + newOrder.totalAmount,
            );
            billed.add(newOrder.customerId);
          }
        }

        writes.add(order.copyWith(
          nextRecurringDate:
              now.add(Duration(days: order.recurringIntervalDays)),
          updatedAt: now,
        ));
      }

      await isar.orders.putAll(writes);
      if (billed.isNotEmpty) {
        await isar.customers.putAll([for (final id in billed) customers[id]!]);
      }
    });
  }

  Future<void> deleteOrder(int id) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final order = await isar.orders.get(id);
        if (order == null) return;

        final wasStockDeducted =
            order.orderStatus != OrderStatus.pending &&
            order.orderStatus != OrderStatus.cancelled;
        if (wasStockDeducted) {
          await _moveStock(isar, order.items,
              sign: 1,
              type: StockMovementType.adjustment,
              reason: 'Deleted order ${order.orderNumber}');
        }

        if (order.customerId > 0) {
          final customer = await isar.customers.get(order.customerId);
          if (customer != null) {
            await isar.customers.put(customer.copyWith(
              totalOrders: (customer.totalOrders - 1).clamp(0, 999999),
              totalSpent: (customer.totalSpent - order.totalAmount)
                  .clamp(0, double.infinity),
              outstandingBalance:
                  (customer.outstandingBalance - order.balanceDue)
                      .clamp(0, double.infinity),
            ));
          }
        }

        await isar.payments.filter().orderIdEqualTo(id).deleteAll();
        await isar.orders.delete(id);
      });
    });
  }
}
