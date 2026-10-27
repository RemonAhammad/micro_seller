import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A tap outside the focused text field closes the keyboard, on every
/// screen, dialog and sheet below it (the app frame puts it around the
/// router).
///
/// Flutter leaves the keyboard open on a touch outside the field on Android
/// and iOS, and iOS's number pads have no key that closes them. This
/// overrides the two intents a focused EditableText invokes for a pointer
/// outside it ([EditableTextTapOutsideIntent] on the way down,
/// [EditableTextTapUpOutsideIntent] on the way up; EditableText looks the
/// action up from its own context, so this ancestor's wins):
///
/// * A touch unfocuses when it lifts within the touch slop of where it went
///   down: a tap, or a finger that wobbled. A drag or a scroll keeps the
///   keyboard open.
/// * A mouse, a stylus or an unknown pointer unfocuses as it goes down, and
///   so does anything on desktop: Flutter's own default, which this
///   replaces.
///
/// Inside the field doesn't count: everything in its tap region group
/// (`TextFieldTapRegion`), such as the field's own paste and clear buttons,
/// its selection handles and toolbar, other text fields and the iOS
/// keyboard bar (`keyboard_accessory_bar.dart`). A button elsewhere still
/// fires: the field unfocuses first, then the button's tap lands.
class TapOutsideUnfocus extends StatefulWidget {
  const TapOutsideUnfocus({super.key, required this.child});

  final Widget child;

  @override
  State<TapOutsideUnfocus> createState() => _TapOutsideUnfocusState();
}

class _TapOutsideUnfocusState extends State<TapOutsideUnfocus> {
  late final Map<Type, Action<Intent>> _actions = {
    EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
      onInvoke: _onTapOutside,
    ),
    EditableTextTapUpOutsideIntent:
        CallbackAction<EditableTextTapUpOutsideIntent>(
          onInvoke: _onTapUpOutside,
        ),
  };

  /// The window's gesture settings (this sits outside the zoom, so the touch
  /// slop is in the same window dp as pointer positions).
  DeviceGestureSettings? _gestureSettings;

  /// A touch that went down outside the focused field and hasn't lifted.
  PointerDownEvent? _down;

  Object? _onTapOutside(EditableTextTapOutsideIntent intent) {
    final event = intent.pointerDownEvent;
    final mobile = switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => false,
    };
    if (mobile && event.kind == PointerDeviceKind.touch) {
      // A tap or a scroll: decided when the finger lifts.
      _down = event;
    } else {
      _down = null;
      intent.focusNode.unfocus();
    }
    return null;
  }

  Object? _onTapUpOutside(EditableTextTapUpOutsideIntent intent) {
    final down = _down;
    final up = intent.pointerUpEvent;
    if (down == null || down.pointer != up.pointer) return null;
    _down = null;
    final slop = computeHitSlop(PointerDeviceKind.touch, _gestureSettings);
    if ((up.position - down.position).distance < slop) {
      intent.focusNode.unfocus();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    _gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    return Actions(actions: _actions, child: widget.child);
  }
}
