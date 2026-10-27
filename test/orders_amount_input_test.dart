// Typing amounts in the order screens. A phone's number pad types its own
// region's digits and decimal point: '12,50' on a French or Brazilian
// phone (the tests run in France, where ',' is the point), '١٢٫٥' on an
// Arabic one, a Bengali keyboard's own digits on Android. The order form,
// the order detail's Record Payment and a return's refund show each amount
// as the app writes it (0-9, '.' as the point) and save the amount the
// seller meant; with the Kuwaiti Dinar, to its 3 decimals.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/number_input.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/orders/presentation/order_detail_screen.dart';
import 'package:micro_seller/features/orders/presentation/order_form_screen.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:micro_seller/features/returns/presentation/create_return_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/layout_harness.dart';

/// The order notifier without a database: records what the screens save.
class _RecordingOrders extends OrderNotifier {
  final updated = <Order>[];
  final payments = <double>[];
  final refunds = <double>[];

  @override
  Future<void> updateOrder(Order order) async => updated.add(order);

  @override
  Future<void> recordPayment(
    int orderId,
    double paymentAmount, {
    PaymentMethod? method,
    String transactionId = '',
  }) async => payments.add(paymentAmount);

  @override
  Future<void> createReturnOrder({
    required Order originalOrder,
    required List<OrderItem> returnItems,
    required ReturnReason reason,
    required double refundAmount,
    String returnNotes = '',
  }) async => refunds.add(refundAmount);
}

/// The order detail shows nothing until the database is open; nothing here
/// uses it.
class _NoDatabase implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _order = Order(
  id: 1,
  orderNumber: 'ORD-042',
  customerId: 2,
  customerName: 'Rahim Uddin',
  customerPhone: '01712345678',
  items: [
    OrderItem(
      productId: 4,
      productName: 'Rice 5kg',
      qty: 2,
      unitPrice: 450,
      totalPrice: 900,
    ),
  ],
  subtotal: 900,
  totalAmount: 900,
  amountPaid: 500,
  paymentStatus: PaymentStatus.partial,
  orderStatus: OrderStatus.confirmed,
  isRecurring: true,
  recurringIntervalDays: 30,
  createdAt: DateTime(2026, 10, 19, 10, 30),
  updatedAt: DateTime(2026, 10, 19, 10, 30),
);

/// [screen] opened from the order list, as the app shows it, so it goes back
/// there once saved. Returns what the screen saves.
Future<_RecordingOrders> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  // Tall enough that every field and button is on screen.
  setLayoutScreen(tester, 411, height: 2400);
  addTearDown(tester.view.reset);
  final orders = _RecordingOrders();
  final router = GoRouter(
    initialLocation: '/orders/screen',
    routes: [
      GoRoute(
        path: '/orders',
        builder: (_, _) => const Scaffold(body: Text('Orders')),
        routes: [GoRoute(path: 'screen', builder: (_, _) => screen)],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [orderProvider.overrideWith(() => orders), ...overrides],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  // The app's strings load asynchronously.
  await tester.pump();
  await tester.pump();
  return orders;
}

/// The text field labelled [label].
Finder _field(String label) => find.widgetWithText(TextField, label);

/// The order form's repeat interval, beside "Repeat every".
final _daysField = find.descendant(
  of: find
      .ancestor(of: find.text('Repeat every'), matching: find.byType(Row))
      .first,
  matching: find.byType(TextField),
);

String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

/// The shop's currency is [symbol], as set at startup and saved in Settings
/// (which applies it again when it loads).
void _currency(String symbol) {
  CurrencyFormatter.setSymbol(symbol);
  SharedPreferences.setMockInitialValues({'currencySymbol': symbol});
}

void main() {
  setUpAll(() => CurrencyFormatter.setSymbol('৳'));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // A French phone: its number pad's ',' is the decimal point.
    NumberInput.debugDeviceLocale = const Locale('fr', 'FR');
  });
  tearDown(() {
    NumberInput.debugDeviceLocale = null;
    CurrencyFormatter.setSymbol('৳');
  });

  testWidgets('the order form saves amounts typed in any script', (
    tester,
  ) async {
    final orders = await _pump(tester, OrderFormScreen(order: _order));
    await tester.enterText(_field('Discount'), '12,50');
    await tester.enterText(_field('Delivery Fee'), '٦٠');
    await tester.enterText(_field('Tax / VAT (%)'), '7,5');
    await tester.enterText(_field('Amount Paid'), '১০০,৫');
    await tester.enterText(_daysField, '١٤');
    await tester.pump();
    expect(_text(tester, _field('Discount')), '12.50');
    expect(_text(tester, _field('Delivery Fee')), '60');
    expect(_text(tester, _field('Tax / VAT (%)')), '7.5');
    expect(_text(tester, _field('Amount Paid')), '100.5');
    expect(_text(tester, _daysField), '14');
    // The totals follow: 7.5% of 887.50.
    expect(find.text('Tax (7.5%)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Edit Order'));
    await tester.pumpAndSettle();
    final saved = orders.updated.single;
    final totals = orderTotals(
      subtotal: 900,
      discount: 12.5,
      taxRate: 7.5,
      delivery: 60,
    );
    expect(saved.discountAmount, 12.5);
    expect(saved.deliveryFee, 60);
    expect(saved.taxAmount, totals.tax);
    expect(saved.totalAmount, totals.total);
    expect(saved.amountPaid, 100.5);
    expect(saved.recurringIntervalDays, 14);
    expect(find.text('Orders'), findsOneWidget, reason: 'back at the list');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'the order form repeats whole days up to 999, and every 30 days for an '
    'empty or 0 interval',
    (tester) async {
      for (final (typed, shown, days) in [
        ('0', '0', 30),
        ('٠', '0', 30),
        ('', '', 30),
        ('1234', '123', 123),
      ]) {
        final orders = await _pump(
          tester,
          OrderFormScreen(order: _order.copyWith(recurringIntervalDays: 7)),
        );
        await tester.enterText(_daysField, '');
        await tester.enterText(_daysField, typed);
        await tester.pump();
        expect(_text(tester, _daysField), shown, reason: typed);
        await tester.tap(find.widgetWithText(FilledButton, 'Edit Order'));
        await tester.pumpAndSettle();
        expect(
          orders.updated.single.recurringIntervalDays,
          days,
          reason: typed,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets("the order detail's Record Payment saves '12,50' as 12.5", (
    tester,
  ) async {
    final orders = await _pump(
      tester,
      OrderDetailScreen(orderId: _order.id),
      overrides: [
        isarProvider.overrideWithValue(AsyncData(_NoDatabase())),
        orderByIdProvider(_order.id).overrideWithValue(AsyncData(_order)),
      ],
    );
    await tester.tap(find.text('Record Payment'));
    await tester.pumpAndSettle();
    final amount = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(amount.first, '12,50');
    await tester.pump();
    expect(_text(tester, amount.first), '12.50');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(orders.payments, [12.5]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("editing a Kuwaiti Dinar order keeps the amounts' fils", (
    tester,
  ) async {
    _currency(CurrencyFormatter.kuwaitiDinarSymbol);
    final order = _order.copyWith(
      discountAmount: 0.125,
      deliveryFee: 1.5,
      amountPaid: 5.125,
    );
    final orders = await _pump(tester, OrderFormScreen(order: order));
    // Shown with the dinar's 3 decimals: 2 made them 0.13 and 5.13.
    expect(_text(tester, _field('Discount')), '0.125');
    expect(_text(tester, _field('Delivery Fee')), '1.500');
    expect(_text(tester, _field('Amount Paid')), '5.125');

    // Only the notes changed: the amounts are saved as they were.
    await tester.tap(find.widgetWithText(FilledButton, 'Edit Order'));
    await tester.pumpAndSettle();
    final saved = orders.updated.single;
    expect(saved.discountAmount, 0.125);
    expect(saved.deliveryFee, 1.5);
    expect(saved.amountPaid, 5.125);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("Pay Full types the total with the currency's decimals", (
    tester,
  ) async {
    for (final (symbol, expected) in [
      ('৳', '901.25'),
      (CurrencyFormatter.kuwaitiDinarSymbol, '901.250'),
    ]) {
      _currency(symbol);
      await _pump(
        tester,
        OrderFormScreen(order: _order.copyWith(deliveryFee: 1.25)),
      );
      await tester.tap(find.text('Pay Full'));
      await tester.pump();
      expect(_text(tester, _field('Amount Paid')), expected, reason: symbol);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets("a Kuwaiti Dinar return's refund shows its fils, and refunds "
      'them left as suggested', (tester) async {
    _currency(CurrencyFormatter.kuwaitiDinarSymbol);
    final orders = await _pump(
      tester,
      CreateReturnScreen(originalOrder: _order.copyWith(amountPaid: 1.125)),
    );
    // At most what was paid: 2 decimals showed 1.13.
    expect(_text(tester, _field('Refund')), '1.125');
    await tester.tap(find.text('Submit Return Request'));
    await tester.pumpAndSettle();
    expect(orders.refunds, [1.125]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("a return's refund saves '١٢٫٥' as 12.5", (tester) async {
    final orders = await _pump(
      tester,
      CreateReturnScreen(originalOrder: _order),
    );
    // Suggested: the goods' value, at most what was paid.
    expect(_text(tester, _field('Refund')), '500.00');
    await tester.enterText(_field('Refund'), '١٢٫٥');
    await tester.pump();
    expect(_text(tester, _field('Refund')), '12.5');

    await tester.tap(find.text('Submit Return Request'));
    await tester.pumpAndSettle();
    expect(orders.refunds, [12.5]);
    await tester.pumpWidget(const SizedBox());
  });
}
