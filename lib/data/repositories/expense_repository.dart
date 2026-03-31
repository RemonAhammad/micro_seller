import 'package:isar/isar.dart';
import '../models/expense.dart';

class ExpenseRepository {
  final Isar _isar;
  ExpenseRepository(this._isar);

  Stream<List<Expense>> watchAll() {
    return _isar.expenses
        .where()
        .sortByDateDesc()
        .watch(fireImmediately: true);
  }

  Future<List<Expense>> getAll() =>
      _isar.expenses.where().sortByDateDesc().findAll();

  Future<List<Expense>> getByDateRange(DateTime from, DateTime to) =>
      _isar.expenses
          .filter()
          .dateBetween(from, to)
          .sortByDateDesc()
          .findAll();

  Future<double> getTotalByMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final expenses = await getByDateRange(start, end);
    return expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  Future<void> save(Expense expense) async {
    await _isar.writeTxn(() => _isar.expenses.put(expense));
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.expenses.delete(id));
  }
}
