import 'package:flutter/widgets.dart';

/// Where [context]'s widget is drawn, in logical window coordinates, for a
/// share sheet to point at: an iPad's (and a Mac's) share sheet is a popover
/// anchored to a rect, which share_plus takes as `sharePositionOrigin`.
/// Without one it opens from the middle of the screen, pointing at nothing.
///
/// The rect is where the control is on screen, the Display size zoom
/// (`AppZoom`) included. Pass the context of the control that was tapped (a [Builder]
/// around it, or a [GlobalKey]'s `currentContext`). Null when that widget
/// isn't laid out: unmounted, not yet sized, or not a box.
Rect? shareOriginOf(BuildContext? context) {
  if (context == null || !context.mounted) return null;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}
