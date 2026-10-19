/// Settings → Display size (whole-app zoom) and Text size. Both are
/// per-device; the saved values live in `displayScaleProvider`.
///
/// Known limitation: text selection menus. Flutter places them by adding a
/// text field's on-screen position (`localToGlobal`, which includes the
/// zoom) to offsets inside the field (which don't), so at a Display size `s`
/// other than 100% they land off by a share of a distance inside the field.
/// Nothing is off at 100%. Below, `X` is where a field's text starts and `d`
/// how far into it the selection's centre (or a click) is, in on-screen dp.
///
/// * iOS 16+ system edit menu (Cut / Copy / Paste, and the caret's Paste,
///   on every editable field): it points `(1/s - 1) × d` beside the
///   selection, a fifth of `d` to the left at 125% and a quarter of it to
///   the right at 80%: 56 dp at 125% for a word 280 dp into a field. Its
///   target also keeps its unscaled size. Cut, Copy and Paste still act on
///   the selection. Turning `supportsShowingSystemContextMenu` off while
///   zoomed doesn't help: Flutter's own Cupertino toolbar then sits over the
///   word, but its arrow points at the same wrong spot, it drifts at the
///   screen edges as below, and its Paste brings back iOS's "Allow Paste"
///   prompt. So iOS keeps the system menu.
/// * Flutter-drawn toolbars (Android, desktop, iOS read-only fields) sit on
///   the selection, but keep clear of the screen edges in a frame shifted
///   `(1 - s) × X`. At 125%, a field whose text starts 115 dp from the left
///   edge puts its first word's toolbar 19 dp off-screen (`X / 4 - 10`). At
///   80%, a word near the right edge can push it about 8 dp past that edge.
///   Above or below is decided in the same frame, so at 80% a field just
///   under the app bar can get its toolbar below it, over the next field.
///   On iOS the toolbar's arrow points where the system menu would.
/// * A right-click (mouse) menu opens `(s - 1) × d` from the pointer: a
///   quarter of `d` to the right at 125% (78 dp for a click 312 dp into a
///   field), a fifth of it to the left at 80%.
/// * Above 100%, a toolbar that a scroll hid doesn't come back for a
///   selection less than `(1 - 1/s)` of the window's height above the
///   bottom of the visible area (the keyboard, when open), or that share of
///   its width from the right edge: 183 dp and 82 dp at 125% on a
///   411 × 914 dp phone, so a field just above the keyboard loses it. A tap
///   on the selection shows it again. (EditableText measures the screen as
///   the zoomed window size minus the window's own insets.)
///
/// The menus could only be corrected by a `contextMenuBuilder` on every text
/// field (Flutter has no app-wide default), and the scroll check not at all,
/// so these are left to Flutter.
library;

import 'dart:math' as math;
import 'dart:ui' as ui show DisplayFeature;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Smallest Display size, in percent of the coded dp. A custom Text size
/// uses the same range and step.
const int kMinDisplayPercent = 80;

/// Largest Display size (and custom Text size), in percent.
const int kMaxDisplayPercent = 130;

/// Display / Text size step, in percent.
const int kDisplayPercentStep = 5;

/// Zooming in never lays the app out narrower than this many window dp: the
/// narrowest phone the layouts are built for. Zooming out is never limited.
const double kMinZoomedLayoutWidth = 320;

/// [value] rounded to the nearest step and clamped to the offered range. A
/// value that isn't a finite number (a corrupt preference) gives 100.
int snapPercent(num value) {
  if (!value.isFinite) return 100;
  // Clamp first: the bounds are on the step grid, and rounding a huge
  // double to an int would overflow.
  final clamped = value.clamp(kMinDisplayPercent, kMaxDisplayPercent);
  return (clamped / kDisplayPercentStep).round() * kDisplayPercentStep;
}

/// The largest Display size a window [windowWidth] dp wide allows, so that
/// zooming in leaves at least [kMinZoomedLayoutWidth] dp for the layout (110%
/// on a 360 dp phone). Never below 100%, so it never forces a zoom-out. An
/// unknown width (0 before the first real frame) allows 100%.
int maxDisplayPercentFor(double windowWidth) {
  if (!windowWidth.isFinite || windowWidth <= 0) return 100;
  // The epsilon keeps float drift in a width derived from physical pixels
  // (351.99999… for 352) from costing a whole step.
  final steps =
      (100 * windowWidth / kMinZoomedLayoutWidth + 1e-9) ~/ kDisplayPercentStep;
  return (steps * kDisplayPercentStep).clamp(100, kMaxDisplayPercent);
}

/// The Display size actually applied: the saved one, capped by
/// [maxDisplayPercentFor] the current window.
int effectiveDisplayPercent(int requested, double windowWidth) =>
    math.min(snapPercent(requested), maxDisplayPercentFor(windowWidth));

/// The MediaQuery for a subtree drawn at [scale] times its own dp.
///
/// Window lengths (size, insets, display features, corner radii) are divided
/// by [scale], so they still add up to the window in the subtree's dp:
/// SafeArea, the keyboard inset and hinge avoidance stay right.
/// devicePixelRatio is multiplied by it, so images still decode at the
/// screen's physical resolution. gestureSettings are kept: drag slop is
/// compared in window units. supportsShowingSystemContextMenu is kept, so
/// iOS keeps its system edit menu (see the library comment for where it
/// points). [textScaler], when given, replaces the window's (the phone's
/// font size).
MediaQueryData zoomMediaQuery(
  MediaQueryData outer,
  double scale, {
  TextScaler? textScaler,
}) {
  if (scale == 1.0) {
    // At 100% the app sees the window's own data, untouched.
    return textScaler == null || textScaler == outer.textScaler
        ? outer
        : outer.copyWith(textScaler: textScaler);
  }
  // The constructor, not copyWith: copyWith can't set displayCornerRadii.
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

/// Lays its child out at the incoming constraints divided by [scale] and
/// paints it scaled by [scale], so the child covers exactly the box it would
/// have covered unscaled. Hit tests, semantics and localToGlobal go through
/// the same transform. At 1.0 it paints the child directly, with no
/// transform layer.
class ZoomBox extends SingleChildRenderObjectWidget {
  const ZoomBox({super.key, required this.scale, super.child});

  /// Must be finite and greater than zero.
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

/// The render object behind [ZoomBox].
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
    // constrain() absorbs the float drift of (x / s) * s.
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

/// What [AppZoom] applied, for widgets that need the window's own values:
/// the Display size setting (to cap its choices at [maxDisplayPercentFor]
/// the real window) and [ZoomNeutral].
class AppZoomScope extends InheritedWidget {
  const AppZoomScope({
    super.key,
    required this.scale,
    required this.displayPercent,
    required this.outer,
    required super.child,
  });

  /// The scale the subtree is drawn at; 1.0 = coded dp.
  final double scale;

  /// The Display size in effect, after the window-width cap.
  final int displayPercent;

  /// The window's MediaQuery, before zooming.
  ///
  /// A change to only its padding and insets doesn't notify dependents: the
  /// keyboard moves them on every frame of its animation. Read those from
  /// MediaQuery (zoomed).
  final MediaQueryData outer;

  static AppZoomScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppZoomScope>();

  /// 1.0 outside an [AppZoom].
  static double scaleOf(BuildContext context) => maybeOf(context)?.scale ?? 1.0;

  @override
  bool updateShouldNotify(AppZoomScope oldWidget) =>
      scale != oldWidget.scale ||
      displayPercent != oldWidget.displayPercent ||
      !_sameApartFromInsets(outer, oldWidget.outer);

  /// Whether [a] and [b] differ in nothing but padding and insets.
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

/// Applies the Display size ([displayPercent]) and Text size ([textPercent];
/// null follows the phone's font size) to [child].
///
/// It sits in MaterialApp.router's `builder`, around the Router, so every
/// route, dialog, sheet, menu, tooltip and snackbar is zoomed alike (text
/// selection menus land a little off: see the library comment). PDF and
/// catalog captures build their own tree and are never zoomed.
///
/// [child] is laid out at the window size divided by the scale and painted
/// scaled back up, so it always fills the window, and the MediaQuery below is
/// rewritten to match ([zoomMediaQuery]). The widget tree is the same at
/// every size, 100% included: a size change relays out the app but never
/// remounts the Router, the shell or a branch navigator.
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

/// Cancels the app zoom for [child], which then lays out and paints in the
/// window's own dp (the Text size still applies). For Flutter widgets that
/// mix window and local coordinates and so misplace things under a scale,
/// e.g. ReorderableListView's drag proxy.
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
