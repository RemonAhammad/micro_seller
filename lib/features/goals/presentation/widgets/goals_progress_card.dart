import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/sales_target.dart';

class GoalsProgressCard extends StatelessWidget {
  const GoalsProgressCard({
    super.key,
    required this.target,
    required this.currentRevenue,
    required this.currentProfit,
    required this.currentOrderCount,
    this.onEdit,
  });

  final SalesTarget target;
  final double currentRevenue;
  final double currentProfit;
  final int currentOrderCount;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final brand = context.brand;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ThinIcon(tabler.Target.new, size: 20, color: brand.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.tr('salesTargets'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: ThinIcon(tabler.Edit.new, size: 18),
                    onPressed: onEdit,
                    tooltip: s.tr('editTargets'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (target.revenueTarget > 0)
              _ProgressRow(
                label: s.tr('revenue'),
                current: currentRevenue,
                targetValue: target.revenueTarget,
                color: brand.primary,
                isCurrency: true,
              ),
            if (target.profitTarget > 0) ...[
              const SizedBox(height: 8),
              _ProgressRow(
                label: s.tr('profit'),
                current: currentProfit,
                targetValue: target.profitTarget,
                color: Colors.green.shade600,
                isCurrency: true,
              ),
            ],
            if (target.orderCountTarget > 0) ...[
              const SizedBox(height: 8),
              _ProgressRow(
                label: s.tr('orders'),
                current: currentOrderCount.toDouble(),
                targetValue: target.orderCountTarget.toDouble(),
                color: Colors.blue.shade600,
              ),
            ],
            if (target.productTargets.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${target.productTargets.length} ${s.tr('productTargets').toLowerCase()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.current,
    required this.targetValue,
    required this.color,
    this.isCurrency = false,
  });

  final String label;
  final double current;
  final double targetValue;
  final Color color;
  final bool isCurrency;

  @override
  Widget build(BuildContext context) {
    final progress = targetValue > 0 ? (current / targetValue).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).round();
    final achieved = percent >= 100;

    String formatValue(double v) {
      if (isCurrency) return CurrencyFormatter.formatCompact(v);
      return v.toInt().toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (achieved)
              Icon(Icons.check_circle, size: 16, color: Colors.green.shade600)
            else
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(
              achieved ? Colors.green.shade600 : color,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${formatValue(current)} / ${formatValue(targetValue)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }
}
