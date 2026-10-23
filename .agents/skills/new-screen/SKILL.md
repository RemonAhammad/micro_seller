---
name: new-screen
description: Conventions for adding a screen, route, or Riverpod provider/notifier to Micro Seller. Use when building any new UI screen, bottom sheet, or data-mutating notifier so it matches the app's patterns (keepAlive notifiers, writeTxn, GoRouter branch routes, localization, responsive layout).
---

# Adding a screen or notifier

## Providers (`lib/features/<feature>/providers/`)
- **CRUD notifiers must use `@Riverpod(keepAlive: true)`.** Riverpod 3 disposes providers automatically, so a screen's `ref.read(xProvider.notifier).save()` can dispose the notifier during the `await`, and the following `state =` throws `UnmountedRefException`.
- Riverpod 3 details: use plain `Ref`, and `@riverpod class FooNotifier` generates `fooProvider`. `AsyncValue.value` is nullable; `valueOrNull` no longer exists.
- Mutations: `state = await AsyncValue.guard(() async { final isar = await ref.read(isarProvider.future); await isar.writeTxn(() async { ... }); });`
- **Every related write goes in one `writeTxn`.** If an operation changes stock, it updates **both** the base `stockQty` and the matching `VariantCombination.stockQty`, and writes a `StockMovement`. If it changes money, it updates customer or supplier totals, and on delete or cancel it reverses them.
- Lists: a `Stream` provider that yields `reloadOn(isar.<x>.watchLazy(), query.findAll)` (`lib/data/services/isar_reload.dart`) — not `query.watch(fireImmediately: true)`, which replays one full reload per write while the tab is offstage (Riverpod 3 pauses it). Big collections load in a worker: `reloadOn(..., () => runDbJob(isar, job))` with `job` built by a top-level function from plain values (`db_worker.dart`); long lists page (see `order_pages_provider.dart`). Providers that only need to know *that* something changed watch a revision counter (`isar_revisions.dart`) instead of a whole list.
- Index where-clauses don't return equal keys in id order: re-sort by id before summing money.

## Routes (`lib/core/router/app_router.dart`)
- A new screen normally goes as a sub-route of an existing `StatefulShellBranch`. Adding a sidebar branch changes `sidebarOrder`, `hiddenSidebarItems` and the backup settings, so only do it when there's a real reason.
- Fixed sub-paths (`add`, `dues`, `catalog`) go **before** `:id`, or GoRouter will read them as an id.
- Navigate with `context.push(...)` for detail screens and `context.go(...)` to switch branches.

## Widgets
- Strings: `final s = AppStrings.of(context);`. Nothing hardcoded (see the `l10n` skill).
- Icons: thin Tabler only — `ThinIcon(tabler.Plus.new)` with `import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;`. Never `Icon(Icons.…)`. Icon parameters are typed `ThinIconBuilder`, not `IconData`. Shared icons go in `AppIcons`.
- Responsive: use `LayoutBuilder`, with 600px as the phone/tablet breakpoint and grids sized by `width / 170–180` clamped to 2–6 columns.
- Reuse shared widgets: `EmptyState`, `AppBottomSheet.show`, `ConfirmDialog.show`, `AppButton`, `AppTextField`, `LoadingShimmer`, `Debouncer` (400ms search).
- Number fields always get `inputFormatters` (`FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))` for money).
- Money: always `CurrencyFormatter.format(x)`, never a literal ৳.
- Deletes: confirm first, then `context.showUndoSnackBar(...)` if the kind supports trash.
- Destructive or security-sensitive actions go through `runAuthGate(context, ...)`.
- FABs are icon-only with a tooltip and a 16px-radius rounded square. Cards use a 14px radius. Status badges are text-only.
- Form errors show friendly messages, never a raw exception string.

## Before finishing
Run the `verify` skill.
