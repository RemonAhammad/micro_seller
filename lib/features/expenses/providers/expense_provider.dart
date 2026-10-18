import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/trash_entry.dart';
import '../../../data/services/isar_reload.dart';
import '../../../data/services/isar_service.dart';
import '../../../data/services/trash_service.dart';

part 'expense_provider.g.dart';

@riverpod
Stream<List<Expense>> expenses(Ref ref) async* {
  final isar = await ref.watch(isarProvider.future);
  final query = isar.expenses.where().sortByCreatedAtDesc();
  yield* reloadOn(isar.expenses.watchLazy(), query.findAll);
}

@Riverpod(keepAlive: true)
class ExpenseNotifier extends _$ExpenseNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> addExpense(Expense expense) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final now = DateTime.now();
      await isar.writeTxn(() async =>
          isar.expenses.put(expense.copyWith(createdAt: now)));
    });
  }

  Future<void> updateExpense(Expense expense) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async => isar.expenses.put(expense));
    });
  }

  /// Moves the expense to the trash instead of destroying it. Recoverable for
  /// [kTrashRetention] via the undo snackbar or Settings → Recycle Bin.
  /// Returns the trash entry id, for wiring an UNDO action. Null if the
  /// expense was already gone.
  Future<int?> deleteExpense(int id) async {
    int? trashId;
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final trash = TrashService(isar);
      await isar.writeTxn(() async {
        final expense = await isar.expenses.get(id);
        if (expense == null) return;
        trashId = await trash.capture(
          kind: TrashKind.expense,
          originalId: id,
          payload: expense.toJson(),
          label: expense.title,
          sublabel: CurrencyFormatter.format(expense.amount),
        );
        await isar.expenses.delete(id);
      });
    });
    return trashId;
  }
}
