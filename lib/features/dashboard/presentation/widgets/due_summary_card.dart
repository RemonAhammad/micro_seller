import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/share_origin.dart';
import '../../../../shared/widgets/aging_bar.dart';
import '../../../customers/presentation/widgets/due_actions.dart';
import '../../../customers/providers/dues_provider.dart';
import 'stat_card.dart' show measureTextWidth;

class DueSummaryCard extends ConsumerWidget {
  const DueSummaryCard({
    super.key,
    required this.summary,
    required this.dues,
  });

  final DueSummary summary;
  final List<CustomerDue> dues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final toChase = [...dues]
      ..sort((a, b) {
        final byAge = b.daysOutstanding.compareTo(a.daysOutstanding);
        return byAge != 0 ? byAge : b.totalDue.compareTo(a.totalDue);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            CurrencyFormatter.format(summary.total),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.paymentUnpaid,
            ),
            maxLines: 1,
          ),
        ),
        Text(s.customersOwing(summary.customerCount),
            style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        const SizedBox(height: 12),

        AgingBar(
          under30: summary.under30,
          from30to60: summary.from30to60,
          over60: summary.over60,
        ),
        const SizedBox(height: 8),
        const Divider(height: 16),
        for (final due in toChase.take(3)) _ChaseRow(due: due),
      ],
    );
  }
}

class _ChaseRow extends ConsumerWidget {
  const _ChaseRow({required this.due});

  final CustomerDue due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final days = due.daysOutstanding;
    final ageColor = days >= 60
        ? AppColors.paymentUnpaid
        : days >= 30
            ? AppColors.paymentPartial
            : theme.colorScheme.onSurface.withValues(alpha: 0.5);

    const amountStyle = TextStyle(fontWeight: FontWeight.w800);
    final amountText = CurrencyFormatter.format(due.totalDue);
    final amount = Text(amountText, style: amountStyle, maxLines: 1);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/customers/${due.customer.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {

            final beside =
                measureTextWidth(context, amountText, amountStyle) <=
                    constraints.maxWidth * 0.45;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        due.customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (!beside)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: amount,
                        ),
                      Text(
                        s.daysOutstanding(days),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ageColor),
                      ),
                    ],
                  ),
                ),
                if (beside) amount,

                Builder(
                  builder: (button) => IconButton(
                    tooltip: s.remind,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => sendDueReminder(context, ref,
                        due.customer, due.orderDues, due.totalDue,
                        shareOrigin: shareOriginOf(button)),
                    icon: const ThinIcon(AppIcons.whatsapp,
                        color: Color(0xFF25D366), size: 22),
                  ),
                ),
                IconButton(
                  tooltip: s.collect,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showCollectPaymentSheet(
                      context, due.customer, due.orderDues, due.totalDue),
                  icon: ThinIcon(AppIcons.collected,
                      color: context.brand.primary, size: 22),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
