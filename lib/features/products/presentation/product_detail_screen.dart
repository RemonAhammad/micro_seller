import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/product_detail_providers.dart';
import '../providers/product_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../settings/providers/trash_provider.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'widgets/stock_badge.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

class ProductDetailScreen extends ConsumerWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    // Live, so an edit or a stock adjustment shows on return.
    return ref.watch(productByIdProvider(productId)).when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (product) {
        if (product == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(s.productNotFound)),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                actions: [
                  IconButton(
                    icon: const ThinIcon(tabler.Pencil.new),
                    onPressed: () => context.push('/products/$productId/edit'),
                  ),
                  IconButton(
                    icon: const ThinIcon(tabler.Trash.new),
                    onPressed: () async {
                      final ok = await ConfirmDialog.show(
                        context,
                        title: s.deleteProduct,
                        message: s.deleteProductConfirm,
                        confirmText: s.delete,
                        isDestructive: true,
                        icon: tabler.Trash.new,
                      );
                      if (ok == true && context.mounted) {
                        final trashId = await ref
                            .read(productProvider.notifier)
                            .deleteProduct(product.id);
                        if (!context.mounted) return;
                        context.pop();
                        // After the pop, so the snackbar belongs to the list
                        // screen rather than the detail screen unwinding.
                        if (trashId != null) {
                          context.showUndoSnackBar(
                            '${s.itemDeleted}: ${product.name}',
                            onUndo: () => ref
                                .read(trashProvider.notifier)
                                .restore(trashId),
                          );
                        }
                      }
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: product.imagePath.isNotEmpty
                      ? Image.file(File(product.imagePath), fit: BoxFit.cover)
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withOpacity(0.6),
                              ],
                            ),
                          ),
                          // The text color on the main color, at white30's
                          // alpha.
                          child: ThinIcon(
                            tabler.Package.new,
                            size: 80,
                            color: theme.colorScheme.onPrimary.withAlpha(0x4D),
                          ),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The stock badge sits beside the name, or under it
                      // once large text on a narrow layout would leave the
                      // name too little room for its words.
                      LayoutBuilder(builder: (context, constraints) {
                        final beside = constraints.maxWidth >=
                            MediaQuery.textScalerOf(context).scale(224);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SKU: ${product.sku}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  if (!beside) ...[
                                    const SizedBox(height: 8),
                                    StockBadge(product: product),
                                  ],
                                ],
                              ),
                            ),
                            if (beside) StockBadge(product: product),
                          ],
                        );
                      }),
                      if (product.category.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Pricing card
                      _InfoCard(
                        children: [
                          _InfoRow(
                            s.sellingPrice,
                            CurrencyFormatter.format(product.sellingPrice),
                            valueColor: theme.colorScheme.primary,
                            isBold: true,
                          ),
                          if (product.costPrice > 0) ...[
                            _InfoRow(s.costPrice, CurrencyFormatter.format(product.costPrice)),
                            _InfoRow(
                              s.profitMargin,
                              '${product.profitMargin.toStringAsFixed(1)}%',
                              valueColor:
                                  product.profitMargin >= 0 ? AppColors.statusCompleted : AppColors.statusCancelled,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Stock card
                      _InfoCard(
                        children: [
                          _InfoRow(
                            s.stock,
                            '${product.stockQty}',
                            valueColor: product.isOutOfStock
                                ? AppColors.statusCancelled
                                : product.isLowStock
                                    ? AppColors.statusPending
                                    : null,
                          ),
                          _InfoRow(s.lowStockThreshold, '${product.lowStockThreshold}'),
                        ],
                      ),
                      if (product.hasVariants) ...[
                        const SizedBox(height: 12),
                        _InfoCard(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${s.variants} (${product.variantCombinations.where((c) => c.isActive).length} ${s.combinations})',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...product.variantCombinations.where((c) => c.isActive).map((c) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // A long SKU wraps in up to 40% of the
                                    // row instead of pushing the label out.
                                    LayoutBuilder(
                                      builder: (context, constraints) => Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c.displayLabel,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (c.sku.isNotEmpty)
                                            ConstrainedBox(
                                              constraints: BoxConstraints(
                                                  maxWidth: constraints.maxWidth * 0.4),
                                              child: Text(
                                                c.sku,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                ),
                                                textAlign: TextAlign.end,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // The price adjustment moves to its own
                                    // line when the two don't fit side by side.
                                    Wrap(
                                      spacing: 16,
                                      children: [
                                        Text(
                                          '${s.stock}: ${c.stockQty}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: c.stockQty <= 0
                                                ? AppColors.statusCancelled
                                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        if (c.priceAdjustment != 0) ...[
                                          Text(
                                            'Price: ${c.priceAdjustment > 0 ? '+' : ''}${CurrencyFormatter.format(c.priceAdjustment)}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: c.priceAdjustment > 0
                                                  ? AppColors.statusCompleted
                                                  : AppColors.statusCancelled,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )),
                          ],
                        ),
                      ],
                      if (product.qrCode.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InfoCard(
                          children: [
                            _InfoRow(s.qrBarcode, product.qrCode,
                                wrapValue: true),
                          ],
                        ),
                      ],
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InfoCard(
                          children: [
                            Text(
                              s.description,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(product.description),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      _InfoCard(
                        children: [
                          _InfoRow(s.tr('created'), DateFormatter.format(product.createdAt)),
                          _InfoRow(s.tr('lastUpdated'), DateFormatter.format(product.updatedAt)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Adjust stock button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/inventory/adjust/$productId'),
                          icon: const ThinIcon(tabler.AdjustmentsHorizontal.new),
                          label: Text(s.adjustStock),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  /// Free text such as a scanned code: wraps instead of shrinking to fit.
  final bool wrapValue;

  const _InfoRow(this.label, this.value,
      {this.valueColor, this.isBold = false, this.wrapValue = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueText = Text(
      value,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
        color: valueColor,
      ),
      textAlign: TextAlign.end,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      // The value keeps its own width up to 60% of the row (an amount past
      // that is shrunk to fit, never cut; free text wraps in half the row);
      // the label wraps in the rest.
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * (wrapValue ? 0.5 : 0.6)),
              child: wrapValue
                  ? valueText
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: valueText,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
