import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../dashboard/presentation/widgets/stat_card.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) _startDate = _endDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reportAsync = ref.watch(reportDataProvider(_startDate, _endDate));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            centerTitle: false,
            title: Text(
              s.reports,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.dashboardGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 8, 20, 0),
                    child: Row(
                      children: [
                        _DateChip(
                          label: DateFormatter.formatShort(_startDate),
                          onTap: () => _pickDate(isStart: true),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('to',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                        _DateChip(
                          label: DateFormatter.formatShort(_endDate),
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: reportAsync.when(
              data: (data) => _ReportBody(data: data),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: LoadingShimmer(height: 400, borderRadius: 14)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 40, color: cs.error),
                      const SizedBox(height: 12),
                      Text(s.errorOccurred,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(e.toString(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date Chip ──────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 12, color: Colors.white70),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Report Body ────────────────────────────────────────────────────────────

class _ReportBody extends StatelessWidget {
  final ReportData data;
  const _ReportBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          _buildStatCards(context),
          const SizedBox(height: 14),
          if (data.topProducts.isNotEmpty) ...[
            _SectionCard(
              title: s.topProducts,
              icon: Icons.bar_chart_rounded,
              iconColor: AppColors.primary,
              child: _TopProductsChart(products: data.topProducts),
            ),
            const SizedBox(height: 14),
          ],
          if (data.salesByCategory.isNotEmpty) ...[
            _SectionCard(
              title: s.salesByCategory,
              icon: Icons.pie_chart_rounded,
              iconColor: AppColors.statusConfirmed,
              child: _RankedList(
                entries: data.salesByCategory,
                formatValue: CurrencyFormatter.formatCompact,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (data.topCustomers.isNotEmpty) ...[
            _SectionCard(
              title: s.topCustomers,
              icon: Icons.people_rounded,
              iconColor: AppColors.statusShipped,
              child: _RankedList(
                entries: data.topCustomers,
                formatValue: CurrencyFormatter.formatCompact,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (data.topProductsByQty.isNotEmpty)
            _SectionCard(
              title: s.topProductsByQty,
              icon: Icons.inventory_2_rounded,
              iconColor: AppColors.statusPending,
              child: _RankedList(
                entries: data.topProductsByQty,
                formatValue: (v) => '${v.toInt()} ${s.tr("sold")}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCards(BuildContext context) {
    final s = AppStrings.of(context);
    final items = [
      (
        label: s.totalRevenue,
        value: CurrencyFormatter.formatCompact(data.totalRevenue),
        icon: Icons.trending_up_rounded,
        color: AppColors.primary,
      ),
      (
        label: s.totalProfit,
        value: CurrencyFormatter.formatCompact(data.totalProfit),
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF42A5F5),
      ),
      (
        label: s.totalExpenses,
        value: CurrencyFormatter.formatCompact(data.totalExpenses),
        icon: Icons.receipt_long_rounded,
        color: AppColors.statusCancelled,
      ),
      (
        label: s.avgOrderValue,
        value: CurrencyFormatter.formatCompact(data.avgOrderValue),
        icon: Icons.shopping_cart_rounded,
        color: AppColors.statusShipped,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 170).floor().clamp(2, 4);
        const spacing = 10.0;
        final cardWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((item) => SizedBox(
                    width: cardWidth,
                    height: 110,
                    child: StatCard(
                      label: item.label,
                      value: item.value,
                      icon: item.icon,
                      color: item.color,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ─── Top Products Bar Chart ─────────────────────────────────────────────────

class _TopProductsChart extends StatelessWidget {
  final Map<String, double> products;
  const _TopProductsChart({required this.products});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = products.entries.toList();
    final maxRevenue = entries.first.value;
    final maxY = maxRevenue * 1.2;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY == 0 ? 100 : maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final name = entries[group.x].key;
                return BarTooltipItem(
                  '$name\n${CurrencyFormatter.format(rod.toY)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  final name = entries[i].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      name.length > 8 ? '${name.substring(0, 8)}..' : name,
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY == 0 ? 25 : maxY / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: cs.onSurface.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value,
                  color: AppColors.primary.withValues(alpha: 0.8),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY == 0 ? 100 : maxY,
                    color: cs.onSurface.withValues(alpha: 0.03),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Ranked List ────────────────────────────────────────────────────────────

class _RankedList extends StatelessWidget {
  final Map<String, double> entries;
  final String Function(double) formatValue;
  const _RankedList({required this.entries, required this.formatValue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = entries.entries.toList();
    final maxValue = items.isNotEmpty ? items.first.value : 1.0;

    return Column(
      children: items.asMap().entries.map((e) {
        final rank = e.key + 1;
        final item = e.value;
        final fraction = maxValue > 0 ? item.value / maxValue : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rank <= 3
                        ? AppColors.primary
                        : cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 4,
                        backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.primary.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatValue(item.value),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Section Card (same pattern as dashboard) ───────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
