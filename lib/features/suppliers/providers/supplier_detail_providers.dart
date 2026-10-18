import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/supplier.dart';
import '../../../data/services/isar_service.dart';

part 'supplier_detail_providers.g.dart';

/// One supplier, live, for their detail screen. A provider rather than a
/// stream created in build(): go_router rebuilds pages on every push/pop in
/// the branch, and each rebuild used to resubscribe. Null once the supplier
/// doesn't exist.
@riverpod
Stream<Supplier?> supplierById(Ref ref, int id) async* {
  final isar = await ref.watch(isarProvider.future);
  yield isar.suppliers.getSync(id);
  // No fireImmediately: the current value was just yielded above.
  yield* isar.suppliers.watchObject(id);
}
