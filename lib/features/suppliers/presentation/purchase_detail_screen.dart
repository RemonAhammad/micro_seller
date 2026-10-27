import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import '../../../data/models/purchase.dart';
import '../providers/supplier_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/number_input.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  final int purchaseId;

  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isarAsync = ref.watch(isarProvider);
    return isarAsync.when(
      data: (isar) => _Body(purchaseId: purchaseId, isar: isar),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  final int purchaseId;
  final Isar isar;

  const _Body({required this.purchaseId, required this.isar});

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late final Stream<Purchase?> _purchaseStream = widget.isar.purchases
      .watchObject(widget.purchaseId, fireImmediately: true);
  late final Purchase? _initialPurchase =
      widget.isar.purchases.getSync(widget.purchaseId);

  String _methodLabel(BuildContext context, PurchasePaymentMethod m) {
    final s = AppStrings.of(context);
    return switch (m) {
      PurchasePaymentMethod.cash => s.cash,
      PurchasePaymentMethod.card => s.card,
      PurchasePaymentMethod.bkash => s.bkash,
      PurchasePaymentMethod.nagad => s.nagad,
      PurchasePaymentMethod.bank => s.bank,
      PurchasePaymentMethod.other => s.other,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final badge = MediaQuery.textScalerOf(context).scale(36);

    return StreamBuilder<Purchase?>(
      stream: _purchaseStream,
      initialData: _initialPurchase,
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(s.purchaseNotFound)),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${s.purchases} #${p.id}'),
            actions: [
              IconButton(
                icon: const ThinIcon(tabler.Trash.new),
                onPressed: () async {
                  final ok = await ConfirmDialog.show(
                    context,
                    title: s.deletePurchase,
                    message: s.tr('deletePurchaseConfirm'),
                    confirmText: s.delete,
                    isDestructive: true,
                    icon: tabler.Trash.new,
                  );
                  if (ok == true && context.mounted) {
                    await ref
                        .read(supplierProvider.notifier)
                        .deletePurchase(p.id);
                    if (context.mounted) context.pop();
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
                    ],
                  ),
                  child: Column(
                    children: [
                      _row(theme, s.suppliers,
                          p.supplierName.isNotEmpty ? p.supplierName : '-'),
                      _row(theme, s.date, DateFormatter.formatWithTime(p.createdAt)),
                      _row(theme, s.payment, _methodLabel(context, p.paymentMethod)),
                      if (p.referenceNumber.isNotEmpty)
                        _row(theme, s.referenceReceipt, p.referenceNumber),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Items
                Text(s.items,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: p.items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final nameStyle = theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600);
                      final unit =
                          '${CurrencyFormatter.format(item.unitCost)} × ${item.qty}';
                      final unitStyle = theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5));
                      final total = CurrencyFormatter.format(item.totalCost);
                      final totalStyle = theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700);
                      return Column(
                        children: [
                          if (i > 0)
                            Divider(
                                height: 1,
                                indent: 12,
                                endIndent: 12,
                                color: cs.outline.withValues(alpha: 0.1)),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: LayoutBuilder(builder: (context, box) {
                              // The line total sits at the end of the row,
                              // unless that would leave the name or the unit
                              // price too narrow for one of its words (large
                              // text, narrow layout): then it goes under them.
                              final totalBelow = box.maxWidth - badge - 12 -
                                      _textWidth(context, total, totalStyle) <
                                  math.max(
                                    _textWidth(context, item.productName,
                                        nameStyle,
                                        widestWord: true),
                                    _textWidth(context, unit, unitStyle,
                                        widestWord: true),
                                  );
                              return Row(
                                children: [
                                  Container(
                                    // 36 square at the default text size,
                                    // growing with the text; a quantity too
                                    // long for it shrinks instead of wrapping.
                                    width: badge,
                                    height: badge,
                                    decoration: BoxDecoration(
                                      color: cs.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('${item.qty}',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: cs.primary,
                                                  fontSize: 14)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName, style: nameStyle),
                                        Text(unit, style: unitStyle),
                                        if (totalBelow)
                                          Align(
                                            alignment:
                                                AlignmentDirectional.centerEnd,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(total,
                                                  style: totalStyle),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (!totalBelow) Text(total, style: totalStyle),
                                ],
                              );
                            }),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Totals
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
                    ],
                  ),
                  child: Column(
                    children: [
                      _row(theme, s.total,
                          CurrencyFormatter.format(p.totalAmount),
                          isBold: true, valueColor: cs.primary, keepWhole: true),
                      _row(theme, s.paid, CurrencyFormatter.format(p.amountPaid),
                          keepWhole: true),
                      if (p.balanceDue > 0)
                        _row(theme, s.balanceDue,
                            CurrencyFormatter.format(p.balanceDue),
                            isBold: true, valueColor: Colors.red, keepWhole: true),
                    ],
                  ),
                ),

                if (p.balanceDue > 0) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showPayDialog(context, ref, p),
                      icon: const ThinIcon(tabler.Cash.new),
                      label: Text(s.recordPayment),
                    ),
                  ),
                ],

                if (p.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.notes,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.5),
                            )),
                        const SizedBox(height: 4),
                        Text(p.notes),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// [label] at the start of a line and [value] at its end. A long label
  /// wraps within half the line (or its longest word, when that's wider)
  /// and a long value wraps under itself, or goes under the label when a
  /// word of it wouldn't fit beside it. With [keepWhole] (an amount) the
  /// value shrinks to fit instead, so it is never split.
  Widget _row(ThemeData theme, String label, String value,
      {bool isBold = false, Color? valueColor, bool keepWhole = false}) {
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
      color: valueColor,
    );
    final valueText = Text(value, textAlign: TextAlign.end, style: valueStyle);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(builder: (context, box) {
        final labelMax = math.max(
          box.maxWidth / 2,
          math.min(_textWidth(context, label, labelStyle, widestWord: true),
              box.maxWidth * 0.7),
        );
        if (!keepWhole &&
            box.maxWidth -
                    math.min(_textWidth(context, label, labelStyle), labelMax) -
                    12 <
                _textWidth(context, value, valueStyle, widestWord: true)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text(label, style: labelStyle), valueText],
          );
        }
        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: labelMax),
              child: Text(label, style: labelStyle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: keepWhole
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: valueText,
                    )
                  : valueText,
            ),
          ],
        );
      }),
    );
  }

  void _showPayDialog(BuildContext context, WidgetRef ref, Purchase purchase) {
    final s = AppStrings.of(context);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.recordPayment),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s.due}: ${CurrencyFormatter.format(purchase.balanceDue)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [DecimalInputFormatter.money()],
              decoration: InputDecoration(
                labelText: s.paymentAmount,
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
          // Enabled once there's an amount to pay, as the Due Book's
          // Collect is: a tap on an empty or zero amount used to do nothing.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: ctrl,
            builder: (_, value, _) {
              final amount = NumberInput.parseDecimal(value.text);
              return FilledButton(
                onPressed: amount == null || amount <= 0
                    ? null
                    : () async {
                        await ref
                            .read(supplierProvider.notifier)
                            .recordPurchasePayment(purchase.id, amount);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: Text(s.pay),
              );
            },
          ),
        ],
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
