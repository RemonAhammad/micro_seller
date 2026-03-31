import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/product.dart';
import '../../../../core/constants/app_colors.dart';

class LowStockList extends StatelessWidget {
  final List<Product> products;

  const LowStockList({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: products
          .take(5)
          .map((product) => _LowStockItem(product: product))
          .toList(),
    );
  }
}

class _LowStockItem extends StatelessWidget {
  final Product product;

  const _LowStockItem({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOut = product.isOutOfStock;
    final color = isOut ? AppColors.statusCancelled : AppColors.statusPending;

    return InkWell(
      onTap: () => context.push('/products/${product.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isOut
                    ? Icons.remove_shopping_cart_rounded
                    : Icons.warning_amber_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    product.sku,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOut ? 'Out' : '${product.stockQty} left',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
