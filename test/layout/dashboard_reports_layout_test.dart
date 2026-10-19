import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/features/cash_register/providers/cash_register_provider.dart';
import 'package:micro_seller/features/dashboard/presentation/dashboard_screen.dart';
import 'package:micro_seller/features/dashboard/presentation/widgets/due_summary_card.dart';
import 'package:micro_seller/features/dashboard/presentation/widgets/low_stock_list.dart';
import 'package:micro_seller/features/dashboard/presentation/widgets/sales_chart.dart';
import 'package:micro_seller/features/dashboard/providers/dashboard_provider.dart';
import 'package:micro_seller/features/reports/presentation/reports_screen.dart';
import 'package:micro_seller/features/reports/presentation/widgets/report_widgets.dart';
import 'package:micro_seller/features/splash/presentation/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';
import 'dashboard_reports_data.dart';

// The Dashboard, every Reports tab and the Splash screen with worst-case
// data (long names, eight-digit amounts, every status and method) must lay
// out without an overflow and draw all of their text whole, at the narrowest
// layout the Display size allows up to a large phone font; and look as they
// always did at 100% text on a normal phone. (test/text_scale_layout_test.dart
// covers the headers, stat cards and loading states without data.)

const _eps = 0.01;

/// Tall enough that every section is laid out (slivers and list rows past
/// the viewport aren't), so every one is checked.
const _tall = 6000.0;

/// Section cards per Reports tab, all of which must be on screen.
const _sectionsPerTab = [7, 3, 5, 4];

Future<void> _pumpDashboard(
  WidgetTester tester,
  double width,
  double textScale, {
  required List<Override> overrides,
}) async {
  setLayoutScreen(tester, width, height: _tall);
  await pumpLayoutApp(tester, const DashboardScreen(),
      textScale: textScale, overrides: overrides);
  await tester.pumpAndSettle();
}

/// The Reports screen, on [tab] once its entrance has settled.
Future<void> _pumpReports(
  WidgetTester tester,
  double width,
  double textScale, {
  List<Override>? overrides,
}) async {
  setLayoutScreen(tester, width, height: _tall);
  await pumpLayoutApp(tester, const ReportsScreen(),
      textScale: textScale, overrides: overrides ?? reportOverrides());
  await tester.pumpAndSettle();
}

Future<void> _showTab(WidgetTester tester, int tab) async {
  tester.widget<TabBar>(find.byType(TabBar)).controller!.index = tab;
  await tester.pumpAndSettle();
}

/// The splash just before it navigates away (2.5 s): everything is in.
Future<void> _pumpSplash(
    WidgetTester tester, double width, double textScale) async {
  setLayoutScreen(tester, width, height: 800);
  await pumpLayoutApp(tester, const SplashScreen(),
      textScale: textScale, rail: false);
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every line of [p] is centered in it, but a last line cut short by an
/// ellipsis (which no selection box covers). Spaces are left out: one ending
/// a line hangs past it and isn't centered.
void _expectLinesCentered(RenderParagraph p, String where) {
  final text = p.text.toPlainText();
  final lines = <int, (double, double)>{};
  for (var i = 0; i < text.length; i++) {
    if (text[i].trim().isEmpty) continue;
    for (final box in p.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1))) {
      final key = box.top.round();
      final (left, right) = lines[key] ?? (box.left, box.right);
      lines[key] = (
        left < box.left ? left : box.left,
        right > box.right ? right : box.right,
      );
    }
  }
  final tops = lines.keys.toList()..sort();
  if (p.didExceedMaxLines) tops.removeLast();
  expect(tops, isNotEmpty, reason: where);
  for (final top in tops) {
    final (left, right) = lines[top]!;
    expect((left + right) / 2, closeTo(p.size.width / 2, 2),
        reason: '$where: line at $top of "$text" is not centered');
  }
}

void main() {
  setUpAll(() async {
    await loadRoboto();
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    CurrencyFormatter.setSymbol('৳');
  });

  test('chart labels keep their 22 px at the default text size', () {
    for (final scaler in [TextScaler.noScaling, const TextScaler.linear(1)]) {
      expect(axisTitleReserve(scaler, fontSize: 10, padding: 6), 22);
      expect(axisTitleReserve(scaler, fontSize: 9, padding: 4), 22);
    }
    // A 10 px label (1.43 line height) under 6 px of padding at 150%.
    expect(
        axisTitleReserve(const TextScaler.linear(1.5),
            fontSize: 10, padding: 6),
        greaterThanOrEqualTo(6 + 15 * 1.43));
  });

  group('dashboard with data', () {
    testWidgets('draws every section whole at every width and text size',
        (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = 'dashboard at $width dp, ${t}x text';
          await _pumpDashboard(tester, width, t,
              overrides: dashboardOverrides(
                stats: worstDashboardStats(),
                dues: worstDues(),
                collected: kBig,
              ));
          expectCleanLayout(tester, where);
          // Every section is on screen, so every one is checked.
          for (final section in [
            SalesChart,
            OrderStatusChart,
            RevenueExpenseChart,
            LowStockList,
            DueSummaryCard,
          ]) {
            expect(find.byType(section), findsOneWidget,
                reason: '$where: $section');
          }
          expect(find.textContaining('60+ days'), findsWidgets,
              reason: '$where: the overdue banner');
          expectTextIntact(tester, where);

          // The order-status legend stays inside its card.
          final chart = tester.getRect(find.byType(OrderStatusChart));
          for (final count in ['123456', '123460', '(20%)']) {
            final rect = tester.getRect(find.text(count).first);
            expect(rect.right, lessThanOrEqualTo(chart.right + _eps),
                reason: '$where: "$count" leaves the chart');
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('opens the collect sheet cleanly', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = 'collect sheet at $width dp, ${t}x text';
          await _pumpDashboard(tester, width, t, overrides: [
            ...dashboardOverrides(
                stats: worstDashboardStats(), dues: worstDues()),
            openRegisterProvider.overrideWithValue(const AsyncValue.data(null)),
          ]);
          await tester.tap(find.byTooltip('Collect').first);
          await tester.pumpAndSettle();
          // Show the allocation preview too.
          await tester.enterText(find.byType(TextField).first, '12345678.9');
          await tester.pumpAndSettle();
          expectCleanLayout(tester, where);
          expectTextIntact(tester, where);
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('lays out with empty sections', (tester) async {
      addTearDown(tester.view.reset);
      for (final t in kLayoutTextScales) {
        final where = 'empty dashboard at 320 dp, ${t}x text';
        await _pumpDashboard(tester, 320, t,
            overrides: dashboardOverrides(stats: const DashboardStats()));
        expectCleanLayout(tester, where);
        expectTextIntact(tester, where);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('is unchanged at 100% on a normal phone', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in [360.0, 411.0]) {
        final where = 'typical dashboard at $width dp, 1x text';
        await _pumpDashboard(tester, width, 1,
            overrides: dashboardOverrides(
              stats: typicalDashboardStats(),
              dues: typicalDues(),
              collected: 98765,
            ));
        expectCleanLayout(tester, where);

        // The legend beside the pie, in the chart's 140 px.
        expect(tester.getSize(find.byType(OrderStatusChart)).height, 140,
            reason: where);
        expect(tester.getRect(find.text('Completed')).left,
            greaterThan(tester.getRect(find.byType(PieChart)).right),
            reason: where);

        // Each amount to chase beside its customer's name, at full size.
        for (final (name, amount) in [
          ('Rahim Uddin', '৳2,500'),
          ('Karim Store', '৳12,000'),
          ('Nasima Begum', '৳850'),
        ]) {
          final amountFinder = find.descendant(
              of: find.byType(DueSummaryCard), matching: find.text(amount));
          expect(amountFinder, findsOneWidget, reason: '$where: $amount');
          expect(tester.getRect(amountFinder).left,
              greaterThanOrEqualTo(tester.getRect(find.text(name)).right),
              reason: '$where: $amount beside $name');
          expect(drawnAtFullSize(tester, amountFinder), isTrue,
              reason: '$where: $amount');
        }
        // The receivable at full size.
        expect(drawnAtFullSize(tester, find.text('৳15,350')), isTrue,
            reason: where);
        // The 60+ days banner keeps its text beside its Open button.
        expect(
            tester.getRect(find.textContaining('for 60+ days')).right,
            lessThanOrEqualTo(
                tester.getRect(find.widgetWithText(TextButton, 'Open')).left),
            reason: where);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('reports with data', () {
    testWidgets('draws every tab whole at every width and text size',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          await _pumpReports(tester, width, t);
          for (var tab = 0; tab < 4; tab++) {
            final where = 'reports tab $tab at $width dp, ${t}x text';
            await _showTab(tester, tab);
            expect(find.byType(ReportSectionCard),
                findsNWidgets(_sectionsPerTab[tab]),
                reason: '$where: every section on screen');
            expectCleanLayout(tester, where);
            expectTextIntact(tester, where);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('lays out monthly and empty reports', (tester) async {
      addTearDown(tester.view.reset);
      for (final t in kLayoutTextScales) {
        for (final (name, overrides) in [
          ('monthly', reportOverrides(byMonth: true)),
          ('empty', reportOverrides(empty: true)),
        ]) {
          await _pumpReports(tester, 320, t, overrides: overrides);
          for (var tab = 0; tab < 4; tab++) {
            final where = '$name reports tab $tab at 320 dp, ${t}x text';
            await _showTab(tester, tab);
            expectCleanLayout(tester, where);
            expectTextIntact(tester, where);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('opens the export sheet cleanly', (tester) async {
      addTearDown(tester.view.reset);
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = 'export sheet at $width dp, ${t}x text';
          await _pumpReports(tester, width, t);
          await _showTab(tester, 3);
          await tester.tap(find.byTooltip('Export'));
          await tester.pumpAndSettle();
          expect(find.text('Share as CSV'), findsOneWidget, reason: where);
          expectCleanLayout(tester, where);
          expectTextIntact(tester, where);
          await tester.pumpWidget(const SizedBox());
        }
      }
    });

    testWidgets('is unchanged at 100% on a normal phone', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in [360.0, 411.0]) {
        await _pumpReports(tester, width, 1);
        for (var tab = 0; tab < 4; tab++) {
          final where = 'reports tab $tab at $width dp, 1x text';
          await _showTab(tester, tab);
          expectCleanLayout(tester, where);
          // Every amount in a statement, a ranked list and a section at its
          // own size, none shrunk to fit. (The KPI cards' own FittedBox is
          // checked in text_scale_layout_test.dart.)
          final amounts = find.descendant(
              of: find.byType(ReportSectionCard),
              matching: find.textContaining('৳'));
          expect(amounts, findsWidgets, reason: where);
          for (var i = 0; i < amounts.evaluate().length; i++) {
            expect(drawnAtFullSize(tester, amounts.at(i)), isTrue,
                reason: '$where: '
                    '"${tester.widget<Text>(amounts.at(i)).data}" shrunk');
          }
        }
        // The average order value still ends the chart's title row.
        await _showTab(tester, 0);
        final title = tester.getRect(find.text('Daily net sales'));
        final badge = tester.getRect(find.textContaining('Avg Order Value'));
        expect(badge.top, lessThan(title.bottom), reason: '$width dp');
        expect(badge.left, greaterThanOrEqualTo(title.right - _eps),
            reason: '$width dp');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('splash', () {
    testWidgets('draws its text whole and centered at every size',
        (tester) async {
      addTearDown(tester.view.reset);
      for (final name in ['My Shop', kLongName]) {
        SharedPreferences.setMockInitialValues(
            {'currencySymbol': '৳', 'shopName': name});
        for (final width in kLayoutWidths) {
          for (final t in kLayoutTextScales) {
            final where = 'splash for "$name" at $width dp, ${t}x text';
            await _pumpSplash(tester, width, t);
            expectCleanLayout(tester, where);
            expectTextIntact(tester, where);
            // The shop name's lines are centered, clear of the edges.
            final title = tester.renderObject<RenderParagraph>(
                find.textContaining(name.substring(0, 5)));
            _expectLinesCentered(title, where);
            final rect = tester.getRect(find.textContaining(name.substring(0, 5)));
            expect(rect.left, greaterThan(0), reason: where);
            expect(rect.right, lessThan(width), reason: where);
            // The tagline stays on one line.
            final tagline = tester.renderObject<RenderParagraph>(
                find.text('INVENTORY  ·  ORDERS  ·  REPORTS'));
            expect(
                tagline.size.height,
                lessThan(1.5 *
                    tagline.getFullHeightForCaret(
                        const TextPosition(offset: 0))),
                reason: '$where: the tagline wraps');
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
      SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    });

    testWidgets('is unchanged at 100% on a normal phone', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(
          {'currencySymbol': '৳', 'shopName': 'My Shop'});
      for (final width in [360.0, 411.0]) {
        final where = 'splash at $width dp, 1x text';
        await _pumpSplash(tester, width, 1);
        expectCleanLayout(tester, where);
        final title = tester.renderObject<RenderParagraph>(find.text('My Shop'));
        expect(title.didExceedMaxLines, isFalse, reason: where);
        expect(title.size.height,
            lessThan(1.5 * title.getFullHeightForCaret(TextPosition(offset: 0))),
            reason: '$where: the title is one line');
        expect(
            drawnAtFullSize(
                tester, find.text('INVENTORY  ·  ORDERS  ·  REPORTS')),
            isTrue,
            reason: '$where: the tagline is shrunk');
        await tester.pumpWidget(const SizedBox());
      }
      SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
    });
  });
}
