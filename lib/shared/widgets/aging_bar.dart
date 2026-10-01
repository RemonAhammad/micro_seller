import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';

/// Stacked bar of how long money has been owed (<30 / 30–60 / 60+ days),
/// with a legend. Used by the dashboard's Due Book card and the Reports
/// "Dues & Payments" tab.
class AgingBar extends StatelessWidget {
  const AgingBar({
    super.key,
    required this.under30,
    required this.from30to60,
    required this.over60,
  });

  final double under30;
  final double from30to60;
  final double over60;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final total = under30 + from30to60 + over60;
    final buckets = [
      (s.ageUnder30, under30, AppColors.paymentPaid),
      (s.age30to60, from30to60, AppColors.paymentPartial),
      (s.age60plus, over60, AppColors.paymentUnpaid),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (total <= 0)
                  Expanded(
                      child: Container(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.08))),
                for (final (_, amount, color) in buckets)
                  if (amount > 0)
                    Expanded(
                      // Flex needs ints; scale so small buckets stay visible.
                      flex: (amount / total * 1000).round().clamp(1, 1000),
                      child: Container(color: color),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final (label, amount, color) in buckets)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$label  ${CurrencyFormatter.formatCompact(amount)}',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
