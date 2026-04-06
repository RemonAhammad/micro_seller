import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar/isar.dart';
import '../../../data/models/product.dart';
import '../providers/product_provider.dart';
import '../../../data/services/isar_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'widgets/stock_badge.dart';

class ProductDetailScreen extends ConsumerWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isarAsync = ref.watch(isarProvider);

    return isarAsync.when(
      data: (isar) => _ProductDetailBody(productId: productId, isar: isar),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }
}

class _ProductDetailBody extends ConsumerWidget {
  final int productId;
  final Isar isar;

  const _ProductDetailBody({required this.productId, required this.isar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return FutureBuilder<Product?>(
      future: isar.products.get(productId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final product = snapshot.data;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Product not found')),
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
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => context.push('/products/$productId/edit'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded),
                    onPressed: () async {
                      final ok = await ConfirmDialog.show(
                        context,
                        title: 'Delete Product',
                        message: 'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
                        confirmText: 'Delete',
                        isDestructive: true,
                        icon: Icons.delete_rounded,
                      );
                      if (ok == true && context.mounted) {
                        await ref.read(productNotifierProvider.notifier).deleteProduct(product.id);
                        if (context.mounted) context.pop();
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
                          child: const Icon(Icons.inventory_2_rounded, size: 80, color: Colors.white30),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StockBadge(product: product),
                        ],
                      ),
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
                            'Selling Price',
                            CurrencyFormatter.format(product.sellingPrice),
                            valueColor: theme.colorScheme.primary,
                            isBold: true,
                          ),
                          if (product.costPrice > 0) ...[
                            _InfoRow('Cost Price', CurrencyFormatter.format(product.costPrice)),
                            _InfoRow(
                              'Profit Margin',
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
                            'Current Stock',
                            '${product.stockQty} units',
                            valueColor: product.isOutOfStock
                                ? AppColors.statusCancelled
                                : product.isLowStock
                                    ? AppColors.statusPending
                                    : null,
                          ),
                          _InfoRow('Low Stock Alert', '${product.lowStockThreshold} units'),
                        ],
                      ),
                      if (product.hasVariants) ...[
                        const SizedBox(height: 12),
                        _InfoCard(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Variants (${product.variantCombinations.where((c) => c.isActive).length} combinations)',
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
                                    Row(
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
                                          Text(
                                            c.sku,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Stock: ${c.stockQty}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: c.stockQty <= 0
                                                ? AppColors.statusCancelled
                                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        if (c.priceAdjustment != 0) ...[
                                          const SizedBox(width: 16),
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
                            _InfoRow('QR / Barcode', product.qrCode),
                          ],
                        ),
                      ],
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InfoCard(
                          children: [
                            Text(
                              'Description',
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
                          _InfoRow('Created', DateFormatter.format(product.createdAt)),
                          _InfoRow('Last Updated', DateFormatter.format(product.updatedAt)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Adjust stock button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/inventory/adjust/$productId'),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Adjust Stock'),
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

  const _InfoRow(this.label, this.value, {this.valueColor, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
