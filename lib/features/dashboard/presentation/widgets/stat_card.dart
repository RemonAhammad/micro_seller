import 'package:flutter/material.dart';
import '../../../../core/constants/app_icons.dart';

double statCardHeight(TextScaler textScaler) =>
    110 +
    StatCard._textHeight(textScaler) -
    StatCard._textHeight(TextScaler.noScaling);

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
