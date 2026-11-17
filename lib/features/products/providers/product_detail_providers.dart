import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:isar_community/isar.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product.dart';
import '../../../data/models/product_serial.dart';
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

/// One serial of a product with the order it went out on, if any.
typedef SerialRow = ({ProductSerial serial, Order? order});

/// A product's serial numbers, newest first, each with its order; live.
@riverpod
Stream<List<SerialRow>> productSerials(Ref ref, int productId) async* {
  final isar = await ref.watch(isarProvider.future);
  await for (final rows in isar.productSerials.where().productIdEqualTo(productId).watch(fireImmediately: true)) {
    rows.sort((a, b) => b.id.compareTo(a.id));
    final orderIds = {for (final r in rows) if (r.orderId > 0) r.orderId}.toList();
    final orders = {
      for (final o in await isar.orders.getAll(orderIds))
        if (o != null) o.id: o,
    };
    yield [for (final r in rows) (serial: r, order: orders[r.orderId])];
  }
}
