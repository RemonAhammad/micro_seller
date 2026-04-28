import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/product_provider.dart';
import '../../categories/providers/category_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/debouncer.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/animated_entrance.dart';
import 'widgets/product_card.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer();
  String _query = '';
  String? _selectedCategory;
  bool _showGrid = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.products),
        actions: [
          IconButton(
            icon: Icon(
                _showGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => _debouncer.run(
                      () => setState(() => _query = v.toLowerCase())),
                  decoration: InputDecoration(
                    hintText: s.searchProducts,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              categoriesAsync.when(
                data: (cats) => cats.isEmpty
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(s.all),
                                selected: _selectedCategory == null,
                                onSelected: (_) =>
                                    setState(() => _selectedCategory = null),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                            ...cats.map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(c.name),
                                    selected: _selectedCategory == c.name,
                                    onSelected: (_) => setState(() =>
                                        _selectedCategory =
                                            _selectedCategory == c.name
                                                ? null
                                                : c.name),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                )),
                          ],
                        ),
                      ),
                loading: () => const SizedBox(height: 40),
                error: (_, __) => const SizedBox(height: 40),
              ),
            ],
          ),
        ),
      ),
      body: productsAsync.when(
        data: (allProducts) {
          var products = allProducts;
          if (_selectedCategory != null) {
            products = products
                .where((p) => p.category == _selectedCategory)
                .toList();
          }
          if (_query.isNotEmpty) {
            products = products
                .where((p) =>
                    p.name.toLowerCase().contains(_query) ||
                    p.sku.toLowerCase().contains(_query) ||
                    p.category.toLowerCase().contains(_query))
                .toList();
          }

          if (products.isEmpty) {
            final isFiltered = _query.isNotEmpty || _selectedCategory != null;
            return EmptyState(
              icon: Icons.inventory_2_rounded,
              title: isFiltered ? s.noProductsFound : s.noDataFound,
              subtitle: isFiltered ? null : s.addFirstProduct,
              actionLabel: isFiltered ? null : s.addProduct,
              onAction: isFiltered ? null : () => context.push('/products/add'),
            );
          }

          if (_showGrid) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final cols = (constraints.maxWidth / 180).floor().clamp(2, 6);
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) => AnimatedEntrance(
                    index: i,
                    child: ProductCard(product: products[i]),
                  ),
                );
              },
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final product = products[i];
              return AnimatedEntrance(
                index: i,
                child: _ProductListTile(product: product),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('${AppStrings.of(context).error}: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/products/add'),
        tooltip: s.addProduct,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProductListTile extends ConsumerWidget {
  final dynamic product;

  const _ProductListTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/products/${product.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_rounded,
                color: theme.colorScheme.primary.withOpacity(0.5),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(product.sellingPrice),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  '${product.stockQty} ${AppStrings.of(context).tr('inStockLabel')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: product.isLowStock
                        ? Colors.orange
                        : product.isOutOfStock
                            ? Colors.red
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
