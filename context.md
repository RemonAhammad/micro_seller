# MicroSeller (SellerBook) — Project Context

A Flutter inventory & order management app for micro/small sellers. Local-first with optional Google Drive backup.

## Tech Stack

- **Flutter** (SDK >=3.5.0 <4.0.0)
- **State Management:** Riverpod (`flutter_riverpod` + `riverpod_annotation` + code generation)
- **Database:** Isar 3.1 (embedded NoSQL, local-first)
- **Navigation:** GoRouter with `StatefulShellRoute` (8-branch sidebar navigation)
- **Code Generation:** Freezed (immutable classes), JSON serializable, Isar schema generator
- **PDF:** `pdf` + `printing` packages for receipt generation
- **Cloud:** Google Sign-In + Google Drive API for backup/restore
- **Charts:** fl_chart for dashboard sales visualization
- **Other:** image_picker, mobile_scanner (QR), share_plus, url_launcher, intl

## Architecture

Feature-based modular structure with repository pattern:

```
lib/
├── main.dart                     # Entry point, portrait-only, ProviderScope
├── app.dart                      # Root MaterialApp, theme, GoRouter, Isar warmup
├── core/
│   ├── constants/
│   │   ├── app_colors.dart       # Teal primary (#00897B), status/payment colors
│   │   ├── app_sizes.dart        # Spacing, radius, icon size tokens
│   │   └── app_strings.dart      # 100+ string constants (localization-ready)
│   ├── extensions/
│   │   └── context_extensions.dart  # Theme, snackbar, confirm dialog shortcuts
│   ├── router/
│   │   └── app_router.dart       # GoRouter config, sidebar navigation shell
│   ├── theme/
│   │   └── app_theme.dart        # Material 3 light/dark themes
│   └── utils/
│       ├── currency_formatter.dart  # Format/parse/compact currency
│       ├── date_formatter.dart      # Date formatting, timeAgo, isToday etc.
│       └── validators.dart          # Form validators (required, phone, sku, etc.)
├── data/
│   ├── models/
│   │   ├── category.dart         # id, name, createdAt
│   │   ├── customer.dart         # id, name, phone, address, tag(new/regular/vip), stats
│   │   ├── expense.dart          # id, title, amount, category(logistics/packaging/marketing/supplies/other), date
│   │   ├── order.dart            # id, orderNumber, customer info, items, totals, payment/order status
│   │   ├── order_item.dart       # @embedded: productId, name, sku, qty, unitPrice, totalPrice
│   │   ├── product.dart          # id, name, sku, prices, stockQty, category, qrCode, isActive
│   │   └── stock_movement.dart   # id, productId, type(sale/restock/adjustment/damage), qty, reason
│   ├── repositories/
│   │   ├── customer_repository.dart   # CRUD, search, watchAll stream
│   │   ├── expense_repository.dart    # CRUD, date range, monthly totals
│   │   ├── order_repository.dart      # CRUD + createOrder (stock deduction, customer stats), markAsPaid
│   │   ├── product_repository.dart    # CRUD, watchLowStock, adjustStock (creates StockMovement)
│   │   └── stock_repository.dart      # CRUD, watchByProduct
│   └── services/
│       ├── isar_service.dart     # Riverpod provider (keepAlive), opens DB with 6 schemas
│       ├── drive_service.dart    # Google Drive backup/restore, max 5 backups, OAuth
│       └── pdf_service.dart      # Order receipt PDF, WhatsApp text generation
├── features/
│   ├── categories/
│   │   ├── presentation/category_screen.dart      # List + add/edit/delete dialogs
│   │   └── providers/category_provider.dart        # Stream + notifier (ensureExists)
│   ├── customers/
│   │   ├── presentation/
│   │   │   ├── customer_list_screen.dart           # Search by name/phone
│   │   │   ├── customer_form_screen.dart           # Add/edit with tag selector
│   │   │   ├── customer_detail_screen.dart         # Stats + order history
│   │   │   └── widgets/customer_card.dart
│   │   └── providers/customer_provider.dart
│   ├── dashboard/
│   │   ├── presentation/
│   │   │   ├── dashboard_screen.dart               # Revenue, stats, chart, low stock, unpaid
│   │   │   └── widgets/
│   │   │       ├── stat_card.dart
│   │   │       ├── sales_chart.dart                # 7-day bar chart with revenue/profit toggle
│   │   │       ├── low_stock_list.dart
│   │   │       └── unpaid_orders_widget.dart
│   │   └── providers/dashboard_provider.dart       # Aggregates stats from all collections
│   ├── expenses/
│   │   ├── presentation/
│   │   │   ├── expense_list_screen.dart            # Month summary banner + list
│   │   │   ├── expense_form_screen.dart            # Date picker, category selector
│   │   │   └── widgets/expense_card.dart
│   │   └── providers/expense_provider.dart
│   ├── inventory/
│   │   ├── presentation/
│   │   │   ├── inventory_screen.dart               # 2 tabs: Stock Levels, Movements
│   │   │   ├── stock_adjustment_screen.dart        # Type selector, qty, reason
│   │   │   └── widgets/stock_movement_tile.dart
│   │   └── providers/inventory_provider.dart
│   ├── orders/
│   │   ├── presentation/
│   │   │   ├── order_list_screen.dart              # 5 tabs: All/Pending/Active/Completed/Cancelled
│   │   │   ├── order_form_screen.dart              # Customer picker, product picker, pricing
│   │   │   ├── order_detail_screen.dart            # Status actions, payment, share/print/PDF
│   │   │   └── widgets/
│   │   │       ├── order_card.dart
│   │   │       ├── order_item_row.dart
│   │   │       └── order_status_badge.dart         # Also PaymentStatusBadge
│   │   └── providers/order_provider.dart           # Complex: stock deduction, customer stats
│   ├── products/
│   │   ├── presentation/
│   │   │   ├── product_list_screen.dart            # Search, category chips, grid/list toggle
│   │   │   ├── product_form_screen.dart            # Image picker, QR scanner, category chips
│   │   │   ├── product_detail_screen.dart          # Full info, adjust stock
│   │   │   └── widgets/
│   │   │       ├── product_card.dart
│   │   │       └── stock_badge.dart
│   │   └── providers/product_provider.dart
│   └── settings/
│       ├── presentation/settings_screen.dart       # Shop config, Drive backup, clear data
│       └── providers/settings_provider.dart        # keepAlive: shopName, currency(৳), threshold
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
|-------|-----------|----------------|
| **Product** | name, sku, sellingPrice, costPrice, stockQty, lowStockThreshold, category, qrCode, isActive | profitMargin, isLowStock, isOutOfStock |
| **Order** | orderNumber, customerId/Name/Phone, items (embedded), subtotal, discountAmount, deliveryFee, totalAmount, amountPaid, paymentStatus, orderStatus | balanceDue, isFullyPaid, totalItems |
| **OrderItem** | @embedded: productId, productName, productSku, qty, unitPrice, totalPrice | — |
| **Customer** | name, phone, address, notes, tag (new/regular/vip), totalOrders, totalSpent, outstandingBalance | hasOutstanding |
| **Expense** | title, amount, category (logistics/packaging/marketing/supplies/other), date, notes | — |
| **StockMovement** | productId, productName, type (sale/restock/adjustment/damage), qty, reason | isIncoming |
| **Category** | name | — |

## Key Business Flows

### Order Creation (transactional)
1. Save order to DB
2. If status == confirmed: deduct stock per item + create StockMovement records
3. If customerId > 0: update customer totalOrders, totalSpent, outstandingBalance

### Payment Recording (transactional)
1. Update order.amountPaid, determine paymentStatus (paid/partial)
2. Update customer.outstandingBalance -= payment

### Stock Adjustment (transactional)
1. Update product.stockQty += delta
2. Create StockMovement record with type and reason

### Backup/Restore (Google Drive)
- Exports all 6 collections as timestamped JSON to Drive appDataFolder
- Keeps max 5 backups, cleans up old ones
- Restore clears all data then imports from selected backup

## Navigation (GoRouter)

8 branches via `StatefulShellRoute` with persistent sidebar:

| Branch | Path | Sub-routes |
|--------|------|------------|
| Dashboard | `/` | — |
| Products | `/products` | `add`, `:id`, `:id/edit` |
| Orders | `/orders` | `add`, `:id` |
| Customers | `/customers` | `add`, `:id`, `:id/edit` |
| Inventory | `/inventory` | `adjust/:id` |
| Expenses | `/expenses` | `add`, `:id/edit` |
| Categories | `/categories` | — |
| Settings | `/settings` | — |

## State Management Pattern

- **Stream providers** for reactive lists (products, orders, customers, etc.)
- **Notifier classes** for mutations (add, update, delete, complex transactions)
- **AsyncValue.guard()** for error handling
- **Isar watch(fireImmediately: true)** for real-time UI updates
- **Freezed** for immutable dashboard stats (DailySales, DashboardStats)
- **Settings provider** (keepAlive): shopName, currencySymbol (৳), lowStockThreshold

## UI Design

- Material 3, teal primary (#00897B), light/dark theme support
- Sidebar navigation (collapsible, gradient teal-to-dark)
- Cards with 12px radius, subtle shadows
- Color-coded status badges (order status, payment status, stock level)
- Shimmer loading, empty states, confirm dialogs
- Currency: Bangladeshi Taka (৳) by default

## Code Generation

Run after model/provider changes:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Generates: `.g.dart` (Isar schemas, JSON, Riverpod providers), `.freezed.dart` (dashboard stats)

## Platform Support

Android, iOS, Web, macOS, Linux, Windows (Windows support recently added).
