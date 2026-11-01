import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/product.dart';
import '../../../../data/services/product_image_store.dart';
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
    final photo = resolveProductImagePath(product.imagePath);

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

            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: photo != null
                    ? LayoutBuilder(
                        builder: (context, constraints) => Image.file(
                          File(photo),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          cacheWidth:
                              _decodeWidth(context, constraints.maxWidth),
                          errorBuilder: (_, __, ___) =>
                              _ProductImagePlaceholder(product: product),
                        ),
                      )
                    : _ProductImagePlaceholder(product: product),
              ),
            ),

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

              child: LayoutBuilder(
                builder: (context, constraints) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CurrencyFormatter.format(product.sellingPrice),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                        ),
                        StockBadge(product: product),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int? _decodeWidth(BuildContext context, double maxWidth) {
  if (!maxWidth.isFinite || maxWidth <= 0) return null;
  return (maxWidth * MediaQuery.devicePixelRatioOf(context) * 1.4).ceil();
}

class _ProductImagePlaceholder extends StatelessWidget {
  final Product product;

  const _ProductImagePlaceholder({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.primary.withOpacity(0.06),

      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ThinIcon(
                    tabler.Package.new,
                    size: 36,
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  if (product.category.isNotEmpty)
                    Text(
                      product.category,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
