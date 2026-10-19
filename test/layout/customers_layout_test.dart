import 'package:fl_chart/fl_chart.dart' show BarChart;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/date_formatter.dart';
import 'package:micro_seller/data/models/cash_register.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/features/cash_register/providers/cash_register_provider.dart';
import 'package:micro_seller/features/customers/presentation/customer_detail_screen.dart';
import 'package:micro_seller/features/customers/presentation/customer_form_screen.dart';
import 'package:micro_seller/features/customers/presentation/customer_list_screen.dart';
import 'package:micro_seller/features/customers/presentation/due_book_screen.dart';
import 'package:micro_seller/features/customers/presentation/widgets/due_actions.dart';
import 'package:micro_seller/features/customers/providers/customer_detail_providers.dart';
import 'package:micro_seller/features/customers/providers/customer_provider.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:micro_seller/features/returns/presentation/create_return_screen.dart';
import 'package:micro_seller/features/returns/presentation/returns_screen.dart';

import '../support/layout_harness.dart';

// Layout of the Customers, Due Book and Returns screens under the Display
// size / Text size settings: clean from the narrowest layout (320 dp) to a
// large phone font (150%), with worst-case data (long names, big amounts,
// long numbers) and long translations, and unchanged at 100% text on a
// normal phone wherever it laid out cleanly before.

const _eps = 0.01;

/// Latin-script languages with long labels: measured with real Roboto
/// widths, unlike scripts the test fonts don't carry.
const _longLangs = ['pt', 'fr'];

/// The app's light theme as a phone draws it. The theme's button and app bar
/// title styles name no font family: a phone draws those in its system font
/// (Roboto on Android), but a test would draw them in its square test font,
/// far wider. Naming Roboto there measures them as on a phone.
final ThemeData _phoneTheme = () {
  final theme = AppTheme.lightTheme;
  ButtonStyle? roboto(ButtonStyle? style) => style?.copyWith(
        textStyle: WidgetStateProperty.resolveWith((states) => style.textStyle
            ?.resolve(states)
            ?.copyWith(fontFamily: 'Roboto')),
      );
  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle:
          theme.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto'),
    ),
    filledButtonTheme:
        FilledButtonThemeData(style: roboto(theme.filledButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: roboto(theme.outlinedButtonTheme.style)),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: roboto(theme.elevatedButtonTheme.style)),
  );
}();

// ─── Data ────────────────────────────────────────────────────────────────

const _longName = 'Mohammad Abdur Rahman Chowdhury Trading Co.';
const _longPhone = '+880 1712-345678';
const _address =
    'House 12, Road 5, Block C, Mirpur DOHS, Dhaka 1216, Bangladesh';
final _now = DateTime.now();

/// Every number at its worst: a long name, a 5-digit order count and
/// eight-digit amounts.
final _big = Customer(
  id: 7,
  name: _longName,
  phone: _longPhone,
  address: _address,
  notes: 'Prefers delivery after 6 PM; pays by bKash; ask for the warehouse '
      'manager at the back gate',
  tag: CustomerTag.vip,
  totalOrders: 12345,
  totalSpent: 12345678.9,
  outstandingBalance: 1234567.89,
  createdAt: DateTime(2024, 1, 15),
);

/// An everyday customer.
final _karim = Customer(
  id: 9,
  name: 'Karim Uddin',
  phone: '01712345678',
  address: 'Mirpur 10, Dhaka',
  tag: CustomerTag.regular,
  totalOrders: 5,
  totalSpent: 12500,
  outstandingBalance: 2000,
  createdAt: DateTime(2025, 3, 2),
);

final _rahim = Customer(id: 8, name: 'Rahim');

OrderItem _item(int k, {int qty = 1234}) => OrderItem(
      productId: k + 1,
      productName: 'Premium Organic Basmati Rice Extra Long Grain $k',
      productSku: 'SKU-PREMIUM-BASMATI-000$k-XL',
      qty: qty,
      unitPrice: 12345.67,
      totalPrice: 12345.67 * qty,
      variantDisplayLabel: 'Size: Extra Large / Color: Midnight Blue',
      variantCombinationKey: 'Color:Midnight Blue/Size:Extra Large',
    );

Order _order(int i, Customer c,
        {double total = 12345678.9, double paid = 0, int daysAgo = 90}) =>
    Order(
      id: 1000 + i,
      orderNumber: 'ORD-${100000 + i}',
      customerId: c.id,
      customerName: c.name,
      customerPhone: c.phone,
      items: [for (var k = 0; k < 3; k++) _item(k)],
      subtotal: total,
      totalAmount: total,
      amountPaid: paid,
      paymentStatus: paid == 0 ? PaymentStatus.unpaid : PaymentStatus.partial,
      orderStatus: OrderStatus.values[i % OrderStatus.values.length],
      createdAt: _now.subtract(Duration(days: daysAgo)),
    );

final _bigOrders = [
  for (var i = 0; i < 6; i++)
    _order(i, _big, paid: i.isEven ? 0 : 2345678.9, daysAgo: 10 + 20 * i),
];

CustomerDue _due(Customer c, double total, int daysAgo, {DateTime? paid}) =>
    CustomerDue(
      customer: c,
      orderDues: [OrderDue(_order(c.id, c, total: total, daysAgo: daysAgo), total)],
      totalDue: total,
      lastPaymentAt: paid,
    );

/// The Due Book at its worst: a 9-digit total, several overdue orders.
final _worstDues = [
  CustomerDue(
    customer: _big,
    // Oldest first, as the Due Book lists them.
    orderDues: [
      for (final o in _bigOrders.reversed) OrderDue(o, 12345678.9),
    ],
    totalDue: 123456789.01,
    lastPaymentAt: _now.subtract(const Duration(days: 400)),
  ),
  _due(_karim, 1250, 40),
  _due(Customer(id: 10, name: 'Karim Uddin Ahmed Bhuiyan Enterprise'),
      99999.99, 5,
      paid: _now.subtract(const Duration(hours: 3))),
];

/// An everyday Due Book.
final _everydayDues = [_due(_karim, 1250, 40), _due(_rahim, 2000, 70)];

final _payments = [
  for (var i = 0; i < 4; i++)
    Payment(
      id: i + 1,
      customerId: 7,
      orderId: 1000 + i,
      amount: i.isEven ? 12345678.9 : -1234567.89,
      method: PaymentMethod.values[i % PaymentMethod.values.length],
      transactionId: i == 0 ? 'TXN-8F3K29XQ7Z' : '',
      paidAt: _now.subtract(Duration(days: i)),
    ),
];

/// A return of every reason × status, as an everyday return (short numbers,
/// a short name, a small refund) and at its worst.
final _returns = [
  for (final (i, status) in ReturnStatus.values.indexed)
    for (final (j, reason) in ReturnReason.values.indexed)
      for (final worst in [false, true])
        Order(
          id: 2000 + i * 100 + j * 10 + (worst ? 1 : 0),
          orderNumber: worst ? 'RET-${100000 + i * 10 + j}' : 'RET-00$j',
          customerId: 7,
          customerName: worst ? _longName : (j == 2 ? '' : 'Rahim'),
          isReturn: true,
          originalOrderId: worst ? 123456 : (j == 4 ? 0 : 7),
          returnStatus: status,
          returnReason: reason,
          refundAmount: worst ? 12345678.9 : 250,
          items: [_item(0, qty: worst ? 1234 : 1)],
          createdAt: _now,
        ),
];

List<Override> _overrides({
  List<CustomerDue>? dues,
  List<Customer>? customers,
}) =>
    [
      for (final c in [_big, _karim]) ...[
        customerByIdProvider(c.id).overrideWithValue(AsyncValue.data(c)),
        customerMonthlySpendingProvider(c.id).overrideWithValue(AsyncValue.data({
          for (var i = 5; i >= 0; i--)
            DateTime(_now.year, _now.month - i, 1):
                c == _big ? 12345678.9 * (i + 1) : 2500.0 * i,
        })),
        customerPaymentsProvider(c.id).overrideWithValue(
            AsyncValue.data(c == _big ? _payments : const <Payment>[])),
        customerOrdersProvider(c.id).overrideWithBuild((ref, notifier) =>
            Stream.value(CustomerOrdersPage(c == _big ? _bigOrders : const [],
                hasMore: false))),
      ],
      duesProvider.overrideWithValue(AsyncValue.data(dues ?? _worstDues)),
      customersProvider.overrideWithValue(
          AsyncValue.data(customers ?? [_big, _rahim, _karim])),
      returnOrdersProvider.overrideWithValue(AsyncValue.data(_returns)),
      openRegisterProvider
          .overrideWithValue(AsyncValue.data(CashRegister(id: 1))),
    ];

// ─── Harness ─────────────────────────────────────────────────────────────

/// Pumps [screen] the way the app shows it on a phone: in a shell branch's
/// Navigator beside the sidebar rail (so a bottom sheet opens beside the
/// rail), with the app's theme, [lang] strings and [textScale] applied over
/// the whole app, and lets list entrances finish.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  double textScale = 1,
  String lang = 'en',
  bool rtl = false,
  List<Override>? overrides,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: overrides ?? _overrides(),
    child: MaterialApp(
      theme: _phoneTheme,
      locale: Locale(lang),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Row(
        children: [
          const SizedBox(width: kRailWidth),
          Expanded(
            child: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Navigator(
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => screen),
              ),
            ),
          ),
        ],
      ),
    ),
  ));
  // The strings load asynchronously; list rows fade in over ~1 s, and an
  // overflow is only reported once a row paints.
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Runs [body] at every layout width × text scale (× [langs]), clearing the
/// screen after each.
Future<void> _forEachLayout(
  WidgetTester tester,
  Future<void> Function(String where, double width, double textScale,
          String lang)
      body, {
  double height = 800,
  List<String> langs = const ['en'],
}) async {
  addTearDown(tester.view.reset);
  for (final lang in langs) {
    for (final width in kLayoutWidths) {
      for (final t in kLayoutTextScales) {
        setLayoutScreen(tester, width, height: height);
        await body('$lang, ${width.toInt()} dp at ${t}x', width, t, lang);
        await tester.pumpWidget(const SizedBox());
        await _settle(tester);
      }
    }
  }
}

/// The lines [p] is laid out on, by their top edges.
int _lineCount(RenderParagraph p) => p
    .getBoxesForSelection(TextSelection(
        baseOffset: 0, extentOffset: p.text.toPlainText().length))
    .map((b) => b.top.round())
    .toSet()
    .length;

/// [finder]'s texts are each drawn whole on one line: not wrapped, not cut
/// short (a number may be shrunk to fit).
void _expectOneLine(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    expect(p.didExceedMaxLines, isFalse, reason: '$where: "$text" cut short');
    expect(_lineCount(p), 1, reason: '$where: "$text" wrapped');
  }
}

/// Every line break in [finder]'s texts falls between words: a box too
/// narrow for a word breaks it across lines without reporting an overflow.
void _expectWholeWords(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    for (final word in RegExp(r'\S+').allMatches(text)) {
      final tops = p
          .getBoxesForSelection(
              TextSelection(baseOffset: word.start, extentOffset: word.end))
          .map((b) => b.top.round())
          .toSet();
      expect(tops.length, lessThanOrEqualTo(1),
          reason: '$where: "${word[0]}" broken in "$text"');
    }
  }
}

/// [finder]'s text is drawn at its laid-out size (no FittedBox shrink).
bool _drawnAtFullSize(WidgetTester tester, Finder finder) =>
    (tester.getRect(finder).width - tester.getSize(finder).width).abs() < _eps;

String _money(double amount) => CurrencyFormatter.format(amount);

void main() {
  setUpAll(() async {
    await loadRoboto();
    CurrencyFormatter.setSymbol('৳');
  });

  testWidgets('the customer list lays out its cards cleanly', (tester) async {
    requireRoboto();
    await _forEachLayout(tester, (where, width, t, lang) async {
      await _pump(tester, const CustomerListScreen(), textScale: t, lang: lang);
      expectCleanLayout(tester, where);
      // Counts, amounts and phone numbers stay whole on one line.
      for (final text in [
        _money(_big.totalSpent),
        _money(_big.outstandingBalance),
        _longPhone,
        _karim.phone,
        _money(_karim.totalSpent),
      ]) {
        _expectOneLine(tester, find.text(text), '$where: $text');
      }
      _expectOneLine(tester, find.textContaining('12345 '), where);

      // Unchanged where the stats fit before: side by side at full size.
      if (width == 411 && t == 1 && lang == 'en') {
        final stats = [
          find.text('5 orders'),
          find.text(_money(_karim.totalSpent)),
          find.text(_money(_karim.outstandingBalance)),
        ];
        for (final stat in stats) {
          expect(_drawnAtFullSize(tester, stat), isTrue, reason: where);
          expect(tester.getRect(stat).top,
              closeTo(tester.getRect(stats.first).top, _eps),
              reason: where);
        }
      }
    }, height: 1000, langs: ['en', ..._longLangs]);
  });

  testWidgets('the customer list empty state lays out cleanly',
      (tester) async {
    await _forEachLayout(tester, (where, width, t, lang) async {
      await _pump(tester, const CustomerListScreen(),
          textScale: t,
          overrides: _overrides(customers: const []));
      expectCleanLayout(tester, where);
    });
  });

  testWidgets('the customer form keeps its type labels whole',
      (tester) async {
    requireRoboto();
    await _forEachLayout(tester, (where, width, t, lang) async {
      for (final screen in [
        const CustomerFormScreen(),
        CustomerFormScreen(customer: _big),
      ]) {
        await _pump(tester, screen, textScale: t, lang: lang);
        expectCleanLayout(tester, where);
        final tags = [
          for (final tag in ['New', 'Regular', 'VIP'])
            if (lang == 'en') find.text(tag),
        ];
        for (final tag in tags) {
          _expectOneLine(tester, tag, where);
          if (width >= 360 && t == 1) {
            expect(_drawnAtFullSize(tester, tag), isTrue, reason: where);
          }
        }
      }
    }, height: 1600, langs: ['en', ..._longLangs]);
  });

  group('customer detail', () {
    testWidgets('lays out cleanly with every number at its worst',
        (tester) async {
      requireRoboto();
      await _forEachLayout(tester, (where, width, t, lang) async {
        await _pump(tester, const CustomerDetailScreen(customerId: 7),
            textScale: t, lang: lang);
        expectCleanLayout(tester, where);

        // The stat chips: numbers whole, labels never broken mid-word.
        for (final value in ['12345', '৳12.3M', '৳1.2M']) {
          _expectOneLine(tester, find.text(value), '$where: $value');
        }
        if (lang == 'en') {
          for (final label in ['Orders', 'Total Spent', 'Outstanding']) {
            _expectWholeWords(tester, find.text(label), '$where: $label');
          }
        }
        // The address and notes don't run down a narrow column a
        // word-fragment at a time.
        _expectWholeWords(tester, find.text(_address), where);

        // The chart's axis labels: month names whole, amounts on one line.
        final chartTexts = find.descendant(
            of: find.byType(BarChart), matching: find.byType(Text));
        expectWholeText(tester, chartTexts, where);
        _expectOneLine(tester, chartTexts, where);

        // Payment history: the amount whole, the title never broken.
        for (final p in _payments) {
          final amount = '${p.isRefund ? '−' : '+'}${_money(p.amount.abs())}';
          _expectOneLine(tester, find.text(amount), '$where: $amount');
        }
        if (lang == 'en') {
          _expectWholeWords(tester, find.text('Payment'), where);
          _expectWholeWords(tester, find.text('Refund'), where);
        }
      }, height: 3200, langs: ['en', ..._longLangs]);
    });

    testWidgets('is unchanged at 100% for an everyday customer',
        (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in [360.0, 411.0]) {
        final where = '${width.toInt()} dp at 1x';
        setLayoutScreen(tester, width, height: 2000);
        await _pump(tester, const CustomerDetailScreen(customerId: 9));
        expectCleanLayout(tester, where);
        for (final text in ['5', '৳12.5K', '৳2.0K', 'Total Spent']) {
          expect(_drawnAtFullSize(tester, find.text(text)), isTrue,
              reason: '$where: $text');
        }
        // The address beside its label, in the value column 110 px over.
        final label = tester.getRect(find.text('Address'));
        final value = tester.getRect(find.text(_karim.address));
        expect(value.left - label.left, closeTo(110, _eps), reason: where);
        expect(value.top, closeTo(label.top, _eps), reason: where);
        await tester.pumpWidget(const SizedBox());
        await _settle(tester);
      }
    });
  });

  group('due book', () {
    testWidgets('lays out cleanly with every number at its worst',
        (tester) async {
      requireRoboto();
      await _forEachLayout(tester, (where, width, t, lang) async {
        await _pump(tester, const DueBookScreen(initialOver60: true),
            textScale: t, lang: lang);
        expectCleanLayout(tester, where);
        // The 60+ filter leaves the worst debtor: its total, in the summary
        // and on its card, stays whole.
        _expectOneLine(tester, find.text(_money(123456789.01)), where);
        _expectWholeWords(tester, find.text(_longName), where);
        _expectWholeWords(tester, find.text(_longPhone), where);

        // A fresh screen: the same one would keep its filter state.
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, const DueBookScreen(), textScale: t, lang: lang);
        expectCleanLayout(tester, where);
        for (final d in _worstDues) {
          _expectOneLine(tester, find.text(_money(d.totalDue)), where);
          _expectWholeWords(tester, find.text(d.customer.name), where);
        }
        if (lang == 'en') {
          _expectWholeWords(tester, find.text('Total Receivable'), where);
          _expectWholeWords(tester, find.text('Over 30 days'), where);
        }
      }, height: 1600, langs: ['en', ..._longLangs]);
    });

    testWidgets('sorts by its longest name without overflowing',
        (tester) async {
      await _forEachLayout(tester, (where, width, t, lang) async {
        await _pump(tester, const DueBookScreen(), textScale: t);
        await tester.tap(find.byTooltip('Sort by'));
        await tester.pumpAndSettle();
        expectCleanLayout(tester, '$where, sort menu');
        // The item's text ignores pointers; its menu item takes the tap.
        await tester.tap(find.text('Longest since last payment').last,
            warnIfMissed: false);
        await tester.pumpAndSettle();
        expectCleanLayout(tester, where);
        _expectWholeWords(tester,
            find.text('Sort by: Longest since last payment'), where);
      }, height: 1600);
    });

    testWidgets('the filter sheet and active filters lay out cleanly',
        (tester) async {
      requireRoboto();
      await _forEachLayout(tester, (where, width, t, lang) async {
        await _pump(tester, const DueBookScreen(), textScale: t);
        await tester.tap(find.byTooltip('Filter'));
        await _settle(tester);
        expectCleanLayout(tester, '$where, filter sheet');
        for (final label in [
          '60+ days',
          'VIP',
          'Regular',
          'No payment in 30 days',
        ]) {
          final chip = find.text(label).last;
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pump();
        }
        await tester.enterText(find.byType(TextField).last, '12345678');
        await tester.ensureVisible(find.byType(Switch));
        await tester.tap(find.byType(Switch));
        await tester.pump();
        expectCleanLayout(tester, '$where, filter sheet');
        _expectWholeWords(tester, find.text('Clear filters').last, where);
        _expectWholeWords(tester, find.text('Done'), where);
        // Unchanged where they fit before: side by side, equal widths.
        if (width >= 360 && t == 1) {
          final clear = tester.getRect(find.byType(OutlinedButton));
          final done = tester.getRect(find.byType(FilledButton));
          expect(clear.center.dy, closeTo(done.center.dy, _eps),
              reason: where);
          expect(clear.width, closeTo(done.width, _eps), reason: where);
          expect(done.left - clear.right, closeTo(12, _eps), reason: where);
        }
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expectCleanLayout(tester, '$where, active filters');
      }, height: 1600);
    });

    testWidgets('the collect sheet keeps amounts and its error whole',
        (tester) async {
      requireRoboto();
      await _forEachLayout(tester, (where, width, t, lang) async {
        await _pump(tester, const DueBookScreen(), textScale: t);
        final card = find
            .ancestor(of: find.text(_longName), matching: find.byType(Card))
            .first;
        final collect = find.descendant(of: card, matching: find.text('Collect'));
        await tester.ensureVisible(collect);
        await tester.pumpAndSettle();
        await tester.tap(collect);
        await tester.pumpAndSettle();
        final amount = find.widgetWithText(TextField, 'Payment Amount');
        expect(amount, findsOneWidget, reason: where);

        // Settles two orders and part of a third: the preview lists each.
        await tester.enterText(amount, '30000000.5');
        await tester.pump();
        expectCleanLayout(tester, '$where, preview');
        _expectOneLine(tester, find.text(_money(12345678.9)), where);
        _expectOneLine(tester, find.text(_money(5308642.7)), where);

        // More than is owed: the error names the total due, in full.
        await tester.enterText(amount, '999999999');
        await tester.pump();
        expectCleanLayout(tester, '$where, error');
        final error = find.textContaining(_money(123456789.01));
        expect(error, findsWidgets, reason: where);
        for (final p in tester.renderObjectList<RenderParagraph>(error)) {
          expect(p.didExceedMaxLines, isFalse, reason: where);
        }
      }, height: 1000);
    });

    testWidgets('is unchanged at 100% for an everyday due book',
        (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      // An 8-digit due beside a short name fit before too: its amount keeps
      // its size (a 45% cap used to shrink it at 360 dp).
      final nadia = Customer(id: 11, name: 'Nadia Store', phone: '01811223344');
      for (final width in [360.0, 411.0]) {
        final where = '${width.toInt()} dp at 1x';
        setLayoutScreen(tester, width, height: 1200);
        await _pump(tester, const DueBookScreen(),
            overrides: _overrides(
                dues: [..._everydayDues, _due(nadia, 12345678.9, 20)]));
        expectCleanLayout(tester, where);
        expect(
            _lineCount(tester.renderObject(find.text('Sort by: Oldest first'))),
            1,
            reason: where);
        for (final (name, amount) in [
          ('Karim Uddin', 1250.0),
          ('Rahim', 2000.0),
          ('Nadia Store', 12345678.9),
        ]) {
          final card = find
              .ancestor(of: find.text(name), matching: find.byType(Card))
              .first;
          final cardRect = tester.getRect(card);
          // As before: the amount at its own size, 8 dp in from the card's
          // 8 dp padding, and the name on one line.
          final total = find.text(_money(amount));
          expect(_drawnAtFullSize(tester, total), isTrue, reason: where);
          expect(tester.getRect(total).right, closeTo(cardRect.right - 16, _eps),
              reason: '$name, $where');
          expect(_lineCount(tester.renderObject(find.text(name))), 1,
              reason: '$name, $where');

          // Collect and Remind side by side from the card's padding, the call
          // button (if any) at the far end.
          final buttons = find.descendant(
              of: card, matching: find.byWidgetPredicate((w) => w is TextButton));
          final collect = tester.getRect(buttons.first);
          final remind = tester.getRect(buttons.last);
          expect(collect.left, closeTo(cardRect.left + 16, _eps),
              reason: '$name, $where');
          expect(remind.top, closeTo(collect.top, _eps),
              reason: '$name, $where');
          expect(remind.left, closeTo(collect.right, _eps),
              reason: '$name, $where');
          final call =
              find.descendant(of: card, matching: find.byType(IconButton));
          if (name != 'Rahim') {
            expect(tester.getRect(call).right,
                closeTo(cardRect.right - 8, _eps),
                reason: '$name, $where');
          }
          // At their own size where they fit (411 dp); 360 dp at 100% is
          // under a pixel short beside the call button, so the pair scales
          // down a hair there rather than wrapping.
          final scale = collect.width / tester.getSize(buttons.first).width;
          if (width == 411 || name == 'Rahim') {
            expect(scale, closeTo(1, _eps), reason: '$name, $where');
          } else {
            expect(scale, inInclusiveRange(0.99, 1), reason: '$name, $where');
          }
        }
        await tester.pumpWidget(const SizedBox());
        await _settle(tester);
      }
    });
  });

  testWidgets('payment history tiles keep amounts whole', (tester) async {
    requireRoboto();
    await _forEachLayout(tester, (where, width, t, lang) async {
      await _pump(
        tester,
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final p in _payments) PaymentHistoryTile(payment: p),
              PaymentHistoryTile(payment: Payment(amount: 1250)),
            ],
          ),
        ),
        textScale: t,
      );
      expectCleanLayout(tester, where);
      for (final amount in [_money(12345678.9), _money(1234567.89)]) {
        _expectOneLine(tester, find.textContaining(amount), where);
      }
      _expectWholeWords(tester, find.text('Payment'), where);
      _expectWholeWords(tester, find.text('Refund'), where);
      // Unchanged where it fit before: the title and amount at full size.
      if (width >= 360 && t == 1) {
        expect(_drawnAtFullSize(tester, find.text('+${_money(1250)}')), isTrue,
            reason: where);
        for (final p in tester
            .renderObjectList<RenderParagraph>(find.text('Payment'))) {
          expect(p.didExceedMaxLines, isFalse, reason: where);
        }
      }
    });
  });

  group('returns', () {
    testWidgets('lay out every reason and status cleanly', (tester) async {
      await _forEachLayout(tester, (where, width, t, lang) async {
        await _pump(tester, const ReturnsScreen(), textScale: t, lang: lang);
        expectCleanLayout(tester, where);
        // Return and order numbers are never cut short: the digits that
        // tell them apart are at the end.
        for (final p in tester.renderObjectList<RenderParagraph>(
            find.textContaining(RegExp(r'^(RET|ORD)-\d+$')))) {
          expect(p.didExceedMaxLines, isFalse,
              reason: '$where: ${p.text.toPlainText()}');
        }
        _expectOneLine(tester, find.text(_money(12345678.9)), where);
        _expectOneLine(tester, find.text(_money(250)), where);
      }, height: 9000, langs: ['en', ..._longLangs]);
    });

    testWidgets('keep an everyday return on one line per row at 100%',
        (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in [360.0, 411.0]) {
        final where = '${width.toInt()} dp at 1x';
        setLayoutScreen(tester, width, height: 9000);
        await _pump(tester, const ReturnsScreen());
        expectCleanLayout(tester, where);
        // RET-001: the longest reason and status, an original order, and a
        // customer. Nothing is cut short; the date and the status sit at
        // the far end of their rows.
        final number = find.text('RET-001').first;
        final card = tester.getRect(find
            .ancestor(of: number, matching: find.byType(GestureDetector))
            .first);
        final inner = card.deflate(16);
        final row1 = tester.getRect(number);
        final date = tester.getRect(find
            .text(DateFormatter.format(_now))
            .at(_returns.indexWhere((o) => o.orderNumber == 'RET-001')));
        expect(date.center.dy, closeTo(row1.center.dy, 1), reason: where);
        expect(date.right, closeTo(inner.right, _eps), reason: where);
        for (final text in ['RET-001', 'ORD-007', 'Rahim', 'Wrong Item']) {
          for (final p
              in tester.renderObjectList<RenderParagraph>(find.text(text))) {
            expect(p.didExceedMaxLines, isFalse, reason: '$where: $text');
          }
        }
        await tester.pumpWidget(const SizedBox());
        await _settle(tester);
      }
    });
  });

  testWidgets('create return keeps quantities whole', (tester) async {
    final order = _order(1, _big, paid: 123456789.01);
    await _forEachLayout(tester, (where, width, t, lang) async {
      await _pump(tester, CreateReturnScreen(originalOrder: order),
          textScale: t, lang: lang);
      expectCleanLayout(tester, where);
      _expectOneLine(tester, find.text('1234'), where);
    }, height: 4000, langs: ['en', ..._longLangs]);
  });

  testWidgets('right-to-left layouts are clean too', (tester) async {
    requireRoboto();
    addTearDown(tester.view.reset);
    for (final (name, screen) in <(String, Widget)>[
      ('list', const CustomerListScreen()),
      ('form', CustomerFormScreen(customer: _big)),
      ('detail', const CustomerDetailScreen(customerId: 7)),
      ('due book', const DueBookScreen(initialOver60: true)),
      ('returns', const ReturnsScreen()),
      ('create return', CreateReturnScreen(originalOrder: _bigOrders[1])),
    ]) {
      for (final (width, t) in [(320.0, 1.5), (411.0, 1.0)]) {
        final where = '$name, rtl, ${width.toInt()} dp at ${t}x';
        setLayoutScreen(tester, width, height: 3200);
        await _pump(tester, screen, textScale: t, rtl: true);
        expectCleanLayout(tester, where);
        await tester.pumpWidget(const SizedBox());
        await _settle(tester);
      }
    }
  });
}
