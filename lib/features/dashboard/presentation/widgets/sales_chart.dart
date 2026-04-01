import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../providers/dashboard_provider.dart';

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
    final theme = Theme.of(context);

    if (widget.weeklySales.isEmpty) {
      return const SizedBox(height: 200);
    }

    final maxRevenue = widget.weeklySales
        .map((s) => s.revenue)
        .reduce((a, b) => a > b ? a : b);
    final maxProfit = widget.weeklySales
        .map((s) => s.profit)
        .reduce((a, b) => a > b ? a : b);
    final maxY = (_showRevenue ? maxRevenue : maxProfit) * 1.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ChartToggle(
              label: 'Revenue',
              color: AppColors.chartRevenue,
              isSelected: _showRevenue,
              onTap: () => setState(() => _showRevenue = true),
            ),
            const SizedBox(width: 8),
            _ChartToggle(
              label: 'Profit',
              color: AppColors.chartProfit,
              isSelected: !_showRevenue,
              onTap: () => setState(() => _showRevenue = false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 100 : maxY,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  if (event.isInterestedForInteractions &&
                      response?.spot != null) {
                    setState(() {
                      _touchedIndex = response!.spot!.touchedBarGroupIndex;
                    });
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
                        fontSize: 12,
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
                        return Text(
                          labels[day.weekday - 1],
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxY == 0 ? 25 : maxY / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.onSurface.withOpacity(0.06),
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
                final color = _showRevenue
                    ? AppColors.chartRevenue
                    : AppColors.chartProfit;

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: value,
                      color: isTouched ? color : color.withOpacity(0.7),
                      width: isTouched ? 22 : 18,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY == 0 ? 100 : maxY,
                        color: theme.colorScheme.onSurface.withOpacity(0.04),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? color
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
