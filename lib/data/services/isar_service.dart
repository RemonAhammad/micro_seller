import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';

part 'isar_service.g.dart';

@Riverpod(keepAlive: true)
Future<Isar> isar(IsarRef ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return await Isar.open(
    [
      CategorySchema,
      ProductSchema,
      OrderSchema,
      CustomerSchema,
      ExpenseSchema,
      StockMovementSchema,
    ],
    directory: dir.path,
    name: 'sellerbook_db',
  );
}
