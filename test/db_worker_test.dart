import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/services/db_worker.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/local_backup_service.dart';

import '../tool/perf_dataset.dart';
import 'support/isar_core.dart';

List<Order> _allOrders(Isar db) => db.orders.where().findAllSync();
int _countOrders(Isar db) => db.orders.countSync();

// Jobs that need arguments are built by a top-level function, so the closure's
// context holds only those arguments (an inline closure in a test body would
// also carry the test's Isar, which can't cross isolates).
String? Function(Isar) _orderNumberOf(int id) =>
    (db) => db.orders.getSync(id)?.orderNumber;

void main() {
  final coreLibrary = isarCoreLibrary();
  late Directory dir;
  late Isar isar;

  setUpAll(() async {
    if (coreLibrary == null) return;
    dbWorkerCoreLibrary = coreLibrary;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dir = await Directory.systemTemp.createTemp('micro_seller_worker');
    isar = await Isar.open(kIsarSchemas,
        directory: dir.path, name: 'worker_test', inspector: false);
    final data =
        PerfDataset(orderCount: 3000, productCount: 300, customerCount: 600, seed: 3)
            .build();
    await LocalBackupService().decodeAll(isar, jsonEncode(data));
  });

  tearDownAll(() async {
    if (coreLibrary == null) return;
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  test('a worker job sees the same data as the app isolate', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final inWorker = await runDbJob(isar, _allOrders);
    final inMain = await isar.orders.where().findAll();
    expect(inWorker.map((o) => o.id), inMain.map((o) => o.id));
    expect(inWorker.map((o) => o.totalAmount), inMain.map((o) => o.totalAmount));
    expect(inWorker.first.items.length, inMain.first.items.length);
  });

  test('the app isolate stays usable after many worker jobs', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    for (var i = 0; i < 20; i++) {
      expect(await runDbJob(isar, _countOrders), greaterThan(0));
    }
    // Still open and writable here.
    expect(isar.isOpen, isTrue);
    final id = await isar.writeTxn(() => isar.orders.put(Order(orderNumber: 'X')));
    expect(await runDbJob(isar, _orderNumberOf(id)), 'X');
    await isar.writeTxn(() => isar.orders.delete(id));
  });

  test('worker overhead (printed)', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await runDbJob(isar, _countOrders);
    }
    final spawn = sw.elapsedMilliseconds / 10;
    sw.reset();
    final main = await isar.orders.where().findAll();
    final mainMs = sw.elapsedMilliseconds;
    sw.reset();
    final worker = await runDbJob(isar, _allOrders);
    final workerMs = sw.elapsedMilliseconds;
    expect(worker.length, main.length);
    // ignore: avoid_print
    print('db worker: spawn+open+count ${spawn.toStringAsFixed(1)} ms; '
        'load ${main.length} orders: app isolate $mainMs ms, worker $workerMs ms '
        '(UI-isolate time in the worker case is ~0)');
  });
}
