import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../core/constants/app_icons.dart';

/// What an editable field takes from its width besides its value, the paste
/// button included: the theme's 16 dp content padding and a 4 dp gap at the
/// start, the 48 dp paste button and a 4 dp gap at the end.
const _kChromeWithPaste = 72.0;

/// A prefix icon's 48 dp box takes the place of the 16 dp start padding.
const _kPrefixIconChrome = 32.0;

/// A suffix icon's 48 dp box sits beside the paste button.
const _kSuffixIconChrome = 48.0;

/// The room a field keeps for its value beside the paste button: about three
/// letters, 3 em of the field's 16 px text, at the current text size.
const _kMinValueRoom = 48.0;

/// A form field with the app's decoration. An editable field with a
/// [controller] has a paste button at its end, unless the field is too narrow
/// to keep [_kMinValueRoom] for its value beside it (two fields side by side
/// on a narrow layout, a large text size): the button is then left out, so
/// the value and the label keep the room. The field's context menu still
/// pastes.
///
/// An editable field decides on its paste button in a [LayoutBuilder], which
/// can't report an intrinsic size: use a plain [TextField] where a parent
/// sizes itself to its content (an [AlertDialog]'s content, [IntrinsicHeight]).
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final String? helperText;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.helperText,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    if (readOnly || controller == null) return _buildField(suffixIcon);
    return LayoutBuilder(
      builder: (context, constraints) => _buildField(
        _pasteFits(context, constraints.maxWidth) ? _withPaste() : suffixIcon,
      ),
    );
  }

  Widget _buildField(Widget? effectiveSuffix) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefix: prefix,
        suffix: suffix,
        prefixIcon: prefixIcon,
        suffixIcon: effectiveSuffix,
        helperText: helperText,
        // Helper and error texts wrap instead of being cut off at one line
        // (a long message, a large text size, a narrow layout).
        helperMaxLines: 3,
        errorMaxLines: 3,
        counterText: '',
      ),
    );
  }

  /// Whether a field [width] wide keeps [_kMinValueRoom], at the current text
  /// size, for its value beside the paste button and its icons.
  bool _pasteFits(BuildContext context, double width) {
    final chrome = _kChromeWithPaste +
        (prefixIcon == null ? 0 : _kPrefixIconChrome) +
        (suffixIcon == null ? 0 : _kSuffixIconChrome);
    return width - chrome >=
        MediaQuery.textScalerOf(context).scale(_kMinValueRoom);
  }

  Widget _withPaste() {
    final pasteBtn = _PasteButton(controller: controller!);
    if (suffixIcon == null) return pasteBtn;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [pasteBtn, suffixIcon!],
    );
  }
}

class _PasteButton extends StatelessWidget {
  final TextEditingController controller;
  const _PasteButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const ThinIcon(tabler.Clipboard.new, size: 18),
      tooltip: MaterialLocalizations.of(context).pasteButtonLabel,
      onPressed: () async {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null) {
          controller.text = data!.text!;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }
      },
    );
  }
}
