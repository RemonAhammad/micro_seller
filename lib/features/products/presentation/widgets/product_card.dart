import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/product.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'stock_badge.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../../core/constants/app_icons.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ProductCard({
    super.key,
    required this.product,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/products/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: product.imagePath.isNotEmpty
                    ? Image.file(
                        File(product.imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            _ProductImagePlaceholder(product: product),
                      )
                    : _ProductImagePlaceholder(product: product),
              ),
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Text(
                product.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  Text(
                    CurrencyFormatter.format(product.sellingPrice),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  StockBadge(product: product),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  final Product product;

  const _ProductImagePlaceholder({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primary.withOpacity(0.06),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThinIcon(
              tabler.Package.new,
              size: 36,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            if (product.category.isNotEmpty)
              Text(
                product.category,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.primary.withOpacity(0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
