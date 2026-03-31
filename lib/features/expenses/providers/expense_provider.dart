import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/models/expense.dart';
import '../../../data/services/isar_service.dart';

part 'expense_provider.g.dart';

@riverpod
Stream<List<Expense>> expenses(ExpensesRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.expenses
      .where()
      .sortByDateDesc()
      .watch(fireImmediately: true);
}

@riverpod
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

  Future<void> deleteExpense(int id) async {
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async => isar.expenses.delete(id));
    });
  }
}
