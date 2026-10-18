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

/// An order totalled exactly the way the order form does it
/// (`_taxAmount` / `_total` in order_form_screen.dart).
Order _order(List<OrderItem> items,
    {double discount = 0, double taxRate = 0, double delivery = 0}) {
  final subtotal = items.fold<double>(0, (s, i) => s + i.totalPrice);
  final tax = taxRate > 0
      ? (subtotal - discount).clamp(0, double.infinity) * taxRate / 100
      : 0.0;
  return Order(
    items: items,
    subtotal: subtotal,
    discountAmount: discount,
    taxAmount: tax.toDouble(),
    deliveryFee: delivery,
    totalAmount:
        (subtotal - discount + tax + delivery).clamp(0, double.infinity).toDouble(),
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

    test('shares are whole paisa and add up to the order', () {
      final items = [
        _item(1, 333.33),
        _item(1, 333.33, productId: 2),
        _item(1, 333.34, productId: 3),
      ];
      final o = _order(items, discount: 100, taxRate: 7.5);
      final parts = [for (final i in items) returnValueFor(o, [i])];
      for (final p in parts) {
        for (final v in [p.discount, p.tax, p.total]) {
          expect(v * 100, closeTo((v * 100).roundToDouble(), 1e-6));
        }
      }
      final whole = returnValueFor(o, items);
      expect(whole.total, closeTo(o.totalAmount, 0.006));
      expect(parts.fold<double>(0, (s, p) => s + p.discount),
          closeTo(o.discountAmount, 0.011));
      expect(parts.fold<double>(0, (s, p) => s + p.total),
          closeTo(whole.total, 0.021));
    });
  });

  test('roundMoney rounds to 2 decimals', () {
    expect(roundMoney(49.99999999999999), 50);
    expect(roundMoney(22.504), 22.5);
    expect(roundMoney(-12.345678), -12.35);
  });
}
