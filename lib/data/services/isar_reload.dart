import 'dart:async';

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
