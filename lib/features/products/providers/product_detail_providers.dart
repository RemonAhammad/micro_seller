import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_service.dart';

part 'product_detail_providers.g.dart';

@riverpod
Stream<Product?> productById(Ref ref, int id) async* {
  final isar = await ref.watch(isarProvider.future);
  var last = isar.products.getSync(id);
  yield last;

  await for (final product in isar.products.watchObject(id)) {
    if (product == null && last != null) continue;
    last = product;
    yield product;
  }
}
