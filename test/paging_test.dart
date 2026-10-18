// The paged Orders tabs and movement history must show exactly the rows the
// full lists showed, in the same order, for the part that is loaded — checked
// on a real Isar database restored from the perf dataset.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/services/db_worker.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/local_backup_service.dart';
import 'package:micro_seller/features/inventory/providers/inventory_provider.dart';
import 'package:micro_seller/features/orders/providers/order_pages_provider.dart';
import 'package:micro_seller/features/orders/providers/order_provider.dart';

import '../tool/perf_dataset.dart';
import 'support/isar_core.dart';

// How the Orders screen filtered and counted ordersProvider before paging.
bool _inTab(Order o, OrderTab tab) {
  if (o.isReturn) return false;
  return switch (tab) {
    OrderTab.all => true,
    OrderTab.pending => o.orderStatus == OrderStatus.pending,
    OrderTab.active =>
      o.orderStatus == OrderStatus.confirmed ||
          o.orderStatus == OrderStatus.shipped,
    OrderTab.completed => o.orderStatus == OrderStatus.completed,
    OrderTab.cancelled => o.orderStatus == OrderStatus.cancelled,
  };
}

List<int> _oldCounts(List<Order> orders) {
  final regular = orders.where((o) => !o.isReturn).toList();
  int pending = 0, active = 0, completed = 0, cancelled = 0;
  for (final o in regular) {
    switch (o.orderStatus) {
      case OrderStatus.pending:
        pending++;
      case OrderStatus.confirmed || OrderStatus.shipped:
        active++;
      case OrderStatus.completed:
        completed++;
      case OrderStatus.cancelled:
        cancelled++;
    }
  }
  return [regular.length, pending, active, completed, cancelled];
}

/// The first value of [provider] that satisfies [done].
Future<T> _until<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
  bool Function(T) done,
) {
  final completer = Completer<T>();
  final sub = container.listen<AsyncValue<T>>(provider, (_, next) {
    if (completer.isCompleted) return;
    if (next.hasError) {
      completer.completeError(next.error!, next.stackTrace);
    } else if (next.value case final v? when done(v)) {
      completer.complete(v);
    }
  }, fireImmediately: true);
  return completer.future
      .timeout(const Duration(seconds: 30))
      .whenComplete(sub.close);
}

void main() {
  final coreLibrary = isarCoreLibrary();
  late Directory dir;
  late Isar isar;
  late ProviderContainer container;

  setUpAll(() async {
    if (coreLibrary == null) return;
    dbWorkerCoreLibrary = coreLibrary;
    await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary});
    dir = await Directory.systemTemp.createTemp('micro_seller_paging');
    isar = await Isar.open(
      kIsarSchemas,
      directory: dir.path,
      name: 'paging_test',
      inspector: false,
    );
    container = ProviderContainer(
      overrides: [isarProvider.overrideWith((ref) async => isar)],
    );
    final data = PerfDataset(
      orderCount: 3000,
      productCount: 300,
      customerCount: 600,
      seed: 5,
    ).build();
    await LocalBackupService().decodeAll(isar, jsonEncode(data));
  });

  tearDownAll(() async {
    if (coreLibrary == null) return;
    container.dispose();
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  test('every Orders tab pages through exactly the old rows', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    container.listen(ordersProvider, (_, _) {});
    final all = await container.read(ordersProvider.future);
    expect(
      all.where((o) => _inTab(o, OrderTab.all)).length,
      greaterThan(kOrderPageSize * 5),
      reason: 'the dataset should need several pages',
    );

    for (final tab in OrderTab.values) {
      final expected = all.where((o) => _inTab(o, tab)).toList();
      final provider = orderPagesProvider(tab);
      container.listen(provider, (_, _) {});
      var page = await container.read(provider.future);
      var limit = kOrderPageSize;
      for (var i = 0; i < 4 && page.hasMore; i++) {
        // A second call before the page arrives must be ignored.
        container.read(provider.notifier).loadMore();
        container.read(provider.notifier).loadMore();
        limit += kOrderPageSize;
        final want = limit;
        page = await _until(
          container,
          provider,
          (p) => p.orders.length >= want || !p.hasMore,
        );
      }
      expect(page.orders.length, min(expected.length, limit), reason: tab.name);
      expect(page.hasMore, expected.length > limit, reason: tab.name);
      expect(
        page.orders.map((o) => o.id),
        expected.take(page.orders.length).map((o) => o.id),
        reason: tab.name,
      );
    }
  });

  test('tab counts equal the old counting', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    container.listen(ordersProvider, (_, _) {});
    final all = await container.read(ordersProvider.future);
    container.listen(orderTabCountsProvider, (_, _) {});
    expect(
      await container.read(orderTabCountsProvider.future),
      _oldCounts(all),
    );
  });

  test('the CSV export loads every order, newest first', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    container.listen(ordersProvider, (_, _) {});
    final all = await container.read(ordersProvider.future);
    final exported = await loadAllOrdersNewestFirst(isar);
    expect(exported.map((o) => o.id), all.map((o) => o.id));
  });

  test('a new order shows on top of its tabs and in the counts', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    final allP = orderPagesProvider(OrderTab.all);
    final pendingP = orderPagesProvider(OrderTab.pending);
    container.listen(allP, (_, _) {});
    container.listen(pendingP, (_, _) {});
    container.listen(orderTabCountsProvider, (_, _) {});
    final before = await container.read(orderTabCountsProvider.future);

    final id = await isar.writeTxn(
      () => isar.orders.put(
        Order(
          orderNumber: 'NEW',
          createdAt: DateTime.now().add(const Duration(days: 1)),
        ),
      ),
    );
    await _until(container, allP, (p) => p.orders.first.id == id);
    await _until(container, pendingP, (p) => p.orders.first.id == id);
    final after = await _until(
      container,
      orderTabCountsProvider,
      (c) => c[0] == before[0] + 1,
    );
    expect(after, [before[0] + 1, before[1] + 1, ...before.skip(2)]);

    await isar.writeTxn(() => isar.orders.delete(id));
    await _until(container, allP, (p) => p.orders.first.id != id);
    await _until(container, orderTabCountsProvider, (c) => c[0] == before[0]);
  });

  test('movement history pages through the full list, newest first', () async {
    if (coreLibrary == null) return markTestSkipped('no Isar core library');
    container.listen(stockMovementsProvider, (_, _) {});
    final all = await container.read(stockMovementsProvider.future);
    expect(
      all.length,
      greaterThan(kMovementPageSize * 4),
      reason: 'the dataset should need several pages',
    );
    final outOfOrder = [
      for (var i = 1; i < all.length; i++)
        if ((all[i - 1].createdAt ?? DateTime(0)).isBefore(
          all[i].createdAt ?? DateTime(0),
        ))
          i,
    ];
    expect(outOfOrder, isEmpty, reason: 'rows newer than the row before');

    final provider = stockMovementPagesProvider;
    container.listen(provider, (_, _) {});
    var page = await container.read(provider.future);
    var limit = kMovementPageSize;
    for (var i = 0; i < 3 && page.hasMore; i++) {
      container.read(provider.notifier).loadMore();
      container.read(provider.notifier).loadMore();
      limit += kMovementPageSize;
      final want = limit;
      page = await _until(
        container,
        provider,
        (p) => p.movements.length >= want || !p.hasMore,
      );
    }
    expect(page.movements.length, min(all.length, limit));
    expect(page.hasMore, all.length > limit);
    expect(
      page.movements.map((m) => m.id),
      all.take(page.movements.length).map((m) => m.id),
    );
  });
}
