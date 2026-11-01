import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

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

  DeviceGestureSettings? _gestureSettings;

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
