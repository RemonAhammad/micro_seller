import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../data/models/order_item.dart';
import '../../../../core/utils/currency_formatter.dart';

class OrderItemRow extends StatelessWidget {
  final OrderItem item;
  final bool showDivider;

  const OrderItemRow({
    super.key,
    required this.item,
    this.showDivider = true,
  });

  /// The narrowest the name column gets beside the line total, at 100% text.
  static const double _minNameWidth = 64;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = CurrencyFormatter.format(item.totalPrice);
    final totalStyle =
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    final nameStyle =
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final details = [
      Text(item.displayName, style: nameStyle),
      Text(
        '${CurrencyFormatter.format(item.unitPrice)} × ${item.qty}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  // A long quantity (or a large text size) shrinks to fit
                  // the box instead of wrapping out of it.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${item.qty}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // The line total sits beside the name while the name keeps a
              // readable width, with room for its longest word; otherwise (a
              // large total, a narrow layout, large text) it goes under the
              // unit price.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final nameRoom = constraints.maxWidth -
                        _lineWidth(context, total, totalStyle);
                    final longestWord = item.displayName.split(' ').fold(
                        0.0,
                        (widest, word) => math.max(
                            widest, _lineWidth(context, word, nameStyle)));
                    final scaler = MediaQuery.textScalerOf(context);
                    if (nameRoom >=
                        math.max(scaler.scale(_minNameWidth), longestWord)) {
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: details,
                            ),
                          ),
                          Text(total, style: totalStyle),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...details,
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(total, style: totalStyle, maxLines: 1),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: theme.colorScheme.onSurface.withOpacity(0.06),
          ),
      ],
    );
  }
}

/// The width [text] takes on one line in [style] as a [Text] draws it here:
/// over the ambient text style, at the ambient text size, bold if the phone
/// asks for it (the Bold text setting).
double _lineWidth(BuildContext context, String text, TextStyle? style) {
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
