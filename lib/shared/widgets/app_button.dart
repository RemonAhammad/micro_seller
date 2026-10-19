import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/constants/app_icons.dart';

enum AppButtonVariant { filled, outlined, text, destructive }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final ThinIconBuilder? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double? height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ThinIcon(icon!, size: 18),
                  const SizedBox(width: 8),
                  // A label longer than the button (a long translation, a
                  // large text size) wraps instead of overflowing.
                  Flexible(
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                ],
              )
            : Text(label, textAlign: TextAlign.center);

    Widget button;
    switch (variant) {
      case AppButtonVariant.filled:
        button = FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: height != null
              ? FilledButton.styleFrom(minimumSize: Size.fromHeight(height!))
              : null,
          child: child,
        );
        break;
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: height != null
              ? OutlinedButton.styleFrom(minimumSize: Size.fromHeight(height!))
              : null,
          child: child,
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
        break;
      case AppButtonVariant.destructive:
        button = FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize:
                height != null ? Size.fromHeight(height!) : null,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(label, textAlign: TextAlign.center),
        );
        break;
    }

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Two buttons side by side at equal widths, [gap] apart, as a `Row` of two
/// `Expanded` buttons lays them out. When a label's longest word wouldn't fit
/// in its half (a long translation, a large text size, a narrow layout), the
/// two are stacked full width instead, [first] on top, so no word is ever
/// broken across lines.
class ButtonPair extends MultiChildRenderObjectWidget {
  ButtonPair({
    super.key,
    required Widget first,
    required Widget second,
    this.gap = 12,
    this.stackedGap = 8,
  }) : super(children: [first, second]);

  /// Space between the buttons side by side.
  final double gap;

  /// Space between the buttons when stacked.
  final double stackedGap;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderButtonPair(
        gap: gap,
        stackedGap: stackedGap,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderButtonPair)
      ..gap = gap
      ..stackedGap = stackedGap
      ..textDirection = Directionality.of(context);
  }
}

class _ButtonPairParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderButtonPair extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ButtonPairParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ButtonPairParentData> {
  _RenderButtonPair({
    required double gap,
    required double stackedGap,
    required TextDirection textDirection,
  })  : _gap = gap,
        _stackedGap = stackedGap,
        _textDirection = textDirection;

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double get stackedGap => _stackedGap;
  double _stackedGap;
  set stackedGap(double value) {
    if (value == _stackedGap) return;
    _stackedGap = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ButtonPairParentData) {
      child.parentData = _ButtonPairParentData();
    }
  }

  List<RenderBox> get _children => [
        for (var child = firstChild; child != null; child = childAfter(child))
          child,
      ];

  double get _gaps => gap * math.max(0, childCount - 1);

  /// Each child's share of [width] side by side.
  double _share(double width) => (width - _gaps) / math.max(1, childCount);

  /// Whether every child fits its share of [width] without breaking a word.
  /// A button's minimum intrinsic width is its padding plus the widest word
  /// of its label.
  bool _sideBySide(double width) =>
      !width.isFinite ||
      _children.every((child) =>
          child.getMinIntrinsicWidth(double.infinity) <= _share(width));

  @override
  double computeMinIntrinsicWidth(double height) => _children.fold(
      0, (w, child) => math.max(w, child.getMinIntrinsicWidth(height)));

  @override
  double computeMaxIntrinsicWidth(double height) {
    // What the Row of Expanded children reported: as wide as the widest
    // child, times the number of children, plus the gaps. Dialogs size
    // themselves from this.
    final widest = _children.fold(
        0.0, (w, child) => math.max(w, child.getMaxIntrinsicWidth(height)));
    return widest * childCount + _gaps;
  }

  double _intrinsicHeight(
      double width, double Function(RenderBox child, double width) height) {
    if (_sideBySide(width)) {
      final share = width.isFinite ? _share(width) : double.infinity;
      return _children.fold(
          0, (h, child) => math.max(h, height(child, share)));
    }
    return _children.fold(0.0, (h, child) => h + height(child, width)) +
        stackedGap * math.max(0, childCount - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(
      width, (child, width) => child.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(
      width, (child, width) => child.getMaxIntrinsicHeight(width));

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double? computeDryBaseline(
      covariant BoxConstraints constraints, TextBaseline baseline) {
    final arranged = _arrange(constraints, ChildLayoutHelper.dryLayoutChild);
    double? highest;
    var i = 0;
    for (final child in _children) {
      final distance =
          child.getDryBaseline(arranged.childConstraints, baseline);
      if (distance != null) {
        final fromTop = distance + arranged.offsets[i].dy;
        highest = highest == null ? fromTop : math.min(highest, fromTop);
      }
      i++;
    }
    return highest;
  }

  @override
  void performLayout() {
    final arranged = _arrange(constraints, ChildLayoutHelper.layoutChild);
    size = arranged.size;
    var i = 0;
    for (final child in _children) {
      (child.parentData! as _ButtonPairParentData).offset =
          arranged.offsets[i++];
    }
  }

  /// Sizes the children with [layoutChild]: the pair's size, the constraints
  /// each child gets and where each one goes.
  ({Size size, BoxConstraints childConstraints, List<Offset> offsets})
      _arrange(BoxConstraints constraints, ChildLayouter layoutChild) {
    final children = _children;
    final width = constraints.maxWidth;
    if (children.isEmpty) {
      return (
        size: constraints.smallest,
        childConstraints: constraints,
        offsets: const [],
      );
    }

    if (_sideBySide(width)) {
      // As a Row of Expanded children, centered across.
      final childConstraints = width.isFinite
          ? BoxConstraints.tightFor(width: _share(width))
              .copyWith(maxHeight: constraints.maxHeight)
          : BoxConstraints(maxHeight: constraints.maxHeight);
      final sizes = [
        for (final child in children) layoutChild(child, childConstraints),
      ];
      final size = constraints.constrain(Size(
        width.isFinite
            ? width
            : sizes.fold(_gaps, (w, childSize) => w + childSize.width),
        sizes.fold(0, (h, childSize) => math.max(h, childSize.height)),
      ));
      final offsets = <Offset>[];
      var x = 0.0;
      for (final childSize in sizes) {
        final left = textDirection == TextDirection.ltr
            ? x
            : size.width - x - childSize.width;
        offsets.add(Offset(left, (size.height - childSize.height) / 2));
        x += childSize.width + gap;
      }
      return (
        size: size,
        childConstraints: childConstraints,
        offsets: offsets,
      );
    }

    // Stacked, each as wide as the pair.
    final childConstraints = BoxConstraints.tightFor(width: width);
    final offsets = <Offset>[];
    var y = 0.0;
    for (final child in children) {
      if (offsets.isNotEmpty) y += stackedGap;
      offsets.add(Offset(0, y));
      y += layoutChild(child, childConstraints).height;
    }
    return (
      size: constraints.constrain(Size(width, y)),
      childConstraints: childConstraints,
      offsets: offsets,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
