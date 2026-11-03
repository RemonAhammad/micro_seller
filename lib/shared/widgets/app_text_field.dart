import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../core/constants/app_icons.dart';
import '../../core/utils/number_input.dart';

final _asciiDigit = RegExp('[0-9]');

const _kChromeWithPaste = 72.0;

const _kPrefixIconChrome = 32.0;

const _kSuffixIconChrome = 48.0;

const _kMinValueRoom = 48.0;

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
  final bool isRequired;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.isRequired = false,
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
        labelText: isRequired ? null : label,
        label: isRequired
            ? Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                  ],
                ),
              )
            : null,
        hintText: hint,
        prefix: prefix,
        suffix: suffix,
        prefixIcon: prefixIcon,
        suffixIcon: effectiveSuffix,
        helperText: helperText,

        helperMaxLines: 3,
        errorMaxLines: 3,
        counterText: '',
      ),
    );
  }

  bool _pasteFits(BuildContext context, double width) {
    final chrome = _kChromeWithPaste +
        (prefixIcon == null ? 0 : _kPrefixIconChrome) +
        (suffixIcon == null ? 0 : _kSuffixIconChrome);
    return width - chrome >=
        MediaQuery.textScalerOf(context).scale(_kMinValueRoom);
  }

  Widget _withPaste() {
    final pasteBtn = _PasteButton(
      controller: controller!,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      onChanged: onChanged,
    );
    if (suffixIcon == null) return pasteBtn;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [pasteBtn, suffixIcon!],
    );
  }
}

class _PasteButton extends StatelessWidget {
  final TextEditingController controller;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  const _PasteButton({
    required this.controller,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
  });

  bool get _takesDigits =>
      inputFormatters?.any(
        (f) =>
            f is DecimalInputFormatter ||
            f is IntegerInputFormatter ||
            f is PhoneInputFormatter,
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const ThinIcon(tabler.Clipboard.new, size: 18),
      tooltip: MaterialLocalizations.of(context).pasteButtonLabel,
      onPressed: () async {
        final pasted = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        if (pasted == null || !context.mounted) return;

        if (_takesDigits &&
            !NumberInput.toAsciiDigits(pasted).contains(_asciiDigit)) {
          return;
        }
        final current = controller.value;

        final old = current.copyWith(
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: current.text.length,
          ),
          composing: TextRange.empty,
        );
        var value = TextEditingValue(
          text: pasted,
          selection: TextSelection.collapsed(offset: pasted.length),
        );
        for (final formatter in [
          ...?inputFormatters,
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        ]) {
          value = formatter.formatEditUpdate(old, value);
        }

        if (value.text == current.text ||
            (value.text.trim().isEmpty && pasted.trim().isNotEmpty)) {
          return;
        }
        controller.value = value;
        onChanged?.call(value.text);
      },
    );
  }
}
