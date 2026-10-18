# Micro Seller (SellerBook) — Project Context

A Flutter inventory & order management app for micro/small sellers. Local-first with optional Google Drive backup.

## Tech Stack

- **Flutter** (SDK >=3.8.0 <4.0.0)
- **State Management:** Riverpod 3 (`flutter_riverpod ^3.0` + `riverpod_annotation ^4.0` + `riverpod_generator ^4.0`). Notes: (1) Riverpod 3 uses plain `Ref` everywhere (no per-provider `XxxRef` typedefs), and `@riverpod class XxxNotifier` generates `xxxProvider` (no `Notifier` infix). `AsyncValue.value` is now nullable; `valueOrNull` is gone. (2) **All CRUD notifiers must be `@Riverpod(keepAlive: true)`** — Riverpod 3 auto-disposes by default, and a `ref.read(xxxProvider.notifier).method()` call from a screen disposes the provider during the await. Post-await `state = ...` then throws `UnmountedRefException`. This applies to product / order / customer / supplier / expense / category / cash_register notifiers.
- **Database:** Isar 3.3 via the community fork — `isar_community` + `isar_community_flutter_libs` + `isar_community_generator` ^3.3.2. The original `isar` package was abandoned in 2023 and shipped 4 KB-aligned native binaries that Play Store rejects on Android 15+. The community fork is API-identical; storage format is byte-compatible (no on-device migration).
- **Navigation:** GoRouter with `StatefulShellRoute` (14-branch sidebar navigation)
- **Code Generation:** Freezed 3 (`freezed ^3.2.5` + `freezed_annotation ^3.1`). Note: freezed 3 requires `abstract class Foo with _$Foo` (the `abstract` keyword is mandatory). JSON serializable + isar_community schema generator.
- **Security:** `local_auth` (biometric) + `crypto` (SHA-256 PIN hashing). `AuthGateService` + `runAuthGate(context, reason: ..., fingerprintEnabled: ..., pinEnabled: ...)` helper protect destructive actions. PIN is stored in SharedPreferences as `sha256(salt + pin)` with a per-install salt. Android: `MainActivity` extends `FlutterFragmentActivity` (required by local_auth's BiometricPrompt) and the manifest declares `USE_BIOMETRIC`. Two-layer gate: (1) **`.env` build-time visibility** — `ENABLE_FINGERPRINT_GATE` / `ENABLE_PIN_GATE` (default `true`) control whether each toggle is shown in Settings → Security at all, and `runAuthGate` ignores any path whose `.env` flag is false; (2) **user setting** — `securityFingerprintEnabled` / `securityPinEnabled` in SharedPreferences (default `true`) control whether the user has each path active. Each toggle in Settings is verified independently — flipping fingerprint requires verifying *current fingerprint only* (never PIN), flipping PIN requires verifying *current PIN only*. Enabling PIN runs `runPinSetup` (fresh setup); disabling clears the stored PIN. `runAuthGate` chooses biometric if (env+user+device-available), else PIN if (env+user+stored), else passthrough.
- **PDF:** `pdf` + `printing` + `screenshot` (Flutter widget → PNG capture for guaranteed Unicode shaping, embedded into a single-page A4 `pw.Document`)
- **File open:** `open_file` package — used by the post-download bottom sheet to hand a saved invoice PDF to the system PDF viewer. Replaced an earlier SnackBar-based flow because Material's SnackBar duration was unreliable on MIUI / Xiaomi devices (timer paused indefinitely); the new `lib/shared/widgets/pdf_saved_sheet.dart` modal sheet owns its own `Timer(Duration(seconds: 5))` for guaranteed auto-dismiss.
- **Cloud:** Google Sign-In **7** + Google Drive API (`googleapis` 17) for backup/restore. v7 splits authentication (`GoogleSignIn.instance.authenticate()`, UI) from authorization (`authorizationClient.authorizationForScopes` — no UI — / `authorizeScopes`). `DriveService` only needs authorization for Drive calls, so background/startup paths (`hasDriveAccess()`, `_getDriveApi(interactive: false)`) never show UI. **On Android without google-services.json, v7 requires the *web* OAuth client id as `serverClientId`** — read from `GOOGLE_OAUTH_WEB_CLIENT_ID` in `.env` by `DriveService._ensureInitialized()`; if it's empty, sign-in fails with a configuration error.
- **Charts:** fl_chart for dashboard sales visualization + reports + customer history
- **Notifications:** flutter_local_notifications for low stock & payment alerts
- **CSV:** `csv` + `file_picker` for import/export
- **Localization:** flutter_localizations + custom delegate (12 languages: en, bn, ar, es, fr, pt, tr, id, th, vi, ur, ms)
- **Persistence:** SharedPreferences for app settings
- **Env config:** `flutter_dotenv` loads `.env` at startup (OAuth client IDs, gitignored; `.env.example` is the tracked template)
- **Onboarding:** showcaseview v5 for first-time guided tour
- **In-App Update:** in_app_update for Play Store auto-update prompts
- **Icons:** the **whole app** uses thin Tabler line icons (`tabler_icons_next`, SVG via `flutter_svg`) — no Material `Icons.*` / `Icon(...)` anywhere in `lib/`. Use `ThinIcon(tabler.Plus.new, size:, color:)` (a drop-in for `Icon`, defaults from `IconTheme`) with `import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;`. Icons are Tabler **constructor tear-offs** (`tabler.Box.new`), typed `ThinIconBuilder`; they're compile-time constants, so `const ThinIcon(...)` and `const` lists work. Widgets that take an icon (`EmptyState`, `ConfirmDialog`, `AppButton`, `StatCard`, `SidebarItem`, …) take a `ThinIconBuilder`, not `IconData`. Shared named icons live in `AppIcons` ([app_icons.dart](lib/core/constants/app_icons.dart)). Stroke `kIconStroke = 1.25` (`kIconStrokeSelected = 1.75` for the active sidebar tab; Tabler's default is 2.0). The theme's `actionIconTheme` swaps Flutter's own back / drawer / close buttons for Tabler too (back arrow flips in RTL). History: `phosphor_flutter` 2.1.0 doesn't compile on Flutter 3.44 (extends the now-`final` `IconData`); Lucide and Fluent were judged too bold.
- **Package versions (upgraded 2026-09-30 to latest for Flutter 3.44):** share_plus 13 (`SharePlus.instance.share(ShareParams(...))` — `Share.share` is deprecated), file_picker 13 (static `FilePicker.pickFile` / `getDirectoryPath`; read `PlatformFile.readAsBytes()` because SAF content URIs have no path), csv 8 (`csv.encode` / `csv.decode`), fl_chart 1.x (`tooltipBorderRadius`), local_auth 3 (`authenticate(biometricOnly:, persistAcrossBackgrounding:)` — no `AuthenticationOptions`), flutter_local_notifications 22 (named `initialize(settings:)` / `show(id:, title:, body:, notificationDetails:)`), go_router 18, mobile_scanner 7, package_info_plus 10, in_app_update 5, open_file 4, flutter_dotenv 6, flutter_lints 6. After a major plugin upgrade run `flutter clean` — a stale Gradle Kotlin cache made share_plus 13 fail to compile until cleaned.
- **Other:** image_picker, mobile_scanner v7 (QR), url_launcher, intl

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
│   │   └── app_router.dart       # GoRouter config, 14-branch sidebar navigation shell, SafeArea wrapper
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
│   │   ├── order.dart            # id, orderNumber, customer info, items, totals, payment/order status, paymentMethod, delivery, recurring, return fields. Also `returnValueFor` (what returning items is worth) and `roundMoney`
│   │   ├── order_item.dart       # @embedded: productId, name, sku, qty, unitPrice, costPrice, totalPrice, variantCombinationKey, variantDisplayLabel
│   │   ├── product.dart          # id, name, sku, prices, stockQty, category, qrCode, isActive, variantAttributes, variantCombinations
│   │   ├── product_variant.dart  # @embedded (deprecated): flat name/value/priceAdjustment/stockQty/sku
│   │   ├── variant_attribute.dart # @embedded: name, options[] — defines one dimension (e.g. Size→[S,M,L])
│   │   ├── variant_combination.dart # @embedded: combinationKey, displayLabel, priceAdjustment, stockQty, sku, isActive
│   │   ├── supplier.dart         # id, name, phone, email, address, company, notes, totalPurchases, totalPaid, totalDue
│   │   ├── purchase.dart         # id, supplierId, supplierName, items (embedded PurchaseItem), totalAmount, amountPaid, paymentMethod, notes, referenceNumber
│   │   ├── cash_register.dart    # id, openingAmount, closingAmount, totalSales, totalExpenses, totalCashIn, totalCashOut, isClosed, openedAt, closedAt
│   │   ├── payment.dart          # @Index customerId + orderId, amount (negative = refund), method, transactionId, note, groupId, paidAt — history log behind Order.amountPaid
│   │   ├── stock_movement.dart   # id, productId, type(sale/restock/adjustment/damage), qty, reason
│   │   └── trash_entry.dart      # kind(TrashKind), originalId, payload(JSON), sidecar(JSON), label, sublabel, deletedAt. `@Collection(accessor: 'trashEntries')` — the default pluralisation would be `trashEntrys`.
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
│       ├── drive_service.dart       # Google Drive backup/restore — delegates JSON to LocalBackupService (all 10 backed-up collections); typed DriveBackupException + DriveErrorCode; max 5 backups; safe restore with rollback; full error/stack logging via dart:developer
│       ├── isar_service.dart        # Riverpod provider (keepAlive), opens DB with `kIsarSchemas` (11 schemas). The auto-backup worker opens the same file from its own isolate with the **same constant** — a hand-kept copy there had silently fallen behind (missing TrashEntrySchema). Also runs one-time migrations (`migrateVariantsV2`, `migrateOutstandingBalancesV1`).
│       ├── dues_service.dart        # `computeOrderDues` (effective due per order, oldest first — subtracts refunded returns), `recalculateOutstandingBalancesInTxn`, `migrateOutstandingBalancesV1`
│       ├── report_service.dart      # Pure report builders (no Isar): buildSalesReport (P&L: gross sales at list price → discounts → returns → net sales → COGS → gross profit → + delivery → expenses → net profit; tax collected shown, never profit; also feeds the Dashboard's profit), buildDuesReport, buildInventoryReport, buildPurchasesReport. Each report has toTables(tr) → List<ReportTable>, the single shape CSV and PDF export from.
│       ├── report_pdf_service.dart  # Paginated widget→PNG→PDF for a report's tables (repeats table headers across pages)
│       ├── statement_service.dart   # Customer statement: `buildRows` (running ledger: orders debit; payments + refunded returns credit; unlogged legacy payments inferred per order) + paginated widget→PNG→PDF (26 rows/page, 794×1123)
│       ├── catalog_service.dart     # Shareable product catalog. Same widget→PNG→PDF pipeline as pdf_service (Skia/HarfBuzz for Unicode). `generateCatalogImage` (single-page PNG for chat), `generateCatalogPdf` (paginated, 6 tiles/page in a fixed 794×1123 A4 canvas), `generateCatalogText` (plain price list). Product images are pre-read to `Uint8List` and rendered via `Image.memory` — `Image.file` loads async and the off-screen capture races it, producing blank tiles.
│       ├── trash_service.dart       # Soft-delete store behind the undo snackbar + Recycle Bin. Generic over all models (every one has toJson/fromJson). `capture()` is called inside the delete's own writeTxn; `restore()` dispatches on TrashKind and reverses side effects from the entry's `sidecar`; `purgeExpired()` drops entries older than `kTrashRetention` (30 days), called post-first-frame from app.dart.
│       ├── local_backup_service.dart # Public encodeAll(Isar)/decodeAll(Isar,String) — single source of truth for backup JSON shape (v4 — adds `payments`; older backups restore with empty payment history). exportBackup/importBackup/exportToDirectory delegate to these. All 10 backed-up collections (everything except `trashEntries`).
│       ├── notification_service.dart # Low stock alerts + unpaid order reminders via flutter_local_notifications
│       ├── tutorial_service.dart    # SharedPreferences flags: splash_shown, tour_completed; resetAll()
│       ├── auth_gate_service.dart   # Biometric (local_auth) + 4-digit PIN (SHA-256 with per-install salt, stored in SharedPreferences). Used to gate destructive actions like Clear All Data. Two-layer control: `.env` (`ENABLE_FINGERPRINT_GATE` / `ENABLE_PIN_GATE`) gates each toggle's *visibility* in Settings → Security; user settings (`securityFingerprintEnabled` / `securityPinEnabled`) control whether each path is *active*. Each toggle is verified independently against its own auth method only.
│       ├── auto_backup_runner.dart  # Two surfaces: (a) `runIfDue()` fires once on app startup (post-frame, fast catch-up) and (b) a top-level `autoBackupCallbackDispatcher` registered with WorkManager runs at **00:05 local time daily** in a separate isolate (Android only). Implemented as a self-rescheduling chain of `registerOneOffTask` calls (with `initialDelay = duration to next 00:05`) rather than `registerPeriodicTask`, because WorkManager's periodic API only promises an interval, not a clock time. The worker re-opens Isar from disk, calls `DriveService.backupToDrive(interactive: false)` with a `_exportSettingsFromPrefs` snapshot, writes `lastBackupTime` on success, then re-registers itself for the next 00:05. On revoked access (`notSignedIn` / `signInFailed` / `developerError`) the worker writes `kAutoBackupErrorKey` to SharedPreferences, fires `NotificationService.showAutoBackupPaused()` *once* (subsequent revoke runs skip the notification to avoid spam), and stops the chain — the Settings → Drive banner re-arms it after the user signs back in. `scheduleAutoBackup()` / `cancelAutoBackup()` static helpers register/cancel the chain; called from `main.dart` on startup and from the Settings toggle.
│       ├── review_service.dart      # Rating prompt (ported from Fuel Cost): eligibility (≥5 real sales orders), back-off (Later = 30-day snooze, max 3 asks; rate/decline = never again), requestReview() → Play in-app review sheet or store listing
│       ├── update_service.dart      # In-app update via Play Store (immediate for critical, flexible for normal)
│       └── pdf_service.dart         # Order invoice PDF + WhatsApp text. Renders the receipt as a Flutter widget tree (`_ReceiptWidget`) and captures it to a PNG via `screenshot.captureFromWidget` (Skia + HarfBuzz → full Unicode shaping for Bengali conjuncts, Arabic ligatures, Thai/Devanagari/CJK, color emoji), then embeds the PNG into a single-page A4 `pw.Document`. Bottom-right "Powered by ⬡ Micro Seller" watermark. Trade-off: PDF text is rasterised, not selectable — accepted for guaranteed Unicode correctness. Earlier `pw.Document`-only and `Printing.convertHtml` paths were tried and failed (broken Indic shaping / WebView hangs respectively).
├── features/
│   ├── categories/
│   │   ├── presentation/category_screen.dart      # List + add/edit/delete dialogs
│   │   └── providers/category_provider.dart        # Stream + notifier (ensureExists)
│   ├── customers/
│   │   ├── presentation/
│   │   │   ├── customer_list_screen.dart           # Search by name/phone (debounced)
│   │   │   ├── customer_form_screen.dart           # Add/edit with tag selector
│   │   │   ├── customer_detail_screen.dart         # Live (watchObject) stats, Collect / Remind / Statement actions, payment history, order history, 6-month purchase chart
│   │   │   ├── due_book_screen.dart                # /dues (own sidebar tab, branch 13) — who owes what; sort menu (oldest / newest, largest / smallest, most unpaid orders, longest since last payment / recently paid, name A–Z / Z–A; ties → larger due first); filter sheet (age bucket <30/30–60/60+ days, customer tag, never paid / no payment in 30 days, minimum due, has phone) with live results, removable active-filter chips, badge count; summary card totals follow the filters; collect / WhatsApp remind / call, recalculate balances
│   │   │   ├── widgets/due_actions.dart            # Collect sheet (allocation preview), `sendDueReminder` (wa.me), `shareCustomerStatement`, `PaymentHistoryTile`
│   │   │   └── widgets/customer_card.dart
│   │   ├── providers/customer_provider.dart        # Cascading delete (unlinks orders)
│   │   └── providers/dues_provider.dart            # `duesProvider` (live List<CustomerDue>), `customerPaymentsProvider(customerId)`
│   ├── dashboard/
│   │   ├── presentation/
│   │   │   ├── dashboard_screen.dart               # Responsive dashboard with date-range filter bar, showcaseview tour (3 steps), in-app update check
│   │   │   └── widgets/
│   │   │       ├── stat_card.dart                  # Compact card with icon, value, label, optional onTap (dashboard passes a `route`)
│   │   │       ├── sales_chart.dart                # SalesChart (bar), OrderStatusChart (pie), RevenueExpenseChart (line)
│   │   │       ├── low_stock_list.dart
│   │   │       └── due_summary_card.dart           # Due Book on the dashboard: total receivable, aging bar (<30 / 30–60 / 60+ days, per customer by oldest due), top 3 to chase with WhatsApp remind + collect
│   │   └── providers/dashboard_provider.dart       # DashboardDateRange notifier + stats provider (watches date range and `ordersProvider`, so cards update without pull-to-refresh; profit = `buildSalesReport(...).grossProfit`, the Reports number)
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
│   │   ├── presentation/reports_screen.dart        # One date range (Today / This week / This month / Last month / This year / Custom) + 4 tabs; Export → current tab as PDF or CSV
│   │   ├── presentation/widgets/report_tabs.dart   # SalesReportTab, DuesReportTab, InventoryReportTab, PurchasesReportTab
│   │   ├── presentation/widgets/report_widgets.dart # ReportSectionCard, KpiGrid, PnlTable, BreakdownBars, NetSalesChart, ReportEmpty
│   │   └── providers/reports_provider.dart         # salesReport / duesReport / inventoryReport / purchasesReport (from, to) — load Isar rows for `reportWindow` [start, end) and call report_service builders. `loadOrdersAndReturns` / `loadCancelledOrderIds` are shared with the Dashboard
│   ├── splash/
│   │   └── presentation/splash_screen.dart         # Animated 3s splash: pulsing rings, logo scale+rotate, title slide, tagline fade, loader
│   ├── returns/
│   │   └── presentation/create_return_screen.dart  # Item selector with qty controls, reason chips, refund amount (pre-filled from `returnValueFor`, capped at amountPaid), variant display
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
│       ├── presentation/recycle_bin_screen.dart    # Deleted items grouped by kind; Restore / Delete forever / Empty bin (auth-gated)
│       ├── providers/trash_provider.dart           # trashServiceProvider + trashEntriesProvider (stream) + TrashNotifier (keepAlive)
│       ├── presentation/settings_screen.dart       # Theme toggle, language picker, currency picker (38+ currencies), shop config, tax rate, local backup export/import, Drive backup, clear data
│       └── providers/settings_provider.dart        # keepAlive, SharedPreferences: shopName, shopPhone (optional, printed on the shared catalog), currency(৳), threshold, themeMode, taxRate, language, downloadDirectory, sidebarOrder, sidebarPosition ('left' | 'right'), hiddenSidebarItems (list of keys the user toggled off). Exposes `exportSettings()`/`importSettings(map)` so backup/restore round-trips preferences alongside the 10 backed-up Isar collections. `toggleSidebarItemHidden('settings', _)` is a no-op — the Settings tab is force-visible to prevent soft-lockout.
└── shared/
    ├── screens/qr_scanner_screen.dart
    │   (sidebar Scanner branch lives in features/scanner/presentation/scanner_screen.dart)
    └── widgets/
        ├── app_button.dart           # Variants: filled, outlined, text, destructive
        ├── app_text_field.dart        # With paste button
        ├── bottom_sheet_handle.dart   # AppBottomSheet.show()
        ├── confirm_dialog.dart        # ConfirmDialog.show()
        ├── payment_method_chips.dart  # PaymentMethodChips + paymentMethodLabel()
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
| **Order**              | orderNumber, customerId/Name/Phone, items (embedded), subtotal, discountAmount, deliveryFee, **taxAmount**, totalAmount, amountPaid, paymentStatus, **paymentMethod**, orderStatus, **deliveryAddress**, **estimatedDeliveryDate**, **actualDeliveryDate**, **isReturn**, **originalOrderId**, **isRecurring**, **recurringIntervalDays**, **nextRecurringDate** | balanceDue, isFullyPaid, totalItems, goodsTotal (list price), netGoods (after discount), discountFactor, deliveryIncome |
| **OrderItem**          | @embedded: productId, productName, productSku, qty, unitPrice, **costPrice**, totalPrice, **variantCombinationKey**, **variantDisplayLabel**                                                                                                                                                                                                                     | hasVariant, displayName                                                               |
| **Customer**           | name, phone, address, notes, tag (new/regular/vip), totalOrders, totalSpent, outstandingBalance                                                                                                                                                                                                                                                                  | hasOutstanding                                                                        |
| **Expense**            | title, amount, category (logistics/packaging/marketing/supplies/other), date, notes                                                                                                                                                                                                                                                                              | —                                                                                     |
| **StockMovement**      | productId, productName, type (sale/restock/adjustment/damage), qty, reason                                                                                                                                                                                                                                                                                       | isIncoming                                                                            |
| **Category**           | name                                                                                                                                                                                                                                                                                                                                                             | —                                                                                     |
| **Supplier**           | name, phone, email, address, company, notes, totalPurchases, totalPaid, totalDue                                                                                                                                                                                                                                                                                 | hasOutstanding                                                                        |
| **Purchase**           | supplierId, supplierName, items (embedded PurchaseItem), totalAmount, amountPaid, paymentMethod, notes, referenceNumber                                                                                                                                                                                                                                          | balanceDue, isFullyPaid, totalItems                                                   |
| **PurchaseItem**       | @embedded: productId, productName, qty, unitCost, totalCost                                                                                                                                                                                                                                                                                                      | —                                                                                     |
| **Payment**            | customerId, orderId, amount (negative = refund), method, transactionId, note, groupId (shared by one multi-order collection), paidAt                                                                                                                                                              | isRefund                                                                              |
| **TrashEntry**         | kind, originalId, payload (JSON of the deleted record), sidecar (JSON of what its delete also changed), label, sublabel, deletedAt                                                                                                                                                                                                              | —                                                                                     |
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
  - **Download PDF** — saves to the user's chosen download directory (asked once, persisted in settings); `showPdfSavedSheet` (`pdf_saved_sheet.dart`) confirms the path with Open / Share and auto-dismisses after 5 s
  - **Print** — opens the system print dialog via `Printing.layoutPdf`
  - **Share via WhatsApp** — sends the formatted text version
  - **Done** dismisses; the form then pops back to the order list
  Edit-mode is unchanged (still pops directly).

## Key Business Flows

### Order Creation (transactional)

1. Customer is required (validated in form)
2. Save order to DB — each OrderItem stores `costPrice` from the product at time of order (frozen for accurate profit)
3. OrderItem stores `variantCombinationKey` + `variantDisplayLabel` if a variant was selected (legacy `variantName`/`variantValue` are only read as a fallback for pre-migration orders)
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
5. **Valued at what the customer paid:** `createReturnOrder` stores `returnValueFor(original, items)` as the return's subtotal / discountAmount / taxAmount / totalAmount: list price, minus the items' pro-rata share of the order discount, plus their share of the tax (delivery isn't refunded). The refund pre-fill uses the same function. At list price, a full return of a discounted order credited the customer the discount against their *other* dues. Returns created before this keep their list-price value (no migration — balances were settled against it).
6. Creates a new order with `RET-XXX` numbering, `isReturn: true`, linked via `originalOrderId`
7. Return detail screen shows only the 3-step return flow (Requested → Received → Refunded), **not** the regular order status stepper
8. On approve: **restores stock** (base + variant) for all items via restock StockMovements
9. **Updates customer stats** (decrements totalSpent)

### Recurring Orders

1. Toggle in order form sets `isRecurring`, `recurringIntervalDays`, `nextRecurringDate`
2. `processRecurringOrders()` checks for due recurring orders and auto-creates new pending copies

### Delivery Tracking

1. Delivery address and estimated delivery date set in order form
2. Order detail shows delivery tracking card with "Mark as Delivered" button
3. Marking delivered sets `actualDeliveryDate` and status to completed

### Profit Calculation

One formula, `buildSalesReport`, feeds both Reports → Gross profit and the Dashboard's profit card and 7-day chart (`profitSeries`), so the two screens can't disagree. The Dashboard used to sum `(unitPrice − costPrice) × qty`, which ignored the order discount (a Play Store review) and took whole cash refunds off profit.

- **Gross profit** = goods at list price − order discounts − returns − COGS. The discount is order-level (`discountAmount`); `Order.discountFactor` spreads it pro rata where per-item revenue is needed (top products, categories)
- **Tax** is never sales or profit — the P&L shows it as "Tax collected"
- **Delivery** (`deliveryIncome`, normally `deliveryFee`) is added below gross profit, so it lands in net profit against courier costs logged as Logistics expenses
- COGS uses `costPrice` stored on OrderItem (frozen at order time); falls back to the product's current cost when 0
- Returns reverse their goods value (`netGoods`) and their COGS on the day the goods came back
- Dashboard shows: filtered profit, weekly profit chart, revenue vs expenses line chart. Its revenue card is unchanged: billed totals minus refunds
- `test/profit_flow_test.dart` runs sale → return → refund on a real Isar database (the core library bundled in isar_community_flutter_libs, so it runs offline) and checks the Dashboard, Reports and Due Book agree

### Payment Recording (transactional)

1. Update order.amountPaid, determine paymentStatus (paid/partial)
2. Update customer.outstandingBalance -= payment
3. Log a `Payment` row in the same `writeTxn`. Every `amountPaid` change logs one: `createOrder` (initial payment), `recordPayment`, `collectFromCustomer`, `processRefund` (negative, on the original order), cancel (negative — cancel is an auto-refund). `deleteOrder` deletes the order's rows.

### Due Book (customer credit ledger)

Sellers sell on credit ("baki"); the Due Book is where they get paid back. Own sidebar tab **Due Book** (`/dues`, branch 13, key `dues`), also reached from the Customers appbar and the Dashboard unpaid card.

- **Dues are computed from orders, never from `Customer.outstandingBalance`.** That counter drifts (`updateOrder` doesn't adjust it; recurring copies didn't bill the customer until the Due Book fixed `processRecurringOrders`). The customer's total is `computeNetDue` — every order's effective due *including credits* (an exchange return worth more than an order's remaining due), floored at 0 — so it matches the counter and the statement; collections are capped at it. `computeOrderDues` takes all of a customer's orders *including returns*: excluded are cancelled orders and return orders; each order's effective due is `balanceDue − value of its refunded returns`, because `processRefund` lowers the original's `amountPaid` by the refund but not its `totalAmount`.
- **Collect** (`OrderNotifier.collectFromCustomer`): one amount applied oldest-first across the customer's due orders, capped at the total due (no advance credit). One `Payment` per touched order sharing a `groupId`. Cash collections can add to the open cash register in the same transaction. The sheet's allocation preview mirrors the notifier's loop.
- **Remind**: localized WhatsApp text via `https://wa.me/<digits>?text=`. A Bangladeshi local mobile (`01…`, 11 digits) with ৳ gets the `88` prefix; other numbers pass through as typed. No phone / launch failure → share sheet.
- **Statement**: `StatementService` PDF (running balance). Orders before payment history existed have no `Payment` rows, so each order's unlogged `amountPaid` is shown as a payment on the order date — the closing balance always matches the orders.
- **Recalculate balances** (Due Book overflow menu, and once automatically via `migrateOutstandingBalancesV1`) resets every counter to the computed dues.

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

- Exports **all 10 backed-up collections** as timestamped JSON to Drive appDataFolder (uses `LocalBackupService.encodeAll`)
- Keeps max 5 backups, cleans up old ones (cleanup failure doesn't break upload)
- **Safe restore:** creates local safety backup before clearing → if import fails, rolls back to safety backup
- **Settings round-trip:** backup payload includes a `settings` field built from `Settings.exportSettings()` (theme, currency, sidebar order/position/hidden items, shop name, autoBackup, etc.). Restore re-applies via `Settings.importSettings(map)`. v2 backups (collections only) still restore correctly — `settings` is optional on decode.
- **Auto Backup (two-tier):** `Settings.autoBackup` toggle (Settings → Drive section). Enabling it both (a) lets `AutoBackupRunner.runIfDue()` fire post-first-frame from `SellerBookApp.initState()` for a fast catch-up (12 h soft de-dupe via `lastBackupTime`), and (b) registers a daily `Workmanager().registerOneOffTask` (uniqueName `auto-backup-daily`, `initialDelay = duration to next 00:05 local time`, `NetworkType.connected` + `requiresBatteryNotLow`) that runs in a background isolate even when the app is closed. The worker re-arms itself for the next 00:05 in its `finally` block, forming a self-rescheduling chain — chosen over `registerPeriodicTask` because the periodic API only promises an interval, not a clock time. Neither path ever triggers interactive sign-in (foreground via `getCurrentUser()` early-return; worker via `backupToDrive(interactive: false)`). When the worker hits `notSignedIn` / `signInFailed` / `developerError` it persists `autoBackupError` in SharedPreferences, fires a "Auto backup paused" notification *once* (subsequent revoke runs skip it), and stops the chain. The Settings → Drive section watches that flag (refreshed on `initState` and `AppLifecycleState.resumed`) and shows an amber banner with a "Sign in to fix" button that re-runs `DriveService.signIn()`, clears the flag, and re-arms the chain via `scheduleAutoBackup()`. Toggling Auto Backup off cancels the worker and clears the banner. WorkManager is Android-only; the helpers `Platform.isAndroid` early-return on iOS/desktop. Native setup: workmanager **0.10.x** (0.5.2 no longer compiles on current Flutter — it used the removed v1 embedding `Registrar` / `ShimPluginRegistry`) auto-registers via the v2 plugin embedding — no MainActivity / Application class changes required. `initialize()` takes no `isInDebugMode` in 0.10.
- Validates backup structure (`version`, `timestamp`) before touching local data
- **Typed errors:** `DriveBackupException` with `DriveErrorCode` (`notSignedIn`, `signInFailed`, `developerError` for ApiException 10, `network`, `invalidBackup`, `uploadFailed`, `downloadFailed`, `restoreFailed`, `rolledBack`). UI switches on the code instead of substring-matching messages.
- **Logging:** every failure logs the error + stack via `dart:developer` and `debugPrintStack` in debug builds.
- **OAuth scope:** `drive.appdata` — backups live in a hidden app-data folder; not visible at drive.google.com.
- **OAuth client IDs** are stored in `.env` (gitignored). Since google_sign_in 7, `GOOGLE_OAUTH_WEB_CLIENT_ID` is **required at runtime** on Android (passed as `serverClientId`); the Android client ids still just need to exist in the Cloud project with the right package + SHA-1.

### Product Catalog Share

Turns the app from a pure ledger into an outbound sales surface — the target sellers sell *through* WhatsApp and Facebook groups and previously retyped price lists by hand.

1. Products list → share action in the appbar → `/products/catalog`
2. Multi-select products (only `isActive` ones are offered — a soft-deleted item shouldn't be advertised), with select-all
3. Filter chips toggle photos / stock / SKU per tile
4. Three outputs, because chat apps treat them differently:
   - **Share as Image** — one PNG, the most shareable form in a thread. Capped at one page (6 products); a snackbar says so rather than silently dropping the overflow.
   - **Share as PDF** — paginated, carries everything
   - **Copy price list** — plain text, includes per-variant prices (`sellingPrice + priceAdjustment`) which a flat list would misquote
5. Header shows `Settings.shopName` + optional `Settings.shopPhone`; footer carries the same "Powered by ⬡ Micro Seller" watermark as the invoice

**Two constraints inherited from `pdf_service`:** (a) `captureFromWidget` needs a *finite* `targetSize` — infinity × pixelRatio yields an undecodable PNG — so the page is a fixed 794×1123 and content is paginated rather than scrolled; (b) the capture environment provides only `Directionality`, so `MediaQuery` / `DefaultTextStyle` / `Material` are wired by hand (`MaterialApp` fails there). Unlike the receipt, the catalog is image-heavy, so images are pre-decoded to bytes and the capture `delay` is raised to 300 ms.

### Undo & Recycle Bin

Before this, `grep -r 'undo|trash|deletedAt' lib/` returned one string constant in a warning dialog — deletes were safe for data integrity but permanent for the user.

- **One generic `TrashEntry` collection** rather than `deletedAt` flags on each model, viable because all 13 models implement `toJson`/`fromJson`. No query in the app needs to learn to filter deleted rows.
- **Deletes are not pure**, so the payload alone is not enough to restore. Each entry carries a `sidecar` of what else the delete touched:

  | Delete | Side effect | Sidecar |
  | --- | --- | --- |
  | Customer | Zeroes `customerId` on their orders | `unlinkedOrderIds` — re-linked on restore, skipping orders since deleted |
  | Product (soft) | Sets `isActive = false` | `softDeleted: true` — restore flips the flag on the *current* row, preserving edits made since |
  | Product (hard) | Also wipes the product's StockMovements | `softDeleted: false` + the movement JSONs |
  | Expense, Category | None | `{}` |

- `capture()` runs **inside the delete's own `writeTxn`**, so the trash entry and the delete can never diverge. `restore()` likewise runs the payload put + side-effect reversal in a single transaction.
- **Two UX layers:** a 10-second `showUndoSnackBar` (in `context_extensions.dart`) on each delete, and Settings → Recycle Bin for the full 30-day window. The snackbar is only a convenience — MIUI's known SnackBar-timer stall (the quirk that made `pdf_saved_sheet.dart` own its `Timer`) is harmless here, since the record is recoverable from the bin either way.
- **Phase A covers expense, category, customer, product.** Order, purchase and supplier still delete permanently — their reversal touches stock, variant stock, movements and party stats. `TrashService.restore` throws `UnsupportedError` for those kinds and the bin renders them with restore disabled, so no path offers an action that would fail.
- **Both bulk-clear paths clear the trash too** — `LocalBackupService.decodeAll` and Settings → Clear All Data. `decodeAll` clears the backed-up collections *explicitly* (not `isar.clear()`), so without this a surviving `trashEntries` row would reference ids from the replaced dataset and restoring it would corrupt live data. Trash is deliberately **not** part of the backup payload.
- `purgeExpired()` runs post-first-frame from `app.dart`, wrapped in a try/catch — a failure must never block startup.

### CSV Export

- Export orders, products, or expenses as CSV files via share_plus
- Export buttons available in all three list screens

### Bulk Product Import

- Pick CSV file via file_picker (expected columns: Name, SKU, Category, Selling Price, Cost Price, Stock, Threshold)
- Parse with validation and error reporting
- Confirmation dialog shows count + any skipped rows before importing

### Dashboard due info

All from the Due Book's providers (`duesProvider` → `dueSummaryProvider`, plus `duesCollectedThisMonthProvider`), so dashboard and Due Book can't disagree. The old `DashboardStats.unpaidTotal` (counted return orders) and `unpaidOrdersProvider` (listed cancelled orders) were removed.

- **Stat cards**: *Total Receivable* and *Dues collected (this month)* — both open `/dues`. "Collected" = payments dated this month on a **later day** than their order (pay-at-sale excluded); refunds are ignored, not subtracted, since a refund of a pay-at-sale order was never counted (`duesCollectedBetween`). Other stat cards are tappable too via a `route` field.
- **Due Book section card** (`DueSummaryCard`) replaces the old unpaid-orders list.
- **60+ days banner** (amber, only when someone owes for 60+ days) → `/dues?age=60`, which opens the Due Book pre-filtered. The `/dues` route is keyed on its URI so the query re-applies even though the branch keeps state.

### Notifications

- **Low stock alerts:** triggered when products fall below threshold
- **Payment reminders:** triggered for unpaid orders
- Checked when the dashboard first loads and on pull-to-refresh — not on the recompute every order change triggers (`!ref.isReload`), which would notify on each save. `checkAndNotify` does nothing if `init()` never completed

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

### Rating Prompt (Play in-app review)

- Ported from the Fuel Cost app. `ReviewService` (rules) + `RateAppDialog` (gate: **Rate now / Later / No thanks**) — only sellers who choose "Rate now" see Google Play's review sheet (stars + optional written review).
- **When:** Dashboard post-frame, only if the showcase tour is done, the seller has **≥ 5 real sales orders** (no returns, no cancelled), the back-off allows it, and `InAppReview.isAvailable()` is true (so we never ask and then do nothing on iOS/desktop/non-Play installs). 1.2 s delay after load.
- **Back-off** (SharedPreferences `review_prompt_*`, per-device — not in the backup): Later or dismiss = 30-day snooze, max 3 asks; Rate or No thanks = never again.
- **Settings → About → Rate this app** opens the sheet directly (no gate) or the store listing. The About section also shows the real version (`PackageInfo`) — it used to be a hardcoded `1.0.0`.
- Google only shows the sheet for builds **installed from Play** (e.g. internal testing) and enforces a silent quota — no sheet in debug is expected.

### In-App Update (Play Store)

- Checks for Play Store updates when dashboard loads
- **Immediate update** forced for critical versions (priority >= 4)
- **Flexible update** for normal versions (downloads in background, prompts to install)
- Silent failure — never disrupts user if check fails
- Android-only (skips on other platforms)

### Local Backup Export/Import

- **Export:** Saves all 10 backed-up collections as a timestamped JSON file via share sheet
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

Initial route is `/splash` (animated splash screen), then navigates to `/` (dashboard shell). 14 branches via `StatefulShellRoute` with a responsive sidebar (icon-only <600px, expanded with labels >=600px). Tooltips on icons when collapsed. Wrapped in `SafeArea`.

| Route         | Path             | Sub-routes                                                                                  |
| ------------- | ---------------- | ------------------------------------------------------------------------------------------- |
| Splash        | `/splash`        | — (initial route, auto-navigates to `/`)                                                    |
| Dashboard     | `/`              | —                                                                                           |
| Products      | `/products`      | `catalog`, `add`, `:id`, `:id/edit`                                                         |
| Orders        | `/orders`        | `add`, `:id`, `:id/edit`                                                                    |
| Returns       | `/returns`       | `:id`                                                                                       |
| Customers     | `/customers`     | `add`, `:id`, `:id/edit`                                                                    |
| Due Book      | `/dues`          | — (branch 13; customer detail via `/customers/:id`)                                         |
| Scanner       | `/scanner`       | — (scan QR/barcode → view matching product, or add it as new)                               |
| Inventory     | `/inventory`     | `adjust/:id`                                                                                |
| Suppliers     | `/suppliers`     | `add`, `:id`, `:id/edit`, `:id/purchase/add`, `purchases`, `purchases/add`, `purchases/:id` |
| Expenses      | `/expenses`      | `add`, `:id/edit`                                                                           |
| Cash Register | `/cash-register` | —                                                                                           |
| Categories    | `/categories`    | —                                                                                           |
| Reports       | `/reports`       | —                                                                                           |
| Settings      | `/settings`      | `sidebar-order`, `recycle-bin`                                                              |

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
- **Shop name as primary brand:** `Settings.shopName` (default "My Shop") replaces `AppStrings.appName` in three live-rendering surfaces — `MaterialApp.title` (OS task switcher), Splash Screen hero text, Dashboard SliverAppBar title — each falls back to "Micro Seller" if the shop name is empty. The PDF invoice watermark intentionally stays as "Powered by Micro Seller" (brand attribution, not the user's shop).
- **Language:** 12 languages with in-app language switcher (English, Bengali, Arabic, Spanish, French, Portuguese, Turkish, Indonesian, Thai, Vietnamese, Urdu, Malay)
- **Colored sidebar icons**: every `SidebarItem` has its own `color` (dashboard teal, products indigo, orders blue, returns deep orange, customers purple, Due Book amber-orange, inventory brown, suppliers cyan, expenses red, cash register green, categories pink, reports deep purple, scanner blue-grey, settings grey). `_tile` tints the icon with it (75% when unselected), and the selected tile's background and label too; dark mode lerps each color 25% toward white for contrast. Sidebar Order screen uses the same colors.
- **Responsive sidebar navigation**: icon-only rail (56px) on phones (<600px), expanded with labels (200px) on tablet/desktop (>=600px). Tooltips on collapsed icons. Wrapped in SafeArea.
- **Sidebar customization** lives under its own **"Sidebar"** section header on the Settings screen (separate from Theme / Language / Shop): drag-reorder tabs (Settings → Sidebar Order screen; `reconcileSidebarOrder` slots a newly added tab after its default predecessor so existing users see it in place, not below Settings), per-tab visibility toggle (`CupertinoSwitch`), and a **left/right position** picker on the main Settings screen. The position picker is a custom `_SidebarPositionToggle` widget (in [settings_screen.dart](lib/features/settings/presentation/settings_screen.dart)) — a compact pill-rounded two-icon segmented control that fits inside `ListTile.trailing` without forcing the title onto a second line. Active side fills with `cs.primary`; inactive ghosts to 55% `onSurface`. Material 3 `SegmentedButton` was tried first but its mandatory label+icon padding was too wide. The position swap itself is just a `Row.children` reorder in `_NavigationShell` — not two separate layouts. `Settings.toggleSidebarItemHidden('settings', _)` is a hard no-op and the Settings row's switch is rendered disabled, so the user can never lock themselves out. All three knobs (`sidebarOrder`, `hiddenSidebarItems`, `sidebarPosition`) are part of the backup payload via `exportSettings()` / `importSettings(map)`.
- **Responsive layouts throughout**:
  - Dashboard: stat cards via `Wrap` + `LayoutBuilder` (2-6 cols based on `width/170`); charts side-by-side on wide screens; date-range filter bar
  - Product grid: responsive columns via `LayoutBuilder` (`width/180`, clamp 2-6)
  - Order card: compact column on phone, single-row layout on tablet (>=600px)
  - Inventory: category filter + sort dropdown bar; **per-variant stock display**
- **Dashboard charts**: Weekly sales bar chart, order status pie chart, revenue vs expenses line chart
- **Dashboard SliverAppBar**: `title:` ("Micro Seller") always shown; `expandedHeight: 160`; `flexibleSpace` holds greeting + date pill + today's revenue/total-orders stats with top padding `kToolbarHeight + 8` so content sits below the toolbar layer. Title remains visible when collapsed.
- **Reports screen**: four tabs over one date range — **Profit & Sales** (P&L statement, net sales chart by day or month, sales by payment method, orders by status, top products / categories / customers), **Dues & Payments** (money received by method, dues collected, credit given, refunds; receivable + aging *as of today*; top debtors), **Stock & Returns** (stock value at cost / selling price, potential profit, movements by type, best sellers, not-sold-in-period, return reasons), **Purchases & Expenses** (purchased / paid / unpaid, owed to suppliers today, top suppliers, expenses by category, cash register cash in/out and over/short). Export shares the current tab as PDF (Unicode-safe) or CSV (UTF-8 BOM for Excel).
- **Report accounting rules**: returns count when their goods are back (`returnStatus` received/refunded), dated `updatedAt ?? createdAt`, and are *subtracted* (the old single-page report added them to revenue). Gross sales are goods at list price; order discounts are their own row; returns are valued at `netGoods` (after their discount share, without tax). Tax is shown as "Tax collected", never sales; delivery is added after gross profit. Sales by payment method, top customers and average order value stay on billed `totalAmount`. Net margin is 0 when net sales ≤ 0 (a ratio over a negative base flips sign). COGS uses `OrderItem.costPrice`, falling back to the product's current cost when 0, and returned items reverse their COGS. Stock value, receivable and supplier dues are point-in-time ("as of today"). Returns against a cancelled original are ignored (the cancel already removed the sale). Pending orders count as sales (same as the Due Book). "Owed to suppliers" = Σ `Supplier.totalDue` + unlinked purchases' `balanceDue` (direct supplier payments don't touch purchases). Cancel reversals (`Payment.note == kCancelledPaymentNote`) net out of money received; "Refunds paid" is return refunds only. Known trade-offs: a return is dated `updatedAt`, so refunding it later moves it to the refund date; legacy zero-cost items use today's product cost. `ReportTable` cells are String/int/double — money stays numeric in CSV (formula-like text is apostrophe-escaped), and `formatCell` formats it for the PDF.
- **Reports header** (was SliverAppBar-only): `NestedScrollView` + pinned `SliverAppBar` (`expandedHeight: 150`, range chips + date line in `flexibleSpace`, scrollable `TabBar` in `bottom`). Previously: `title:` ("Reports") always shown; `expandedHeight: 120`; `flexibleSpace` holds the start/end date chips with same `kToolbarHeight + 8` top padding pattern.
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

## Claude Code tooling (`.claude/`)

| Kind | Name | Use it for |
| --- | --- | --- |
| Skill | `l10n` | Any visible string: en key → `_L10nStrings` getter → 11 locales → `scripts/l10n_parity.sh` (exit 0 required) |
| Skill | `new-collection` | Adding an Isar model — `kIsarSchemas`, backup encode/decode + version bump, Clear All Data, trash decision |
| Skill | `new-screen` | Screen / route / notifier conventions (keepAlive, writeTxn, sub-route before `:id`, shared widgets) |
| Skill | `verify` | After any change: build_runner (if needed) → `flutter analyze` → l10n parity |
| Skill | `release` | `/release` only — version bump, obfuscated AAB, 16 KB alignment check |
| Skill | `sync-docs` | Keep this file matching the code after a feature |
| Agent | `invariant-reviewer` | Read-only review of a diff against the money/stock/backup invariants above |
| Agent | `translator` | Fill the 11 non-English locale files for new keys |

`AppLocalizations.tr` falls back to English, then to the raw key — a missing key shows English, but parity is still required.
