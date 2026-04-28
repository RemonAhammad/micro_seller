import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/inventory_provider.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../features/categories/providers/category_provider.dart';
import '../../../data/models/product.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'widgets/stock_movement_tile.dart';

enum _StockSort { lowStock, name, stockAsc, stockDesc }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _StockSort _sort = _StockSort.lowStock;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Product> _sorted(List<Product> products) {
    final list = [...products];
    switch (_sort) {
      case _StockSort.lowStock:
        list.sort((a, b) {
          // Score: how urgently stock is needed (lower = more urgent)
          // Out of stock → negative, low stock → small positive, healthy → large
          final aDiff = a.stockQty - a.lowStockThreshold;
          final bDiff = b.stockQty - b.lowStockThreshold;
          return aDiff.compareTo(bDiff);
        });
      case _StockSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _StockSort.stockAsc:
        list.sort((a, b) => a.stockQty.compareTo(b.stockQty));
      case _StockSort.stockDesc:
        list.sort((a, b) => b.stockQty.compareTo(a.stockQty));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final movementsAsync = ref.watch(stockMovementsProvider);
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.inventory),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: s.stockLevels),
            Tab(text: s.movements),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Stock levels tab ──
          productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_rounded,
                  title: s.noDataFound,
                  subtitle: s.addFirstProduct,
                );
              }

              // Collect unique categories from products
              final categoryNames = categoriesAsync.whenOrNull(
                    data: (cats) => cats.map((c) => c.name).toList(),
                  ) ??
                  <String>[];

              final filtered = _categoryFilter == null
                  ? products
                  : products
                      .where((p) => p.category == _categoryFilter)
                      .toList();
              final sorted = _sorted(filtered);

              return Column(
                children: [
                  // Filter & sort bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Row(
                      children: [
                        // Category filter
                        PopupMenuButton<String?>(
                          initialValue: _categoryFilter,
                          onSelected: (v) =>
                              setState(() => _categoryFilter = v),
                          tooltip: s.filter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _categoryFilter != null
                                  ? cs.primary.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _categoryFilter != null
                                    ? cs.primary.withValues(alpha: 0.3)
                                    : cs.outline.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.filter_list,
                                    size: 15,
                                    color: _categoryFilter != null
                                        ? cs.primary
                                        : cs.onSurface
                                            .withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  _categoryFilter ?? s.all,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _categoryFilter != null
                                        ? cs.primary
                                        : cs.onSurface
                                            .withValues(alpha: 0.6),
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down,
                                    size: 16,
                                    color: _categoryFilter != null
                                        ? cs.primary
                                        : cs.onSurface
                                            .withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                          itemBuilder: (_) => [
                            PopupMenuItem<String?>(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(Icons.clear_all,
                                      size: 18,
                                      color: _categoryFilter == null
                                          ? cs.primary
                                          : cs.onSurface
                                              .withValues(alpha: 0.6)),
                                  const SizedBox(width: 10),
                                  Text(s.tr('allCategories'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _categoryFilter == null
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: _categoryFilter == null
                                            ? cs.primary
                                            : null,
                                      )),
                                  if (_categoryFilter == null) ...[
                                    const Spacer(),
                                    Icon(Icons.check,
                                        size: 16, color: cs.primary),
                                  ],
                                ],
                              ),
                            ),
                            ...categoryNames.map((name) => PopupMenuItem<String?>(
                                  value: name,
                                  child: Row(
                                    children: [
                                      Icon(Icons.label_outline,
                                          size: 18,
                                          color: _categoryFilter == name
                                              ? cs.primary
                                              : cs.onSurface
                                                  .withValues(alpha: 0.6)),
                                      const SizedBox(width: 10),
                                      Text(name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                                _categoryFilter == name
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                            color: _categoryFilter == name
                                                ? cs.primary
                                                : null,
                                          )),
                                      if (_categoryFilter == name) ...[
                                        const Spacer(),
                                        Icon(Icons.check,
                                            size: 16, color: cs.primary),
                                      ],
                                    ],
                                  ),
                                )),
                          ],
                        ),

                        const SizedBox(width: 6),
                        Text(
                          '${filtered.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const Spacer(),

                        // Sort
                        PopupMenuButton<_StockSort>(
                          initialValue: _sort,
                          onSelected: (v) => setState(() => _sort = v),
                          tooltip: s.tr('sort'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sort, size: 16, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                _sortLabel(_sort),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                ),
                              ),
                              Icon(Icons.arrow_drop_down,
                                  size: 18, color: cs.primary),
                            ],
                          ),
                          itemBuilder: (_) => [
                            _sortItem(_StockSort.lowStock, 'Low Stock First',
                                Icons.warning_amber_rounded),
                            _sortItem(_StockSort.name, 'Name',
                                Icons.sort_by_alpha),
                            _sortItem(_StockSort.stockAsc,
                                'Stock: Low → High', Icons.arrow_upward),
                            _sortItem(_StockSort.stockDesc,
                                'Stock: High → Low', Icons.arrow_downward),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Product list
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => AnimatedEntrance(
                        index: i,
                        child: _StockTile(
                            product: sorted[i], theme: theme, cs: cs),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),

          // ── Movements tab ──
          movementsAsync.when(
            data: (movements) {
              if (movements.isEmpty) {
                return EmptyState(
                  icon: Icons.swap_vert_rounded,
                  title: s.noStockMovements,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: movements.length,
                itemBuilder: (ctx, i) => AnimatedEntrance(
                  index: i,
                  child: StockMovementTile(movement: movements[i]),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ],
      ),
    );
  }

  String _sortLabel(_StockSort sort) {
    final s = AppStrings.of(context);
    return switch (sort) {
      _StockSort.lowStock => s.lowStock,
      _StockSort.name => s.customerName,
      _StockSort.stockAsc => '${s.stock} ↑',
      _StockSort.stockDesc => '${s.stock} ↓',
    };
  }

  PopupMenuItem<_StockSort> _sortItem(
      _StockSort value, String label, IconData icon) {
    final selected = _sort == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Theme.of(context).colorScheme.primary : null,
              )),
          if (selected) ...[
            const Spacer(),
            Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
          ],
        ],
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  final Product product;
  final ThemeData theme;
  final ColorScheme cs;

  const _StockTile({
    required this.product,
    required this.theme,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = product.isOutOfStock;
    final isLow = product.isLowStock;
    final color = isOut
        ? Colors.red
        : isLow
            ? Colors.orange
            : Colors.green;

    return Container(
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(product.sku,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        )),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.totalStock}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: color,
                    ),
                  ),
                  Text(
                    'of ${product.lowStockThreshold} threshold',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: () =>
                    context.push('/inventory/adjust/${product.id}'),
                style: IconButton.styleFrom(
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  foregroundColor: cs.primary,
                ),
              ),
            ],
          ),
          if (product.hasVariants) ...[
            const SizedBox(height: 8),
            ...product.variantCombinations.where((c) => c.isActive).map((c) {
              final vColor = c.stockQty <= 0
                  ? Colors.red
                  : c.stockQty <= product.lowStockThreshold
                      ? Colors.orange
                      : cs.onSurface.withValues(alpha: 0.7);
              return Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right,
                        size: 14, color: cs.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.displayLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${c.stockQty}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: vColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
