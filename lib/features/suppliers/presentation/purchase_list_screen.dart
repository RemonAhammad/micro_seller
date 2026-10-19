import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supplier_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class PurchaseListScreen extends ConsumerWidget {
  const PurchaseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final purchasesAsync = ref.watch(purchasesProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.purchases)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/suppliers/purchases/add'),
        tooltip: s.newPurchase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const ThinIcon(tabler.Plus.new),
      ),
      body: purchasesAsync.when(
        data: (purchases) {
          if (purchases.isEmpty) {
            return EmptyState(
              icon: tabler.ShoppingBag.new,
              title: s.noPurchasesYet,
              subtitle: s.tr('recordFirstPurchase'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: purchases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = purchases[i];
              return AnimatedEntrance(
                index: i,
                child: InkWell(
                onTap: () => context.push('/suppliers/purchases/${p.id}'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(builder: (context, box) {
                        final name = p.supplierName.isNotEmpty
                            ? p.supplierName
                            : 'No supplier';
                        final nameStyle = theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.supplierName.isEmpty
                              ? cs.onSurface.withValues(alpha: 0.5)
                              : null,
                        );
                        final meta =
                            '${p.totalItems} items  ·  ${DateFormatter.format(p.createdAt)}';
                        final metaStyle = theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        );
                        final amount = CurrencyFormatter.format(p.totalAmount);
                        final amountStyle = TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: cs.primary,
                        );
                        final due = p.balanceDue > 0
                            ? '${s.due}: ${CurrencyFormatter.format(p.balanceDue)}'
                            : null;
                        final dueStyle = TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                        );
                        const paidStyle = TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w600);
                        // The total and its due sit at the end of the row,
                        // unless that would leave the supplier or the date
                        // line too narrow for one of its words (large text,
                        // narrow layout): then they go under them.
                        final totalsBelow = box.maxWidth -
                                math.max(
                                  _textWidth(context, amount, amountStyle),
                                  due != null
                                      ? _textWidth(context, due, dueStyle)
                                      : _textWidth(context, s.paid, paidStyle) +
                                          12,
                                ) <
                            math.max(
                              _textWidth(context, name, nameStyle,
                                  widestWord: true),
                              _textWidth(context, meta, metaStyle,
                                  widestWord: true),
                            );
                        final info = [
                          Text(name, style: nameStyle),
                          Text(meta, style: metaStyle),
                        ];
                        final amountText = Text(amount, style: amountStyle);
                        final status = due != null
                            ? Text(due, style: dueStyle)
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(s.paid, style: paidStyle),
                              );
                        if (totalsBelow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...info,
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 12,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FittedBox(
                                      fit: BoxFit.scaleDown, child: amountText),
                                  FittedBox(
                                      fit: BoxFit.scaleDown, child: status),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: info,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [amountText, status],
                            ),
                          ],
                        );
                      }),
                      if (p.items.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          p.items.map((i) => '${i.productName} ×${i.qty}').join(', '),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

/// How wide [text] in [style] is where [context] lays it out: on one line,
/// or with [widestWord], its widest word (the narrowest it wraps to without
/// breaking a word).
double _textWidth(BuildContext context, String text, TextStyle? style,
    {bool widestWord = false}) {
  var effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = widestWord ? painter.minIntrinsicWidth : painter.width;
  painter.dispose();
  return width;
}
