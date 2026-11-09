import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/promotion.dart';
import '../../../data/services/isar_service.dart';

part 'promotion_provider.g.dart';

@Riverpod(keepAlive: true)
class PromotionNotifier extends _$PromotionNotifier {
  @override
  Future<List<Promotion>> build() async {
    final isar = await ref.watch(isarProvider.future);
    return isar.promotions.where().sortByCreatedAtDesc().findAll();
  }

  Future<void> save(Promotion promo) async {
    final isar = await ref.read(isarProvider.future);
    final now = DateTime.now();
    final toSave = promo.copyWith(
      createdAt: promo.createdAt ?? now,
      updatedAt: now,
    );
    await isar.writeTxn(() => isar.promotions.put(toSave));
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() => isar.promotions.delete(id));
    ref.invalidateSelf();
  }
}
