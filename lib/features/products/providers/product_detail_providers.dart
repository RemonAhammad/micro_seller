import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_service.dart';

part 'product_detail_providers.g.dart';

/// One product, live, for its detail screen — so it shows an edit or a stock
/// adjustment made while it's open. A provider rather than a future created
/// in build(): go_router rebuilds pages on every push/pop in the branch, and
/// each rebuild used to re-query and flash a spinner.
///
/// Null when the product doesn't exist. But once a product has been shown, a
/// later delete keeps its last value: the detail screen pops itself after
/// deleting, and its exit transition shouldn't switch to "Product not found"
/// (it never did when the screen read the product once).
@riverpod
Stream<Product?> productById(Ref ref, int id) async* {
  final isar = await ref.watch(isarProvider.future);
  var last = isar.products.getSync(id);
  yield last;
  // No fireImmediately: the current value was just yielded above.
  await for (final product in isar.products.watchObject(id)) {
    if (product == null && last != null) continue;
    last = product;
    yield product;
  }
}
