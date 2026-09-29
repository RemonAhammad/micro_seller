import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/statement_service.dart';

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
}
