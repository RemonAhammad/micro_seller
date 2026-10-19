# Micro Seller (SellerBook) — Project Context

A Flutter inventory & order management app for micro/small sellers. Local-first with optional Google Drive backup.

## Tech Stack

- **Flutter** (SDK >=3.8.0 <4.0.0; built with **Flutter 3.44.9**, see Build & Release → Toolchain)
- **State Management:** Riverpod 3 (`flutter_riverpod ^3.0` + `riverpod_annotation ^4.0` + `riverpod_generator ^4.0`). Notes: (1) Riverpod 3 uses plain `Ref` everywhere (no per-provider `XxxRef` typedefs), and `@riverpod class XxxNotifier` generates `xxxProvider` (no `Notifier` infix). `AsyncValue.value` is now nullable; `valueOrNull` is gone. (2) **All CRUD notifiers must be `@Riverpod(keepAlive: true)`** — Riverpod 3 auto-disposes by default, and a `ref.read(xxxProvider.notifier).method()` call from a screen disposes the provider during the await. Post-await `state = ...` then throws `UnmountedRefException`. This applies to product / order / customer / supplier / expense / category / cash_register notifiers.
- **Database:** Isar 3.3 via the community fork — `isar_community` + `isar_community_flutter_libs` + `isar_community_generator` ^3.3.2. The original `isar` package was abandoned in 2023 and shipped 4 KB-aligned native binaries that Play Store rejects on Android 15+. The community fork is API-identical; storage format is byte-compatible (no on-device migration).
- **Navigation:** GoRouter with `StatefulShellRoute` (14-branch sidebar navigation)
- **Code Generation:** Freezed 3 (`freezed ^3.2.5` + `freezed_annotation ^3.1`). Note: freezed 3 requires `abstract class Foo with _$Foo` (the `abstract` keyword is mandatory). JSON serializable + isar_community schema generator.
- **Security:** `local_auth` (biometric) + `crypto` (SHA-256 PIN hashing). `AuthGateService` + `runAuthGate(context, reason: ..., fingerprintEnabled: ..., pinEnabled: ...)` helper protect destructive actions. PIN is stored in SharedPreferences as `sha256(salt + pin)` with a per-install salt. Android: `MainActivity` extends `FlutterFragmentActivity` (required by local_auth's BiometricPrompt) and the manifest declares `USE_BIOMETRIC`. Two-layer gate: (1) **`.env` build-time visibility** — `ENABLE_FINGERPRINT_GATE` / `ENABLE_PIN_GATE` (default `true`) control whether each toggle is shown in Settings → Security at all, and `runAuthGate` ignores any path whose `.env` flag is false; (2) **user setting** — `securityFingerprintEnabled` / `securityPinEnabled` in SharedPreferences (default `true`) control whether the user has each path active. Each toggle in Settings is verified independently — flipping fingerprint requires verifying *current fingerprint only* (never PIN), flipping PIN requires verifying *current PIN only*. Enabling PIN runs `runPinSetup` (fresh setup); disabling clears the stored PIN. `runAuthGate` chooses biometric if (env+user+device-available), else PIN if (env+user+stored), else passthrough.
- **PDF:** `pdf` + `printing` + `flutter_image_compress`. A Flutter widget is captured to PNG by `widget_capture.dart` (guaranteed Unicode shaping) and `pdf_assembly.dart` builds the A4 `pw.Document` on a background isolate. `widget_capture.dart` is a trimmed copy of the `screenshot` package's capture. `screenshot` is still listed in `pubspec.yaml`, but nothing in `lib/` imports it.
- **File open:** `open_file` package. The post-download bottom sheet uses it to hand a saved invoice PDF to the system PDF viewer. The sheet replaced an earlier SnackBar flow because Material's SnackBar duration was unreliable on MIUI / Xiaomi devices (the timer paused indefinitely). `lib/shared/widgets/pdf_saved_sheet.dart` is a modal sheet with an Open action that runs its own `Timer(Duration(seconds: 15))` for a guaranteed auto-dismiss.
- **Cloud:** Google Sign-In **7** + Google Drive API (`googleapis` 17) for backup/restore. v7 splits authentication (`GoogleSignIn.instance.authenticate()`, UI) from authorization (`authorizationClient.authorizationForScopes` — no UI — / `authorizeScopes`). `DriveService` only needs authorization for Drive calls, so background/startup paths (`hasDriveAccess()`, `_getDriveApi(interactive: false)`) never show UI. **On Android without google-services.json, v7 requires the *web* OAuth client id as `serverClientId`** — read from `GOOGLE_OAUTH_WEB_CLIENT_ID` in `.env` by `DriveService._ensureInitialized()`; if it's empty, sign-in fails with a configuration error.
- **Charts:** fl_chart for dashboard sales visualization + reports + customer history
- **Notifications:** flutter_local_notifications for low stock & payment alerts
- **CSV:** `csv` + `file_picker` for import/export
- **Localization:** flutter_localizations + custom delegate (12 languages: en, bn, ar, es, fr, pt, tr, id, th, vi, ur, ms)
- **Persistence:** SharedPreferences for app settings
- **Env config:** `flutter_dotenv` loads `.env` at startup (OAuth client IDs, gitignored; `.env.example` is the tracked template)
- **Onboarding:** showcaseview v5 for first-time guided tour
- **In-App Update:** in_app_update for Play Store auto-update prompts
- **Icons:** the **whole app** uses thin Tabler line icons (`tabler_icons_next`, SVG via `flutter_svg`) — no Material `Icons.*` / `Icon(...)` anywhere in `lib/`. Use `ThinIcon(tabler.Plus.new, size:, color:)` (a drop-in for `Icon`, defaults from `IconTheme`; like `Icon`, it draws at its own size centered in a bigger forced box, so no call site needs a `Center`) with `import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;`. Icons are Tabler **constructor tear-offs** (`tabler.Box.new`), typed `ThinIconBuilder`; they're compile-time constants, so `const ThinIcon(...)` and `const` lists work. Widgets that take an icon (`EmptyState`, `ConfirmDialog`, `AppButton`, `StatCard`, `SidebarItem`, …) take a `ThinIconBuilder`, not `IconData`. Shared named icons live in `AppIcons` ([app_icons.dart](lib/core/constants/app_icons.dart)). Stroke `kIconStroke = 1.25` (`kIconStrokeSelected = 1.75` for the active sidebar tab; Tabler's default is 2.0). The theme's `actionIconTheme` swaps Flutter's own back / drawer / close buttons for Tabler too (back arrow flips in RTL). History: `phosphor_flutter` 2.1.0 doesn't compile on Flutter 3.44 (extends the now-`final` `IconData`); Lucide and Fluent were judged too bold. `flutter_svg` is a direct dependency only so `main()` can set `svg.cache.maximumSize = 300`. The app draws about 140 distinct (icon, stroke) SVGs, and with the default limit of 100, evicted icons were re-parsed on an isolate and appeared a frame late. `warmThinIcons` (in `app_icons.dart`) pre-parses the sidebar icons at both strokes, plus `AppIcons.dashboardSet`, after the first frame.
- **Package versions (upgraded 2026-09-30 to latest for Flutter 3.44):** share_plus 13 (`SharePlus.instance.share(ShareParams(...))` — `Share.share` is deprecated), file_picker 13 (static `FilePicker.pickFile` / `getDirectoryPath`; read `PlatformFile.readAsBytes()` because SAF content URIs have no path), csv 8 (`csv.encode` / `csv.decode`), fl_chart 1.x (`tooltipBorderRadius`), local_auth 3 (`authenticate(biometricOnly:, persistAcrossBackgrounding:)` — no `AuthenticationOptions`), flutter_local_notifications 22 (named `initialize(settings:)` / `show(id:, title:, body:, notificationDetails:)`), go_router 18, mobile_scanner 7, package_info_plus 10, in_app_update 5, open_file 4, flutter_dotenv 6, flutter_lints 6. After a major plugin upgrade run `flutter clean` — a stale Gradle Kotlin cache made share_plus 13 fail to compile until cleaned.
- **Other:** image_picker, mobile_scanner v7 (QR), url_launcher, intl

## Architecture

Feature-based modular structure with repository pattern:

```text
lib/
├── main.dart                     # Entry point: .env ∥ SharedPreferences, currency init, `TutorialService.primeFrom` + `DisplayScale.primeFrom` (so the first frame is already at the saved Display / Text size), portrait-only, SVG cache size, ProviderScope; notification init (awaited before runApp on iOS only); icon warm-up + Workmanager after the first frame (see Performance → Startup)
├── app.dart                      # Root MaterialApp, theme (light/dark/system), GoRouter, Isar warmup, localization. Watches only themeMode / language / shopName via `select`. `builder` wraps the Router in `_DisplayScaleScope` → `AppZoom` (Display size / Text size); its own widget, so a size change rebuilds only the zoom, not MaterialApp, its theme and the Router. Post-first-frame: `purgeExpired()`, plus the auto-backup catch-up 15 s later
├── core/
│   ├── constants/
│   │   ├── app_colors.dart       # Teal primary (#00897B), status/payment colors
│   │   ├── app_icons.dart        # `ThinIconBuilder`, `ThinIcon` (drawn at its own size, centered in whatever box its parent forces — `_CenteredIcon`, as `Icon` centers its glyph; the SVG fills the box it gets, so a text field's 48 dp prefix slot used to draw a 20 dp icon at 48; the whole box still takes hits), stroke constants, `AppIcons` (+ `dashboardSet`), `warmThinIcons` (SVG cache warm-up)
│   │   ├── app_sizes.dart        # Spacing, radius, icon size tokens
│   │   ├── app_strings.dart      # 100+ string constants (localization-ready)
│   │   └── sidebar_items.dart    # `SidebarItem` (stable key, branchIndex, icon, color), `sidebarItems`, `reconcileSidebarOrder`
│   ├── extensions/
│   │   └── context_extensions.dart  # Theme, snackbar, confirm dialog shortcuts
│   ├── l10n/
│   │   ├── app_localizations.dart   # Custom LocalizationsDelegate (12 locales)
│   │   ├── translations_en.dart     # English (~180 keys, source of truth) + parameterized helpers
│   │   └── translations_<bn|ar|es|fr|pt|tr|id|th|vi|ur|ms>.dart  # Same keys, translated
│   ├── router/
│   │   └── app_router.dart       # GoRouter config (`initialLocation` is `/splash` only until the splash has been shown), 14-branch sidebar navigation shell, SafeArea wrapper. The shell watches only `sidebarPosition`, and the sidebar only the order and hidden set, via `select`. The shell also runs the first-run sidebar tour (see First-Time Showcase Tour)
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
│   │   ├── customer.dart         # id, name (@Index value — the customers list's name order), phone, address, tag(new/regular/vip), stats
│   │   ├── expense.dart          # id, title, amount, category(logistics/packaging/marketing/supplies/other), date (@Index)
│   │   ├── order.dart            # id, orderNumber, customer info (@Index customerId), items, totals, payment/order status, paymentMethod, delivery, recurring, return fields, @Index createdAt. Also `orderTotals` (the form's tax/total, rounded to 2 decimals), `returnValueFor` (what returning items is worth) and `roundMoney`
│   │   ├── order_item.dart       # @embedded: productId, name, sku, qty, unitPrice, costPrice, totalPrice, variantCombinationKey, variantDisplayLabel
│   │   ├── product.dart          # id, name, sku, prices, stockQty, category, qrCode, isActive, variantAttributes, variantCombinations. Composite index (isActive, name as a value index) — the products list's where-clause
│   │   ├── product_variant.dart  # @embedded (deprecated): flat name/value/priceAdjustment/stockQty/sku
│   │   ├── variant_attribute.dart # @embedded: name, options[] — defines one dimension (e.g. Size→[S,M,L])
│   │   ├── variant_combination.dart # @embedded: combinationKey, displayLabel, priceAdjustment, stockQty, sku, isActive
│   │   ├── supplier.dart         # id, name, phone, email, address, company, notes, totalPurchases, totalPaid, totalDue
│   │   ├── purchase.dart         # id, supplierId, supplierName, items (embedded PurchaseItem), totalAmount, amountPaid, paymentMethod, notes, referenceNumber
│   │   ├── cash_register.dart    # id, openingAmount, closingAmount, totalSales, totalExpenses, totalCashIn, totalCashOut, isClosed, openedAt, closedAt
│   │   ├── payment.dart          # @Index customerId + orderId + paidAt, amount (negative = refund), method, transactionId, note, groupId — history log behind Order.amountPaid
│   │   ├── stock_movement.dart   # id, productId (@Index), type(sale/restock/adjustment/damage), qty, reason, createdAt (@Index)
│   │   └── trash_entry.dart      # kind(TrashKind), originalId, payload(JSON), sidecar(JSON), label, sublabel, deletedAt. `@Collection(accessor: 'trashEntries')` — the default pluralisation would be `trashEntrys`.
│   ├── repositories/
│   │   ├── customer_repository.dart   # CRUD, search, watchAll stream
│   │   ├── expense_repository.dart    # CRUD, date range, monthly totals
│   │   ├── order_repository.dart      # CRUD + createOrder (stock deduction, customer stats), markAsPaid
│   │   ├── product_repository.dart    # CRUD, watchLowStock, adjustStock (creates StockMovement)
│   │   └── stock_repository.dart      # CRUD, watchByProduct
│   └── services/
│       ├── csv_export_service.dart  # Export orders/products/expenses/report tables as CSV via share_plus. CSV + UTF-8 encoding runs in `compute` (rows hold only plain values)
│       ├── csv_import_service.dart  # Import products from CSV via file_picker
│       ├── migration_service.dart  # One-time migration: flat variants → hierarchical VariantAttribute + VariantCombination
│       ├── drive_service.dart       # Google Drive backup/restore via LocalBackupService (all 10 backed-up collections). Backup bytes are encoded on a worker (`encodeOnWorker: false` for the WorkManager isolate) and uploaded with `ResumableUploadOptions` in 8 MB chunks; multipart would base64 the whole file at once. Download is joined with `BytesBuilder(copy: false)`. `restoreFromBytes` (@visibleForTesting) does snapshot → restore → rollback. Typed DriveBackupException + DriveErrorCode, max 5 backups, full error/stack logging via dart:developer
│       ├── isar_service.dart        # Riverpod provider (keepAlive), opens DB with `kIsarSchemas` (11 schemas) and `compactOnLaunch` (≥ 20 MB file, ratio 2; it only rewrites a file that is mostly free space, e.g. after a big restore or Clear All Data). The auto-backup worker and every `runDbJob` worker open the same file with the **same constant**. A hand-kept copy in the worker once fell behind and was missing TrashEntrySchema. Also runs one-time migrations (`migrateVariantsV2`, `migrateOutstandingBalancesV1`).
│       ├── db_worker.dart           # `runDbJob(isar, job)` — runs a synchronous Isar job on a worker isolate (see Performance). `dbWorkerCoreLibrary` (@visibleForTesting) is the Isar core path for tests. Conditional import of `db_worker_core_ffi.dart` (loads the core with `dart:ffi`) / `db_worker_core_stub.dart` (no-op), so web still compiles
│       ├── isar_reload.dart         # `reloadOn(changes, load)` + `mergeChanges(streams)` — the replacement for `watch(fireImmediately: true)` in list providers (see Performance)
│       ├── isar_revisions.dart      # keepAlive change counters bumped by `watchLazy()`: `ordersRevisionProvider`, `customersRevisionProvider`, `productsRevisionProvider`, `expensesRevisionProvider`, `paymentsRevisionProvider`
│       ├── backup_format.dart       # `kBackupVersion` (4) + `buildBackupMap(...)` — the backup JSON envelope. Pure Dart, so `tool/gen_perf_backup.dart` builds through it too
│       ├── dues_service.dart        # `computeOrderDues` (effective due per order, oldest first — subtracts refunded returns), `computeNetDue`, `kDueEpsilon`, `duesCollectedBetween`. Balance recalculation comes as an async `recalculateOutstandingBalancesInTxn` and a sync `…InTxnSync`. Both load all customers and one id-ordered filter over orders, grouped in Dart, then `putAll`. `recalculateOutstandingBalancesJob` / `recalculateOutstandingBalances(isar)` run the whole thing in one write txn on a worker. `migrateOutstandingBalancesV1` uses the async variant on purpose: opening the DB must not depend on a worker isolate being able to open it
│       ├── report_service.dart      # Pure report builders (no Isar): buildSalesReport (P&L: gross sales at list price → discounts → returns → net sales → COGS → gross profit → + delivery → expenses → net profit; tax collected shown, never profit; also feeds the Dashboard's profit), buildDuesReport, buildInventoryReport, buildPurchasesReport. Each report has toTables(tr) → List<ReportTable>, the single shape CSV and PDF export from.
│       ├── report_pdf_service.dart  # Paginated widget→PNG→PDF for a report's tables (repeats table headers across pages). Full-canvas pages become JPEG; a table-less page is only as wide as its header text, so it stays PNG
│       ├── statement_service.dart   # Customer statement: `buildRows` (running ledger: orders debit; payments + refunded returns credit; unlogged legacy payments inferred per order) + paginated widget→PNG→PDF (26 rows/page, 794×1123, JPEG pages)
│       ├── catalog_service.dart     # Shareable product catalog. Same widget→PNG→PDF pipeline as pdf_service (Skia/HarfBuzz for Unicode). `generateCatalogImage` (single-page PNG for chat), `generateCatalogPdf` (paginated, 6 tiles/page in a fixed 794×1123 A4 canvas, JPEG pages), `generateCatalogText` (plain price list). Photos are decoded one at a time to `ui.Image` at tile size × pixelRatio (`decodeImageForBox`, cover, never upscaled) and drawn with `RawImage`. An image widget decodes asynchronously, so the off-screen capture raced it: blank tiles, or a second capture plus a long wait. The placeholder icon is rasterized once per run, so the capture delay is 100 ms. Each PDF page's photos are disposed after capture
│       ├── pdf_assembly.dart        # `assemblePdf(pages, jpegPages:)` — builds the A4 PDF in `compute`. `pw.MemoryImage` decodes PNGs in pure Dart inside `save()`, about 0.5–1.5 s per page on a low-end phone, which used to freeze the spinner. Pages exactly `jpegPages` pixels in size are re-encoded to JPEG q75 first (`flutter_image_compress`, embedded as-is; q75 keeps chat-shared files small). Only full-canvas, opaque-white layouts qualify because JPEG has no alpha. Pages stay PNG where the encoder is unavailable (Linux / Windows)
│       ├── widget_capture.dart      # `captureWidgetPng(widget, targetSize:, pixelRatio:, delay:)` — a trimmed copy of `screenshot`'s capture. It retakes up to 4 captures while the tree is dirty, then **unmounts** the off-screen tree; screenshot never unmounted, so every captured page stayed in memory. Also `decodeImageForBox` (decode at draw size for `RawImage`)
│       ├── trash_service.dart       # Soft-delete store behind the undo snackbar + Recycle Bin. Generic over all models (every one has toJson/fromJson). `capture()` is called inside the delete's own writeTxn; `restore()` dispatches on TrashKind and reverses side effects from the entry's `sidecar`; `purgeExpired()` drops entries older than `kTrashRetention` (30 days), called post-first-frame from app.dart.
│       ├── local_backup_service.dart # Backup encode/restore for all 10 backed-up collections (everything except `trashEntries`; v4 adds `payments`, older backups restore with an empty payment history). Synchronous core for worker jobs: `encodeBackupBytesSync` (one read txn → `buildBackupMap` → `JsonUtf8Encoder`), `parseBackupBytes` / `validateBackupMap` (throw `InvalidBackupException` before anything is written; `requireMetadata` for Drive), `restoreBackupSync` (rows parsed *before* one write txn: clear all → putAll → `recalculateOutstandingBalancesInTxnSync`), `clearAllCollectionsInTxnSync` (all 10 + trash, shared by restore and Clear All Data so they can't drift). `LocalBackupService.encodeAllBytes` / `restoreBytes` / `clearAll` run these through `runDbJob`. `exportBackup` / `exportToDirectory` / `importBackup` use them. `encodeAll` / `decodeAll` (String, calling isolate) remain for tests and tools
│       ├── notification_service.dart # Low stock alerts + unpaid order reminders via flutter_local_notifications. `init()` is memoized (one shared future). `checkAndNotify(isar, lowStock:)` awaits it and returns quietly if init never started or failed. It reuses the dashboard's low-stock list and counts unpaid orders natively (`count()`), since the text only needs the number
│       ├── tutorial_service.dart    # SharedPreferences flags: splash_shown, tour_completed; resetAll(). `primeFrom(prefs)` (main, before runApp) fills the synchronous `splashShown` the router's `initialLocation` reads
│       ├── auth_gate_service.dart   # Biometric (local_auth) + 4-digit PIN (SHA-256 with per-install salt, stored in SharedPreferences). Used to gate destructive actions like Clear All Data. Two-layer control: `.env` (`ENABLE_FINGERPRINT_GATE` / `ENABLE_PIN_GATE`) gates each toggle's *visibility* in Settings → Security; user settings (`securityFingerprintEnabled` / `securityPinEnabled`) control whether each path is *active*. Each toggle is verified independently against its own auth method only.
│       ├── auto_backup_runner.dart  # Two surfaces: (a) `runIfDue()` fires once on app startup (15 s after the first frame, fast catch-up) and (b) a top-level `autoBackupCallbackDispatcher` registered with WorkManager runs at **00:05 local time daily** in a separate isolate (Android only). Implemented as a self-rescheduling chain of `registerOneOffTask` calls (with `initialDelay = duration to next 00:05`) rather than `registerPeriodicTask`, because WorkManager's periodic API only promises an interval, not a clock time. The worker re-opens Isar from disk, calls `DriveService.backupToDrive(interactive: false, encodeOnWorker: false)` with a `_exportSettingsFromPrefs` snapshot (it already runs on a UI-less isolate, so it encodes in place), writes `lastBackupTime` on success, then re-registers itself for the next 00:05. On revoked access (`notSignedIn` / `signInFailed` / `developerError`) the worker writes `kAutoBackupErrorKey` to SharedPreferences, fires `NotificationService.showAutoBackupPaused()` *once* (subsequent revoke runs skip the notification to avoid spam), and stops the chain — the Settings → Drive banner re-arms it after the user signs back in. `scheduleAutoBackup({replace})` / `cancelAutoBackup()` static helpers register/cancel the chain. The Settings toggle uses `ExistingWorkPolicy.replace`. `main.dart` calls it after the first frame with `replace: false` (`keep`), because replacing on every cold start re-enqueued the pending run and could cancel one that was running.
│       ├── review_service.dart      # Rating prompt (ported from Fuel Cost): eligibility (≥5 real sales orders), back-off (Later = 30-day snooze, max 3 asks; rate/decline = never again), requestReview() → Play in-app review sheet or store listing
│       ├── update_service.dart      # In-app update via Play Store (immediate for critical, flexible for normal)
│       └── pdf_service.dart         # Order invoice PDF + WhatsApp text. Renders the receipt as a Flutter widget tree (`_ReceiptWidget`) and captures it to a PNG via `captureWidgetPng` (Skia + HarfBuzz → full Unicode shaping for Bengali conjuncts, Arabic ligatures, Thai/Devanagari/CJK, color emoji), then `assemblePdf` embeds it in a single-page A4 `pw.Document`. The receipt is sized to its content, not a full page, so it stays PNG. Bottom-right "Powered by ⬡ Micro Seller" watermark. Its icon is decoded once per session at draw size (`loadPdfWatermarkIcon`, 16 px × `kPdfCapturePixelRatio` 2.0) and drawn with `RawImage`; every PDF service shares it. Trade-off: PDF text is rasterised, not selectable — accepted for guaranteed Unicode correctness. Earlier `pw.Document`-only and `Printing.convertHtml` paths were tried and failed (broken Indic shaping / WebView hangs respectively).
├── features/
│   ├── categories/
│   │   ├── presentation/category_screen.dart      # List + add/edit/delete dialogs
│   │   └── providers/category_provider.dart        # Stream + notifier (ensureExists)
│   ├── customers/
│   │   ├── presentation/
│   │   │   ├── customer_list_screen.dart           # Search by name/phone (debounced)
│   │   │   ├── customer_form_screen.dart           # Add/edit with tag selector
│   │   │   ├── customer_detail_screen.dart         # Live stats (`customerByIdProvider`), Collect / Remind / Statement actions, payment history, paged order history (`customerOrdersProvider`), 6-month purchase chart (`customerMonthlySpendingProvider`). Slivers, so the history only builds what's on screen
│   │   │   ├── due_book_screen.dart                # /dues (own sidebar tab, branch 13) — who owes what; sort menu (oldest / newest, largest / smallest, most unpaid orders, longest since last payment / recently paid, name A–Z / Z–A; ties → larger due first); filter sheet (age bucket <30/30–60/60+ days, customer tag, never paid / no payment in 30 days, minimum due, has phone) with live results, removable active-filter chips, badge count; summary card totals follow the filters; collect / WhatsApp remind / call, recalculate balances
│   │   │   ├── widgets/due_actions.dart            # Collect sheet (allocation preview), `sendDueReminder` (wa.me), `shareCustomerStatement` (behind `runWithProgress`; payments re-sorted by id), `PaymentHistoryTile`
│   │   │   └── widgets/customer_card.dart
│   │   ├── providers/customer_provider.dart        # `customersProvider` (name-index order, no sort), cascading delete (unlinks orders via the customerId index)
│   │   ├── providers/customer_detail_providers.dart # `customerById(id)`, `CustomerOrders(customerId)` (paged history: customerId index, then ordered in Dart — newest first, null dates last, ties by id — on a worker; `loadMore()`), `customerMonthlySpending(customerId)` (two property reads, not whole orders; `spendingByMonth`)
│   │   └── providers/dues_provider.dart            # `loadDuesSync` (worker job shared by the Due Book and the Dues report), `duesProvider` (`reloadOn` orders + customers → `runDbJob`), `dueSummaryProvider`, `duesCollectedThisMonthProvider` (paidAt index), `customerPaymentsProvider(customerId)` (customerId index, `sortByPaidAtDesc().thenById()`)
│   ├── dashboard/
│   │   ├── presentation/
│   │   │   ├── dashboard_screen.dart               # Responsive dashboard with date-range filter bar, in-app update check, rating prompt (waits for the shell's tour). Header height from `dashboardHeaderHeight(textScaler)`, stat-card slots from `statCardHeight`, so a larger font never clips them. The body is a const `_DashboardContent`: the shell resizes on every keyboard frame, even while this tab is offstage, and an identical const child is skipped. Watches `currencySymbol` / `shopName` via `select`
│   │   │   └── widgets/
│   │   │       ├── stat_card.dart                  # Compact card with icon, value, label, optional onTap (dashboard passes a `route`). The value shrinks to fit (`FittedBox`) instead of being cut mid-number. `statCardHeight(textScaler)`: 110 at the default text size, plus exactly the growth of the card's two text lines; the dashboard grid, its skeleton, the Reports KPI grid and the Display size preview all use it, so they can't drift. `measureTextWidth` (one line, as a `Text` draws it, Bold text included) for rows that choose side-by-side vs stacked
│   │   │       ├── sales_chart.dart                # SalesChart (bar), OrderStatusChart (pie), RevenueExpenseChart (line). RepaintBoundaries, and stable fl_chart callbacks (see Performance → UI)
│   │   │       ├── low_stock_list.dart
│   │   │       └── due_summary_card.dart           # Due Book on the dashboard: total receivable, aging bar (<30 / 30–60 / 60+ days, per customer by oldest due), top 3 to chase with WhatsApp remind + collect
│   │   └── providers/dashboard_provider.dart       # DashboardDateRange notifier + stats provider. It watches the date range and `ordersRevisionProvider`, so cards update without pull-to-refresh and no order list is loaded just to notice a write. All loads and arithmetic run in `dashboardStatsJob(start, end)` on a worker: one createdAt-index load covering the range ∪ the last 7 days, re-sorted by id, with `statusCounts` from a single property read. Profit = `buildSalesReport(...).grossProfit`, the Reports number. Presets are re-resolved against now by `resolveDashboardRange` (the notifier keeps the dates from when a preset was picked, stale once the app stays open past midnight), and every card uses the same `reportWindow`
│   ├── expenses/
│   │   ├── presentation/
│   │   │   ├── expense_list_screen.dart            # Month summary banner + list + CSV export button
│   │   │   ├── expense_form_screen.dart            # Date picker, category selector
│   │   │   └── widgets/expense_card.dart
│   │   └── providers/expense_provider.dart
│   ├── inventory/
│   │   ├── presentation/
│   │   │   ├── inventory_screen.dart               # 2 tabs; category filter + sort (low stock/name/qty); shows per-variant stock. The movements tab (`_MovementsTab`) is paged and watched only while that tab is built
│   │   │   ├── stock_adjustment_screen.dart        # Variant selector, pill-chip type selector, qty, reason; real-time stock via StreamBuilder
│   │   │   └── widgets/stock_movement_tile.dart
│   │   └── providers/inventory_provider.dart       # `StockMovementPages` (paged history, createdAt index desc, worker), `stockMovementsProvider` (full list, worker), `productStockMovements(productId)`
│   ├── orders/
│   │   ├── presentation/
│   │   │   ├── order_list_screen.dart              # 5 tabs (`OrderTab`), each paged via `orderPagesProvider(tab)`, with count badges from `orderTabCountsProvider`. Long-press status change. CSV export loads every order (`loadAllOrdersNewestFirst`), not just the loaded pages
│   │   │   ├── order_form_screen.dart              # Create + Edit mode, variant-aware product picker, per-order tax/VAT field, stock validation, payment method, delivery, recurring. Totals parsed once into `_FormTotals` and redrawn by `ListenableBuilder`s on the money fields, so a keystroke doesn't rebuild the form
│   │   │   ├── order_detail_screen.dart            # Status stepper (hidden for returns), cancel order action, payment, share/print/PDF, edit, return order, delivery tracking. Reads `orderByIdProvider`. The receipt PDF is rendered once (behind `runWithProgress`) and reused by Share / Print / Download, keyed on order id + `updatedAt` + the shop settings it prints
│   │   │   └── widgets/
│   │   │       ├── order_card.dart                 # Responsive: compact on phone, row on tablet. The long-press status menu converts the press point into the branch Navigator overlay's coordinates (beside the rail, under the status bar, zoomed), so it opens at the finger
│   │   │       ├── order_item_row.dart             # Shows variant info via displayName
│   │   │       └── order_status_badge.dart         # Text-only badges (no icons), PaymentStatusBadge
│   │   ├── providers/order_pages_provider.dart     # `kOrderPageSize` (100), `OrderTab` enum (statuses per tab; regular orders only), `OrderPages(tab)` (keepAlive; createdAt index desc + `limit(n + 1)` on a worker; `loadMore()`), `orderTabCountsProvider` (native `count()` per tab), `loadAllOrdersNewestFirst` (CSV export)
│   │   └── providers/order_provider.dart           # `returnOrdersProvider` (Returns screen), `orderByIdProvider(id)`, `ordersProvider` (every order, worker; no screen watches it now, tests use it as the reference). Notifier: stock deduction (base + variant) via the batched `_moveStock`, rollback, customer stats, createReturnOrder, processRecurringOrders, cancel order
│   ├── products/
│   │   ├── presentation/
│   │   │   ├── product_list_screen.dart            # Search (debounced), category chips, responsive grid/list (`_ProductGridDelegate`), CSV export + import
│   │   │   ├── product_form_screen.dart            # Image, QR, category, selling+cost price, hierarchical variants editor (attributes + combinations), scroll-to-top on validation fail, autofocus on new attribute. Variant regeneration is debounced 300 ms and reuses entries and controllers by key; combination rows are lazy (see Performance → UI)
│   │   │   ├── product_detail_screen.dart          # Full info, variants card, adjust stock. Live via `productByIdProvider`
│   │   │   ├── catalog_share_screen.dart           # `/products/catalog` — pick products + tile options, share as image / PDF / text (see Product Catalog Share). Avatars decoded at display size (`ResizeImage`)
│   │   │   └── widgets/
│   │   │       ├── product_card.dart               # Photo decoded near the tile's pixel width (`cacheWidth`, 1.4× headroom for cover cropping)
│   │   │       └── stock_badge.dart
│   │   ├── providers/product_detail_providers.dart # `productById(id)` — after a product has been shown, a later delete keeps its last value, so the popping detail screen doesn't flash "not found"
│   │   └── providers/product_provider.dart         # `productsProvider` (active products straight from the (isActive, name) index, on a worker). Soft-delete if any order references it (`itemsElement` filter), negative stock prevention, variant-aware adjustStock
│   ├── reports/
│   │   ├── presentation/reports_screen.dart        # One date range (Today / This week / This month / Last month / This year / Custom) + 4 tabs; Export → current tab as PDF or CSV. Header height from `reportsHeaderHeight` / `reportsChipRowHeight` (grow with the text size; see UI Design → Reports header)
│   │   ├── presentation/widgets/report_tabs.dart   # SalesReportTab, DuesReportTab, InventoryReportTab, PurchasesReportTab
│   │   ├── presentation/widgets/report_widgets.dart # ReportSectionCard, KpiGrid, PnlTable, BreakdownBars, NetSalesChart, ReportEmpty
│   │   └── providers/reports_provider.dart         # salesReport / duesReport / inventoryReport / purchasesReport (from, to). Each runs `salesReportJob` / `duesReportJob` / `inventoryReportJob` / `purchasesReportJob` for `reportWindow` [start, end) on a worker and calls the report_service builder there. Sync loaders `loadSalesSync` (createdAt index, re-sorted by id), `loadReturnsSync`, `loadCancelledOrderIdsSync` are shared with the Dashboard job. Live through revision counters: sales (orders + expenses), dues (orders + customers), inventory (orders + products); purchases watches none. The Reports tab, kept mounted by the shell, stays live like the Dashboard. Each report is kept alive 3 min after its tab is left (`_keepForAWhile`), so swiping tabs doesn't reload
│   ├── splash/
│   │   └── presentation/splash_screen.dart         # Animated 2.5 s splash: pulsing rings, logo scale+rotate, title slide, tagline fade, loader. Shown only until `splash_shown` is set. Timeline animations built once in initState, repeating controllers stopped before navigating
│   ├── returns/
│   │   ├── presentation/returns_screen.dart        # /returns — 5 tabs over `returnOrdersProvider` (return orders only, newest first)
│   │   └── presentation/create_return_screen.dart  # Item selector with qty controls, reason chips, refund amount (pre-filled from `returnValueFor`, capped at amountPaid), variant display
│   ├── scanner/
│   │   └── presentation/scanner_screen.dart        # /scanner branch — scan QR/barcode, match by qrCode or sku → "View product" or "Add as new product" (product form pre-filled). Camera starts/stops by hand (`autoStart: false`) with `TickerMode` + app lifecycle (see Performance → UI)
│   ├── suppliers/
│   │   ├── presentation/
│   │   │   ├── supplier_list_screen.dart           # List with due amounts; FABs for "New Purchase" + "Add Supplier"; appbar action for "All Purchases"
│   │   │   ├── supplier_form_screen.dart           # Add/edit supplier (name, company, phone, email, address, notes)
│   │   │   ├── supplier_detail_screen.dart         # Contact info with call button, stats, linked products, restock activity (purchases + stock adjustments), New Purchase + Pay Due actions. Reads `supplierByIdProvider`; slivers, so the lists only build what's on screen
│   │   │   ├── purchase_list_screen.dart           # All purchases across suppliers, FAB to add
│   │   │   ├── purchase_form_screen.dart           # Optional supplier picker, product picker with unit cost, payment method, partial payment, notes. One unit-cost controller per item (keyed by productId), so a rebuild never overwrites typing; totals via `ListenableBuilder`
│   │   │   └── purchase_detail_screen.dart         # Items, payment summary, record payment, delete (reverses stock + supplier stats)
│   │   ├── providers/supplier_detail_providers.dart # `supplierById(id)`
│   │   └── providers/supplier_provider.dart        # CRUD; createPurchase (auto-restocks + updates costPrice + supplier stats); deletePurchase (reverses); recordSupplierPayment, recordPurchasePayment. Per-item product updates are batched (`_productsById`: one getAll, then one putAll each for products and movements)
│   ├── cash_register/
│   │   ├── presentation/cash_register_screen.dart  # Open/close register, cash in/out, expected vs actual closing, history (lazy `SliverList.builder`)
│   │   └── providers/cash_register_provider.dart   # openRegister, closeRegister, addCashIn, addCashOut
│   └── settings/
│       ├── presentation/recycle_bin_screen.dart    # Deleted items grouped by kind; Restore / Delete forever / Empty bin (auth-gated)
│       ├── providers/trash_provider.dart           # trashServiceProvider + trashEntriesProvider (stream) + TrashNotifier (keepAlive)
│       ├── presentation/settings_screen.dart       # Theme toggle, **Display** section between Theme and Language (Display size + Text size rows → the sheets below; each row's value is its own small widget, since `AppZoomScope` changes on every keyboard frame), language picker, currency picker (38+ currencies), shop config, tax rate, local backup export/import, Drive backup, clear data (`LocalBackupService.clearAll`: one write txn on a worker)
│       ├── presentation/sidebar_order_screen.dart  # Settings → Sidebar Order: drag-reorder + per-tab visibility switch (Settings row disabled). The list runs in `ZoomNeutral` with its own `Overlay.wrap` (unclipped) and each row is re-zoomed with a `ZoomBox` (see Display size & Text size)
│       ├── presentation/widgets/display_size_sheets.dart # `showDisplaySizeSheet` / `showTextSizeSheet`: slider + live preview (`_AppSample` in a `ZoomBox` relative to the current zoom; `_TextSample` under a text scaler), Reset, and on the Text sheet a "Follow phone" switch. `phoneTextPercent` reads the window's text scaler from `AppZoomScope.outer`, since the app's MediaQuery carries the Text size
│       ├── providers/display_scale_provider.dart   # `DisplayScale` (keepAlive): `(displayPercent, textPercent?)`, per-device SharedPreferences keys `displayScalePercent` / `textScalePercent` (removed = follow the phone), outside `Settings` so no backup carries them. `primeFrom(prefs)` (main, before runApp) reads them synchronously and never throws (`prefs.get` + `is num`, since typed getters throw on a wrong type); the setters keep that snapshot current, so a rebuilt provider never reverts
│       └── providers/settings_provider.dart        # keepAlive, SharedPreferences: shopName, shopPhone (optional, printed on the shared catalog), currency(৳), threshold, themeMode, taxRate, language, downloadDirectory, sidebarOrder, sidebarPosition ('left' | 'right'), hiddenSidebarItems (list of keys the user toggled off). Exposes `exportSettings()`/`importSettings(map)` so backup/restore round-trips preferences alongside the 10 backed-up Isar collections. `importSettings` writes every key, then assigns state once, because each assignment rebuilds every settings watcher. The auto-backup error refresh calls `prefs.reload()`, since the worker isolate has its own prefs cache, and only assigns state on a change. `toggleSidebarItemHidden('settings', _)` is a no-op — the Settings tab is force-visible to prevent soft-lockout. Display / Text size are not settings here: they are per-device (`displayScaleProvider`).
└── shared/
    ├── screens/qr_scanner_screen.dart
    │   (sidebar Scanner branch lives in features/scanner/presentation/scanner_screen.dart)
    └── widgets/
        ├── aging_bar.dart            # <30 / 30–60 / 60+ days stacked bar + legend (dashboard Due Book card, Dues report)
        ├── animated_entrance.dart    # Staggered fade + slide for list items — only a list's first screenful animates (see Performance → UI)
        ├── app_button.dart           # Variants: filled, outlined, text, destructive (a long label wraps). `ButtonPair`: two buttons at equal widths side by side, stacked full width (first on top) when a label's longest word wouldn't fit its half, so no word is broken across lines
        ├── app_text_field.dart        # With paste button, left out when the field can't keep ~3 letters (48 dp × text scale) for its value beside it; the context menu still pastes. Helper / error text wraps to 3 lines. It decides in a `LayoutBuilder`, which has no intrinsic size: use a plain `TextField` in an `AlertDialog`'s content or under `IntrinsicHeight`
        ├── app_zoom.dart              # Display size zoom (see Display size & Text size): `AppZoom`, `zoomMediaQuery`, `ZoomBox` / `RenderZoomBox` (lays out at constraints ÷ scale, paints × scale, no layer at 1.0), `AppZoomScope` (scale, capped percent, the window's own MediaQuery), `ZoomNeutral`, the percent rules (`snapPercent`, `maxDisplayPercentFor`, `kMinZoomedLayoutWidth`). Its library comment documents where text-selection menus land when zoomed
        ├── auth_gate.dart            # `runAuthGate`, `runPinSetup`, `.env` gate flags
        ├── bottom_sheet_handle.dart   # AppBottomSheet.show()
        ├── confirm_dialog.dart        # ConfirmDialog.show(). Confirm / Cancel default to the localized strings; scrollable, so a long message at a large text size scrolls above the buttons; buttons in a `ButtonPair`
        ├── payment_method_chips.dart  # PaymentMethodChips + paymentMethodLabel()
        ├── pdf_saved_sheet.dart      # `showPdfSavedSheet` — "PDF saved" modal with Open, own 15 s auto-dismiss timer
        ├── rate_app_dialog.dart      # Rate now / Later / No thanks gate before the Play review sheet
        ├── drawer_menu_button.dart
        ├── empty_state.dart           # Icon + title + optional action
        └── loading_overlay.dart       # `runWithProgress(context, task)` (modal spinner painted *before* the task starts — sync work at its start would otherwise freeze the screen with no feedback — and its barrier blocks repeat taps) + LoadingOverlay + LoadingShimmer
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

**Indexes:** `Order.createdAt`, `Order.customerId`, `Payment.customerId` / `orderId` / `paidAt`, `StockMovement.createdAt` / `productId`, `Expense.date`, `Customer.name` (value index), and on Product a composite `isActive` + `name` (value). Adding one changes the schema, so run codegen. Two pitfalls, both documented at the call sites:

- **Isar does not return equal index keys in id order** (it uses stored-id byte order). Rows loaded through an index that feed money sums are re-sorted by id (`..sort((a, b) => a.id.compareTo(b.id))`, `_byId` in reports_provider), so floating-point sums add in the same order as before and stay bit-identical. `test/worker_parity_test.dart` checks this. Where a per-customer group must keep id order without a sort, the code uses a `filter()` scan instead of an index where-clause (`loadDuesSync`, the balance recalculation).
- **A string part used for ordering must be `IndexType.value`.** Strings default to a hash index, which has no order.

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
  - **Real-time stock** via Isar `StreamBuilder` (not a stale snapshot). The stream is created once in `initState`, because a new `watch()` per build restarted the watcher and re-read every product. Lowercased search keys and the filtered list are memoized per emission and query
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
  - Tax auto-calculated: `(subtotal - discount) * taxRate / 100`, shown as helper text. Tax and total come from `orderTotals` and are rounded to 2 decimals, so "Pay Full" (which types the 2-decimal total) really pays in full
  - Amount paid field with "Pay Full" quick button (fills total)

- **Payment method:** ChoiceChips (Cash / Card / bKash / Nagad / Bank / Other)

- **Order status:** ChoiceChips (Pending / Confirmed) — not a dropdown

- **Delivery section:** Delivery address text field + estimated delivery date picker

- **Recurring toggle:** Switch + interval days input

- **Sticky footer:** Live subtotal/discount/tax/delivery/total summary + "Create Order" / "Update Order" button. Only the summary rows listen to the money fields (`ListenableBuilder`), so typing doesn't rebuild the form

- **Post-creation invoice sheet:** After a *new* order is saved, an `AppBottomSheet` opens titled "Order created · {orderNumber}" with four tappable action tiles before the form pops. The invoice PDF is rendered once per sheet behind `runWithProgress` and shared by Share / Download / Print; a failed render is dropped, so the next tap retries:
  - **Share PDF** — generates the invoice and opens the system share sheet
  - **Download PDF** — saves to the user's chosen download directory (asked once, persisted in settings; the folder is picked before rendering, so cancelling costs nothing). `showPdfSavedSheet` (`pdf_saved_sheet.dart`) confirms the path with an Open action and auto-dismisses after 15 s
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
- Every stock move (sale, rollback, cancel, delete, return approve) goes through `OrderNotifier._moveStock(items, sign:, type:, reason:)` inside the caller's `writeTxn`. It runs one `getAll` for the products, applies items **in order** to an in-memory map keyed by product id (so two variants of one product compose exactly as sequential get → put did), then one `putAll` for products and one for StockMovements. Items whose product is gone are skipped, movement included. It replaced a get + put + put per item, each a round trip to Isar's thread. `test/batched_writes_test.dart` pins the numbers

### Order Deletion (safe)

- **Restores stock** (base + variant) if order was confirmed/shipped/completed (creates adjustment StockMovements)
- **Reverses customer stats** (totalOrders, totalSpent, outstandingBalance)
- Then deletes the order

### Return Orders

1. "Create Return" action from order detail screen (hidden for return orders themselves)
2. Create return screen shows items with variant info via `displayName`, qty selector, reason chips
3. **Refund amount capped at `amountPaid`** on original order (validation + auto-fill cap)
4. Refund of 0 allowed (e.g. exchange)
5. **Valued at what the customer paid:** `createReturnOrder` stores `returnValueFor(original, items)` as the return's subtotal / discountAmount / taxAmount / totalAmount: list price, minus the items' pro-rata share of the order discount, plus their share of the tax (delivery isn't refunded). Not rounded, so piecewise returns add up to exactly the order. The refund pre-fill uses the same function; submitting it unedited refunds the exact value, and the check allows half a paisa over `amountPaid` (the field shows 2 decimals; `processRefund` caps at `amountPaid`). At list price, a full return of a discounted order credited the customer the discount against their *other* dues. Returns created before this keep their list-price value (no migration — balances were settled against it).
6. Creates a new order with `RET-XXX` numbering, `isReturn: true`, linked via `originalOrderId`
7. Return detail screen shows only the 3-step return flow (Requested → Received → Refunded), **not** the regular order status stepper
8. On approve: **restores stock** (base + variant) for all items via restock StockMovements
9. **Updates customer stats** (decrements totalSpent)

### Recurring Orders

1. Toggle in order form sets `isRecurring`, `recurringIntervalDays`, `nextRecurringDate`
2. `processRecurringOrders()` checks for due recurring orders and auto-creates new pending copies, all in **one** `writeTxn`. The order count is read once and advanced locally (each copy adds exactly one order, so the `ORD-` numbers match a fresh count per copy). Customers are read with one `getAll`, so a customer with several due orders accumulates on one map entry, and each copy bills them as `createOrder` would. Orders and customers are written with one `putAll` each

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

- **Dues are computed from orders, never from `Customer.outstandingBalance`.** That counter drifts (`updateOrder` doesn't adjust it; recurring copies didn't bill the customer until the Due Book fixed `processRecurringOrders`). The customer's total is `computeNetDue` — every order's effective due *including credits* (an exchange return worth more than an order's remaining due), floored at 0, ignoring orders within `kDueEpsilon` of settled (sub-paisa leftovers on several orders used to add up to a "due" on no order, and `orderDues.first` crashed the Due Book) — so it matches the counter and the statement; collections are capped at it. `computeOrderDues` takes all of a customer's orders *including returns*: excluded are cancelled orders and return orders; each order's effective due is `balanceDue − value of its refunded returns`, because `processRefund` lowers the original's `amountPaid` by the refund but not its `totalAmount`.
- **Loading:** `duesProvider` runs `loadDuesSync` on a worker (`runDbJob`), reloading via `reloadOn` when orders or customers change. It does one id-ordered `filter()` scan of orders with a customer, groups them in Dart, `getAll`s the debtors, and finds each one's last positive payment from two property reads (`customerId`, `paidAt`) instead of a query per debtor. The Dues report reuses the same job, so the two can't disagree.
- **Collect** (`OrderNotifier.collectFromCustomer`): one amount applied oldest-first across the customer's due orders, capped at the total due (no advance credit). The orders are loaded through the customerId index and re-sorted by id, so allocation matches the Due Book. One `Payment` per touched order sharing a `groupId`; the order updates and payment rows are written with one `putAll` each. Cash collections can add to the open cash register in the same transaction. The sheet's allocation preview mirrors the notifier's loop.
- **Remind**: localized WhatsApp text via `https://wa.me/<digits>?text=`. A Bangladeshi local mobile (`01…`, 11 digits) with ৳ gets the `88` prefix; other numbers pass through as typed. No phone / launch failure → share sheet.
- **Statement**: `StatementService` PDF (running balance). Orders before payment history existed have no `Payment` rows, so each order's unlogged `amountPaid` is shown as a payment on the order date — the closing balance always matches the orders.
- **Recalculate balances** (Due Book overflow menu, and once automatically via `migrateOutstandingBalancesV1`) resets every counter to the computed dues. The menu action runs `recalculateOutstandingBalances(isar)` (load, compute and write in one transaction on a worker) behind `runWithProgress`; on the UI isolate it froze the spinner with thousands of orders. Every restore also recalculates, inside its own write transaction.

### Stock Adjustment (transactional, combination-aware)

1. Update product.stockQty += delta (**clamped to 0 minimum**)
2. If `combinationKey` specified: also update the matching `VariantCombination.stockQty`
3. Create StockMovement record with type and reason (includes combination displayLabel in productName)
4. Stock adjustment screen shows **combination selector** (choice chips) for products with variants
5. Stock values shown via `StreamBuilder` for real-time updates

### Product Detail Screen

- Shows full product info including **variants card** with per-combination stock, price adjustment, and SKU
- Adjust stock button links to inventory adjustment screen
- Live (`productByIdProvider`), so an edit or stock adjustment shows on return

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

- Exports **all 10 backed-up collections** as timestamped JSON to Drive appDataFolder. The bytes come from `LocalBackupService.encodeAllBytes`: one read txn, encoded straight to UTF-8 on a worker. The upload is resumable in 8 MB chunks, so big backups are sent and retried piecewise and nothing base64-encodes the whole file on the UI isolate
- Keeps max 5 backups, cleans up old ones (cleanup failure doesn't break upload)
- **Safe restore** (`restoreFromBytes`): snapshot the current DB + settings (`encodeAllBytes`), then `restoreBytes(requireMetadata: true)`, which parses, validates and replaces the DB on a worker in one write transaction. Then apply settings. If anything after validation fails, the snapshot is restored and the error is `rolledBack`; if the rollback fails too, it is `restoreFailed`. A file that isn't a backup is `invalidBackup` with nothing touched. The outcome is thrown outside the rollback's `try` (a successful rollback used to be caught by its own catch and reported as `restoreFailed`). `test/backup_worker_test.dart` covers `rolledBack` (settings failing after the restore; a malformed row) and `invalidBackup`
- **Settings round-trip:** backup payload includes a `settings` field built from `Settings.exportSettings()` (theme, currency, sidebar order/position/hidden items, shop name, autoBackup, etc.). Restore re-applies via `Settings.importSettings(map)`. v2 backups (collections only) still restore correctly — `settings` is optional on decode.
- **Auto Backup (two-tier):** `Settings.autoBackup` toggle (Settings → Drive section). Enabling it both (a) lets `AutoBackupRunner.runIfDue()` fire 15 s after the first frame (a timer started from `SellerBookApp.initState()`, kept off the startup path) for a fast catch-up (12 h soft de-dupe via `lastBackupTime`), and (b) registers a daily `Workmanager().registerOneOffTask` (uniqueName `auto-backup-daily`, `initialDelay = duration to next 00:05 local time`, `NetworkType.connected` + `requiresBatteryNotLow`) that runs in a background isolate even when the app is closed. The worker re-arms itself for the next 00:05 in its `finally` block, forming a self-rescheduling chain — chosen over `registerPeriodicTask` because the periodic API only promises an interval, not a clock time. Neither path ever triggers interactive sign-in (foreground via `getCurrentUser()` early-return; worker via `backupToDrive(interactive: false)`). When the worker hits `notSignedIn` / `signInFailed` / `developerError` it persists `autoBackupError` in SharedPreferences, fires a "Auto backup paused" notification *once* (subsequent revoke runs skip it), and stops the chain. The Settings → Drive section watches that flag (refreshed on `initState` and `AppLifecycleState.resumed`) and shows an amber banner with a "Sign in to fix" button that re-runs `DriveService.signIn()`, clears the flag, and re-arms the chain via `scheduleAutoBackup()`. Toggling Auto Backup off cancels the worker and clears the banner. WorkManager is Android-only; the helpers `Platform.isAndroid` early-return on iOS/desktop. Native setup: workmanager **0.10.x** (0.5.2 no longer compiles on current Flutter — it used the removed v1 embedding `Registrar` / `ShimPluginRegistry`) auto-registers via the v2 plugin embedding — no MainActivity / Application class changes required. `initialize()` takes no `isInDebugMode` in 0.10.
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

**Two constraints inherited from `pdf_service`:** (a) `captureWidgetPng` needs a *finite* `targetSize` — infinity × pixelRatio yields an undecodable PNG — so the page is a fixed 794×1123 and content is paginated rather than scrolled; (b) the capture environment provides only `Directionality`, so `MediaQuery` / `DefaultTextStyle` / `Material` are wired by hand (`MaterialApp` fails there). The catalog is image-heavy, so nothing on a page loads asynchronously. Photos are decoded at tile size (84 px × pixelRatio) into `ui.Image` and drawn with `RawImage`, and so are the placeholder icon (rasterized once per run) and the watermark icon. One capture is then enough (delay 100 ms, as for the other PDFs). Decoding at tile size instead of camera resolution, one photo at a time and one page at a time, caps peak memory on low-end phones. While it works, the screen paints its progress bar before starting; after that the work yields (decode, encode, PDF assembly on an isolate), so the bar keeps animating.

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
- **Both bulk-clear paths clear the trash too.** Restore and Settings → Clear All Data share `clearAllCollectionsInTxnSync` (`local_backup_service.dart`), which clears each collection *explicitly* (not `isar.clear()`), trash included. A surviving `trashEntries` row would reference ids from the replaced dataset, and restoring it would corrupt live data. A new collection must be added there, which covers both paths. Trash is deliberately **not** part of the backup payload.
- `purgeExpired()` runs post-first-frame from `app.dart`, wrapped in a try/catch — a failure must never block startup.

### CSV Export

- Export orders, products, or expenses as CSV files via share_plus
- Export buttons available in all three list screens
- The orders export loads every order (`loadAllOrdersNewestFirst`, on a worker), not just the pages the list has loaded. CSV + UTF-8 encoding runs in `compute`

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

- **Low stock alerts:** triggered when products fall below threshold. The list comes from the dashboard stats (`checkAndNotify(isar, lowStock: stats.lowStockProducts)`), not a second product query
- **Payment reminders:** triggered for unpaid orders, counted natively (`count()`), since the text only needs how many
- Checked when the dashboard first loads and on pull-to-refresh — not on the recompute every order change triggers (`!ref.isReload`), which would notify on each save. `NotificationService.init()` is memoized and starts unawaited after `runApp` (awaited before it on iOS, which keeps the permission prompt before the first frame). `checkAndNotify` waits for it, and does nothing if init never started or failed

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
8. **Delete purchase** reverses everything: deducts stock back (clamped at 0 per item, in order), decrements supplier stats
9. Create and delete are batched like `_moveStock`: `_productsById` runs one `getAll`, items apply in order (two lines of one product add up, the last cost wins), then one `putAll` for products and one for movements. Deleting a supplier unlinks its purchases and products with one `putAll` each

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

- **First launch only:** shown until `splash_shown` is set (on navigating away; `TutorialService.resetAll()` clears it). `main()` primes `TutorialService.splashShown` from prefs before `runApp`, and `appRouter.initialLocation` is `/` once it's set, so later cold starts skip the splash
- **2.5-second animated sequence** with teal gradient background
- Staggered reveals: pulsing rings → logo icon (scale + rotate with elastic overshoot) → "Micro Seller" title slides up → tagline pill fades in → circular loader appears
- Auto-navigates to dashboard after animation completes
- Uses GoRouter `go('/')` for clean transition. The repeating controllers are stopped first, so they don't keep rebuilding the splash through the route transition

### First-Time Showcase Tour

- **4 highlight steps on the sidebar** (first-time users only), run by `_NavigationShell` in `app_router.dart`:
  1. Categories — start here, create categories
  2. Products — prices, stock, variants, images
  3. Orders — orders, payment, delivery, status
  4. Returns — returns and refunds
- The `Showcase` keys are mapped by branch index (9, 1, 2, 3), not sidebar position, so a reordered sidebar still highlights the right tabs. The texts are English-only (`_Sidebar._showcaseDescriptions`)
- Uses `ShowcaseView.register()` (showcaseview v5+ API) in the shell's `initState`
- Auto-starts 1.5 s after the shell's first frame
- **Skipped under a Display size zoom:** showcaseview places its tooltip with an unanchored `localToGlobal`, which is off when zoomed. A zoomed app isn't a first run anyway, so the tour is marked completed instead (the rating prompt waits for that flag)
- One-time only — flagged via SharedPreferences (`tour_completed`)
- Dismissing or completing the last step marks it as done
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

- **Export:** Saves all 10 backed-up collections as a timestamped JSON file via share sheet (bytes encoded on a worker, `encodeAllBytes`)
- **Import:** Pick a `.json` file, confirm with destructive warning, replaces all data. The picked bytes go to `restoreBytes`: parsed, validated and written in one transaction on a worker. Local imports don't require the `version` / `timestamp` envelope, only Drive restores do
- Available in Settings → Local Backup section
- Complements Google Drive backup (works offline, shareable via any app)

### Currency System

- **38+ currencies** with searchable picker in Settings (symbol, name, code)
- `CurrencyFormatter.setSymbol()` called in `main.dart` before app renders (from SharedPreferences)
- Also called on every currency change in settings
- All screens use `CurrencyFormatter.format()` which reads the static symbol — no hardcoded currency symbols in runtime code
- `CurrencyFormatter.symbol` getter for accessing the current symbol directly
- PDF receipts and WhatsApp text also use the dynamic symbol

### Display size & Text size

Settings → Display: two per-device knobs, for phones where the app's coded dp come out too small or too large.

- **Display size** zooms the whole UI (layout, text, icons, spacing), 80–130% in 5% steps, default 100%. **Text size** follows the phone's font size (default) or is a custom 80–130% in the same steps; switching "Follow phone" off starts at 100%. Each is a sheet (`display_size_sheets.dart`) with a slider, a live preview and **Reset** (100% / follow the phone).
- **Applied when the finger lifts** (or on a tap, an arrow key, a screen reader's adjust), not while dragging: applying mid-drag would rescale the sheet, and the slider with it, under the finger. For the same reason the preview box keeps its height while the slider is held. A gesture the slider loses (the sheet's drag or scroll takes it) or that the system cancels applies nothing.
- **Storage:** `displayScaleProvider`, SharedPreferences `displayScalePercent` / `textScalePercent`. Not in the app's backups (`exportSettings()` leaves them out, `importSettings` ignores them): the right size depends on this screen and the phone's own font setting, so a phone backup restored on a tablet must not resize it (same precedent as the rating prompt's state). Android Auto Backup (the manifest doesn't turn `allowBackup` off) can still bring the prefs to a new phone; the width cap below keeps that safe. Stored values are snapped and clamped (`snapPercent`); a corrupt one falls back to the default.
- **First frame:** `DisplayScale.primeFrom(prefs)` runs in `main()` before `runApp`, so the app never draws a frame at 100% and then jumps.
- **One zoom at the root:** `AppZoom` sits in `MaterialApp.router`'s `builder`, around the Router, so every route, dialog, sheet, menu, tooltip and snackbar is zoomed alike and no screen has to know. The child is laid out at the window size ÷ scale and painted × scale (`RenderZoomBox`; hit tests, semantics and `localToGlobal` go through the same transform), so it always fills the window. `zoomMediaQuery` rewrites the MediaQuery to match:
  - size, padding, viewPadding, viewInsets, systemGestureInsets, display features and corner radii ÷ scale, so SafeArea, the keyboard inset and hinge avoidance still add up to the window
  - devicePixelRatio × scale, so images still decode at the screen's physical resolution
  - `gestureSettings` untouched (drag slop is compared in window units); `supportsShowingSystemContextMenu` kept
  - textScaler replaced only by a custom Text size; at 100% with no custom Text size the app gets the window's MediaQuery as is
- **Same tree at every size, 100% included:** a size change relays out the app but never remounts the Router, the shell or a branch navigator, so no screen loses state or reloads. At 100% `RenderZoomBox` paints the child directly, with no transform layer. PDF and catalog captures build their own tree and are never zoomed.
- **320 dp minimum layout width** (`kMinZoomedLayoutWidth`, the narrowest phone the layouts are built for): `maxDisplayPercentFor(windowWidth)` caps zooming in so the layout stays at least 320 dp wide — 125% on a ~411 dp phone, 110% on a 360 dp one, never below 100%. Zooming out is never limited. The slider ends at the cap, and Settings shows the size in effect (`AppZoomScope.displayPercent`), which a narrow window can hold below the saved one.
- **`AppZoomScope`** gives the scale, the capped percent and the window's own MediaQuery (`outer`) to widgets that need window values (the sheet's cap, the phone's font size, `ZoomNeutral`). It doesn't notify on padding / inset-only changes, because the keyboard moves them on every animation frame.
- **`ZoomNeutral`** cancels the zoom for a subtree (window dp; the Text size still applies), for Flutter widgets that mix window and local coordinates. `ReorderableListView`'s drag proxy and drop slots only agree unscaled (zoomed, the dragged row was drawn away from the finger), so Sidebar Order runs its list in `ZoomNeutral` with its own unclipped `Overlay.wrap` for the proxy, and draws each row back at the zoom with a `ZoomBox`.
- **Tour:** skipped (and marked completed) when zoomed — see First-Time Showcase Tour.
- **iOS edit menu:** Flutter positions text-selection menus by adding a field's on-screen position (zoomed) to offsets inside the field (not zoomed). iOS keeps its system edit menu (Cut / Copy / Paste act on the right selection, but the menu points `(1/s − 1) × d` beside it). Turning `supportsShowingSystemContextMenu` off while zoomed was worse: Flutter's Cupertino toolbar points at the same wrong spot, drifts at the screen edges, and its Paste brings back iOS's "Allow Paste" prompt. A fix would need a `contextMenuBuilder` on every field (Flutter has no app-wide default). The details are in `app_zoom.dart`'s library comment; `app_zoom_platform_test.dart` fails if a Flutter upgrade fixes the target, so the comment gets updated then.
- **Known limitations** (none at 100%): Flutter-drawn selection toolbars (Android, desktop) can sit slightly off, near the screen edges, when zoomed; a right-click menu opens a little away from the pointer; a toolbar hidden by a scroll may not come back for a selection near the keyboard (a tap shows it). Native surfaces — the share sheet, file / image pickers, notifications, the print dialog — are drawn by the OS and follow the phone's own sizes.
- **Layout rule:** every screen must lay out cleanly — nothing overflows or is cut off, no label is split mid-word — at 320 / 360 / 411 dp × text 1.0 / 1.3 / 1.5 (`kLayoutWidths` × `kLayoutTextScales` in `test/support/layout_harness.dart`), and look unchanged at 100% text on a normal phone. The tools: `ButtonPair`, one-line amounts in `FittedBox(scaleDown)`, slot heights computed from the text scaler (`statCardHeight`, `dashboardHeaderHeight`, `reportsHeaderHeight`), rows that measure their text and stack when it won't fit side by side, and Settings rows that move their control under the title (`_EndControl`). A helper that measures text must measure it as `Text` draws it: ambient style, `MediaQuery.textScalerOf`, and **Bold text** (`MediaQuery.boldTextOf` → `FontWeight.bold`), as `measureTextWidth` in `stat_card.dart` does; otherwise it under-measures when the phone's Bold text is on.

## Navigation (GoRouter)

Initial route is `/splash` (animated splash screen) on first launch, which then navigates to `/` (dashboard shell); after that, `appRouter.initialLocation` is `/` (from `TutorialService.splashShown`, primed in `main()`). 14 branches via `StatefulShellRoute` with a responsive sidebar (icon-only <600px, expanded with labels >=600px). Tooltips on icons when collapsed. Wrapped in `SafeArea`.

| Route         | Path             | Sub-routes                                                                                  |
| ------------- | ---------------- | ------------------------------------------------------------------------------------------- |
| Splash        | `/splash`        | — (initial route on first launch, auto-navigates to `/`)                                    |
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

- **Stream providers** for reactive lists (products, customers, suppliers, …), built on `reloadOn(collection.watchLazy(), load)`, not `watch(fireImmediately: true)` (see Performance). Big lists load on a worker via `runDbJob`. Long histories are paged notifiers (`OrderPages`, `StockMovementPages`, `CustomerOrders`)
- **One-row providers** (`orderById`, `productById`, `customerById`, `supplierById`): yield `getSync(id)`, then `watchObject(id)` without `fireImmediately`. Detail screens read these instead of creating streams or futures in `build()`, because go_router rebuilds pages on every push/pop in the branch, and each rebuild resubscribed, flashed a spinner and re-queried
- **Revision counters** (`isar_revisions.dart`) for providers that run their own queries (dashboard stats, reports), so nothing deserializes a whole collection just to notice a write
- **Notifier classes** for mutations (add, update, delete, complex transactions). Per-item reads and writes inside a `writeTxn` are batched (`getAll` / `putAll`)
- **AsyncValue.guard()** for error handling
- **Isar `watch` / `watchObject(fireImmediately: true)`** remains only for small or one-off streams: categories, the trash bin, `lowStockProducts`, `pendingOrders`, the order/purchase product pickers (created once in `initState`), purchase detail and stock adjustment (one row each), and the repositories
- **StreamBuilder** for real-time stock in product picker and stock adjustment screens
- **Freezed** for immutable dashboard stats (DailySales, DashboardStats)
- **DashboardDateRange notifier** for date filter state (Today/This Week/This Month/Custom)
- **Settings provider** (keepAlive, SharedPreferences): shopName, currencySymbol (৳), lowStockThreshold, themeMode, taxRate, language, lastBackupTime. Watch single keys with `ref.watch(settingsProvider.select(...))`; watching the whole map rebuilds on every settings write

## Performance (large datasets)

The app is tuned against a generated dataset of about 10 000 orders (`tool/perf_dataset.dart`), because most slowdowns grow with orders, payments and movements. Isar deserializes query results on the isolate that runs the query, so a big load freezes that isolate, together with the Dart work done on the results.

- **Worker jobs — `runDbJob(isar, job)`** (`db_worker.dart`): runs a *synchronous* job (`findAllSync`, `txnSync`, `writeTxnSync`, …) through `compute`, which is `Isolate.run` on native. The worker opens the same DB with `kIsarSchemas`. Isar shares the native instance between isolates, and the worker's `close()` releases only its own reference. The result comes back via `Isolate.exit`, uncopied. On web the job runs inline. **Jobs must be built by top-level functions from plain values** (`salesReportJob(start, end)`, `restoreBackupJob(bytes)`, …) and never capture a `Ref`, a `BuildContext` or the caller's `Isar`: a closure carries its whole context across isolates, and those can't cross. Current jobs: Due Book (`loadDuesSync`), dashboard (`dashboardStatsJob`), the four report jobs, the products / orders / movements lists and pages, customer history (`customerOrdersJob`), CSV orders export, backup encode (`backupBytesJob`), restore (`restoreBackupJob`), Clear All Data (`clearAllDataJob`), balance recalculation (`recalculateOutstandingBalancesJob`).
- **Live lists — `reloadOn(changes, load)`** (`isar_reload.dart`): Isar's `watch()` is `watchLazy().asyncMap(findAll)`, one full query per change event with none skipped. Riverpod 3 pauses providers whose widgets are offstage, and go_router keeps visited branches mounted under `TickerMode(false)`. A hidden tab therefore queued events and replayed one full reload each when shown, and a transaction touching two watched collections reloaded twice. `reloadOn` only marks the data dirty: it subscribes *before* the first load, coalesces bursts within 16 ms, runs one load at a time (a change during a load costs one more load after it), never loads while paused, and loads once on resume if anything changed. `mergeChanges([...])` combines several `watchLazy()` streams; paged notifiers also merge their own "load more" stream.
- **Revision counters** (`ordersRevisionProvider`, `customersRevisionProvider`, `productsRevisionProvider`, `expensesRevisionProvider`, `paymentsRevisionProvider`): keepAlive ints bumped by `watchLazy()`. They are never paused, so writes made while the Dashboard or Reports is offstage collapse into one recompute when it's shown. `dashboardStats` and the sales / dues / inventory reports watch them instead of full list providers. Nothing watches `paymentsRevisionProvider` yet.
- **Indexes:** see Data Models → Indexes, including the id-order pitfall.
- **Paging:** 100 rows per page. A list asks for the next 100 when it builds a row within 20 of the end (scheduled after the frame, since the notifier can't change during a build), and shows a spinner row while more exist. Each page query fetches `limit + 1` rows to know whether more exist. Tab badges are native `count()`s. Paged: the Orders tabs (`order_pages_provider.dart`), inventory movement history, and customer purchase history. Exports never depend on how far a list was scrolled.
- **Batched writes:** see `_moveStock` (Order Status Change), `_productsById` (Purchase Recording), `collectFromCustomer`, `processRecurringOrders` (one transaction for all due copies). Each batch applies items in order to an in-memory map, so results match the old sequential get → put exactly. `test/batched_writes_test.dart` pins them.
- **PDF pipeline:** capture (`captureWidgetPng`, which unmounts the off-screen tree afterwards) → `assemblePdf` on a background isolate, with full-page outputs (report, statement, catalog PDF) re-encoded to JPEG q75. The invoice stays PNG. Bitmaps on a page (catalog photos, placeholder, watermark icon) are pre-decoded at draw size and drawn with `RawImage`, so a capture never waits on an async image load. `runWithProgress` puts up the spinner before the work starts.
- **Startup:** `.env` and SharedPreferences load in parallel (`.env` must still be loaded before `runApp`, because DriveService reads it). The splash shows only on first launch. Notification init runs off the critical path except on iOS. Icon warm-up and Workmanager registration (`keep`) happen after the first frame, and the auto-backup catch-up 15 s later. Isar `compactOnLaunch` keeps the file compact after big restores or clears.
- **UI:**
  - `AnimatedEntrance` animates only a list's first screenful. It decides once, on mount, and shows the child immediately if its `Scrollable` is already scrolled or its index is past `3 × maxStaggerIndex`, so a fling never reveals blank rows still waiting to animate.
  - The Scanner tab runs `MobileScannerController(autoStart: false)` and starts/stops the camera from `TickerMode` (branch offstage or covered) + app lifecycle. Calls are serialized through one future chain, because `start()` throws while a start is in flight. A denied camera is re-requested only when the tab is opened: Android re-prompts on every `start()`, and the prompt pauses/resumes the app, which loops.
  - fl_chart compares chart data, callbacks included, with `==`, so an inline closure restarted the animation on every parent rebuild. Chart callbacks are State-method tear-offs or statics (`GridLineCallback` hands out one per color, so a theme switch still repaints), and charts sit in `RepaintBoundary`s.
  - Products grid: `_ProductGridDelegate` picks the column count at layout time (`(width + 32) / 180`, clamp 2–6), so a keyboard-driven height change relays out without rebuilding cards.
  - Images are decoded at display size: product card `cacheWidth`, catalog avatar `ResizeImage`, splash logo `cacheWidth`.
  - Product form: typing in an attribute or option only schedules regeneration (300 ms debounce, flushed on submit). Regeneration keeps entries and controllers by combination key, so typed stock / price / SKU survive. Combination rows are built lazily, but every `FormField` stays in the always-mounted first `SliverToBoxAdapter`: a lazily built `FormField` scrolled out of the cache extent is unmounted, and `Form.validate()` silently skips it.
  - Long detail pages (cash register, customer, supplier) are slivers with `SliverList.builder`, so history only builds what's on screen.

## UI Design

- Material 3, teal primary (#00897B), light/dark theme support with **user-selectable toggle** (Light/Dark/System)
- **Dark scaffold:** `Colors.blueGrey.shade900` (#263238); light scaffold: `#F8F9FA`
- **Status bar** color matches appbar (white in light theme, blueGrey.shade900 in dark theme)
- **Shop name as primary brand:** `Settings.shopName` (default "My Shop") replaces `AppStrings.appName` in three live-rendering surfaces — `MaterialApp.title` (OS task switcher), Splash Screen hero text, Dashboard SliverAppBar title — each falls back to "Micro Seller" if the shop name is empty. The PDF invoice watermark intentionally stays as "Powered by Micro Seller" (brand attribution, not the user's shop).
- **Language:** 12 languages with in-app language switcher (English, Bengali, Arabic, Spanish, French, Portuguese, Turkish, Indonesian, Thai, Vietnamese, Urdu, Malay)
- **Display size / Text size** (Settings → Display): whole-app zoom and the app's own font size, per device. Every screen must stay clean from 320 dp up to 150% text — see Key Business Flows → Display size & Text size (layout rule)
- **Colored sidebar icons**: every `SidebarItem` has its own `color` (dashboard teal, products indigo, orders blue, returns deep orange, customers purple, Due Book amber-orange, inventory brown, suppliers cyan, expenses red, cash register green, categories pink, reports deep purple, scanner blue-grey, settings grey). `_tile` tints the icon with it (75% when unselected), and the selected tile's background and label too; dark mode lerps each color 25% toward white for contrast. Sidebar Order screen uses the same colors.
- **Responsive sidebar navigation**: icon-only rail (56px) on phones (<600px), expanded with labels (200px) on tablet/desktop (>=600px). Tooltips on collapsed icons. Wrapped in SafeArea.
- **Sidebar customization** lives under its own **"Sidebar"** section header on the Settings screen (separate from Theme / Language / Shop): drag-reorder tabs (Settings → Sidebar Order screen; `reconcileSidebarOrder` slots a newly added tab after its default predecessor so existing users see it in place, not below Settings), per-tab visibility toggle (`CupertinoSwitch`), and a **left/right position** picker on the main Settings screen. The position picker is a custom `_SidebarPositionToggle` widget (in [settings_screen.dart](lib/features/settings/presentation/settings_screen.dart)) — a compact pill-rounded two-icon segmented control that fits inside `ListTile.trailing` without forcing the title onto a second line. Active side fills with `cs.primary`; inactive ghosts to 55% `onSurface`. Material 3 `SegmentedButton` was tried first but its mandatory label+icon padding was too wide. The position swap itself is just a `Row.children` reorder in `_NavigationShell` — not two separate layouts. `Settings.toggleSidebarItemHidden('settings', _)` is a hard no-op and the Settings row's switch is rendered disabled, so the user can never lock themselves out. All three knobs (`sidebarOrder`, `hiddenSidebarItems`, `sidebarPosition`) are part of the backup payload via `exportSettings()` / `importSettings(map)`.
- **Responsive layouts throughout**:
  - Dashboard: stat cards via `Wrap` + `LayoutBuilder` (2-6 cols based on `width/170`, height `statCardHeight`); charts side-by-side on wide screens; date-range filter bar
  - Product grid: responsive columns from `_ProductGridDelegate` at layout time (body `width/180`, clamp 2-6)
  - Order card: compact column on phone, single-row layout on tablet (>=600px)
  - Inventory: category filter + sort dropdown bar; **per-variant stock display**
- **Dashboard charts**: Weekly sales bar chart, order status pie chart, revenue vs expenses line chart
- **Dashboard SliverAppBar**: `title:` ("Micro Seller") always shown; `expandedHeight: dashboardHeaderHeight(textScaler)` — 160 at the default text size, growing by exactly what its three text lines (date pill, revenue label, amount) grow, so a larger font never clips the stats; `flexibleSpace` holds greeting + date pill + today's revenue/total-orders stats with top padding `kToolbarHeight + 8` so content sits below the toolbar layer. Title remains visible when collapsed.
- **Reports screen**: four tabs over one date range — **Profit & Sales** (P&L statement, net sales chart by day or month, sales by payment method, orders by status, top products / categories / customers), **Dues & Payments** (money received by method, dues collected, credit given, refunds; receivable + aging *as of today*; top debtors), **Stock & Returns** (stock value at cost / selling price, potential profit, movements by type, best sellers, not-sold-in-period, return reasons), **Purchases & Expenses** (purchased / paid / unpaid, owed to suppliers today, top suppliers, expenses by category, cash register cash in/out and over/short). Export shares the current tab as PDF (Unicode-safe) or CSV (UTF-8 BOM for Excel).
- **Report accounting rules**: returns count when their goods are back (`returnStatus` received/refunded), dated `updatedAt ?? createdAt`, and are *subtracted* (the old single-page report added them to revenue). Gross sales are goods at list price; order discounts are their own row; returns are valued at `netGoods` (after their discount share, without tax). Tax is shown as "Tax collected", never sales; delivery is added after gross profit. Sales by payment method, top customers and average order value stay on billed `totalAmount`. Net margin is 0 when net sales ≤ 0 (a ratio over a negative base flips sign). COGS uses `OrderItem.costPrice`, falling back to the product's current cost when 0, and returned items reverse their COGS. Stock value, receivable and supplier dues are point-in-time ("as of today"). Returns against a cancelled original are ignored (the cancel already removed the sale). Pending orders count as sales (same as the Due Book). "Owed to suppliers" = Σ `Supplier.totalDue` + unlinked purchases' `balanceDue` (direct supplier payments don't touch purchases). Cancel reversals (`Payment.note == kCancelledPaymentNote`) net out of money received; "Refunds paid" is return refunds only. Known trade-offs: a return is dated `updatedAt`, so refunding it later moves it to the refund date; legacy zero-cost items use today's product cost. `ReportTable` cells are String/int/double — money stays numeric in CSV (formula-like text is apostrophe-escaped), and `formatCell` formats it for the PDF.
- **Reports header** (was SliverAppBar-only): `NestedScrollView` + pinned `SliverAppBar` (range chips + date line in `flexibleSpace`, scrollable `TabBar` in `bottom`). `expandedHeight` is `reportsHeaderHeight(textScaler, tabBar.preferredSize.height)`: toolbar + chip row (`reportsChipRowHeight`, 36 at the default text size) + date line + the TabBar's own height, so both text rows grow with the text size without clipping or sliding under the tabs. The date line stays one line and shrinks (`FittedBox`) rather than wrapping. Previously: `title:` ("Reports") always shown; `expandedHeight: 120`; `flexibleSpace` holds the start/end date chips with same `kToolbarHeight + 8` top padding pattern.
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

Generates: `.g.dart` (Isar schemas, JSON, Riverpod providers — including `lib/data/services/isar_revisions.g.dart` and `isar_service.g.dart`), `.freezed.dart` (dashboard stats). Adding or changing an `@Index` changes the schema and its generated where-clauses (e.g. `isActiveEqualToAnyName`, `createdAtBetween`), so regenerate.

**All Isar imports use `package:isar_community/isar.dart`** — never `package:isar/isar.dart`. The `isar_community_generator` produces the same `.g.dart` shape as the abandoned `isar_generator` ever did, so existing schemas, queries, and `IsarCollection<T>` extensions still work unchanged.

## Tests & Performance Tooling

Database tests run on a real Isar database. They use the core library bundled in `isar_community_flutter_libs` for the desktop host, found by `isarCoreLibrary()` in `test/support/isar_core.dart`, so they run offline on macOS / Linux / Windows and are skipped when it isn't found. Tests that reach `runDbJob` also set `dbWorkerCoreLibrary`, so worker isolates can load the core.

| Test | Checks |
| --- | --- |
| `profit_flow_test.dart` | Sale → return → refund through the notifiers; Dashboard, Reports and Due Book agree |
| `worker_parity_test.dart` | Worker jobs (Due Book, reports, dashboard) and index-backed lists equal the original main-isolate filter queries **bit for bit** (doubles compared exactly) on a generated dataset |
| `db_worker_test.dart` | A worker sees the app isolate's data; the app isolate stays usable after many jobs; prints worker overhead |
| `isar_reload_test.dart` | `reloadOn` / `mergeChanges`: one load on listen, bursts coalesce, nothing loads while paused, errors forwarded |
| `paging_test.dart` | Orders tabs and movement history page through exactly the old rows; tab counts; CSV export loads every order |
| `batched_writes_test.dart` | Every batched write path gives the sequential path's stock, movements, payments and party stats |
| `backup_worker_test.dart` | Worker backup bytes equal the old `encodeAll` JSON byte for byte; restore round-trip; sync vs async recalculation; Drive restore failure codes |
| `perf_dataset_test.dart` | Restores the perf dataset through the real path, checks consistency, prints load timings. Default 1500 orders; `PERF_ORDERS=10000 flutter test test/perf_dataset_test.dart` for full size (desktop timings are relative, not phone numbers) |
| `animated_entrance_test.dart` | Only the first screenful animates; rows built after scrolling show at once; no pending timer on dispose |
| `app_zoom_test.dart` | Percent rules (snap, 320 dp cap), `zoomMediaQuery`, `AppZoom` never remounts the tree on a size change, `AppZoomScope` notifications, `ZoomBox`, `ZoomNeutral` — on a ~411 × 914 dp phone at 125% font |
| `app_zoom_platform_test.dart` | iOS keeps its system edit menu when zoomed, and where it points; fails when a Flutter upgrade fixes the target (then update `app_zoom.dart`'s comment) |
| `display_scale_test.dart` | `primeFrom` (synchronous, tolerant of bad values), setters (snap, persist, follow-phone removes the key), neither size exported nor imported by a backup |
| `display_size_sheets_test.dart` | Both sheets and their Settings rows in a zoomed app: a size applies only on commit (lift, tap, arrow key, screen reader), a lost or cancelled gesture applies nothing, the cap, Reset, the preview label's Turkish İ |
| `sidebar_order_zoom_test.dart` | Sidebar Order drag under every offered Display size: the dragged row stays under the finger; 100% draws no transform |
| `order_card_menu_test.dart` | The long-press status menu opens at the finger in a branch Navigator beside the rail, under the status bar, zoomed |
| `thin_icon_test.dart` | `ThinIcon` draws at its own size, centered in a bigger forced box; unchanged under loose constraints; a smaller box still shrinks it; same size / stroke as `warmThinIcons` caches |
| `text_scale_layout_test.dart` | Slot heights (`statCardHeight`, dashboard / reports headers), stat card, dashboard, product tile, variant option fields: clean from 80% to 150% text down to 320 dp, unchanged at 100% |
| `test/layout/*_layout_test.dart` | One file per area (customers, dashboard_reports, money_stock, orders, products, settings, settings_display_sheets, settings_shell, settings_sidebar_order, shared, suppliers): every screen, sheet and dialog with worst-case data (long names and translations, eight-digit amounts) at `kLayoutWidths` × `kLayoutTextScales` — no overflow, all text drawn whole, unchanged at 100% text on a normal phone. `settings_shell` also checks the tour is skipped when zoomed |

Also: `dashboard_range_test`, `dues_test`, `order_money_test`, `report_service_test`, `review_service_test`, `sidebar_order_test`.

**Layout harness** (`test/support/layout_harness.dart`, shared by `test/layout/`): `kLayoutWidths` (320 / 360 / 411 dp), `kLayoutTextScales` (1.0 / 1.3 / 1.5), `kRailWidth`; `loadRoboto()` loads Roboto from the Flutter SDK's cache so text measures as on an Android phone (the test font draws every glyph as a 1 em square, far wider) — only the "unchanged at 100%" checks need it, and they skip themselves when it isn't found; `layoutPhoneTheme` (the light theme with Roboto named where the theme leaves the font to the system); `setLayoutScreen`; `pumpLayoutApp` (a screen beside the sidebar rail, the text scale applied app-wide); `expectCleanLayout` (no overflow or other error); `expectWholeText` (catches a paragraph cut off by a short box, which reports no overflow).

**`tool/`** (dev-only, not bundled):

- `tool/perf_dataset.dart` — `PerfDataset(orderCount:, productCount:, customerCount:, seed:)`. A deterministic, internally consistent dataset: payments add up to `amountPaid`, returns are valued like the app values them, and ids follow creation time so cross-references survive a restore. It builds through `buildBackupMap`, and the tests above share it.
- `tool/gen_perf_backup.dart` — `dart run tool/gen_perf_backup.dart [--orders 10000] [--products 1000] [--customers 2000] [--seed 42] [--out build/perf_backup.json]` writes a large backup file. Import it on a **test phone only** (Settings → Local Backup → Import replaces all data). Measure performance on data like this, not an empty install.

## Build & Release

### Android Release Config

- **App label:** `Micro Seller` (with space — in `AndroidManifest.xml` `android:label`)
- **Application ID:** `com.blackshadowsoftware.micro_seller`
- **Kotlin source path:** `android/app/src/main/kotlin/com/blackshadowsoftware/micro_seller/MainActivity.kt` — must match the `package` declaration. (A previous package rename left the file at `…/blackshadowsoftwareltd/…`; the release Kotlin compiler refuses that mismatch with "Unresolved reference 'embedding'".)
- **Keystore:** Shared upload keystore at `/Users/remon/Documents/upload-keystore.jks` (same as Fuel Cost app)
- **Signing:** `android/key.properties` → read by `build.gradle.kts` → `signingConfigs.release`
- **R8/ProGuard:** enabled (`isMinifyEnabled = true`, `isShrinkResources = true`) with rules in `android/app/proguard-rules.pro` The rules also keep six `kotlin.*` classes (Unit, Result, Continuation, coroutine intrinsics) that JNI-based plugins look up by name — R8 renaming them crashed release builds at startup (flutter/flutter#194649). `shared_preferences_android` is pinned `<2.5.0` in pubspec.yaml for the same bug; lift the pin when a fixed release ships.
- **Core library desugaring:** enabled for `flutter_local_notifications`
- **NDK version:** `28.2.13676358`
- **16 KB page size compliance:** Every `.so` in the AAB must use ELF program-header alignment ≥ `0x4000` (16 KB) so it can be `mmap`'d on Android 15 devices that run with 16 KB pages. Verified at build time with `llvm-readelf -lW` looking at the first `LOAD` segment's alignment. The legacy `isar_flutter_libs` 3.1.0+1 shipped a 4 KB-aligned `libisar.so` and was the sole blocker; switching to `isar_community_flutter_libs` resolved it. Together with NDK 28 (16 KB-aligned linking by default; bumped from 27 because package:jni requires 28.2) + `useLegacyPackaging = false`, every arm64 lib in the AAB must be ≥ 16 KB aligned — re-run the check below after dependency changes.
- **Subprojects fixes** (in root `android/build.gradle.kts`, applied via `afterEvaluate` for any `com.android.library` plugin):
  1. Forces `compileSdk = 35` on plugins that hardcode older versions (resolves `android:attr/lStar not found`).
  2. Injects `namespace` from each plugin's `AndroidManifest.xml` `package` attribute when missing — required by AGP 8+. (Originally added to fix `isar_flutter_libs` 3.1.0+1; still useful for any other plugin relying on the deprecated manifest `package` attribute.)
- **Launcher icon:** Generated via `flutter_launcher_icons` from `assets/icons/app_icon.png`, named `launcher_icon`
- **Predictive back:** `android:enableOnBackInvokedCallback="true"` in manifest

### iOS Config

- **Minimum iOS version:** 16.0 (set in `ios/Podfile`)

### macOS Config

- **Minimum macOS version:** 13.0 (`platform :osx` in `macos/Podfile`)
- `post_install` raises every pod whose `MACOSX_DEPLOYMENT_TARGET` is below 13.0 up to 13.0. Xcode 27 only builds for macOS 12.0+, but Flutter 3.44's generated `FlutterMacOS.podspec` still declares 10.15, and `flutter_additional_macos_build_settings` only lifts pods below 10.14

### Toolchain

- Builds are done with **Flutter 3.44.9** (stable framework); `pubspec.lock` requires Flutter ≥ 3.44.0
- **`pubspec.lock` is committed** (`!pubspec.lock` overrides the `*.lock` ignore): Isar's generated schemas assert `Isar.version == version`, so a fresh resolve to a newer `isar_community` breaks the build at compile time. `.gitattributes` keeps LF line endings, because riverpod_generator hashes provider sources into `.g.dart`.

### CI/CD (GitHub Actions)

Setup, secrets and the release steps are in [RELEASE.md](RELEASE.md) → GitHub Releases (CI/CD).

- `.github/actions/setup-flutter` is the one place the CI Flutter version (3.44.9) is pinned; it runs `flutter pub get --enforce-lockfile`.
- `ci.yml` (PRs, pushes to `main`, and called by `release.yml`): generated code must be committed and current, l10n parity, `flutter analyze --no-fatal-infos` (errors and warnings fail), `flutter test` — and **no skipped tests**, since the real-Isar tests skip themselves when the Isar core library isn't found.
- `release.yml` (tag `vX.Y.Z` = `v` + pubspec version name, or a manual run on `main`): signed AAB + universal and split APKs in the `release` environment (required reviewer; signing secrets live only there), checked by `tool/ci/verify_android_artifacts.sh`, then a **draft** GitHub Release that is published by hand. The AAB and the obfuscation symbols are run artifacts (they expire: archive them).
- `REQUIRE_RELEASE_SIGNING=true` makes `android/app/build.gradle.kts` fail instead of falling back to the debug key when `key.properties` is missing.
- Actions are pinned to commit SHAs; Dependabot (`.github/dependabot.yml`) keeps them current.

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

# Verify signer, version and 16 KB alignment (every LOAD segment, arm64 + x86_64)
# of APKs/AABs — the same checks as CI's release job:
#   NDK_VERSION=28.2.13676358 tool/ci/verify_android_artifacts.sh <cert-sha256> <name> <code> <files>
# Quick manual look at the first LOAD segment of the arm64 libs:
LREAD=$ANDROID_HOME/ndk/28.2.13676358/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf
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

Android, iOS (min 16.0), Web, macOS (min 13.0), Linux, Windows. Web has no worker isolates or native Isar core, so `runDbJob` runs jobs inline there.

## Claude Code tooling (`.claude/`)

| Kind | Name | Use it for |
| --- | --- | --- |
| Skill | `l10n` | Any visible string: en key → `_L10nStrings` getter → 11 locales → `.claude/skills/l10n/scripts/l10n_parity.sh` (exit 0 required) |
| Skill | `new-collection` | Adding an Isar model — `kIsarSchemas`, backup encode/decode (`buildBackupMap` + `restoreBackupSync`) + `kBackupVersion` bump, clear in `clearAllCollectionsInTxnSync` (restore *and* Clear All Data), trash decision |
| Skill | `new-screen` | Screen / route / notifier conventions (keepAlive, writeTxn, sub-route before `:id`, shared widgets) |
| Skill | `verify` | After any change: build_runner (if needed) → `flutter analyze` → l10n parity |
| Skill | `release` | `/release` only — version bump, obfuscated AAB, `tool/ci/verify_android_artifacts.sh`; pushing the `vX.Y.Z` tag lets CI build the GitHub Release |
| Skill | `sync-docs` | Keep this file matching the code after a feature |
| Agent | `invariant-reviewer` | Read-only review of a diff against the money/stock/backup invariants above |
| Agent | `translator` | Fill the 11 non-English locale files for new keys |

`AppLocalizations.tr` falls back to English, then to the raw key — a missing key shows English, but parity is still required.
