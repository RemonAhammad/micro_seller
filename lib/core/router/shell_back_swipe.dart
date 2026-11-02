import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const double _kStripWidth = 20;

const double _kMinFlingVelocity = 1;

class BranchTopRouteObserver extends NavigatorObserver {

  Route<dynamic>? get topRoute => _topRoute;
  Route<dynamic>? _topRoute;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _topRoute = topRoute;
  }
}

class ShellEdgeBackSwipe extends StatefulWidget {
  const ShellEdgeBackSwipe({
    super.key,
    required this.enabled,
    required this.shell,
    required this.child,
  });

  final bool enabled;

  final StatefulNavigationShell shell;

  final Widget child;

  @override
  State<ShellEdgeBackSwipe> createState() => _ShellEdgeBackSwipeState();
}

class _ShellEdgeBackSwipeState extends State<ShellEdgeBackSwipe> {
  late final HorizontalDragGestureRecognizer _recognizer;

  PageRoute<dynamic>? _route;
  NavigatorState? _navigator;
  double _width = 0;

  bool _swiping = false;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)

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

    route.handleStartBackGesture(progress: route.animation!.value);
    setState(() => _swiping = true);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final route = _route;
    if (route == null) return;

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

  void _handleDragCancel() => _finish(0);

  void _finish(double velocity) {
    final route = _route;
    final navigator = _navigator;
    if (route == null || navigator == null) return;
    _route = null;
    _navigator = null;
    setState(() => _swiping = false);
    final bool keep;
    if (!route.isCurrent) {

      keep = route.isActive;
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      keep = velocity <= 0;
    } else {
      keep = route.animation!.value > 0.5;
    }
    _settle(route, navigator, keep: keep);
  }

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

  static void _settle(
    PageRoute<dynamic> route,
    NavigatorState navigator, {
    required bool keep,
  }) {
    final animation = route.animation!;
    if (keep && (route.isCurrent || animation.isCompleted)) {

      route.handleCancelBackGesture();
      if (!animation.isAnimating) return;

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

      _transitionOf(route).forward();
    } else if (route.isCurrent) {

      navigator.pop();
    }
    var ended = false;
    void end() {
      if (ended) return;
      ended = true;
      if (navigator.mounted) navigator.didStopUserGesture();
    }

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

    route.completed.whenComplete(end);
  }

  static AnimationController _transitionOf(PageRoute<dynamic> route) =>
      // ignore: invalid_use_of_protected_member
      route.controller!;

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

        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: math.max(inset, _kStripWidth),

          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: widget.enabled ? _handlePointerDown : null,
          ),
        ),
      ],
    );
  }
}
