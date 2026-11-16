import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/services/db_worker.dart';
import '../../../data/services/isar_revisions.dart';
import '../../../data/services/isar_service.dart';

part 'quick_add_provider.g.dart';

/// How many products the order form offers as one-tap chips.
const kQuickAddCount = 8;

/// How many recent orders decide what counts as "often sold".
const kQuickAddOrderWindow = 300;

/// The seller's most often sold products of late, for the order form's
/// quick-add chips: active ones with something left to sell, most sold first.
@riverpod
Future<List<Product>> quickAddProducts(Ref ref) async {
  ref.watch(ordersRevisionProvider);
  ref.watch(productsRevisionProvider);
  final isar = await ref.watch(isarProvider.future);
  return runDbJob(isar, topRecentProductsJob);
}

/// Counts the orders each product appears in (not its quantity, so one bulk
/// order doesn't outrank daily sellers) over the last
/// [kQuickAddOrderWindow] sales. Ties keep the more recent product first.
List<Product> topRecentProductsJob(Isar db) {
  final orders = db.orders
      .where(sort: Sort.desc)
      .anyCreatedAt()
      .filter()
      .isReturnEqualTo(false)
      .not()
      .orderStatusEqualTo(OrderStatus.cancelled)
      .limit(kQuickAddOrderWindow)
      .findAllSync();

  final counts = <int, int>{};
  for (final order in orders) {
    for (final id in order.items.map((i) => i.productId).toSet()) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return const [];

  final ranked = counts.keys.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  final products = db.products.getAllSync(ranked);

  return [
    for (final p in products)
      if (p != null && p.isActive && _hasStock(p)) p,
  ].take(kQuickAddCount).toList();
}

bool _hasStock(Product p) => p.hasVariants
    ? p.variantCombinations.any((c) => c.isActive && c.stockQty > 0)
    : p.stockQty > 0;
