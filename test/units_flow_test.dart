import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/validators.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/quantity_unit.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/services/csv_import_service.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/pdf_service.dart';
import 'package:micro_seller/data/services/report_service.dart';
import 'package:micro_seller/features/orders/providers/order_form_defaults.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:micro_seller/features/orders/providers/quick_add_provider.dart';
import 'package:micro_seller/features/products/providers/product_provider.dart';

import 'support/isar_core.dart';

/// The pieces behind the simpler order form and selling by weight: the
/// remembered defaults, quick-add ranking, stock adjustments, variants and
/// returns in kilograms, reports, the CSV import and the WhatsApp text.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(closeTestIsars);

  ProviderContainer containerFor(Isar isar) {
    final c = ProviderContainer(overrides: [isarProvider.overrideWith((ref) async => isar)]);
    addTearDown(c.dispose);
    return c;
  }

  OrderItem line(Product p, double qty, {VariantCombination? combo}) {
    final price = p.sellingPrice + (combo?.priceAdjustment ?? 0);
    return OrderItem(
      productId: p.id,
      productName: p.name,
      qty: qty,
      unit: p.unit,
      unitPrice: price,
      costPrice: p.costPrice,
      totalPrice: lineTotal(price, qty),
      variantCombinationKey: combo?.combinationKey ?? '',
      variantDisplayLabel: combo?.displayLabel ?? '',
    );
  }

  Order orderOf(List<OrderItem> items,
      {String number = 'ORD-001', OrderStatus status = OrderStatus.confirmed, bool isReturn = false, DateTime? at}) {
    final total = items.fold(0.0, (sum, i) => sum + i.totalPrice);
    return Order(
      orderNumber: number,
      items: items,
      subtotal: total,
      totalAmount: total,
      amountPaid: total,
      paymentStatus: PaymentStatus.paid,
      orderStatus: status,
      isReturn: isReturn,
      createdAt: at ?? DateTime.now(),
    );
  }

  group('OrderFormDefaults', () {
    test('nothing saved: cash and Confirmed', () async {
      final d = await OrderFormDefaults.load();
      expect(d.paymentMethod, PaymentMethod.cash);
      expect(d.orderStatus, OrderStatus.confirmed);
    });

    test('remembers the method and a form status, round trip', () async {
      await OrderFormDefaults.remember(paymentMethod: PaymentMethod.bank, orderStatus: OrderStatus.pending);
      final d = await OrderFormDefaults.load();
      expect(d.paymentMethod, PaymentMethod.bank);
      expect(d.orderStatus, OrderStatus.pending);
    });

    test('a status the form doesn\'t offer is not remembered', () async {
      await OrderFormDefaults.remember(paymentMethod: PaymentMethod.card, orderStatus: OrderStatus.shipped);
      final d = await OrderFormDefaults.load();
      expect(d.paymentMethod, PaymentMethod.card);
      expect(d.orderStatus, OrderStatus.confirmed);
    });

    test('foreign or wrongly typed values fall back', () async {
      SharedPreferences.setMockInitialValues({
        OrderFormDefaults.keyPaymentMethod: 'cheque',
        OrderFormDefaults.keyOrderStatus: 3,
      });
      final d = await OrderFormDefaults.load();
      expect(d.paymentMethod, PaymentMethod.cash);
      expect(d.orderStatus, OrderStatus.confirmed);
      SharedPreferences.setMockInitialValues({OrderFormDefaults.keyOrderStatus: 'completed'});
      expect((await OrderFormDefaults.load()).orderStatus, OrderStatus.confirmed);
    });
  });

  group('quick add', skip: isarSkipReason, () {
    test('most often sold first; no returns, cancelled, inactive or empty products; at most 8', () async {
      final isar = await openTestIsar('quick_add');
      late List<Product> p;
      await isar.writeTxn(() async {
        final ids = await isar.products.putAll([
          for (var i = 0; i < 12; i++) Product(name: 'P$i', sellingPrice: 10, stockQty: 5),
        ]);
        p = (await isar.products.getAll(ids)).cast<Product>();
        // P10 sold out, P11 hidden in the Recycle Bin.
        await isar.products.putAll([p[10].copyWith(stockQty: 0), p[11].copyWith(isActive: false)]);
        p = (await isar.products.getAll(ids)).cast<Product>();

        final orders = <Order>[];
        // P0 in 5 orders, P1 in 4 (one order with qty 50 counts once), …
        for (var n = 0; n < 5; n++) {
          orders.add(orderOf([line(p[0], 1), if (n < 4) line(p[1], n == 0 ? 50 : 1)], number: 'O$n'));
        }
        for (var i = 2; i <= 11; i++) {
          orders.add(orderOf([line(p[i], 1), line(p[i], 1)], number: 'X$i'));
        }
        // Many returns and a cancelled order of P9 don't make it popular.
        for (var n = 0; n < 6; n++) {
          orders.add(orderOf([line(p[9], 1)], number: 'R$n', isReturn: true));
          orders.add(orderOf([line(p[9], 1)], number: 'C$n', status: OrderStatus.cancelled));
        }
        await isar.orders.putAll(orders);
      });

      final top = topRecentProductsJob(isar);
      expect(top.length, kQuickAddCount);
      expect(top.take(2).map((e) => e.name), ['P0', 'P1']);
      final names = top.map((e) => e.name).toSet();
      expect(names, isNot(contains('P10')), reason: 'out of stock');
      expect(names, isNot(contains('P11')), reason: 'inactive');
    });

    test('no sales yet: no chips', () async {
      final isar = await openTestIsar('quick_add_empty');
      expect(topRecentProductsJob(isar), isEmpty);
    });

    test('a variant product counts while any combination has stock', () async {
      final isar = await openTestIsar('quick_add_variant');
      await isar.writeTxn(() async {
        final id = await isar.products.put(Product(name: 'Shirt', sellingPrice: 500, variantCombinations: [
          VariantCombination(combinationKey: 'Size:L', stockQty: 2),
        ]));
        final shirt = (await isar.products.get(id))!;
        await isar.orders.put(orderOf([line(shirt, 1)]));
      });
      expect(topRecentProductsJob(isar).single.name, 'Shirt');
    });
  });

  group('kilograms through the notifiers', skip: isarSkipReason, () {
    test('a stock adjustment of +2.5 kg and a damage of 0.125 kg', () async {
      final isar = await openTestIsar('adjust');
      late int id;
      await isar.writeTxn(() async {
        id = await isar.products.put(Product(name: 'Rice', sellingPrice: 90, stockQty: 10, unit: QuantityUnit.kg));
      });
      final c = containerFor(isar);
      await c.read(productProvider.notifier).adjustStock(id, 2.5, 'Delivery', StockMovementType.restock);
      await c.read(productProvider.notifier).adjustStock(id, -0.125, 'Spilt', StockMovementType.damage);
      expect((await isar.products.get(id))!.stockQty, 12.375);
      final moves = await isar.stockMovements.where().findAll();
      expect(moves.map((m) => m.qty), [2.5, -0.125]);
    });

    test('an adjustment never takes stock below 0', () async {
      final isar = await openTestIsar('adjust_floor');
      late int id;
      await isar.writeTxn(() async {
        id = await isar.products.put(Product(name: 'Oil', sellingPrice: 180, stockQty: 0.5, unit: QuantityUnit.litre));
      });
      await containerFor(isar).read(productProvider.notifier).adjustStock(id, -2, '', StockMovementType.damage);
      expect((await isar.products.get(id))!.stockQty, 0);
    });

    test('a combination sold by the metre: 2.5 m of 10 m, cancelled back', () async {
      final isar = await openTestIsar('variant_metre');
      late Product cloth;
      await isar.writeTxn(() async {
        final id = await isar.products.put(Product(
          name: 'Cotton',
          sellingPrice: 200,
          stockQty: 15,
          unit: QuantityUnit.metre,
          variantCombinations: [
            VariantCombination(combinationKey: 'Color:Red', displayLabel: 'Color: Red', stockQty: 10, priceAdjustment: 20),
            VariantCombination(combinationKey: 'Color:Blue', displayLabel: 'Color: Blue', stockQty: 5),
          ],
        ));
        cloth = (await isar.products.get(id))!;
      });
      final red = cloth.variantCombinations.first;
      final notifier = containerFor(isar).read(orderProvider.notifier);
      final orderId = await notifier.createOrder(orderOf([line(cloth, 2.5, combo: red)]));

      var after = (await isar.products.get(cloth.id))!;
      expect(after.findCombination('Color:Red')!.stockQty, 7.5);
      expect(after.findCombination('Color:Blue')!.stockQty, 5);
      expect(after.stockQty, 12.5);
      expect((await isar.orders.get(orderId))!.totalAmount, 550, reason: '2.5 m × (200 + 20)');

      await notifier.updateStatus(orderId, OrderStatus.cancelled);
      after = (await isar.products.get(cloth.id))!;
      expect(after.findCombination('Color:Red')!.stockQty, 10);
      expect(after.stockQty, 15);
    });

    test('returning 0.5 kg of a 1.25 kg sale puts 0.5 kg back on approval', () async {
      final isar = await openTestIsar('return_kg');
      late Product fish;
      await isar.writeTxn(() async {
        final id = await isar.products.put(
            Product(name: 'Rui fish', sellingPrice: 600, costPrice: 450, stockQty: 5, unit: QuantityUnit.kg));
        fish = (await isar.products.get(id))!;
      });
      final notifier = containerFor(isar).read(orderProvider.notifier);
      final saleId = await notifier.createOrder(orderOf([line(fish, 1.25)]));
      final sale = (await isar.orders.get(saleId))!;

      await notifier.createReturnOrder(
        originalOrder: sale,
        returnItems: [sale.items.single.copyWith(qty: 0.5, totalPrice: lineTotal(600, 0.5))],
        reason: ReturnReason.values.first,
        refundAmount: 300,
      );
      final ret = (await isar.orders.filter().isReturnEqualTo(true).findFirst())!;
      expect(ret.totalAmount, 300, reason: '0.5 kg at ৳600/kg');
      expect((await isar.products.get(fish.id))!.stockQty, 3.75, reason: 'requested: nothing back yet');

      await notifier.approveReturn(ret.id);
      expect((await isar.products.get(fish.id))!.stockQty, 4.25);
    });
  });

  group('reports', () {
    test('kilograms sold add up without drift and print as quantities, not money', () {
      final fish = Product(id: 1, name: 'Rui fish', sellingPrice: 600, costPrice: 450, stockQty: 3, unit: QuantityUnit.kg);
      final now = DateTime.now();
      final orders = [
        for (var i = 0; i < 10; i++) orderOf([line(fish, 0.1)], number: 'O$i', at: now),
        orderOf([line(fish, 0.25)], number: 'X', at: now),
      ];
      final report = buildInventoryReport(
        products: [fish],
        movements: [StockMovement(productId: 1, type: StockMovementType.sale, qty: -1.25, createdAt: now)],
        orders: orders,
        start: now.subtract(const Duration(days: 1)),
        end: now.add(const Duration(days: 1)),
      );
      expect(report.bestSellers['Rui fish'], 1.25);
      expect(report.movementQty[StockMovementType.sale], 1.25);
      expect(report.stockValueAtPrice, 1800);

      final tables = report.toTables((k) => k);
      final best = tables.firstWhere((t) => t.title == 'bestSellers');
      expect(best.rows.single[1], isA<ReportQty>());
      expect(formatCell(best.rows.single[1]), '1.25');
      expect(formatCell(const ReportQty(3)), '3');
      expect(formatCell(1.25), CurrencyFormatter.format(1.25), reason: 'a bare double is still money');
    });
  });

  group('CSV import', () {
    const header = 'Name,SKU,Category,Selling Price,Cost Price,Stock,Threshold,Unit\n';

    test('a Unit column: decimals for kg, whole numbers for pieces', () {
      final result = CsvImportService.parseProductCsv('${header}Rice,R1,Grain,90,70,12.5,2.25,kg\n'
          'Soap,S1,Bath,40,25,7.6,3,pcs\n'
          'Oil,O1,,180,150,4.75,1,Liter\n'
          'Cloth,C1,,200,150,30,5,meter\n');
      expect(result.errors, isEmpty);
      final [rice, soap, oil, cloth] = result.products;
      expect((rice.unit, rice.stockQty, rice.lowStockThreshold), (QuantityUnit.kg, 12.5, 2.25));
      expect((soap.unit, soap.stockQty), (QuantityUnit.piece, 8.0));
      expect((oil.unit, oil.stockQty), (QuantityUnit.litre, 4.75));
      expect(cloth.unit, QuantityUnit.metre);
    });

    test('an older file without a Unit column imports pieces as before', () {
      final result = CsvImportService.parseProductCsv(
          'Name,SKU,Category,Selling Price,Cost Price,Stock,Threshold\nSoap,S1,Bath,40,25,7,3\n');
      expect(result.products.single.unit, QuantityUnit.piece);
      expect(result.products.single.stockQty, 7);
    });

    test('rows it can\'t use are named', () {
      final result = CsvImportService.parseProductCsv('$header,S1,,40\nOnly,two\n');
      expect(result.products, isEmpty);
      expect(result.errors, hasLength(2));
    });
  });

  group('texts sent to customers', () {
    test('the WhatsApp text writes kilograms and pieces', () {
      final fish = Product(id: 1, name: 'Rui fish', sellingPrice: 600, unit: QuantityUnit.kg);
      final soap = Product(id: 2, name: 'Soap', sellingPrice: 40);
      final text = PdfService().generateWhatsAppText(
        orderOf([line(fish, 1.25), line(soap, 2)]),
        currencySymbol: '৳',
      );
      expect(text, contains('Rui fish x1.25 kg'));
      expect(text, contains('Soap x2 —'));
      expect(text, isNot(contains('2.0')));
    });
  });

  group('Validators.nonNegativeQty', () {
    test('decimals only where the unit takes them', () {
      expect(Validators.nonNegativeQty('1.25', decimal: true), isNull);
      expect(Validators.nonNegativeQty('1,25', decimal: true), isNull, reason: 'a comma decimal point');
      expect(Validators.nonNegativeQty('-1', decimal: true), isNotNull);
      expect(Validators.nonNegativeQty('', decimal: true), isNotNull);
      expect(Validators.nonNegativeQty('1.5', decimal: false), isNotNull);
      expect(Validators.nonNegativeQty('3', decimal: false), isNull);
    });
  });
}
