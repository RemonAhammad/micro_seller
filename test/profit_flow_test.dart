// End-to-end money flows on a real Isar database: the order and return
// notifiers write, and the Dashboard, Reports and Due Book read back.
//
// Uses the Isar core library bundled in isar_community_flutter_libs, so it
// runs offline on macOS, Linux and Windows hosts; skipped when not found.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/report_service.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';
import 'package:micro_seller/features/dashboard/providers/dashboard_provider.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:micro_seller/features/reports/providers/reports_provider.dart';

String? _isarCoreLibrary() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final packages = (jsonDecode(config.readAsStringSync())['packages'] as List)
      .cast<Map<String, dynamic>>();
  final pkg = packages
      .where((p) => p['name'] == 'isar_community_flutter_libs')
      .firstOrNull;
  if (pkg == null) return null;
  final root = Directory.fromUri(
      config.absolute.uri.resolve('${pkg['rootUri']}/'));
  final file = switch (Platform.operatingSystem) {
    'macos' => 'macos/libisar.dylib',
    'linux' => 'linux/libisar.so',
    'windows' => 'windows/libisar.dll',
    _ => null,
  };
  if (file == null) return null;
  final path = '${root.path}$file';
  return File(path).existsSync() ? path : null;
}

void main() {
  final coreLibrary = _isarCoreLibrary();

  late Directory dir;
  late Isar isar;
  late ProviderContainer container;
  late int customerId;

  setUpAll(() async {
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
  });

  setUp(() async {
    if (coreLibrary == null) return;
    dir = await Directory.systemTemp.createTemp('micro_seller_profit');
    isar = await Isar.open(kIsarSchemas,
        directory: dir.path, name: 'profit_test', inspector: false);
    container = ProviderContainer(
        overrides: [isarProvider.overrideWith((ref) async => isar)]);
    customerId = await isar.writeTxn(
        () => isar.customers.put(Customer(name: 'Rahim', phone: '01711111111')));
  });

  tearDown(() async {
    if (coreLibrary == null) return;
    container.dispose();
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  OrderNotifier orders() => container.read(orderProvider.notifier);

  Future<Product> addProduct(
      {double price = 1000, double cost = 700, int stock = 10}) async {
    final p = Product(
        name: 'Panjabi', sku: 'PJ-1', sellingPrice: price, costPrice: cost, stockQty: stock);
    p.id = await isar.writeTxn(() => isar.products.put(p));
    return p;
  }

  /// Saves an order the way the order form builds it, through the real
  /// notifier (stock, payment log, customer stats).
  Future<Order> sell(Product p, int qty,
      {double discount = 0, double taxRate = 0, double delivery = 0, double? paid}) async {
    final goods = p.sellingPrice * qty;
    final t = orderTotals(
        subtotal: goods, discount: discount, taxRate: taxRate, delivery: delivery);
    final tax = t.tax;
    final total = t.total;
    // "Pay Full" types the total with 2 decimals.
    final amountPaid = paid ?? double.parse(total.toStringAsFixed(2));
    final id = await orders().createOrder(Order(
      orderNumber: 'ORD-${DateTime.now().microsecondsSinceEpoch}',
      customerId: customerId,
      customerName: 'Rahim',
      items: [
        OrderItem(
          productId: p.id,
          productName: p.name,
          productSku: p.sku,
          qty: qty,
          unitPrice: p.sellingPrice,
          costPrice: p.costPrice,
          totalPrice: goods,
        ),
      ],
      subtotal: goods,
      discountAmount: discount,
      taxAmount: tax,
      deliveryFee: delivery,
      totalAmount: total,
      amountPaid: amountPaid,
      paymentStatus: amountPaid >= total
          ? PaymentStatus.paid
          : amountPaid > 0
              ? PaymentStatus.partial
              : PaymentStatus.unpaid,
      orderStatus: OrderStatus.confirmed,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    return (await isar.orders.get(id))!;
  }

  /// Request → receive → refund, through the real notifier.
  Future<Order> returnAndRefund(Order original, int qty, double refund) async {
    final item = original.items.first;
    await orders().createReturnOrder(
      originalOrder: (await isar.orders.get(original.id))!,
      returnItems: [
        item.copyWith(qty: qty, totalPrice: item.unitPrice * qty),
      ],
      reason: ReturnReason.changedMind,
      refundAmount: refund,
    );
    final ret = (await isar.orders.filter().isReturnEqualTo(true).findAll()).last;
    await orders().approveReturn(ret.id);
    await orders().processRefund(ret.id);
    return (await isar.orders.get(ret.id))!;
  }

  // The Dashboard recomputes when orders change; give Isar's watch stream a
  // moment to fire, then read the settled value.
  Future<DashboardStats> dashboard() async {
    container.listen(dashboardStatsProvider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return container.read(dashboardStatsProvider.future);
  }

  Future<SalesReport> report() async {
    final today = DateTime.now();
    final p = salesReportProvider(today, today);
    container.listen(p, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return container.read(p.future);
  }

  Future<double> customerDue() async => computeNetDue(
      await isar.orders.filter().customerIdEqualTo(customerId).findAll());

  group('money flows on a real database', skip: coreLibrary == null ? 'Isar core library not found' : false, () {
    test('the review: a discount comes off Dashboard profit, same as Reports', () async {
      final p = await addProduct(); // cost 700, price 1000
      await sell(p, 1, discount: 100);

      final d = await dashboard();
      final r = await report();
      expect(d.thisMonthProfit, 200); // was 300: the discount was ignored
      expect(d.weeklySales.last.profit, 200);
      expect(r.grossProfit, 200);
      expect(r.discounts, 100);
      expect(d.thisMonthRevenue, 900);
    });

    test('tax and delivery stay out of gross profit', () async {
      final p = await addProduct();
      await sell(p, 1, discount: 100, taxRate: 5, delivery: 60); // billed 1005

      final d = await dashboard();
      final r = await report();
      expect(d.thisMonthProfit, 200);
      expect(r.grossProfit, 200);
      expect(r.taxCollected, 45);
      expect(r.deliveryCharges, 60);
      expect(r.netProfit, 260);
      expect(r.billedSales, 1005);
    });

    test('full return of a discounted, taxed order: everything nets to 0', () async {
      final p = await addProduct();
      final sale = await sell(p, 1, discount: 100, taxRate: 5, delivery: 60);
      final v = returnValueFor(sale, sale.items);
      expect(v.total, 945); // goods after discount + tax; delivery kept

      final ret = await returnAndRefund(sale, 1, v.total);
      expect(ret.subtotal, 1000);
      expect(ret.discountAmount, 100);
      expect(ret.taxAmount, 45);
      expect(ret.totalAmount, 945);
      expect(ret.refundAmount, 945);

      final d = await dashboard();
      final r = await report();
      expect(d.thisMonthProfit, 0);
      expect(r.grossProfit, 0);
      expect(r.netSales, 0);
      expect(r.taxCollected, 0);
      expect(await customerDue(), 0);
      expect((await isar.customers.get(customerId))!.outstandingBalance, 0);
      expect((await isar.products.get(p.id))!.stockQty, 10);
      final payments = await isar.payments.where().findAll();
      expect(payments.map((x) => x.amount), [1005, -945]);
    });

    test('partial return: suggested refund settles it; kept item keeps its profit', () async {
      final p = await addProduct(price: 500, cost: 300);
      final sale = await sell(p, 2, discount: 100); // 900 paid, cost 600
      final v = returnValueFor(sale, [sale.items.first.copyWith(qty: 1, totalPrice: 500)]);
      expect(v.total, 450);

      await returnAndRefund(sale, 1, v.total);
      expect(await customerDue(), 0);
      expect((await dashboard()).thisMonthProfit, 150); // 450 − 300
      expect((await report()).grossProfit, 150);
      expect((await isar.products.get(p.id))!.stockQty, 9);
    });

    test('full refund of a discounted order does not eat into other dues', () async {
      final p = await addProduct();
      final sale = await sell(p, 1, discount: 100); // 900 paid
      await sell(p, 1, paid: 0); // another 1000 on credit
      await returnAndRefund(sale, 1, 900);
      // At list price the return was worth 1000, and 100 came off the credit.
      expect(await customerDue(), 1000);
      expect((await isar.customers.get(customerId))!.outstandingBalance, 1000);
    });

    test('Dashboard updates by itself after a new order', () async {
      final p = await addProduct();
      expect((await dashboard()).thisMonthProfit, 0);
      await sell(p, 1, discount: 100);
      expect((await dashboard()).thisMonthProfit, 200); // no pull-to-refresh
    });

    test('a mounted Reports tab stays live too, and agrees with the Dashboard', () async {
      final p = await addProduct();
      expect((await report()).grossProfit, 0); // Reports opened first
      await sell(p, 1, discount: 100);
      expect((await dashboard()).thisMonthProfit, 200);
      expect((await report()).grossProfit, 200);
      await sell(p, 1, discount: 100);
      expect((await dashboard()).thisMonthProfit, 400);
      expect((await report()).grossProfit, 400);
    });

    test('a preset picked yesterday still covers today, revenue and profit alike', () async {
      container.dispose();
      container = ProviderContainer(overrides: [
        isarProvider.overrideWith((ref) async => isar),
        dashboardDateRangeProvider.overrideWith(_PickedYesterday.new),
      ]);
      await sell(await addProduct(), 1); // 1000, cost 700
      final d = await dashboard();
      expect(d.thisMonthRevenue, 1000);
      expect(d.todayRevenue, 1000);
      expect(d.thisMonthProfit, 300);
    });

    test('"Pay Full" on a 7.5% tax order leaves nothing owed', () async {
      final sale = await sell(await addProduct(price: 999, cost: 500), 1, taxRate: 7.5);
      expect(sale.paymentStatus, PaymentStatus.paid);
      expect(await customerDue(), 0);
    });

    test('sub-paisa leftovers on old orders do not crash the Due Book', () async {
      // Saved before totals were rounded; "Pay Full" typed 2 decimals.
      await isar.writeTxn(() async {
        for (final (total, paid) in [(10.5315, 10.53), (10.542, 10.54), (10.5525, 10.55)]) {
          await isar.orders.put(Order(
            orderNumber: 'OLD-$total',
            customerId: customerId,
            customerName: 'Rahim',
            totalAmount: total,
            amountPaid: paid,
            paymentStatus: PaymentStatus.partial,
            orderStatus: OrderStatus.completed,
            createdAt: DateTime.now(),
          ));
        }
      });
      container.listen(duesProvider, (_, _) {});
      expect(await container.read(duesProvider.future), isEmpty);
      expect(container.read(dueSummaryProvider)?.total, 0);
    });
  });
}

/// The Dashboard's "This month", as picked yesterday and never re-tapped.
class _PickedYesterday extends DashboardDateRange {
  @override
  DashboardRange build() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return (start: DateTime(y.year, y.month, 1), end: y, preset: DateRangePreset.thisMonth);
  }
}
