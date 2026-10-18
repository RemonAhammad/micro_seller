// Dev-only dataset behind tool/gen_perf_backup.dart and test/perf_dataset_test.dart:
// a large, internally consistent Micro Seller dataset (orders with items,
// payments that add up to amountPaid, returns valued like the app values
// them, stock movements, purchases, expenses, register sessions).
//
// Ids are explicit and follow creation time, the way Isar's auto-increment
// assigns them, so cross-references (payments → orders, returns → originals)
// survive a restore. Deterministic for a given seed.
import 'dart:math';

import 'package:micro_seller/core/utils/variant_utils.dart';
import 'package:micro_seller/data/models/cash_register.dart';
import 'package:micro_seller/data/models/category.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/expense.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/purchase.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/models/supplier.dart';
import 'package:micro_seller/data/models/variant_attribute.dart';
import 'package:micro_seller/data/services/backup_format.dart';

class PerfDataset {
  PerfDataset({
    required this.orderCount,
    required this.productCount,
    required this.customerCount,
    required int seed,
  }) : rnd = Random(seed);

  final int orderCount;
  final int productCount;
  final int customerCount;
  final Random rnd;

  final now = DateTime.now();
  late final start = DateTime(now.year, now.month - 18, now.day);

  late final List<Category> categories;
  late final List<Supplier> suppliers;
  late final List<Product> products;
  late final List<Customer> customers;
  final List<Order> orders = [];
  final List<_PendingPayment> pendingPayments = [];
  final List<StockMovement> movements = [];
  final List<Purchase> purchases = [];
  late final List<Expense> expenses;
  late final List<CashRegister> registers;

  /// The full backup map (see `buildBackupMap`). Call once per instance.
  Map<String, Object?> build() {
    categories = _categories();
    suppliers = _suppliers();
    products = _products();
    customers = _customers();
    _orders();
    _returns();
    _numberOrdersAndLinkIds();
    final payments = _payments();
    _saleMovements();
    _purchases();
    _adjustments();
    expenses = _expenses();
    registers = _registers();
    _customerStats();

    movements.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    for (var i = 0; i < movements.length; i++) {
      movements[i].id = i + 1;
    }

    return buildBackupMap(
      products: products,
      orders: orders,
      customers: customers,
      expenses: expenses,
      stockMovements: movements,
      categories: categories,
      suppliers: suppliers,
      purchases: purchases,
      cashRegisters: registers,
      payments: payments,
      timestamp: now,
    );
  }

  // ── helpers ──

  T pick<T>(List<T> xs) => xs[rnd.nextInt(xs.length)];

  /// Skewed towards 0 — a few customers / products get most of the action.
  int skewedIndex(int n, [double power = 2.2]) =>
      min(n - 1, (pow(rnd.nextDouble(), power) * n).floor());

  /// A moment in [start, now], biased towards recent dates (sales grow).
  DateTime recentDate() {
    final span = now.difference(start).inSeconds;
    final t = sqrt(rnd.nextDouble());
    return start.add(Duration(seconds: (t * span).floor()));
  }


  DateTime minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  String pad(int n, int width) => n.toString().padLeft(width, '0');

  // ── catalog ──

  static const _categoryNames = [
    'Clothing', 'Electronics', 'Cosmetics', 'Groceries', 'Home', 'Toys',
    'Books', 'Shoes', 'Bags', 'Jewellery', 'Sports', 'Stationery',
  ];
  static const _adjectives = [
    'Classic', 'Premium', 'Cotton', 'Smart', 'Organic', 'Handmade', 'Mini',
    'Deluxe', 'Fresh', 'Silk', 'Leather', 'Kids', 'Travel', 'Eco', 'Royal',
  ];
  static const _nouns = [
    'Shirt', 'Saree', 'Panjabi', 'Earbuds', 'Lipstick', 'Rice Pack', 'Lamp',
    'Teddy', 'Notebook', 'Sneakers', 'Backpack', 'Necklace', 'Cricket Bat',
    'Pen Set', 'Kurti', 'Charger', 'Face Wash', 'Honey Jar', 'Mug', 'Wallet',
  ];
  static const _firstNames = [
    'Rahim', 'Karim', 'Fatema', 'Ayesha', 'Nusrat', 'Tanvir', 'Sadia',
    'Arif', 'Mitu', 'Rafi', 'Sumaiya', 'Hasan', 'Jannat', 'Imran', 'Tania',
    'Sakib', 'Mim', 'Farhan', 'Lima', 'Rakib',
  ];
  static const _lastNames = [
    'Ahmed', 'Hossain', 'Islam', 'Rahman', 'Khan', 'Chowdhury', 'Akter',
    'Sarkar', 'Uddin', 'Begum', 'Mia', 'Das',
  ];

  List<Category> _categories() => [
        for (var i = 0; i < _categoryNames.length; i++)
          Category(id: i + 1, name: _categoryNames[i], createdAt: start),
      ];

  List<Supplier> _suppliers() => [
        for (var i = 1; i <= 40; i++)
          Supplier(
            id: i,
            name: 'Supplier $i',
            company: '${pick(_lastNames)} Traders',
            phone: '01${pad(rnd.nextInt(1000000000), 9)}',
            createdAt: start,
          ),
      ];

  List<Product> _products() {
    final list = <Product>[];
    for (var i = 1; i <= productCount; i++) {
      final selling = (pow(10, 1.7 + rnd.nextDouble() * 2.0) / 10).round() * 10.0;
      final cost = roundMoney(selling * (0.55 + rnd.nextDouble() * 0.25));
      final withVariants = rnd.nextDouble() < 0.2;
      final attributes = withVariants
          ? [
              VariantAttribute(name: 'Size', options: const ['S', 'M', 'L']),
              VariantAttribute(name: 'Color', options: const ['Red', 'Blue', 'Black']),
            ]
          : <VariantAttribute>[];
      final sku = 'SKU-${pad(i, 5)}';
      final combos = generateCombinations(attributes, baseSku: sku)
          .map((c) => c.copyWith(
                stockQty: rnd.nextInt(30),
                priceAdjustment: rnd.nextDouble() < 0.3 ? 20.0 : 0.0,
              ))
          .toList();
      list.add(Product(
        id: i,
        name: '${pick(_adjectives)} ${pick(_nouns)} $i',
        sku: sku,
        sellingPrice: selling,
        costPrice: cost,
        stockQty: withVariants
            ? combos.fold(0, (s, c) => s + c.stockQty)
            : (rnd.nextDouble() < 0.05 ? 0 : rnd.nextInt(200)),
        lowStockThreshold: 10,
        category: pick(_categoryNames),
        isActive: rnd.nextDouble() > 0.02,
        variantAttributes: attributes,
        variantCombinations: combos,
        supplierId: rnd.nextDouble() < 0.7 ? 1 + rnd.nextInt(suppliers.length) : 0,
        createdAt: start,
        updatedAt: start,
      ));
    }
    return list;
  }

  List<Customer> _customers() => [
        for (var i = 1; i <= customerCount; i++)
          Customer(
            id: i,
            name: '${pick(_firstNames)} ${pick(_lastNames)} $i',
            phone: rnd.nextDouble() < 0.9 ? '01${pad(rnd.nextInt(1000000000), 9)}' : '',
            address: rnd.nextDouble() < 0.6 ? 'House ${rnd.nextInt(200)}, Road ${rnd.nextInt(30)}, Dhaka' : '',
            tag: CustomerTag.values[skewedIndex(3, 1.5)],
            createdAt: start,
          ),
      ];

  // ── orders ──

  OrderStatus _status() {
    final r = rnd.nextDouble();
    if (r < 0.60) return OrderStatus.completed;
    if (r < 0.70) return OrderStatus.confirmed;
    if (r < 0.75) return OrderStatus.shipped;
    if (r < 0.90) return OrderStatus.pending;
    return OrderStatus.cancelled;
  }

  PaymentStatus _paymentStatus(double paid, double total) => paid >= total - 0.005
      ? PaymentStatus.paid
      : paid > 0
          ? PaymentStatus.partial
          : PaymentStatus.unpaid;

  void _orders() {
    final active = products.where((p) => p.isActive).toList();
    final dates = [for (var i = 0; i < orderCount; i++) recentDate()]..sort();

    for (final createdAt in dates) {
      final customer = customers[skewedIndex(customers.length)];
      final itemCount = 1 + skewedIndex(5, 1.8);
      final items = <OrderItem>[];
      for (var k = 0; k < itemCount; k++) {
        final p = active[skewedIndex(active.length, 1.6)];
        final qty = 1 + skewedIndex(3, 2.0);
        var unit = p.sellingPrice;
        var key = '', label = '';
        if (p.hasVariants) {
          final c = pick(p.variantCombinations);
          unit += c.priceAdjustment;
          key = c.combinationKey;
          label = c.displayLabel;
        }
        items.add(OrderItem(
          productId: p.id,
          productName: p.name,
          productSku: p.sku,
          qty: qty,
          unitPrice: unit,
          costPrice: p.costPrice,
          totalPrice: unit * qty,
          variantCombinationKey: key,
          variantDisplayLabel: label,
        ));
      }
      final subtotal = items.fold(0.0, (s, i) => s + i.totalPrice);
      final discount = rnd.nextDouble() < 0.2
          ? (subtotal * (0.05 + rnd.nextDouble() * 0.1)).roundToDouble()
          : 0.0;
      final delivery = rnd.nextDouble() < 0.5 ? pick(const [60.0, 120.0]) : 0.0;
      final taxRate = rnd.nextDouble() < 0.3 ? 5.0 : 0.0;
      final totals = orderTotals(
          subtotal: subtotal, discount: discount, taxRate: taxRate, delivery: delivery);
      final status = _status();
      final method = PaymentMethod.values[skewedIndex(PaymentMethod.values.length, 1.3)];

      final order = Order(
        customerId: customer.id,
        customerName: customer.name,
        customerPhone: customer.phone,
        items: items,
        subtotal: subtotal,
        discountAmount: discount,
        deliveryFee: delivery,
        taxAmount: totals.tax,
        totalAmount: totals.total,
        paymentMethod: method,
        orderStatus: status,
        deliveryAddress: customer.address,
        actualDeliveryDate: status == OrderStatus.completed
            ? minDate(createdAt.add(Duration(days: 1 + rnd.nextInt(4))), now)
            : null,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      orders.add(order);

      // Payments: cancelled orders carry none (cancel refunds what was paid).
      var paid = 0.0;
      if (status != OrderStatus.cancelled) {
        final r = rnd.nextDouble();
        final atSale = r < 0.55
            ? totals.total
            : r < 0.80
                ? roundMoney(totals.total * (0.2 + rnd.nextDouble() * 0.6))
                : 0.0;
        if (atSale > 0) {
          paid = atSale;
          pendingPayments.add(_PendingPayment(order, atSale, createdAt, method));
        }
        // Many credit sales get collected later, in one or two instalments.
        final age = now.difference(createdAt).inDays;
        if (paid < totals.total && age > 7 && rnd.nextDouble() < 0.65) {
          final instalments = rnd.nextDouble() < 0.3 ? 2 : 1;
          for (var n = 0; n < instalments; n++) {
            final rest = roundMoney(totals.total - paid);
            if (rest <= 0) break;
            final amount = n == instalments - 1 ? rest : roundMoney(rest / 2);
            final when = minDate(createdAt.add(Duration(days: 3 + rnd.nextInt(min(age, 90)))), now);
            paid = roundMoney(paid + amount);
            pendingPayments.add(_PendingPayment(order, amount, when, method));
          }
        }
      }
      order.amountPaid = paid;
      order.paymentStatus = _paymentStatus(paid, order.totalAmount);
    }
  }

  void _returns() {
    final candidates = orders
        .where((o) =>
            o.orderStatus == OrderStatus.completed &&
            o.isFullyPaid &&
            now.difference(o.createdAt!).inDays > 3)
        .toList();
    final returnCount = (orders.length * 0.03).round();
    for (var i = 0; i < returnCount && candidates.isNotEmpty; i++) {
      final original = candidates.removeAt(rnd.nextInt(candidates.length));
      final item = pick(original.items);
      final value = returnValueFor(original, [item]);
      final when = minDate(original.createdAt!.add(Duration(days: 1 + rnd.nextInt(14))), now);
      final refunded = rnd.nextDouble() < 0.7;
      final refund = roundMoney(min(value.total, original.amountPaid));

      final ret = Order(
        customerId: original.customerId,
        customerName: original.customerName,
        customerPhone: original.customerPhone,
        items: [item],
        subtotal: value.subtotal,
        discountAmount: value.discount,
        taxAmount: value.tax,
        totalAmount: value.total,
        refundAmount: refund,
        amountPaid: refunded ? refund : 0,
        paymentStatus: refunded ? PaymentStatus.paid : PaymentStatus.unpaid,
        paymentMethod: original.paymentMethod,
        orderStatus: refunded ? OrderStatus.completed : OrderStatus.pending,
        isReturn: true,
        returnStatus: refunded ? ReturnStatus.refunded : ReturnStatus.received,
        returnReason: ReturnReason.values[rnd.nextInt(ReturnReason.values.length)],
        createdAt: when,
        updatedAt: when,
      );
      ret.notes = 'Return';
      _returnOf[ret] = original;
      orders.add(ret);
      original.returnStatus = ReturnStatus.requested;

      if (refunded) {
        original.amountPaid = roundMoney(original.amountPaid - refund);
        original.paymentStatus = _paymentStatus(original.amountPaid, original.totalAmount);
        pendingPayments.add(_PendingPayment(original, -refund, when, original.paymentMethod));
      }
    }
  }

  final Map<Order, Order> _returnOf = {};

  /// Ids follow creation time (like Isar's auto-increment), and order numbers
  /// follow ids — ORD-/RET- prefixes as the app assigns them.
  void _numberOrdersAndLinkIds() {
    orders.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    for (var i = 0; i < orders.length; i++) {
      final o = orders[i];
      o.id = i + 1;
      o.orderNumber = '${o.isReturn ? 'RET' : 'ORD'}-${pad(i + 1, 3)}';
    }
    for (final entry in _returnOf.entries) {
      entry.key.originalOrderId = entry.value.id;
      entry.key.notes = 'Return for ${entry.value.orderNumber}';
    }
  }

  List<Payment> _payments() {
    pendingPayments.sort((a, b) => a.paidAt.compareTo(b.paidAt));
    return [
      for (var i = 0; i < pendingPayments.length; i++)
        Payment(
          id: i + 1,
          customerId: pendingPayments[i].order.customerId,
          orderId: pendingPayments[i].order.id,
          amount: pendingPayments[i].amount,
          method: pendingPayments[i].method,
          groupId: 'g${i + 1}',
          paidAt: pendingPayments[i].paidAt,
          createdAt: pendingPayments[i].paidAt,
        ),
    ];
  }

  // ── stock ──

  String _movementName(OrderItem item) => item.variantDisplayLabel.isEmpty
      ? item.productName
      : '${item.productName} (${item.variantDisplayLabel})';

  void _saleMovements() {
    for (final o in orders) {
      final deducted = o.orderStatus == OrderStatus.confirmed ||
          o.orderStatus == OrderStatus.shipped ||
          o.orderStatus == OrderStatus.completed;
      if (o.isReturn) {
        for (final item in o.items) {
          movements.add(StockMovement(
            productId: item.productId,
            productName: _movementName(item),
            type: StockMovementType.restock,
            qty: item.qty,
            reason: 'Return ${o.orderNumber}',
            createdAt: o.createdAt,
          ));
        }
      } else if (deducted) {
        for (final item in o.items) {
          movements.add(StockMovement(
            productId: item.productId,
            productName: _movementName(item),
            type: StockMovementType.sale,
            qty: -item.qty,
            reason: 'Order ${o.orderNumber}',
            createdAt: o.createdAt,
          ));
        }
      }
    }
  }

  void _purchases() {
    final count = max(50, orderCount ~/ 16);
    final bySupplier = <int, List<Product>>{};
    for (final p in products) {
      if (p.supplierId > 0) bySupplier.putIfAbsent(p.supplierId, () => []).add(p);
    }
    final dates = [for (var i = 0; i < count; i++) recentDate()]..sort();
    for (var i = 0; i < count; i++) {
      final linked = rnd.nextDouble() < 0.8;
      final supplier = linked ? pick(suppliers) : null;
      final pool = (supplier != null ? bySupplier[supplier.id] : null) ?? products;
      final items = [
        for (var k = 0; k < 1 + rnd.nextInt(6); k++)
          () {
            final p = pick(pool);
            final qty = 5 + rnd.nextInt(46);
            return PurchaseItem(
              productId: p.id,
              productName: p.name,
              qty: qty,
              unitCost: p.costPrice,
              totalCost: roundMoney(p.costPrice * qty),
            );
          }(),
      ];
      final total = roundMoney(items.fold(0.0, (s, it) => s + it.totalCost));
      final r = rnd.nextDouble();
      final paid = r < 0.7 ? total : (r < 0.9 ? roundMoney(total * 0.5) : 0.0);
      final purchase = Purchase(
        id: i + 1,
        supplierId: supplier?.id ?? 0,
        supplierName: supplier?.name ?? '',
        items: items,
        totalAmount: total,
        amountPaid: paid,
        paymentMethod: PurchasePaymentMethod.values[rnd.nextInt(PurchasePaymentMethod.values.length)],
        referenceNumber: 'PO-${pad(i + 1, 4)}',
        createdAt: dates[i],
      );
      purchases.add(purchase);
      if (supplier != null) {
        supplier.totalPurchases += 1;
        supplier.totalPaid = roundMoney(supplier.totalPaid + paid);
        supplier.totalDue = roundMoney(supplier.totalDue + total - paid);
      }
      for (final it in items) {
        movements.add(StockMovement(
          productId: it.productId,
          productName: it.productName,
          type: StockMovementType.restock,
          qty: it.qty,
          reason: supplier != null ? 'Purchase from ${supplier.name}' : 'Purchase',
          supplierId: supplier?.id ?? 0,
          createdAt: dates[i],
        ));
      }
    }
  }

  void _adjustments() {
    final count = max(100, orderCount ~/ 5);
    for (var i = 0; i < count; i++) {
      final p = pick(products);
      final damage = rnd.nextDouble() < 0.3;
      movements.add(StockMovement(
        productId: p.id,
        productName: p.name,
        type: damage ? StockMovementType.damage : StockMovementType.adjustment,
        qty: damage ? -(1 + rnd.nextInt(3)) : (rnd.nextBool() ? 1 : -1) * (1 + rnd.nextInt(10)),
        reason: damage ? 'Damaged in storage' : 'Stock count',
        createdAt: recentDate(),
      ));
    }
  }

  // ── money in/out ──

  List<Expense> _expenses() {
    const titles = {
      ExpenseCategory.logistics: 'Courier charge',
      ExpenseCategory.packaging: 'Packaging material',
      ExpenseCategory.marketing: 'Facebook boost',
      ExpenseCategory.supplies: 'Office supplies',
      ExpenseCategory.other: 'Misc',
    };
    final count = max(100, orderCount ~/ 7);
    final dates = [for (var i = 0; i < count; i++) recentDate()]..sort();
    return [
      for (var i = 0; i < count; i++)
        () {
          final cat = ExpenseCategory.values[rnd.nextInt(ExpenseCategory.values.length)];
          return Expense(
            id: i + 1,
            title: titles[cat]!,
            amount: (50 + rnd.nextInt(4950)).toDouble(),
            category: cat,
            date: dates[i],
            createdAt: dates[i],
          );
        }(),
    ];
  }

  List<CashRegister> _registers() {
    final days = min(365, now.difference(start).inDays);
    final list = <CashRegister>[];
    for (var d = days; d >= 0; d--) {
      final day = DateTime(now.year, now.month, now.day - d);
      final opening = (1000 + rnd.nextInt(4000)).toDouble();
      final cashIn = (rnd.nextInt(20000)).toDouble();
      final cashOut = (rnd.nextInt(5000)).toDouble();
      final isToday = d == 0;
      final expected = opening + cashIn - cashOut;
      list.add(CashRegister(
        id: list.length + 1,
        openingAmount: opening,
        totalSales: cashIn,
        totalCashIn: cashIn,
        totalCashOut: cashOut,
        isClosed: !isToday,
        closingAmount: isToday ? null : expected + (rnd.nextInt(201) - 100),
        openedAt: day.add(const Duration(hours: 9)),
        closedAt: isToday ? null : day.add(const Duration(hours: 21)),
      ));
    }
    return list;
  }

  void _customerStats() {
    for (final o in orders) {
      if (o.isReturn || o.orderStatus == OrderStatus.cancelled) continue;
      final c = customers[o.customerId - 1];
      c.totalOrders += 1;
      c.totalSpent = roundMoney(c.totalSpent + o.totalAmount);
    }
  }
}

class _PendingPayment {
  _PendingPayment(this.order, this.amount, this.paidAt, this.method);
  final Order order;
  final double amount;
  final DateTime paidAt;
  final PaymentMethod method;
}
