import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/statement_service.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';

final _labels = StatementLabels(
  title: 'Statement',
  date: 'Date',
  reference: 'Ref',
  debit: 'Debit',
  credit: 'Credit',
  balance: 'Balance',
  closingBalance: 'Closing',
  payment: 'Payment',
  refund: 'Refund',
  generatedOn: (d) => d,
  pageOf: (p, t) => '$p/$t',
);

Order _order(
  int id,
  double total, {
  double paid = 0,
  int day = 1,
  OrderStatus status = OrderStatus.confirmed,
}) =>
    Order(
      id: id,
      orderNumber: 'ORD-$id',
      customerId: 1,
      totalAmount: total,
      amountPaid: paid,
      orderStatus: status,
      createdAt: DateTime(2026, 1, day),
    );

double _sum(List<OrderDue> d) => d.fold(0, (s, e) => s + e.due);

void main() {
  group('computeOrderDues', () {
    test('sums unpaid and partial orders, oldest first', () {
      final dues = computeOrderDues([
        _order(3, 800, day: 3),
        _order(1, 1000, day: 1),
        _order(2, 500, paid: 200, day: 2),
      ]);
      expect(dues.map((d) => d.order.id), [1, 2, 3]);
      expect(_sum(dues), 2100);
    });

    test('ignores cancelled, fully paid and return orders', () {
      final dues = computeOrderDues([
        _order(1, 1000, status: OrderStatus.cancelled),
        _order(2, 500, paid: 500),
        Order(id: 3, isReturn: true, customerId: 1, totalAmount: 300),
      ]);
      expect(dues, isEmpty);
    });

    test('refunded return: cash refund leaves nothing owed', () {
      // Paid 1000, returned everything, refunded 1000 → processRefund drops
      // original.amountPaid to 0, but the customer owes nothing.
      final dues = computeOrderDues([
        _order(1, 1000, paid: 0),
        Order(
          id: 2,
          customerId: 1,
          isReturn: true,
          originalOrderId: 1,
          returnStatus: ReturnStatus.refunded,
          totalAmount: 1000,
        ),
      ]);
      expect(dues, isEmpty);
    });

    test('refunded return: exchange (refund 0) reduces the debt', () {
      // Unpaid 1000, returned 400 worth, no cash back → owes 600.
      final dues = computeOrderDues([
        _order(1, 1000),
        Order(
          id: 2,
          customerId: 1,
          isReturn: true,
          originalOrderId: 1,
          returnStatus: ReturnStatus.refunded,
          totalAmount: 400,
        ),
      ]);
      expect(_sum(dues), 600);
    });

    test('a return still awaiting refund does not change the due', () {
      final dues = computeOrderDues([
        _order(1, 1000),
        Order(
          id: 2,
          customerId: 1,
          isReturn: true,
          originalOrderId: 1,
          returnStatus: ReturnStatus.received,
          totalAmount: 400,
        ),
      ]);
      expect(_sum(dues), 1000);
    });
  });

  group('computeNetDue (review findings)', () {
    test('credit on one order offsets another order\'s due', () {
      // ORD-1 100 paid 100 + exchange return 30 (refund 0) → credit 30.
      // ORD-2 50 unpaid. Counter & statement say 20; so must the Due Book.
      final orders = [
        _order(1, 100, paid: 100),
        _order(2, 50, day: 2),
        Order(
          id: 3,
          customerId: 1,
          isReturn: true,
          originalOrderId: 1,
          returnStatus: ReturnStatus.refunded,
          totalAmount: 30,
        ),
      ];
      expect(computeNetDue(orders), closeTo(20, 0.001));
      expect(computeOrderDues(orders).map((d) => d.order.id), [2]);
      final rows = StatementService().buildRows(orders, const [], labels: _labels);
      expect(rows.last.balance, closeTo(20, 0.001));
    });

    test('refunded return on a cancelled original is ignored everywhere', () {
      final orders = [
        _order(1, 100, status: OrderStatus.cancelled),
        Order(
          id: 2,
          orderNumber: 'RET-2',
          customerId: 1,
          isReturn: true,
          originalOrderId: 1,
          returnStatus: ReturnStatus.refunded,
          totalAmount: 40,
        ),
      ];
      expect(computeNetDue(orders), 0);
      final rows = StatementService().buildRows(orders, const [], labels: _labels);
      expect(rows, isEmpty);
    });
  });

  group('returns from a discounted order', () {
    // Two ৳500 items with ৳100 off: billed ৳900.
    OrderItem item() =>
        OrderItem(productId: 1, qty: 1, unitPrice: 500, totalPrice: 500);
    Order discounted({double paid = 0}) => Order(
          id: 1,
          orderNumber: 'ORD-1',
          customerId: 1,
          items: [item(), item()],
          subtotal: 1000,
          discountAmount: 100,
          totalAmount: 900,
          amountPaid: paid,
          orderStatus: OrderStatus.completed,
          createdAt: DateTime(2026, 1, 1),
        );
    // Valued the way createReturnOrder values it, then refunded.
    Order refunded(Order original, List<OrderItem> items) {
      final v = returnValueFor(original, items);
      return Order(
        id: 2,
        orderNumber: 'RET-2',
        customerId: 1,
        isReturn: true,
        originalOrderId: original.id,
        returnStatus: ReturnStatus.refunded,
        items: items,
        subtotal: v.subtotal,
        discountAmount: v.discount,
        taxAmount: v.tax,
        totalAmount: v.total,
        createdAt: DateTime(2026, 1, 5),
      );
    }

    test('full return, full refund: no credit against other dues', () {
      // Paid 900, all returned, 900 refunded → amountPaid back to 0. At list
      // price the return was worth 1000, and the extra 100 silently came
      // off the customer's other order.
      final original = discounted();
      final orders = [
        original,
        refunded(original, original.items),
        _order(3, 500, day: 2),
      ];
      expect(computeNetDue(orders), closeTo(500, 0.001));
      final rows = StatementService().buildRows(orders, const [], labels: _labels);
      expect(rows.last.balance, closeTo(500, 0.001));
    });

    test('partial return refunded at the suggested amount settles it', () {
      // Paid 900; one item back; suggested refund 450 → amountPaid 450.
      final original = discounted(paid: 450);
      expect(computeNetDue([original, refunded(original, [item()])]), 0);
    });

    test('exchange on credit lowers the debt by what the item cost', () {
      final original = discounted(); // unpaid
      expect(computeNetDue([original, refunded(original, [item()])]),
          closeTo(450, 0.001));
    });
  });

  group('sub-paisa leftovers', () {
    // Orders saved before totals were rounded: 5% tax on 10.03 / 10.04 /
    // 10.05 is 10.5315 / 10.542 / 10.5525, and "Pay Full" typed 10.53 /
    // 10.54 / 10.55. Each order is settled; together they used to add up
    // to 0.006 — a "due" on no order, which crashed the Due Book.
    final dusty = [
      _order(1, 10.5315, paid: 10.53, day: 1),
      _order(2, 10.542, paid: 10.54, day: 2),
      _order(3, 10.5525, paid: 10.55, day: 3),
    ];

    test('do not add up to a due no order shows', () {
      expect(computeOrderDues(dusty), isEmpty);
      expect(computeNetDue(dusty), 0);
    });

    test('a real due next to them is still counted in full', () {
      expect(computeNetDue([...dusty, _order(4, 100, day: 4)]), 100);
    });

    test('a customer row with no due orders has no oldest date', () {
      final row = CustomerDue(
          customer: Customer(id: 1, name: 'Rahim'), orderDues: const [], totalDue: 0);
      expect(row.oldestDueDate, isNull);
      expect(row.daysOutstanding, 0);
    });
  });

  group('StatementService.buildRows', () {
    final service = StatementService();

    test('closing balance matches computed dues with logged payments', () {
      final orders = [
        _order(1, 1000, paid: 1000, day: 1),
        _order(2, 500, paid: 500, day: 2),
        _order(3, 800, day: 3),
      ];
      final payments = [
        Payment(orderId: 2, customerId: 1, amount: 200, paidAt: DateTime(2026, 1, 2)),
        Payment(orderId: 1, customerId: 1, amount: 1000, paidAt: DateTime(2026, 1, 5)),
        Payment(orderId: 2, customerId: 1, amount: 300, paidAt: DateTime(2026, 1, 5)),
      ];
      final rows = service.buildRows(orders, payments, labels: _labels);
      expect(rows.last.balance, closeTo(800, 0.001));
      expect(rows.last.balance, closeTo(_sum(computeOrderDues(orders)), 0.001));
    });

    test('legacy payments without Payment rows are inferred per order', () {
      final orders = [_order(1, 1000, paid: 600)];
      final rows = service.buildRows(orders, const [], labels: _labels);
      expect(rows.length, 2);
      expect(rows.last.balance, closeTo(400, 0.001));
    });

    test('cancelled order with payment and its cancel refund nets to zero', () {
      final orders = [
        _order(1, 1000, status: OrderStatus.cancelled),
        _order(2, 300, day: 2),
      ];
      final payments = [
        Payment(orderId: 1, customerId: 1, amount: 400, paidAt: DateTime(2026, 1, 1)),
        Payment(orderId: 1, customerId: 1, amount: -400, paidAt: DateTime(2026, 1, 2)),
      ];
      final rows = service.buildRows(orders, payments, labels: _labels);
      expect(rows.length, 1);
      expect(rows.last.balance, 300);
    });

    test('partial cash refund on a return matches the dues model', () {
      // Paid 1000; returned 400 worth; refunded 250 in cash.
      // processRefund: original.amountPaid 1000 → 750, logs −250.
      final orders = [
        _order(1, 1000, paid: 750),
        Order(
          id: 2,
          orderNumber: 'RET-2',
          customerId: 1,
          isReturn: true,
          originalOrderId: 1,
          returnStatus: ReturnStatus.refunded,
          totalAmount: 400,
          createdAt: DateTime(2026, 1, 3),
        ),
      ];
      final payments = [
        Payment(orderId: 1, customerId: 1, amount: 1000, paidAt: DateTime(2026, 1, 1)),
        Payment(orderId: 1, customerId: 1, amount: -250, paidAt: DateTime(2026, 1, 3)),
      ];
      final rows = service.buildRows(orders, payments, labels: _labels);
      // Kept 600 of goods, paid net 750 → customer is 150 in credit; the
      // Due Book shows nothing owed (dues never go negative).
      expect(rows.last.balance, closeTo(-150, 0.001));
      expect(computeOrderDues(orders), isEmpty);
    });
  });

  group('summarizeDues', () {
    CustomerDue due(int id, double total, int oldestDaysAgo) {
      final o = Order(
        id: id,
        customerId: id,
        totalAmount: total,
        createdAt: DateTime.now().subtract(Duration(days: oldestDaysAgo)),
      );
      return CustomerDue(
        customer: Customer(id: id, name: 'C$id'),
        orderDues: [OrderDue(o, total)],
        totalDue: total,
      );
    }

    test('buckets sum to the total and use the oldest order age', () {
      final summary = summarizeDues([
        due(1, 100, 5),
        due(2, 200, 45),
        due(3, 300, 70),
        due(4, 50, 61),
      ]);
      expect(summary.total, 650);
      expect(summary.customerCount, 4);
      expect(summary.under30, 100);
      expect(summary.from30to60, 200);
      expect(summary.over60, 350);
      expect(summary.over60Count, 2);
      expect(summary.under30 + summary.from30to60 + summary.over60,
          summary.total);
    });
  });

  group('duesCollectedBetween', () {
    final start = DateTime(2026, 3, 1);
    final end = DateTime(2026, 4, 1);
    final orders = {
      1: _order(1, 1000).copyWith(createdAt: DateTime(2026, 2, 20)),
      2: _order(2, 500).copyWith(createdAt: DateTime(2026, 3, 10, 9)),
    };

    test('counts later collections, skips pay-at-sale and refunds', () {
      final total = duesCollectedBetween([
        // Collected on a due from February → counts.
        Payment(orderId: 1, amount: 300, paidAt: DateTime(2026, 3, 5)),
        // Paid at the time of sale (same day) → not a due collection.
        Payment(orderId: 2, amount: 200, paidAt: DateTime(2026, 3, 10, 18)),
        // Collected later on order 2 → counts.
        Payment(orderId: 2, amount: 100, paidAt: DateTime(2026, 3, 20)),
        // Refund → not a collection, ignored.
        Payment(orderId: 1, amount: -50, paidAt: DateTime(2026, 3, 25)),
        // Outside the month → ignored.
        Payment(orderId: 1, amount: 999, paidAt: DateTime(2026, 4, 2)),
      ], orders, start, end);
      expect(total, 400);
    });
  });
}
