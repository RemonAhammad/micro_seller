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

/// Every order newest first, read in createdAt-index order (no sort) on a
/// worker isolate.
List<Order> _allOrdersNewestFirst(Isar db) =>
    db.orders.where(sort: Sort.desc).anyCreatedAt().findAllSync();

/// Return orders only, newest first — the Returns screen's list, without
/// loading every order to filter them.
@riverpod
Stream<List<Order>> returnOrders(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  final query =
      isar.orders.filter().isReturnEqualTo(true).sortByCreatedAtDesc();
  yield* reloadOn(isar.orders.watchLazy(), query.findAll);
}

/// One order, live — without reloading every order on each write.
@riverpod
Stream<Order?> orderById(Ref ref, int id) async* {
  final isar = await ref.watch(isarProvider.future);
  yield isar.orders.getSync(id);
  // No fireImmediately: the current value was just yielded above.
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

@Riverpod(keepAlive: true)
class OrderNotifier extends _$OrderNotifier {
  @override
  FutureOr<void> build() {}

  /// Update variant combination stockQty within a product.
  /// Returns the updated product (not yet persisted).
  Product _adjustVariantStock(Product product, OrderItem item, int delta) {
    if (!item.hasVariant) return product;

    // Use combinationKey if available (new system), fallback to old name:value
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

  /// Appends one row to the payment history. Call inside the caller's
  /// writeTxn so the log and the `amountPaid` change can't diverge.
  Future<void> _logPayment(
    Isar isar, {
    required Order order,
    required double amount,
    PaymentMethod? method,
    String transactionId = '',
    String note = '',
    String groupId = '',
  }) async {
    await isar.payments.put(_paymentRow(
      order: order,
      amount: amount,
      method: method,
      transactionId: transactionId,
      note: note,
      groupId: groupId,
    ));
  }

  /// The payment-history row [_logPayment] writes, for callers that log
  /// several in one `putAll`.
  Payment _paymentRow({
    required Order order,
    required double amount,
    PaymentMethod? method,
    String transactionId = '',
    String note = '',
    String groupId = '',
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
      paidAt: now,
      createdAt: now,
    );
  }

  /// Moves each item's qty in or out of stock — `sign` -1 deducts (sale),
  /// +1 restores — on both the product's base `stockQty` and the item's
  /// variant combination, with one [StockMovement] per item. Call inside the
  /// caller's writeTxn.
  ///
  /// Batched: the products are read with one `getAll` and written with one
  /// `putAll`, the movements with another `putAll` — instead of a get + put
  /// + put per item, each a round trip to Isar's thread. Items are applied
  /// in order to the in-memory product, so two items of one product (e.g.
  /// two variants) compose exactly as the sequential get → put did. Items
  /// whose product no longer exists are skipped, movement included.
  Future<void> _moveStock(
    Isar isar,
    List<OrderItem> items, {
    required int sign,
    required StockMovementType type,
    required String reason,
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
        createdAt: DateTime.now(),
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
              transactionId: order.transactionId);
        }

        // Deduct stock and create movements for confirmed orders
        if (order.orderStatus == OrderStatus.confirmed) {
          await _moveStock(isar, order.items,
              sign: -1,
              type: StockMovementType.sale,
              reason: 'Order ${order.orderNumber}');
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
      state = const AsyncValue.data(null);
      return newId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
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
          await _moveStock(isar, order.items,
              sign: 1,
              type: StockMovementType.adjustment,
              reason: 'Rollback ${order.orderNumber} → ${status.name}');
        }

        // Deduct stock when moving from pending/cancelled to active status
        if (!wasStockDeducted && shouldDeductStock) {
          await _moveStock(isar, order.items,
              sign: -1,
              type: StockMovementType.sale,
              reason: 'Order ${order.orderNumber}');
        }

        // Cancel-into transition: reverse the customer ledger fully and zero
        // out amountPaid (treats cancel as auto-refund — micro-seller context).
        // The opposite (un-cancel) is intentionally NOT supported here; the
        // user would have to recreate the order to re-bill.
        var cancelledOrder = order;
        if (oldStatus != OrderStatus.cancelled &&
            status == OrderStatus.cancelled) {
          if (order.customerId > 0) {
            final customer = await isar.customers.get(order.customerId);
            if (customer != null) {
              // createOrder added: totalOrders+1, totalSpent+totalAmount,
              // outstandingBalance + balanceDue. Reverse all three exactly.
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

        await isar.orders.put(cancelledOrder.copyWith(
          orderStatus: status,
          updatedAt: DateTime.now(),
        ));
      });
    });
  }

  Future<void> recordPayment(
    int orderId,
    double paymentAmount, {
    PaymentMethod? method,
    String transactionId = '',
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
          // Only overwrite transactionId if a new one was supplied — empty
          // string preserves the previous value. Every payment's own id is
          // kept in the Payment history row logged below.
          transactionId:
              transactionId.isNotEmpty ? transactionId : order.transactionId,
          updatedAt: DateTime.now(),
        ));
        await _logPayment(isar,
            order: order,
            amount: paymentAmount,
            method: method,
            transactionId: transactionId);

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

  /// Due Book collection: one payment from a customer, applied to their
  /// unpaid orders oldest-first. Capped at what they owe (no advance credit).
  ///
  /// If [registerId] is given (an open cash register), the applied amount is
  /// also added to that register's cash-in, in the same transaction.
  /// Returns the amount actually applied (may be less than [amount] if the
  /// dues changed since the caller read them).
  Future<double> collectFromCustomer(
    int customerId,
    double amount, {
    PaymentMethod method = PaymentMethod.cash,
    String transactionId = '',
    String note = '',
    int? registerId,
  }) async {
    var applied = 0.0;
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        // Index lookups don't return equal keys in id order; sort so the
        // dues are summed and allocated in the same order as the Due Book.
        final orders = (await isar.orders
            .where()
            .customerIdEqualTo(customerId)
            .findAll())
          ..sort((a, b) => a.id.compareTo(b.id));
        final groupId = 'col-${DateTime.now().microsecondsSinceEpoch}';
        // Never collect more than the net due — credits on other orders
        // (over-valued exchange returns) reduce what's actually owed.
        var remaining = amount.clamp(0.0, computeNetDue(orders));

        // Each due order is a distinct row, so the updates and their
        // payment rows are collected and written with one putAll each.
        final paidOrders = <Order>[];
        final payments = <Payment>[];
        for (final d in computeOrderDues(orders)) {
          if (remaining <= kDueEpsilon) break;
          final part = remaining < d.due ? remaining : d.due;
          final newPaid = d.order.amountPaid + part;
          paidOrders.add(d.order.copyWith(
            amountPaid: newPaid,
            // Same rule as recordPayment/processRefund, so status and the
            // order's displayed balanceDue never disagree.
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
              groupId: groupId));
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
          if (register != null && !register.isClosed) {
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

  // ─── Return Flow (3-step: Request → Approve/Receive → Refund) ─────────

  /// Step 1: Create a return order with selected items, reason, and refund amount.
  /// Stock is NOT restored here. Original order is marked.
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

        // The screen's copy may be stale; value and mark the stored order.
        final original =
            await isar.orders.get(originalOrder.id) ?? originalOrder;

        // Valued at what the customer paid for these goods — their share of
        // the order discount off, their share of the tax on — not list
        // price. A list-price value credited the customer the discount.
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

        // Save the return and mark the original as having one — one putAll,
        // in the same order the two puts ran.
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

  /// Step 2: Approve return and receive items back → restores stock.
  Future<void> approveReturn(int returnOrderId) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        final returnOrder = await isar.orders.get(returnOrderId);
        if (returnOrder == null || !returnOrder.isReturn) return;
        if (returnOrder.returnStatus != ReturnStatus.requested) return;

        // Mark as received
        await isar.orders.put(returnOrder.copyWith(
          returnStatus: ReturnStatus.received,
          updatedAt: DateTime.now(),
        ));

        // Restore stock for returned items
        await _moveStock(isar, returnOrder.items,
            sign: 1,
            type: StockMovementType.restock,
            reason: 'Return ${returnOrder.orderNumber}');

        // Update original order
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

  /// Reject a return request.
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

        // Reset original order's return status
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

  /// Step 3: Process refund. Considers partial payment on original order.
  /// refundAmount = min(requested refund, what customer actually paid on original).
  ///
  /// [refundMethod] is how the cash is going back to the customer (cash / bKash
  /// / etc.); stored on the return order's `paymentMethod` field.
  /// [refundTransactionId] is the receipt/reference for the refund payout.
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

        // Get original order to check what was actually paid
        final original = returnOrder.originalOrderId > 0
            ? await isar.orders.get(returnOrder.originalOrderId)
            : null;

        // Actual refund = min(requested refund, original amountPaid)
        // If original had partial payment, can't refund more than paid
        final maxRefundable = original?.amountPaid ?? returnOrder.refundAmount;
        final actualRefund =
            returnOrder.refundAmount.clamp(0.0, maxRefundable);

        // Mark return as refunded, and update the original order — reduce
        // amountPaid by refund. Both rows were read above and nothing reads
        // between the two writes, so one putAll (same order) replaces them.
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

        // Update customer stats.
        //
        // - totalSpent decreases by the BILLED value of returned goods
        //   (returnOrder.totalAmount) — symmetric with createOrder which adds
        //   `order.totalAmount`. This makes totalSpent stable across exchange
        //   ($0 refund), partial refund, and full cash refund: all three end
        //   with totalSpent = lifetime value of goods the customer kept.
        //
        // - outstandingBalance decreases by (returnedItemsValue - actualRefund):
        //   the customer no longer owes for the returned items, but they did
        //   get back the refund cash, so the net debt reduction is the
        //   difference. For a 1:1 cash refund this is zero (kept-goods debt
        //   matches kept-goods value); for an exchange (refund=0) it's the
        //   full goods value (customer's debt drops by what they returned).
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

    // One transaction for every due copy (it used to be one each), batched:
    // the order count is read once and advanced locally — each copy adds
    // exactly one order, so the numbers match what a fresh count per copy
    // gave — and a customer with several due orders composes on one map
    // entry, as the sequential get → put did.
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
        // Generate new order number
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

        // Bill the customer exactly as createOrder would — this path used
        // to skip it, so the outstandingBalance counter drifted.
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

        // Update the original order's next date
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

        // Restore stock if order had stock deducted
        final wasStockDeducted =
            order.orderStatus != OrderStatus.pending &&
            order.orderStatus != OrderStatus.cancelled;
        if (wasStockDeducted) {
          await _moveStock(isar, order.items,
              sign: 1,
              type: StockMovementType.adjustment,
              reason: 'Deleted order ${order.orderNumber}');
        }

        // Restore customer stats
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
