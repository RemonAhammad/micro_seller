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

/// Totalled the way the order form does: goods − discount + tax + delivery,
/// never below 0.
Order _sale(int id, List<OrderItem> items,
    {int day = 10,
    double paid = 0,
    double discount = 0,
    double tax = 0,
    double delivery = 0,
    OrderStatus status = OrderStatus.completed,
    PaymentMethod method = PaymentMethod.cash}) {
  final goods = items.fold<double>(0, (s, i) => s + i.totalPrice);
  final total = goods - discount + tax + delivery;
  return Order(
    id: id,
    orderNumber: 'ORD-$id',
    customerId: 1,
    customerName: 'Rahim',
    items: items,
    subtotal: goods,
    discountAmount: discount,
    taxAmount: tax,
    deliveryFee: delivery,
    totalAmount: total > 0 ? total : 0,
    amountPaid: paid,
    orderStatus: status,
    paymentMethod: method,
    createdAt: DateTime(2026, 9, day),
  );
}

/// A return of [items] from [original], valued the way `createReturnOrder`
/// values it.
Order _return(int id, Order original, List<OrderItem> items,
    {int day = 12, ReturnStatus status = ReturnStatus.refunded}) {
  final v = returnValueFor(original, items);
  return Order(
    id: id,
    isReturn: true,
    originalOrderId: original.id,
    returnStatus: status,
    items: items,
    subtotal: v.subtotal,
    discountAmount: v.discount,
    taxAmount: v.tax,
    totalAmount: v.total,
    updatedAt: DateTime(2026, 9, day),
  );
}

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

  group('profit after discounts, tax and delivery', () {
    SalesReport sales(List<Order> orders, {List<Expense> expenses = const []}) =>
        buildSalesReport(
          orders: orders,
          productsById: products,
          expenses: expenses,
          start: start,
          end: end,
        );

    // The Play Store review: cost ৳700, price ৳1,000, ৳100 discount. The
    // Dashboard used to show ৳300 profit (the discount ignored).
    test('a discount comes off profit', () {
      final r = sales([_sale(1, [_item(1, 1, 1000, cost: 700)], discount: 100)]);
      expect(r.grossSales, 1000);
      expect(r.discounts, 100);
      expect(r.netSales, 900);
      expect(r.cogs, 700);
      expect(r.grossProfit, 200);
      expect(r.netProfit, 200);
      expect(r.topProducts, {'P1': 900});
      expect(r.byCategory, {'Tea': 900});
    });

    test('tax is not profit; delivery counts in net profit, not gross', () {
      final o = _sale(1, [_item(1, 1, 1000, cost: 700)],
          discount: 100, tax: 45, delivery: 60);
      final r = sales([o], expenses: [
        Expense(
            title: 'Courier',
            amount: 60,
            category: ExpenseCategory.logistics,
            date: DateTime(2026, 9, 10)),
      ]);
      expect(o.totalAmount, 1005);
      expect(r.netSales, 900);
      expect(r.grossProfit, 200);
      expect(r.taxCollected, 45);
      expect(r.deliveryCharges, 60);
      expect(r.netProfit, 200); // 200 + 60 delivery − 60 courier
      expect(r.billedSales, 1005);
      expect(r.avgOrderValue, 1005);
      expect(r.byPaymentMethod.values.fold<double>(0, (s, v) => s + v),
          r.billedSales);
    });

    test('the P&L adds back up to what customers were billed', () {
      final r = sales([
        _sale(1, [_item(1, 3, 333, cost: 200)],
            discount: 50, tax: 71.18, delivery: 60),
        _sale(2, [_item(2, 2, 250, cost: 100)], tax: 75, day: 11),
        // Discount bigger than the goods: the excess comes off delivery.
        _sale(3, [_item(1, 1, 100, cost: 60)], discount: 130, delivery: 60, day: 12),
      ]);
      expect(r.grossSales - r.discounts + r.deliveryCharges + r.taxCollected,
          closeTo(r.billedSales, 1e-9));
    });

    test('full refund of a discounted, taxed order leaves profit at 0', () {
      final o = _sale(1, [_item(1, 1, 1000, cost: 700)],
          discount: 100, tax: 45, delivery: 60);
      final r = sales([o, _return(2, o, o.items)]);
      expect(r.returnsValue, 900);
      expect(r.netSales, 0);
      expect(r.cogs, 0);
      expect(r.grossProfit, 0);
      expect(r.taxCollected, 0);
      expect(r.deliveryCharges, 60); // delivery isn't refunded
      expect(r.marginPct, 0);
    });

    test('an exchange (no cash back) still takes the returned margin out', () {
      final o = _sale(1, [_item(1, 2, 500, cost: 300)], discount: 100);
      final r = sales([
        o,
        _return(2, o, [_item(1, 1, 500, cost: 300)],
            status: ReturnStatus.received),
      ]);
      expect(r.returnsValue, 450);
      expect(r.netSales, 450);
      expect(r.cogs, 300);
      expect(r.grossProfit, 150); // the kept item: 450 − 300
    });

    test('returns recorded before this fix keep their list-price value', () {
      final o = _sale(1, [_item(1, 1, 1000, cost: 700)], discount: 100);
      final legacy = Order(
        id: 2,
        isReturn: true,
        originalOrderId: 1,
        returnStatus: ReturnStatus.refunded,
        items: [_item(1, 1, 1000, cost: 700)],
        totalAmount: 1000,
        updatedAt: DateTime(2026, 9, 12),
      );
      final r = sales([o, legacy]);
      // As recorded: customer balances were settled against this value.
      expect(r.returnsValue, 1000);
      expect(r.grossProfit, -100);
    });

    test('profit per day sums to gross profit; returns land on their day', () {
      final o = _sale(1, [_item(1, 2, 500, cost: 300)], discount: 100, day: 10);
      final r = sales([o, _return(2, o, [_item(1, 1, 500, cost: 300)], day: 15)]);
      final byDay = {for (final p in r.profitSeries) p.bucket: p.value};
      expect(byDay[DateTime(2026, 9, 10)], 300); // 900 − 600
      expect(byDay[DateTime(2026, 9, 15)], -150); // −(450 − 300)
      expect(r.profitSeries.fold<double>(0, (s, p) => s + p.value),
          closeTo(r.grossProfit, 1e-9));
      expect(r.profitSeries.length, r.series.length);
    });

    test('margin is 0, not a flipped sign, when net sales are negative', () {
      // The sale is from August; only its return falls in September.
      final o = _sale(1, [_item(1, 1, 1000, cost: 700)])
          .copyWith(createdAt: DateTime(2026, 8, 20));
      final r = sales([o, _return(2, o, o.items)]);
      expect(r.netSales, -1000);
      expect(r.netProfit, -300);
      expect(r.marginPct, 0);
    });

    test('items with no frozen cost use the product cost in profit', () {
      final r = sales([_sale(1, [_item(2, 3, 50)], discount: 15)]); // cost 20
      expect(r.cogs, 60);
      expect(r.grossProfit, 150 - 15 - 60);
    });

    test('export rows carry the new lines; deductions are negative', () {
      final o = _sale(1, [_item(1, 1, 1000, cost: 700)],
          discount: 100, tax: 45, delivery: 60);
      final rows = {
        for (final row in sales([o]).toTables((k) => k).first.rows) row[0]: row[1]
      };
      expect(rows['grossSales'], 1000);
      expect(rows['discounts'], -100);
      expect(rows['netSales'], 900);
      expect(rows['costOfGoods'], -700);
      expect(rows['grossProfit'], 200);
      expect(rows['deliveryCharges'], 60);
      expect(rows['netProfit'], 260);
      expect(rows['taxCollected'], 45);
    });

    test('Stock & Returns values a return the same way as the P&L', () {
      final o = _sale(1, [_item(1, 1, 1000, cost: 700)], discount: 100, tax: 45);
      final r = buildInventoryReport(
        products: const [],
        movements: const [],
        orders: [o, _return(2, o, o.items)],
        start: start,
        end: end,
      );
      expect(r.returnedValue, 900);
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
