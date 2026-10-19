import 'package:flutter/material.dart';
import '../../../../core/constants/app_icons.dart';

/// Height of the fixed slot a [StatCard] fills: the dashboard grid, its
/// loading skeleton and the Reports KPI grid all use it, so they can't drift.
///
/// 110 at the default text size. It grows (or shrinks) by exactly as much as
/// the card's two text lines do, so a larger font never clips the label and
/// the card keeps the same space under its icon at every text size.
double statCardHeight(TextScaler textScaler) =>
    110 +
    StatCard._textHeight(textScaler) -
    StatCard._textHeight(TextScaler.noScaling);

/// How wide [text] is on one line in [style], measured the way a [Text]
/// draws it here (over the ambient text style, at the current text size and
/// bold-text setting). Lets a row pick between side by side and stacked
/// before a long amount or a large font would make it overflow.
double measureTextWidth(BuildContext context, String text, TextStyle? style) {
  var effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  /// Material icon — or pass [iconBuilder] for a thin Tabler icon instead.
  final ThinIconBuilder? icon;
  final ThinIconBuilder? iconBuilder;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconBuilder,
    required this.color,
    this.onTap,
  }) : assert(icon != null || iconBuilder != null);

  // The two text lines, pinned here so [statCardHeight] measures what the
  // card draws. The heights are titleLarge's and bodyMedium's (the
  // surrounding Material's text style), which the lines used before.
  static const double _valueSize = 20, _valueHeight = 1.27;
  static const double _labelSize = 11, _labelHeight = 1.43;

  static double _textHeight(TextScaler s) =>
      s.scale(_valueSize) * _valueHeight + s.scale(_labelSize) * _labelHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: ThinIcon(iconBuilder ?? icon!, color: color, size: 18),
              ),
            ),
            const Spacer(),
            // A number that doesn't fit (narrow card, large text) shrinks
            // instead of being cut off mid-number.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                  fontSize: _valueSize,
                  height: _valueHeight,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: _labelSize,
                height: _labelHeight,
                color: cs.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
