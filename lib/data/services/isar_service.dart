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

part 'isar_service.g.dart';

/// Every collection in the database. Shared by the app and the background
/// auto-backup worker ([autoBackupCallbackDispatcher]), which opens the same
/// file from its own isolate — both must pass the identical list, or the
/// worker's open would see a schema missing collections the app has written.
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
  final db = await Isar.open(
    kIsarSchemas,
    directory: dir.path,
    name: 'sellerbook_db',
    // Rewrites the file only when it is mostly free space (e.g. after a big
    // restore or Clear All Data), so reads stay compact; a no-op otherwise.
    compactOnLaunch: const CompactCondition(
      minFileSize: 20 * 1024 * 1024,
      minRatio: 2.0,
    ),
  );

  // Run one-time migrations
  await migrateVariantsV2(db);
  await migrateOutstandingBalancesV1(db);

  return db;
}
