import 'dart:math' as math;
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';

const _scriptZeros = <int>[
  0x0660,
  0x06F0,
  0x0966,
  0x09E6,
  0x0A66,
  0x0AE6,
  0x0B66,
  0x0BE6,
  0x0C66,
  0x0CE6,
  0x0D66,
  0x0E50,
  0x0ED0,
  0x1040,
  0x17E0,
  0xFF10,
];

const _zero = 0x30;
const _point = 0x2E;
const _comma = 0x2C;
const _minus = 0x2D;
const _unicodeMinus = 0x2212;
const _arabicPoint = 0x066B;
const _arabicGrouping = 0x066C;

const _pointKeys = <int>{_point, _arabicPoint, 0xFF0E};

const _commaKeys = <int>{_comma, 0xFF0C};

const _groupingSpaces = <int>{0x20, 0xA0, 0x2007, 0x2009, 0x202F};

const _groupingOnly = <int>{..._groupingSpaces, _arabicGrouping, 0x27, 0x2019};

final _invisibleMarks = RegExp(
  '[\u200B\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069\uFEFF]',
);

final _numberEnds = RegExp(
  r"^[\p{L}\p{M}\p{Sc}\s()%‰٪+.,٫٬'’/=−-]*$",
  unicode: true,
);

final _endsWithLetter = RegExp(r'[\p{L}\p{M}]$', unicode: true);

final _decimalText = RegExp(r'^-?(\d+\.?\d*|\.\d+)$');
final _integerText = RegExp(r'^-?\d+(\.0*)?$');
final _nonZeroDigit = RegExp('[1-9]');
final _nonDigit = RegExp('[^0-9]');

bool _isAsciiDigit(int unit) => unit >= _zero && unit <= _zero + 9;

abstract final class NumberInput {

  static int moneyDecimals = 2;

  @visibleForTesting
  static Locale? debugDeviceLocale;

  static Locale? _separatorLocale;
  static String? _separator;

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

  static bool get _typedCommaIsPoint =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      deviceDecimalSeparator == ',';

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

  static bool phoneMatches(String phone, String query) =>
      toAsciiDigits(phone).contains(toAsciiDigits(query));

  static int _digitOf(int unit) {
    if (_isAsciiDigit(unit)) return unit - _zero;
    for (final zero in _scriptZeros) {
      if (unit >= zero && unit <= zero + 9) return unit - zero;
    }
    return -1;
  }

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

    if (negative && !signed) return null;

    final leadingPoint =
        prefix.isNotEmpty &&
        (_pointKeys.contains(prefix.codeUnitAt(prefix.length - 1)) ||
            _commaKeys.contains(prefix.codeUnitAt(prefix.length - 1))) &&
        !_endsWithLetter.hasMatch(prefix.substring(0, prefix.length - 1));

    final number = text.substring(first, last + 1);
    for (final unit in number.codeUnits) {
      if (!_isAsciiDigit(unit) &&
          unit != _point &&
          unit != _comma &&
          unit != _arabicPoint &&
          !_groupingOnly.contains(unit)) {
        return null;
      }
    }
    int count(String mark) => mark.allMatches(number).length;
    final dots = count('.');
    final commas = count(',');

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
      return null;
    }

    var whole = point == null ? number : number.substring(0, point);
    var fraction = point == null ? '' : number.substring(point + 1);
    if (leadingPoint) {
      fraction = whole;
      whole = '';
    }

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

    if (mark == ',') return true;
    final region = deviceDecimalSeparator;
    if (region != null) return mark != region;
    return integer || (maxDecimals != null && maxDecimals < 3);
  }

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

  static double? parseDecimal(String? text) {
    final readable = _readable(text);
    if (readable == null || !_decimalText.hasMatch(readable)) return null;
    final value = double.tryParse(readable);
    return value != null && value.isFinite ? value : null;
  }

  static int? parseInteger(String? text) {
    final readable = _readable(text);
    if (readable == null || !_integerText.hasMatch(readable)) return null;
    final point = readable.indexOf('.');
    return int.tryParse(point < 0 ? readable : readable.substring(0, point));
  }

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

class DecimalInputFormatter extends TextInputFormatter {
  const DecimalInputFormatter({
    this.signed = false,
    this._maxDecimals,
    this.grouping = false,
  }) : _money = false;

  const DecimalInputFormatter.money({this.signed = false})
    : _maxDecimals = null,
      grouping = true,
      _money = true;

  const DecimalInputFormatter.percent()
    : signed = false,
      _maxDecimals = 2,
      grouping = false,
      _money = false;

  final bool signed;

  final bool grouping;

  final int? _maxDecimals;
  final bool _money;

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

class IntegerInputFormatter extends TextInputFormatter {
  const IntegerInputFormatter({this.signed = false});

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

class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final out = StringBuffer();

    final dropped = List<int>.filled(text.length + 1, 0);
    var started = false;
    for (var i = 0; i < text.length; i++) {
      dropped[i + 1] = dropped[i];
      final unit = text.codeUnitAt(i);
      final digit = NumberInput._digitOf(unit);
      int? kept;
      if (digit >= 0) {
        kept = _zero + digit;
        started = true;
      } else if (unit == 0x2B || unit == 0xFF0B) {
        if (!started) kept = 0x2B;
        started = true;
      } else if (_groupingSpaces.contains(unit)) {
        kept = 0x20;
      } else if (unit == _minus ||
          unit == _unicodeMinus ||
          (unit >= 0x2010 && unit <= 0x2013)) {
        kept = _minus;
      } else if (unit == 0x28 || unit == 0xFF08) {
        kept = 0x28;
      } else if (unit == 0x29 || unit == 0xFF09) {
        kept = 0x29;
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
  var same = 0;
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

  if (edit.inserted.isEmpty) return newValue;

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

    if (!edit.atSelection && canonical(newValue.text)) return newValue;
    inserted = _typed(
      head,
      edit.inserted,
      tail,
      signed: signed,
      integer: integer,
    );

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
