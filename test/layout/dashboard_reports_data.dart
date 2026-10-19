import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/expense.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/report_service.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';
import 'package:micro_seller/features/dashboard/providers/dashboard_provider.dart';
import 'package:micro_seller/features/expenses/providers/expense_provider.dart';
import 'package:micro_seller/features/reports/providers/reports_provider.dart';

// Worst-case data for the Dashboard and Reports layout tests: long names
// and SKUs, eight-digit amounts, every status, method and reason, and a
// checker that every piece of text on screen is drawn whole.

/// A long shop / customer / product name, as sellers really type them.
const kLongName = 'Mohammad Abdur Rahman Chowdhury Trading Co.';

/// An eight-digit amount: "৳12,345,678.90" in full, "৳12.3M" compact.
const kBig = 12345678.9;

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

// ─── Dashboard ──────────────────────────────────────────────────────────────

CustomerDue _due(int i, int daysAgo, double amount, {String? name}) {
  final customerName = name ?? '$kLongName $i';
  final order = Order(
    id: 100 + i,
    orderNumber: 'ORD-12345$i',
    customerId: i + 1,
    customerName: customerName,
    totalAmount: amount,
    createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
  );
  return CustomerDue(
    customer: Customer(id: i + 1, name: customerName, phone: '01712345678'),
    orderDues: [OrderDue(order, amount)],
    totalDue: amount,
  );
}

/// Customers owing eight-digit sums for 400 days (the 60+ days banner), 45
/// days and 3 days.
List<CustomerDue> worstDues() => [
      _due(0, 400, kBig),
      _due(1, 45, kBig * 2),
      _due(2, 3, 98765432.1),
      _due(3, 1, 1234.5),
    ];

/// Low-stock products: an out-of-stock one and huge counts left.
List<Product> worstLowStock() => [
      for (var i = 0; i < 5; i++)
        Product(
          id: i + 1,
          name: '$kLongName Premium Basmati Rice 25 kg $i',
          sku: 'SKU-BASMATI-PREMIUM-25KG-000$i-EXTRA-LONG-CODE',
          sellingPrice: kBig,
          stockQty: i == 0 ? 0 : 123456 * i,
          lowStockThreshold: 999999,
        ),
    ];

DashboardStats worstDashboardStats() => DashboardStats(
      todayRevenue: kBig,
      thisMonthRevenue: kBig * 10,
      thisMonthProfit: -1234567.89,
      totalOrders: 1234567,
      pendingOrders: 123456,
      lowStockProducts: worstLowStock(),
      weeklySales: [
        for (var i = 6; i >= 0; i--)
          DailySales(
            date: _today.subtract(Duration(days: i)),
            revenue: kBig + i * 1000,
            profit: i.isEven ? 1234567.8 : 234567.8,
          ),
      ],
      statusCounts: {
        for (final status in OrderStatus.values) status: 123456 + status.index,
      },
    );

/// What a typical shop shows: the layout must look as it always did.
List<CustomerDue> typicalDues() => [
      _due(0, 75, 2500, name: 'Rahim Uddin'),
      _due(1, 40, 12000, name: 'Karim Store'),
      _due(2, 5, 850, name: 'Nasima Begum'),
    ];

DashboardStats typicalDashboardStats() => DashboardStats(
      todayRevenue: 12500,
      thisMonthRevenue: 345678.5,
      thisMonthProfit: 45230,
      totalOrders: 1234,
      pendingOrders: 12,
      lowStockProducts: [
        Product(
            id: 1,
            name: 'Basmati Rice 5 kg',
            sku: 'RICE-5KG',
            sellingPrice: 850,
            stockQty: 3),
        Product(
            id: 2,
            name: 'Soybean Oil 1 L',
            sku: 'OIL-1L',
            sellingPrice: 190,
            stockQty: 0),
      ],
      weeklySales: [
        for (var i = 6; i >= 0; i--)
          DailySales(
            date: _today.subtract(Duration(days: i)),
            revenue: 5000.0 + i * 2100,
            profit: 900.0 + i * 310,
          ),
      ],
      statusCounts: const {
        OrderStatus.pending: 12,
        OrderStatus.confirmed: 30,
        OrderStatus.shipped: 8,
        OrderStatus.completed: 240,
        OrderStatus.cancelled: 5,
      },
    );

List<Override> dashboardOverrides({
  required DashboardStats stats,
  List<CustomerDue> dues = const [],
  double collected = 0,
}) =>
    [
      dashboardStatsProvider.overrideWithValue(AsyncValue.data(stats)),
      duesProvider.overrideWithValue(AsyncValue.data(dues)),
      duesCollectedThisMonthProvider
          .overrideWithValue(AsyncValue.data(collected)),
      expensesProvider.overrideWithValue(AsyncValue.data([
        Expense(title: kLongName, amount: kBig, date: _today),
        Expense(
          title: 'Courier',
          amount: 1234567.8,
          date: _today.subtract(const Duration(days: 2)),
        ),
      ])),
    ];

// ─── Reports ────────────────────────────────────────────────────────────────

/// The range the Reports screen opens on (this month), which is what the
/// overrides below answer for.
(DateTime, DateTime) thisMonthRange() {
  final now = DateTime.now();
  return (DateTime(now.year, now.month), _today);
}

Map<String, double> _names(String prefix, int n, {bool blank = false}) => {
      if (blank) '': kBig * 3,
      for (var i = 0; i < n; i++) '$prefix $kLongName ${i + 1}': kBig - i,
    };

SalesReport worstSalesReport({bool empty = false, bool byMonth = false}) {
  final start = thisMonthRange().$1;
  final series = [
    for (var i = 0; i < (byMonth ? 12 : 31); i++)
      (
        bucket: byMonth
            ? DateTime(start.year, i + 1)
            : start.add(Duration(days: i)),
        value: i == 3 ? -kBig / 4 : kBig - i * 1000,
      ),
  ];
  return SalesReport(
    grossSales: kBig * 10,
    discounts: kBig,
    returnsValue: 1234567.89,
    cogs: kBig * 5,
    deliveryCharges: 1234567.8,
    taxCollected: empty ? 0 : 9876543.21,
    billedSales: kBig * 11,
    expenses: kBig * 3,
    orderCount: empty ? 0 : 1234567,
    returnCount: 12345,
    byStatus: empty
        ? const {}
        : {for (final s in OrderStatus.values) s: 1234567 + s.index},
    byPaymentMethod: empty
        ? const {}
        : {
            for (final m in PaymentMethod.values)
              m: m == PaymentMethod.other ? -1234567.89 : kBig * (m.index + 1),
          },
    series: empty ? const [] : series,
    profitSeries: empty ? const [] : series,
    seriesByMonth: byMonth,
    topProducts: empty ? const {} : _names('Product', 10),
    topProductsByQty: empty ? const {} : _names('Product', 10),
    byCategory: empty ? const {} : _names('Category', 6, blank: true),
    topCustomers: empty ? const {} : _names('Customer', 10, blank: true),
  );
}

DuesReport worstDuesReport({bool empty = false}) {
  final dues = empty ? <CustomerDue>[] : worstDues();
  return DuesReport(
    collectedByMethod: empty
        ? const {}
        : {
            for (final m in PaymentMethod.values)
              m: m == PaymentMethod.other ? -1234567.89 : kBig * (m.index + 1),
          },
    duesCollected: kBig * 4,
    creditGiven: kBig * 7,
    refundsPaid: 1234567.89,
    summary: empty
        ? const DueSummary()
        : const DueSummary(
            total: 987654321.09,
            customerCount: 123456,
            under30: kBig,
            from30to60: kBig * 20,
            over60: 852369741.2,
            over60Count: 12345,
          ),
    topDebtors: dues,
  );
}

InventoryReport worstInventoryReport({bool empty = false}) => InventoryReport(
      stockValueAtCost: kBig * 30,
      stockValueAtPrice: kBig * 45,
      activeProducts: 123456,
      lowStockCount: 12345,
      outOfStockCount: 6789,
      movementQty: empty
          ? const {}
          : {for (final t in StockMovementType.values) t: 1234567 + t.index},
      bestSellers: empty ? const {} : _names('Product', 10),
      slowMovers: empty
          ? const {}
          : {
              for (var i = 0; i < 10; i++)
                'Slow $kLongName ${i + 1}': 1234567.0 - i,
            },
      returnCount: 12345,
      returnedValue: kBig,
      refunded: empty ? 0 : kBig * 2,
      returnsByReason: empty
          ? const {}
          : {for (final r in ReturnReason.values) r: 123456 + r.index},
    );

PurchasesReport worstPurchasesReport({bool empty = false}) => PurchasesReport(
      purchaseCount: 1234567,
      purchased: kBig * 9,
      paid: kBig * 2,
      owedToSuppliersToday: kBig * 7,
      topSuppliers: empty ? const {} : _names('Supplier', 10, blank: true),
      expensesByCategory: empty
          ? const {}
          : {for (final c in ExpenseCategory.values) c: kBig * (c.index + 1)},
      registerSessions: 123456,
      cashIn: kBig * 3,
      cashOut: kBig,
      overShort: -1234567.89,
    );

List<Override> reportOverrides({bool empty = false, bool byMonth = false}) {
  final (from, to) = thisMonthRange();
  return [
    salesReportProvider(from, to).overrideWithValue(
        AsyncValue.data(worstSalesReport(empty: empty, byMonth: byMonth))),
    duesReportProvider(from, to)
        .overrideWithValue(AsyncValue.data(worstDuesReport(empty: empty))),
    inventoryReportProvider(from, to).overrideWithValue(
        AsyncValue.data(worstInventoryReport(empty: empty))),
    purchasesReportProvider(from, to).overrideWithValue(
        AsyncValue.data(worstPurchasesReport(empty: empty))),
  ];
}

// ─── Checks ─────────────────────────────────────────────────────────────────

const _eps = 0.01;

/// An amount as the app formats it, full ("৳12,345,678.90", "৳-12.5") or
/// compact ("৳12.3M").
final _amount = RegExp(r'৳-?[\d,]+(?:\.\d+)?[KM]?');

/// Render objects of the horizontally scrolling rows on screen (chip rows,
/// the TabBar), whose content may run past the screen edge on purpose. A
/// TabBarView's pages are not among them.
Set<RenderObject> _sidewaysScrollers(WidgetTester tester) => {
      for (final e in find
          .byWidgetPredicate((w) =>
              w is Scrollable &&
              axisDirectionToAxis(w.axisDirection) == Axis.horizontal &&
              w.controller is! PageController)
          .evaluate())
        ?e.renderObject,
    };

bool _inside(RenderObject child, Set<RenderObject> ancestors) {
  for (var r = child.parent; r != null; r = r.parent) {
    if (ancestors.contains(r)) return true;
  }
  return false;
}

/// Every paragraph laid out on screen is drawn whole:
/// * as tall and as wide as its text (nothing clipped or painted outside
///   its box),
/// * an amount is never ellipsized or broken over two lines,
/// * and, outside sideways-scrolling rows, it stays on screen.
void expectTextIntact(WidgetTester tester, String where) {
  final screenWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final scrollers = _sidewaysScrollers(tester);
  var checked = 0;
  // An element and its descendants share a render object: count each once.
  for (final p in tester.allRenderObjects.whereType<RenderParagraph>().toSet()) {
    if (!p.attached || !p.hasSize) continue;
    final text = p.text.toPlainText();
    if (text.trim().isEmpty) continue;
    checked++;
    expect(p.size.height, greaterThanOrEqualTo(p.textSize.height - _eps),
        reason: '$where: "$text" is cut off at the bottom');
    expect(p.size.width, greaterThanOrEqualTo(p.textSize.width - _eps),
        reason: '$where: "$text" runs past its box');
    for (final m in _amount.allMatches(text)) {
      expect(p.didExceedMaxLines, isFalse,
          reason: '$where: "$text" is ellipsized');
      final lines = p
          .getBoxesForSelection(
              TextSelection(baseOffset: m.start, extentOffset: m.end))
          .map((b) => b.top.round())
          .toSet();
      expect(lines.length, 1,
          reason: '$where: "${m[0]}" is broken over lines in "$text"');
    }
    if (!_inside(p, scrollers)) {
      final left = p.localToGlobal(Offset.zero).dx;
      final right = p.localToGlobal(Offset(p.size.width, 0)).dx;
      expect(left, greaterThanOrEqualTo(-_eps),
          reason: '$where: "$text" starts off screen ($left)');
      expect(right, lessThanOrEqualTo(screenWidth + _eps),
          reason: '$where: "$text" ends off screen ($right > $screenWidth)');
    }
  }
  expect(checked, greaterThan(0), reason: '$where: no text on screen');
}

/// Whether [finder] is drawn at its laid-out size (no FittedBox shrink).
bool drawnAtFullSize(WidgetTester tester, Finder finder) =>
    (tester.getRect(finder).width - tester.getSize(finder).width).abs() <
    _eps;
