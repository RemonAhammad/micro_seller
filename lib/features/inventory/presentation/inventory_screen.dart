import 'dart:math' as math;

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
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../../core/constants/app_icons.dart';

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
                  icon: tabler.Package.new,
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
                        // Category filter and count, in the space the sort
                        // button leaves: a long category name ellipsizes.
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: _categoryFilterButton(categoryNames, cs),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${filtered.length}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.4),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Sort
                        PopupMenuButton<_StockSort>(
                          initialValue: _sort,
                          onSelected: (v) => setState(() => _sort = v),
                          tooltip: s.tr('sort'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ThinIcon(tabler.ArrowsSort.new, size: 16, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                _sortLabel(_sort),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                ),
                              ),
                              ThinIcon(tabler.CaretDown.new,
                                  size: 18, color: cs.primary),
                            ],
                          ),
                          itemBuilder: (_) => [
                            _sortItem(_StockSort.lowStock, 'Low Stock First',
                                tabler.AlertTriangle.new),
                            _sortItem(_StockSort.name, 'Name',
                                tabler.SortAscendingLetters.new),
                            _sortItem(_StockSort.stockAsc,
                                'Stock: Low → High', tabler.ArrowUp.new),
                            _sortItem(_StockSort.stockDesc,
                                'Stock: High → Low', tabler.ArrowDown.new),
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
          const _MovementsTab(),
        ],
      ),
    );
  }

  /// The category filter: the selected category (or All) and its menu.
  Widget _categoryFilterButton(List<String> categoryNames, ColorScheme cs) {
    final s = AppStrings.of(context);
    return PopupMenuButton<String?>(
      initialValue: _categoryFilter,
      onSelected: (v) => setState(() => _categoryFilter = v),
      tooltip: s.filter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            ThinIcon(tabler.Filter.new,
                size: 15,
                color: _categoryFilter != null
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _categoryFilter ?? s.all,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _categoryFilter != null
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ThinIcon(tabler.CaretDown.new,
                size: 16,
                color: _categoryFilter != null
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              ThinIcon(tabler.ClearAll.new,
                  size: 18,
                  color: _categoryFilter == null
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.tr('allCategories'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _categoryFilter == null
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: _categoryFilter == null ? cs.primary : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              if (_categoryFilter == null)
                ThinIcon(tabler.Check.new, size: 16, color: cs.primary),
            ],
          ),
        ),
        ...categoryNames.map((name) => PopupMenuItem<String?>(
              value: name,
              child: Row(
                children: [
                  ThinIcon(tabler.Tag.new,
                      size: 18,
                      color: _categoryFilter == name
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _categoryFilter == name
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _categoryFilter == name ? cs.primary : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (_categoryFilter == name)
                    ThinIcon(tabler.Check.new, size: 16, color: cs.primary),
                ],
              ),
            )),
      ],
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
      _StockSort value, String label, ThinIconBuilder icon) {
    final selected = _sort == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          ThinIcon(icon, size: 18,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Theme.of(context).colorScheme.primary : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          if (selected)
            ThinIcon(tabler.Check.new, size: 16, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }
}

/// The movement history, watched only while this tab is built — at the
/// screen's root it stayed loaded and reloaded on every stock change while
/// the Stock Levels tab was showing. Paged: nearing the end of the loaded
/// rows loads the next page, with a spinner row below while more exist.
class _MovementsTab extends ConsumerStatefulWidget {
  const _MovementsTab();

  @override
  ConsumerState<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends ConsumerState<_MovementsTab> {
  /// How close to the last loaded row the next page is requested.
  static const _loadMoreAhead = 20;
  bool _loadMoreScheduled = false;

  // After the frame: the notifier's state can't change during a build.
  void _loadMoreSoon() {
    if (_loadMoreScheduled) return;
    _loadMoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreScheduled = false;
      if (mounted) ref.read(stockMovementPagesProvider.notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return ref.watch(stockMovementPagesProvider).when(
          data: (page) {
            final movements = page.movements;
            if (movements.isEmpty) {
              return EmptyState(
                icon: tabler.ArrowsSort.new,
                title: s.noStockMovements,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: movements.length + (page.hasMore ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (page.hasMore && i >= movements.length - _loadMoreAhead) {
                  _loadMoreSoon();
                }
                if (i == movements.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return AnimatedEntrance(
                  index: i,
                  child: StockMovementTile(movement: movements[i]),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        );
  }
}

/// What [text] needs drawn by a [Text] here with [style]: the width of its
/// longest word, and of the whole text on one line (rounded up).
({double word, double line}) _textWidths(
    BuildContext context, String text, TextStyle? style) {
  var effective = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
  final widths = (
    word: painter.minIntrinsicWidth.ceilToDouble(),
    line: painter.maxIntrinsicWidth.ceilToDouble(),
  );
  painter.dispose();
  return widths;
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
          LayoutBuilder(
            builder: (context, row) => Row(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, beside) {
                    final stock = '${product.totalStock}';
                    final caption = 'of ${product.lowStockThreshold} threshold';
                    final nameStyle = theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600);
                    final skuStyle = theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    );
                    final stockStyle = TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: color,
                    );
                    final captionStyle = TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    );
                    // The stock column keeps its own width while the name
                    // column beside it keeps its longest word and 30% of the
                    // tile, as it always did on a phone at 100%. Past that (a
                    // huge number, a narrow layout, large text) it takes at
                    // most 40% of the tile, so the name keeps room: the
                    // number shrinks and the caption wraps.
                    final fits = math.max(
                              _textWidths(context, stock, stockStyle).line,
                              _textWidths(context, caption, captionStyle).line,
                            ) +
                            [
                              row.maxWidth * 0.3,
                              _textWidths(context, product.name, nameStyle)
                                  .word,
                              _textWidths(context, product.sku, skuStyle).word,
                            ].reduce(math.max) <=
                        beside.maxWidth;

                    Widget stockText = Text(stock, style: stockStyle);
                    if (!fits) {
                      stockText = FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: stockText,
                      );
                    }
                    Widget stockColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        stockText,
                        Text(
                          caption,
                          style: captionStyle,
                          textAlign: fits ? null : TextAlign.end,
                        ),
                      ],
                    );
                    if (!fits) {
                      stockColumn = ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: row.maxWidth * 0.4),
                        child: stockColumn,
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.name, style: nameStyle),
                              Text(product.sku, style: skuStyle),
                            ],
                          ),
                        ),
                        stockColumn,
                      ],
                    );
                  }),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const ThinIcon(tabler.AdjustmentsHorizontal.new),
                  onPressed: () =>
                      context.push('/inventory/adjust/${product.id}'),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primary.withValues(alpha: 0.1),
                    foregroundColor: cs.primary,
                  ),
                ),
              ],
            ),
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
                    ThinIcon(tabler.CornerDownRight.new,
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
