import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/data/models/cash_register.dart';
import 'package:micro_seller/data/models/expense.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/purchase.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/models/supplier.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/report_service.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';

final start = DateTime(2026, 9, 1);
final end = DateTime(2026, 10, 1);

OrderItem _item(int productId, int qty, double price, {double cost = 0}) =>
    OrderItem(
      productId: productId,
      productName: 'P$productId',
      qty: qty,
      unitPrice: price,
      costPrice: cost,
      totalPrice: qty * price,
    );

Order _sale(int id, List<OrderItem> items,
        {int day = 10,
        double paid = 0,
        OrderStatus status = OrderStatus.completed,
        PaymentMethod method = PaymentMethod.cash}) =>
    Order(
      id: id,
      orderNumber: 'ORD-$id',
      customerId: 1,
      customerName: 'Rahim',
      items: items,
      totalAmount: items.fold(0, (s, i) => s + i.totalPrice),
      amountPaid: paid,
      orderStatus: status,
      paymentMethod: method,
      createdAt: DateTime(2026, 9, day),
    );

void main() {
  final products = {
    1: Product(id: 1, name: 'P1', sellingPrice: 100, costPrice: 60, category: 'Tea'),
    2: Product(id: 2, name: 'P2', sellingPrice: 50, costPrice: 20),
  };

  group('buildSalesReport', () {
    test('returns lower net sales and profit; cancelled ignored', () {
      final r = buildSalesReport(
        orders: [
          _sale(1, [_item(1, 2, 100, cost: 60)]), // 200, cost 120
          _sale(2, [_item(2, 1, 50)], status: OrderStatus.cancelled),
          Order(
            id: 3,
            isReturn: true,
            originalOrderId: 1,
            returnStatus: ReturnStatus.refunded,
            items: [_item(1, 1, 100, cost: 60)],
            totalAmount: 100,
            updatedAt: DateTime(2026, 9, 12),
          ),
        ],
        productsById: products,
        expenses: [Expense(title: 'Box', amount: 10, date: DateTime(2026, 9, 5))],
        start: start,
        end: end,
      );
      expect(r.grossSales, 200);
      expect(r.returnsValue, 100);
      expect(r.netSales, 100);
      expect(r.cogs, 60); // 120 sold − 60 returned
      expect(r.grossProfit, 40);
      expect(r.netProfit, 30);
      expect(r.orderCount, 1);
      expect(r.byCategory, {'Tea': 200});
    });

    test('zero frozen cost falls back to the product cost', () {
      final r = buildSalesReport(
        orders: [_sale(1, [_item(2, 3, 50)])], // item cost 0 → product 20
        productsById: products,
        expenses: const [],
        start: start,
        end: end,
      );
      expect(r.cogs, 60);
    });

    test('payment method split sums to gross sales; daily series fills range', () {
      final r = buildSalesReport(
        orders: [
          _sale(1, [_item(1, 1, 100)], method: PaymentMethod.cash),
          _sale(2, [_item(2, 2, 50)], method: PaymentMethod.mfs, day: 11),
        ],
        productsById: products,
        expenses: const [],
        start: start,
        end: end,
      );
      expect(r.byPaymentMethod.values.fold<double>(0, (s, v) => s + v), r.grossSales);
      expect(r.series.length, 30);
      expect(r.seriesByMonth, isFalse);
    });

    test('orders outside the range are excluded', () {
      final r = buildSalesReport(
        orders: [
          Order(id: 9, items: [_item(1, 1, 100)], totalAmount: 100, createdAt: DateTime(2026, 8, 31)),
        ],
        productsById: products,
        expenses: const [],
        start: start,
        end: end,
      );
      expect(r.grossSales, 0);
    });
  });

  group('buildDuesReport', () {
    test('credit given, collections by method, refunds', () {
      final o1 = _sale(1, [_item(1, 10, 100)], paid: 300); // 1000, 300 at sale
      final old = Order(
          id: 2, customerId: 1, totalAmount: 500, createdAt: DateTime(2026, 8, 1));
      final payments = [
        Payment(orderId: 1, amount: 300, method: PaymentMethod.cash, paidAt: DateTime(2026, 9, 10)),
        Payment(orderId: 2, amount: 200, method: PaymentMethod.mfs, paidAt: DateTime(2026, 9, 15)),
        Payment(orderId: 1, amount: -50, paidAt: DateTime(2026, 9, 20)),
      ];
      final r = buildDuesReport(
        payments: payments,
        ordersById: {1: o1, 2: old},
        ordersInPeriod: [o1],
        dues: const <CustomerDue>[],
        start: start,
        end: end,
      );
      expect(r.creditGiven, 700);
      expect(r.collectedByMethod[PaymentMethod.cash], 300);
      expect(r.collectedByMethod[PaymentMethod.mfs], 200);
      expect(r.totalCollected, 500);
      expect(r.duesCollected, 200); // only the later payment on the old order
      expect(r.refundsPaid, 50);
    });

    test('legacy order without payment rows uses amountPaid', () {
      final o = _sale(1, [_item(1, 5, 100)], paid: 100);
      final r = buildDuesReport(
        payments: const [],
        ordersById: {1: o},
        ordersInPeriod: [o],
        dues: const [],
        start: start,
        end: end,
      );
      expect(r.creditGiven, 400);
    });
  });

  group('buildInventoryReport', () {
    test('stock value, slow movers, returns by reason, movements', () {
      final prods = [
        Product(id: 1, name: 'P1', sellingPrice: 100, costPrice: 60, stockQty: 5),
        Product(id: 2, name: 'P2', sellingPrice: 50, costPrice: 20, stockQty: 4),
        Product(id: 3, name: 'Gone', sellingPrice: 10, stockQty: 9, isActive: false),
      ];
      final r = buildInventoryReport(
        products: prods,
        movements: [
          StockMovement(productId: 1, type: StockMovementType.sale, qty: -2, createdAt: DateTime(2026, 9, 10)),
          StockMovement(productId: 2, type: StockMovementType.damage, qty: -1, createdAt: DateTime(2026, 9, 11)),
        ],
        orders: [
          _sale(1, [_item(1, 2, 100)]),
          Order(
            id: 2,
            isReturn: true,
            returnStatus: ReturnStatus.refunded,
            returnReason: ReturnReason.defective,
            totalAmount: 100,
            refundAmount: 80,
            updatedAt: DateTime(2026, 9, 20),
          ),
        ],
        start: start,
        end: end,
      );
      expect(r.stockValueAtCost, 5 * 60 + 4 * 20);
      expect(r.stockValueAtPrice, 5 * 100 + 4 * 50);
      expect(r.activeProducts, 2);
      expect(r.slowMovers.keys, ['P2']);
      expect(r.movementQty[StockMovementType.damage], 1);
      expect(r.returnCount, 1);
      expect(r.refunded, 80);
      expect(r.returnsByReason[ReturnReason.defective], 1);
    });
  });

  group('buildPurchasesReport', () {
    test('purchases, expenses by category, cash register over/short', () {
      final r = buildPurchasesReport(
        // Karim was paid 300 directly (not against a purchase): owes 100.
        suppliers: [Supplier(id: 7, name: 'Karim', totalDue: 100)],
        purchases: [
          Purchase(items: const [], supplierId: 7, supplierName: 'Karim', totalAmount: 1000, amountPaid: 600, createdAt: DateTime(2026, 9, 3)),
          Purchase(items: const [], totalAmount: 300, amountPaid: 100, createdAt: DateTime(2026, 7, 1)),
        ],
        expenses: [
          Expense(title: 'a', amount: 40, category: ExpenseCategory.packaging, date: DateTime(2026, 9, 2)),
          Expense(title: 'b', amount: 60, category: ExpenseCategory.logistics, date: DateTime(2026, 9, 3)),
        ],
        registers: [
          CashRegister(openingAmount: 100, totalCashIn: 500, totalCashOut: 50, closingAmount: 540, isClosed: true, closedAt: DateTime(2026, 9, 4)),
        ],
        start: start,
        end: end,
      );
      expect(r.purchaseCount, 1);
      expect(r.purchased, 1000);
      expect(r.unpaid, 400);
      expect(r.owedToSuppliersToday, 300); // Karim's balance 100 + unlinked July purchase 200
      expect(r.totalExpenses, 100);
      expect(r.registerSessions, 1);
      expect(r.overShort, -10); // expected 550, counted 540
    });
  });

  test('return against a cancelled order is not subtracted', () {
    final r = buildSalesReport(
      orders: [
        Order(
          id: 5,
          isReturn: true,
          originalOrderId: 4,
          returnStatus: ReturnStatus.refunded,
          items: [_item(1, 1, 100, cost: 60)],
          totalAmount: 100,
          updatedAt: DateTime(2026, 9, 12),
        ),
      ],
      cancelledOrderIds: {4},
      productsById: products,
      expenses: const [],
      start: start,
      end: end,
    );
    expect(r.returnsValue, 0);
    expect(r.cogs, 0);
  });

  test('cancel reversal nets out of money received, not refunds', () {
    final o = _sale(1, [_item(1, 4, 100)], status: OrderStatus.cancelled);
    final r = buildDuesReport(
      payments: [
        Payment(orderId: 1, amount: 400, method: PaymentMethod.cash, paidAt: DateTime(2026, 9, 10)),
        Payment(orderId: 1, amount: -400, method: PaymentMethod.cash, note: kCancelledPaymentNote, paidAt: DateTime(2026, 9, 11)),
      ],
      ordersById: {1: o},
      ordersInPeriod: [o],
      dues: const [],
      start: start,
      end: end,
    );
    expect(r.totalCollected, 0);
    expect(r.refundsPaid, 0);
  });

  test('money cells stay numeric for CSV; formatCell renders them', () {
    final t = buildSalesReport(
            orders: [_sale(1, [_item(1, 1, 100)])],
            productsById: products,
            expenses: const [],
            start: start,
            end: end)
        .toTables((k) => k)
        .first;
    expect(t.rows.first[1], isA<double>());
    expect(formatCell(3), '3');
  });

  test('every report exports non-empty tables', () {
    String tr(String k) => k;
    final sales = buildSalesReport(
        orders: [_sale(1, [_item(1, 1, 100)])],
        productsById: products,
        expenses: const [],
        start: start,
        end: end);
    for (final t in sales.toTables(tr)) {
      expect(t.headers, isNotEmpty);
    }
    expect(sales.toTables(tr).first.rows, isNotEmpty);
    expect(kDueEpsilon, greaterThan(0));
    expect(summarizeDues(const []).total, 0);
  });
}
