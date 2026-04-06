# MicroSeller (SellerBook) — Project Context

A Flutter inventory & order management app for micro/small sellers. Local-first with optional Google Drive backup.

## Tech Stack

- **Flutter** (SDK >=3.5.0 <4.0.0)
- **State Management:** Riverpod (`flutter_riverpod` + `riverpod_annotation` + code generation)
- **Database:** Isar 3.1 (embedded NoSQL, local-first)
- **Navigation:** GoRouter with `StatefulShellRoute` (10-branch sidebar navigation)
- **Code Generation:** Freezed (immutable classes), JSON serializable, Isar schema generator
- **PDF:** `pdf` + `printing` packages for receipt generation
- **Cloud:** Google Sign-In + Google Drive API for backup/restore
- **Charts:** fl_chart for dashboard sales visualization + reports + customer history
- **Notifications:** flutter_local_notifications for low stock & payment alerts
- **CSV:** `csv` + `file_picker` for import/export
- **Localization:** flutter_localizations + custom delegate (English + Bengali)
- **Persistence:** SharedPreferences for app settings
- **Other:** image_picker, mobile_scanner v6 (QR), share_plus, url_launcher, intl

## Architecture

Feature-based modular structure with repository pattern:

```text
lib/
├── main.dart                     # Entry point, portrait-only, ProviderScope, notification init
├── app.dart                      # Root MaterialApp, theme (light/dark/system), GoRouter, Isar warmup, localization
├── core/
│   ├── constants/
│   │   ├── app_colors.dart       # Teal primary (#00897B), status/payment colors
│   │   ├── app_sizes.dart        # Spacing, radius, icon size tokens
│   │   └── app_strings.dart      # 100+ string constants (localization-ready)
│   ├── extensions/
│   │   └── context_extensions.dart  # Theme, snackbar, confirm dialog shortcuts
│   ├── l10n/
│   │   ├── app_localizations.dart   # Custom LocalizationsDelegate (en, bn)
│   │   ├── translations_en.dart     # English translation map (160+ keys)
│   │   └── translations_bn.dart     # Bengali translation map (160+ keys)
│   ├── router/
│   │   └── app_router.dart       # GoRouter config, 10-branch sidebar navigation shell, SafeArea wrapper
│   ├── theme/
│   │   └── app_theme.dart        # Material 3 light/dark themes, status bar matches appbar color
│   └── utils/
│       ├── currency_formatter.dart  # Format/parse/compact currency
│       ├── date_formatter.dart      # Date formatting, timeAgo, isToday etc.
│       ├── debouncer.dart           # Reusable 400ms search debouncer
│       └── validators.dart          # Form validators (required, phone, sku, costVsSelling, etc.)
├── data/
│   ├── models/
│   │   ├── category.dart         # id, name, createdAt
│   │   ├── customer.dart         # id, name, phone, address, tag(new/regular/vip), stats
│   │   ├── expense.dart          # id, title, amount, category(logistics/packaging/marketing/supplies/other), date
│   │   ├── order.dart            # id, orderNumber, customer info, items, totals, payment/order status, paymentMethod, delivery, recurring, return fields
│   │   ├── order_item.dart       # @embedded: productId, name, sku, qty, unitPrice, costPrice, totalPrice, variantName, variantValue
│   │   ├── product.dart          # id, name, sku, prices, stockQty, category, qrCode, isActive, variants
│   │   ├── product_variant.dart  # @embedded: name, value, priceAdjustment, stockQty, sku
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
│       ├── drive_service.dart       # Google Drive backup/restore (safe restore with rollback), max 5 backups, OAuth
│       ├── isar_service.dart        # Riverpod provider (keepAlive), opens DB with 6 collection schemas
│       ├── notification_service.dart # Low stock alerts + unpaid order reminders via flutter_local_notifications
│       └── pdf_service.dart         # Order receipt PDF (with tax line), WhatsApp text generation
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
│   │   │   ├── dashboard_screen.dart               # Responsive dashboard with date-range filter bar (Today/Week/Month/Custom)
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
│   │   │   ├── product_form_screen.dart            # Image, QR, category, selling+cost price, variants editor
│   │   │   ├── product_detail_screen.dart          # Full info, variants card, adjust stock
│   │   │   └── widgets/
│   │   │       ├── product_card.dart
│   │   │       └── stock_badge.dart
│   │   └── providers/product_provider.dart         # Soft-delete (if in orders), negative stock prevention, variant-aware adjustStock
│   ├── reports/
│   │   ├── presentation/reports_screen.dart        # Date range picker, summary cards, top products chart, category sales, top customers
│   │   └── providers/reports_provider.dart         # Parameterized by date range, aggregates revenue/profit/expenses/rankings
│   ├── returns/
│   │   └── presentation/create_return_screen.dart  # Item selector with qty controls, reason chips, refund amount (capped at amountPaid), variant display
│   └── settings/
│       ├── presentation/settings_screen.dart       # Theme toggle, language picker, shop config, tax rate, Drive backup, clear data
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

| Model | Key Fields | Computed Props |
| ----- | ---------- | -------------- |
| **Product** | name, sku, sellingPrice, costPrice, stockQty, lowStockThreshold, category, qrCode, isActive, **variants** (embedded list) | profitMargin, isLowStock, isOutOfStock, hasVariants, totalStock |
| **ProductVariant** | @embedded: name, value, priceAdjustment, stockQty, sku | — |
| **Order** | orderNumber, customerId/Name/Phone, items (embedded), subtotal, discountAmount, deliveryFee, **taxAmount**, totalAmount, amountPaid, paymentStatus, **paymentMethod**, orderStatus, **deliveryAddress**, **estimatedDeliveryDate**, **actualDeliveryDate**, **isReturn**, **originalOrderId**, **isRecurring**, **recurringIntervalDays**, **nextRecurringDate** | balanceDue, isFullyPaid, totalItems |
| **OrderItem** | @embedded: productId, productName, productSku, qty, unitPrice, **costPrice**, totalPrice, **variantName**, **variantValue** | hasVariant, displayName |
| **Customer** | name, phone, address, notes, tag (new/regular/vip), totalOrders, totalSpent, outstandingBalance | hasOutstanding |
| **Expense** | title, amount, category (logistics/packaging/marketing/supplies/other), date, notes | — |
| **StockMovement** | productId, productName, type (sale/restock/adjustment/damage), qty, reason | isIncoming |
| **Category** | name | — |

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
  - **Variant support:** Products with variants show expand/collapse arrow; each variant has its own price, stock, and add/qty controls
  - Inline +/- qty controls per product/variant (no close-reopen cycle)
  - **Stock validation:** + button disabled when qty reaches available stock; qty clamped to stock limit
  - Out-of-stock products/variants are dimmed with disabled button
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

## Key Business Flows

### Order Creation (transactional)

1. Customer is required (validated in form)
2. Save order to DB — each OrderItem stores `costPrice` from the product at time of order (frozen for accurate profit)
3. OrderItem stores `variantName`/`variantValue` if a variant was selected
4. Tax amount is calculated from the per-order tax rate field and stored on the order
5. If status == confirmed: deduct stock per item (**both base `stockQty` and variant `stockQty`**) + create StockMovement records
6. If customerId > 0: update customer totalOrders, totalSpent, outstandingBalance

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

### Stock Adjustment (transactional, variant-aware)

1. Update product.stockQty += delta (**clamped to 0 minimum**)
2. If variant specified: also update the matching variant's stockQty
3. Create StockMovement record with type and reason (includes variant info in productName)
4. Stock adjustment screen shows **variant selector** (choice chips) for products with variants
5. Stock values shown via `StreamBuilder` for real-time updates

### Product Detail Screen

- Shows full product info including **variants card** with per-variant stock, price adjustment, and SKU
- Adjust stock button links to inventory adjustment screen

### Product Deletion (safe)

- If product is referenced in any order: **soft-delete** (sets isActive=false)
- If not referenced: hard-delete + cleans up stock movements

### Customer Deletion (safe)

- **Unlinks orders** (sets customerId=0 on related orders, preserving order data)
- Then deletes the customer

### Backup/Restore (Google Drive, safe)

- Exports all 6 collections as timestamped JSON to Drive appDataFolder
- Keeps max 5 backups, cleans up old ones (cleanup failure doesn't break upload)
- **Safe restore:** creates local safety backup before clearing → if import fails, rolls back to safety backup
- Validates backup structure before touching local data

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

## Navigation (GoRouter)

10 branches via `StatefulShellRoute` with a responsive sidebar (icon-only <600px, expanded with labels >=600px). Tooltips on icons when collapsed. Wrapped in `SafeArea`.

| Branch | Path | Sub-routes |
| ------ | ---- | ---------- |
| Dashboard | `/` | — |
| Products | `/products` | `add`, `:id`, `:id/edit` |
| Orders | `/orders` | `add`, `:id`, `:id/edit` |
| Returns | `/returns` | `:id` |
| Customers | `/customers` | `add`, `:id`, `:id/edit` |
| Inventory | `/inventory` | `adjust/:id` |
| Expenses | `/expenses` | `add`, `:id/edit` |
| Categories | `/categories` | — |
| Reports | `/reports` | — |
| Settings | `/settings` | — |

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
- **Status bar** color matches appbar (white in light theme, #1C1C2E in dark theme)
- **Language:** English + Bengali with in-app language switcher
- **Responsive sidebar navigation**: icon-only rail (56px) on phones (<600px), expanded with labels (200px) on tablet/desktop (>=600px). Tooltips on collapsed icons. Wrapped in SafeArea.
- **Responsive layouts throughout**:
  - Dashboard: stat cards via `Wrap` + `LayoutBuilder` (2-6 cols based on `width/170`); charts side-by-side on wide screens; date-range filter bar
  - Product grid: responsive columns via `LayoutBuilder` (`width/180`, clamp 2-6)
  - Order card: compact column on phone, single-row layout on tablet (>=600px)
  - Inventory: category filter + sort dropdown bar; **per-variant stock display**
- **Dashboard charts**: Weekly sales bar chart, order status pie chart, revenue vs expenses line chart
- **Reports screen**: Date range picker, summary stat cards, top products bar chart, category sales, top customers ranking
- **Customer detail chart**: 6-month purchase history bar chart
- **FABs**: Icon-only `+` with tooltip, rounded-square shape (16px radius)
- Cards with 14px radius, subtle shadows
- Color-coded text-only status badges (no icons in badges)
- Shimmer loading, empty states, confirm dialogs
- All number inputs have `inputFormatters` (digits, decimal, or phone pattern)
- Currency: Bangladeshi Taka (৳) by default
- **Search debouncing** (400ms) on product and customer list screens
- **User-friendly error messages** in all form screens (no raw exceptions)

## Code Generation

Run after model/provider changes:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Generates: `.g.dart` (Isar schemas, JSON, Riverpod providers), `.freezed.dart` (dashboard stats)

## Platform Support

Android, iOS (min 16.0), Web, macOS, Linux, Windows.
