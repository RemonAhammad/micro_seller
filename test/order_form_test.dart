import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/quantity_unit.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/orders/presentation/order_form_screen.dart';
import 'package:micro_seller/features/orders/providers/order_form_defaults.dart';
import 'package:micro_seller/features/orders/providers/quick_add_provider.dart';

import 'support/isar_core.dart';

/// The order form on a real database. Isar answers from its own threads, so
/// every step lets real time pass ([settle]) before pumping.
void main() {
  late Isar isar;
  late Product soap;
  late Product fish;
  late Product shirt;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(closeTestIsars);

  Future<void> settle(WidgetTester tester) async {
    // Each await inside an Isar transaction needs a real event-loop turn
    // (runAsync) and then a pump to run what it resumed.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    // Bounded: a spinner or the stock stream never "settles".
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openDb(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      isar = await openTestIsar(name);
      await isar.writeTxn(() async {
        final ids = await isar.products.putAll([
          Product(name: 'Soap', sellingPrice: 40, costPrice: 25, stockQty: 10),
          Product(name: 'Rui fish', sellingPrice: 600, costPrice: 450, stockQty: 5, unit: QuantityUnit.kg),
          Product(
            name: 'Shirt',
            sellingPrice: 500,
            variantAttributes: const [],
            variantCombinations: [
              VariantCombination(combinationKey: 'Size:L', displayLabel: 'Size: L', stockQty: 4, priceAdjustment: 50),
            ],
          ),
        ]);
        await isar.customers.put(Customer(name: 'Karim', phone: '01711000000'));
        soap = (await isar.products.get(ids[0]))!;
        fish = (await isar.products.get(ids[1]))!;
        shirt = (await isar.products.get(ids[2]))!;
      });
    });
  }

  Future<void> pumpForm(WidgetTester tester, {Order? order, List<Product>? quick}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('orders list')),
          routes: [GoRoute(path: 'add', builder: (_, _) => OrderFormScreen(order: order))],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isarProvider.overrideWith((ref) async => isar),
        quickAddProductsProvider.overrideWith((ref) async => quick ?? [soap, fish, shirt]),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await settle(tester);
  }

  Future<List<Order>> orders(WidgetTester tester) async =>
      (await tester.runAsync(() => isar.orders.where().findAll()))!;

  Future<Product> reload(WidgetTester tester, Product p) async =>
      (await tester.runAsync(() => isar.products.get(p.id)))!;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await settle(tester);
  }

  /// The quantity sheet's own Add / Update (the cart's header has an Add too).
  Future<void> confirmSheet(WidgetTester tester, String label) async {
    final button = find.descendant(of: find.byType(BottomSheet), matching: find.text(label));
    await tester.tap(button.last);
    await settle(tester);
  }

  group('order form', skip: isarSkipReason, () {
    testWidgets('a new order: walk-in, More options folded, Paid in full and Credit buttons', (tester) async {
      await openDb(tester, 'form_defaults');
      await pumpForm(tester);

      expect(find.text('Walk-in customer'), findsOneWidget);
      expect(find.text('More options'), findsOneWidget);
      expect(find.text('Delivery Fee'), findsNothing, reason: 'folded away');
      expect(find.text('Paid in full'), findsOneWidget);
      expect(find.text('Credit / partial'), findsOneWidget);
      expect(find.text('New Order'), findsOneWidget, reason: 'the app bar; no save button until credit');

      await tapText(tester, 'More options');
      expect(find.text('Delivery Fee'), findsOneWidget);
    });

    testWidgets('a walk-in cash sale in two taps: quick add, Paid in full', (tester) async {
      await openDb(tester, 'form_walk_in');
      await pumpForm(tester);

      await tapText(tester, 'Soap');
      await tapText(tester, 'Soap');
      await tapText(tester, 'Paid in full');

      expect(find.textContaining('ORD-001'), findsOneWidget);
      final saved = (await orders(tester)).single;
      expect(saved.customerId, 0);
      expect(saved.customerName, '');
      expect(saved.items.single.qty, 2);
      expect(saved.totalAmount, 80);
      expect(saved.amountPaid, 80);
      expect(saved.paymentStatus, PaymentStatus.paid);
      expect(saved.orderStatus, OrderStatus.confirmed);
      expect(saved.paymentMethod, PaymentMethod.cash);
      expect((await reload(tester, soap)).stockQty, 8, reason: 'confirmed: stock left at once');

      await tapText(tester, 'Done');
      expect(find.text('orders list'), findsOneWidget);
    });

    testWidgets('Paid in full with nothing in the cart saves nothing', (tester) async {
      await openDb(tester, 'form_empty');
      await pumpForm(tester);
      await tapText(tester, 'Paid in full');
      expect(find.text('Add at least one product'), findsOneWidget);
      expect(await orders(tester), isEmpty);
    });

    testWidgets('credit without a customer asks for one and saves nothing', (tester) async {
      await openDb(tester, 'form_credit');
      await pumpForm(tester);
      await tapText(tester, 'Soap');

      await tapText(tester, 'Credit / partial');
      expect(find.text('Karim'), findsOneWidget, reason: 'the customer picker opened');
      // Dismiss the picker without choosing.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);

      // Credit mode: the save button replaces the pair.
      expect(find.text('Paid in full'), findsNothing);
      await tapText(tester, 'New Order');
      expect(
        find.text('Choose a customer for a sale on credit, so the due goes to their Due Book'),
        findsOneWidget,
      );
      expect(await orders(tester), isEmpty);
    });

    testWidgets('credit with a customer saves an unpaid order for them', (tester) async {
      await openDb(tester, 'form_credit_customer');
      await pumpForm(tester);
      await tapText(tester, 'Soap');
      await tapText(tester, 'Credit / partial');
      await tapText(tester, 'Karim');

      expect(find.text('Karim'), findsOneWidget, reason: 'shown as the customer');
      await tapText(tester, 'New Order');
      await tapText(tester, 'Done');

      final saved = (await orders(tester)).single;
      expect(saved.customerName, 'Karim');
      expect(saved.amountPaid, 0);
      expect(saved.paymentStatus, PaymentStatus.unpaid);
      final karim = (await tester.runAsync(() => isar.customers.where().findFirst()))!;
      expect(karim.outstandingBalance, 40, reason: 'the due went to their Due Book');
    });

    testWidgets('the last payment method and status are remembered for the next order', (tester) async {
      SharedPreferences.setMockInitialValues({
        OrderFormDefaults.keyPaymentMethod: 'card',
        OrderFormDefaults.keyOrderStatus: 'pending',
      });
      await openDb(tester, 'form_remember');
      await pumpForm(tester);

      final card = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Card'));
      expect(card.selected, isTrue);
      await tester.scrollUntilVisible(find.text('More options'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Pending'), findsWidgets, reason: 'named on the folded More options');
      await tester.scrollUntilVisible(find.text('MFS'), -200, scrollable: find.byType(Scrollable).first);

      await tapText(tester, 'MFS');
      await tapText(tester, 'Soap');
      await tapText(tester, 'Paid in full');

      final saved = (await orders(tester)).single;
      expect(saved.paymentMethod, PaymentMethod.mfs);
      expect(saved.orderStatus, OrderStatus.pending);
      expect((await reload(tester, soap)).stockQty, 10, reason: 'pending: stock not taken');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(OrderFormDefaults.keyPaymentMethod), 'mfs');
      expect(prefs.getString(OrderFormDefaults.keyOrderStatus), 'pending');
    });

    testWidgets('a weighed product asks how much: 1.25 kg of fish', (tester) async {
      await openDb(tester, 'form_weighed');
      await pumpForm(tester);

      await tapText(tester, 'Rui fish');
      expect(find.text('৳600.00 / kg').evaluate().isNotEmpty || find.text('\$600 / kg').evaluate().isNotEmpty,
          isTrue, reason: 'the quantity sheet shows the price per kg');
      await tester.enterText(find.byType(TextField).last, '1.25');
      await settle(tester);
      await confirmSheet(tester, 'Add');

      expect(find.textContaining('1.25 kg'), findsWidgets);
      await tapText(tester, 'Paid in full');

      final saved = (await orders(tester)).single;
      expect(saved.items.single.qty, 1.25);
      expect(saved.items.single.unit, QuantityUnit.kg);
      expect(saved.totalAmount, 750);
      expect((await reload(tester, fish)).stockQty, 3.75);
    });

    testWidgets('a weighed product by amount: 200 worth of fish is 0.333 kg', (tester) async {
      await openDb(tester, 'form_by_amount');
      await pumpForm(tester);

      await tapText(tester, 'Rui fish');
      await tapText(tester, 'By amount');
      await tester.enterText(find.byType(TextField).last, '200');
      await settle(tester);
      await confirmSheet(tester, 'Add');
      await tapText(tester, 'Paid in full');

      final saved = (await orders(tester)).single;
      expect(saved.items.single.qty, 0.333);
      expect(saved.totalAmount, 199.8);
      expect((await reload(tester, fish)).stockQty, 4.667);
    });

    testWidgets('a variant product\'s quick add opens its combinations', (tester) async {
      await openDb(tester, 'form_variant');
      await pumpForm(tester);

      await tapText(tester, 'Shirt');
      expect(find.text('Size: L'), findsNothing, reason: 'collapsed under the product');
      await tapText(tester, '1 combination');
      expect(find.text('Size: L'), findsOneWidget);
    });

    testWidgets('editing a walk-in order keeps it walk-in, with the save button', (tester) async {
      await openDb(tester, 'form_edit');
      final order = Order(
        id: 7,
        orderNumber: 'ORD-007',
        items: [
          OrderItem(productId: 1, productName: 'Soap', qty: 1, unitPrice: 40, totalPrice: 40),
        ],
        subtotal: 40,
        totalAmount: 40,
        amountPaid: 40,
        paymentStatus: PaymentStatus.paid,
        orderStatus: OrderStatus.confirmed,
        createdAt: DateTime(2026, 11, 1),
      );
      await pumpForm(tester, order: order);

      expect(find.text('Walk-in customer'), findsOneWidget);
      expect(find.text('Paid in full'), findsWidgets, reason: 'the payment line says it is paid');
      expect(find.text('Credit / partial'), findsNothing);
      expect(find.text('Edit Order'), findsWidgets, reason: 'title and save button');
    });
  });
}
