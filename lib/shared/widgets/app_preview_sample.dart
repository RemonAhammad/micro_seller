import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../features/dashboard/presentation/widgets/stat_card.dart';

// A picture of the app for the settings that change how it looks: Display
// size and Text size (display_size_sheets.dart) and Color theme
// (color_theme_screen.dart, color_theme_editor.dart). It draws in the
// ambient theme, so a `Theme` above it previews another color theme.

/// The soft shadow the app's cards cast (OrderCard, the Dashboard's
/// sections).
final previewCardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

/// The preview box: the screen's background, rounded, with a hairline
/// border, and nothing in it reacts to touch, focus or a screen reader.
class AppPreviewFrame extends StatelessWidget {
  const AppPreviewFrame({super.key, required this.preview, this.sample});

  /// What the box shows.
  ///
  /// With a [sample], it is drawn from the top and clipped to the box: a
  /// larger size runs off the bottom, a smaller one leaves room.
  final Widget preview;

  /// The sample as the app draws it now. Laid out but never shown, it sets
  /// the box's height, which therefore can't change while a size slider is
  /// held: the slider below stays under the finger. Without it, the box is
  /// as tall as [preview].
  final Widget? sample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(14);
    final sample = this.sample;
    // A picture of the app, not controls: no taps, no keyboard focus (the
    // sample's button would take a Tab), nothing for a screen reader.
    return ExcludeFocus(
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: radius,
            ),
            // In front, so a sample running off the bottom doesn't cover it.
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: sample == null
                ? preview
                : Stack(
                    // The sample gets the box's own width, as the preview
                    // does.
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

/// A slice of the app as it is drawn, with sample figures: two Dashboard
/// cards, an order as the Orders list shows it, and a button. With [header],
/// the Dashboard's header band too: the theme's gradient with its text color
/// on it.
class AppPreviewSample extends StatelessWidget {
  const AppPreviewSample({super.key, this.header = false});

  /// Whether to draw the Dashboard's header band above the cards.
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
                      // An order number is data: the app never translates it.
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
                    // All the room the amount leaves, so the badges only
                    // shorten when it is really tight.
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

/// The Dashboard's header band: today's revenue in the theme's text color
/// on its gradient.
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
          // One line: a long amount shrinks instead of wrapping.
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

/// An order's status pill, as the Orders list draws it.
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
