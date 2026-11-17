import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/variant_combination.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';

/// One row of the dashboard low-stock list: a whole product, or a single
/// low / out-of-stock variation of it.
class _LowEntry {
  final Product product;
  final VariantCombination? combination;
  const _LowEntry(this.product, [this.combination]);

  bool get isOut => combination != null
      ? combination!.stockQty <= 0
      : product.isOutOfStock;

  double get stockQty =>
      combination != null ? combination!.stockQty : product.stockQty;

  String? get subtitle =>
      combination != null ? combination!.displayLabel : product.sku;
}

class LowStockList extends StatelessWidget {
  final List<Product> products;

  const LowStockList({super.key, required this.products});

  /// Flattens products into per-variation entries: a variant product
  /// contributes one entry per out-of-stock variation and one per low
  /// variation; a plain product contributes a single entry.
  static List<_LowEntry> _entries(List<Product> products) {
    final entries = <_LowEntry>[];
    for (final product in products) {
      if (product.hasVariants) {
        for (final c in product.outOfStockCombinations) {
          entries.add(_LowEntry(product, c));
        }
        for (final c in product.lowStockCombinations) {
          entries.add(_LowEntry(product, c));
        }
      } else {
        entries.add(_LowEntry(product));
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _entries(products)
          .take(5)
          .map((entry) => _LowStockItem(entry: entry))
          .toList(),
    );
  }
}

class _LowStockItem extends StatelessWidget {
  final _LowEntry entry;

  const _LowStockItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final product = entry.product;
    final isOut = entry.isOut;
    final color = isOut ? AppColors.statusCancelled : AppColors.statusPending;
    final subtitle = entry.subtitle;

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
              child: ThinIcon(
                isOut
                    ? tabler.ShoppingCartOff.new
                    : tabler.AlertTriangle.new,
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
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                isOut
                    ? s.outOfStock
                    : '${s.qty(entry.stockQty, product.unit)} ${s.left}',
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
