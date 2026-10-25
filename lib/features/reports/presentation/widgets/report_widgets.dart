import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../dashboard/presentation/widgets/sales_chart.dart'
    show GridLineCallback, axisTitleReserve;
import '../../../dashboard/presentation/widgets/stat_card.dart';

/// Shared building blocks for the four Reports tabs.

class ReportSectionCard extends StatelessWidget {
  const ReportSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.badge,
  });

  final String title;
  final ThinIconBuilder icon;
  final Color color;
  final Widget child;

  /// Small note next to the title, e.g. "as of today".
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final badgeStyle = theme.textTheme.labelSmall?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.5),
        fontStyle: FontStyle.italic);
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
          LayoutBuilder(builder: (context, constraints) {
            // The badge ends the title row while it leaves the title a
            // third of it (the icon's 36 px aside). A longer one (narrow
            // screen, large text) goes under the title instead of
            // squeezing it to a letter a line or overflowing.
            final badgeText =
                badge == null ? null : Text(badge!, style: badgeStyle);
            final beside = badge == null ||
                measureTextWidth(context, badge!, badgeStyle) <=
                    (constraints.maxWidth - 36) * 2 / 3;
            final header = Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(child: ThinIcon(icon, color: color, size: 16)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                if (beside && badgeText != null) badgeText,
              ],
            );
            if (beside) return header;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 36, top: 2),
                  child: badgeText,
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// KPI tiles in a responsive grid (2–4 columns), reusing the dashboard card.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.items});

  final List<({String label, String value, ThinIconBuilder icon, Color color})>
      items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 170).floor().clamp(2, 4);
      const spacing = 10.0;
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      final h = statCardHeight(MediaQuery.textScalerOf(context));
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final i in items)
            SizedBox(
              width: w,
              height: h,
              child: StatCard(
                label: i.label,
                value: i.value,
                iconBuilder: i.icon,
                color: i.color,
              ),
            ),
        ],
      );
    });
  }
}

/// Profit & loss statement: label / amount rows; [strong] rows are
/// subtotals drawn bold with a rule above.
class PnlTable extends StatelessWidget {
  const PnlTable({super.key, required this.rows});

  final List<({String label, double amount, bool strong, bool deduct})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          for (final r in rows) ...[
            if (r.strong) Divider(height: 12, color: cs.onSurface.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontWeight: r.strong ? FontWeight.w700 : FontWeight.w400,
                        color: r.strong ? cs.onSurface : cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  _Amount(
                    maxWidth: constraints.maxWidth * 0.6,
                    child: Text(
                      '${r.deduct ? '− ' : ''}${CurrencyFormatter.format(r.amount.abs())}',
                      style: TextStyle(
                        fontWeight: r.strong ? FontWeight.w800 : FontWeight.w600,
                        color: r.deduct
                            ? AppColors.paymentUnpaid
                            : r.strong && r.amount < 0
                                ? AppColors.paymentUnpaid
                                : r.strong
                                    ? AppColors.paymentPaid
                                    : cs.onSurface,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ranked horizontal share bars — methods, categories, reasons, top lists.
class BreakdownBars extends StatelessWidget {
  const BreakdownBars({
    super.key,
    required this.entries,
    required this.format,
    this.color,
    this.ranked = false,
  });

  final Map<String, double> entries;
  final String Function(double) format;

  /// The bars' and top ranks' color; the theme's main color by default.
  final Color? color;

  /// Show 1, 2, 3… before each row (top-N lists).
  final bool ranked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = this.color ?? context.brand.primary;
    final items = entries.entries.toList();
    final max = items.fold<double>(0, (m, e) => e.value.abs() > m ? e.value.abs() : m);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (ranked)
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: i < 3 ? color : cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: max > 0 ? items[i].value.abs() / max : 0,
                            minHeight: 4,
                            backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Amount(
                    maxWidth: constraints.maxWidth * 0.45,
                    child: Text(format(items[i].value),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        maxLines: 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// An amount at the end of a row: its own width while that's under
/// [maxWidth], shrunk to fit beyond it (narrow screen, large text), so the
/// label keeps room and the number is never cut off or ellipsized.
class _Amount extends StatelessWidget {
  const _Amount({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerEnd,
          child: child,
        ),
      );
}

/// Net sales per day (or month) as bars; returns can make a bucket negative.
///
/// Stateful only so the chart callbacks are stable tear-offs: fl_chart
/// compares its data (callbacks included) to decide whether to animate, and
/// closures built in `build` restarted the animation on every rebuild.
class NetSalesChart extends StatefulWidget {
  const NetSalesChart({super.key, required this.series, required this.byMonth});

  final List<({DateTime bucket, double value})> series;
  final bool byMonth;

  @override
  State<NetSalesChart> createState() => _NetSalesChartState();
}

class _NetSalesChartState extends State<NetSalesChart> {
  static const _months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  final _gridLine = GridLineCallback();

  /// Read by [_bottomTitle]; set in [build].
  Color _labelColor = Colors.transparent;
  int _every = 1;

  BarTooltipItem _tooltipItem(
      BarChartGroupData g, int groupIndex, BarChartRodData rod, int rodIndex) {
    final d = widget.series[g.x].bucket;
    final label = widget.byMonth ? '${d.month}/${d.year}' : '${d.day}/${d.month}';
    return BarTooltipItem('$label\n${CurrencyFormatter.format(rod.toY)}',
        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600));
  }

  Widget _bottomTitle(double v, TitleMeta meta) {
    final series = widget.series;
    final i = v.toInt();
    if (i < 0 || i >= series.length || i % _every != 0) {
      return const SizedBox.shrink();
    }
    final d = series[i].bucket;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(widget.byMonth ? _months[d.month - 1] : '${d.day}',
          style: TextStyle(fontSize: 9, color: _labelColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final series = widget.series;
    final maxV = series.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final minV = series.fold<double>(0, (m, e) => e.value < m ? e.value : m);
    final top = maxV == 0 ? 100.0 : maxV * 1.15;
    _every = (series.length / 7).ceil().clamp(1, 1000);
    _labelColor = cs.onSurface.withValues(alpha: 0.5);

    return SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          maxY: top,
          minY: minV < 0 ? minV * 1.15 : 0,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine:
                _gridLine.forColor(cs.onSurface.withValues(alpha: 0.05)),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: _tooltipItem,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: axisTitleReserve(
                    MediaQuery.textScalerOf(context),
                    fontSize: 9,
                    padding: 4),
                getTitlesWidget: _bottomTitle,
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: series[i].value,
                  width: series.length > 20 ? 5 : 12,
                  // A sales series: the fixed revenue color, as on the
                  // dashboard's chart, whatever the color theme.
                  color: series[i].value < 0
                      ? AppColors.paymentUnpaid
                      : AppColors.chartRevenue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// "No data for this period" placeholder inside a tab.
class ReportEmpty extends StatelessWidget {
  const ReportEmpty({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(message,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
      ),
    );
  }
}
