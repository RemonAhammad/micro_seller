import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const double kTabletShortestSide = 600;

List<DeviceOrientation> orientationsFor(double? shortestSide) =>
    shortestSide != null && shortestSide >= kTabletShortestSide
    ? const []
    : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

class OrientationPolicy with WidgetsBindingObserver {
  OrientationPolicy._();

  static OrientationPolicy? _installed;

  bool? _tablet;

  static Future<void> install() {
    final policy = _installed ??= OrientationPolicy._();
    WidgetsBinding.instance
      ..removeObserver(policy)
      ..addObserver(policy);
    return policy._apply();
  }

  @visibleForTesting
  static void debugUninstall() {
    final policy = _installed;
    if (policy == null) return;
    WidgetsBinding.instance.removeObserver(policy);
    _installed = null;
  }

  @visibleForTesting
  static double? shortestDisplaySide(PlatformDispatcher dispatcher) {
    for (final display in dispatcher.displays) {
      final size = display.size;
      if (display.devicePixelRatio > 0 && !size.isEmpty) {
        return size.shortestSide / display.devicePixelRatio;
      }
    }
    final view = dispatcher.implicitView;
    if (view != null &&
        view.devicePixelRatio > 0 &&
        !view.physicalSize.isEmpty) {
      return view.physicalSize.shortestSide / view.devicePixelRatio;
    }
    return null;
  }

  Future<void> _apply() async {
    final side = shortestDisplaySide(
      WidgetsBinding.instance.platformDispatcher,
    );
    final tablet = side != null && side >= kTabletShortestSide;
    if (tablet == _tablet) return;
    _tablet = tablet;
    try {
      await SystemChrome.setPreferredOrientations(orientationsFor(side));
    } catch (e) {
      if (kDebugMode) debugPrint('[orientation] not applied: $e');
    }
  }

  @override
  void didChangeMetrics() => unawaited(_apply());
}
