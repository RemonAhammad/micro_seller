import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/supplier.dart';
import '../../../data/services/isar_service.dart';

part 'supplier_detail_providers.g.dart';

@riverpod
Stream<Supplier?> supplierById(Ref ref, int id) async* {
  final isar = await ref.watch(isarProvider.future);
  yield isar.suppliers.getSync(id);

  yield* isar.suppliers.watchObject(id);
}
