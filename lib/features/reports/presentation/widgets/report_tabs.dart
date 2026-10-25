import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/aging_bar.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../providers/reports_provider.dart';
import 'report_widgets.dart';

/// The four Reports tabs. Each watches its own provider for the shared
/// `[from, to]` range picked in the header.

String _m(double v) => CurrencyFormatter.formatCompact(v);
String _full(double v) => CurrencyFormatter.format(v);

Widget _async<T>(
  BuildContext context,
  AsyncValue<T> value,
  Widget Function(T data) data,
) {
  final s = AppStrings.of(context);
  // Reports recompute when orders change; keep the last numbers up
  // meanwhile instead of flashing the shimmer.
  return value.when(
    skipLoadingOnReload: true,
    data: data,
    loading: () => const Padding(
      padding: EdgeInsets.all(16),
      child: LoadingShimmer(height: 400, borderRadius: 14),
    ),
    error: (e, _) => Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text('${s.errorOccurred}\n$e', textAlign: TextAlign.center)),
    ),
  );
}

List<Widget> _gap(List<Widget> children) => [
      for (final c in children) ...[c, const SizedBox(height: 14)],
    ];

// ─── Profit & Sales ──────────────────────────────────────────────────────

class SalesReportTab extends ConsumerWidget {
  const SalesReportTab({super.key, required this.from, required this.to});
  final DateTime from, to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final primary = context.brand.primary;
    return _async(context, ref.watch(salesReportProvider(from, to)), (r) {
      final empty = s.tr('noDataForPeriod');
      return ListView(
        padding: const EdgeInsets.all(16),
        children: _gap([
          KpiGrid(items: [
            (label: s.tr('netSales'), value: _m(r.netSales), icon: AppIcons.revenue, color: primary),
            (label: s.tr('grossProfit'), value: _m(r.grossProfit), icon: AppIcons.profit, color: const Color(0xFF42A5F5)),
            (label: s.tr('netProfit'), value: _m(r.netProfit), icon: AppIcons.collected,
              color: r.netProfit < 0 ? AppColors.paymentUnpaid : AppColors.paymentPaid),
            (label: s.tr('totalOrders'), value: '${r.orderCount}', icon: AppIcons.orders, color: AppColors.statusShipped),
          ]),
          ReportSectionCard(
            title: s.tr('profitAndLoss'),
            icon: AppIcons.reports,
            color: primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PnlTable(rows: [
                  (label: s.tr('grossSales'), amount: r.grossSales, strong: false, deduct: false),
                  (label: s.tr('discounts'), amount: r.discounts, strong: false, deduct: true),
                  (label: s.tr('returnsLabel'), amount: r.returnsValue, strong: false, deduct: true),
                  (label: s.tr('netSales'), amount: r.netSales, strong: true, deduct: false),
                  (label: s.tr('costOfGoods'), amount: r.cogs, strong: false, deduct: true),
                  (label: s.tr('grossProfit'), amount: r.grossProfit, strong: true, deduct: false),
                  (label: s.tr('deliveryCharges'), amount: r.deliveryCharges, strong: false, deduct: false),
                  (label: s.tr('totalExpenses'), amount: r.expenses, strong: false, deduct: true),
                  (label: s.tr('netProfit'), amount: r.netProfit, strong: true, deduct: false),
                ]),
                if (r.taxCollected.abs() >= 0.005)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      s.taxCollectedNote(_m(r.taxCollected)),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ),
              ],
            ),
          ),
          ReportSectionCard(
            title: s.tr(r.seriesByMonth ? 'monthlyNetSales' : 'dailyNetSales'),
            icon: AppIcons.revenue,
            color: primary,
            badge: '${s.tr('avgOrderValue')}: ${_m(r.avgOrderValue)}',
            child: NetSalesChart(series: r.series, byMonth: r.seriesByMonth),
          ),
          ReportSectionCard(
            title: s.tr('salesByPaymentMethod'),
            icon: AppIcons.expenses,
            color: const Color(0xFF7E57C2),
            child: r.byPaymentMethod.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: {for (final e in r.byPaymentMethod.entries) s.tr(e.key.name): e.value},
                    format: _m,
                    color: const Color(0xFF7E57C2),
                  ),
          ),
          ReportSectionCard(
            title: s.tr('ordersByStatus'),
            icon: AppIcons.orders,
            color: AppColors.statusShipped,
            child: r.byStatus.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: {for (final e in r.byStatus.entries) s.tr(e.key.name): e.value.toDouble()},
                    format: (v) => v.toStringAsFixed(0),
                    color: AppColors.statusShipped,
                  ),
          ),
          ReportSectionCard(
            title: s.topProducts,
            icon: AppIcons.products,
            color: primary,
            child: r.topProducts.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(entries: r.topProducts, format: _m, ranked: true),
          ),
          ReportSectionCard(
            title: s.salesByCategory,
            icon: AppIcons.categories,
            color: const Color(0xFFD81B60),
            child: r.byCategory.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: {
                      for (final e in r.byCategory.entries)
                        (e.key.isEmpty ? s.tr('uncategorized') : e.key): e.value,
                    },
                    format: _m,
                    color: const Color(0xFFD81B60),
                  ),
          ),
          ReportSectionCard(
            title: s.topCustomers,
            icon: AppIcons.customers,
            color: const Color(0xFF8E24AA),
            child: r.topCustomers.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: {
                      for (final e in r.topCustomers.entries)
                        (e.key.isEmpty ? s.tr('walkIn') : e.key): e.value,
                    },
                    format: _m,
                    ranked: true,
                    color: const Color(0xFF8E24AA),
                  ),
          ),
        ]),
      );
    });
  }
}

// ─── Dues & Payments ─────────────────────────────────────────────────────

class DuesReportTab extends ConsumerWidget {
  const DuesReportTab({super.key, required this.from, required this.to});
  final DateTime from, to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final primary = context.brand.primary;
    return _async(context, ref.watch(duesReportProvider(from, to)), (r) {
      final empty = s.tr('noDataForPeriod');
      return ListView(
        padding: const EdgeInsets.all(16),
        children: _gap([
          KpiGrid(items: [
            (label: s.tr('moneyReceived'), value: _m(r.totalCollected), icon: AppIcons.collected, color: AppColors.paymentPaid),
            (label: s.tr('duesCollected'), value: _m(r.duesCollected), icon: AppIcons.dueBook, color: primary),
            (label: s.tr('creditGiven'), value: _m(r.creditGiven), icon: AppIcons.pending, color: AppColors.paymentPartial),
            (label: s.tr('refundsPaid'), value: _m(r.refundsPaid), icon: AppIcons.returns, color: AppColors.paymentUnpaid),
          ]),
          ReportSectionCard(
            title: s.tr('totalReceivableToday'),
            icon: AppIcons.dueBook,
            color: AppColors.paymentUnpaid,
            badge: s.tr('asOfToday'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shrinks rather than breaking the number over two lines.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(_full(r.summary.total),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800, color: AppColors.paymentUnpaid),
                      maxLines: 1),
                ),
                Text(s.customersOwing(r.summary.customerCount),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                AgingBar(
                  under30: r.summary.under30,
                  from30to60: r.summary.from30to60,
                  over60: r.summary.over60,
                ),
              ],
            ),
          ),
          ReportSectionCard(
            title: s.tr('receivedByMethod'),
            icon: AppIcons.expenses,
            color: const Color(0xFF7E57C2),
            child: r.collectedByMethod.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: {for (final e in r.collectedByMethod.entries) s.tr(e.key.name): e.value},
                    format: _m,
                    color: const Color(0xFF7E57C2),
                  ),
          ),
          ReportSectionCard(
            title: s.tr('topDebtors'),
            icon: AppIcons.customers,
            color: AppColors.paymentUnpaid,
            badge: s.tr('asOfToday'),
            child: r.topDebtors.isEmpty
                ? ReportEmpty(message: s.noDues)
                : BreakdownBars(
                    entries: {for (final d in r.topDebtors) d.customer.name: d.totalDue},
                    format: _m,
                    ranked: true,
                    color: AppColors.paymentUnpaid,
                  ),
          ),
        ]),
      );
    });
  }
}

// ─── Stock & Returns ─────────────────────────────────────────────────────

class InventoryReportTab extends ConsumerWidget {
  const InventoryReportTab({super.key, required this.from, required this.to});
  final DateTime from, to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    return _async(context, ref.watch(inventoryReportProvider(from, to)), (r) {
      final empty = s.tr('noDataForPeriod');
      return ListView(
        padding: const EdgeInsets.all(16),
        children: _gap([
          KpiGrid(items: [
            (label: s.tr('stockValueCost'), value: _m(r.stockValueAtCost), icon: AppIcons.inventory, color: const Color(0xFF6D4C41)),
            (label: s.tr('potentialProfit'), value: _m(r.potentialProfit), icon: AppIcons.profit, color: AppColors.paymentPaid),
            (label: s.lowStockItems, value: '${r.lowStockCount} / ${r.outOfStockCount}', icon: AppIcons.lowStock, color: AppColors.statusPending),
            (label: s.tr('returnsLabel'), value: '${r.returnCount} · ${_m(r.returnedValue)}', icon: AppIcons.returns, color: const Color(0xFFF4511E)),
          ]),
          ReportSectionCard(
            title: s.tr('stockValuePrice'),
            icon: AppIcons.products,
            color: context.brand.primary,
            badge: s.tr('asOfToday'),
            child: PnlTable(rows: [
              (label: s.tr('stockValuePrice'), amount: r.stockValueAtPrice, strong: false, deduct: false),
              (label: s.tr('stockValueCost'), amount: r.stockValueAtCost, strong: false, deduct: true),
              (label: s.tr('potentialProfit'), amount: r.potentialProfit, strong: true, deduct: false),
            ]),
          ),
          ReportSectionCard(
            title: s.tr('stockMovements'),
            icon: AppIcons.inventory,
            color: const Color(0xFF6D4C41),
            child: r.movementQty.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: {for (final e in r.movementQty.entries) s.tr(e.key.name): e.value.toDouble()},
                    format: (v) => v.toStringAsFixed(0),
                    color: const Color(0xFF6D4C41),
                  ),
          ),
          ReportSectionCard(
            title: s.tr('bestSellers'),
            icon: AppIcons.revenue,
            color: AppColors.paymentPaid,
            child: r.bestSellers.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: r.bestSellers,
                    format: (v) => v.toStringAsFixed(0),
                    ranked: true,
                    color: AppColors.paymentPaid,
                  ),
          ),
          ReportSectionCard(
            title: s.tr('slowMovers'),
            icon: AppIcons.pending,
            color: AppColors.statusPending,
            child: r.slowMovers.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: r.slowMovers,
                    format: (v) => '${v.toStringAsFixed(0)} ${s.tr('inStock')}',
                    color: AppColors.statusPending,
                  ),
          ),
          ReportSectionCard(
            title: s.tr('returnReasons'),
            icon: AppIcons.returns,
            color: const Color(0xFFF4511E),
            badge: r.refunded > 0 ? '${s.tr('refundsPaid')}: ${_m(r.refunded)}' : null,
            child: r.returnsByReason.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: {for (final e in r.returnsByReason.entries) s.tr(e.key.name): e.value.toDouble()},
                    format: (v) => v.toStringAsFixed(0),
                    color: const Color(0xFFF4511E),
                  ),
          ),
        ]),
      );
    });
  }
}

// ─── Purchases & Expenses ────────────────────────────────────────────────

class PurchasesReportTab extends ConsumerWidget {
  const PurchasesReportTab({super.key, required this.from, required this.to});
  final DateTime from, to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    return _async(context, ref.watch(purchasesReportProvider(from, to)), (r) {
      final empty = s.tr('noDataForPeriod');
      return ListView(
        padding: const EdgeInsets.all(16),
        children: _gap([
          KpiGrid(items: [
            (label: s.tr('purchasedValue'), value: _m(r.purchased), icon: AppIcons.suppliers, color: const Color(0xFF00ACC1)),
            (label: s.tr('owedToSuppliersToday'), value: _m(r.owedToSuppliersToday), icon: AppIcons.dueBook, color: AppColors.paymentUnpaid),
            (label: s.tr('totalExpenses'), value: _m(r.totalExpenses), icon: AppIcons.expenses, color: const Color(0xFFE53935)),
            (label: s.tr('overShort'), value: _m(r.overShort), icon: AppIcons.cashRegister,
              color: r.overShort < 0 ? AppColors.paymentUnpaid : AppColors.paymentPaid),
          ]),
          ReportSectionCard(
            title: s.tr('purchases'),
            icon: AppIcons.suppliers,
            color: const Color(0xFF00ACC1),
            badge: '${r.purchaseCount}',
            child: PnlTable(rows: [
              (label: s.tr('purchasedValue'), amount: r.purchased, strong: false, deduct: false),
              (label: s.tr('paidToSuppliers'), amount: r.paid, strong: false, deduct: true),
              (label: s.tr('unpaidInPeriod'), amount: r.unpaid, strong: true, deduct: false),
            ]),
          ),
          ReportSectionCard(
            title: s.tr('topSuppliers'),
            icon: AppIcons.suppliers,
            color: const Color(0xFF00ACC1),
            child: r.topSuppliers.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: {
                      for (final e in r.topSuppliers.entries)
                        (e.key.isEmpty ? s.tr('noSupplier') : e.key): e.value,
                    },
                    format: _m,
                    ranked: true,
                    color: const Color(0xFF00ACC1),
                  ),
          ),
          ReportSectionCard(
            title: s.tr('expensesByCategory'),
            icon: AppIcons.expenses,
            color: const Color(0xFFE53935),
            child: r.expensesByCategory.isEmpty
                ? ReportEmpty(message: empty)
                : BreakdownBars(
                    entries: {for (final e in r.expensesByCategory.entries) s.tr(e.key.name): e.value},
                    format: _m,
                    color: const Color(0xFFE53935),
                  ),
          ),
          ReportSectionCard(
            title: s.tr('registerSessions'),
            icon: AppIcons.cashRegister,
            color: const Color(0xFF43A047),
            badge: '${r.registerSessions}',
            child: PnlTable(rows: [
              (label: s.tr('cashIn'), amount: r.cashIn, strong: false, deduct: false),
              (label: s.tr('cashOut'), amount: r.cashOut, strong: false, deduct: true),
              (label: s.tr('overShort'), amount: r.overShort, strong: true, deduct: false),
            ]),
          ),
        ]),
      );
    });
  }
}
