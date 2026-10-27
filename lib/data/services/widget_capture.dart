import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_fonts.dart';

/// Renders [widget] off-screen and returns it as PNG bytes.
///
/// A trimmed copy of `screenshot` 3.0.0's `captureFromWidget` /
/// `widgetToUiImage`, with the same semantics: the widget is laid out inside
/// [targetSize] (logical px — it must be finite, `infinity * pixelRatio` is not
/// an image), painted at [pixelRatio], and captured; then [delay] is waited
/// out, and if anything in the tree asked to rebuild meanwhile (an image or
/// SVG finishing its async load) the tree is rebuilt and captured again, up to
/// four captures. Like screenshot, a `Directionality` is provided above
/// [widget], and so is the app's font ([captureScope]); MediaQuery /
/// Material / DefaultTextStyle are the caller's job.
///
/// What screenshot leaves commented out is done here: once captured, the
/// off-screen tree is unmounted and its render objects, layers and focus
/// manager disposed. Screenshot never unmounts it, so every captured page —
/// its State objects, the image-stream listeners they register in the global
/// ImageCache, and the decoded images those hold — stayed reachable for the
/// rest of the session.
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
    // Something in the tree changed after the first build (async image /
    // SVG load): capture again after this round.
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
    // Unmount: swap in an empty root and finalize, which deactivates and
    // unmounts every element (State.dispose, image-stream listeners removed,
    // RawImage clones released, render objects disposed).
    try {
      RenderObjectToWidgetAdapter<RenderBox>(container: repaintBoundary)
          .attachToRenderTree(buildOwner, rootElement);
      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();
      pipelineOwner.rootNode = null;
      // Releases the layer trees (and the pictures in them) now rather than
      // whenever the GC gets to them.
      repaintBoundary.dispose();
      positionedBox.dispose();
      renderView.dispose();
      pipelineOwner.dispose();
      focusManager.dispose();
    } catch (e, st) {
      // Cleanup must never turn a good capture into a failure.
      assert(() {
        debugPrint('captureWidgetPng cleanup failed: $e\n$st');
        return true;
      }());
    }
  }
}

/// What a capture puts above the captured [widget]: a left-to-right
/// Directionality, as screenshot does, and the app's font ([appFontFamily],
/// the bundled Roboto on iOS), so PDFs draw in the app's font everywhere.
///
/// The font goes in through a Theme ([captureTheme]): a page sets its own
/// DefaultTextStyle and draws on a Material, which sets its text to the
/// theme's bodyMedium, and with no Theme above that is Flutter's fallback
/// theme, whose text is San Francisco on iOS. The DefaultTextStyle.merge
/// covers text outside a Material.
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

/// [captureTheme]'s last theme, and the platform it was built for.
(TargetPlatform, ThemeData)? _captureTheme;

/// The theme a capture draws in: Flutter's fallback theme, what a tree with
/// no Theme gets (so colors and sizes stay as they were), with the app's
/// font in its text themes. Its icon theme is the fallback one a tree with
/// no IconTheme gets, so an icon's default color stays too. Built once per
/// platform (the font and the fallback's typography depend on it).
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

/// Decodes encoded image bytes at the size they will be drawn, rather than at
/// full resolution: scaled down (never up), aspect ratio kept, so the result
/// covers ([BoxFit.cover]) or fits inside ([BoxFit.contain]) a [width] ×
/// [height] box in *physical* pixels (logical size × capture pixelRatio).
///
/// The result is drawn with `RawImage`, which paints synchronously — unlike
/// `Image.memory` / `Image.asset`, whose async decode forces a capture to be
/// retaken. The caller owns the returned image and must dispose it.
///
/// [buffer] is consumed (disposed) by this call.
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
      // Cover rounds up so the short side still fills the box.
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
