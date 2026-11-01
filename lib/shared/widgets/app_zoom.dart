

library;

import 'dart:math' as math;
import 'dart:ui' as ui show DisplayFeature;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const int kMinDisplayPercent = 80;

const int kMaxDisplayPercent = 130;

const int kDisplayPercentStep = 5;

const double kMinZoomedLayoutWidth = 320;

int snapPercent(num value) {
  if (!value.isFinite) return 100;

  final clamped = value.clamp(kMinDisplayPercent, kMaxDisplayPercent);
  return (clamped / kDisplayPercentStep).round() * kDisplayPercentStep;
}

int maxDisplayPercentFor(double windowWidth) {
  if (!windowWidth.isFinite || windowWidth <= 0) return 100;

  final steps =
      (100 * windowWidth / kMinZoomedLayoutWidth + 1e-9) ~/ kDisplayPercentStep;
  return (steps * kDisplayPercentStep).clamp(100, kMaxDisplayPercent);
}

int effectiveDisplayPercent(int requested, double windowWidth) =>
    math.min(snapPercent(requested), maxDisplayPercentFor(windowWidth));

MediaQueryData zoomMediaQuery(
  MediaQueryData outer,
  double scale, {
  TextScaler? textScaler,
}) {
  if (scale == 1.0) {

    return textScaler == null || textScaler == outer.textScaler
        ? outer
        : outer.copyWith(textScaler: textScaler);
  }

  final cornerRadii = outer.displayCornerRadii;
  return MediaQueryData(
    size: outer.size / scale,
    devicePixelRatio: outer.devicePixelRatio * scale,
    textScaler: textScaler ?? outer.textScaler,
    platformBrightness: outer.platformBrightness,
    padding: outer.padding / scale,
    viewInsets: outer.viewInsets / scale,
    systemGestureInsets: outer.systemGestureInsets / scale,
    viewPadding: outer.viewPadding / scale,
    alwaysUse24HourFormat: outer.alwaysUse24HourFormat,
    accessibleNavigation: outer.accessibleNavigation,
    invertColors: outer.invertColors,
    highContrast: outer.highContrast,
    onOffSwitchLabels: outer.onOffSwitchLabels,
    disableAnimations: outer.disableAnimations,
    boldText: outer.boldText,
    supportsAnnounce: outer.supportsAnnounce,
    navigationMode: outer.navigationMode,
    gestureSettings: outer.gestureSettings,
    displayFeatures: [
      for (final feature in outer.displayFeatures)
        ui.DisplayFeature(
          bounds: Rect.fromLTRB(
            feature.bounds.left / scale,
            feature.bounds.top / scale,
            feature.bounds.right / scale,
            feature.bounds.bottom / scale,
          ),
          type: feature.type,
          state: feature.state,
        ),
    ],
    supportsShowingSystemContextMenu: outer.supportsShowingSystemContextMenu,
    lineHeightScaleFactorOverride: outer.lineHeightScaleFactorOverride,
    letterSpacingOverride: outer.letterSpacingOverride,
    wordSpacingOverride: outer.wordSpacingOverride,
    paragraphSpacingOverride: outer.paragraphSpacingOverride,
    displayCornerRadii: cornerRadii == null ? null : cornerRadii / scale,
  );
}

class ZoomBox extends SingleChildRenderObjectWidget {
  const ZoomBox({super.key, required this.scale, super.child});

  final double scale;

  @override
  RenderZoomBox createRenderObject(BuildContext context) =>
      RenderZoomBox(scale: scale);

  @override
  void updateRenderObject(BuildContext context, RenderZoomBox renderObject) {
    renderObject.scale = scale;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('scale', scale));
  }
}

class RenderZoomBox extends RenderProxyBox {
  RenderZoomBox({required double scale, RenderBox? child})
    : assert(scale > 0 && scale.isFinite),
      _scale = scale,
      super(child);

  double get scale => _scale;
  double _scale;
  set scale(double value) {
    assert(value > 0 && value.isFinite);
    if (value == _scale) return;
    _scale = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  Matrix4 get _transform => Matrix4.diagonal3Values(_scale, _scale, 1);

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMinIntrinsicWidth(height / _scale) ?? 0) * _scale;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      (child?.getMaxIntrinsicWidth(height / _scale) ?? 0) * _scale;

  @override
  double computeMinIntrinsicHeight(double width) =>
      (child?.getMinIntrinsicHeight(width / _scale) ?? 0) * _scale;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (child?.getMaxIntrinsicHeight(width / _scale) ?? 0) * _scale;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(
      child.getDryLayout(constraints / _scale) * _scale,
    );
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final distance = child?.getDryBaseline(constraints / _scale, baseline);
    return distance == null ? null : distance * _scale;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final distance = child?.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance * _scale;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints / _scale, parentUsesSize: true);

    size = constraints.constrain(child.size * _scale);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _scale == 1.0 ? null : _transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    if (_scale != 1.0) transform.multiply(_transform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || _scale == 1.0) {
      layer = null;
      if (child != null) context.paintChild(child, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('scale', scale));
  }
}

class AppZoomScope extends InheritedWidget {
  const AppZoomScope({
    super.key,
    required this.scale,
    required this.displayPercent,
    required this.outer,
    required super.child,
  });

  final double scale;

  final int displayPercent;

  final MediaQueryData outer;

  static AppZoomScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppZoomScope>();

  static double scaleOf(BuildContext context) => maybeOf(context)?.scale ?? 1.0;

  @override
  bool updateShouldNotify(AppZoomScope oldWidget) =>
      scale != oldWidget.scale ||
      displayPercent != oldWidget.displayPercent ||
      !_sameApartFromInsets(outer, oldWidget.outer);

  static bool _sameApartFromInsets(MediaQueryData a, MediaQueryData b) =>
      identical(a, b) ||
      a.copyWith(
            padding: b.padding,
            viewPadding: b.viewPadding,
            viewInsets: b.viewInsets,
            systemGestureInsets: b.systemGestureInsets,
          ) ==
          b;
}

class AppZoom extends StatelessWidget {
  const AppZoom({
    super.key,
    required this.displayPercent,
    this.textPercent,
    required this.child,
  });

  final int displayPercent;
  final int? textPercent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outer = MediaQuery.of(context);
    final percent = effectiveDisplayPercent(displayPercent, outer.size.width);
    final scale = percent / 100;
    final textScaler = textPercent == null
        ? null
        : TextScaler.linear(snapPercent(textPercent!) / 100);
    return AppZoomScope(
      scale: scale,
      displayPercent: percent,
      outer: outer,
      child: MediaQuery(
        data: zoomMediaQuery(outer, scale, textScaler: textScaler),
        child: ZoomBox(scale: scale, child: child),
      ),
    );
  }
}

class ZoomNeutral extends StatelessWidget {
  const ZoomNeutral({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = AppZoomScope.maybeOf(context);
    final scale = scope?.scale ?? 1.0;
    final mq = MediaQuery.of(context);
    return AppZoomScope(
      scale: 1.0,
      displayPercent: 100,
      outer: scope?.outer ?? mq,
      child: MediaQuery(
        data: zoomMediaQuery(mq, 1 / scale, textScaler: mq.textScaler),
        child: ZoomBox(scale: 1 / scale, child: child),
      ),
    );
  }
}
