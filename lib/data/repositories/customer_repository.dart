import 'package:isar_community/isar.dart';
import '../models/customer.dart';

class CustomerRepository {
  final Isar _isar;
  CustomerRepository(this._isar);

  Stream<List<Customer>> watchAll() {
    return _isar.customers
        .where()
        .sortByName()
        .watch(fireImmediately: true);
  }

  Future<List<Customer>> getAll() =>
      _isar.customers.where().sortByName().findAll();

  Future<Customer?> getById(int id) => _isar.customers.get(id);

  Future<List<Customer>> search(String query) => _isar.customers
      .filter()
      .nameContains(query, caseSensitive: false)
      .or()
      .phoneContains(query)
      .findAll();

  Future<void> save(Customer customer) async {
    await _isar.writeTxn(() => _isar.customers.put(customer));
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.customers.delete(id));
  }
}
