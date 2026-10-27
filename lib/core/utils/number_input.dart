import 'dart:math' as math;

import 'package:flutter/services.dart';

// Typing and reading amounts and other numbers alike on every phone.
//
// A phone's number pad types its own region's digits and decimal separator:
// on iOS, '١٢٫٥' with an Arabic region and '12,5' with a French, Brazilian or
// Indonesian one; on Android, a Bengali or Arabic keyboard types its own
// digits. double.tryParse reads none of them. The formatters below keep a
// field's text canonical (ASCII digits, '.' as the point, '-' only where the
// field takes a sign) whatever was typed or pasted, and
// NumberInput.parseDecimal / parseInteger read field text back.

/// The zero of every script whose digits are mapped to 0-9. Each of these
/// digits is one UTF-16 unit, like '0'-'9', so mapping one never moves the
/// caret.
const _scriptZeros = <int>[
  0x0660, // Arabic-Indic
  0x06F0, // Extended Arabic-Indic (Persian, Urdu)
  0x0966, // Devanagari
  0x09E6, // Bengali
  0x0A66, // Gurmukhi
  0x0AE6, // Gujarati
  0x0B66, // Oriya
  0x0BE6, // Tamil
  0x0C66, // Telugu
  0x0CE6, // Kannada
  0x0D66, // Malayalam
  0x0E50, // Thai
  0x0ED0, // Lao
  0x1040, // Myanmar
  0x17E0, // Khmer
  0xFF10, // Full-width
];

const _zero = 0x30;
const _point = 0x2E; // .
const _comma = 0x2C; // ,
const _minus = 0x2D; // -
const _unicodeMinus = 0x2212; // −
const _arabicPoint = 0x066B; // ٫
const _arabicGrouping = 0x066C; // ٬

/// Keys a keyboard types for the decimal point: '.', ',', the Arabic '٫',
/// and the full-width '．' and '，'.
const _pointKeys = <int>{_point, _comma, _arabicPoint, 0xFF0E, 0xFF0C};

/// Spaces that group digits: the space, the no-break space, the figure,
/// thin and narrow no-break spaces.
const _groupingSpaces = <int>{0x20, 0xA0, 0x2007, 0x2009, 0x202F};

/// What only ever groups digits inside a pasted number, so it is dropped:
/// the spaces, '٬' and apostrophes (1'250.50).
const _groupingOnly = <int>{..._groupingSpaces, _arabicGrouping, 0x27, 0x2019};

/// What may come before the first digit or after the last one of a pasted
/// number: a currency symbol or code (৳, Rp, د.ك, Tk.), '%', spaces,
/// parentheses and signs, '/-' and '/=' (500/- reads "500 only"). Anything
/// else there (12# or #12) isn't an amount.
final _numberEnds = RegExp(
  r"^[\p{L}\p{M}\p{Sc}\s()%‰+.,٫٬'’/=−-]*$",
  unicode: true,
);

/// Ends with a letter: a '.' after one ends a currency code (Rs.500, Tk.50)
/// rather than starting a fraction.
final _endsWithLetter = RegExp(r'[\p{L}\p{M}]$', unicode: true);

final _decimalText = RegExp(r'^-?(\d+\.?\d*|\.\d+)$');
final _integerText = RegExp(r'^-?\d+(\.0*)?$');
final _nonZeroDigit = RegExp('[1-9]');

bool _isAsciiDigit(int unit) => unit >= _zero && unit <= _zero + 9;

/// Typing, pasting and reading numbers in any script. See also the
/// formatters: [DecimalInputFormatter], [IntegerInputFormatter] and
/// [PhoneInputFormatter].
abstract final class NumberInput {
  /// The decimals a money field takes: 2, or 3 while the shop's currency is
  /// the Kuwaiti Dinar (1 dinar is 1000 fils), the one currency the picker
  /// offers with 3. `CurrencyFormatter.setSymbol` keeps it current, so it
  /// follows the currency set at startup and every change in Settings.
  static int moneyDecimals = 2;

  /// [text] with every digit of the scripts in [_scriptZeros] (Arabic-Indic,
  /// Persian, Bengali, Devanagari, Thai, full-width, …) as 0-9. Everything
  /// else, and the length, stays as it was.
  static String toAsciiDigits(String text) {
    List<int>? units;
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (unit < _scriptZeros.first) continue;
      final digit = _digitOf(unit);
      if (digit >= 0) (units ??= text.codeUnits.toList())[i] = _zero + digit;
    }
    return units == null ? text : String.fromCharCodes(units);
  }

  /// The value 0-9 of [unit] when it is a digit of any script in
  /// [_scriptZeros] or ASCII, else -1.
  static int _digitOf(int unit) {
    if (_isAsciiDigit(unit)) return unit - _zero;
    for (final zero in _scriptZeros) {
      if (unit >= zero && unit <= zero + 9) return unit - zero;
    }
    return -1;
  }

  /// A pasted number ([raw]) as a field's canonical text, or null when it
  /// isn't one ("abc", "12 apples 3").
  ///
  /// Any script's digits count; '٫' is always the decimal point; '٬',
  /// spaces and apostrophes group digits. A currency symbol or code, '%' and
  /// parentheses at either end are dropped. The number is negative when a
  /// '-' comes before its first digit or it is in parentheses, which only a
  /// [signed] field keeps.
  ///
  /// Which of '.' and ',' is the point: when both appear, the last one (it
  /// must appear once); a kind that appears more than once groups digits; a
  /// kind that appears once is the point. With [grouping] (money and whole
  /// numbers), a single one with exactly 3 digits after it and 1 to 3 digits
  /// before it, not starting with 0, groups thousands instead (1,250 and
  /// 25.000), unless the field takes 3 decimals, where it is the point.
  ///
  /// An [integer] field drops a fraction of zeros and refuses any other.
  /// More decimals than [maxDecimals] round half up (0.125 → 0.13).
  static String? normalize(
    String raw, {
    bool signed = false,
    int? maxDecimals,
    bool grouping = false,
    bool integer = false,
  }) {
    final text = toAsciiDigits(raw).replaceAll('．', '.').replaceAll('，', ',');
    var first = -1;
    var last = -1;
    for (var i = 0; i < text.length; i++) {
      if (!_isAsciiDigit(text.codeUnitAt(i))) continue;
      if (first < 0) first = i;
      last = i;
    }
    if (first < 0) return null;
    final prefix = text.substring(0, first);
    final suffix = text.substring(last + 1);
    if (!_numberEnds.hasMatch(prefix) || !_numberEnds.hasMatch(suffix)) {
      return null;
    }
    final negative =
        prefix.contains('-') ||
        prefix.contains('−') ||
        (prefix.contains('(') && suffix.contains(')'));
    // A point right before the first digit starts the fraction (.5, -.5,
    // $.50), unless it ends a currency code (Rs.500).
    final leadingPoint =
        prefix.isNotEmpty &&
        _pointKeys.contains(prefix.codeUnitAt(prefix.length - 1)) &&
        !_endsWithLetter.hasMatch(prefix.substring(0, prefix.length - 1));

    // The digits and the separators that may be the point.
    final buffer = StringBuffer();
    for (final unit in text.substring(first, last + 1).codeUnits) {
      if (_isAsciiDigit(unit) ||
          unit == _point ||
          unit == _comma ||
          unit == _arabicPoint) {
        buffer.writeCharCode(unit);
      } else if (!_groupingOnly.contains(unit)) {
        return null; // a letter, a sign or a slash between digits
      }
    }
    final body = buffer.toString();
    int count(String separator) => separator.allMatches(body).length;

    // Where the decimal point is in [body]; null when it has none.
    int? point;
    if (body.contains('٫')) {
      point = body.indexOf('٫');
      if (count('٫') > 1 ||
          body.contains('.', point) ||
          body.contains(',', point)) {
        return null;
      }
    } else {
      final dots = count('.');
      final commas = count(',');
      if (dots > 0 && commas > 0) {
        point = math.max(body.lastIndexOf('.'), body.lastIndexOf(','));
        if (count(body[point]) > 1) return null;
      } else if (dots + commas == 1) {
        point = body.indexOf(dots == 1 ? '.' : ',');
        // Only digits come before it: [point] is the length of the whole
        // part.
        final thousands =
            grouping &&
            (integer || (maxDecimals != null && maxDecimals < 3)) &&
            body.length - point - 1 == 3 &&
            point <= 3 &&
            body.codeUnitAt(0) != _zero;
        if (thousands) point = null;
      }
    }
    if (leadingPoint && (point != null || count('.') + count(',') > 0)) {
      return null; // two points
    }

    String digitsOf(String s) => s.replaceAll(RegExp('[.,٫]'), '');
    var whole = digitsOf(point == null ? body : body.substring(0, point));
    var fraction = point == null ? '' : digitsOf(body.substring(point + 1));
    if (leadingPoint) {
      fraction = whole;
      whole = '';
    }
    final sign = negative && signed ? '-' : '';

    if (integer) {
      if (whole.isEmpty || fraction.contains(_nonZeroDigit)) return null;
      return '$sign$whole';
    }
    if (maxDecimals != null && fraction.length > maxDecimals) {
      // Half up, on the digits themselves: no binary rounding error.
      var digits = whole + fraction.substring(0, maxDecimals);
      if (fraction.codeUnitAt(maxDecimals) >= _zero + 5) {
        digits = _plusOne(digits);
      }
      whole = digits.substring(0, digits.length - maxDecimals);
      fraction = digits.substring(digits.length - maxDecimals);
      if (whole.isEmpty && fraction.isEmpty) whole = '0';
    }
    return fraction.isEmpty ? '$sign$whole' : '$sign$whole.$fraction';
  }

  /// [digits] plus one in its last place ('199' → '200', '99' → '100').
  static String _plusOne(String digits) {
    final units = digits.codeUnits.toList();
    var i = units.length - 1;
    while (i >= 0 && units[i] == _zero + 9) {
      units[i] = _zero;
      i--;
    }
    if (i < 0) return '1${String.fromCharCodes(units)}';
    units[i]++;
    return String.fromCharCodes(units);
  }

  /// The amount in a field's [text]: any script's digits, ',' or '٫' as the
  /// point, spaces and '٬' ignored. Null for empty text, '.', '-', and
  /// anything else that isn't a finite number.
  static double? parseDecimal(String? text) {
    final readable = _readable(text);
    if (readable == null || !_decimalText.hasMatch(readable)) return null;
    final value = double.tryParse(readable);
    return value != null && value.isFinite ? value : null;
  }

  /// The whole number in a field's [text], read as [parseDecimal] reads it;
  /// a fraction of zeros ('12.0') is allowed. Null for anything else.
  static int? parseInteger(String? text) {
    final readable = _readable(text);
    if (readable == null || !_integerText.hasMatch(readable)) return null;
    final point = readable.indexOf('.');
    return int.tryParse(point < 0 ? readable : readable.substring(0, point));
  }

  /// [text] as the parsers read it: ASCII digits, '.' for ',' and '٫', no
  /// spaces or '٬'.
  static String? _readable(String? text) {
    if (text == null) return null;
    final out = StringBuffer();
    for (final unit in toAsciiDigits(text.trim()).codeUnits) {
      if (unit == _comma || unit == _arabicPoint) {
        out.writeCharCode(_point);
      } else if (unit != _arabicGrouping && !_groupingSpaces.contains(unit)) {
        out.writeCharCode(unit);
      }
    }
    return out.toString();
  }

  /// Whether [text] is a field's canonical text: an optional '-' ([signed]
  /// only), ASCII digits, then for a decimal field an optional '.' with at
  /// most [maxDecimals] digits after it (any number when null). '', '-' and
  /// '.5' are canonical, as deleting leaves them.
  static bool _isCanonical(
    String text, {
    required bool signed,
    required bool integer,
    required int? maxDecimals,
  }) {
    var i = signed && text.startsWith('-') ? 1 : 0;
    while (i < text.length && _isAsciiDigit(text.codeUnitAt(i))) {
      i++;
    }
    if (i == text.length) return true;
    if (integer || text.codeUnitAt(i) != _point) return false;
    final fraction = ++i;
    while (i < text.length && _isAsciiDigit(text.codeUnitAt(i))) {
      i++;
    }
    return i == text.length &&
        (maxDecimals == null || i - fraction <= maxDecimals);
  }
}

/// An amount field's formatter: keeps the text canonical (ASCII digits, '.'
/// as the point, at most [maxDecimals] decimals, '-' first only when
/// [signed]) whatever a keyboard types or the user pastes.
///
/// Typing: any script's digit becomes 0-9; '.', ',', '٫', '．' and '，'
/// become the point, unless the text already has one (a point typed first
/// becomes '0.'); '-' only at the start of a signed field; any other key is
/// ignored, and a key that would leave the text off its form (a third
/// decimal) leaves it, caret included, as it was. Pasting reads the pasted
/// text as [NumberInput.normalize] does. Deleting is never refused.
class DecimalInputFormatter extends TextInputFormatter {
  const DecimalInputFormatter({
    this.signed = false,
    this._maxDecimals,
    this.grouping = false,
  }) : _money = false;

  /// A money field: [NumberInput.moneyDecimals] decimals, read when the text
  /// changes, so a currency change applies at once. With 2 decimals a pasted
  /// 1,250 is 1250; with the Kuwaiti Dinar's 3 it is 1.250.
  const DecimalInputFormatter.money({this.signed = false})
    : _maxDecimals = null,
      grouping = true,
      _money = true;

  /// A percentage: 2 decimals; a pasted 1,250 is 1.25.
  const DecimalInputFormatter.percent()
    : signed = false,
      _maxDecimals = 2,
      grouping = false,
      _money = false;

  /// Whether the field takes a '-' (a price adjustment).
  final bool signed;

  /// Whether a pasted single '.' or ',' with 3 digits after it may group
  /// thousands (see [NumberInput.normalize]).
  final bool grouping;

  final int? _maxDecimals;
  final bool _money;

  /// The most decimals the field takes; null for any number.
  int? get maxDecimals => _money ? NumberInput.moneyDecimals : _maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _formatNumber(
    oldValue,
    newValue,
    signed: signed,
    integer: false,
    maxDecimals: maxDecimals,
    grouping: grouping,
  );
}

/// A whole-number field's formatter (stock, days, a threshold): any
/// script's digits as 0-9, '-' first only when [signed], everything else
/// ignored. A pasted 1,250 is 1250; a pasted 12.5 is refused.
class IntegerInputFormatter extends TextInputFormatter {
  const IntegerInputFormatter({this.signed = false});

  /// Whether the field takes a '-'.
  final bool signed;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _formatNumber(
    oldValue,
    newValue,
    signed: signed,
    integer: true,
    maxDecimals: 0,
    grouping: true,
  );
}

/// A phone number field's formatter: any script's digits as 0-9, and '+'
/// (before the first digit only), spaces, '-', '(' and ')' kept; anything
/// else is dropped, typed or pasted.
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final out = StringBuffer();
    // How many units before each offset were dropped, to move the caret.
    final dropped = List<int>.filled(text.length + 1, 0);
    var started = false; // a digit or '+' kept
    for (var i = 0; i < text.length; i++) {
      dropped[i + 1] = dropped[i];
      final unit = text.codeUnitAt(i);
      final digit = NumberInput._digitOf(unit);
      int? kept;
      if (digit >= 0) {
        kept = _zero + digit;
        started = true;
      } else if (unit == 0x2B || unit == 0xFF0B) {
        if (!started) kept = 0x2B; // +
        started = true;
      } else if (_groupingSpaces.contains(unit)) {
        kept = 0x20;
      } else if (unit == _minus ||
          unit == _unicodeMinus ||
          (unit >= 0x2010 && unit <= 0x2013)) {
        kept = _minus; // hyphens and dashes
      } else if (unit == 0x28 || unit == 0xFF08) {
        kept = 0x28; // (
      } else if (unit == 0x29 || unit == 0xFF09) {
        kept = 0x29; // )
      }
      if (kept == null) {
        dropped[i + 1]++;
      } else {
        out.writeCharCode(kept);
      }
    }
    final result = out.toString();
    if (result == text) return newValue;
    int moved(int offset) =>
        offset < 0 || offset > text.length ? offset : offset - dropped[offset];
    final selection = newValue.selection;
    return TextEditingValue(
      text: result,
      selection: selection.copyWith(
        baseOffset: moved(selection.baseOffset),
        extentOffset: moved(selection.extentOffset),
      ),
    );
  }
}

/// [newValue] as an edit of [oldValue]: the old text's [start, end) replaced
/// by [inserted]. [atSelection] when that range is the old selection (a key
/// typed, a paste, a cut), rather than the least that changed (a deletion
/// before the caret, text an input method rewrote).
({int start, int end, String inserted, bool atSelection}) _editOf(
  TextEditingValue oldValue,
  TextEditingValue newValue,
) {
  final before = oldValue.text;
  final after = newValue.text;
  final selection = oldValue.selection;
  if (selection.isValid && selection.end <= before.length) {
    final head = before.substring(0, selection.start);
    final tail = before.substring(selection.end);
    if (after.length >= head.length + tail.length &&
        after.startsWith(head) &&
        after.endsWith(tail)) {
      return (
        start: selection.start,
        end: selection.end,
        inserted: after.substring(head.length, after.length - tail.length),
        atSelection: true,
      );
    }
  }
  var start = 0;
  while (start < before.length &&
      start < after.length &&
      before.codeUnitAt(start) == after.codeUnitAt(start)) {
    start++;
  }
  var same = 0; // units alike at the end, after [start]
  while (same < before.length - start &&
      same < after.length - start &&
      before.codeUnitAt(before.length - 1 - same) ==
          after.codeUnitAt(after.length - 1 - same)) {
    same++;
  }
  return (
    start: start,
    end: before.length - same,
    inserted: after.substring(start, after.length - same),
    atSelection: false,
  );
}

/// The formatting behind [DecimalInputFormatter] and
/// [IntegerInputFormatter].
TextEditingValue _formatNumber(
  TextEditingValue oldValue,
  TextEditingValue newValue, {
  required bool signed,
  required bool integer,
  required int? maxDecimals,
  required bool grouping,
}) {
  if (newValue.text == oldValue.text) return newValue;
  bool canonical(String text) => NumberInput._isCanonical(
    text,
    signed: signed,
    integer: integer,
    maxDecimals: maxDecimals,
  );
  final edit = _editOf(oldValue, newValue);
  // What deleting leaves of canonical text is canonical, and text the app
  // set (a price saved with more decimals) can always be edited down.
  if (edit.inserted.isEmpty) return newValue;

  if (edit.atSelection && edit.inserted.length == 1) {
    // One key typed over the selection.
    final head = oldValue.text.substring(0, edit.start);
    final tail = oldValue.text.substring(edit.end);
    final key = edit.inserted.codeUnitAt(0);
    final digit = NumberInput._digitOf(key);
    var typed = '';
    if (digit >= 0) {
      typed = String.fromCharCode(_zero + digit);
    } else if (_pointKeys.contains(key)) {
      if (!integer && !head.contains('.') && !tail.contains('.')) {
        typed = head.isEmpty || head == '-' ? '0.' : '.';
      }
    } else if (key == _minus || key == _unicodeMinus) {
      if (signed && edit.start == 0) typed = '-';
    }
    final text = head + typed + tail;
    if (!canonical(text)) return oldValue;
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: edit.start + typed.length),
    );
  }

  if (canonical(newValue.text)) return newValue;
  // A paste over the selection, or text an input method rewrote: read as a
  // pasted number.
  final source = edit.atSelection ? edit.inserted : newValue.text;
  final pasted = NumberInput.normalize(
    source,
    signed: signed,
    maxDecimals: maxDecimals,
    grouping: grouping,
    integer: integer,
  );
  if (pasted == null) return oldValue;
  final text = edit.atSelection
      ? oldValue.text.replaceRange(edit.start, edit.end, pasted)
      : pasted;
  if (!canonical(text)) return oldValue;
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(
      offset: edit.atSelection ? edit.start + pasted.length : text.length,
    ),
  );
}
