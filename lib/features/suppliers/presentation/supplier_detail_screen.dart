import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/supplier.dart';
import '../providers/supplier_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/confirm_dialog.dart';

class SupplierDetailScreen extends ConsumerWidget {
  final int supplierId;

  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isarAsync = ref.watch(isarProvider);
    return isarAsync.when(
      data: (isar) => _Body(supplierId: supplierId, isar: isar),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }
}

class _Body extends ConsumerWidget {
  final int supplierId;
  final Isar isar;

  const _Body({required this.supplierId, required this.isar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return StreamBuilder<Supplier?>(
      stream: isar.suppliers.watchObject(supplierId, fireImmediately: true),
      builder: (context, snap) {
        final supplier = snap.data;
        if (supplier == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(s.supplierNotFound)),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(supplier.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => context.push('/suppliers/${supplier.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded),
                onPressed: () async {
                  final ok = await ConfirmDialog.show(
                    context,
                    title: s.deleteSupplier,
                    message: '${s.delete} "${supplier.name}"? ${s.tr("deleteSupplierConfirm")}',
                    confirmText: s.delete,
                    isDestructive: true,
                    icon: Icons.delete_rounded,
                  );
                  if (ok == true && context.mounted) {
                    await ref.read(supplierNotifierProvider.notifier).deleteSupplier(supplier.id);
                    if (context.mounted) context.pop();
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
                  ),
                  child: Column(
                    children: [
                      if (supplier.company.isNotEmpty)
                        _row(theme, s.company, supplier.company),
                      if (supplier.phone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s.phone, style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.6),
                              )),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(supplier.phone, style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => launchUrl(Uri.parse('tel:${supplier.phone}')),
                                    child: Icon(Icons.call_rounded, size: 18, color: cs.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (supplier.email.isNotEmpty)
                        _row(theme, s.tr('email'), supplier.email),
                      if (supplier.address.isNotEmpty)
                        _row(theme, s.address, supplier.address),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Stats card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
                  ),
                  child: Column(
                    children: [
                      _row(theme, s.purchases, '${supplier.totalPurchases}'),
                      _row(theme, s.paid, CurrencyFormatter.format(supplier.totalPaid)),
                      if (supplier.hasOutstanding)
                        _row(theme, s.due, CurrencyFormatter.format(supplier.totalDue),
                            valueColor: Colors.red),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            context.push('/suppliers/${supplier.id}/purchase/add'),
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: Text(s.newPurchase),
                      ),
                    ),
                    if (supplier.hasOutstanding) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showPayDialog(context, ref, supplier),
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: Text(s.payDue),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // Products from this supplier
                _SupplierProductsSection(supplierId: supplier.id),

                const SizedBox(height: 20),

                // Restock Activity (unified: purchases + stock adjustments)
                _SupplierRestockActivity(supplierId: supplier.id),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(ThemeData theme, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          )),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600, color: valueColor,
          )),
        ],
      ),
    );
  }

  void _showPayDialog(BuildContext context, WidgetRef ref, Supplier supplier) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(context).tr('recordPaymentToSupplier')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${AppStrings.of(context).due}: ${CurrencyFormatter.format(supplier.totalDue)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppStrings.of(context).paymentAmount,
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.of(context).cancel)),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0) return;
              await ref.read(supplierNotifierProvider.notifier)
                  .recordSupplierPayment(supplier.id, amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppStrings.of(context).payDue),
          ),
        ],
      ),
    );
  }
}

// ─── Products From This Supplier Section ───────────────────────────────────

class _SupplierProductsSection extends ConsumerWidget {
  final int supplierId;

  const _SupplierProductsSection({required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final productsAsync = ref.watch(supplierProductsProvider(supplierId));

    return productsAsync.when(
      data: (products) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(AppStrings.of(context).productsFromSupplier,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${products.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (products.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                ),
                child: Center(
                  child: Text(
                    'No products linked to this supplier',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              )
            else
              Column(
                children: products.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () => context.push('/products/${p.id}'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.inventory_2_outlined,
                                size: 18, color: cs.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                if (p.sku.isNotEmpty)
                                  Text('SKU: ${p.sku}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.5))),
                              ],
                            ),
                          ),
                          Text(
                            'Stock: ${p.totalStock}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.totalStock <= 0
                                    ? Colors.red
                                    : cs.onSurface.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
    );
  }
}

// ─── Supplier Restock Activity ──────────────────────────────────────────────

class _SupplierRestockActivity extends ConsumerWidget {
  final int supplierId;

  const _SupplierRestockActivity({required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final movementsAsync =
        ref.watch(supplierStockMovementsProvider(supplierId));

    return movementsAsync.when(
      data: (movements) {
        // Only show incoming (positive qty) restocks
        final restocks = movements.where((m) => m.qty > 0).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(AppStrings.of(context).restockActivity,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${restocks.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (restocks.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                ),
                child: Center(
                  child: Text(
                    'No restocks from this supplier yet',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              )
            else
              Column(
                children: restocks
                    .map((m) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: cs.outline.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('+${m.qty}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: Colors.green)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(m.productName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    Text(
                                      DateFormatter.formatWithTime(
                                          m.createdAt),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.5)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
    );
  }
}
