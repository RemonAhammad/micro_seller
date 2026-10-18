import 'dart:async';

/// A stream of fresh snapshots from [load], reloaded when [changes] fires —
/// the replacement for `query.watch(fireImmediately: true)` in providers.
///
/// Isar's `watch()` is `watchLazy().asyncMap(findAll)`: one full query and
/// deserialization per change event, in order, none skipped. Riverpod 3
/// pauses providers whose widgets are offstage (go_router keeps every visited
/// tab mounted under `TickerMode(false)`), so while a tab is hidden its events
/// queue up and replay as one full reload each when it is shown again; and a
/// transaction touching two watched collections reloads twice.
///
/// Here a change only marks the data dirty:
/// - the first load runs as soon as someone listens;
/// - changes within [settle] of each other cost one reload;
/// - at most one load runs at a time — changes during a load cause one more
///   load after it, so the last snapshot always reflects the last write;
/// - nothing loads while the listener is paused; resuming loads once if
///   anything changed meanwhile.
Stream<T> reloadOn<T>(
  Stream<void> changes,
  Future<T> Function() load, {
  Duration settle = const Duration(milliseconds: 16),
}) {
  late final StreamController<T> controller;
  StreamSubscription<void>? changeSub;
  Timer? settleTimer;
  var dirty = true;
  var loading = false;
  var cancelled = false;

  Future<void> pump() async {
    if (loading) return;
    loading = true;
    try {
      while (dirty && !cancelled && !controller.isPaused) {
        dirty = false;
        try {
          final value = await load();
          if (!cancelled) controller.add(value);
        } catch (e, st) {
          if (!cancelled) controller.addError(e, st);
        }
      }
    } finally {
      loading = false;
    }
  }

  void onChange(void _) {
    dirty = true;
    settleTimer ??= Timer(settle, () {
      settleTimer = null;
      pump();
    });
  }

  controller = StreamController<T>(
    onListen: () {
      // Subscribe before the first load, so a write during it isn't missed.
      changeSub = changes.listen(onChange, onError: controller.addError);
      pump();
    },
    onResume: pump,
    onCancel: () async {
      cancelled = true;
      settleTimer?.cancel();
      await changeSub?.cancel();
    },
  );
  return controller.stream;
}

/// Merges change notifiers (e.g. several collections' `watchLazy()`) into one,
/// for [reloadOn].
Stream<void> mergeChanges(List<Stream<void>> streams) {
  final subs = <StreamSubscription<void>>[];
  late final StreamController<void> controller;
  controller = StreamController<void>(
    onListen: () {
      for (final s in streams) {
        subs.add(s.listen(controller.add, onError: controller.addError));
      }
    },
    onCancel: () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    },
  );
  return controller.stream;
}
