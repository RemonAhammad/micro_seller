import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../providers/dashboard_provider.dart';

// ─── Weekly Sales Bar Chart ─────────────────────────────────────────────────

class SalesChart extends StatefulWidget {
  final List<DailySales> weeklySales;

  const SalesChart({super.key, required this.weeklySales});

  @override
  State<SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<SalesChart> {
  int _touchedIndex = -1;
  bool _showRevenue = true;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (widget.weeklySales.isEmpty) {
      return const SizedBox(height: 160);
    }

    final maxRevenue = widget.weeklySales
        .map((d) => d.revenue)
        .reduce((a, b) => a > b ? a : b);
    final maxProfit = widget.weeklySales
        .map((d) => d.profit)
        .reduce((a, b) => a > b ? a : b);
    final maxY = (_showRevenue ? maxRevenue : maxProfit) * 1.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ChartToggle(
              label: s.revenue,
              color: AppColors.chartRevenue,
              isSelected: _showRevenue,
              onTap: () => setState(() => _showRevenue = true),
            ),
            const SizedBox(width: 8),
            _ChartToggle(
              label: s.profit,
              color: AppColors.chartProfit,
              isSelected: !_showRevenue,
              onTap: () => setState(() => _showRevenue = false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 100 : maxY,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  if (event.isInterestedForInteractions &&
                      response?.spot != null) {
                    setState(() =>
                        _touchedIndex = response!.spot!.touchedBarGroupIndex);
                  } else {
                    setState(() => _touchedIndex = -1);
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final sales = widget.weeklySales[group.x];
                    final amount =
                        _showRevenue ? sales.revenue : sales.profit;
                    return BarTooltipItem(
                      '${DateFormatter.formatShort(sales.date)}\n${CurrencyFormatter.format(amount)}',
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
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < widget.weeklySales.length) {
                        final day = widget.weeklySales[index].date;
                        final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[day.weekday - 1],
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurface.withValues(alpha: 0.45),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxY == 0 ? 25 : maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: cs.onSurface.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
              barGroups: widget.weeklySales.asMap().entries.map((e) {
                final index = e.key;
                final sales = e.value;
                final value = _showRevenue ? sales.revenue : sales.profit;
                final isTouched = index == _touchedIndex;
                final color =
                    _showRevenue ? AppColors.chartRevenue : AppColors.chartProfit;

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: value,
                      color: isTouched ? color : color.withValues(alpha: 0.7),
                      width: isTouched ? 20 : 16,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(5)),
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
        ),
      ],
    );
  }
}

// ─── Order Status Pie Chart ─────────────────────────────────────────────────

class OrderStatusChart extends StatefulWidget {
  final Map<String, int> statusCounts;

  const OrderStatusChart({super.key, required this.statusCounts});

  @override
  State<OrderStatusChart> createState() => _OrderStatusChartState();
}

class _OrderStatusChartState extends State<OrderStatusChart> {
  int _touchedIndex = -1;

  static const _statusColors = {
    'Pending': AppColors.statusPending,
    'Confirmed': AppColors.statusConfirmed,
    'Shipped': AppColors.statusShipped,
    'Completed': AppColors.statusCompleted,
    'Cancelled': AppColors.statusCancelled,
  };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = widget.statusCounts.entries
        .where((e) => e.value > 0)
        .toList();

    if (entries.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(s.addFirstOrder,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4))),
        ),
      );
    }

    final total = entries.fold<int>(0, (s, e) => s + e.value);

    return SizedBox(
      height: 140,
      child: Row(
        children: [
          // Pie chart
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (event.isInterestedForInteractions &&
                        response?.touchedSection != null) {
                      setState(() => _touchedIndex =
                          response!.touchedSection!.touchedSectionIndex);
                    } else {
                      setState(() => _touchedIndex = -1);
                    }
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: entries.asMap().entries.map((e) {
                  final i = e.key;
                  final entry = e.value;
                  final color = _statusColors[entry.key] ?? cs.outline;
                  final isTouched = i == _touchedIndex;
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    color: color,
                    radius: isTouched ? 32 : 26,
                    title: '',
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Legend
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.map((e) {
                final color = _statusColors[e.key] ?? cs.outline;
                final pct = (e.value / total * 100).round();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($pct%)',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Revenue vs Expense Line Chart ──────────────────────────────────────────

class RevenueExpenseChart extends StatelessWidget {
  final List<DailySales> weeklySales;
  final Map<int, double> dailyExpenses; // day index → amount

  const RevenueExpenseChart({
    super.key,
    required this.weeklySales,
    required this.dailyExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (weeklySales.isEmpty) return const SizedBox(height: 140);

    final maxRevenue = weeklySales
        .map((d) => d.revenue)
        .reduce((a, b) => a > b ? a : b);
    final maxExpense = dailyExpenses.values.isEmpty
        ? 0.0
        : dailyExpenses.values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxRevenue > maxExpense ? maxRevenue : maxExpense) * 1.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend
        Row(
          children: [
            _dot(AppColors.chartRevenue),
            const SizedBox(width: 4),
            Text(s.revenue,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
            const SizedBox(width: 14),
            _dot(AppColors.statusCancelled),
            const SizedBox(width: 4),
            Text(s.expenses,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              maxY: maxY == 0 ? 100 : maxY,
              minY: 0,
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxY == 0 ? 25 : maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: cs.onSurface.withValues(alpha: 0.05),
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i >= 0 && i < weeklySales.length) {
                        final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[weeklySales[i].date.weekday - 1],
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final isExpense = s.barIndex == 1;
                    return LineTooltipItem(
                      CurrencyFormatter.format(s.y),
                      TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: isExpense ? 1.5 : 1,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                // Revenue line
                LineChartBarData(
                  spots: weeklySales
                      .asMap()
                      .entries
                      .map((e) => FlSpot(
                          e.key.toDouble(), e.value.revenue))
                      .toList(),
                  color: AppColors.chartRevenue,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.chartRevenue,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.chartRevenue.withValues(alpha: 0.08),
                  ),
                  isCurved: true,
                  preventCurveOverShooting: true,
                ),
                // Expense line
                LineChartBarData(
                  spots: List.generate(
                    weeklySales.length,
                    (i) => FlSpot(
                        i.toDouble(), dailyExpenses[i] ?? 0),
                  ),
                  color: AppColors.statusCancelled,
                  barWidth: 2,
                  dashArray: [6, 4],
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, ___) =>
                        FlDotCirclePainter(
                      radius: 2.5,
                      color: AppColors.statusCancelled,
                      strokeWidth: 0,
                    ),
                  ),
                  isCurved: true,
                  preventCurveOverShooting: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 8,
        height: 8,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      );
}

// ─── Toggle chip ────────────────────────────────────────────────────────────

class _ChartToggle extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChartToggle({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? color
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
