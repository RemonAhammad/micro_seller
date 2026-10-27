import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/date_formatter.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/order_item.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/variant_attribute.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/orders/presentation/order_detail_screen.dart';
import 'package:micro_seller/features/orders/presentation/order_form_screen.dart';
import 'package:micro_seller/features/orders/presentation/order_list_screen.dart';
import 'package:micro_seller/features/orders/presentation/widgets/order_card.dart';
import 'package:micro_seller/features/orders/presentation/widgets/order_item_row.dart';
import 'package:micro_seller/features/orders/providers/order_pages_provider.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/isar_core.dart';
import '../support/layout_harness.dart';

// Layout of the Orders screens (list, detail, form and the sheets and
// dialogs they open) under the Display size / Text size settings: clean from
// the narrowest layout (320 dp) to a large phone font (150%) with worst-case
// data (long names, eight-digit amounts, five-digit quantities), and
// unchanged at 100% text on a normal phone wherever it laid out cleanly
// before.

const _eps = 0.01;

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
const _address = 'House 12, Road 34, Block C, Bashundhara Residential Area, '
    'Dhaka 1229, Bangladesh';
const _riceName = 'Premium Basmati Rice Extra Long Grain 25kg Family Pack';
const _teeName = 'Cotton T-Shirt Premium Heavyweight';

/// Every number at its worst: eight-digit amounts, a four- and a five-digit
/// quantity, a long variant label.
List<OrderItem> _worstItems() => [
      OrderItem(
        productId: 1,
        productName: _riceName,
        productSku: 'SKU-RICE-BASMATI-EXTRA-LONG-25KG',
        qty: 1234,
        unitPrice: 12345.67,
        totalPrice: 15234556.78,
      ),
      OrderItem(
        productId: 3,
        productName: _teeName,
        qty: 12,
        unitPrice: 1234567.5,
        totalPrice: 14814810,
        variantCombinationKey: 'Color:Midnight Blue/Size:XXL',
        variantDisplayLabel: 'Color: Midnight Blue / Size: XXL',
      ),
      OrderItem(
        productId: 2,
        productName: 'Oil',
        qty: 99999,
        unitPrice: 5,
        totalPrice: 499995,
      ),
    ];

Order _worstOrder({
  OrderStatus status = OrderStatus.confirmed,
  PaymentStatus payment = PaymentStatus.partial,
  ReturnStatus? returnStatus,
}) {
  final isReturn = returnStatus != null;
  return Order(
    id: 1,
    orderNumber: isReturn ? 'RET-12345' : 'ORD-12345',
    customerId: 1,
    customerName: _longName,
    customerPhone: _longPhone,
    items: _worstItems(),
    subtotal: 30549361.78,
    discountAmount: 1234567.89,
    deliveryFee: 12345.6,
    taxAmount: 987654.32,
    totalAmount: 30314793.81,
    amountPaid: 1234567.8,
    paymentStatus: payment,
    paymentMethod: PaymentMethod.mfs,
    transactionId: 'TXN-ABCDEFGHIJKLMNOPQRSTUVWXYZ-0123456789',
    orderStatus: status,
    notes: 'Deliver after 6 PM. Call before arriving; the gate code is '
        '4521. Fragile items: handle with care and keep them upright.',
    deliveryAddress: _address,
    estimatedDeliveryDate: DateTime(2026, 12, 28),
    actualDeliveryDate:
        status == OrderStatus.completed ? DateTime(2026, 12, 29) : null,
    isReturn: isReturn,
    originalOrderId: isReturn ? 123456 : 0,
    returnStatus: returnStatus ?? ReturnStatus.none,
    returnReason: ReturnReason.changedMind,
    returnNotes: isReturn
        ? 'Customer says the size is wrong and the colour faded after one '
            'wash.'
        : '',
    refundAmount: isReturn ? 1234567.8 : 0,
    createdAt: DateTime(2026, 10, 28, 23, 45),
    updatedAt: DateTime(2026, 10, 28, 23, 45),
  );
}

/// An everyday order, which laid out cleanly at 100% on a 360 dp phone.
Order _everydayOrder({OrderStatus status = OrderStatus.pending}) => Order(
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
            totalPrice: 900),
        OrderItem(
            productId: 6,
            productName: 'T-Shirt',
            qty: 12,
            unitPrice: 350,
            totalPrice: 4200,
            variantCombinationKey: 'Size:L',
            variantDisplayLabel: 'Size: L'),
      ],
      subtotal: 5100,
      discountAmount: 85,
      deliveryFee: 60,
      taxAmount: 250,
      totalAmount: 5325,
      amountPaid: 2000,
      paymentStatus: PaymentStatus.partial,
      orderStatus: status,
      notes: 'Call before delivery',
      deliveryAddress: 'House 12, Road 3, Dhanmondi, Dhaka',
      estimatedDeliveryDate: DateTime(2026, 10, 25),
      createdAt: DateTime(2026, 10, 19, 10, 30),
      updatedAt: DateTime(2026, 10, 19, 10, 30),
    );

/// Order cards as the list shows them: every status and payment status with
/// a long name and an eight-digit amount, an everyday order, and one with
/// no customer.
List<Order> _cardOrders() => [
      for (final status in OrderStatus.values)
        for (final payment in PaymentStatus.values)
          _worstOrder(status: status, payment: payment),
      _everydayOrder(),
      Order(
        orderNumber: 'ORD-99999',
        items: [OrderItem(qty: 1234)],
        totalAmount: 12345678.9,
        orderStatus: OrderStatus.completed,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime(2026, 10, 28),
      ),
    ];

const _badgeLabels = {
  'Pending',
  'Confirmed',
  'Shipped',
  'Completed',
  'Cancelled',
  'Unpaid',
  'Partial',
  'Paid',
};

// ─── Pumping ─────────────────────────────────────────────────────────────

/// [screen] as the app shows it: in its shell branch's Navigator beside the
/// sidebar, [railWidth] wide (so its sheets and menus open there too), pushed
/// over the branch's first page unless [pushed] is false (so it has a back
/// button).
Widget _shell(Widget screen,
        {required double railWidth, bool pushed = true, bool rtl = false}) =>
    Row(
      children: [
        SizedBox(width: railWidth),
        Expanded(
          child: Theme(
            data: _phoneTheme,
            child: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Navigator(
                onGenerateInitialRoutes: (_, _) => [
                  if (pushed)
                    MaterialPageRoute<void>(builder: (_) => const SizedBox()),
                  MaterialPageRoute<void>(builder: (_) => screen),
                ],
              ),
            ),
          ),
        ),
      ],
    );

/// The sidebar beside the screen in the test window, as the app lays it out:
/// the icon rail on a phone, labels from 600 dp ([railWidthFor]).
double _railWidth(WidgetTester tester) =>
    railWidthFor(tester.view.physicalSize.width / tester.view.devicePixelRatio);

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  double textScale = 1,
  bool pushed = true,
  bool rtl = false,
  List<Override> overrides = const [],
}) async {
  await pumpLayoutApp(
    tester,
    _shell(screen, railWidth: _railWidth(tester), pushed: pushed, rtl: rtl),
    textScale: textScale,
    overrides: overrides,
    rail: false,
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Closes the open menu by tapping its barrier, beside the sidebar (the
/// window's corner is the sidebar, outside the branch's overlay).
Future<void> _dismiss(WidgetTester tester) async {
  await tester.tapAt(Offset(_railWidth(tester) + 4, 4));
  await _settle(tester);
}

/// Pumps until [finder] shows up, letting the database answer meanwhile
/// (its queries run outside the test's fake clock). It allows several
/// seconds: a busy machine (tests running side by side) made a second too
/// little for saving an order.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 500 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(finder, findsWidgets);
  await _settle(tester);
}

/// Runs [body] at every layout width × text scale, clearing the screen after
/// each.
Future<void> _forEachLayout(
  WidgetTester tester,
  Future<void> Function(String where, double width, double textScale) body, {
  double height = 800,
  List<double> widths = kLayoutWidths,
  List<double> textScales = kLayoutTextScales,
}) async {
  addTearDown(tester.view.reset);
  for (final width in widths) {
    for (final t in textScales) {
      setLayoutScreen(tester, width, height: height);
      await body('${width.toInt()} dp at ${t}x', width, t);
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    }
  }
}

// ─── Checks ──────────────────────────────────────────────────────────────

/// A string key missing from the translation files, shown raw: one
/// camelCase word, which may break anywhere. (Not a layout problem.)
final _rawKey = RegExp(r'^[a-z]+(?:[A-Z][a-z]*)+$');

/// Everything on screen laid out cleanly: no overflow reported, every text
/// drawn whole (not cut off by a box too short for it, not broken in the
/// middle of a word or number, no amount cut short, inside the window unless
/// it scrolls sideways), and no icon squeezed below its size.
void _expectClean(WidgetTester tester, String where) {
  expectCleanLayout(tester, where);
  final window = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final seen = <RenderParagraph>{};
  for (final element in find.byType(RichText).evaluate()) {
    final p = element.renderObject! as RenderParagraph;
    if (!seen.add(p) || !p.attached || !p.hasSize) continue;
    final text = p.text.toPlainText();
    if (text.trim().isEmpty) continue;
    expect(p.size.height, greaterThanOrEqualTo(p.textSize.height - _eps),
        reason: '$where: "$text" cut off');
    if (text.contains('৳')) {
      expect(p.didExceedMaxLines, isFalse,
          reason: '$where: "$text" cut short');
    }
    // A line may break at a space, after a hyphen or after a slash.
    if (!_rawKey.hasMatch(text)) {
      for (final word in RegExp(r'[^\s\-/]+').allMatches(text)) {
        final tops = p
            .getBoxesForSelection(
                TextSelection(baseOffset: word.start, extentOffset: word.end))
            .map((b) => b.top.round())
            .toSet();
        expect(tops.length, lessThanOrEqualTo(1),
            reason: '$where: "${word[0]}" broken in "$text"');
      }
    }
    final scrollable = Scrollable.maybeOf(element);
    if (scrollable != null &&
        axisDirectionToAxis(scrollable.axisDirection) == Axis.horizontal) {
      continue;
    }
    final toWindow = p.getTransformTo(null);
    for (final box in p.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length))) {
      final r = MatrixUtils.transformRect(toWindow, box.toRect());
      expect(r.left, greaterThanOrEqualTo(-0.5),
          reason: '$where: "$text" drawn off the window');
      expect(r.right, lessThanOrEqualTo(window + 0.5),
          reason: '$where: "$text" drawn off the window');
    }
  }
  for (final element in find.byType(ThinIcon).evaluate()) {
    final icon = element.widget as ThinIcon;
    final want = icon.size ?? IconTheme.of(element).size ?? 24;
    final size = (element.renderObject! as RenderBox).size;
    expect(math.min(size.width, size.height), greaterThanOrEqualTo(want - 0.5),
        reason: '$where: an icon squeezed to $size');
  }
}

/// [finder]'s texts are drawn in full (not ellipsized; they may be shrunk).
void _expectUncut(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    expect(p.didExceedMaxLines, isFalse,
        reason: '$where: "${p.text.toPlainText()}" cut short');
  }
}

/// Each order card's number, badges and amount are drawn in full, inside
/// the card.
void _expectCardsWhole(WidgetTester tester, String where) {
  final cards = find.byType(OrderCard);
  expect(cards, findsWidgets, reason: where);
  for (var i = 0; i < cards.evaluate().length; i++) {
    final card = tester.getRect(cards.at(i));
    for (final p in tester.renderObjectList<RenderParagraph>(
        find.descendant(of: cards.at(i), matching: find.byType(RichText)))) {
      final text = p.text.toPlainText();
      if (text.startsWith('ORD-') ||
          text.contains('৳') ||
          _badgeLabels.contains(text)) {
        expect(p.didExceedMaxLines, isFalse,
            reason: '$where: "$text" cut short');
      }
      final r = MatrixUtils.transformRect(
          p.getTransformTo(null), Offset.zero & p.size);
      expect(r.left, greaterThanOrEqualTo(card.left + 16 - 0.5),
          reason: '$where: "$text" outside its card');
      expect(r.right, lessThanOrEqualTo(card.right - 16 + 0.5),
          reason: '$where: "$text" outside its card');
    }
  }
}

/// [a] and [b] are drawn on one line: their vertical centres meet.
void _expectSameLine(Finder a, Finder b, WidgetTester tester, String where) {
  expect(tester.getCenter(a).dy, closeTo(tester.getCenter(b).dy, 0.5),
      reason: where);
}

/// [finder]'s widget is drawn at its laid-out size (no FittedBox shrink).
bool _drawnAtFullSize(WidgetTester tester, Finder finder) =>
    (tester.getRect(finder).width - tester.getSize(finder).width).abs() < _eps;

String _money(double amount) => CurrencyFormatter.format(amount);

void main() {
  final coreLibrary = isarCoreLibrary();
  Isar? db;
  Directory? dir;

  setUpAll(() async {
    await loadRoboto();
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    CurrencyFormatter.setSymbol('৳');
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dir = await Directory.systemTemp.createTemp('micro_seller_orders_layout');
    final isar = db = await Isar.open(
      kIsarSchemas,
      directory: dir!.path,
      name: 'orders_layout_test',
      inspector: false,
    );
    isar.writeTxnSync(() {
      isar.customers.putAllSync([
        Customer(id: 1, name: _longName, phone: _longPhone),
        Customer(id: 2, name: 'Rahim Uddin', phone: '01712345678'),
        Customer(id: 3, name: 'Karim Uddin Ahmed Bhuiyan Old Dhaka Wholesale'),
      ]);
      isar.products.putAllSync([
        Product(
          id: 1,
          name: _riceName,
          sku: 'SKU-RICE-BASMATI-EXTRA-LONG-25KG',
          sellingPrice: 12345678.9,
          stockQty: 123456,
        ),
        Product(
          id: 2,
          name: 'Out of stock item with a long product name',
          sellingPrice: 12345678.9,
          stockQty: 0,
        ),
        Product(
          id: 3,
          name: _teeName,
          sellingPrice: 450,
          stockQty: 30,
          variantAttributes: [
            VariantAttribute(name: 'Color', options: ['Midnight Blue', 'Red']),
            VariantAttribute(name: 'Size', options: ['XXL', 'S']),
          ],
          variantCombinations: [
            VariantCombination(
              combinationKey: 'Color:Midnight Blue/Size:XXL',
              displayLabel: 'Color: Midnight Blue / Size: XXL',
              priceAdjustment: 1234567.5,
              stockQty: 12345,
            ),
            VariantCombination(
              combinationKey: 'Color:Red/Size:S',
              displayLabel: 'Color: Red / Size: S',
              stockQty: 0,
              sku: 'TS-RED-S',
            ),
          ],
        ),
        Product(id: 4, name: 'Rice 5kg', sellingPrice: 450, stockQty: 40),
        Product(id: 5, name: 'Soybean Oil 1L', sellingPrice: 185, stockQty: 0),
        Product(id: 6, name: 'T-Shirt', sellingPrice: 350, stockQty: 30),
      ]);
    });
  });

  tearDownAll(() async {
    await db?.close(deleteFromDisk: true);
    await dir?.delete(recursive: true);
  });

  /// The providers a database-backed screen reads, over the test database.
  List<Override> dbOverrides() => [isarProvider.overrideWith((ref) async => db!)];

  // ─── Order card ─────────────────────────────────────────────────────────

  group('order card', () {
    Widget list(List<Order> orders) => Scaffold(
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => OrderCard(order: orders[i]),
          ),
        );

    testWidgets(
        'keeps the order number, badges and amount whole at every width '
        'and text size', (tester) async {
      requireRoboto();
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, list(_cardOrders()), textScale: t, pushed: false);
        _expectClean(tester, where);
        _expectCardsWhole(tester, where);
      }, height: 2400);
    });

    testWidgets('lays out right to left', (tester) async {
      requireRoboto();
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, list(_cardOrders()),
            textScale: t, pushed: false, rtl: true);
        expectCleanLayout(tester, '$where, RTL');
        _expectCardsWhole(tester, '$where, RTL');
      }, height: 2400, widths: [320], textScales: [1.5]);
    });

    testWidgets(
        'keeps its first row on one line at 100% on a phone, nothing cut '
        'short', (tester) async {
      requireRoboto();
      // It used to give the order number, the customer and a spacer a
      // third of the row each: "ORD-0…" on every phone, and the date and
      // amount short of the card's end.
      final everyday = _everydayOrder(status: OrderStatus.confirmed);
      final walkIn = Order(
        orderNumber: 'ORD-1234',
        items: [OrderItem(qty: 3)],
        totalAmount: 950,
        orderStatus: OrderStatus.completed,
        createdAt: DateTime(2026, 10, 1),
      );
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, list([everyday, walkIn]), pushed: false);
        _expectClean(tester, where);
        _expectCardsWhole(tester, where);
        for (final (i, order) in [everyday, walkIn].indexed) {
          final card = find.byType(OrderCard).at(i);
          Finder text(String s) =>
              find.descendant(of: card, matching: find.text(s));
          final number = text(order.orderNumber);
          final date = text(DateFormatter.format(order.createdAt));
          final amount = text(_money(order.totalAmount));
          final end = tester.getRect(card).right - 16;
          _expectSameLine(number, date, tester, where);
          _expectSameLine(number, text('${order.totalItems} items'), tester,
              where);
          expect(tester.getRect(date).right, closeTo(end, 0.5), reason: where);
          expect(tester.getRect(amount).right, closeTo(end, 0.5),
              reason: where);
          expect(_drawnAtFullSize(tester, amount), isTrue, reason: where);
        }
      }, widths: [360, 411], textScales: [1.0]);
    });

    testWidgets('keeps amounts and badges whole on a tablet', (tester) async {
      requireRoboto();
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, list(_cardOrders()), textScale: t, pushed: false);
        _expectClean(tester, where);
        _expectCardsWhole(tester, where);
      }, height: 1600, widths: [600, 800]);
    });

    testWidgets('is one row once the card itself is wide enough',
        (tester) async {
      requireRoboto();
      // It used to follow the window: from 600 dp it took the row layout
      // even though the sidebar there is 200 dp wide, which left the row a
      // 368 dp card. An iPad mini's 744 dp window gives a 512 dp card.
      final order = _everydayOrder(status: OrderStatus.confirmed);
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, list([order]), textScale: t, pushed: false);
        _expectClean(tester, where);
        _expectCardsWhole(tester, where);
        final card = tester.getRect(find.byType(OrderCard));
        expect(card.width, width - _railWidth(tester) - 2 * 16, reason: where);
        final row = card.width >= OrderCard.rowLayoutMinWidth;
        expect(row, width >= 744, reason: where);
        // One row: the amount beside the order number, not under it.
        final number = tester.getRect(find.text(order.orderNumber));
        final amount = tester.getRect(find.text(_money(order.totalAmount)));
        expect(amount.top < number.bottom, row, reason: where);
      }, widths: [411, 600, 694, 743, 744, 800, 1133]);
    });
  });

  // ─── Order list ─────────────────────────────────────────────────────────

  testWidgets('the order list lays out at every width and text size',
      (tester) async {
    requireRoboto();
    final orders = _cardOrders();
    await _forEachLayout(tester, (where, width, t) async {
      await _pump(tester, const OrderListScreen(),
          textScale: t,
          pushed: false,
          overrides: [
            orderTabCountsProvider.overrideWithValue(
                const AsyncValue.data([123456, 12345, 1234, 123, 0])),
            orderPagesProvider.overrideWithBuild((ref, pages) => Stream.value(
                pages.tab == OrderTab.cancelled
                    ? const OrderPage([], hasMore: false)
                    : OrderPage(orders, hasMore: false))),
          ]);
      _expectClean(tester, where);
      _expectCardsWhole(tester, where);

      // The long-press status menu.
      await tester.longPress(find.byType(OrderCard).first);
      await _settle(tester);
      expect(find.byType(PopupMenuItem<OrderStatus>), findsWidgets,
          reason: where);
      _expectClean(tester, '$where, status menu');
      await _dismiss(tester);

      // An empty tab.
      final cancelled = find.descendant(
          of: find.byType(TabBar), matching: find.text('Cancelled'));
      await tester.ensureVisible(cancelled);
      await _settle(tester);
      await tester.tap(cancelled);
      await _settle(tester);
      expect(find.text('No orders yet. Create your first order!'),
          findsOneWidget,
          reason: where);
      _expectClean(tester, '$where, empty tab');
    }, height: 2400);
  });

  // ─── Order detail ───────────────────────────────────────────────────────

  group('order detail', () {
    List<Override> overrides(Order order) => [
          isarProvider.overrideWithValue(AsyncValue.data(db!)),
          orderByIdProvider(order.id).overrideWithValue(AsyncValue.data(order)),
        ];

    testWidgets('lays out every order status at every width and text size',
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      await _forEachLayout(tester, (where, width, t) async {
        for (final status in OrderStatus.values) {
          final order = _worstOrder(status: status);
          final at = '$where, ${status.name}';
          await _pump(tester, OrderDetailScreen(orderId: order.id),
              textScale: t, overrides: overrides(order));
          _expectClean(tester, at);
          // The order number, shown only in the app bar, in full.
          _expectUncut(
              tester,
              find.descendant(
                  of: find.byType(AppBar), matching: find.text('ORD-12345')),
              at);
          if (status == OrderStatus.confirmed) {
            await tester.tap(find.byType(PopupMenuButton<String>));
            await _settle(tester);
            expect(find.byType(PopupMenuItem<String>), findsWidgets,
                reason: at);
            _expectClean(tester, '$at, actions menu');
            await _dismiss(tester);

            await tester.ensureVisible(find.text('Record Payment'));
            await tester.tap(find.text('Record Payment'));
            await _settle(tester);
            expect(find.byType(Dialog), findsOneWidget, reason: at);
            _expectClean(tester, '$at, payment dialog');
          }
          await tester.pumpWidget(const SizedBox());
          await _settle(tester);
        }
      }, height: 1000);
    });

    testWidgets('lays out every return status at every width and text size',
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      await _forEachLayout(tester, (where, width, t) async {
        for (final status in [
          ReturnStatus.requested,
          ReturnStatus.received,
          ReturnStatus.refunded,
          ReturnStatus.rejected,
        ]) {
          final order = _worstOrder(
              status: OrderStatus.pending, returnStatus: status);
          final at = '$where, return ${status.name}';
          await _pump(tester, OrderDetailScreen(orderId: order.id),
              textScale: t, overrides: overrides(order));
          _expectClean(tester, at);
          if (status == ReturnStatus.requested) {
            await tester.tap(find.text('Approve & Receive'));
            await _settle(tester);
            expect(find.byType(Dialog), findsOneWidget, reason: at);
            _expectClean(tester, '$at, approve dialog');
          }
          if (status == ReturnStatus.received) {
            await tester.tap(find.textContaining('Process Refund ('));
            await _settle(tester);
            expect(find.byType(Dialog), findsOneWidget, reason: at);
            _expectClean(tester, '$at, refund dialog');
          }
          await tester.pumpWidget(const SizedBox());
          await _settle(tester);
        }
      }, height: 1000);
    });

    testWidgets('lays out right to left', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      await _forEachLayout(tester, (where, width, t) async {
        for (final order in [
          _worstOrder(),
          _worstOrder(returnStatus: ReturnStatus.received),
        ]) {
          await _pump(tester, OrderDetailScreen(orderId: order.id),
              textScale: t, rtl: true, overrides: overrides(order));
          expectCleanLayout(tester, '$where, RTL ${order.orderNumber}');
          await tester.pumpWidget(const SizedBox());
          await _settle(tester);
        }
      }, height: 1000, widths: [320], textScales: [1.5]);
    });

    testWidgets('keeps its one-row layouts at 100% on a phone',
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      final order = _everydayOrder();
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, OrderDetailScreen(orderId: order.id),
            overrides: overrides(order));
        _expectClean(tester, where);
        // Badges, and the date at the end of their row.
        final date = find.text(DateFormatter.formatWithTime(order.createdAt));
        final badge = find.text('Partial');
        _expectSameLine(badge, date, tester, where);
        expect(tester.getRect(date).right, closeTo(width - 20, 0.5),
            reason: where);
        // Label at the start, value at the end of the same line.
        for (final (label, value) in [
          ('Customer', 'Rahim Uddin'),
          ('Phone', '01712345678'),
          ('Subtotal', _money(order.subtotal)),
          ('Total', _money(order.totalAmount)),
          ('Balance Due', _money(order.balanceDue)),
        ]) {
          _expectSameLine(find.text(label), find.text(value), tester, where);
        }
        expect(tester.getRect(find.text('Rahim Uddin')).right,
            closeTo(width - 20 - 16, 0.5),
            reason: where);
        // Each item's total at the end of its row, beside the name.
        for (final item in order.items) {
          final total = find.text(_money(item.totalPrice));
          final unit = find.text(
              '${_money(item.unitPrice)} × ${item.qty}');
          expect(tester.getRect(total).right, closeTo(width - 20 - 16, 0.5),
              reason: where);
          expect(tester.getRect(total).top,
              lessThan(tester.getRect(unit).bottom),
              reason: where);
        }
        // The status buttons side by side.
        final back = tester.getRect(find.byType(OutlinedButton).first);
        final forward = tester.getRect(find.byType(FilledButton).first);
        expect(back.top, closeTo(forward.top, 0.5), reason: where);
        expect(back.width, closeTo(forward.width, 0.5), reason: where);
      }, height: 1400, widths: [360, 411], textScales: [1.0]);
    });
  });

  // ─── Order form ─────────────────────────────────────────────────────────

  group('order form', () {
    testWidgets('a new order lays out at every width and text size',
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, const OrderFormScreen(),
            textScale: t, overrides: dbOverrides());
        _expectClean(tester, where);
        await tester.tap(find.text('Recurring Order'));
        await _settle(tester);
        _expectClean(tester, '$where, recurring');
        // The interval's digits are all on show, not scrolled out of view.
        final days = tester.allRenderObjects
            .whereType<RenderEditable>()
            .toSet()
            .singleWhere((e) => e.text?.toPlainText() == '30');
        expect(days.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(days.size.width + 0.5),
            reason: '$where: the interval scrolled out of view');
      }, height: 3000);
    });

    testWidgets(
        'an order with long items and big amounts lays out at every width '
        'and text size', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      final order = _worstOrder()
          .copyWith(isRecurring: true, recurringIntervalDays: 365);
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, OrderFormScreen(order: order),
            textScale: t, overrides: dbOverrides());
        _expectClean(tester, where);
      }, height: 3000);
    });

    testWidgets('lays out right to left', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      final order = _worstOrder()
          .copyWith(isRecurring: true, recurringIntervalDays: 365);
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, OrderFormScreen(order: order),
            textScale: t, rtl: true, overrides: dbOverrides());
        expectCleanLayout(tester, '$where, RTL');
      }, height: 3000, widths: [320], textScales: [1.5]);
    });

    testWidgets('its pickers lay out at every width and text size',
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      final order = _worstOrder();
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, OrderFormScreen(order: order),
            textScale: t, overrides: dbOverrides());

        await tester.tap(find.text(_longName).first);
        await _waitFor(tester, find.text('Create New Customer'));
        _expectClean(tester, '$where, customer picker');
        await tester.tap(find.text('Create New Customer'));
        await _settle(tester);
        expect(find.text('Add & Select'), findsOneWidget, reason: where);
        _expectClean(tester, '$where, new customer form');
        await tester.pumpWidget(const SizedBox());
        await _settle(tester);

        await _pump(tester, OrderFormScreen(order: order),
            textScale: t, overrides: dbOverrides());
        await tester.tap(find.text('Add').first);
        await _waitFor(tester, find.text(_teeName));
        _expectClean(tester, '$where, product picker');
        await tester.tap(find.text(_teeName).last);
        await _settle(tester);
        expect(find.text('Color: Midnight Blue / Size: XXL'), findsOneWidget,
            reason: where);
        _expectClean(tester, '$where, product picker with variants');
      }, height: 3000);
    });

    testWidgets("a saved order's invoice sheet lays out at every width and "
        'text size', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, const OrderFormScreen(),
            textScale: t, overrides: dbOverrides());
        await tester.tap(find.text('Select or create customer'));
        await _waitFor(tester, find.text(_longName));
        await tester.tap(find.text(_longName).last);
        await _settle(tester);
        await tester.tap(find.text('Add').first);
        await _waitFor(tester, find.text('Rice 5kg'));
        await tester.tap(find
            .descendant(
                of: find.byType(DraggableScrollableSheet),
                matching: find.text('Add'))
            .first);
        await _settle(tester);
        await tester.tap(find.text('Done').last);
        await _settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'New Order'));
        await _waitFor(tester, find.text('Share PDF'));
        _expectClean(tester, '$where, invoice sheet');
      }, height: 1400);
    });

    testWidgets('keeps item rows and picker buttons as they were at 100% on '
        'a phone', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      final order = _everydayOrder()
          .copyWith(isRecurring: true, recurringIntervalDays: 30);
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(tester, OrderFormScreen(order: order),
            overrides: dbOverrides());
        _expectClean(tester, where);
        // Quantity, total and remove beside the name, not under it.
        for (final item in order.items) {
          final total = find.text(_money(item.totalPrice));
          final unit = find.text(_money(item.unitPrice));
          final qty = find.text('${item.qty}');
          expect(tester.getRect(total).top,
              lessThan(tester.getRect(unit).bottom),
              reason: where);
          _expectSameLine(qty, total, tester, where);
          expect(_drawnAtFullSize(tester, total), isTrue, reason: where);
        }
        await tester.tap(find.text('Add').first);
        await _waitFor(tester, find.text('Soybean Oil 1L'));
        _expectClean(tester, '$where, product picker');
        // The buttons at their own size: the cap only bites at large text.
        expect(_drawnAtFullSize(tester, find.text('Out of Stock').first),
            isTrue,
            reason: where);
        expect(_drawnAtFullSize(tester, find.text('Add').last), isTrue,
            reason: where);
      }, height: 1400, widths: [360, 411], textScales: [1.0]);
    });
  });

  // ─── Tablets ────────────────────────────────────────────────────────────

  // iPads and Android tablets in both orientations, and the app's window in
  // Split View, at 100% and 150% text: each screen beside the sidebar the
  // app gives that window (labels from 600 dp).
  group('on tablets', () {
    testWidgets('the order list lays out in every tablet window',
        (tester) async {
      requireRoboto();
      final orders = _cardOrders();
      await forEachTabletLayout(tester, (where, window, t) async {
        await _pump(tester, const OrderListScreen(),
            textScale: t,
            pushed: false,
            overrides: [
              orderTabCountsProvider.overrideWithValue(
                  const AsyncValue.data([123456, 12345, 1234, 123, 0])),
              orderPagesProvider.overrideWithBuild((ref, pages) =>
                  Stream.value(OrderPage(orders, hasMore: false))),
            ]);
        _expectClean(tester, where);
        _expectCardsWhole(tester, where);

        // The long-press status menu.
        await tester.longPress(find.byType(OrderCard).first);
        await _settle(tester);
        expect(find.byType(PopupMenuItem<OrderStatus>), findsWidgets,
            reason: where);
        _expectClean(tester, '$where, status menu');
        await _dismiss(tester);
      });
    });

    testWidgets('the order detail lays out in every tablet window',
        (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      await forEachTabletLayout(tester, (where, window, t) async {
        for (final order in [
          _worstOrder(),
          _worstOrder(
              status: OrderStatus.pending,
              returnStatus: ReturnStatus.received),
        ]) {
          final at = '$where, ${order.orderNumber}';
          await _pump(tester, OrderDetailScreen(orderId: order.id),
              textScale: t,
              overrides: [
                isarProvider.overrideWithValue(AsyncValue.data(db!)),
                orderByIdProvider(order.id)
                    .overrideWithValue(AsyncValue.data(order)),
              ]);
          _expectClean(tester, at);
          if (!order.isReturn) {
            await tester.tap(find.byType(PopupMenuButton<String>));
            await _settle(tester);
            expect(find.byType(PopupMenuItem<String>), findsWidgets,
                reason: at);
            _expectClean(tester, '$at, actions menu');
            await _dismiss(tester);

            await tester.ensureVisible(find.text('Record Payment'));
            await tester.tap(find.text('Record Payment'));
            await _settle(tester);
            expect(find.byType(Dialog), findsOneWidget, reason: at);
            _expectClean(tester, '$at, payment dialog');
          }
          await tester.pumpWidget(const SizedBox());
          await _settle(tester);
        }
      });
    });

    testWidgets('the order form and its product picker lay out in every '
        'tablet window', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      final order = _worstOrder()
          .copyWith(isRecurring: true, recurringIntervalDays: 365);
      await forEachTabletLayout(tester, (where, window, t) async {
        await _pump(tester, OrderFormScreen(order: order),
            textScale: t, overrides: dbOverrides());
        _expectClean(tester, where);

        await tester.tap(find.text('Add').first);
        await _waitFor(tester, find.text(_teeName));
        _expectClean(tester, '$where, product picker');
      });
    });
  });

  // ─── Bold text ──────────────────────────────────────────────────────────

  // The phone's Bold text setting draws every Text in bold (a Text merges
  // FontWeight.bold over its style). A row that measures its texts to choose
  // between side by side and stacked must measure them bold too, or it keeps
  // side by side texts that no longer fit.
  group('with Bold text on', () {
    /// Turns the phone's Bold text setting on for the rest of the test.
    void boldText(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(boldText: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }

    /// The setting reaches [finder]'s widget through its MediaQuery.
    void expectBold(WidgetTester tester, Finder finder, String where) =>
        expect(MediaQuery.boldTextOf(tester.element(finder.first)), isTrue,
            reason: where);

    testWidgets('order cards lay out at 320 dp and 130% text',
        (tester) async {
      requireRoboto();
      boldText(tester);
      // The worst cases, and cards whose first row steps, a few pixels at a
      // time, through the width where it goes from one line to two.
      final orders = [
        ..._cardOrders(),
        for (var digits = 0; digits <= 6; digits++)
          for (var qtyDigits = 1; qtyDigits <= 6; qtyDigits++)
            for (final name in ['', 'Al'])
              Order(
                orderNumber: 'ORD-${'123456'.substring(0, digits)}',
                customerName: name,
                items: [
                  OrderItem(qty: int.parse('123456'.substring(0, qtyDigits))),
                ],
                totalAmount: 950,
                createdAt: DateTime(2026, 10, 28),
              ),
      ];
      await _forEachLayout(tester, (where, width, t) async {
        await _pump(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final order in orders) ...[
                      OrderCard(order: order),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            textScale: t,
            pushed: false);
        final at = '$where, bold text';
        expectBold(tester, find.byType(OrderCard), at);
        _expectClean(tester, at);
        _expectCardsWhole(tester, at);
      }, height: 12000, widths: [320], textScales: [1.3]);
    });

    testWidgets('order item rows lay out at 320 dp and 130% text',
        (tester) async {
      requireRoboto();
      boldText(tester);
      // The worst cases, everyday items, and totals from one to nine digits
      // beside the same name.
      final items = [
        ..._worstItems(),
        ..._everydayOrder().items,
        for (var digits = 1; digits <= 9; digits++)
          OrderItem(
            productName: 'Mustard Oil Bottle',
            qty: 1,
            unitPrice: 5,
            totalPrice: double.parse('987654321'.substring(0, digits)),
          ),
      ];
      await _forEachLayout(tester, (where, width, t) async {
        // As the order detail screen lists them.
        await _pump(
            tester,
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final (i, item) in items.indexed)
                        OrderItemRow(
                            item: item, showDivider: i < items.length - 1),
                    ],
                  ),
                ),
              ),
            ),
            textScale: t);
        final at = '$where, bold text';
        expectBold(tester, find.byType(OrderItemRow), at);
        _expectClean(tester, at);
        _expectUncut(
            tester,
            find.descendant(
                of: find.byType(OrderItemRow),
                matching: find.textContaining('৳')),
            at);
      }, height: 3000, widths: [320], textScales: [1.3]);
    });

    testWidgets(
        "the order form's item rows, product picker and invoice sheet lay "
        'out at 320 dp and 130% text', (tester) async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      requireRoboto();
      boldText(tester);
      final order = _worstOrder()
          .copyWith(isRecurring: true, recurringIntervalDays: 365);
      await _forEachLayout(tester, (where, width, t) async {
        final at = '$where, bold text';
        await _pump(tester, OrderFormScreen(order: order),
            textScale: t, overrides: dbOverrides());
        expectBold(tester, find.byType(OrderFormScreen), at);
        _expectClean(tester, at);
        await tester.tap(find.text('Add').first);
        await _waitFor(tester, find.text(_teeName));
        _expectClean(tester, '$at, product picker');
        await tester.tap(find.text(_teeName).last);
        await _settle(tester);
        expect(find.text('Color: Midnight Blue / Size: XXL'), findsOneWidget,
            reason: at);
        _expectClean(tester, '$at, product picker with variants');
        await tester.pumpWidget(const SizedBox());
        await _settle(tester);

        // A new order, saved: its invoice sheet.
        await _pump(tester, const OrderFormScreen(),
            textScale: t, overrides: dbOverrides());
        await tester.tap(find.text('Select or create customer'));
        await _waitFor(tester, find.text(_longName));
        await tester.tap(find.text(_longName).last);
        await _settle(tester);
        await tester.tap(find.text('Add').first);
        await _waitFor(tester, find.text('Rice 5kg'));
        await tester.tap(find
            .descendant(
                of: find.byType(DraggableScrollableSheet),
                matching: find.text('Add'))
            .first);
        await _settle(tester);
        await tester.tap(find.text('Done').last);
        await _settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'New Order'));
        await _waitFor(tester, find.text('Share PDF'));
        _expectClean(tester, '$at, invoice sheet');
      }, height: 3000, widths: [320], textScales: [1.3]);
    });
  });
}
