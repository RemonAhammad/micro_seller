import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../features/dashboard/presentation/widgets/stat_card.dart';

final previewCardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

class AppPreviewFrame extends StatelessWidget {
  const AppPreviewFrame({super.key, required this.preview, this.sample});

  final Widget preview;

  final Widget? sample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(14);
    final sample = this.sample;

    return ExcludeFocus(
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: radius,
            ),

            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: sample == null
                ? preview
                : Stack(

                    fit: StackFit.passthrough,
                    children: [
                      Visibility(
                        visible: false,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: sample,
                      ),
                      Positioned.fill(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: 0,
                          maxHeight: double.infinity,
                          child: preview,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class AppPreviewSample extends StatelessWidget {
  const AppPreviewSample({super.key, this.header = false});

  final bool header;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final orderTitle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header) ...[const _HeaderSample(), const SizedBox(height: 10)],
          SizedBox(
            height: statCardHeight(MediaQuery.textScalerOf(context)),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: s.monthRevenue,
                    value: CurrencyFormatter.formatCompact(48250),
                    iconBuilder: AppIcons.revenue,
                    color: context.brand.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    label: s.pendingOrders,
                    value: '12',
                    iconBuilder: AppIcons.pending,
                    color: AppColors.statusPending,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: previewCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(

                      child: Text(
                        'ORD-042',
                        style: orderTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      s.today,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [

                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: _Badge(s.pending, AppColors.statusPending),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: _Badge(s.paid, AppColors.paymentPaid),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(1250),
                      style: orderTitle?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: () {},
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              icon: const ThinIcon(tabler.Plus.new, size: 18),
              label: Text(s.addOrder),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSample extends StatelessWidget {
  const _HeaderSample();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final brand = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: brand.gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.todayRevenue,
            style: TextStyle(
              color: brand.onPrimary.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              CurrencyFormatter.format(48250),
              maxLines: 1,
              style: TextStyle(
                color: brand.onPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
