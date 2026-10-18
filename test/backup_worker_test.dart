// Backup encode / restore / balance recalculation on worker isolates, against
// real Isar databases loaded with the generated performance dataset
// (tool/perf_dataset.dart): the worker paths must produce exactly what the
// old UI-isolate paths did.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/data/models/cash_register.dart';
import 'package:micro_seller/data/models/category.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/expense.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/purchase.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/models/supplier.dart';
import 'package:micro_seller/data/models/trash_entry.dart';
import 'package:micro_seller/data/services/db_worker.dart';
import 'package:micro_seller/data/services/drive_service.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/local_backup_service.dart';

import '../tool/perf_dataset.dart';
import 'support/isar_core.dart';

typedef _Dump = Map<String, List<Map<String, dynamic>>>;

/// Every row of every collection (trash included), as JSON, in id order.
Future<_Dump> _dump(Isar db) async {
  List<Map<String, dynamic>> json(List<dynamic> rows) =>
      [for (final r in rows) jsonDecode(jsonEncode(r)) as Map<String, dynamic>];
  return {
    'products': json(await db.products.where().findAll()),
    'orders': json(await db.orders.where().findAll()),
    'customers': json(await db.customers.where().findAll()),
    'expenses': json(await db.expenses.where().findAll()),
    'stockMovements': json(await db.stockMovements.where().findAll()),
    'categories': json(await db.categories.where().findAll()),
    'suppliers': json(await db.suppliers.where().findAll()),
    'purchases': json(await db.purchases.where().findAll()),
    'cashRegisters': json(await db.cashRegisters.where().findAll()),
    'payments': json(await db.payments.where().findAll()),
    'trashEntries': json(await db.trashEntries.where().findAll()),
  };
}

void _expectSameRows(_Dump actual, _Dump expected) {
  expect(actual.keys, expected.keys);
  for (final name in expected.keys) {
    final a = actual[name]!, e = expected[name]!;
    expect(a.length, e.length, reason: '$name row count');
    for (var i = 0; i < e.length; i++) {
      final x = jsonEncode(a[i]), y = jsonEncode(e[i]);
      if (x != y) expect(x, y, reason: '$name row $i');
    }
  }
}

String _withoutTimestamp(String json) =>
    json.replaceFirst(RegExp(r'"timestamp":"[^"]*"'), '"timestamp":""');

void main() {
  final coreLibrary = isarCoreLibrary();
  final service = LocalBackupService();
  late Directory dir;
  late Isar source;
  late Map<String, Object?> dataset;
  final opened = <Isar>[];

  Future<Isar> openDb(String name) async {
    final db = await Isar.open(kIsarSchemas,
        directory: dir.path, name: name, inspector: false);
    opened.add(db);
    return db;
  }

  setUpAll(() async {
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dbWorkerCoreLibrary = coreLibrary;
    dir = await Directory.systemTemp.createTemp('micro_seller_backup_worker');
    dataset = PerfDataset(
            orderCount: 1500, productCount: 150, customerCount: 300, seed: 11)
        .build();
    source = await openDb('backup_source');
    await service.decodeAll(source, jsonEncode(dataset));
  });

  tearDownAll(() async {
    if (coreLibrary == null) return;
    for (final db in opened) {
      await db.close(deleteFromDisk: true);
    }
    await dir.delete(recursive: true);
  });

  test('worker backup bytes are the old encodeAll JSON, byte for byte',
      () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final settings = <String, dynamic>{
      'shopName': 'দোকান — Shop', // non-ASCII must come out as UTF-8
      'sidebarOrder': ['dashboard', 'orders'],
      'taxRate': 7.5,
      'autoBackup': true,
    };
    final bytes = await service.encodeAllBytes(source, settings: settings);
    final old = await service.encodeAll(source, settings: settings);
    expect(_withoutTimestamp(utf8.decode(bytes)), _withoutTimestamp(old));

    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect((decoded['orders'] as List).length,
        (dataset['orders'] as List).length);
    expect(decoded['settings'], settings);
  });

  test('restoring worker bytes into another database reproduces every row '
      'and recalculates balances', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final bytes = await service.encodeAllBytes(source);
    // Drifted counters in the file: the restore must recompute them.
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    for (final c in data['customers'] as List) {
      (c as Map<String, dynamic>)['outstandingBalance'] = 12345.0;
    }
    final drifted = utf8.encode(jsonEncode(data));

    final target = await openDb('backup_target');
    // Leftovers that a restore must wipe, the recycle bin included.
    await target.writeTxn(() async {
      await target.orders.put(Order(orderNumber: 'STALE-1'));
      await target.trashEntries.put(TrashEntry(
          kind: TrashKind.expense,
          originalId: 99999,
          payload: '{}',
          label: 'stale'));
    });

    var watched = 0;
    final sub = target.orders.watchLazy().listen((_) => watched++);
    final settings =
        await service.restoreBytes(target, drifted, requireMetadata: true);
    await pumpEventQueue();
    await sub.cancel();

    expect(settings, isNull, reason: 'that backup carried no settings');
    expect(watched, greaterThan(0),
        reason: "this isolate's watchers see the worker's write");
    _expectSameRows(await _dump(target), await _dump(source));
    expect(await target.trashEntries.count(), 0);

    final orders = await target.orders.where().findAll();
    final byCustomer = <int, List<Order>>{};
    for (final o in orders) {
      byCustomer.putIfAbsent(o.customerId, () => []).add(o);
    }
    var owing = 0;
    for (final c in await target.customers.where().findAll()) {
      final due = computeNetDue(byCustomer[c.id] ?? const []);
      expect(c.outstandingBalance, due, reason: c.name);
      if (due > 0) owing++;
    }
    expect(owing, greaterThan(0), reason: 'the dataset should have debtors');
  });

  test('sync (worker) recalculation equals the async one exactly', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final db = await openDb('backup_recalc');
    await service.decodeAll(db, jsonEncode(dataset));

    Future<void> drift() => db.writeTxn(() async {
          final customers = await db.customers.where().findAll();
          await db.customers.putAll([
            for (final c in customers)
              c.copyWith(outstandingBalance: (c.id % 7) * 13.37),
          ]);
        });
    Future<List<double>> balances() async => [
          for (final c in await db.customers.where().findAll())
            c.outstandingBalance,
        ];

    await drift();
    final asyncChanged =
        await db.writeTxn(() => recalculateOutstandingBalancesInTxn(db));
    final asyncBalances = await balances();
    expect(asyncChanged, greaterThan(0));

    await drift();
    final workerChanged = await recalculateOutstandingBalances(db);
    expect(workerChanged, asyncChanged);
    expect(await balances(), asyncBalances);

    await drift();
    final syncChanged =
        db.writeTxnSync(() => recalculateOutstandingBalancesInTxnSync(db));
    expect(syncChanged, asyncChanged);
    expect(await balances(), asyncBalances);
  });

  group('Drive restore failure handling', () {
    late Isar db;
    late _Dump before;
    late Map<String, Object?> other;

    setUpAll(() async {
      if (coreLibrary == null) return;
      db = await openDb('backup_rollback');
      await service.decodeAll(db, jsonEncode(dataset));
      before = await _dump(db);
      other = PerfDataset(
              orderCount: 60, productCount: 12, customerCount: 15, seed: 5)
          .build()
        ..['settings'] = {'shopName': 'Other shop'};
    });

    Matcher failsWith(DriveErrorCode code) => throwsA(
        isA<DriveBackupException>().having((e) => e.code, 'code', code));

    test('settings failing after the restore rolls back -> rolledBack',
        () async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      var settingsCalls = 0;
      await expectLater(
        DriveService().restoreFromBytes(
          db,
          utf8.encode(jsonEncode(other)),
          currentSettings: {'shopName': 'Mine'},
          onSettingsRestored: (map) async {
            settingsCalls++;
            // The new data really was committed before this failed.
            expect(map['shopName'], 'Other shop');
            expect(await db.orders.count(), (other['orders'] as List).length);
            throw StateError('settings failed');
          },
        ),
        failsWith(DriveErrorCode.rolledBack),
      );
      expect(settingsCalls, 1);
      _expectSameRows(await _dump(db), before);
    });

    test('a malformed row fails the restore job -> rolledBack, data kept',
        () async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      final broken = jsonDecode(jsonEncode(other)) as Map<String, dynamic>;
      (broken['orders'] as List).add('not an order');
      await expectLater(
        DriveService()
            .restoreFromBytes(db, utf8.encode(jsonEncode(broken))),
        failsWith(DriveErrorCode.rolledBack),
      );
      _expectSameRows(await _dump(db), before);
    });

    test('not a backup -> invalidBackup, nothing touched', () async {
      if (coreLibrary == null) return markTestSkipped('no Isar core library');
      final cases = <Uint8List>[
        utf8.encode('{"version": 4, "timestamp": "x", "orders": ['),
        Uint8List.fromList([0xff, 0xfe, 0x00]),
        utf8.encode('[1, 2, 3]'),
        utf8.encode(jsonEncode({'orders': []})), // no version / timestamp
        utf8.encode(jsonEncode({'version': 4, 'timestamp': 'x'})),
      ];
      for (final bytes in cases) {
        await expectLater(DriveService().restoreFromBytes(db, bytes),
            failsWith(DriveErrorCode.invalidBackup));
      }
      _expectSameRows(await _dump(db), before);
    });
  });
}
