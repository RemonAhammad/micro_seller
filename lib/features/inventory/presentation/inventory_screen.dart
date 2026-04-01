import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/inventory_provider.dart';
import '../../../features/products/providers/product_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/empty_state.dart';
import 'widgets/stock_movement_tile.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(stockMovementsProvider);
    final productsAsync = ref.watch(productsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.inventory),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Stock Levels'),
            Tab(text: 'Movements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Stock levels tab
          productsAsync.when(
            data: (products) {
              if (products.isEmpty) {
                return const EmptyState(
                  icon: Icons.inventory_2_rounded,
                  title: AppStrings.noDataFound,
                  subtitle: AppStrings.addFirstProduct,
                );
              }

              // Sort: out of stock first, then low stock, then in stock
              final sorted = [...products]
                ..sort((a, b) {
                  final aScore = a.isOutOfStock
                      ? 0
                      : a.isLowStock
                          ? 1
                          : 2;
                  final bScore = b.isOutOfStock
                      ? 0
                      : b.isLowStock
                          ? 1
                          : 2;
                  return aScore.compareTo(bScore);
                });

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final product = sorted[i];
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
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6)
                      ],
                    ),
                    child: Row(
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
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  )),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${product.stockQty}',
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
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.4),
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
                            backgroundColor: theme.colorScheme.primary
                                .withOpacity(0.1),
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),

          // Movements tab
          movementsAsync.when(
            data: (movements) {
              if (movements.isEmpty) {
                return const EmptyState(
                  icon: Icons.swap_vert_rounded,
                  title: AppStrings.noStockMovements,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: movements.length,
                itemBuilder: (ctx, i) =>
                    StockMovementTile(movement: movements[i]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          ),
        ],
      ),
    );
  }
}
