import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/cash_register.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/stock_movement.dart';
import '../models/supplier.dart';
import 'migration_service.dart';

part 'isar_service.g.dart';

@Riverpod(keepAlive: true)
Future<Isar> isar(Ref ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final db = await Isar.open(
    [
      CategorySchema,
      ProductSchema,
      OrderSchema,
      CustomerSchema,
      ExpenseSchema,
      StockMovementSchema,
      SupplierSchema,
      PurchaseSchema,
      CashRegisterSchema,
    ],
    directory: dir.path,
    name: 'sellerbook_db',
  );

  // Run one-time migrations
  await migrateVariantsV2(db);

  return db;
}
