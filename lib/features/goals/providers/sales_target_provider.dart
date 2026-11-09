import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/sales_target.dart';
import '../../../data/services/isar_service.dart';

part 'sales_target_provider.g.dart';

@Riverpod(keepAlive: true)
class SalesTargetNotifier extends _$SalesTargetNotifier {
  @override
  Future<SalesTarget?> build() async {
    final isar = await ref.watch(isarProvider.future);
    final now = DateTime.now();
    return _findTarget(isar, now.year, now.month);
  }

  Future<SalesTarget?> _findTarget(Isar isar, int year, int month) async {
    return isar.salesTargets
        .filter()
        .yearEqualTo(year)
        .monthEqualTo(month)
        .findFirst();
  }

  Future<void> saveTarget(SalesTarget target) async {
    final isar = await ref.read(isarProvider.future);
    final now = DateTime.now();
    final updated = target.copyWith(
      updatedAt: now,
      createdAt: target.createdAt ?? now,
    );
    await isar.writeTxn(() async {
      await isar.salesTargets.put(updated);
    });
    state = AsyncData(updated);
  }

  Future<void> setRevenueTarget(double value) async {
    final current = await _getOrCreate();
    await saveTarget(current.copyWith(revenueTarget: value));
  }

  Future<void> setProfitTarget(double value) async {
    final current = await _getOrCreate();
    await saveTarget(current.copyWith(profitTarget: value));
  }

  Future<void> setOrderCountTarget(int value) async {
    final current = await _getOrCreate();
    await saveTarget(current.copyWith(orderCountTarget: value));
  }

  Future<void> addProductTarget(ProductTarget pt) async {
    final current = await _getOrCreate();
    final targets = List<ProductTarget>.from(current.productTargets)
      ..removeWhere((t) => t.productId == pt.productId)
      ..add(pt);
    await saveTarget(current.copyWith(productTargets: targets));
  }

  Future<void> removeProductTarget(int productId) async {
    final current = await _getOrCreate();
    final targets = List<ProductTarget>.from(current.productTargets)
      ..removeWhere((t) => t.productId == productId);
    await saveTarget(current.copyWith(productTargets: targets));
  }

  Future<SalesTarget> _getOrCreate() async {
    final existing = state.value;
    if (existing != null) return existing;
    final now = DateTime.now();
    return SalesTarget(year: now.year, month: now.month);
  }
}

@Riverpod(keepAlive: true)
Future<SalesTarget?> salesTargetForMonth(
  Ref ref,
  int year,
  int month,
) async {
  final isar = await ref.watch(isarProvider.future);
  return isar.salesTargets
      .filter()
      .yearEqualTo(year)
      .monthEqualTo(month)
      .findFirst();
}
