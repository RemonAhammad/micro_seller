# Flutter App — Micro Seller Inventory & Order Manager
## Claude Code Instruction Set

---

## 1. Project overview

Build a Flutter mobile app for micro sellers (Facebook/WhatsApp/Instagram resellers, home-based sellers, small stall vendors) to manage their products, orders, inventory, customers, expenses, and profit — all stored locally with Isar database and backed up to Google Drive. No REST API server. Single user, single device.

**App name:** SellerBook (or your preferred name from the analysis)
**Platform:** Android (primary), iOS (secondary)
**Target:** Google Play Store release

---

## 2. Tech stack — strict requirements

| Layer | Package | Notes |
|---|---|---|
| State management | `riverpod` + `flutter_riverpod` + `riverpod_annotation` | Use `@riverpod` annotations everywhere |
| Code generation | `build_runner` + `riverpod_generator` + `freezed` + `freezed_annotation` + `json_serializable` | Run `dart run build_runner build --delete-conflicting-outputs` |
| Local database | `isar` + `isar_flutter_libs` + `isar_generator` | All models must have `@collection` annotation |
| Google auth | `google_sign_in` | For Drive backup auth |
| Google Drive | `googleapis` + `googleapis_auth` | Drive App Data folder only |
| Navigation | `go_router` | With typed routes |
| PDF generation | `pdf` + `printing` | For receipts and reports |
| Image handling | `image_picker` + `flutter_image_compress` | Product photos |
| Utilities | `intl` + `path_provider` + `uuid` + `flutter_local_notifications` | Standard utilities |
| UI | `fl_chart` | For dashboard charts |

**Do NOT use:** GetX, Provider, BLoC, Hive, SharedPreferences for main data, or any REST API packages.

---

## 3. Project structure

Create this exact folder structure:

```
lib/
├── main.dart
├── app.dart                          # MaterialApp + ProviderScope root
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_strings.dart
│   │   └── app_sizes.dart
│   ├── theme/
│   │   └── app_theme.dart
│   ├── router/
│   │   └── app_router.dart           # go_router config
│   ├── utils/
│   │   ├── currency_formatter.dart
│   │   ├── date_formatter.dart
│   │   └── validators.dart
│   └── extensions/
│       └── context_extensions.dart
├── data/
│   ├── models/                       # Isar + Freezed models
│   │   ├── product.dart
│   │   ├── product.freezed.dart      # generated
│   │   ├── product.g.dart            # generated
│   │   ├── order.dart
│   │   ├── order.freezed.dart
│   │   ├── order.g.dart
│   │   ├── order_item.dart
│   │   ├── order_item.freezed.dart
│   │   ├── order_item.g.dart
│   │   ├── customer.dart
│   │   ├── customer.freezed.dart
│   │   ├── customer.g.dart
│   │   ├── expense.dart
│   │   ├── expense.freezed.dart
│   │   ├── expense.g.dart
│   │   ├── stock_movement.dart
│   │   ├── stock_movement.freezed.dart
│   │   └── stock_movement.g.dart
│   ├── repositories/
│   │   ├── product_repository.dart
│   │   ├── order_repository.dart
│   │   ├── customer_repository.dart
│   │   ├── expense_repository.dart
│   │   └── stock_repository.dart
│   └── services/
│       ├── isar_service.dart         # Isar DB init & singleton
│       ├── drive_service.dart        # Google Drive backup/restore
│       └── pdf_service.dart          # Receipt & report generation
├── features/
│   ├── dashboard/
│   │   ├── presentation/
│   │   │   ├── dashboard_screen.dart
│   │   │   └── widgets/
│   │   │       ├── stat_card.dart
│   │   │       ├── sales_chart.dart
│   │   │       ├── low_stock_list.dart
│   │   │       └── unpaid_orders_widget.dart
│   │   └── providers/
│   │       └── dashboard_provider.dart
│   │       └── dashboard_provider.g.dart
│   ├── products/
│   │   ├── presentation/
│   │   │   ├── product_list_screen.dart
│   │   │   ├── product_form_screen.dart
│   │   │   ├── product_detail_screen.dart
│   │   │   └── widgets/
│   │   │       ├── product_card.dart
│   │   │       └── stock_badge.dart
│   │   └── providers/
│   │       ├── product_provider.dart
│   │       └── product_provider.g.dart
│   ├── orders/
│   │   ├── presentation/
│   │   │   ├── order_list_screen.dart
│   │   │   ├── order_form_screen.dart
│   │   │   ├── order_detail_screen.dart
│   │   │   └── widgets/
│   │   │       ├── order_card.dart
│   │   │       ├── order_status_badge.dart
│   │   │       └── order_item_row.dart
│   │   └── providers/
│   │       ├── order_provider.dart
│   │       └── order_provider.g.dart
│   ├── customers/
│   │   ├── presentation/
│   │   │   ├── customer_list_screen.dart
│   │   │   ├── customer_form_screen.dart
│   │   │   ├── customer_detail_screen.dart
│   │   │   └── widgets/
│   │   │       └── customer_card.dart
│   │   └── providers/
│   │       ├── customer_provider.dart
│   │       └── customer_provider.g.dart
│   ├── inventory/
│   │   ├── presentation/
│   │   │   ├── inventory_screen.dart
│   │   │   ├── stock_adjustment_screen.dart
│   │   │   └── widgets/
│   │   │       └── stock_movement_tile.dart
│   │   └── providers/
│   │       ├── inventory_provider.dart
│   │       └── inventory_provider.g.dart
│   ├── expenses/
│   │   ├── presentation/
│   │   │   ├── expense_list_screen.dart
│   │   │   ├── expense_form_screen.dart
│   │   │   └── widgets/
│   │   │       └── expense_card.dart
│   │   └── providers/
│   │       ├── expense_provider.dart
│   │       └── expense_provider.g.dart
│   └── settings/
│       ├── presentation/
│       │   └── settings_screen.dart
│       └── providers/
│           ├── settings_provider.dart
│           └── settings_provider.g.dart
└── shared/
    └── widgets/
        ├── app_button.dart
        ├── app_text_field.dart
        ├── empty_state.dart
        ├── loading_overlay.dart
        ├── confirm_dialog.dart
        └── bottom_sheet_handle.dart
```

---

## 4. pubspec.yaml — exact dependencies

```yaml
name: sellerbook
description: Inventory and order manager for micro sellers
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Database
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  path_provider: ^2.1.4

  # Code generation helpers
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # Google auth & Drive
  google_sign_in: ^6.2.1
  googleapis: ^13.2.0
  googleapis_auth: ^1.6.0

  # Navigation
  go_router: ^14.2.7

  # PDF
  pdf: ^3.11.1
  printing: ^5.13.1

  # Image
  image_picker: ^1.1.2
  flutter_image_compress: ^2.3.0

  # UI & charts
  fl_chart: ^0.69.0

  # Utilities
  intl: ^0.19.0
  uuid: ^4.5.1
  share_plus: ^10.0.2
  url_launcher: ^6.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

  # Code generation
  build_runner: ^2.4.12
  riverpod_generator: ^2.4.3
  freezed: ^2.5.7
  isar_generator: ^3.1.0+1
  json_serializable: ^6.8.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
```

---

## 5. Data models — Isar + Freezed pattern

Use this exact pattern for every model. The model must work both as an Isar collection AND as a Freezed data class. Use embedded objects for nested data.

### Pattern: Product model

```dart
// lib/data/models/product.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar/isar.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
@Collection(ignore: {'copyWith'})
class Product with _$Product {
  const Product._();

  const factory Product({
    @Default(Isar.autoIncrement) Id id,
    required String name,
    required String sku,
    @Default('') String description,
    @Default('') String imagePath,
    required double sellingPrice,
    @Default(0.0) double costPrice,
    @Default(0) int stockQty,
    @Default(10) int lowStockThreshold,
    @Default('') String category,
    @Default([]) List<String> tags,
    @Default(true) bool isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  double get profitMargin => sellingPrice > 0
      ? ((sellingPrice - costPrice) / sellingPrice) * 100
      : 0;

  bool get isLowStock => stockQty <= lowStockThreshold;
}
```

### Models to create (same pattern):

**Order:**
- `id`, `orderNumber` (String, auto-generate "ORD-001"), `customerId` (int, nullable), `customerName` (String), `items` (List\<OrderItem\> — embedded), `subtotal`, `discountAmount`, `deliveryFee`, `totalAmount`, `amountPaid`, `paymentStatus` (enum: unpaid/partial/paid), `orderStatus` (enum: pending/confirmed/shipped/completed/cancelled), `notes`, `createdAt`, `updatedAt`

**OrderItem (Isar embedded):**
- `productId`, `productName`, `productSku`, `qty`, `unitPrice`, `totalPrice`

**Customer:**
- `id`, `name`, `phone`, `address`, `notes`, `tag` (enum: new/regular/vip), `totalOrders`, `totalSpent`, `outstandingBalance`, `createdAt`

**Expense:**
- `id`, `title`, `amount`, `category` (enum: logistics/packaging/marketing/supplies/other), `date`, `notes`, `createdAt`

**StockMovement:**
- `id`, `productId`, `productName`, `type` (enum: sale/restock/adjustment/damage), `qty` (positive = in, negative = out), `reason`, `createdAt`

---

## 6. Isar service — singleton init

```dart
// lib/data/services/isar_service.dart
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/stock_movement.dart';

part 'isar_service.g.dart';

@Riverpod(keepAlive: true)
Future<Isar> isar(IsarRef ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return await Isar.open(
    [
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
```

---

## 7. Riverpod providers — pattern to follow

Use `@riverpod` annotation everywhere. Never use `StateNotifier` directly — use `@riverpod` with `Notifier` or `AsyncNotifier`.

```dart
// lib/features/products/providers/product_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:isar/isar.dart';
import '../../../data/models/product.dart';
import '../../../data/services/isar_service.dart';

part 'product_provider.g.dart';

// Watch all products (stream — auto-updates on DB change)
@riverpod
Stream<List<Product>> products(ProductsRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.products
      .where()
      .filter()
      .isActiveEqualTo(true)
      .sortByNameDesc()
      .watch(fireImmediately: true);
}

// Watch low-stock products
@riverpod
Stream<List<Product>> lowStockProducts(LowStockProductsRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.products
      .where()
      .filter()
      .isActiveEqualTo(true)
      .and()
      .stockQtyLessThan(10) // use threshold
      .watch(fireImmediately: true);
}

// Product CRUD notifier
@riverpod
class ProductNotifier extends _$ProductNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> addProduct(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final now = DateTime.now();
      final p = product.copyWith(createdAt: now, updatedAt: now);
      await isar.writeTxn(() async => isar.products.put(p));
    });
  }

  Future<void> updateProduct(Product product) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      final p = product.copyWith(updatedAt: DateTime.now());
      await isar.writeTxn(() async => isar.products.put(p));
    });
  }

  Future<void> deleteProduct(int id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async => isar.products.delete(id));
    });
  }

  Future<void> adjustStock(int productId, int delta, String reason) async {
    final isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() async {
      final product = await isar.products.get(productId);
      if (product == null) return;
      final updated = product.copyWith(
        stockQty: product.stockQty + delta,
        updatedAt: DateTime.now(),
      );
      await isar.products.put(updated);
      await isar.stockMovements.put(StockMovement(
        productId: productId,
        productName: product.name,
        type: delta > 0 ? StockMovementType.restock : StockMovementType.adjustment,
        qty: delta,
        reason: reason,
        createdAt: DateTime.now(),
      ));
    });
  }
}
```

---

## 8. Order creation — critical business logic

When an order is confirmed, these things MUST happen in a single Isar write transaction:

1. Save the order with `orderStatus: confirmed`
2. For each `OrderItem`, deduct `qty` from the product's `stockQty`
3. For each product deducted, create a `StockMovement` record with `type: sale`
4. Update `customer.totalOrders++`, `customer.totalSpent += order.totalAmount`, `customer.outstandingBalance += order.totalAmount - order.amountPaid`

When marking order as paid:
1. Update `order.paymentStatus` and `order.amountPaid`
2. Update `customer.outstandingBalance` accordingly

---

## 9. Dashboard provider — metrics to compute

```dart
// lib/features/dashboard/providers/dashboard_provider.dart

@freezed
class DashboardStats with _$DashboardStats {
  const factory DashboardStats({
    @Default(0.0) double todayRevenue,
    @Default(0.0) double thisMonthRevenue,
    @Default(0.0) double thisMonthProfit,
    @Default(0) int totalOrders,
    @Default(0) int pendingOrders,
    @Default(0.0) double unpaidTotal,
    @Default([]) List<Product> lowStockProducts,
    @Default([]) List<DailySales> weeklySales,  // for chart
  }) = _DashboardStats;
}

@freezed
class DailySales with _$DailySales {
  const factory DailySales({
    required DateTime date,
    required double revenue,
    required double profit,
  }) = _DailySales;
}

@riverpod
Future<DashboardStats> dashboardStats(DashboardStatsRef ref) async {
  // compute all stats from Isar queries
  // return DashboardStats(...)
}
```

---

## 10. Google Drive backup service

```dart
// lib/data/services/drive_service.dart

class DriveService {
  // Scope: only App Data folder (not visible in user's Drive)
  static const _scopes = [drive.DriveApi.driveAppdataScope];

  // Export: serialize all Isar collections to JSON, zip, upload to Drive
  Future<void> backupToDriver(Isar isar) async { ... }

  // Import: download latest backup from Drive, deserialize, write to Isar
  Future<void> restoreFromDrive(Isar isar) async { ... }

  // List backups available in Drive App Data
  Future<List<DriveBackupInfo>> listBackups() async { ... }
}
```

Backup file format: a single JSON file named `sellerbook_backup_YYYYMMDD_HHmm.json` containing all collections. Store max 5 backups — delete oldest on new backup.

---

## 11. Navigation — go_router routes

```dart
// Routes to implement:
/                        → DashboardScreen
/products                → ProductListScreen
/products/add            → ProductFormScreen (add mode)
/products/:id            → ProductDetailScreen
/products/:id/edit       → ProductFormScreen (edit mode)
/orders                  → OrderListScreen
/orders/add              → OrderFormScreen
/orders/:id              → OrderDetailScreen
/customers               → CustomerListScreen
/customers/add           → CustomerFormScreen
/customers/:id           → CustomerDetailScreen
/inventory               → InventoryScreen
/inventory/adjust/:id    → StockAdjustmentScreen
/expenses                → ExpenseListScreen
/expenses/add            → ExpenseFormScreen
/settings                → SettingsScreen
```

Use a `NavigationShell` with bottom nav for: Dashboard, Products, Orders, Customers, More (Inventory / Expenses / Settings).

---

## 12. PDF receipt — structure

Generate a receipt PDF for each order with:
- Shop name + date at top
- Order number
- Customer name
- Item table: product name | qty | unit price | total
- Subtotal, discount, delivery fee, grand total
- Payment status
- "Thank you" footer

Use `share_plus` to share PDF via WhatsApp or any other app.

Also generate a **WhatsApp-friendly plain text** version:
```
📦 Order #ORD-001
📅 12 Jan 2025

Products:
• T-Shirt (L) x2 — ৳600
• Jeans x1 — ৳1,200

Subtotal: ৳1,800
Delivery: ৳60
Total: ৳1,860

Status: Unpaid
```

---

## 13. Build runner — code generation commands

After creating all model and provider files, run:

```bash
# Clean + generate all .g.dart and .freezed.dart files
dart run build_runner build --delete-conflicting-outputs

# Or watch mode during development
dart run build_runner watch --delete-conflicting-outputs
```

Every file that needs generation must have the correct `part` directives at the top:
- Models: `part 'filename.freezed.dart';` and `part 'filename.g.dart';`
- Providers: `part 'filename.g.dart';`
- Isar service: `part 'isar_service.g.dart';`

---

## 14. Theme & UI guidelines

- Use Material 3 (`useMaterial3: true`)
- Primary color: a clean teal/green (e.g. `Color(0xFF00897B)`) — conveys trust + commerce
- Use `ColorScheme.fromSeed(seedColor: ...)` for the full palette
- All monetary values display in Bangladeshi Taka (৳) by default — make currency symbol configurable in Settings
- Date format: `dd MMM yyyy` (e.g. 12 Jan 2025)
- Support both light and dark theme
- Use `Card` with rounded corners (`BorderRadius.circular(12)`) throughout
- Status badges: use colored `Container` chips (not Flutter `Chip` widget)
  - Pending: amber
  - Confirmed: blue
  - Shipped: purple
  - Completed: green
  - Cancelled: red
  - Unpaid: red
  - Partial: orange
  - Paid: green

---

## 15. Settings screen — options to implement

- Shop name (shown on receipts)
- Currency symbol (default ৳, configurable)
- Default low stock threshold
- Google account (sign in / sign out)
- Backup to Drive (manual trigger)
- Restore from Drive (pick backup file)
- Last backup time display
- App version display
- Clear all data (with confirmation dialog)

---

## 16. Error handling

- All provider methods use `AsyncValue.guard()` — never let unhandled exceptions crash the app
- Show `SnackBar` on success/error actions
- Empty states: every list screen must have a proper empty state widget with an illustration placeholder and a CTA button
- Loading states: use `AsyncValue.when()` pattern with `loading`, `data`, `error` builders

---

## 17. Build & run steps for Claude Code

Execute in this exact order:

```bash
# 1. Create Flutter project
flutter create sellerbook --org com.yourname --platforms android,ios

# 2. Replace pubspec.yaml with the one above

# 3. Get packages
flutter pub get

# 4. Create all folder structure

# 5. Create all model files with @freezed + @Collection annotations

# 6. Create all provider files with @riverpod annotations

# 7. Run code generation
dart run build_runner build --delete-conflicting-outputs

# 8. Verify no errors in generated files

# 9. Implement screens and widgets

# 10. Test on Android emulator
flutter run
```

---

## 18. Android configuration

In `android/app/src/main/AndroidManifest.xml` add:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

For Google Sign-In, add the SHA-1 fingerprint to Firebase/Google Cloud Console and download `google-services.json` into `android/app/`.

Set `minSdkVersion 21` in `android/app/build.gradle`.

---

## 19. What NOT to do

- Do NOT use `setState` anywhere — use Riverpod only
- Do NOT use `SharedPreferences` for storing business data — use Isar
- Do NOT create any REST API endpoints or HTTP calls for data (Drive API only)
- Do NOT use `Provider` package — use `flutter_riverpod` only
- Do NOT skip `part` directives — code generation will fail
- Do NOT put business logic inside widgets — it belongs in providers or repositories
- Do NOT use `late` without proper initialization guards
- Do NOT forget to run `build_runner` after any model or provider change

---

*End of instruction set. Hand this document to Claude Code and it will scaffold the full app.*