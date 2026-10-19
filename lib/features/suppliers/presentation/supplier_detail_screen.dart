import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/supplier.dart';
import '../providers/supplier_detail_providers.dart';
import '../providers/supplier_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class SupplierDetailScreen extends ConsumerWidget {
  final int supplierId;

  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ref.watch(supplierByIdProvider(supplierId)).when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (supplier) {
        if (supplier == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(s.supplierNotFound)),
          );
        }

        final newPurchase = FilledButton.icon(
          onPressed: () =>
              context.push('/suppliers/${supplier.id}/purchase/add'),
          icon: const ThinIcon(tabler.ShoppingCartPlus.new, size: 18),
          label: Text(s.newPurchase),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(supplier.name),
            actions: [
              IconButton(
                icon: const ThinIcon(tabler.Pencil.new),
                onPressed: () => context.push('/suppliers/${supplier.id}/edit'),
              ),
              IconButton(
                icon: const ThinIcon(tabler.Trash.new),
                onPressed: () async {
                  final ok = await ConfirmDialog.show(
                    context,
                    title: s.deleteSupplier,
                    message: '${s.delete} "${supplier.name}"? ${s.tr("deleteSupplierConfirm")}',
                    confirmText: s.delete,
                    isDestructive: true,
                    icon: tabler.Trash.new,
                  );
                  if (ok == true && context.mounted) {
                    await ref.read(supplierProvider.notifier).deleteSupplier(supplier.id);
                    if (context.mounted) context.pop();
                  }
                },
              ),
            ],
          ),
          // Slivers, so the product and restock lists only build what's on
          // screen.
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
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
                              _row(
                                theme,
                                s.phone,
                                supplier.phone,
                                keepWhole: true,
                                trailing: GestureDetector(
                                  onTap: () => launchUrl(Uri.parse('tel:${supplier.phone}')),
                                  child: ThinIcon(tabler.Phone.new, size: 18, color: cs.primary),
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
                            _row(theme, s.purchases, '${supplier.totalPurchases}',
                                keepWhole: true),
                            _row(theme, s.paid, CurrencyFormatter.format(supplier.totalPaid),
                                keepWhole: true),
                            if (supplier.hasOutstanding)
                              _row(theme, s.due, CurrencyFormatter.format(supplier.totalDue),
                                  valueColor: Colors.red, keepWhole: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Action buttons: side by side, or stacked when a
                      // label wouldn't fit its half.
                      if (supplier.hasOutstanding)
                        ButtonPair(
                          gap: 8,
                          first: newPurchase,
                          second: OutlinedButton.icon(
                            onPressed: () => _showPayDialog(context, ref, supplier),
                            icon: const ThinIcon(tabler.Cash.new, size: 18),
                            label: Text(s.payDue),
                          ),
                        )
                      else
                        Row(children: [Expanded(child: newPurchase)]),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Products from this supplier
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: _SupplierProductsSection(supplierId: supplier.id),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Restock Activity (unified: purchases + stock adjustments)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: _SupplierRestockActivity(supplierId: supplier.id),
              ),
            ],
          ),
        );
      },
    );
  }

  /// [label] at the start of a line and [value] at its end. A long label
  /// wraps within half the line (or its longest word, when that's wider)
  /// and a long value wraps under itself, or goes under the label when a
  /// word of it wouldn't fit beside it. With [keepWhole] (an amount, a phone
  /// number) the value shrinks to fit instead, so it is never split.
  Widget _row(ThemeData theme, String label, String value,
      {Color? valueColor, bool keepWhole = false, Widget? trailing}) {
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600, color: valueColor,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: keepWhole
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: valueText,
                          )
                        : valueText,
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ],
              ),
            ),
          ],
        );
      }),
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
              await ref.read(supplierProvider.notifier)
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
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(AppStrings.of(context).productsFromSupplier,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
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
                    ),
                ],
              ),
            ),
            SliverList.builder(
              itemCount: products.length,
              itemBuilder: (context, i) {
                final p = products[i];
                const nameStyle =
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 13);
                final sku = p.sku.isNotEmpty
                    ? '${AppStrings.of(context).sku}: ${p.sku}'
                    : null;
                final skuStyle = TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5));
                final stock = 'Stock: ${p.totalStock}';
                final stockStyle = TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.totalStock <= 0
                        ? Colors.red
                        : cs.onSurface.withValues(alpha: 0.7));
                return Padding(
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
                      child: LayoutBuilder(builder: (context, box) {
                        // The stock sits at the end of the row, unless that
                        // would leave the name or SKU too narrow for one of
                        // its words (large text, narrow layout): then it goes
                        // under them.
                        final stockBelow = box.maxWidth - 42 -
                                _textWidth(context, stock, stockStyle) <
                            math.max(
                              _textWidth(context, p.name, nameStyle,
                                  widestWord: true),
                              sku == null
                                  ? 0.0
                                  : _textWidth(context, sku, skuStyle,
                                      widestWord: true),
                            );
                        return Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ThinIcon(tabler.Package.new,
                                  size: 18, color: cs.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: nameStyle),
                                  if (sku != null) Text(sku, style: skuStyle),
                                  if (stockBelow)
                                    Text(stock, style: stockStyle),
                                ],
                              ),
                            ),
                            if (!stockBelow) Text(stock, style: stockStyle),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      loading: () => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverToBoxAdapter(child: Text('$e')),
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
        final badge = MediaQuery.textScalerOf(context).scale(36);

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(AppStrings.of(context).restockActivity,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
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
                    ),
                ],
              ),
            ),
            SliverList.builder(
              itemCount: restocks.length,
              itemBuilder: (context, i) {
                final m = restocks[i];
                return Container(
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
                        // 36 square at the default text size, growing with
                        // the text; a quantity too long for it shrinks
                        // instead of wrapping.
                        width: badge,
                        height: badge,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('+${m.qty}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: Colors.green)),
                            ),
                          ),
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
                );
              },
            ),
          ],
        );
      },
      loading: () => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverToBoxAdapter(child: Text('$e')),
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
