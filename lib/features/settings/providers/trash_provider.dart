import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/trash_entry.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/trash_service.dart';

part 'trash_provider.g.dart';

@Riverpod(keepAlive: true)
Future<TrashService> trashService(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  return TrashService(isar);
}

/// Live contents of the recycle bin, newest first.
@riverpod
Stream<List<TrashEntry>> trashEntries(Ref ref) async* {
  final service = await ref.watch(trashServiceProvider.future);
  yield* service.watchAll();
}

/// keepAlive per the project rule: a `ref.read(...).restore()` from a screen
/// would otherwise dispose this provider mid-await and the post-await
/// `state = ...` would throw UnmountedRefException.
@Riverpod(keepAlive: true)
class TrashNotifier extends _$TrashNotifier {
  @override
  FutureOr<void> build() {}

  /// Puts a trashed record back. Returns false if the entry is already gone.
  Future<bool> restore(int trashId) async {
    var restored = false;
    state = await AsyncValue.guard(() async {
      final service = await ref.read(trashServiceProvider.future);
      restored = await service.restore(trashId);
    });
    return restored;
  }

  Future<void> deleteForever(int trashId) async {
    state = await AsyncValue.guard(() async {
      final service = await ref.read(trashServiceProvider.future);
      await service.deleteForever(trashId);
    });
  }

  Future<void> clearAll() async {
    state = await AsyncValue.guard(() async {
      final service = await ref.read(trashServiceProvider.future);
      await service.clearAll();
    });
  }
}
