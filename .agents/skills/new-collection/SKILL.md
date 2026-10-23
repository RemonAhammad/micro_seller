---
name: new-collection
description: Checklist for adding a new Isar collection (model) to Micro Seller — schema list, backup encode/decode + version bump, Clear All Data, trash decision, codegen, docs. Use when creating any new @collection model or adding a field that must survive backup/restore.
---

# Adding an Isar collection

Every step matters. A skipped one fails silently: the data never gets backed up, or it survives Clear All Data.

## Checklist

1. **Model** `lib/data/models/<name>.dart`. Follow `customer.dart`:
   - `import 'package:isar_community/isar.dart';` — never `package:isar/isar.dart`
   - `@collection` + `@JsonSerializable()`, `part '<name>.g.dart';`
   - `Id id = Isar.autoIncrement`, `DateTime? createdAt`, `copyWith`, `fromJson`/`toJson`
   - Put `@Index()` on foreign-key fields you'll query (`customerId`, `orderId`, …)
   - Enums: `@Enumerated(EnumType.name)`, so reordering an enum doesn't corrupt data
   - Computed getters take `@ignore`
   - If the default plural reads badly, set `@Collection(accessor: '...')` (see `trash_entry.dart`)
2. **Schema list:** add `<Name>Schema` to `kIsarSchemas` in `lib/data/services/isar_service.dart`. The app and the background auto-backup worker (`auto_backup_runner.dart`, a separate isolate) both open the database with this constant. **Never** give either `Isar.open` its own list: the worker's hand-kept copy once fell behind and was missing `TrashEntrySchema`.
3. **Backup:**
   - `lib/data/services/backup_format.dart`: add a required `List<Name>` parameter and `'<plural>': rows.map((e) => e.toJson()).toList()` to `buildBackupMap`, and bump `kBackupVersion`. The required parameter makes every encoder fail to compile until it passes the new rows.
   - `lib/data/services/local_backup_service.dart`: pass the rows in `encodeBackupBytesSync` (`findAllSync`, worker isolate) and `encodeAll`; in `restoreBackupSync` read them with the `rows('<plural>', Name.fromJson)` helper (a missing key means an older backup — restore empty) and `putAllSync` them inside its single `writeTxnSync`.
   - Drive backup, export and auto backup all go through these, so they need no separate change.
4. **Clear All Data / restore:** add `db.<plural>.clearSync()` to `clearAllCollectionsInTxnSync` in `local_backup_service.dart` — restore and Settings → Clear All Data both use it, so the two can't drift apart.
5. **Trash decision:** should deleting a row be undoable? If yes, add a `TrashKind`, call `TrashService.capture()` inside the delete's `writeTxn`, and handle it in `restore()`. Record any side effects in the sidecar. If not, write down why in the provider.
6. **Codegen and docs:** `dart run build_runner build --delete-conflicting-outputs`, then add a row to the AGENTS.md Data Models table and fix any collection counts ("N collections").

## Check
`grep -rn "Isar.open" lib --include='*.dart'` should show only calls that pass `kIsarSchemas` (the app, the auto-backup worker and `db_worker.dart`'s `openSync`). `grep -n "<plural>" lib/data/services/backup_format.dart lib/data/services/local_backup_service.dart` should hit `buildBackupMap`, both encoders, the restore and `clearAllCollectionsInTxnSync`. `test/backup_worker_test.dart` round-trips every collection — extend it. Then run the `verify` skill.
