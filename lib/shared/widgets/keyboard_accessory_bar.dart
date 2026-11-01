import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';

bool hasNoReturnKey(TextInputType type) =>
    (type.index == TextInputType.number.index && type.signed != true) ||
    type.index == TextInputType.phone.index;

double keyboardAccessoryBarHeight(TextScaler textScaler) =>
    math.max(44, textScaler.scale(16) * 1.4 + 12);

class KeyboardAccessoryHost extends StatefulWidget {
  const KeyboardAccessoryHost({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardAccessoryHost> createState() => _KeyboardAccessoryHostState();
}

class _KeyboardAccessoryHostState extends State<KeyboardAccessoryHost> {
  late final bool _enabled =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  EditableTextState? _field;

  bool _closing = false;

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

class _AccessoryBar extends StatelessWidget {
  const _AccessoryBar({
    required this.showNext,
    required this.onNext,
    required this.onDone,
  });

  final bool showNext;

  final VoidCallback? onNext;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

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
