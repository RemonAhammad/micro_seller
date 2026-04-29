# Micro Seller (SellerBook) — Project Context

A Flutter inventory & order management app for micro/small sellers. Local-first with optional Google Drive backup.

## Tech Stack

- **Flutter** (SDK >=3.8.0 <4.0.0)
- **State Management:** Riverpod 3 (`flutter_riverpod ^3.0` + `riverpod_annotation ^4.0` + `riverpod_generator ^4.0`). Note: Riverpod 3 uses plain `Ref` everywhere (no per-provider `XxxRef` typedefs), and `@riverpod class XxxNotifier` generates `xxxProvider` (no `Notifier` infix). `AsyncValue.value` is now nullable; `valueOrNull` is gone.
- **Database:** Isar 3.3 via the community fork — `isar_community` + `isar_community_flutter_libs` + `isar_community_generator` ^3.3.2. The original `isar` package was abandoned in 2023 and shipped 4 KB-aligned native binaries that Play Store rejects on Android 15+. The community fork is API-identical; storage format is byte-compatible (no on-device migration).
- **Navigation:** GoRouter with `StatefulShellRoute` (12-branch sidebar navigation)
- **Code Generation:** Freezed 3 (`freezed ^3.2.5` + `freezed_annotation ^3.1`). Note: freezed 3 requires `abstract class Foo with _$Foo` (the `abstract` keyword is mandatory). JSON serializable + isar_community schema generator.
- **PDF:** `pdf` + `printing` packages for receipt generation
- **Cloud:** Google Sign-In + Google Drive API for backup/restore
- **Charts:** fl_chart for dashboard sales visualization + reports + customer history
- **Notifications:** flutter_local_notifications for low stock & payment alerts
- **CSV:** `csv` + `file_picker` for import/export
- **Localization:** flutter_localizations + custom delegate (12 languages: en, bn, ar, es, fr, pt, tr, id, th, vi, ur, ms)
- **Persistence:** SharedPreferences for app settings
- **Env config:** `flutter_dotenv` loads `.env` at startup (OAuth client IDs, gitignored; `.env.example` is the tracked template)
- **Onboarding:** showcaseview v5 for first-time guided tour
- **In-App Update:** in_app_update for Play Store auto-update prompts
- **Other:** image_picker, mobile_scanner v6 (QR), share_plus, url_launcher, intl, package_info_plus

## Architecture

Feature-based modular structure with repository pattern:

```text
lib/
├── main.dart                     # Entry point, portrait-only, ProviderScope, currency init, notification init
├── app.dart                      # Root MaterialApp, theme (light/dark/system), GoRouter, Isar warmup, localization
├── core/
│   ├── constants/
│   │   ├── app_colors.dart       # Teal primary (#00897B), status/payment colors
│   │   ├── app_sizes.dart        # Spacing, radius, icon size tokens
│   │   └── app_strings.dart      # 100+ string constants (localization-ready)
│   ├── extensions/
│   │   └── context_extensions.dart  # Theme, snackbar, confirm dialog shortcuts
│   ├── l10n/
│   │   ├── app_localizations.dart   # Custom LocalizationsDelegate (12 locales)
│   │   ├── translations_en.dart     # English (~180 keys, source of truth) + parameterized helpers
│   │   └── translations_<bn|ar|es|fr|pt|tr|id|th|vi|ur|ms>.dart  # Same keys, translated
│   ├── router/
│   │   └── app_router.dart       # GoRouter config, 12-branch sidebar navigation shell, SafeArea wrapper
│   ├── theme/
│   │   └── app_theme.dart        # Material 3 light/dark themes, status bar matches appbar color
│   └── utils/
│       ├── currency_formatter.dart  # Format/parse/compact currency
│       ├── date_formatter.dart      # Date formatting, timeAgo, isToday etc.
│       ├── debouncer.dart           # Reusable 400ms search debouncer
│       ├── variant_utils.dart       # buildCombinationKey, buildDisplayLabel, generateCombinations (cartesian product)
│       └── validators.dart          # Form validators (required, phone, sku, costVsSelling, etc.)
├── data/
│   ├── models/
│   │   ├── category.dart         # id, name, createdAt
│   │   ├── customer.dart         # id, name, phone, address, tag(new/regular/vip), stats
│   │   ├── expense.dart          # id, title, amount, category(logistics/packaging/marketing/supplies/other), date
│   │   ├── order.dart            # id, orderNumber, customer info, items, totals, payment/order status, paymentMethod, delivery, recurring, return fields
│   │   ├── order_item.dart       # @embedded: productId, name, sku, qty, unitPrice, costPrice, totalPrice, variantCombinationKey, variantDisplayLabel
│   │   ├── product.dart          # id, name, sku, prices, stockQty, category, qrCode, isActive, variantAttributes, variantCombinations
│   │   ├── product_variant.dart  # @embedded (deprecated): flat name/value/priceAdjustment/stockQty/sku
│   │   ├── variant_attribute.dart # @embedded: name, options[] — defines one dimension (e.g. Size→[S,M,L])
│   │   ├── variant_combination.dart # @embedded: combinationKey, displayLabel, priceAdjustment, stockQty, sku, isActive
│   │   ├── supplier.dart         # id, name, phone, email, address, company, notes, totalPurchases, totalPaid, totalDue
│   │   ├── purchase.dart         # id, supplierId, supplierName, items (embedded PurchaseItem), totalAmount, amountPaid, paymentMethod, notes, referenceNumber
│   │   ├── cash_register.dart    # id, openingAmount, closingAmount, totalSales, totalExpenses, totalCashIn, totalCashOut, isClosed, openedAt, closedAt
│   │   └── stock_movement.dart   # id, productId, type(sale/restock/adjustment/damage), qty, reason
│   ├── repositories/
│   │   ├── customer_repository.dart   # CRUD, search, watchAll stream
│   │   ├── expense_repository.dart    # CRUD, date range, monthly totals
│   │   ├── order_repository.dart      # CRUD + createOrder (stock deduction, customer stats), markAsPaid
│   │   ├── product_repository.dart    # CRUD, watchLowStock, adjustStock (creates StockMovement)
│   │   └── stock_repository.dart      # CRUD, watchByProduct
│   └── services/
│       ├── csv_export_service.dart  # Export orders/products/expenses as CSV via share_plus
│       ├── csv_import_service.dart  # Import products from CSV via file_picker
│       ├── migration_service.dart  # One-time migration: flat variants → hierarchical VariantAttribute + VariantCombination
│       ├── drive_service.dart       # Google Drive backup/restore — delegates JSON to LocalBackupService (all 9 collections); typed DriveBackupException + DriveErrorCode; max 5 backups; safe restore with rollback; full error/stack logging via dart:developer
│       ├── isar_service.dart        # Riverpod provider (keepAlive), opens DB with 9 collection schemas
│       ├── local_backup_service.dart # Public encodeAll(Isar)/decodeAll(Isar,String) — single source of truth for backup JSON shape (v2). exportBackup/importBackup/exportToDirectory delegate to these. All 9 collections.
│       ├── notification_service.dart # Low stock alerts + unpaid order reminders via flutter_local_notifications
│       ├── tutorial_service.dart    # SharedPreferences flags: splash_shown, tour_completed; resetAll()
│       ├── update_service.dart      # In-app update via Play Store (immediate for critical, flexible for normal)
│       └── pdf_service.dart         # Order invoice PDF (with tax line), WhatsApp text generation. Unicode-safe: Noto Sans base + cached fallback chain (Bengali, Arabic, Urdu Nastaliq, Thai, Devanagari, zh-SC/TC, JP, KR, ColorEmoji) applied once via pw.ThemeData.withFont, so any user-typed script renders correctly without per-Text font overrides. Uses OrderItem.displayName so variant info appears in line items and WhatsApp text.
├── features/
│   ├── categories/
│   │   ├── presentation/category_screen.dart      # List + add/edit/delete dialogs
│   │   └── providers/category_provider.dart        # Stream + notifier (ensureExists)
│   ├── customers/
│   │   ├── presentation/
│   │   │   ├── customer_list_screen.dart           # Search by name/phone (debounced)
│   │   │   ├── customer_form_screen.dart           # Add/edit with tag selector
│   │   │   ├── customer_detail_screen.dart         # Stats + order history + 6-month purchase history bar chart
│   │   │   └── widgets/customer_card.dart
│   │   └── providers/customer_provider.dart        # Cascading delete (unlinks orders)
│   ├── dashboard/
│   │   ├── presentation/
│   │   │   ├── dashboard_screen.dart               # Responsive dashboard with date-range filter bar, showcaseview tour (3 steps), in-app update check
│   │   │   └── widgets/
│   │   │       ├── stat_card.dart                  # Compact card with icon, value, label
│   │   │       ├── sales_chart.dart                # SalesChart (bar), OrderStatusChart (pie), RevenueExpenseChart (line)
│   │   │       ├── low_stock_list.dart
│   │   │       └── unpaid_orders_widget.dart
│   │   └── providers/dashboard_provider.dart       # DashboardDateRange notifier + stats provider (watches date range)
│   ├── expenses/
│   │   ├── presentation/
│   │   │   ├── expense_list_screen.dart            # Month summary banner + list + CSV export button
│   │   │   ├── expense_form_screen.dart            # Date picker, category selector
│   │   │   └── widgets/expense_card.dart
│   │   └── providers/expense_provider.dart
│   ├── inventory/
│   │   ├── presentation/
│   │   │   ├── inventory_screen.dart               # 2 tabs; category filter + sort (low stock/name/qty); shows per-variant stock
│   │   │   ├── stock_adjustment_screen.dart        # Variant selector, pill-chip type selector, qty, reason; real-time stock via StreamBuilder
│   │   │   └── widgets/stock_movement_tile.dart
│   │   └── providers/inventory_provider.dart
│   ├── orders/
│   │   ├── presentation/
│   │   │   ├── order_list_screen.dart              # 5 tabs with count badges, long-press status change, CSV export
│   │   │   ├── order_form_screen.dart              # Create + Edit mode, variant-aware product picker, per-order tax/VAT field, stock validation, payment method, delivery, recurring
│   │   │   ├── order_detail_screen.dart            # Status stepper (hidden for returns), cancel order action, payment, share/print/PDF, edit, return order, delivery tracking
│   │   │   └── widgets/
│   │   │       ├── order_card.dart                 # Responsive: compact on phone, row on tablet
│   │   │       ├── order_item_row.dart             # Shows variant info via displayName
│   │   │       └── order_status_badge.dart         # Text-only badges (no icons), PaymentStatusBadge
│   │   └── providers/order_provider.dart           # Stock deduction (base + variant), rollback, customer stats, createReturnOrder, processRecurringOrders, cancel order
│   ├── products/
│   │   ├── presentation/
│   │   │   ├── product_list_screen.dart            # Search (debounced), category chips, responsive grid/list, CSV export + import
│   │   │   ├── product_form_screen.dart            # Image, QR, category, selling+cost price, hierarchical variants editor (attributes + combinations), scroll-to-top on validation fail, autofocus on new attribute
│   │   │   ├── product_detail_screen.dart          # Full info, variants card, adjust stock
│   │   │   └── widgets/
│   │   │       ├── product_card.dart
│   │   │       └── stock_badge.dart
│   │   └── providers/product_provider.dart         # Soft-delete (if in orders), negative stock prevention, variant-aware adjustStock
│   ├── reports/
│   │   ├── presentation/reports_screen.dart        # Date range picker, summary cards, top products chart, category sales, top customers
│   │   └── providers/reports_provider.dart         # Parameterized by date range, aggregates revenue/profit/expenses/rankings
│   ├── splash/
│   │   └── presentation/splash_screen.dart         # Animated 3s splash: pulsing rings, logo scale+rotate, title slide, tagline fade, loader
│   ├── returns/
│   │   └── presentation/create_return_screen.dart  # Item selector with qty controls, reason chips, refund amount (capped at amountPaid), variant display
│   ├── suppliers/
│   │   ├── presentation/
│   │   │   ├── supplier_list_screen.dart           # List with due amounts; FABs for "New Purchase" + "Add Supplier"; appbar action for "All Purchases"
│   │   │   ├── supplier_form_screen.dart           # Add/edit supplier (name, company, phone, email, address, notes)
│   │   │   ├── supplier_detail_screen.dart         # Contact info with call button, stats, purchase history (tappable), New Purchase + Pay Due actions
│   │   │   ├── purchase_list_screen.dart           # All purchases across suppliers, FAB to add
│   │   │   ├── purchase_form_screen.dart           # Optional supplier picker, product picker with unit cost, payment method, partial payment, notes
│   │   │   └── purchase_detail_screen.dart         # Items, payment summary, record payment, delete (reverses stock + supplier stats)
│   │   └── providers/supplier_provider.dart        # CRUD; createPurchase (auto-restocks + updates costPrice + supplier stats); deletePurchase (reverses); recordSupplierPayment, recordPurchasePayment
│   ├── cash_register/
│   │   ├── presentation/cash_register_screen.dart  # Open/close register, cash in/out, expected vs actual closing, history
│   │   └── providers/cash_register_provider.dart   # openRegister, closeRegister, addCashIn, addCashOut
│   └── settings/
│       ├── presentation/settings_screen.dart       # Theme toggle, language picker, currency picker (38+ currencies), shop config, tax rate, local backup export/import, Drive backup, clear data
│       └── providers/settings_provider.dart        # keepAlive, SharedPreferences: shopName, currency(৳), threshold, themeMode, taxRate, language
└── shared/
    ├── screens/qr_scanner_screen.dart
    └── widgets/
        ├── app_button.dart           # Variants: filled, outlined, text, destructive
        ├── app_text_field.dart        # With paste button
        ├── bottom_sheet_handle.dart   # AppBottomSheet.show()
        ├── confirm_dialog.dart        # ConfirmDialog.show()
        ├── drawer_menu_button.dart
        ├── empty_state.dart           # Icon + title + optional action
        └── loading_overlay.dart       # LoadingOverlay + LoadingShimmer
```

## Data Models (Isar Collections)

All models have: `Id id`, `DateTime? createdAt`, `copyWith()`, `toJson()`/`fromJson()`.

| Model                  | Key Fields                                                                                                                                                                                                                                                                                                                                                       | Computed Props                                                                        |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Product**            | name, sku, sellingPrice, costPrice, stockQty, lowStockThreshold, category, qrCode, isActive, **variantAttributes** (embedded list), **variantCombinations** (embedded list), **supplierId** (optional, 0 = none)                                                                                                                                                 | profitMargin, isLowStock, isOutOfStock, hasVariants, totalStock, findCombination(key) |
| **VariantAttribute**   | @embedded: name, options[] — one dimension of variation (e.g. Size→[S,M,L])                                                                                                                                                                                                                                                                                      | —                                                                                     |
| **VariantCombination** | @embedded: combinationKey (canonical sorted "Color:Red/Size:L"), displayLabel, priceAdjustment, stockQty, sku, isActive                                                                                                                                                                                                                                          | —                                                                                     |
| **Order**              | orderNumber, customerId/Name/Phone, items (embedded), subtotal, discountAmount, deliveryFee, **taxAmount**, totalAmount, amountPaid, paymentStatus, **paymentMethod**, orderStatus, **deliveryAddress**, **estimatedDeliveryDate**, **actualDeliveryDate**, **isReturn**, **originalOrderId**, **isRecurring**, **recurringIntervalDays**, **nextRecurringDate** | balanceDue, isFullyPaid, totalItems                                                   |
| **OrderItem**          | @embedded: productId, productName, productSku, qty, unitPrice, **costPrice**, totalPrice, **variantCombinationKey**, **variantDisplayLabel**                                                                                                                                                                                                                     | hasVariant, displayName                                                               |
| **Customer**           | name, phone, address, notes, tag (new/regular/vip), totalOrders, totalSpent, outstandingBalance                                                                                                                                                                                                                                                                  | hasOutstanding                                                                        |
| **Expense**            | title, amount, category (logistics/packaging/marketing/supplies/other), date, notes                                                                                                                                                                                                                                                                              | —                                                                                     |
| **StockMovement**      | productId, productName, type (sale/restock/adjustment/damage), qty, reason                                                                                                                                                                                                                                                                                       | isIncoming                                                                            |
| **Category**           | name                                                                                                                                                                                                                                                                                                                                                             | —                                                                                     |
| **Supplier**           | name, phone, email, address, company, notes, totalPurchases, totalPaid, totalDue                                                                                                                                                                                                                                                                                 | hasOutstanding                                                                        |
| **Purchase**           | supplierId, supplierName, items (embedded PurchaseItem), totalAmount, amountPaid, paymentMethod, notes, referenceNumber                                                                                                                                                                                                                                          | balanceDue, isFullyPaid, totalItems                                                   |
| **PurchaseItem**       | @embedded: productId, productName, qty, unitCost, totalCost                                                                                                                                                                                                                                                                                                      | —                                                                                     |
| **CashRegister**       | openingAmount, closingAmount, totalSales, totalExpenses, totalCashIn, totalCashOut, isClosed, openedAt, closedAt                                                                                                                                                                                                                                                 | expectedClosing, difference                                                           |

## Order Form UX (order_form_screen.dart)

The order creation/edit screen is designed for fast, frictionless use:

- **Create + Edit modes:** Accepts optional `order` or `orderId` param. Edit mode pre-populates all fields, uses `updateOrder` on submit.

- **Customer picker (bottom sheet):**
  - Search by name or phone with autofocus
  - Select existing customer from filtered list
  - **Always-visible "Create New Customer" button** at top of the sheet
    - Tapping opens an inline form (Name, Phone, Address) within the same sheet
    - Pre-fills from search query (digits → phone field, text → name field)
    - "Add & Select" saves to Isar and returns as selected customer
    - Back arrow returns to search/list view
  - Selected customer shows with an X button to clear
  - **Customer is required** — validation prevents creating order without one

- **Product picker (bottom sheet, stays open for multi-add):**
  - **Real-time stock** via Isar `StreamBuilder` (not a stale snapshot)
  - Search by name or SKU
  - **Hierarchical variant support:** Products with variant combinations show expand/collapse; each combination (e.g. "Size: L / Color: Red") has its own price, stock, and add/qty controls
  - **Unconfigured combinations hidden** — combos with no stock, no price, and no SKU are not shown
  - Inline +/- qty controls per product/combination (no close-reopen cycle)
  - **Stock validation:** + button disabled when qty reaches available stock; qty clamped to stock limit
  - Out-of-stock combinations shown as disabled with "Out of stock" label
  - Products with no configured combos are hidden entirely
  - Item count badge, "Done" button to close
  - Changes are pushed to parent via `onChanged` callback in real time

- **Item list (main screen):**
  - Each item has +/- qty buttons and an X delete button (no hidden swipe)
  - **Stock validation on increment** — checks current stock from Isar, shows snackbar if exceeded
  - Shows variant info via `displayName` (e.g. "T-Shirt (Size: Large)")
  - Item count badge in section header
  - Tapping empty state opens product picker

- **Pricing:**
  - Discount + delivery fee fields
  - **Per-order Tax/VAT (%) field** — defaults from settings tax rate, editable per order
  - Tax auto-calculated: `(subtotal - discount) * taxRate / 100`, shown as helper text
  - Amount paid field with "Pay Full" quick button (fills total)

- **Payment method:** ChoiceChips (Cash / Card / bKash / Nagad / Bank / Other)

- **Order status:** ChoiceChips (Pending / Confirmed) — not a dropdown

- **Delivery section:** Delivery address text field + estimated delivery date picker

- **Recurring toggle:** Switch + interval days input

- **Sticky footer:** Live subtotal/discount/tax/delivery/total summary + "Create Order" / "Update Order" button

- **Post-creation invoice sheet:** After a *new* order is saved, an `AppBottomSheet` opens titled "Order created · {orderNumber}" with four tappable action tiles before the form pops:
  - **Share PDF** — generates the invoice and opens the system share sheet
  - **Download PDF** — saves to the user's chosen download directory (asked once, persisted in settings); snackbar with "Share" action confirms the path
  - **Print** — opens the system print dialog via `Printing.layoutPdf`
  - **Share via WhatsApp** — sends the formatted text version
  - **Done** dismisses; the form then pops back to the order list
  Edit-mode is unchanged (still pops directly).

## Key Business Flows

### Order Creation (transactional)

1. Customer is required (validated in form)
2. Save order to DB — each OrderItem stores `costPrice` from the product at time of order (frozen for accurate profit)
3. OrderItem stores `variantName`/`variantValue` if a variant was selected
4. Tax amount is calculated from the per-order tax rate field and stored on the order
5. If status == confirmed: deduct stock per item (**both base `stockQty` and variant `stockQty`**) + create StockMovement records
6. If customerId > 0: update customer totalOrders, totalSpent, outstandingBalance
7. `createOrder` returns `Future<int>` (the new order's Isar id) so the form can hand the saved order to the post-creation invoice sheet without a follow-up query

### Order Editing

1. Load existing order by ID into the form
2. Pre-populate all fields (customer, items, pricing, tax rate, status, payment method, delivery, recurring)
3. On submit, update order preserving original id, orderNumber, createdAt

### Order Status Change (rollbackable)

- **Forward** (pending → confirmed/shipped/completed): deducts stock (base + variant), creates sale StockMovements
- **Rollback** (confirmed/shipped/completed → pending/cancelled): **restores stock** (base + variant), creates adjustment StockMovements with "Rollback" reason
- **Cancel:** Available from any non-cancelled state via popup menu on order detail screen
- Logic: pending/cancelled = stock not deducted; confirmed/shipped/completed = stock deducted
- Long-press any order card in the list to change status via popup menu

### Order Deletion (safe)

- **Restores stock** (base + variant) if order was confirmed/shipped/completed (creates adjustment StockMovements)
- **Reverses customer stats** (totalOrders, totalSpent, outstandingBalance)
- Then deletes the order

### Return Orders

1. "Create Return" action from order detail screen (hidden for return orders themselves)
2. Create return screen shows items with variant info via `displayName`, qty selector, reason chips
3. **Refund amount capped at `amountPaid`** on original order (validation + auto-fill cap)
4. Refund of 0 allowed (e.g. exchange)
5. Creates a new order with `RET-XXX` numbering, `isReturn: true`, linked via `originalOrderId`
6. Return detail screen shows only the 3-step return flow (Requested → Received → Refunded), **not** the regular order status stepper
7. On approve: **restores stock** (base + variant) for all items via restock StockMovements
8. **Updates customer stats** (decrements totalSpent)

### Recurring Orders

1. Toggle in order form sets `isRecurring`, `recurringIntervalDays`, `nextRecurringDate`
2. `processRecurringOrders()` checks for due recurring orders and auto-creates new pending copies

### Delivery Tracking

1. Delivery address and estimated delivery date set in order form
2. Order detail shows delivery tracking card with "Mark as Delivered" button
3. Marking delivered sets `actualDeliveryDate` and status to completed

### Profit Calculation

- `profit = (unitPrice - costPrice) × qty` per order item
- Uses `costPrice` stored on OrderItem (frozen at order time); falls back to product lookup for old orders without it
- Dashboard shows: filtered profit, weekly profit chart, revenue vs expenses line chart

### Payment Recording (transactional)

1. Update order.amountPaid, determine paymentStatus (paid/partial)
2. Update customer.outstandingBalance -= payment

### Stock Adjustment (transactional, combination-aware)

1. Update product.stockQty += delta (**clamped to 0 minimum**)
2. If `combinationKey` specified: also update the matching `VariantCombination.stockQty`
3. Create StockMovement record with type and reason (includes combination displayLabel in productName)
4. Stock adjustment screen shows **combination selector** (choice chips) for products with variants
5. Stock values shown via `StreamBuilder` for real-time updates

### Product Detail Screen

- Shows full product info including **variants card** with per-combination stock, price adjustment, and SKU
- Adjust stock button links to inventory adjustment screen

### Hierarchical Variant System

Products support **multi-attribute variant combinations**:

1. **VariantAttributes** define dimensions: e.g. Size→[S,M,L], Color→[Red,Blue]
2. **VariantCombinations** are the cartesian product: "Size: S / Color: Red", "Size: S / Color: Blue", etc.
3. Each combination has its own `stockQty`, `priceAdjustment`, `sku`, and `isActive` flag
4. Combinations are identified by a canonical `combinationKey` (sorted alphabetically: "Color:Red/Size:L")
5. **Product form** has a two-step editor: define attributes+options, then auto-generated combination table with bulk actions
6. **Limits:** max 3 attributes, max 15 options each
7. **Migration:** Old flat `ProductVariant` data is auto-migrated to single-attribute combinations on first launch
8. **OrderItem** stores `variantCombinationKey` + `variantDisplayLabel` (denormalized for display)
9. All stock operations (order create/status/delete, return, manual adjustment) use `combinationKey` for per-combination stock tracking

### Product Deletion (safe)

- If product is referenced in any order: **soft-delete** (sets isActive=false)
- If not referenced: hard-delete + cleans up stock movements

### Customer Deletion (safe)

- **Unlinks orders** (sets customerId=0 on related orders, preserving order data)
- Then deletes the customer

### Backup/Restore (Google Drive, safe)

- Exports **all 9 collections** as timestamped JSON to Drive appDataFolder (uses `LocalBackupService.encodeAll`)
- Keeps max 5 backups, cleans up old ones (cleanup failure doesn't break upload)
- **Safe restore:** creates local safety backup before clearing → if import fails, rolls back to safety backup
- Validates backup structure (`version`, `timestamp`) before touching local data
- **Typed errors:** `DriveBackupException` with `DriveErrorCode` (`notSignedIn`, `signInFailed`, `developerError` for ApiException 10, `network`, `invalidBackup`, `uploadFailed`, `downloadFailed`, `restoreFailed`, `rolledBack`). UI switches on the code instead of substring-matching messages.
- **Logging:** every failure logs the error + stack via `dart:developer` and `debugPrintStack` in debug builds.
- **OAuth scope:** `drive.appdata` — backups live in a hidden app-data folder; not visible at drive.google.com.
- **OAuth client IDs** are stored in `.env` (gitignored) for documentation. Note: Android `google_sign_in` does NOT read these at runtime — it matches the running APK's package + signing-cert SHA-1 against the Cloud project automatically. The `.env` becomes functional once iOS/web client IDs are wired into `GoogleSignIn(clientId: ...)`.

### CSV Export

- Export orders, products, or expenses as CSV files via share_plus
- Export buttons available in all three list screens

### Bulk Product Import

- Pick CSV file via file_picker (expected columns: Name, SKU, Category, Selling Price, Cost Price, Stock, Threshold)
- Parse with validation and error reporting
- Confirmation dialog shows count + any skipped rows before importing

### Notifications

- **Low stock alerts:** triggered when products fall below threshold
- **Payment reminders:** triggered for unpaid orders
- Checked automatically on dashboard load

### Supplier Management

- **Supplier directory** with name, company, phone (with call button), email, address, notes
- **Optional supplier:** purchases can be recorded with no supplier linked (e.g. one-off cash buys)
- **Product → Supplier link (optional):** products have an optional `supplierId` to mark their primary supplier
- **Product form** has an optional supplier picker (below the Category field)
- **Supplier detail** shows a "Products from this supplier" section with linked products (tappable to view product detail)
- **Purchase history:** supplier detail screen shows full purchase history (tappable to view detail)
- **Supplier stats:** totalPurchases, totalPaid, totalDue tracked automatically when supplier is linked
- **Payment tracking:** record direct payments to suppliers (reduces their outstanding due)
- **Safe deletion:** deleting a supplier unlinks purchases AND products (sets their `supplierId` to 0, preserves all data)

### Purchase Recording (transactional)

1. **Entry points:** "New Purchase" FAB on supplier list, "+ New Purchase" on supplier detail, or all-purchases list FAB
2. **Optional supplier picker** at top of form (can be skipped for one-off buys)
3. **Product picker** with real-time stock and current cost price; tap to add, +/- to adjust qty. When a supplier is selected, a filter chip lets you toggle between "{Supplier} only" and "All products" to quickly find that supplier's items
4. **Per-item unit cost** field — defaults to product's existing costPrice
5. **Payment:** amount paid (with "Pay Full" quick button), payment method chips (Cash/Card/bKash/Nagad/Bank/Other), reference number, notes
6. **On save:**
   - Stock auto-restocks for each item
   - Product `costPrice` is updated to the new unit cost (so future profit margins are accurate)
   - StockMovement records created with "Purchase from {supplier}" or "Purchase" reason
   - If supplier linked: their `totalPurchases`, `totalPaid`, `totalDue` are updated
7. **Record payment** action on purchase detail reduces both purchase and supplier dues
8. **Delete purchase** reverses everything: deducts stock back, decrements supplier stats

### Daily Cash Register

- **Open register:** set opening cash amount to start the day
- **Cash in/out:** record cash inflows (e.g. sales) and outflows (e.g. supplier payments, petty cash) during the day
- **Expected closing:** auto-calculated as `opening + cashIn - cashOut`
- **Close register:** enter actual closing amount, system shows difference (over/short)
- **Auto-close:** opening a new register auto-closes any existing open register
- **History:** view past register sessions with opening, closing, cash flow, and differences

### Order Detail UX

- **Call button** next to customer phone number — taps to open dialer

### Splash Screen

- **3-second animated sequence** with teal gradient background
- Staggered reveals: pulsing rings → logo icon (scale + rotate with elastic overshoot) → "Micro Seller" title slides up → tagline pill fades in → circular loader appears
- Auto-navigates to dashboard after animation completes
- Uses GoRouter `go('/')` for clean transition

### First-Time Showcase Tour

- **3 highlight steps** on the dashboard (first-time users only):
  1. Date Range Filter — explains filtering by Today/Week/Month/Custom
  2. Business Stats — overview of revenue, profit, orders, expenses
  3. Charts & Insights — visual breakdown of trends
- Uses `ShowcaseView.register()` (showcaseview v5+ API)
- Auto-starts 1.2s after dashboard loads (lets data settle)
- One-time only — flagged via SharedPreferences (`tour_completed`)
- Dismissing or completing marks it as done
- `TutorialService.resetAll()` available for future "Replay Tour" in settings

### In-App Update (Play Store)

- Checks for Play Store updates when dashboard loads
- **Immediate update** forced for critical versions (priority >= 4)
- **Flexible update** for normal versions (downloads in background, prompts to install)
- Silent failure — never disrupts user if check fails
- Android-only (skips on other platforms)

### Local Backup Export/Import

- **Export:** Saves all 9 collections as a timestamped JSON file via share sheet
- **Import:** Pick a `.json` file, confirm with destructive warning, replaces all data
- Available in Settings → Local Backup section
- Complements Google Drive backup (works offline, shareable via any app)

### Currency System

- **38+ currencies** with searchable picker in Settings (symbol, name, code)
- `CurrencyFormatter.setSymbol()` called in `main.dart` before app renders (from SharedPreferences)
- Also called on every currency change in settings
- All screens use `CurrencyFormatter.format()` which reads the static symbol — no hardcoded currency symbols in runtime code
- `CurrencyFormatter.symbol` getter for accessing the current symbol directly
- PDF receipts and WhatsApp text also use the dynamic symbol

## Navigation (GoRouter)

Initial route is `/splash` (animated splash screen), then navigates to `/` (dashboard shell). 12 branches via `StatefulShellRoute` with a responsive sidebar (icon-only <600px, expanded with labels >=600px). Tooltips on icons when collapsed. Wrapped in `SafeArea`.

| Route         | Path             | Sub-routes                                                                                  |
| ------------- | ---------------- | ------------------------------------------------------------------------------------------- |
| Splash        | `/splash`        | — (initial route, auto-navigates to `/`)                                                    |
| Dashboard     | `/`              | —                                                                                           |
| Products      | `/products`      | `add`, `:id`, `:id/edit`                                                                    |
| Orders        | `/orders`        | `add`, `:id`, `:id/edit`                                                                    |
| Returns       | `/returns`       | `:id`                                                                                       |
| Customers     | `/customers`     | `add`, `:id`, `:id/edit`                                                                    |
| Inventory     | `/inventory`     | `adjust/:id`                                                                                |
| Suppliers     | `/suppliers`     | `add`, `:id`, `:id/edit`, `:id/purchase/add`, `purchases`, `purchases/add`, `purchases/:id` |
| Expenses      | `/expenses`      | `add`, `:id/edit`                                                                           |
| Cash Register | `/cash-register` | —                                                                                           |
| Categories    | `/categories`    | —                                                                                           |
| Reports       | `/reports`       | —                                                                                           |
| Settings      | `/settings`      | —                                                                                           |

## State Management Pattern

- **Stream providers** for reactive lists (products, orders, customers, etc.)
- **Notifier classes** for mutations (add, update, delete, complex transactions)
- **AsyncValue.guard()** for error handling
- **Isar watch(fireImmediately: true)** for real-time UI updates
- **StreamBuilder** for real-time stock in product picker and stock adjustment screens
- **Freezed** for immutable dashboard stats (DailySales, DashboardStats)
- **DashboardDateRange notifier** for date filter state (Today/This Week/This Month/Custom)
- **Settings provider** (keepAlive, SharedPreferences): shopName, currencySymbol (৳), lowStockThreshold, themeMode, taxRate, language, lastBackupTime

## UI Design

- Material 3, teal primary (#00897B), light/dark theme support with **user-selectable toggle** (Light/Dark/System)
- **Dark scaffold:** `Colors.blueGrey.shade900` (#263238); light scaffold: `#F8F9FA`
- **Status bar** color matches appbar (white in light theme, blueGrey.shade900 in dark theme)
- **Language:** 12 languages with in-app language switcher (English, Bengali, Arabic, Spanish, French, Portuguese, Turkish, Indonesian, Thai, Vietnamese, Urdu, Malay)
- **Responsive sidebar navigation**: icon-only rail (56px) on phones (<600px), expanded with labels (200px) on tablet/desktop (>=600px). Tooltips on collapsed icons. Wrapped in SafeArea.
- **Responsive layouts throughout**:
  - Dashboard: stat cards via `Wrap` + `LayoutBuilder` (2-6 cols based on `width/170`); charts side-by-side on wide screens; date-range filter bar
  - Product grid: responsive columns via `LayoutBuilder` (`width/180`, clamp 2-6)
  - Order card: compact column on phone, single-row layout on tablet (>=600px)
  - Inventory: category filter + sort dropdown bar; **per-variant stock display**
- **Dashboard charts**: Weekly sales bar chart, order status pie chart, revenue vs expenses line chart
- **Dashboard SliverAppBar**: `title:` ("Micro Seller") always shown; `expandedHeight: 160`; `flexibleSpace` holds greeting + date pill + today's revenue/total-orders stats with top padding `kToolbarHeight + 8` so content sits below the toolbar layer. Title remains visible when collapsed.
- **Reports screen**: Date range picker, summary stat cards, top products bar chart, category sales, top customers ranking
- **Reports SliverAppBar**: `title:` ("Reports") always shown; `expandedHeight: 120`; `flexibleSpace` holds the start/end date chips with same `kToolbarHeight + 8` top padding pattern.
- **Customer detail chart**: 6-month purchase history bar chart
- **FABs**: Icon-only `+` with tooltip, rounded-square shape (16px radius)
- Cards with 14px radius, subtle shadows
- Color-coded text-only status badges (no icons in badges)
- Shimmer loading, empty states, confirm dialogs
- All number inputs have `inputFormatters` (digits, decimal, or phone pattern)
- Currency: Bangladeshi Taka (৳) by default
- **Search debouncing** (400ms) on product and customer list screens
- **User-friendly error messages** in all form screens (no raw exceptions)
- **Localization-first**: visible UI strings go through `AppStrings.of(context).<getter>` or `AppLocalizations.tr(key)`. Parameterized strings use `{count}`/`{stock}`/`{item}` placeholders resolved by helper methods on `_L10nStrings` (e.g. `productsFoundToImport(int)`, `notEnoughStock(int, String)`, `rowsSkipped(int)`, `andMore(int)`).

## Code Generation

Run after model/provider changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generates: `.g.dart` (Isar schemas, JSON, Riverpod providers), `.freezed.dart` (dashboard stats)

**All Isar imports use `package:isar_community/isar.dart`** — never `package:isar/isar.dart`. The `isar_community_generator` produces the same `.g.dart` shape as the abandoned `isar_generator` ever did, so existing schemas, queries, and `IsarCollection<T>` extensions still work unchanged.

## Build & Release

### Android Release Config

- **App label:** `Micro Seller` (with space — in `AndroidManifest.xml` `android:label`)
- **Application ID:** `com.blackshadowsoftware.micro_seller`
- **Kotlin source path:** `android/app/src/main/kotlin/com/blackshadowsoftware/micro_seller/MainActivity.kt` — must match the `package` declaration. (A previous package rename left the file at `…/blackshadowsoftwareltd/…`; the release Kotlin compiler refuses that mismatch with "Unresolved reference 'embedding'".)
- **Keystore:** Shared upload keystore at `/Users/remon/Documents/upload-keystore.jks` (same as Fuel Cost app)
- **Signing:** `android/key.properties` → read by `build.gradle.kts` → `signingConfigs.release`
- **R8/ProGuard:** enabled (`isMinifyEnabled = true`, `isShrinkResources = true`) with rules in `android/app/proguard-rules.pro`
- **Core library desugaring:** enabled for `flutter_local_notifications`
- **NDK version:** `27.0.12077973`
- **16 KB page size compliance:** Every `.so` in the AAB must use ELF program-header alignment ≥ `0x4000` (16 KB) so it can be `mmap`'d on Android 15 devices that run with 16 KB pages. Verified at build time with `llvm-readelf -lW` looking at the first `LOAD` segment's alignment. The legacy `isar_flutter_libs` 3.1.0+1 shipped a 4 KB-aligned `libisar.so` and was the sole blocker; switching to `isar_community_flutter_libs` resolved it. Together with NDK 27 + `useLegacyPackaging = false`, all 7 arm64 libs in the AAB are now ≥ 16 KB aligned.
- **Subprojects fixes** (in root `android/build.gradle.kts`, applied via `afterEvaluate` for any `com.android.library` plugin):
  1. Forces `compileSdk = 35` on plugins that hardcode older versions (resolves `android:attr/lStar not found`).
  2. Injects `namespace` from each plugin's `AndroidManifest.xml` `package` attribute when missing — required by AGP 8+. (Originally added to fix `isar_flutter_libs` 3.1.0+1; still useful for any other plugin relying on the deprecated manifest `package` attribute.)
- **Launcher icon:** Generated via `flutter_launcher_icons` from `assets/icons/app_icon.png`, named `launcher_icon`
- **Predictive back:** `android:enableOnBackInvokedCallback="true"` in manifest

### iOS Config

- **Minimum iOS version:** 16.0 (set in `ios/Podfile`)

### Build Commands

```bash
# Debug
flutter run

# Release APK (for testing)
flutter build apk --release

# Release AAB (for Play Store upload) — preferred form
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/debug-info --tree-shake-icons
# Output: build/app/outputs/bundle/release/app-release.aab

# Verify 16 KB alignment of every native library in the AAB
LREAD=$ANDROID_HOME/ndk/27.0.12077973/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf
cd build/app/intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib/arm64-v8a
for f in *.so; do
  align=$("$LREAD" -lW "$f" | awk '/^  LOAD/ {print $NF; exit}')
  printf "%-35s %s\n" "$f" "$align"   # want 0x4000 or 0x10000 for every row
done

# Generate launcher icons (after placing icon in assets/icons/app_icon.png)
dart run flutter_launcher_icons
```

See [RELEASE.md](RELEASE.md) for the full Play Store publishing guide.

## Platform Support

Android, iOS (min 16.0), Web, macOS, Linux, Windows.
