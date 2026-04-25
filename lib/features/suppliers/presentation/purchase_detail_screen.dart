import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import '../../../data/models/purchase.dart';
import '../providers/supplier_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/confirm_dialog.dart';

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

class _Body extends ConsumerWidget {
  final int purchaseId;
  final Isar isar;

  const _Body({required this.purchaseId, required this.isar});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<Purchase?>(
      stream: isar.purchases.watchObject(purchaseId, fireImmediately: true),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) {
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
                icon: const Icon(Icons.delete_rounded),
                onPressed: () async {
                  final ok = await ConfirmDialog.show(
                    context,
                    title: s.deletePurchase,
                    message: s.tr('deletePurchaseConfirm'),
                    confirmText: s.delete,
                    isDestructive: true,
                    icon: Icons.delete_rounded,
                  );
                  if (ok == true && context.mounted) {
                    await ref
                        .read(supplierNotifierProvider.notifier)
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
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('${item.qty}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: cs.primary,
                                            fontSize: 14)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(fontWeight: FontWeight.w600)),
                                      Text(
                                        '${CurrencyFormatter.format(item.unitCost)} × ${item.qty}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                            color: cs.onSurface
                                                .withValues(alpha: 0.5)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(CurrencyFormatter.format(item.totalCost),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
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
                          isBold: true, valueColor: cs.primary),
                      _row(theme, s.paid, CurrencyFormatter.format(p.amountPaid)),
                      if (p.balanceDue > 0)
                        _row(theme, s.balanceDue,
                            CurrencyFormatter.format(p.balanceDue),
                            isBold: true, valueColor: Colors.red),
                    ],
                  ),
                ),

                if (p.balanceDue > 0) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showPayDialog(context, ref, p),
                      icon: const Icon(Icons.payments_outlined),
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

  Widget _row(ThemeData theme, String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              )),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor,
              )),
        ],
      ),
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
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0) return;
              await ref
                  .read(supplierNotifierProvider.notifier)
                  .recordPurchasePayment(purchase.id, amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.pay),
          ),
        ],
      ),
    );
  }
}
