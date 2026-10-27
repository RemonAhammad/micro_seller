import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A display whose shortest side is at least this many dp is a tablet's:
/// Material's compact / medium breakpoint, where the sidebar gets its labels
/// too.
const double kTabletShortestSide = 600;

/// The orientations a display [shortestSide] dp across allows: all of them
/// on a tablet (an empty list leaves it to the system, which on an iPad also
/// allows Split View and Slide Over), portrait on a phone, and portrait
/// while the size is unknown, as the app always was.
List<DeviceOrientation> orientationsFor(double? shortestSide) =>
    shortestSide != null && shortestSide >= kTabletShortestSide
    ? const []
    : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

/// Phones stay in portrait; tablets rotate and multitask, on Android and
/// iOS alike.
///
/// It measures the display, not the app's window: Split View and Android's
/// split screen narrow the window, and a tablet must stay free to rotate
/// there. main() calls [install], which applies the policy and applies it
/// again whenever the display changes it (a foldable folded or unfolded).
/// Info.plist and the manifest still allow every orientation.
class OrientationPolicy with WidgetsBindingObserver {
  OrientationPolicy._();

  static OrientationPolicy? _installed;

  /// Whether the last policy applied was a tablet's; null before the first.
  bool? _tablet;

  /// Applies the policy now and on every display change. Never throws: a
  /// platform without orientations (web, desktop) just keeps its own.
  static Future<void> install() {
    final policy = _installed ??= OrientationPolicy._();
    WidgetsBinding.instance
      ..removeObserver(policy)
      ..addObserver(policy);
    return policy._apply();
  }

  /// Stops following the display (tests).
  @visibleForTesting
  static void debugUninstall() {
    final policy = _installed;
    if (policy == null) return;
    WidgetsBinding.instance.removeObserver(policy);
    _installed = null;
  }

  /// The shortest side of the display in dp: the first display's, or the
  /// app's own view's when no display is known. Null when neither has a
  /// size yet.
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

  // Every metrics change (the keyboard's too) lands here; only a display
  // that changes the policy reaches the platform.
  @override
  void didChangeMetrics() => unawaited(_apply());
}
