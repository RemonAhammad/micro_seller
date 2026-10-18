import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';

OrderItem _item(int qty, double price, {int productId = 1}) => OrderItem(
      productId: productId,
      productName: 'P$productId',
      qty: qty,
      unitPrice: price,
      totalPrice: qty * price,
    );

/// An order totalled exactly the way the order form does it.
Order _order(List<OrderItem> items,
    {double discount = 0, double taxRate = 0, double delivery = 0}) {
  final subtotal = items.fold<double>(0, (s, i) => s + i.totalPrice);
  final t = orderTotals(
      subtotal: subtotal, discount: discount, taxRate: taxRate, delivery: delivery);
  return Order(
    items: items,
    subtotal: subtotal,
    discountAmount: discount,
    taxAmount: t.tax,
    deliveryFee: delivery,
    totalAmount: t.total,
  );
}

void main() {
  group('Order money helpers', () {
    test('no discount: net goods is the list price', () {
      final o = _order([_item(2, 500)]);
      expect(o.goodsTotal, 1000);
      expect(o.netGoods, 1000);
      expect(o.discountFactor, 1);
      expect(o.deliveryIncome, 0);
    });

    test('the discount comes off the goods, spread pro rata', () {
      final o = _order([_item(1, 1000)], discount: 100);
      expect(o.netGoods, 900);
      expect(o.discountFactor, closeTo(0.9, 1e-12));
    });

    test('goods + delivery + tax add back up to the billed total', () {
      for (final o in [
        _order([_item(3, 333)], discount: 50, taxRate: 7.5, delivery: 60),
        _order([_item(1, 1000)], discount: 100, taxRate: 5, delivery: 60),
        _order([_item(2, 250), _item(1, 120, productId: 2)], taxRate: 15),
        _order([_item(1, 100)], discount: 130, delivery: 60),
      ]) {
        expect(o.netGoods + o.deliveryIncome + o.taxAmount,
            closeTo(o.totalAmount, 1e-9));
      }
    });

    test('a discount bigger than the goods eats into delivery, not below 0', () {
      final o = _order([_item(1, 100)], discount: 130, delivery: 60);
      expect(o.totalAmount, 30);
      expect(o.netGoods, 0);
      expect(o.discountFactor, 0);
      expect(o.deliveryIncome, 30);
    });

    test('no items: nothing to discount', () {
      final o = Order(totalAmount: 500);
      expect(o.goodsTotal, 0);
      expect(o.netGoods, 0);
      expect(o.discountFactor, 1);
      expect(o.deliveryIncome, 0);
    });
  });

  group('orderTotals', () {
    test('tax is on the goods after discount', () {
      final t = orderTotals(subtotal: 1000, discount: 100, taxRate: 5, delivery: 60);
      expect(t.tax, 45);
      expect(t.total, 1005);
    });

    test('"Pay Full" types the total, and that pays it in full', () {
      // 999 at 7.5% is 74.925 tax: unrounded, the 2-decimal "Pay Full"
      // amount fell half a paisa short and the order read "Partial".
      for (final (subtotal, rate) in [(999.0, 7.5), (10.03, 5.0), (10.05, 5.0), (333.33, 15.0)]) {
        final t = orderTotals(subtotal: subtotal, taxRate: rate);
        final payFull = double.parse(t.total.toStringAsFixed(2));
        expect(payFull >= t.total, isTrue, reason: '$subtotal @ $rate%');
        expect(t.tax * 100, closeTo((t.tax * 100).roundToDouble(), 1e-6));
      }
    });

    test('never below 0', () {
      expect(orderTotals(subtotal: 100, discount: 300).total, 0);
      expect(orderTotals(subtotal: 100, discount: 300, taxRate: 5).tax, 0);
    });
  });

  group('returnValueFor', () {
    test('full return = what the customer paid, minus delivery', () {
      // ৳1,000 − ৳100 discount + 5% tax (৳45) + ৳60 delivery = ৳1,005 billed.
      final o = _order([_item(1, 1000)], discount: 100, taxRate: 5, delivery: 60);
      final v = returnValueFor(o, o.items);
      expect(v.subtotal, 1000);
      expect(v.discount, 100);
      expect(v.tax, 45);
      expect(v.total, 945);
    });

    test('partial return carries its share of the discount and tax', () {
      final o = _order([_item(2, 500)], discount: 100, taxRate: 5);
      final v = returnValueFor(o, [_item(1, 500)]);
      expect(v.subtotal, 500);
      expect(v.discount, 50);
      expect(v.tax, 22.5);
      expect(v.total, 472.5);
    });

    test('no discount and no tax: the list price', () {
      final o = _order([_item(2, 500)]);
      final v = returnValueFor(o, [_item(1, 500)]);
      expect(v.discount, 0);
      expect(v.tax, 0);
      expect(v.total, 500);
    });

    test('discount bigger than the goods: the goods were free', () {
      final o = _order([_item(1, 100)], discount: 130, delivery: 60);
      final v = returnValueFor(o, o.items);
      expect(v.discount, 100);
      expect(v.total, 0);
    });

    test('returning everything piece by piece adds up to exactly the order', () {
      // Rounding each piece to the paisa used to leave 0.01 owed (or
      // credited) once all of it had come back: 3 × 10.00 with 2.00 off
      // came back as 3 × 9.33 = 27.99.
      for (final (prices, discount, rate) in [
        ([10.0, 10.0, 10.0], 2.0, 0.0),
        ([10.0, 10.0, 10.0], 1.0, 0.0),
        ([333.33, 333.33, 333.34], 100.0, 7.5),
        ([99.99, 0.01, 450.0, 12.5], 17.0, 15.0),
      ]) {
        final items = [
          for (var i = 0; i < prices.length; i++) _item(1, prices[i], productId: i + 1)
        ];
        final o = _order(items, discount: discount, taxRate: rate);
        final pieces = items.map((i) => returnValueFor(o, [i]).total);
        expect(pieces.fold<double>(0, (s, v) => s + v), closeTo(o.totalAmount, 1e-9),
            reason: '$prices − $discount @ $rate%');
        expect(returnValueFor(o, items).total, closeTo(o.totalAmount, 1e-9));
      }
    });
  });

  test('roundMoney rounds to 2 decimals', () {
    expect(roundMoney(49.99999999999999), 50);
    expect(roundMoney(22.504), 22.5);
    expect(roundMoney(-12.345678), -12.35);
  });
}
