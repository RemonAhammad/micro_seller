import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The width of the back-swipe strip at a page's leading edge: iOS's own,
/// and Flutter's in `CupertinoPageRoute`. Wider where the screen's inset on
/// that side is.
const double _kStripWidth = 20;

/// A release at least this fast, in navigator widths per second, pops or
/// keeps the page by its direction alone; a slower one by how far the page
/// got (Flutter's rule for its own strip).
const double _kMinFlingVelocity = 1;

/// Remembers the top route of the branch navigator it observes: the page
/// [ShellEdgeBackSwipe] swipes away.
class BranchTopRouteObserver extends NavigatorObserver {
  /// The observed navigator's top route: set on its first build, on every
  /// push and replace, and as soon as a pop starts (to the page below).
  Route<dynamic>? get topRoute => _topRoute;
  Route<dynamic>? _topRoute;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _topRoute = topRoute;
  }
}

/// iOS's back swipe from the screen's leading edge, where the sidebar is.
///
/// On iOS a pushed screen (a [MaterialPage], [MaterialPageRoute] or
/// [CupertinoPageRoute]) is swiped back from a 20 dp strip at its own leading
/// edge, which in the shell starts beside the sidebar. This puts the same
/// strip at the screen's edge, over the sidebar. A drag from there moves the
/// current branch's top page with the finger, as the page's own strip does,
/// through the route's public back-gesture API ([PredictiveBackRoute]):
/// released past halfway or flung back, the page is popped; otherwise it
/// slides back in.
///
/// The sidebar keeps its taps, long presses and vertical scrolls: the strip
/// joins a touch only when the page can be swiped away (not on a tab's first
/// screen), and takes it only once the finger moves sideways past the touch
/// slop. While a page follows the finger, the rest of the shell ignores
/// touches.
///
/// Every branch of [shell] needs a [BranchTopRouteObserver].
class ShellEdgeBackSwipe extends StatefulWidget {
  const ShellEdgeBackSwipe({
    super.key,
    required this.enabled,
    required this.shell,
    required this.child,
  });

  /// Whether the strip takes swipes. The tree is the same either way, so
  /// switching it never rebuilds the shell from scratch.
  final bool enabled;

  /// The shell whose current branch's top page is swiped away.
  final StatefulNavigationShell shell;

  /// The shell's contents: the sidebar beside the branch navigators.
  final Widget child;

  @override
  State<ShellEdgeBackSwipe> createState() => _ShellEdgeBackSwipeState();
}

class _ShellEdgeBackSwipeState extends State<ShellEdgeBackSwipe> {
  late final HorizontalDragGestureRecognizer _recognizer;

  /// The page a finger is swiping, its navigator, and the navigator's width
  /// (a whole swipe), in the shell's own dp, as the drag's are: inside the
  /// Display size zoom, the page follows the finger 1:1.
  PageRoute<dynamic>? _route;
  NavigatorState? _navigator;
  double _width = 0;

  /// While a page follows the finger, the rest of the shell ignores touches.
  bool _swiping = false;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      // Only once the finger has moved sideways past the touch slop, even
      // where nothing else wants the touch (the sidebar between its icons):
      // a tap or a resting thumb there doesn't start a swipe, which would
      // stop the shell taking touches.
      ..onlyAcceptDragOnThreshold = true
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void didUpdateWidget(ShellEdgeBackSwipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        widget.shell.currentIndex != oldWidget.shell.currentIndex) {
      _abandon();
    }
  }

  @override
  void dispose() {
    _abandon();
    _recognizer.dispose();
    super.dispose();
  }

  /// The current branch's top page, if an edge swipe may take it: a
  /// Material or Cupertino page (iOS's slide) that is on top, done
  /// animating, and lets a user gesture pop it (not a tab's first screen,
  /// nor one that refuses a pop), with no other swipe under way.
  PageRoute<dynamic>? _swipeablePage() {
    if (!widget.enabled) return null;
    final shell = widget.shell;
    final observer = shell.route.branches[shell.currentIndex].observers
        ?.whereType<BranchTopRouteObserver>()
        .firstOrNull;
    final navigator = observer?.navigator;
    final route = observer?.topRoute;
    if (navigator == null ||
        !navigator.mounted ||
        navigator.userGestureInProgress) {
      return null;
    }
    if (route is! PageRoute ||
        (route is! MaterialRouteTransitionMixin &&
            route is! CupertinoRouteTransitionMixin)) {
      return null;
    }
    return route.navigator == navigator &&
            route.isCurrent &&
            route.popGestureEnabled
        ? route
        : null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_route == null && _swipeablePage() != null) {
      _recognizer.addPointer(event);
    }
  }

  void _handleDragStart(DragStartDetails details) {
    // Asked again: the page may have changed since the finger went down.
    final route = _swipeablePage();
    final navigator = route?.navigator;
    final box = navigator?.context.findRenderObject();
    if (route == null ||
        navigator == null ||
        box is! RenderBox ||
        !box.hasSize ||
        box.size.width <= 0) {
      return;
    }
    _route = route;
    _navigator = navigator;
    _width = box.size.width;
    // Starts the navigator's gesture, which keeps the page's slide linear
    // under the finger, from where the page is (all the way in).
    route.handleStartBackGesture(progress: route.animation!.value);
    setState(() => _swiping = true);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final route = _route;
    if (route == null) return;
    // A no-op once the page isn't on top any more (the app navigated).
    route.handleUpdateBackGestureProgress(
      progress: clampDouble(
        route.animation!.value - _logical(details.primaryDelta! / _width),
        0,
        1,
      ),
    );
  }

  void _handleDragEnd(DragEndDetails details) =>
      _finish(_logical(details.velocity.pixelsPerSecond.dx / _width));

  // Also called for a touch that never became a swipe, with nothing to end.
  void _handleDragCancel() => _finish(0);

  /// The finger left the screen at [velocity] (navigator widths per second,
  /// positive the way the page leaves): the page is popped or slides back
  /// in, by Flutter's own rule.
  void _finish(double velocity) {
    final route = _route;
    final navigator = _navigator;
    if (route == null || navigator == null) return;
    _route = null;
    _navigator = null;
    setState(() => _swiping = false);
    final bool keep;
    if (!route.isCurrent) {
      // The app navigated mid-swipe: the page stays if it's still there.
      keep = route.isActive;
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      keep = velocity <= 0;
    } else {
      keep = route.animation!.value > 0.5;
    }
    _settle(route, navigator, keep: keep);
  }

  /// Ends a swipe the shell can't finish: another tab is shown, the strip is
  /// switched off, or the shell is going away. After this frame, since
  /// ending the gesture rebuilds the pages: a page still in the tab, on top
  /// or under a route pushed since, is put back in place at once (it's out
  /// of sight or going), and the gesture ends.
  void _abandon() {
    final route = _route;
    final navigator = _navigator;
    if (route == null || navigator == null) return;
    _route = null;
    _navigator = null;
    _swiping = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      if (route.isActive) _transitionOf(route).value = 1;
      _settle(route, navigator, keep: route.isActive);
    });
  }

  /// Ends [navigator]'s gesture on [route] exactly once, whatever happens to
  /// the page meanwhile: a gesture left running would keep every page of
  /// the tab ignoring touches.
  static void _settle(
    PageRoute<dynamic> route,
    NavigatorState navigator, {
    required bool keep,
  }) {
    final animation = route.animation!;
    if (keep && (route.isCurrent || animation.isCompleted)) {
      // Slides the page back in, and ends the gesture at the animation's
      // next status change.
      route.handleCancelBackGesture();
      if (!animation.isAnimating) return;
      // A page removed before that change gets none: end it then.
      var changed = false;
      void onStatus(AnimationStatus status) {
        changed = true;
        animation.removeStatusListener(onStatus);
      }

      animation.addStatusListener(onStatus);
      route.completed.whenComplete(() {
        if (!changed && navigator.mounted) navigator.didStopUserGesture();
      });
      return;
    }
    if (keep) {
      // Covered mid-swipe by a route the app pushed on the tab (the order
      // form's "Order created" sheet): the back-gesture API moves only a
      // page on top, so this one would stay where the finger left it, the
      // page below showing beside it. It slides back in here, as Flutter's
      // own iOS swipe does, with the gesture lasting until it is in.
      _transitionOf(route).forward();
    } else if (route.isCurrent) {
      // A pop slides the page off from where the finger left it.
      // handleCommitBackGesture would start that from all the way in.
      navigator.pop();
    }
    var ended = false;
    void end() {
      if (ended) return;
      ended = true;
      if (navigator.mounted) navigator.didStopUserGesture();
    }

    // The gesture lasts until the page is gone or back in, so its slide
    // stays linear.
    if (!animation.isAnimating) {
      end();
      return;
    }
    void onStatus(AnimationStatus status) {
      if (status.isAnimating) return;
      animation.removeStatusListener(onStatus);
      end();
    }

    animation.addStatusListener(onStatus);
    // A page removed mid-slide gets no status change.
    route.completed.whenComplete(end);
  }

  /// The controller of [route]'s slide. The back-gesture API moves it only
  /// while the route is on top, and Flutter's own swipes drive it directly,
  /// as [_settle] does for a page covered mid-swipe.
  static AnimationController _transitionOf(PageRoute<dynamic> route) =>
      // ignore: invalid_use_of_protected_member
      route.controller!;

  /// [value] along the reading direction: towards the trailing side is
  /// positive, in right-to-left languages too.
  double _logical(double value) => switch (Directionality.of(context)) {
    TextDirection.rtl => -value,
    TextDirection.ltr => value,
  };

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final inset = switch (Directionality.of(context)) {
      TextDirection.rtl => padding.right,
      TextDirection.ltr => padding.left,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(ignoring: _swiping, child: widget.child),
        // From the screen's very edge (outside the shell's SafeArea), on the
        // leading side: the right in Arabic and Urdu, as the sidebar.
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: math.max(inset, _kStripWidth),
          // Translucent: the sidebar beneath gets the touch too, and keeps
          // it unless the finger moves sideways past the touch slop.
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: widget.enabled ? _handlePointerDown : null,
          ),
        ),
      ],
    );
  }
}
