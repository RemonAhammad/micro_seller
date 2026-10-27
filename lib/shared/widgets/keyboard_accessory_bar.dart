import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';

/// Whether [type]'s iOS keyboard has no return key: the number and decimal
/// pads and the phone pad. A signed number keyboard is iOS's numbers and
/// punctuation keyboard, which has one.
bool hasNoReturnKey(TextInputType type) =>
    (type.index == TextInputType.number.index && type.signed != true) ||
    type.index == TextInputType.phone.index;

/// The keyboard bar's height in [textScaler]'s text: 44 dp, the height of
/// iOS's own keyboard bars and its smallest tap target, taller for a large
/// font.
double keyboardAccessoryBarHeight(TextScaler textScaler) =>
    math.max(44, textScaler.scale(16) * 1.4 + 12);

/// iOS's number, decimal and phone pads have no return key, so nothing on
/// them closes the keyboard or moves to the next field. While one of them is
/// up, this shows a bar on top of it with **Done** (closes the keyboard) and,
/// when the field's action is [TextInputAction.next], **Next** (what the
/// return key would do).
///
/// It sits in the app frame inside the zoom, around the router, so the bar
/// is drawn above every screen, dialog and sheet at the Display size. Its
/// height is added to the keyboard inset below it, so Scaffolds shrink above
/// it, the focused field scrolls clear of it, and dialogs and sheets lift
/// over it. It is part of the text fields' tap region group
/// (`TextFieldTapRegion`), so tapping it never counts as a tap outside the
/// field (`tap_outside_unfocus.dart`), and takes no focus.
///
/// Not on other platforms (decided once, when mounted): there it returns
/// [child] as it is and listens to nothing. Not on the web either, where
/// Safari shows its own bar. The widget tree is the same whether the bar
/// shows or not, so it never remounts the router.
class KeyboardAccessoryHost extends StatefulWidget {
  const KeyboardAccessoryHost({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardAccessoryHost> createState() => _KeyboardAccessoryHostState();
}

class _KeyboardAccessoryHostState extends State<KeyboardAccessoryHost> {
  late final bool _enabled =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// The focused text field; null when the focus is anywhere else.
  EditableTextState? _field;

  /// The bar was up when the focus left its field: it stays, its buttons
  /// off, and slides down with the closing keyboard.
  bool _closing = false;

  /// Whether the bar shows Next, as it did for its field while the keyboard
  /// closes.
  bool _next = false;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    FocusManager.instance.addListener(_focusChanged);
    _field = _focusedField();
  }

  @override
  void dispose() {
    if (_enabled) FocusManager.instance.removeListener(_focusChanged);
    super.dispose();
  }

  /// The text field that has the primary focus, if one does.
  EditableTextState? _focusedField() {
    final node = FocusManager.instance.primaryFocus;
    final context = node?.context;
    if (context == null || !context.mounted) return null;
    final field = context.findAncestorStateOfType<EditableTextState>();
    return field != null && field.widget.focusNode == node ? field : null;
  }

  static bool _wantsBar(EditableTextState? field) =>
      field != null &&
      field.mounted &&
      !field.widget.readOnly &&
      hasNoReturnKey(field.widget.keyboardType);

  void _focusChanged() {
    final field = _focusedField();
    if (field == _field) return;
    setState(() {
      // Focus that leaves for no text field closes the keyboard; focus that
      // moves to another field shows that field's bar, or none.
      _closing = field == null && (_closing || _wantsBar(_field));
      _field = field;
    });
  }

  void _performNext(EditableTextState field) {
    if (field.mounted) field.performAction(TextInputAction.next);
  }

  void _done(EditableTextState field) {
    if (field.mounted) field.widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final field = _field;
    final active = _wantsBar(field);
    if (active) {
      _next = field!.widget.textInputAction == TextInputAction.next;
    }
    if (keyboard <= 0) _closing = false;
    final show = keyboard > 0 && (active || _closing);
    final height = keyboardAccessoryBarHeight(media.textScaler);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        MediaQuery(
          data: show
              ? media.copyWith(
                  viewInsets: media.viewInsets.copyWith(
                    bottom: keyboard + height,
                  ),
                )
              : media,
          child: widget.child,
        ),
        if (show)
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard,
            height: height,
            child: TextFieldTapRegion(
              child: ExcludeFocus(
                child: _AccessoryBar(
                  showNext: _next,
                  onNext: active ? () => _performNext(field!) : null,
                  onDone: active ? () => _done(field!) : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The bar itself: Next at the start (when the field has a next action),
/// Done at the end. A label that wouldn't fit shrinks rather than wrap. No
/// tooltips: nothing above the router has an Overlay.
class _AccessoryBar extends StatelessWidget {
  const _AccessoryBar({
    required this.showNext,
    required this.onNext,
    required this.onDone,
  });

  final bool showNext;

  /// Null disables the button (the keyboard is closing).
  final VoidCallback? onNext;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    // The theme's text button colors (the color scheme's primary, readable
    // on the bar in both modes); the size iOS gives its own bar's buttons.
    final style = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(48, 0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    Widget button(
      String label,
      VoidCallback? onPressed, {
      FontWeight? weight,
    }) => Flexible(
      child: TextButton(
        style: style,
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(fontSize: 16, fontWeight: weight),
          ),
        ),
      ),
    );
    // Opaque: a tap on the bar's background stays on the bar.
    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        shape: Border(top: BorderSide(color: theme.dividerColor)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: showNext
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showNext) button(s.next, onNext),
              button(s.done, onDone, weight: FontWeight.w600),
            ],
          ),
        ),
      ),
    );
  }
}
