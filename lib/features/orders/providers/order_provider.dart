import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_item.dart';
import '../../../data/models/product.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/services/isar_service.dart';

part 'order_provider.g.dart';

@riverpod
Stream<List<Order>> orders(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.orders
      .where()
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);
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

@riverpod
Stream<List<Order>> unpaidOrders(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.orders
      .filter()
      .paymentStatusEqualTo(PaymentStatus.unpaid)
      .or()
      .paymentStatusEqualTo(PaymentStatus.partial)
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

        // Deduct stock and create movements for confirmed orders
        if (order.orderStatus == OrderStatus.confirmed) {
          for (final item in order.items) {
            final product = await isar.products.get(item.productId);
            if (product != null) {
              var updated = product.copyWith(
                stockQty: product.stockQty - item.qty,
                updatedAt: DateTime.now(),
              );
              updated = _adjustVariantStock(updated, item, -item.qty);
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
          for (final item in order.items) {
            final product = await isar.products.get(item.productId);
            if (product != null) {
              var updated = product.copyWith(
                stockQty: product.stockQty + item.qty,
                updatedAt: DateTime.now(),
              );
              updated = _adjustVariantStock(updated, item, item.qty);
              await isar.products.put(updated);
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
              var updated = product.copyWith(
                stockQty: product.stockQty - item.qty,
                updatedAt: DateTime.now(),
              );
              updated = _adjustVariantStock(updated, item, -item.qty);
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
          // string preserves the previous value (audit trail across multiple
          // partial payments still loses earlier IDs; consider a Payment
          // entity if that becomes a real requirement).
          transactionId:
              transactionId.isNotEmpty ? transactionId : order.transactionId,
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

        final returnTotal =
            returnItems.fold<double>(0.0, (s, item) => s + item.totalPrice);

        final returnOrder = Order(
          orderNumber: returnOrderNumber,
          customerId: originalOrder.customerId,
          customerName: originalOrder.customerName,
          customerPhone: originalOrder.customerPhone,
          items: returnItems,
          subtotal: returnTotal,
          totalAmount: returnTotal,
          refundAmount: refundAmount,
          amountPaid: 0,
          paymentStatus: PaymentStatus.unpaid,
          paymentMethod: originalOrder.paymentMethod,
          orderStatus: OrderStatus.pending,
          isReturn: true,
          originalOrderId: originalOrder.id,
          returnStatus: ReturnStatus.requested,
          returnReason: reason,
          returnNotes: returnNotes,
          notes: 'Return for ${originalOrder.orderNumber}',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await isar.orders.put(returnOrder);

        // Mark original order as having a return
        await isar.orders.put(originalOrder.copyWith(
          returnStatus: ReturnStatus.requested,
          updatedAt: DateTime.now(),
        ));
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
        for (final item in returnOrder.items) {
          final product = await isar.products.get(item.productId);
          if (product != null) {
            var updated = product.copyWith(
              stockQty: product.stockQty + item.qty,
              updatedAt: DateTime.now(),
            );
            updated = _adjustVariantStock(updated, item, item.qty);
            await isar.products.put(updated);
            await isar.stockMovements.put(StockMovement(
              productId: item.productId,
              productName: item.productName,
              type: StockMovementType.restock,
              qty: item.qty,
              reason: 'Return ${returnOrder.orderNumber}',
              createdAt: DateTime.now(),
            ));
          }
        }

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

        // Mark return as refunded
        await isar.orders.put(returnOrder.copyWith(
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
        ));

        // Update original order — reduce amountPaid by refund
        if (original != null) {
          final newAmountPaid =
              (original.amountPaid - actualRefund).clamp(0.0, double.infinity);
          final newPaymentStatus = newAmountPaid >= original.totalAmount
              ? PaymentStatus.paid
              : newAmountPaid > 0
                  ? PaymentStatus.partial
                  : PaymentStatus.unpaid;
          await isar.orders.put(original.copyWith(
            amountPaid: newAmountPaid,
            paymentStatus: newPaymentStatus,
            returnStatus: ReturnStatus.refunded,
            updatedAt: DateTime.now(),
          ));
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

    for (final order in recurringOrders) {
      if (order.nextRecurringDate != null &&
          order.nextRecurringDate!.isBefore(now)) {
        await isar.writeTxn(() async {
          // Generate new order number
          final count = await isar.orders.count();
          final num = (count + 1).toString().padLeft(3, '0');

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
          await isar.orders.put(newOrder);

          // Update the original order's next date
          await isar.orders.put(order.copyWith(
            nextRecurringDate:
                now.add(Duration(days: order.recurringIntervalDays)),
            updatedAt: now,
          ));
        });
      }
    }
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
          for (final item in order.items) {
            final product = await isar.products.get(item.productId);
            if (product != null) {
              var updated = product.copyWith(
                stockQty: product.stockQty + item.qty,
                updatedAt: DateTime.now(),
              );
              updated = _adjustVariantStock(updated, item, item.qty);
              await isar.products.put(updated);
              await isar.stockMovements.put(StockMovement(
                productId: item.productId,
                productName: item.productName,
                type: StockMovementType.adjustment,
                qty: item.qty,
                reason: 'Deleted order ${order.orderNumber}',
                createdAt: DateTime.now(),
              ));
            }
          }
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

        await isar.orders.delete(id);
      });
    });
  }
}
