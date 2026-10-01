import '../models/cash_register.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/stock_movement.dart';
import '../models/supplier.dart';
import '../../core/utils/currency_formatter.dart';
import '../../features/customers/providers/dues_provider.dart';
import 'dues_service.dart';

/// Business reports — pure functions over already-loaded rows (no Isar), so
/// every number here is unit-testable. Providers in
/// `features/reports/providers/reports_provider.dart` load the rows for a
/// date range and call these.
///
/// Periods are `[start, end)` — callers pass the start of the first day and
/// the start of the day *after* the last one.

/// Resolves a translation key (e.g. `AppStrings.of(context).tr`). Reports
/// take this instead of a BuildContext so they stay pure.
typedef ReportTr = String Function(String key);

/// One exportable table — the single shape both CSV and PDF render from, so
/// the two exports always match each other and the screen.
///
/// Cells are `String`, `int` (counts) or `double` (money). Keeping money as
/// numbers lets the CSV be summed/sorted in Excel; the PDF formats them with
/// [formatCell]. Deductions are negative numbers.
class ReportTable {
  const ReportTable(this.title, this.headers, this.rows);
  final String title;
  final List<String> headers;
  final List<List<Object>> rows;
}

/// Display form of a [ReportTable] cell (PDF / screen).
String formatCell(Object c) => switch (c) {
      double v => CurrencyFormatter.format(v),
      int v => '$v',
      _ => c.toString(),
    };

bool _inRange(DateTime? d, DateTime start, DateTime end) =>
    d != null && !d.isBefore(start) && d.isBefore(end);

/// When a return "happens" for reporting: when its goods came back.
DateTime? returnDate(Order r) => r.updatedAt ?? r.createdAt;

/// Returns whose goods are back in the shop (approved/received or refunded).
bool isCompletedReturn(Order o) =>
    o.isReturn &&
    (o.returnStatus == ReturnStatus.received ||
        o.returnStatus == ReturnStatus.refunded);

Map<K, double> _topN<K>(Map<K, double> m, int n) {
  final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(e.take(n));
}


// ─── Profit & Sales ──────────────────────────────────────────────────────

class SalesReport {
  const SalesReport({
    required this.grossSales,
    required this.returnsValue,
    required this.cogs,
    required this.expenses,
    required this.orderCount,
    required this.returnCount,
    required this.byStatus,
    required this.byPaymentMethod,
    required this.series,
    required this.seriesByMonth,
    required this.topProducts,
    required this.topProductsByQty,
    required this.byCategory,
    required this.topCustomers,
  });

  final double grossSales;
  final double returnsValue;

  /// Cost of goods sold, net of goods returned.
  final double cogs;
  final double expenses;
  final int orderCount;
  final int returnCount;
  final Map<OrderStatus, int> byStatus;
  final Map<PaymentMethod, double> byPaymentMethod;

  /// Net sales per bucket (day, or month when [seriesByMonth]), in order.
  final List<({DateTime bucket, double value})> series;
  final bool seriesByMonth;
  final Map<String, double> topProducts;
  final Map<String, double> topProductsByQty;

  /// Keys are category names; the empty string means uncategorized.
  final Map<String, double> byCategory;

  /// Keys are customer names; the empty string means walk-in.
  final Map<String, double> topCustomers;

  double get netSales => grossSales - returnsValue;
  double get grossProfit => netSales - cogs;
  double get netProfit => grossProfit - expenses;
  double get avgOrderValue => orderCount == 0 ? 0 : grossSales / orderCount;
  double get marginPct => netSales == 0 ? 0 : netProfit / netSales * 100;

  List<ReportTable> toTables(ReportTr tr) => [
        ReportTable(tr('profitAndLoss'), [tr('item'), tr('amount')], [
          [tr('grossSales'), grossSales],
          [tr('returnsLabel'), -returnsValue],
          [tr('netSales'), netSales],
          [tr('costOfGoods'), -cogs],
          [tr('grossProfit'), grossProfit],
          [tr('totalExpenses'), -expenses],
          [tr('netProfit'), netProfit],
          [tr('netMargin'), '${marginPct.toStringAsFixed(1)}%'],
          [tr('totalOrders'), orderCount],
          [tr('avgOrderValue'), avgOrderValue],
        ]),
        ReportTable(tr('salesByPaymentMethod'), [tr('paymentMethod'), tr('amount')], [
          for (final e in byPaymentMethod.entries)
            [paymentMethodKeyLabel(tr, e.key), e.value],
        ]),
        ReportTable(tr('ordersByStatus'), [tr('status'), tr('orders')], [
          for (final e in byStatus.entries) [tr(e.key.name), e.value],
        ]),
        ReportTable(tr('topProducts'), [tr('product'), tr('amount')], [
          for (final e in topProducts.entries) [e.key, e.value],
        ]),
        ReportTable(tr('salesByCategory'), [tr('category'), tr('amount')], [
          for (final e in byCategory.entries)
            [e.key.isEmpty ? tr('uncategorized') : e.key, e.value],
        ]),
        ReportTable(tr('topCustomers'), [tr('customer'), tr('amount')], [
          for (final e in topCustomers.entries)
            [e.key.isEmpty ? tr('walkIn') : e.key, e.value],
        ]),
      ];
}

String paymentMethodKeyLabel(ReportTr tr, PaymentMethod m) => tr(m.name);

/// [productsById] supplies the category and the cost fallback for old
/// orders whose items have no frozen `costPrice`.
SalesReport buildSalesReport({
  required List<Order> orders,
  Set<int> cancelledOrderIds = const {},
  required Map<int, Product> productsById,
  required List<Expense> expenses,
  required DateTime start,
  required DateTime end,
}) {
  double costOf(OrderItem i) {
    final c = i.costPrice > 0 ? i.costPrice : (productsById[i.productId]?.costPrice ?? 0);
    return c * i.qty;
  }

  final byMonth = end.difference(start).inDays > 62;
  DateTime bucketOf(DateTime d) =>
      byMonth ? DateTime(d.year, d.month) : DateTime(d.year, d.month, d.day);
  final buckets = <DateTime, double>{};
  for (var d = bucketOf(start);
      d.isBefore(end);
      d = byMonth ? DateTime(d.year, d.month + 1) : DateTime(d.year, d.month, d.day + 1)) {
    buckets[d] = 0;
  }

  var gross = 0.0, returns = 0.0, cogs = 0.0;
  var orderCount = 0, returnCount = 0;
  final byStatus = <OrderStatus, int>{};
  final byMethod = <PaymentMethod, double>{};
  final productRev = <String, double>{};
  final productQty = <String, double>{};
  final category = <String, double>{};
  final customers = <String, double>{};

  for (final o in orders) {
    if (o.isReturn) {
      if (!isCompletedReturn(o) || !_inRange(returnDate(o), start, end)) {
        continue;
      }
      // Cancelling the original already took its sale out; subtracting the
      // return too would count it twice.
      if (cancelledOrderIds.contains(o.originalOrderId)) continue;
      returnCount++;
      returns += o.totalAmount;
      for (final i in o.items) {
        cogs -= costOf(i);
      }
      final b = bucketOf(returnDate(o)!);
      if (buckets.containsKey(b)) buckets[b] = buckets[b]! - o.totalAmount;
      continue;
    }
    if (o.orderStatus == OrderStatus.cancelled) continue;
    if (!_inRange(o.createdAt, start, end)) continue;

    orderCount++;
    gross += o.totalAmount;
    byStatus[o.orderStatus] = (byStatus[o.orderStatus] ?? 0) + 1;
    byMethod[o.paymentMethod] = (byMethod[o.paymentMethod] ?? 0) + o.totalAmount;
    customers[o.customerName] = (customers[o.customerName] ?? 0) + o.totalAmount;
    final b = bucketOf(o.createdAt!);
    if (buckets.containsKey(b)) buckets[b] = buckets[b]! + o.totalAmount;

    for (final i in o.items) {
      cogs += costOf(i);
      productRev[i.productName] = (productRev[i.productName] ?? 0) + i.totalPrice;
      productQty[i.productName] = (productQty[i.productName] ?? 0) + i.qty;
      final cat = productsById[i.productId]?.category ?? '';
      category[cat] = (category[cat] ?? 0) + i.totalPrice;
    }
  }

  final expenseTotal = expenses
      .where((e) => _inRange(e.date, start, end))
      .fold<double>(0, (s, e) => s + e.amount);

  return SalesReport(
    grossSales: gross,
    returnsValue: returns,
    cogs: cogs,
    expenses: expenseTotal,
    orderCount: orderCount,
    returnCount: returnCount,
    byStatus: byStatus,
    byPaymentMethod: _topN(byMethod, PaymentMethod.values.length),
    series: [for (final e in buckets.entries) (bucket: e.key, value: e.value)],
    seriesByMonth: byMonth,
    topProducts: _topN(productRev, 10),
    topProductsByQty: _topN(productQty, 10),
    byCategory: _topN(category, 10),
    topCustomers: _topN(customers, 10),
  );
}

// ─── Dues & Payments ─────────────────────────────────────────────────────

class DuesReport {
  const DuesReport({
    required this.collectedByMethod,
    required this.duesCollected,
    required this.creditGiven,
    required this.refundsPaid,
    required this.summary,
    required this.topDebtors,
  });

  /// Money received from customers in the period, by method, net of
  /// cancelled-order reversals.
  final Map<PaymentMethod, double> collectedByMethod;

  /// The part of that received against earlier credit sales.
  final double duesCollected;

  /// Unpaid amount left on orders created in the period.
  final double creditGiven;
  final double refundsPaid;

  /// As of today — not affected by the period.
  final DueSummary summary;
  final List<CustomerDue> topDebtors;

  double get totalCollected =>
      collectedByMethod.values.fold(0, (s, v) => s + v);

  List<ReportTable> toTables(ReportTr tr) => [
        ReportTable(tr('duesAndPayments'), [tr('item'), tr('amount')], [
          [tr('moneyReceived'), totalCollected],
          [tr('duesCollected'), duesCollected],
          [tr('creditGiven'), creditGiven],
          [tr('refundsPaid'), refundsPaid],
          [tr('totalReceivableToday'), summary.total],
          [tr('ageUnder30'), (summary.under30)],
          [tr('age30to60'), (summary.from30to60)],
          [tr('age60plus'), (summary.over60)],
        ]),
        ReportTable(tr('receivedByMethod'), [tr('paymentMethod'), tr('amount')], [
          for (final e in collectedByMethod.entries)
            [paymentMethodKeyLabel(tr, e.key), e.value],
        ]),
        ReportTable(tr('topDebtors'), [tr('customer'), tr('phone'), tr('amount')], [
          for (final d in topDebtors)
            [d.customer.name, d.customer.phone, d.totalDue],
        ]),
      ];
}

DuesReport buildDuesReport({
  required List<Payment> payments,
  required Map<int, Order> ordersById,
  required List<Order> ordersInPeriod,
  required List<CustomerDue> dues,
  required DateTime start,
  required DateTime end,
}) {
  final byMethod = <PaymentMethod, double>{};
  var refunds = 0.0;
  for (final p in payments) {
    if (!_inRange(p.paidAt, start, end)) continue;
    if (p.amount > 0) {
      byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amount;
    } else if (p.note == kCancelledPaymentNote) {
      // Cancelling a paid order hands the money back — net it out of what
      // was received, so "Refunds paid" means return refunds on every tab.
      byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amount;
    } else {
      refunds += -p.amount;
    }
  }

  // Same-day payments per order, to see what was left on credit at sale.
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  final paidAtSale = <int, double>{};
  final hasRows = <int>{};
  for (final p in payments) {
    final o = ordersById[p.orderId];
    hasRows.add(p.orderId);
    if (o?.createdAt == null || p.paidAt == null || p.amount <= 0) continue;
    if (sameDay(o!.createdAt!, p.paidAt!)) {
      paidAtSale[o.id] = (paidAtSale[o.id] ?? 0) + p.amount;
    }
  }
  var credit = 0.0;
  for (final o in ordersInPeriod) {
    if (o.isReturn || o.orderStatus == OrderStatus.cancelled) continue;
    if (!_inRange(o.createdAt, start, end)) continue;
    // Orders from before payment history have no rows: their amountPaid is
    // the best record of what was paid.
    final paid = hasRows.contains(o.id) ? (paidAtSale[o.id] ?? 0) : o.amountPaid;
    final left = o.totalAmount - paid;
    if (left > kDueEpsilon) credit += left;
  }

  final debtors = [...dues]..sort((a, b) => b.totalDue.compareTo(a.totalDue));

  return DuesReport(
    collectedByMethod: _topN(byMethod, PaymentMethod.values.length),
    duesCollected: duesCollectedBetween(payments, ordersById, start, end),
    creditGiven: credit,
    refundsPaid: refunds,
    summary: summarizeDues(dues),
    topDebtors: debtors.take(10).toList(),
  );
}

// ─── Inventory & Returns ─────────────────────────────────────────────────

class InventoryReport {
  const InventoryReport({
    required this.stockValueAtCost,
    required this.stockValueAtPrice,
    required this.activeProducts,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.movementQty,
    required this.bestSellers,
    required this.slowMovers,
    required this.returnCount,
    required this.returnedValue,
    required this.refunded,
    required this.returnsByReason,
  });

  /// As of today.
  final double stockValueAtCost;
  final double stockValueAtPrice;
  final int activeProducts;
  final int lowStockCount;
  final int outOfStockCount;

  /// Units moved in the period, per type (absolute quantities).
  final Map<StockMovementType, int> movementQty;
  final Map<String, double> bestSellers;

  /// In stock but not sold at all in the period — name → units on hand.
  final Map<String, double> slowMovers;
  final int returnCount;
  final double returnedValue;
  final double refunded;
  final Map<ReturnReason, int> returnsByReason;

  double get potentialProfit => stockValueAtPrice - stockValueAtCost;

  List<ReportTable> toTables(ReportTr tr) => [
        ReportTable(tr('inventoryAndReturns'), [tr('item'), tr('value')], [
          [tr('stockValueCost'), stockValueAtCost],
          [tr('stockValuePrice'), stockValueAtPrice],
          [tr('potentialProfit'), potentialProfit],
          [tr('activeProducts'), activeProducts],
          [tr('lowStockItems'), lowStockCount],
          [tr('outOfStock'), outOfStockCount],
          [tr('returnsLabel'), returnCount],
          [tr('returnedValue'), returnedValue],
          [tr('refundsPaid'), refunded],
        ]),
        ReportTable(tr('stockMovements'), [tr('type'), tr('quantity')], [
          for (final e in movementQty.entries) [tr(e.key.name), e.value],
        ]),
        ReportTable(tr('bestSellers'), [tr('product'), tr('quantity')], [
          for (final e in bestSellers.entries) [e.key, e.value.round()],
        ]),
        ReportTable(tr('slowMovers'), [tr('product'), tr('inStock')], [
          for (final e in slowMovers.entries) [e.key, e.value.round()],
        ]),
        ReportTable(tr('returnReasons'), [tr('reason'), tr('returnsLabel')], [
          for (final e in returnsByReason.entries) [tr(e.key.name), e.value],
        ]),
      ];
}

InventoryReport buildInventoryReport({
  required List<Product> products,
  required List<StockMovement> movements,
  required List<Order> orders,
  Set<int> cancelledOrderIds = const {},
  required DateTime start,
  required DateTime end,
}) {
  var atCost = 0.0, atPrice = 0.0;
  var active = 0, low = 0, out = 0;
  for (final p in products.where((p) => p.isActive)) {
    active++;
    if (p.isOutOfStock) {
      out++;
    } else if (p.isLowStock) {
      low++;
    }
    if (p.hasVariants) {
      for (final c in p.variantCombinations.where((c) => c.isActive)) {
        final q = c.stockQty < 0 ? 0 : c.stockQty;
        atCost += q * p.costPrice;
        atPrice += q * (p.sellingPrice + c.priceAdjustment);
      }
    } else {
      final q = p.stockQty < 0 ? 0 : p.stockQty;
      atCost += q * p.costPrice;
      atPrice += q * p.sellingPrice;
    }
  }

  final moved = <StockMovementType, int>{};
  for (final m in movements) {
    if (!_inRange(m.createdAt, start, end)) continue;
    moved[m.type] = (moved[m.type] ?? 0) + m.qty.abs();
  }

  final soldQty = <String, double>{};
  final soldIds = <int>{};
  var returnCount = 0;
  var returnedValue = 0.0, refunded = 0.0;
  final reasons = <ReturnReason, int>{};
  for (final o in orders) {
    if (o.isReturn) {
      if (!isCompletedReturn(o) || !_inRange(returnDate(o), start, end)) continue;
      if (cancelledOrderIds.contains(o.originalOrderId)) continue;
      returnCount++;
      returnedValue += o.totalAmount;
      if (o.returnStatus == ReturnStatus.refunded) refunded += o.refundAmount;
      reasons[o.returnReason] = (reasons[o.returnReason] ?? 0) + 1;
      continue;
    }
    if (o.orderStatus == OrderStatus.cancelled) continue;
    if (!_inRange(o.createdAt, start, end)) continue;
    for (final i in o.items) {
      soldIds.add(i.productId);
      soldQty[i.productName] = (soldQty[i.productName] ?? 0) + i.qty;
    }
  }

  final slow = <String, double>{
    for (final p in products)
      if (p.isActive && p.totalStock > 0 && !soldIds.contains(p.id))
        p.name: p.totalStock.toDouble(),
  };

  return InventoryReport(
    stockValueAtCost: atCost,
    stockValueAtPrice: atPrice,
    activeProducts: active,
    lowStockCount: low,
    outOfStockCount: out,
    movementQty: moved,
    bestSellers: _topN(soldQty, 10),
    slowMovers: _topN(slow, 10),
    returnCount: returnCount,
    returnedValue: returnedValue,
    refunded: refunded,
    returnsByReason: reasons,
  );
}

// ─── Purchases & Expenses ────────────────────────────────────────────────

class PurchasesReport {
  const PurchasesReport({
    required this.purchaseCount,
    required this.purchased,
    required this.paid,
    required this.owedToSuppliersToday,
    required this.topSuppliers,
    required this.expensesByCategory,
    required this.registerSessions,
    required this.cashIn,
    required this.cashOut,
    required this.overShort,
  });

  final int purchaseCount;
  final double purchased;
  final double paid;

  /// As of today, across all purchases.
  final double owedToSuppliersToday;

  /// Keys are supplier names; the empty string means no supplier linked.
  final Map<String, double> topSuppliers;
  final Map<ExpenseCategory, double> expensesByCategory;
  final int registerSessions;
  final double cashIn;
  final double cashOut;

  /// Sum of (counted − expected) over closed sessions; negative = short.
  final double overShort;

  double get unpaid => purchased - paid;
  double get totalExpenses =>
      expensesByCategory.values.fold(0, (s, v) => s + v);

  List<ReportTable> toTables(ReportTr tr) => [
        ReportTable(tr('purchasesAndExpenses'), [tr('item'), tr('amount')], [
          [tr('purchases'), purchaseCount],
          [tr('purchasedValue'), purchased],
          [tr('paidToSuppliers'), paid],
          [tr('unpaidInPeriod'), unpaid],
          [tr('owedToSuppliersToday'), owedToSuppliersToday],
          [tr('totalExpenses'), totalExpenses],
          [tr('registerSessions'), registerSessions],
          [tr('cashIn'), cashIn],
          [tr('cashOut'), cashOut],
          [tr('overShort'), overShort],
        ]),
        ReportTable(tr('expensesByCategory'), [tr('category'), tr('amount')], [
          for (final e in expensesByCategory.entries) [tr(e.key.name), e.value],
        ]),
        ReportTable(tr('topSuppliers'), [tr('supplier'), tr('amount')], [
          for (final e in topSuppliers.entries)
            [e.key.isEmpty ? tr('noSupplier') : e.key, e.value],
        ]),
      ];
}

PurchasesReport buildPurchasesReport({
  required List<Purchase> purchases,
  required List<Supplier> suppliers,
  required List<Expense> expenses,
  required List<CashRegister> registers,
  required DateTime start,
  required DateTime end,
}) {
  var count = 0;
  var purchased = 0.0, paid = 0.0, owedToday = 0.0;
  final bySupplier = <String, double>{};
  // Direct supplier payments lower `Supplier.totalDue` but not individual
  // purchases, so the supplier balance is the truth for linked purchases.
  for (final sup in suppliers) {
    owedToday += sup.totalDue > 0 ? sup.totalDue : 0;
  }
  for (final p in purchases) {
    if (p.supplierId == 0) owedToday += p.balanceDue;
    if (!_inRange(p.createdAt, start, end)) continue;
    count++;
    purchased += p.totalAmount;
    paid += p.amountPaid;
    bySupplier[p.supplierName] = (bySupplier[p.supplierName] ?? 0) + p.totalAmount;
  }

  final byCat = <ExpenseCategory, double>{};
  for (final e in expenses) {
    if (!_inRange(e.date, start, end)) continue;
    byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
  }

  var sessions = 0;
  var cashIn = 0.0, cashOut = 0.0, overShort = 0.0;
  for (final r in registers) {
    if (!r.isClosed || !_inRange(r.closedAt, start, end)) continue;
    sessions++;
    cashIn += r.totalCashIn;
    cashOut += r.totalCashOut;
    overShort += r.difference;
  }

  return PurchasesReport(
    purchaseCount: count,
    purchased: purchased,
    paid: paid,
    owedToSuppliersToday: owedToday,
    topSuppliers: _topN(bySupplier, 10),
    expensesByCategory: _topN(byCat, ExpenseCategory.values.length),
    registerSessions: sessions,
    cashIn: cashIn,
    cashOut: cashOut,
    overShort: overShort,
  );
}
