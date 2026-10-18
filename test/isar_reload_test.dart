import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/data/services/isar_reload.dart';

void main() {
  const settle = Duration(milliseconds: 10);
  Future<void> wait([int ms = 40]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  late StreamController<void> changes;
  late int loads;
  late List<int> emitted;

  Stream<int> source({Duration loadTime = Duration.zero}) => reloadOn<int>(
        changes.stream,
        () async {
          loads++;
          final n = loads;
          if (loadTime > Duration.zero) await Future<void>.delayed(loadTime);
          return n;
        },
        settle: settle,
      );

  setUp(() {
    changes = StreamController<void>();
    loads = 0;
    emitted = [];
  });

  // Not awaited: close() on a never-listened controller never completes.
  tearDown(() {
    changes.close();
  });

  test('loads once on listen', () async {
    final sub = source().listen(emitted.add);
    await wait();
    expect(loads, 1);
    expect(emitted, [1]);
    await sub.cancel();
  });

  test('a burst of changes costs one reload', () async {
    final sub = source().listen(emitted.add);
    await wait();
    for (var i = 0; i < 5; i++) {
      changes.add(null);
    }
    await wait();
    expect(loads, 2);
    expect(emitted, [1, 2]);
    await sub.cancel();
  });

  test('a change during a load reloads once more after it', () async {
    final sub = source(loadTime: const Duration(milliseconds: 30))
        .listen(emitted.add);
    await wait(5); // first load in flight
    changes.add(null);
    changes.add(null);
    await wait(120);
    expect(loads, 2);
    expect(emitted.last, 2);
    await sub.cancel();
  });

  test('nothing loads while paused; resume loads once', () async {
    final sub = source().listen(emitted.add);
    await wait();
    sub.pause();
    for (var i = 0; i < 4; i++) {
      changes.add(null);
      await wait(15);
    }
    expect(loads, 1, reason: 'paused listeners must not trigger loads');
    sub.resume();
    await wait();
    expect(loads, 2);
    expect(emitted, [1, 2]);
    await sub.cancel();
  });

  test('resume without changes does not reload', () async {
    final sub = source().listen(emitted.add);
    await wait();
    sub.pause();
    await wait();
    sub.resume();
    await wait();
    expect(loads, 1);
    await sub.cancel();
  });

  test('cancel stops listening and loading', () async {
    final sub = source().listen(emitted.add);
    await wait();
    await sub.cancel();
    expect(changes.hasListener, isFalse);
    changes.add(null);
    await wait();
    expect(loads, 1);
  });

  test('load errors are forwarded and the stream keeps working', () async {
    var fail = true;
    final errors = <Object>[];
    final sub = reloadOn<int>(changes.stream, () async {
      loads++;
      if (fail) throw StateError('boom');
      return loads;
    }, settle: settle)
        .listen(emitted.add, onError: errors.add);
    await wait();
    expect(errors, hasLength(1));
    fail = false;
    changes.add(null);
    await wait();
    expect(emitted, [2]);
    await sub.cancel();
  });

  test('mergeChanges forwards every source', () async {
    final a = StreamController<void>();
    final b = StreamController<void>();
    var count = 0;
    final sub = mergeChanges([a.stream, b.stream]).listen((_) => count++);
    a.add(null);
    b.add(null);
    await wait(5);
    expect(count, 2);
    await sub.cancel();
    expect(a.hasListener || b.hasListener, isFalse);
    await a.close();
    await b.close();
  });
}
