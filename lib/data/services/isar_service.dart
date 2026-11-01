import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/cash_register.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/stock_movement.dart';
import '../models/supplier.dart';
import '../models/trash_entry.dart';
import 'dues_service.dart';
import 'migration_service.dart';
import 'product_image_store.dart';

part 'isar_service.g.dart';

const kIsarSchemas = [
  CategorySchema,
  ProductSchema,
  OrderSchema,
  CustomerSchema,
  ExpenseSchema,
  StockMovementSchema,
  SupplierSchema,
  PurchaseSchema,
  CashRegisterSchema,
  TrashEntrySchema,
  PaymentSchema,
];

@Riverpod(keepAlive: true)
Future<Isar> isar(Ref ref) async {
  final dir = await getApplicationDocumentsDirectory();

  ProductImageStore.documentsDirectory = dir.path;
  final db = await Isar.open(
    kIsarSchemas,
    directory: dir.path,
    name: 'sellerbook_db',

    compactOnLaunch: const CompactCondition(
      minFileSize: 20 * 1024 * 1024,
      minRatio: 2.0,
    ),
  );

  await migrateVariantsV2(db);
  await migrateOutstandingBalancesV1(db);
  await migrateProductImagePathsV1(db);

  return db;
}
