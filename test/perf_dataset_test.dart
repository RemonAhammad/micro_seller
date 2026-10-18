// Loads the generated performance dataset (tool/perf_dataset.dart) through the
// app's real restore path into a real Isar database, checks it is internally
// consistent, and prints how long the heavy data-layer loads take.
//
// Default size keeps `flutter test` quick. For the full-size numbers:
//   PERF_ORDERS=10000 flutter test test/perf_dataset_test.dart
//
// Runs on a desktop CPU, so the timings are relative (before/after a change),
// not what a low-end phone feels.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/data/models/customer.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/payment.dart';
import 'package:micro_seller/data/models/stock_movement.dart';
import 'package:micro_seller/data/services/dues_service.dart';
import 'package:micro_seller/data/services/db_worker.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/local_backup_service.dart';
import 'package:micro_seller/features/customers/providers/dues_provider.dart';
import 'package:micro_seller/features/dashboard/providers/dashboard_provider.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';
import 'package:micro_seller/features/reports/providers/reports_provider.dart';

import '../tool/perf_dataset.dart';

String? _isarCoreLibrary() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final packages = (jsonDecode(config.readAsStringSync())['packages'] as List)
      .cast<Map<String, dynamic>>();
  final pkg = packages
      .where((p) => p['name'] == 'isar_community_flutter_libs')
      .firstOrNull;
  if (pkg == null) return null;
  final root =
      Directory.fromUri(config.absolute.uri.resolve('${pkg['rootUri']}/'));
  final file = switch (Platform.operatingSystem) {
    'macos' => 'macos/libisar.dylib',
    'linux' => 'linux/libisar.so',
    'windows' => 'windows/libisar.dll',
    _ => null,
  };
  if (file == null) return null;
  final path = '${root.path}$file';
  return File(path).existsSync() ? path : null;
}

void main() {
  final coreLibrary = _isarCoreLibrary();
  final orderCount =
      int.tryParse(Platform.environment['PERF_ORDERS'] ?? '') ?? 1500;

  late Directory dir;
  late Isar isar;
  late ProviderContainer container;
  late Map<String, Object?> dataset;
  final timings = <String, int>{};

  Future<T> timed<T>(String label, Future<T> Function() run) async {
    final sw = Stopwatch()..start();
    final result = await run();
    timings[label] = sw.elapsedMilliseconds;
    return result;
  }

  setUpAll(() async {
    if (coreLibrary == null) return;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dbWorkerCoreLibrary = coreLibrary; // providers load on worker isolates
    dir = await Directory.systemTemp.createTemp('micro_seller_perf');
    isar = await Isar.open(kIsarSchemas,
        directory: dir.path, name: 'perf_test', inspector: false);
    container = ProviderContainer(
        overrides: [isarProvider.overrideWith((ref) async => isar)]);

    dataset = PerfDataset(
      orderCount: orderCount,
      productCount: (orderCount / 10).ceil(),
      customerCount: (orderCount / 5).ceil(),
      seed: 7,
    ).build();
    await timed('restore (decodeAll)',
        () => LocalBackupService().decodeAll(isar, jsonEncode(dataset)));
  });

  tearDownAll(() async {
    if (coreLibrary == null) return;
    // ignore: avoid_print
    print('perf dataset: $orderCount orders\n'
        '${timings.entries.map((e) => '  ${e.key.padRight(28)} ${e.value} ms').join('\n')}');
    container.dispose();
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  test('restore keeps every collection', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    expect(await isar.orders.count(), (dataset['orders'] as List).length);
    expect(await isar.payments.count(), (dataset['payments'] as List).length);
    expect(await isar.stockMovements.count(),
        (dataset['stockMovements'] as List).length);
    expect(await isar.customers.count(), (dataset['customers'] as List).length);
  });

  test('payments add up to amountPaid and statuses match', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final orders = await isar.orders.where().findAll();
    final payments = await isar.payments.where().findAll();
    final paidByOrder = <int, double>{};
    for (final p in payments) {
      paidByOrder[p.orderId] = (paidByOrder[p.orderId] ?? 0) + p.amount;
    }
    for (final o in orders.where((o) => !o.isReturn)) {
      expect(paidByOrder[o.id] ?? 0, closeTo(o.amountPaid, 0.01),
          reason: o.orderNumber);
      final expected = o.amountPaid >= o.totalAmount - 0.005
          ? PaymentStatus.paid
          : o.amountPaid > 0
              ? PaymentStatus.partial
              : PaymentStatus.unpaid;
      expect(o.paymentStatus, expected, reason: o.orderNumber);
    }
    for (final r in orders.where((o) => o.isReturn)) {
      expect(r.originalOrderId, greaterThan(0));
      expect(r.originalOrderId, lessThan(r.id));
    }
  });

  test('restore recalculates every balance from orders', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final orders = await isar.orders.where().findAll();
    final byCustomer = <int, List<Order>>{};
    for (final o in orders) {
      byCustomer.putIfAbsent(o.customerId, () => []).add(o);
    }
    final customers = await isar.customers.where().findAll();
    var owing = 0;
    for (final Customer c in customers) {
      final due = computeNetDue(byCustomer[c.id] ?? const []);
      expect(c.outstandingBalance, closeTo(due, 0.01), reason: c.name);
      if (due > 0) owing++;
    }
    expect(owing, greaterThan(0), reason: 'the dataset should have debtors');
  });

  test('heavy loads complete and agree', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    container.listen(ordersProvider, (_, _) {});
    final orders = await timed(
        'ordersProvider (all orders)', () => container.read(ordersProvider.future));
    expect(orders, isNotEmpty);

    container.listen(duesProvider, (_, _) {});
    final dues = await timed(
        'duesProvider (Due Book)', () => container.read(duesProvider.future));
    final customers = await isar.customers.where().findAll();
    final counterTotal =
        customers.fold(0.0, (s, c) => s + c.outstandingBalance);
    expect(dues.fold(0.0, (s, d) => s + d.totalDue),
        closeTo(counterTotal, 0.05));

    container.listen(dashboardStatsProvider, (_, _) {});
    final stats = await timed('dashboardStats',
        () => container.read(dashboardStatsProvider.future));
    expect(stats.totalOrders, orders.length);

    final now = DateTime.now();
    final yearStart = DateTime(now.year - 1, now.month, now.day);
    final salesP = salesReportProvider(yearStart, now);
    container.listen(salesP, (_, _) {});
    final sales =
        await timed('salesReport (12 months)', () => container.read(salesP.future));
    expect(sales.grossSales, greaterThan(0));
    final duesP = duesReportProvider(yearStart, now);
    container.listen(duesP, (_, _) {});
    await timed('duesReport (12 months)', () => container.read(duesP.future));
    final stockP = inventoryReportProvider(yearStart, now);
    container.listen(stockP, (_, _) {});
    await timed(
        'inventoryReport (12 months)', () => container.read(stockP.future));
  });
}
