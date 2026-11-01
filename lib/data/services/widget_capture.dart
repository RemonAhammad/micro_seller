import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_fonts.dart';

Future<Uint8List> captureWidgetPng(
  Widget widget, {
  required Size targetSize,
  double pixelRatio = 1.0,
  Duration delay = const Duration(seconds: 1),
}) async {
  final image = await _captureWidget(
    widget,
    targetSize: targetSize,
    pixelRatio: pixelRatio,
    delay: delay,
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG encoding of the capture failed');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

Future<ui.Image> _captureWidget(
  Widget widget, {
  required Size targetSize,
  required double pixelRatio,
  required Duration delay,
}) async {
  assert(targetSize.isFinite, 'targetSize must be finite');
  var isDirty = false;

  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final repaintBoundary = RenderRepaintBoundary();
  final positionedBox =
      RenderPositionedBox(alignment: Alignment.center, child: repaintBoundary);
  final renderView = RenderView(
    view: view,
    child: positionedBox,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints(
        maxWidth: targetSize.width,
        maxHeight: targetSize.height,
      ),
      devicePixelRatio: pixelRatio,
    ),
  );
  final pipelineOwner = PipelineOwner();
  final focusManager = FocusManager();
  final buildOwner = BuildOwner(
    focusManager: focusManager,

    onBuildScheduled: () => isDirty = true,
  );
  pipelineOwner.rootNode = renderView;
  renderView.prepareInitialFrame();

  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: repaintBoundary,
    child: captureScope(widget),
  ).attachToRenderTree(buildOwner);

  void flushFrame() {
    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();
  }

  ui.Image? image;
  try {
    flushFrame();
    var retries = 3;
    do {
      isDirty = false;
      final previous = image;
      image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
      previous?.dispose();
      await Future<void>.delayed(delay);
      if (isDirty) flushFrame();
      retries--;
    } while (isDirty && retries >= 0);
    return image;
  } catch (_) {
    image?.dispose();
    rethrow;
  } finally {

    try {
      RenderObjectToWidgetAdapter<RenderBox>(container: repaintBoundary)
          .attachToRenderTree(buildOwner, rootElement);
      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();
      pipelineOwner.rootNode = null;

      repaintBoundary.dispose();
      positionedBox.dispose();
      renderView.dispose();
      pipelineOwner.dispose();
      focusManager.dispose();
    } catch (e, st) {

      assert(() {
        debugPrint('captureWidgetPng cleanup failed: $e\n$st');
        return true;
      }());
    }
  }
}

@visibleForTesting
Widget captureScope(Widget widget) => Directionality(
  textDirection: TextDirection.ltr,
  child: Theme(
    data: captureTheme(),
    child: DefaultTextStyle.merge(
      style: TextStyle(fontFamily: appFontFamily),
      child: widget,
    ),
  ),
);

(TargetPlatform, ThemeData)? _captureTheme;

@visibleForTesting
ThemeData captureTheme() {
  final platform = defaultTargetPlatform;
  final cached = _captureTheme;
  if (cached != null && cached.$1 == platform) return cached.$2;
  final fallback = ThemeData.fallback();
  final font = appFontFamily;
  final theme = fallback.copyWith(
    textTheme: fallback.textTheme.apply(fontFamily: font),
    primaryTextTheme: fallback.primaryTextTheme.apply(fontFamily: font),
    iconTheme: const IconThemeData.fallback(),
  );
  _captureTheme = (platform, theme);
  return theme;
}

Future<ui.Image> decodeImageForBox(
  ui.ImmutableBuffer buffer, {
  required int width,
  required int height,
  required BoxFit fit,
}) async {
  assert(fit == BoxFit.cover || fit == BoxFit.contain);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      if (w <= 0 || h <= 0) return const ui.TargetImageSize();
      final sx = width / w;
      final sy = height / h;
      final s = fit == BoxFit.cover ? math.max(sx, sy) : math.min(sx, sy);
      if (s >= 1) return const ui.TargetImageSize();

      int scaled(int v) =>
          math.max(1, fit == BoxFit.cover ? (v * s).ceil() : (v * s).round());
      return ui.TargetImageSize(width: scaled(w), height: scaled(h));
    },
  );
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}
