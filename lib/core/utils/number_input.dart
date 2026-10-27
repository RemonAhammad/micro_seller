import 'dart:math' as math;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';

// Typing and reading amounts and other numbers alike on every phone.
//
// A phone's number pad types its own region's digits and decimal separator:
// on iOS, '١٢٫٥' with an Arabic region and '12,5' with a French, Brazilian or
// Indonesian one; on Android, a Bengali or Arabic keyboard types its own
// digits. double.tryParse reads none of them. The formatters below keep a
// field's text canonical (ASCII digits, '.' as the point, '-' only where the
// field takes a sign) whatever was typed or pasted, and
// NumberInput.parseDecimal / parseInteger read field text back.
//
// Whether a ',' is the decimal point or groups thousands depends on where
// the phone is: France writes 1,5 and 1.250, Bangladesh 1.5 and 1,250. The
// device's region decides ([NumberInput.deviceDecimalSeparator]), for a ','
// typed and for a pasted 1,459 or 1.459.

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

/// Keys that always type the decimal point: '.', the Arabic '٫' and the
/// full-width '．'.
const _pointKeys = <int>{_point, _arabicPoint, 0xFF0E};

/// ',' and the full-width '，': the decimal point where the region writes
/// decimals with a comma, else what groups thousands
/// ([NumberInput._typedCommaIsPoint]).
const _commaKeys = <int>{_comma, 0xFF0C};

/// Spaces that group digits: the space, the no-break space, the figure,
/// thin and narrow no-break spaces.
const _groupingSpaces = <int>{0x20, 0xA0, 0x2007, 0x2009, 0x202F};

/// What only ever groups digits inside a pasted number, so it is dropped:
/// the spaces, '٬' and apostrophes (1'250.50).
const _groupingOnly = <int>{..._groupingSpaces, _arabicGrouping, 0x27, 0x2019};

/// Invisible marks that text copied from Arabic or Urdu (a message, an SMS)
/// carries beside its numbers, and that no one can see to delete: the
/// direction marks, embeddings and isolates, the zero-width space and the
/// byte order mark.
final _invisibleMarks = RegExp(
  '[\u200B\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069\uFEFF]',
);

/// What may come before the first digit or after the last one of a pasted
/// number: a currency symbol or code (৳, Rp, د.ك, Tk.), '%' or '٪', spaces,
/// parentheses and signs, '/-' and '/=' (500/- reads "500 only"). Anything
/// else there (12# or #12) isn't an amount.
final _numberEnds = RegExp(
  r"^[\p{L}\p{M}\p{Sc}\s()%‰٪+.,٫٬'’/=−-]*$",
  unicode: true,
);

/// Ends with a letter: a '.' after one ends a currency code (Rs.500, Tk.50)
/// rather than starting a fraction.
final _endsWithLetter = RegExp(r'[\p{L}\p{M}]$', unicode: true);

final _decimalText = RegExp(r'^-?(\d+\.?\d*|\.\d+)$');
final _integerText = RegExp(r'^-?\d+(\.0*)?$');
final _nonZeroDigit = RegExp('[1-9]');
final _nonDigit = RegExp('[^0-9]');

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

  /// The locale [deviceDecimalSeparator] reads in tests, in place of the
  /// device's. `Locale('und')` is a region with no known separator.
  @visibleForTesting
  static Locale? debugDeviceLocale;

  static Locale? _separatorLocale;
  static String? _separator;

  /// How the device's region writes decimals, '.' or ',', from the phone's
  /// locale (`PlatformDispatcher.locale`, through intl's number symbols):
  /// ',' in France, Brazil, Indonesia or Vietnam, '.' in Bangladesh, India
  /// or the US. Null when the locale isn't known, or writes them otherwise
  /// (Persian and Egyptian Arabic '٫', which is always the point).
  ///
  /// It decides what a ',' typed into an amount is, and a pasted single
  /// '.' or ',' with 3 digits after it (1.459, 1,250).
  static String? get deviceDecimalSeparator {
    final locale = debugDeviceLocale ?? PlatformDispatcher.instance.locale;
    if (locale != _separatorLocale) {
      _separatorLocale = locale;
      _separator = _decimalSeparatorOf(locale);
    }
    return _separator;
  }

  static String? _decimalSeparatorOf(Locale locale) {
    final country = locale.countryCode;
    final name = country == null || country.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_$country';
    final known = Intl.verifiedLocale(
      name,
      NumberFormat.localeExists,
      onFailure: (_) => null,
    );
    final separator = known == null
        ? null
        : numberFormatSymbols[known]?.DECIMAL_SEP;
    return separator == '.' || separator == ',' ? separator : null;
  }

  /// Whether a ',' typed into an amount is its decimal point. On iOS it
  /// always is: the decimal pad has one separator key, the region's decimal
  /// mark (and the language a phone reports needn't tell its region).
  /// Elsewhere a keyboard may have both, and a ',' is the point only where
  /// the region writes decimals with one; in Bangladesh it groups 1,250, as
  /// '.' is the point there, and is left out.
  static bool get _typedCommaIsPoint =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      deviceDecimalSeparator == ',';

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

  /// Whether [phone] holds [query] as typed in a search box: in any script's
  /// digits, as phones are saved with 0-9 (a Bengali keyboard's ০১৭ finds
  /// 017).
  static bool phoneMatches(String phone, String query) =>
      toAsciiDigits(phone).contains(toAsciiDigits(query));

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
  /// isn't one ("abc", "12 apples 3", "1,250,50"), or is negative and the
  /// field isn't [signed].
  ///
  /// Any script's digits count; '٫' is always the decimal point; '٬',
  /// spaces and apostrophes group digits; invisible direction marks are
  /// left out. A currency symbol or code, '%' and parentheses at either end
  /// are dropped. The number is negative when a '-' comes before its first
  /// digit or it is in parentheses: only a [signed] field takes it.
  ///
  /// Which of '.' and ',' is the point: when both appear, the last one (it
  /// must appear once); a kind that appears more than once groups digits; a
  /// kind that appears once is the point, except with [grouping] (money and
  /// whole numbers) when exactly 3 digits follow it, after a valid group:
  /// then it groups thousands when it isn't the decimal separator of the
  /// device's region ([deviceDecimalSeparator]: 1.459 is 1.459 in
  /// Bangladesh and 1459 in Germany). Where the region isn't known, a ','
  /// groups (the app's own 1,250, as `CurrencyFormatter` writes it) and so
  /// does a '.', unless the field takes 3 decimals (the Kuwaiti Dinar's
  /// 25.000).
  ///
  /// Digits must be grouped as amounts are, in thousands (1,250,000) or in
  /// South Asian lakhs and crores (1,25,000 · 12,34,56,789), else the paste
  /// is refused rather than read as another number.
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
    final text = toAsciiDigits(
      raw.replaceAll(_invisibleMarks, ''),
    ).replaceAll('．', '.').replaceAll('，', ',');
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
    // A field without a sign refuses a negative number rather than drop its
    // sign: -50 isn't 50.
    if (negative && !signed) return null;
    // A point right before the first digit starts the fraction (.5, -.5,
    // $.50), unless it ends a currency code (Rs.500).
    final leadingPoint =
        prefix.isNotEmpty &&
        (_pointKeys.contains(prefix.codeUnitAt(prefix.length - 1)) ||
            _commaKeys.contains(prefix.codeUnitAt(prefix.length - 1))) &&
        !_endsWithLetter.hasMatch(prefix.substring(0, prefix.length - 1));

    // The number from its first digit to its last: digits, and the marks
    // that are its point or group its digits.
    final number = text.substring(first, last + 1);
    for (final unit in number.codeUnits) {
      if (!_isAsciiDigit(unit) &&
          unit != _point &&
          unit != _comma &&
          unit != _arabicPoint &&
          !_groupingOnly.contains(unit)) {
        return null; // a letter, a sign or a slash between digits
      }
    }
    int count(String mark) => mark.allMatches(number).length;
    final dots = count('.');
    final commas = count(',');

    // Where the decimal point is in [number]; null when it has none.
    int? point;
    if (number.contains('٫')) {
      point = number.indexOf('٫');
      if (count('٫') > 1 ||
          number.contains('.', point) ||
          number.contains(',', point)) {
        return null;
      }
    } else if (dots > 0 && commas > 0) {
      point = math.max(number.lastIndexOf('.'), number.lastIndexOf(','));
      if (count(number[point]) > 1) return null;
    } else if (dots + commas == 1) {
      final at = number.indexOf(dots == 1 ? '.' : ',');
      final thousands = _groupsThousands(
        number,
        at,
        grouping: grouping,
        integer: integer,
        maxDecimals: maxDecimals,
      );
      if (!thousands) point = at;
    }
    if (leadingPoint && (point != null || dots + commas > 0)) {
      return null; // two points
    }

    var whole = point == null ? number : number.substring(0, point);
    var fraction = point == null ? '' : number.substring(point + 1);
    if (leadingPoint) {
      fraction = whole;
      whole = '';
    }
    // Only digits after the point, and the whole part grouped as amounts
    // are: 1.2.3 and 1,250,50 are no amounts.
    if (fraction.contains(_nonDigit)) return null;
    final groups = whole.split(_nonDigit);
    if (!_validGroups(groups)) return null;
    whole = groups.join();
    final sign = negative ? '-' : '';

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

  /// Whether the one '.' or ',' of [number], at [at], groups thousands
  /// (1,250 · 25.000) rather than being its decimal point: see [normalize].
  static bool _groupsThousands(
    String number,
    int at, {
    required bool grouping,
    required bool integer,
    required int? maxDecimals,
  }) {
    if (!grouping) return false;
    final after = number.substring(at + 1);
    if (after.length != 3 || after.contains(_nonDigit)) return false;
    final groups = number.substring(0, at).split(_nonDigit)..add(after);
    if (!_validGroups(groups)) return false;
    final mark = number[at];
    final region = deviceDecimalSeparator;
    if (region != null) return mark != region;
    return mark == ',' || integer || (maxDecimals != null && maxDecimals < 3);
  }

  /// Whether [groups], a number's whole part cut where it is grouped, are
  /// grouped as amounts are: in thousands (1,250,000), or in South Asian
  /// lakhs and crores (1,25,000 · 12,34,56,789), with no leading zero. A
  /// whole part in one group always is.
  static bool _validGroups(List<String> groups) {
    if (groups.length < 2) return true;
    final first = groups.first;
    if (first.isEmpty ||
        first.length > 3 ||
        first.codeUnitAt(0) == _zero ||
        groups.last.length != 3) {
      return false;
    }
    final middle = groups.sublist(1, groups.length - 1);
    return middle.every((g) => g.length == 3) ||
        (first.length < 3 && middle.every((g) => g.length == 2));
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
  /// spaces, '٬' or invisible marks.
  static String? _readable(String? text) {
    if (text == null) return null;
    final out = StringBuffer();
    final digits = toAsciiDigits(text.replaceAll(_invisibleMarks, '').trim());
    for (final unit in digits.codeUnits) {
      if (unit == _comma || unit == _arabicPoint) {
        out.writeCharCode(_point);
      } else if (unit != _arabicGrouping && !_groupingSpaces.contains(unit)) {
        out.writeCharCode(unit);
      }
    }
    return out.toString();
  }

  /// The decimals of [text] when it is a field's canonical text with any
  /// number of them (0 without a point), else null: an optional '-'
  /// ([signed] only), ASCII digits, then for a decimal field an optional
  /// '.' and digits. '', '-' and '.5' are canonical, as deleting leaves
  /// them.
  static int? _decimalsOf(
    String text, {
    required bool signed,
    required bool integer,
  }) {
    var i = signed && text.startsWith('-') ? 1 : 0;
    while (i < text.length && _isAsciiDigit(text.codeUnitAt(i))) {
      i++;
    }
    if (i == text.length) return 0;
    if (integer || text.codeUnitAt(i) != _point) return null;
    final fraction = ++i;
    while (i < text.length && _isAsciiDigit(text.codeUnitAt(i))) {
      i++;
    }
    return i == text.length ? i - fraction : null;
  }

  /// Whether [text] is a field's canonical text with at most [maxDecimals]
  /// decimals (any number when null): see [_decimalsOf].
  static bool _isCanonical(
    String text, {
    required bool signed,
    required bool integer,
    required int? maxDecimals,
  }) {
    final decimals = _decimalsOf(text, signed: signed, integer: integer);
    return decimals != null && (maxDecimals == null || decimals <= maxDecimals);
  }
}

/// An amount field's formatter: keeps the text canonical (ASCII digits, '.'
/// as the point, at most [maxDecimals] decimals, '-' first only when
/// [signed]) whatever a keyboard types or the user pastes.
///
/// Typing: any script's digit becomes 0-9; '.', '٫' and '．' become the
/// point, and so does ',' on iOS and where the region writes decimals with
/// it (France, Brazil; elsewhere it groups thousands, and is left out),
/// unless the text already has one (a point typed first becomes '0.'); '-'
/// only at the start of a signed field; any other key is ignored, and a key
/// that would leave the text off its form (a third decimal) leaves it,
/// caret included, as it was. Text the app put in the field with more
/// decimals than it types (a price saved before) stays editable, as long as
/// an edit adds none. Pasting reads the pasted text as
/// [NumberInput.normalize] does. Deleting is never refused.
class DecimalInputFormatter extends TextInputFormatter {
  const DecimalInputFormatter({
    this.signed = false,
    this._maxDecimals,
    this.grouping = false,
  }) : _money = false;

  /// A money field: [NumberInput.moneyDecimals] decimals, read when the text
  /// changes, so a currency change applies at once. A pasted 1,250 is 1250
  /// (in a region that writes decimals with ',', 1.250 is), with the
  /// Kuwaiti Dinar's 3 decimals too.
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

/// [keys] typed one after another between [head] and [tail]: each digit of
/// any script as 0-9; a point key as '.' while the text has no point ('0.'
/// with nothing before it), a ',' only where it is the point
/// ([NumberInput._typedCommaIsPoint]); '-' or '−' at the start of a
/// [signed] field; any other key left out.
String _typed(
  String head,
  String keys,
  String tail, {
  required bool signed,
  required bool integer,
}) {
  final out = StringBuffer();
  for (final key in keys.codeUnits) {
    final digit = NumberInput._digitOf(key);
    if (digit >= 0) {
      out.writeCharCode(_zero + digit);
    } else if (_pointKeys.contains(key) ||
        (_commaKeys.contains(key) && NumberInput._typedCommaIsPoint)) {
      final before = '$head$out';
      if (!integer && !before.contains('.') && !tail.contains('.')) {
        out.write(before.isEmpty || before == '-' ? '0.' : '.');
      }
    } else if (key == _minus || key == _unicodeMinus) {
      if (signed && head.isEmpty && out.isEmpty) out.write('-');
    }
  }
  return out.toString();
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
  final edit = _editOf(oldValue, newValue);
  // What deleting leaves of canonical text is canonical, and text the app
  // set (a price saved with more decimals) can always be edited down.
  if (edit.inserted.isEmpty) return newValue;

  // Text the app put in the field with more decimals than it takes (a price
  // saved before, under a currency with more) stays editable: an edit may
  // keep as many decimals as it had, and add none.
  final had = NumberInput._decimalsOf(
    oldValue.text,
    signed: signed,
    integer: integer,
  );
  final limit = maxDecimals != null && had != null && had > maxDecimals
      ? had
      : maxDecimals;
  bool canonical(String text) => NumberInput._isCanonical(
    text,
    signed: signed,
    integer: integer,
    maxDecimals: limit,
  );

  final head = oldValue.text.substring(0, edit.start);
  final tail = oldValue.text.substring(edit.end);
  final String inserted;
  if (edit.atSelection && edit.inserted.length > 1) {
    // A paste over the selection: read as a pasted number.
    final pasted = NumberInput.normalize(
      edit.inserted,
      signed: signed,
      maxDecimals: maxDecimals,
      grouping: grouping,
      integer: integer,
    );
    if (pasted == null) return oldValue;
    inserted = pasted;
  } else {
    // One key typed over the selection; or text an input method changed
    // away from the caret, read as keys typed where it changed, so the
    // digits already in the field are never read again (a 0 typed after a
    // 1,25 the platform hadn't seen become 1.25 isn't 1250).
    if (!edit.atSelection && canonical(newValue.text)) return newValue;
    inserted = _typed(
      head,
      edit.inserted,
      tail,
      signed: signed,
      integer: integer,
    );
    // Nor may such a change take the point out from under the digits it
    // types: 9.99 rewritten as 9,995 isn't 9995.
    if (!edit.atSelection &&
        oldValue.text.substring(edit.start, edit.end).contains('.') &&
        !inserted.contains('.')) {
      return oldValue;
    }
  }
  final text = head + inserted + tail;
  if (!canonical(text)) return oldValue;
  if (text == newValue.text) return newValue;
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: edit.start + inserted.length),
  );
}
