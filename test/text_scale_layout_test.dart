import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_colors.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/date_formatter.dart';
import 'package:micro_seller/data/models/category.dart';
import 'package:micro_seller/data/models/expense.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/variant_attribute.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/categories/providers/category_provider.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';
import 'package:micro_seller/features/dashboard/presentation/dashboard_screen.dart';
import 'package:micro_seller/features/dashboard/presentation/widgets/stat_card.dart';
import 'package:micro_seller/features/dashboard/providers/dashboard_provider.dart';
import 'package:micro_seller/features/expenses/providers/expense_provider.dart';
import 'package:micro_seller/features/products/presentation/product_form_screen.dart';
import 'package:micro_seller/features/products/presentation/widgets/product_card.dart';
import 'package:micro_seller/features/products/presentation/widgets/stock_badge.dart';
import 'package:micro_seller/features/reports/presentation/reports_screen.dart';
import 'package:micro_seller/features/reports/presentation/widgets/report_widgets.dart';
import 'package:micro_seller/features/updates/providers/update_notice_provider.dart';
import 'package:micro_seller/shared/widgets/loading_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/layout_harness.dart' show loadRoboto, requireRoboto;

// Layout under the phone's font size and the app's Text size / Display size
// settings: every spot that used to sit in a fixed-height slot or an
// unscrollable row must lay out cleanly from 80% to 150% text, down to the
// narrowest layout the Display size allows (320 dp), and look unchanged at
// 100% text on a normal phone.

/// Text scales: the Text size setting's 80% up to a large phone font.
const _textScales = [0.8, 1.0, 1.3, 1.5];

/// Window widths in dp: the narrowest layout the Display size allows, a
/// common phone, and the 400 dp phone these were measured on.
const _screenWidths = [320.0, 360.0, 400.0];

/// Every screen sits beside the sidebar's icon rail on a phone.
const _rail = 56.0;

const _eps = 0.01;

void _setScreen(WidgetTester tester, double width, {double height = 800}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, height * 3);
}

/// Pumps [home] beside a sidebar rail, with the app's theme and strings and
/// [textScale] applied over the whole app the way a font size is.
Future<void> _pumpApp(
  WidgetTester tester,
  Widget home, {
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Row(
        children: [
          const SizedBox(width: _rail),
          Expanded(child: home),
        ],
      ),
    ),
  ));
  // The app's strings load asynchronously: the next frame has the content.
  await tester.pump();
}

/// No overflow (or any other error) was reported while laying out.
void _expectCleanLayout(WidgetTester tester, String where) {
  final error = tester.takeException();
  expect(error, isNull, reason: '$where: $error');
}

/// [finder]'s text is drawn whole: a box too short for its line cuts the
/// text off without reporting any overflow.
void _expectWholeText(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    expect(p.size.height, greaterThanOrEqualTo(p.textSize.height - _eps),
        reason: '$where: "${p.text.toPlainText()}" cut off');
  }
}

/// Every widget [finder] matches is [height] tall.
void _expectHeights(
    WidgetTester tester, Finder finder, double height, String where) {
  final count = finder.evaluate().length;
  expect(count, greaterThan(0), reason: where);
  for (var i = 0; i < count; i++) {
    expect(tester.getSize(finder.at(i)).height, closeTo(height, _eps),
        reason: where);
  }
}

/// [text] is drawn in full: not ellipsized (it may be shrunk to fit).
void _expectUntruncated(WidgetTester tester, String text, String where) {
  final p = tester.renderObject<RenderParagraph>(find.text(text));
  expect(p.didExceedMaxLines, isFalse, reason: '$where: "$text" truncated');
}

/// Whether [finder] is drawn at its laid-out size (no FittedBox shrink).
bool _drawnAtFullSize(WidgetTester tester, Finder finder) =>
    (tester.getRect(finder).width - tester.getSize(finder).width).abs() < _eps;

const _statCard = StatCard(
  label: 'Dues collected (this month)',
  value: '৳-12,345.67',
  iconBuilder: AppIcons.collected,
  color: AppColors.paymentPaid,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRoboto();
    // The settings provider loads the symbol from preferences.
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    CurrencyFormatter.setSymbol('৳');
  });

  group('slot heights', () {
    test('are the coded ones at the default text size', () {
      for (final scaler in [TextScaler.noScaling, const TextScaler.linear(1)]) {
        expect(statCardHeight(scaler), 110);
        expect(dashboardHeaderHeight(scaler), 160);
        expect(reportsChipRowHeight(scaler), 36);
      }
    });

    test('follow the text they hold', () {
      double grow(double base, double perScale, double t) =>
          base + perScale * (t - 1);
      for (final t in _textScales) {
        final scaler = TextScaler.linear(t);
        // Stat card value + label: 20 px × 1.27 + 11 px × 1.43.
        expect(statCardHeight(scaler), closeTo(grow(110, 41.13, t), 1e-9));
        // Date pill + revenue label (11 px) and amount (24 px), × 1.43.
        expect(dashboardHeaderHeight(scaler), closeTo(grow(160, 65.78, t), 1e-9));
        // A 12 px chip label, × 1.43.
        expect(reportsChipRowHeight(scaler), closeTo(grow(36, 17.16, t), 1e-9));
      }
      // Toolbar, 4, chips, 6, date line, 4, TabBar: the date line no longer
      // runs into the top of the TabBar.
      expect(reportsHeaderHeight(TextScaler.noScaling, 48),
          closeTo(56 + 4 + 36 + 6 + 17.16 + 4 + 48, 1e-9));
    });
  });

  group('stat card', () {
    testWidgets('fits its slot at every text size and card width',
        (tester) async {
      addTearDown(tester.view.reset);
      _setScreen(tester, 400);
      // 105–111: two columns at 130% Display size / on a 320 dp layout;
      // 151: two columns on a 400 dp phone.
      for (final width in [105.0, 111.0, 151.0]) {
        for (final t in _textScales) {
          final where = 'a $width px card at ${t}x text';
          await _pumpApp(
            tester,
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  height: statCardHeight(TextScaler.linear(t)),
                  child: _statCard,
                ),
              ),
            ),
            textScale: t,
          );
          _expectCleanLayout(tester, where);
          _expectWholeText(
              tester, find.text('Dues collected (this month)'), where);
          // The number is shrunk into the card, never cut off.
          _expectUntruncated(tester, '৳-12,345.67', where);
          final card = tester.getRect(find.byType(StatCard)).deflate(14);
          final value = tester.getRect(find.text('৳-12,345.67'));
          expect(value.left, greaterThanOrEqualTo(card.left - _eps),
              reason: where);
          expect(value.right, lessThanOrEqualTo(card.right + _eps),
              reason: where);
        }
      }
    });

    testWidgets('keeps the value at full size when it fits', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      _setScreen(tester, 400);
      await _pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: SizedBox(
              width: 151,
              height: 110,
              child: StatCard(
                label: 'Revenue (month)',
                value: '৳123.5K',
                iconBuilder: AppIcons.revenue,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      );
      _expectCleanLayout(tester, 'a 151 px card at 1x text');
      expect(_drawnAtFullSize(tester, find.text('৳123.5K')), isTrue);
    });

    testWidgets('the old fixed 110 px slot clipped 130% text', (tester) async {
      requireRoboto();
      // Guards the checks above: the same card in the old slot overflows.
      addTearDown(tester.view.reset);
      _setScreen(tester, 400);
      await _pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: SizedBox(width: 151, height: 110, child: _statCard),
          ),
        ),
        textScale: 1.3,
      );
      expect(
        tester.takeException(),
        isA<FlutterError>()
            .having((e) => e.toString(), 'message', contains('overflowed')),
      );
    });

    testWidgets('KPI grids lay out at every text size and width',
        (tester) async {
      addTearDown(tester.view.reset);
      final kpis = [
        for (final (label, value) in [
          ('Net sales', '৳1,234,567.89'),
          ('Gross profit', '৳-12,345.67'),
          ('Average order value', '৳999.99'),
          ('Orders', '12345'),
        ])
          (
            label: label,
            value: value,
            icon: AppIcons.revenue,
            color: AppColors.primary,
          ),
      ];
      for (final width in _screenWidths) {
        for (final t in _textScales) {
          final where = '$width dp at ${t}x text';
          _setScreen(tester, width);
          await _pumpApp(
            tester,
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [KpiGrid(items: kpis)],
              ),
            ),
            textScale: t,
          );
          _expectCleanLayout(tester, where);
          _expectHeights(tester, find.byType(StatCard),
              statCardHeight(TextScaler.linear(t)), where);
        }
      }
    });
  });

  group('dashboard', () {
    const stats = DashboardStats(
      todayRevenue: 123456.78,
      thisMonthRevenue: 2345678.9,
      thisMonthProfit: -12345.67,
      totalOrders: 12345,
      pendingOrders: 1234,
    );
    List<Override> overrides(AsyncValue<DashboardStats> value) => [
          // Neither Play nor GitHub is asked for an update.
          updateChannelProvider
              .overrideWithValue(const AsyncValue.data(UpdateChannel.none)),
          dashboardStatsProvider.overrideWithValue(value),
          duesProvider
              .overrideWithValue(const AsyncValue.data(<CustomerDue>[])),
          duesCollectedThisMonthProvider
              .overrideWithValue(const AsyncValue.data(98765.43)),
          expensesProvider
              .overrideWithValue(const AsyncValue.data(<Expense>[])),
        ];

    testWidgets('lays out at every text size and width', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in _screenWidths) {
        for (final t in _textScales) {
          final where = '$width dp at ${t}x text';
          _setScreen(tester, width);
          await _pumpApp(
            tester,
            const DashboardScreen(),
            textScale: t,
            overrides: overrides(const AsyncValue.data(stats)),
          );
          await tester.pumpAndSettle();
          _expectCleanLayout(tester, where);

          // Header: today's revenue sits inside it, beside the order count.
          final header = dashboardHeaderHeight(TextScaler.linear(t));
          _expectUntruncated(tester, '৳123,456.78', where);
          final revenue = tester.getRect(find.text('৳123,456.78'));
          final orders = tester.getRect(find.text('12345'));
          expect(revenue.bottom, lessThanOrEqualTo(header + _eps),
              reason: where);
          expect(revenue.right, lessThanOrEqualTo(orders.left + _eps),
              reason: where);
          expect(orders.right, lessThanOrEqualTo(width - 20 + _eps),
              reason: where);

          // Date range bar: the custom-range button stays on screen.
          final button = tester.getRect(find.byTooltip('Custom Range'));
          expect(button.right, lessThanOrEqualTo(width - 16 + _eps),
              reason: where);

          _expectHeights(tester, find.byType(StatCard),
              statCardHeight(TextScaler.linear(t)), where);

          // Unchanged on a 400 dp phone at 100%: the chips fit unscrolled.
          if (width == 400 && t == 1.0) {
            final chips = tester.state<ScrollableState>(find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            ));
            expect(chips.position.maxScrollExtent, 0, reason: where);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('its loading skeleton uses the same card height',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final t in _textScales) {
        final where = '320 dp at ${t}x text';
        _setScreen(tester, 320);
        await _pumpApp(
          tester,
          const DashboardScreen(),
          textScale: t,
          overrides: overrides(const AsyncValue.loading()),
        );
        _expectCleanLayout(tester, where);
        _expectHeights(tester, find.byType(LoadingShimmer),
            statCardHeight(TextScaler.linear(t)), where);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  testWidgets('the reports header fits its chips and date line above the tabs',
      (tester) async {
    requireRoboto();
    addTearDown(tester.view.reset);
    final dateLine = find.textContaining(DateFormatter.format(DateTime.now()));
    for (final width in _screenWidths) {
      for (final t in _textScales) {
        final where = '$width dp at ${t}x text';
        _setScreen(tester, width);
        await _pumpApp(
          tester,
          const ReportsScreen(),
          textScale: t,
          // No database here: the reports themselves stay loading.
          overrides: [
            isarProvider.overrideWithValue(const AsyncValue.loading()),
          ],
        );
        _expectCleanLayout(tester, where);

        _expectWholeText(tester, find.text('Today'), where);
        _expectWholeText(tester, find.text('This Month'), where);
        final chip = tester.getRect(find.text('Today'));
        final date = tester.getRect(dateLine);
        final tabs = tester.getRect(find.byType(TabBar));
        expect(date.top, greaterThanOrEqualTo(chip.bottom), reason: where);
        expect(date.bottom, lessThanOrEqualTo(tabs.top + _eps), reason: where);
        expect(date.right, lessThanOrEqualTo(width - 20 + _eps),
            reason: where);
        expect(tabs.bottom,
            closeTo(reportsHeaderHeight(TextScaler.linear(t), 48), _eps),
            reason: where);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  group('product tile', () {
    testWidgets('fits its price and stock badge at every text size and width',
        (tester) async {
      addTearDown(tester.view.reset);
      _setScreen(tester, 400);
      final products = [
        Product(name: 'Rice', sellingPrice: 250, stockQty: 0),
        Product(name: 'Oil', sellingPrice: 1234.5, stockQty: 5),
        Product(name: 'Phone', sellingPrice: 1234567.89, stockQty: 50),
      ];
      // Tile widths (the grid is 0.78 wide:tall): a 400 dp phone at 100% and
      // 115% Display size, the 320 dp layout, and 130% on a 400 dp phone.
      for (final tile in [150.0, 124.0, 110.0, 104.0]) {
        for (final t in _textScales) {
          for (final product in products) {
            final price = CurrencyFormatter.format(product.sellingPrice);
            final where = '$price in a $tile px tile at ${t}x text';
            await _pumpApp(
              tester,
              Scaffold(
                body: Center(
                  child: SizedBox(
                    width: tile,
                    height: tile / 0.78,
                    child: ProductCard(product: product),
                  ),
                ),
              ),
              textScale: t,
            );
            _expectCleanLayout(tester, where);
            final row = tester.getRect(find.byType(ProductCard)).deflate(10);
            _expectUntruncated(tester, price, where);
            final priceRect = tester.getRect(find.text(price));
            final badge = tester.getRect(find.byType(StockBadge));
            expect(priceRect.left, greaterThanOrEqualTo(row.left - _eps),
                reason: where);
            expect(priceRect.right, lessThanOrEqualTo(badge.left + _eps),
                reason: where);
            expect(badge.right, lessThanOrEqualTo(row.right + _eps),
                reason: where);
          }
        }
      }
    });

    testWidgets('is unchanged at 100% wherever its row fits', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      _setScreen(tester, 400);
      // Two-column tiles on a 400 dp phone (150) and a 360 dp phone (130).
      for (final (tile, product) in [
        (150.0, Product(name: 'Oil', sellingPrice: 1234.5, stockQty: 5)),
        (150.0, Product(name: 'Rice', sellingPrice: 250, stockQty: 0)),
        (130.0, Product(name: 'Rice', sellingPrice: 250, stockQty: 0)),
      ]) {
        final price = CurrencyFormatter.format(product.sellingPrice);
        final where = '$price in a $tile px tile at 1x text';
        await _pumpApp(
          tester,
          Scaffold(
            body: Center(
              child: SizedBox(
                width: tile,
                height: tile / 0.78,
                child: ProductCard(product: product),
              ),
            ),
          ),
        );
        _expectCleanLayout(tester, where);
        // Price and badge at their own size, at the two ends of the row.
        final row = tester.getRect(find.byType(ProductCard)).deflate(10);
        expect(_drawnAtFullSize(tester, find.byType(StockBadge)), isTrue,
            reason: where);
        expect(_drawnAtFullSize(tester, find.text(price)), isTrue,
            reason: where);
        expect(tester.getRect(find.text(price)).left,
            closeTo(row.left, _eps),
            reason: where);
        expect(tester.getRect(find.byType(StockBadge)).right,
            closeTo(row.right, _eps),
            reason: where);
      }
    });
  });

  testWidgets('variant option fields grow with the text instead of clipping',
      (tester) async {
    addTearDown(tester.view.reset);
    final product = Product(
      name: 'T-Shirt',
      sellingPrice: 450,
      variantAttributes: [
        VariantAttribute(name: 'Size', options: ['Small', 'Medium', 'XL']),
      ],
    );
    for (final t in _textScales) {
      final where = 'option fields at ${t}x text';
      // Tall enough that the whole form is on screen.
      _setScreen(tester, 400, height: 2400);
      await _pumpApp(
        tester,
        ProductFormScreen(product: product),
        textScale: t,
        overrides: [
          categoriesProvider
              .overrideWithValue(const AsyncValue.data(<Category>[])),
        ],
      );
      // Only the option fields are checked here. (The form's save button,
      // a shared AppButton, styles its label without a font family: tests
      // draw that in the wide square test font, so it overflows here.)
      tester.takeException();
      for (final option in ['Small', 'Medium', 'XL']) {
        final field = tester.getSize(find.ancestor(
          of: find.text(option),
          matching: find.byType(TextField),
        ));
        final line = tester.allRenderObjects
            .whereType<RenderEditable>()
            .singleWhere((r) => r.text?.toPlainText() == option)
            .preferredLineHeight;
        expect(field.width, 100, reason: where);
        // The coded 36 px, or 8 px of padding above and below the line when
        // that's taller: the text is never cut off.
        expect(field.height, closeTo(math.max(36.0, line + 16), _eps),
            reason: where);
        if (t >= 1.3) expect(field.height, greaterThan(36), reason: where);
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
