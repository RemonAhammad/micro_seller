// Typing and pasting amounts, whole numbers and phone numbers on any phone's
// keyboard. A number pad types its region's digits and decimal separator
// (an iPhone set to France types 12,50, one set to an Arabic region ١٢٫٥٠),
// and a paste can be 1,250.00, 1.250,00 or ৳১,২৫০. The formatters keep a
// field's text canonical (ASCII digits, '.' as the point) and the parsers
// read it back, so every field, validator and save reads the same amount.
//
// Whether a ',' is a point depends on where the phone is: France writes 1,5
// and 1.250, Bangladesh 1.5 and 1,250. The device's region decides, for a
// ',' typed off iOS and for a pasted 1,459 or 1.459.
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/number_input.dart';
import 'package:micro_seller/core/utils/validators.dart';

/// [inserted] typed or pasted over [value]'s selection, as a keyboard or the
/// text field's Paste does it (at the end when there is no selection).
TextEditingValue _enter(
  TextInputFormatter formatter,
  TextEditingValue value,
  String inserted,
) {
  final selection = value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);
  return formatter.formatEditUpdate(
    value.copyWith(selection: selection),
    TextEditingValue(
      text: value.text.replaceRange(selection.start, selection.end, inserted),
      selection: TextSelection.collapsed(
        offset: selection.start + inserted.length,
      ),
    ),
  );
}

/// [keys] typed one key at a time from [from].
TextEditingValue _type(
  TextInputFormatter formatter,
  String keys, {
  TextEditingValue from = TextEditingValue.empty,
}) {
  var value = from;
  for (final key in keys.split('')) {
    value = _enter(formatter, value, key);
  }
  return value;
}

/// [text] with the caret at [caret] (its end when null).
TextEditingValue _at(String text, [int? caret]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);

/// [text], all of it selected.
TextEditingValue _selected(String text) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: 0, extentOffset: text.length),
);

/// [text] pasted over all of the field's value (a 7).
String _pasted(TextInputFormatter formatter, String text) =>
    _enter(formatter, _selected('7'), text).text;

const _money = DecimalInputFormatter.money();
const _signedMoney = DecimalInputFormatter.money(signed: true);
const _percent = DecimalInputFormatter.percent();
const _integer = IntegerInputFormatter();
const _phone = PhoneInputFormatter();

/// Regions that write decimals with '.' (Bangladesh, the US), with ','
/// (France, Indonesia), and one whose way isn't known.
const _bangladesh = Locale('bn', 'BD');
const _us = Locale('en', 'US');
const _france = Locale('fr', 'FR');
const _indonesia = Locale('id', 'ID');
const _unknown = Locale('und');

/// The phone is in [locale]'s region.
void _region(Locale locale) => NumberInput.debugDeviceLocale = locale;

/// The phone is an iPhone (iOS), or an Android phone when null.
void _platform(TargetPlatform? platform) =>
    debugDefaultTargetPlatformOverride = platform;

void main() {
  setUp(() => _region(_bangladesh));

  tearDown(() {
    CurrencyFormatter.setSymbol('\$');
    NumberInput.debugDeviceLocale = null;
    debugDefaultTargetPlatformOverride = null;
  });

  test("the device's region tells how it writes decimals", () {
    final expected = <Locale, String?>{
      _bangladesh: '.',
      _us: '.',
      Locale('en', 'IN'): '.',
      Locale('ur', 'PK'): '.',
      Locale('th', 'TH'): '.',
      Locale('ms', 'MY'): '.',
      Locale('de', 'CH'): '.',
      _france: ',',
      _indonesia: ',',
      Locale('vi', 'VN'): ',',
      Locale('tr', 'TR'): ',',
      Locale('pt', 'BR'): ',',
      Locale('es', 'ES'): ',',
      // '٫' is always the point; ',' and '.' aren't known.
      Locale('ar', 'EG'): null,
      Locale('fa', 'IR'): null,
      _unknown: null,
    };
    for (final MapEntry(key: locale, value: separator) in expected.entries) {
      _region(locale);
      expect(NumberInput.deviceDecimalSeparator, separator, reason: '$locale');
    }
  });

  group('typing', () {
    test('any script\'s digits and decimal point, one key at a time', () {
      const typed = {
        '12.50': '12.50',
        '12٫5': '12.5',
        '١٢٫٥': '12.5',
        '١٢٫٥٠': '12.50',
        '۱۲۳': '123',
        '১২৩.৫': '123.5',
        '१२': '12',
        '๑๒': '12',
        '１２': '12',
        '１２．５': '12.5',
      };
      for (final region in [_bangladesh, _france, _unknown]) {
        _region(region);
        for (final MapEntry(key: keys, value: expected) in typed.entries) {
          final value = _type(_money, keys);
          expect(value.text, expected, reason: '$region: $keys');
          expect(
            value.selection,
            TextSelection.collapsed(offset: expected.length),
            reason: '$region: $keys: the caret stays after what was typed',
          );
        }
      }
    });

    test('a comma is the point on an iPhone, whose decimal pad types the '
        "region's mark", () {
      _platform(TargetPlatform.iOS);
      for (final region in [_bangladesh, _france, _unknown]) {
        _region(region);
        expect(_type(_money, '12,50').text, '12.50', reason: '$region');
        expect(_type(_money, '１２，５').text, '12.5', reason: '$region');
        expect(_type(_money, ',5').text, '0.5', reason: '$region');
      }
    });

    test('elsewhere a comma is the point only where the region writes '
        'decimals with one', () {
      _region(_france);
      expect(_type(_money, '12,50').text, '12.50');
      expect(_type(_money, '１２，５').text, '12.5');
      _region(_indonesia);
      expect(_type(_money, '12,5').text, '12.5');
      // Bangladesh writes 1,250 for 1250 and 1,00,000 for a lakh: a comma
      // groups thousands, and is left out, as the field used to leave it.
      for (final region in [_bangladesh, _us, _unknown]) {
        _region(region);
        expect(_type(_money, '1,250').text, '1250', reason: '$region');
        expect(_type(_money, '1,00,000').text, '100000', reason: '$region');
        expect(_type(_money, '12,50').text, '1250', reason: '$region');
        expect(_type(_money, '1,250.5').text, '1250.5', reason: '$region');
      }
    });

    test('a second point is ignored', () {
      expect(_type(_money, '1.2.3').text, '1.23');
      expect(_type(_money, '1.2٫3').text, '1.23');
      _region(_france);
      expect(_type(_money, '1,2,3').text, '1.23');
      expect(_type(_money, '1.2,3').text, '1.23');
    });

    test('a point typed first becomes 0.', () {
      final point = _type(_money, '.');
      expect(point.text, '0.');
      expect(point.selection, const TextSelection.collapsed(offset: 2));
      expect(_type(_money, '٫٥').text, '0.5');
      // Before digits already there.
      expect(_enter(_money, _at('5', 0), '.').text, '0.5');
      // After a minus.
      expect(_type(_signedMoney, '-.5').text, '-0.5');
      _region(_france);
      expect(_type(_money, ',5').text, '0.5');
    });

    test('a minus only first, and only in a signed field', () {
      expect(_type(_signedMoney, '-12.5').text, '-12.5');
      expect(_type(_signedMoney, '−5').text, '-5');
      expect(_type(_signedMoney, '5-').text, '5');
      expect(_type(_signedMoney, '--5').text, '-5');
      expect(_enter(_signedMoney, _at('5', 0), '-').text, '-5');
      expect(_type(_money, '-5').text, '5');
      expect(_type(_percent, '-5').text, '5');
    });

    test('a third decimal is refused, the caret kept', () {
      final atEnd = _at('12.34');
      expect(_enter(_money, atEnd, '5'), atEnd);
      final inFraction = _at('12.34', 3);
      expect(_enter(_money, inFraction, '9'), inFraction);
      // A digit in the whole part is fine.
      expect(_enter(_money, _at('12.34', 0), '9').text, '912.34');
      expect(_type(_percent, '1.234').text, '1.23');
    });

    test('a field filled with more decimals than it types stays editable, '
        'adding none', () {
      // A price saved before the field took 2 decimals, or under the
      // Kuwaiti Dinar's 3: every key in its whole part used to be refused.
      final price = _at('2.375');
      expect(_enter(_money, _at('2.375', 0), '1').text, '12.375');
      expect(_enter(_money, _at('2.375', 1), '9').text, '29.375');
      expect(_enter(_money, _at('2.375', 0), '12').text, '122.375');
      // A fourth decimal is still refused.
      expect(_enter(_money, price, '5'), price);
      // Typed over its decimals, the field's 2 again.
      final decimals = TextEditingValue(
        text: '2.375',
        selection: const TextSelection(baseOffset: 3, extentOffset: 5),
      );
      expect(_enter(_money, decimals, '9').text, '2.39');
      // A tax rate read back from binary floating point.
      expect(
        _enter(_percent, _at('0.30000000000000004', 0), '1').text,
        '10.30000000000000004',
      );
    });

    test('any other key is ignored', () {
      expect(_type(_money, '1a2 3+%').text, '123');
      final value = _at('12', 1);
      expect(_enter(_money, value, 'x').text, '12');
      expect(_enter(_money, value, 'x').selection.baseOffset, 1);
    });

    test('a key typed over a selection replaces it', () {
      final value = _enter(_money, _selected('12.34'), '7');
      expect(value.text, '7');
      expect(value.selection, const TextSelection.collapsed(offset: 1));
      // The point selected is the one replaced: no second point.
      final point = TextEditingValue(
        text: '12.5',
        selection: const TextSelection(baseOffset: 2, extentOffset: 4),
      );
      expect(_enter(_money, point, '.').text, '12.');
      // A comma that groups thousands here deletes the selection.
      expect(_enter(_money, point, ',').text, '12');
      _region(_france);
      expect(_enter(_money, point, ',').text, '12.');
    });

    test('deleting is never refused', () {
      // The leading 0 of 0.5, with backspace.
      const before = TextEditingValue(
        text: '0.5',
        selection: TextSelection.collapsed(offset: 1),
      );
      const after = TextEditingValue(
        text: '.5',
        selection: TextSelection.collapsed(offset: 0),
      );
      expect(_money.formatEditUpdate(before, after), after);
      // A price the app set with more decimals than the field types.
      final long = _at('0.30000000000000004');
      final shorter = _at('0.3000000000000000');
      expect(_money.formatEditUpdate(long, shorter), shorter);
    });

    test('a composing-only change passes through', () {
      const value = TextEditingValue(
        text: '12',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      expect(_money.formatEditUpdate(_at('12'), value), value);
    });

    test('text an input method changed away from the caret is read as keys '
        'typed there', () {
      // The whole text changed: its digits are mapped.
      final value = _money.formatEditUpdate(
        _at('12', 0),
        const TextEditingValue(
          text: '١٢٣٫٥',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(value.text, '123.5');
      expect(value.selection, const TextSelection.collapsed(offset: 5));
      // A digit added where the caret wasn't.
      expect(
        _money.formatEditUpdate(_at('12', 0), _at('1٢5')).text,
        '125',
      );
    });

    test('a change away from the caret never reads the digits already there '
        'again', () {
      // The platform's copy of the text is a key behind the formatter's: a
      // ',' typed was made '.', and the next key comes on the old text. Read
      // whole again, as a paste, 1,25 and a 0 made 1250.
      for (final (platform, region) in [
        (null, _france),
        (TargetPlatform.iOS, _bangladesh),
        (null, _bangladesh),
      ]) {
        _platform(platform);
        _region(region);
        final where = '$platform, $region';
        final value = _at('1.25');
        expect(
          _money.formatEditUpdate(value, _at('1,250')),
          value,
          reason: where,
        );
        expect(
          _money.formatEditUpdate(_at('1.25', 0), _at('1.250')).text,
          '1.25',
          reason: where,
        );
        final price = _at('9.99');
        expect(
          _money.formatEditUpdate(price, _at('9,995')),
          price,
          reason: where,
        );
        // A key that fits is taken as typed; a ',' that only groups here
        // can't take the place of the point.
        expect(
          _money.formatEditUpdate(_at('1.2', 0), _at('1,25')).text,
          platform == null && region == _bangladesh ? '1.2' : '1.25',
          reason: where,
        );
      }
    });
  });

  group('pasting', () {
    // Pasted → (money, percent, whole number); null is refused.
    void check(
      String where,
      Map<String, (String?, String?, String?)> table,
    ) {
      for (final (field, formatter, column) in [
        ('money', _money as TextInputFormatter, 0),
        ('percent', _percent, 1),
        ('integer', _integer, 2),
      ]) {
        for (final MapEntry(key: pasted, value: row) in table.entries) {
          final expected = [row.$1, row.$2, row.$3][column];
          final reason = '$where, $field: "$pasted"';

          // Over the whole text.
          final all = _selected('7');
          final replaced = _enter(formatter, all, pasted);
          if (expected == null) {
            expect(replaced, all, reason: '$reason refused');
          } else {
            expect(replaced.text, expected, reason: reason);
            expect(
              replaced.selection,
              TextSelection.collapsed(offset: expected.length),
              reason: '$reason caret',
            );
          }

          // At the caret, after a 7 already typed.
          final seven = _at('7');
          final inserted = _enter(formatter, seven, pasted);
          if (expected == null) {
            expect(inserted, seven, reason: '$reason refused');
          } else {
            expect(inserted.text, '7$expected', reason: '7|$reason');
            expect(
              inserted.selection,
              TextSelection.collapsed(offset: 1 + expected.length),
              reason: '7|$reason caret',
            );
          }
        }
      }
    }

    // The same anywhere: both marks, one mark not followed by 3 digits, a
    // mark repeated, Arabic separators, and what isn't a number.
    const anywhere = <String, (String?, String?, String?)>{
      '1,250.00': ('1250.00', '1250.00', '1250'),
      '1.250,00': ('1250.00', '1250.00', '1250'),
      '1,5': ('1.5', '1.5', null),
      '12,50': ('12.50', '12.50', null),
      '1.250.000': ('1250000', '1250000', '1250000'),
      '1,25,000': ('125000', '125000', '125000'),
      '0.125': ('0.13', '0.13', null),
      '٢٬٥٠٠٫٧٥': ('2500.75', '2500.75', null),
      'abc': (null, null, null),
      '12 apples 3': (null, null, null),
      '1.250.50': (null, null, null),
      '-12.50': (null, null, null),
    };

    test('anywhere', () {
      for (final region in [_bangladesh, _france, _unknown]) {
        _region(region);
        check('$region', anywhere);
      }
    });

    test("where the region writes decimals with '.': a lone ',' with 3 digits "
        "groups thousands, a '.' is the point", () {
      for (final region in [_bangladesh, _us]) {
        _region(region);
        check('$region', const {
          '1,250': ('1250', '1.25', '1250'),
          '৳১,২৫০': ('1250', '1.25', '1250'),
          // A fuel price or a weight: not 1459.
          '1.459': ('1.46', '1.46', null),
          '25.000': ('25.00', '25.00', '25'),
          '3.000': ('3.00', '3.00', '3'),
          'Rp 25.000': ('25.00', '25.00', '25'),
        });
      }
    });

    test("where it writes them with ',': a lone '.' with 3 digits groups "
        "thousands, a ',' is the point", () {
      for (final region in [_france, _indonesia]) {
        _region(region);
        check('$region', const {
          '1.250': ('1250', '1.25', '1250'),
          'Rp 25.000': ('25000', '25.00', '25000'),
          '1,459': ('1.46', '1.46', null),
          '1,250': ('1.25', '1.25', null),
          '25,000': ('25.00', '25.00', '25'),
        });
      }
    });

    test('where the region isn\'t known: a lone mark with 3 digits groups '
        'thousands in money and whole numbers', () {
      _region(_unknown);
      check('unknown', const {
        '1,250': ('1250', '1.25', '1250'),
        '৳১,২৫০': ('1250', '1.25', '1250'),
        '25.000': ('25000', '25.00', '25000'),
        'Rp 25.000': ('25000', '25.00', '25000'),
        // Not after a 0, nor 4 digits: no group is like that.
        '0,250': ('0.25', '0.25', null),
        '1234,567': ('1234.57', '1234.57', null),
      });
    });

    test('a paste that would leave the text off its form is refused', () {
      // A second point.
      final point = _at('7.');
      expect(_enter(_money, point, '1,5'), point);
      // A third decimal.
      final decimals = _at('7.1');
      expect(_enter(_money, decimals, '25'), decimals);
      // A minus inside the number.
      final minus = _at('12', 1);
      expect(_enter(_signedMoney, minus, '-5'), minus);
    });

    test('a negative number is taken only by a signed field, never made '
        'positive', () {
      expect(_pasted(_signedMoney, '-12.50'), '-12.50');
      expect(_pasted(_signedMoney, '(1,250.00)'), '-1250.00');
      expect(_pasted(_signedMoney, '−5'), '-5');
      expect(_pasted(const IntegerInputFormatter(signed: true), '-3'), '-3');
      for (final (formatter, text) in [
        (_money as TextInputFormatter, '-12.50'),
        (_money, '(1,250.00)'),
        (_money, '−5'),
        (_money, '৳-50'),
        (_percent, '-5'),
        (_integer, '-3'),
      ]) {
        final value = _selected('7');
        expect(_enter(formatter, value, text), value, reason: text);
      }
    });

    test("the app's own amounts paste back as the same amount, in every "
        'currency', () {
      // As CurrencyFormatter writes them in a WhatsApp order or reminder:
      // the symbol, ',' grouping thousands, '.' and up to 2 decimals, or the
      // Kuwaiti Dinar's 3.
      const symbols = [
        '\$', '৳', '₹', 'Rs', '€', '£', '¥', 'Rp', 'RM', '₫', '฿', '₱',
        '₺', 'R\$', '₦', 'KSh', 'Tk', 'د.إ', 'ر.س', 'د.ك',
      ];
      const values = <double>[
        0, 0.5, 1, 12.5, 99.99, 999, 1000, 1250, 1250.5, 12345.67,
        25000, 100000, 1234567.89, 99999999.99,
      ];
      const fils = <double>[0.005, 1.125, 1250.125, 1234567.875];
      for (final region in [_bangladesh, _us, _unknown]) {
        _region(region);
        for (final symbol in symbols) {
          CurrencyFormatter.setSymbol(symbol);
          for (final value in [
            ...values,
            if (symbol == CurrencyFormatter.kuwaitiDinarSymbol) ...fils,
          ]) {
            final text = CurrencyFormatter.format(value);
            final reason = '$region: $text';
            expect(
              NumberInput.parseDecimal(_pasted(_money, text)),
              value,
              reason: reason,
            );
            expect(
              NumberInput.parseDecimal(_pasted(_signedMoney, text)),
              value,
              reason: reason,
            );
            // A negative one, into a field that takes a sign.
            if (value > 0) {
              final negative = CurrencyFormatter.format(-value);
              expect(
                NumberInput.parseDecimal(_pasted(_signedMoney, negative)),
                -value,
                reason: '$region: $negative',
              );
            }
            // A whole amount into a whole-number field.
            if (value == value.roundToDouble()) {
              expect(
                NumberInput.parseInteger(_pasted(_integer, text)),
                value.toInt(),
                reason: reason,
              );
            }
          }
        }
      }
    });
  });

  group('normalize', () {
    String? money(String raw, {bool signed = false}) => NumberInput.normalize(
      raw,
      signed: signed,
      maxDecimals: 2,
      grouping: true,
    );

    test('rounds half up on the digits', () {
      expect(money('9.9951'), '10.00');
      expect(money('1234.565'), '1234.57');
      expect(money('0.005'), '0.01');
      expect(money('0.004'), '0.00');
      // Binary floating point would make these 1.00 and -2.67.
      expect(NumberInput.normalize('1.005', maxDecimals: 2), '1.01');
      expect(
        NumberInput.normalize('-2.675', signed: true, maxDecimals: 2),
        '-2.68',
      );
      // Where '.' is the point, 9.995 is an amount with 3 decimals.
      expect(money('9.995'), '10.00');
      // Where the region isn't known, a money field reads one '.' with 3
      // digits after 1 to 3 as grouping thousands, as in 25.000.
      _region(_unknown);
      expect(money('9.995'), '9995');
    });

    test('currency symbols and codes, % and spaces at the ends', () {
      expect(money('\$1,250.00'), '1250.00');
      expect(money('1.250,00 €'), '1250.00');
      expect(money('BDT 1,250'), '1250');
      expect(money('Tk. 1,250'), '1250');
      expect(money('Rs.500'), '500');
      expect(money('د.ك 12,5'), '12.5');
      expect(money('500/-'), '500');
      expect(money('12%'), '12');
      expect(money('15٪'), '15');
      expect(money('١٥٪'), '15');
      expect(money('  12.5\n'), '12.5');
    });

    test("Arabic and Urdu text's invisible direction marks are left out", () {
      expect(money('\u200F١٢٫٥٠'), '12.50');
      expect(money('1,250\u200E'), '1250');
      expect(money('\u200F١٢٫٥٠ د.ك.\u200F'), '12.50');
      expect(money('\u2067١٬٢٥٠\u2069'), '1250');
      expect(money('\u061C-5', signed: true), '-5');
      expect(money('\uFEFF12.5'), '12.5');
      expect(NumberInput.parseDecimal('\u200F12.5'), 12.5);
    });

    test('grouping: spaces, apostrophes, ٬ and repeated separators, in '
        'valid groups', () {
      expect(money('1 250,50'), '1250.50');
      expect(money('1 250,50'), '1250.50');
      expect(money('1 250,50'), '1250.50');
      expect(money("1'250.50"), '1250.50');
      expect(money('1 250 000'), '1250000');
      expect(money('1,000,000'), '1000000');
      expect(money('١٬٢٥٠٫٥'), '1250.5');
      expect(NumberInput.normalize('12 345,678', maxDecimals: 2), '12345.68');
      // South Asian lakhs and crores.
      expect(money('1,25,000'), '125000');
      expect(money('1,00,000.50'), '100000.50');
      expect(money('12,34,56,789'), '123456789');
    });

    test('digits grouped as no amount is are refused, not read as another '
        'number', () {
      for (final junk in [
        '1..5',
        '1.2.3',
        '1.250.50',
        '1,250,50',
        '12,5.5',
        '1,2345,678',
        '123,45,678',
        '0.250.000',
        '12 34',
        '1, 250',
      ]) {
        for (final region in [_bangladesh, _france, _unknown]) {
          _region(region);
          expect(money(junk), isNull, reason: '$region: "$junk"');
        }
      }
    });

    test('a point right before the first digit', () {
      expect(money('.5'), '.5');
      expect(money('\$.50'), '.50');
      expect(money('-.5', signed: true), '-.5');
      expect(money('.995'), '1.00');
      expect(NumberInput.normalize('.5', integer: true), isNull);
    });

    test('a single separator groups thousands only before a valid group', () {
      _region(_unknown);
      expect(money('1,250'), '1250');
      expect(money('999.999'), '999999');
      expect(money('1250.000'), '1250.00');
      expect(money('0,250'), '0.25');
      // Off without grouping.
      expect(NumberInput.normalize('1,250', maxDecimals: 2), '1.25');
      // With 3 decimals, a '.' is the point, and a ',' still groups: the
      // app writes 1250 dinars as 1,250.
      expect(
        NumberInput.normalize('1,250', maxDecimals: 3, grouping: true),
        '1250',
      );
      expect(
        NumberInput.normalize('1.250', maxDecimals: 3, grouping: true),
        '1.250',
      );
      expect(NumberInput.normalize('1.250', grouping: true), '1.250');
    });

    test('junk is refused', () {
      for (final junk in [
        '',
        '   ',
        'abc',
        '12 apples 3',
        '12-5',
        '12/5',
        '1,250.000.00',
        '1٫2٫3',
        '1٫2.5',
        '#12',
        '12#',
        'Total: 12',
        '-',
        '.',
      ]) {
        expect(money(junk), isNull, reason: '"$junk"');
      }
    });

    test('whole numbers drop a fraction of zeros only', () {
      String? whole(String raw) =>
          NumberInput.normalize(raw, integer: true, grouping: true);
      expect(whole('12.0'), '12');
      expect(whole('12,00'), '12');
      expect(whole('1,250.00'), '1250');
      expect(whole('12.5'), isNull);
      expect(whole('-3'), isNull);
      expect(NumberInput.normalize('-3', integer: true, signed: true), '-3');
    });
  });

  group('Kuwaiti Dinar: 3 decimals', () {
    test('the currency sets the decimals money fields take', () {
      expect(NumberInput.moneyDecimals, 2);
      CurrencyFormatter.setSymbol(CurrencyFormatter.kuwaitiDinarSymbol);
      expect(NumberInput.moneyDecimals, 3);
      expect(_money.maxDecimals, 3);
      expect(_percent.maxDecimals, 2);
      CurrencyFormatter.setSymbol('৳');
      expect(NumberInput.moneyDecimals, 2);
      expect(_money.maxDecimals, 2);
    });

    test('a third decimal types and pastes; a fourth is refused', () {
      CurrencyFormatter.setSymbol(CurrencyFormatter.kuwaitiDinarSymbol);
      expect(_type(_money, '1.250').text, '1.250');
      expect(_type(_money, '1.2505').text, '1.250');
      _region(_france);
      expect(_type(_money, '1,2505').text, '1.250');
      _region(_bangladesh);
      expect(_pasted(_money, '0.1255'), '0.126');
      // 1,250 is 1250 dinars, as the app writes them; 25.000 is 25.
      expect(_pasted(_money, '1,250'), '1250');
      expect(_pasted(_money, 'د.ك1,250'), '1250');
      expect(_pasted(_money, 'KWD 1,250'), '1250');
      expect(_pasted(_money, '250,000'), '250000');
      expect(_pasted(_money, '25.000'), '25.000');
      expect(_pasted(_money, '1,250.500'), '1250.500');
      _region(_unknown);
      expect(_pasted(_money, '1,250'), '1250');
      expect(_pasted(_money, '25.000'), '25.000');
    });

    test('amounts show their fils', () {
      CurrencyFormatter.setSymbol(CurrencyFormatter.kuwaitiDinarSymbol);
      expect(CurrencyFormatter.format(1.125), 'د.ك1.125');
      expect(CurrencyFormatter.format(1000.125), 'د.ك1,000.125');
      expect(CurrencyFormatter.format(12.5), 'د.ك12.5');
      expect(CurrencyFormatter.format(1250), 'د.ك1,250');
      // Other currencies keep 2.
      CurrencyFormatter.setSymbol('৳');
      expect(CurrencyFormatter.format(1.125), '৳1.13');
      expect(
        CurrencyFormatter.format(
          1.125,
          symbol: CurrencyFormatter.kuwaitiDinarSymbol,
        ),
        'د.ك1.125',
      );
    });
  });

  group('whole numbers', () {
    test('typing', () {
      expect(_type(_integer, '١٢').text, '12');
      expect(_type(_integer, '12.5').text, '125');
      expect(_type(_integer, '1,000').text, '1000');
      expect(_type(_integer, '-3').text, '3');
      expect(_type(const IntegerInputFormatter(signed: true), '-3').text, '-3');
      // A comma never makes a whole number a fraction.
      _region(_france);
      expect(_type(_integer, '1,000').text, '1000');
    });

    test('pasting', () {
      expect(_pasted(_integer, '12.0'), '12');
      expect(_pasted(_integer, '১২'), '12');
      expect(_pasted(_integer, '12.5'), '7');
    });
  });

  group('phone numbers', () {
    test('typing', () {
      expect(_type(_phone, '+880 1712-345678').text, '+880 1712-345678');
      expect(_type(_phone, '+৮৮০ ১৭১২-৩৪৫৬৭৮').text, '+880 1712-345678');
      expect(_type(_phone, '(555) 123-4567').text, '(555) 123-4567');
      expect(_type(_phone, '880+1').text, '8801');
      expect(_type(_phone, '++880').text, '+880');
      expect(_type(_phone, 'abc12.34').text, '1234');
    });

    test('pasting', () {
      final value = _enter(_phone, _selected('7'), '+৮৮০ ১৭১২-৩৪৫৬৭৮');
      expect(value.text, '+880 1712-345678');
      expect(value.selection, const TextSelection.collapsed(offset: 16));
      // A no-break space and a no-break hyphen, from a contact card.
      expect(_pasted(_phone, '+1 555‑123'), '+1 555-123');
      // What is dropped before the caret moves it back.
      final dropped = _enter(_phone, _at('9', 0), 'a1b2');
      expect(dropped.text, '129');
      expect(dropped.selection, const TextSelection.collapsed(offset: 2));
    });

    test('a search finds them typed in any script\'s digits', () {
      expect(NumberInput.phoneMatches('01712345678', '০১৭১২'), isTrue);
      expect(NumberInput.phoneMatches('+880 1712-345678', '১৭১২'), isTrue);
      expect(NumberInput.phoneMatches('01712345678', '٠١٧'), isTrue);
      expect(NumberInput.phoneMatches('01712345678', '1712'), isTrue);
      expect(NumberInput.phoneMatches('01712345678', '১৮'), isFalse);
      expect(NumberInput.phoneMatches('', '1'), isFalse);
    });
  });

  group('parsing', () {
    test('decimals', () {
      const parsed = <String?, double?>{
        null: null,
        '': null,
        '.': null,
        '-': null,
        '-.': null,
        'NaN': null,
        'Infinity': null,
        '1e5': null,
        '12abc': null,
        '1.2.3': null,
        '+5': null,
        '12': 12,
        '12.5': 12.5,
        '12.': 12,
        '.5': 0.5,
        '-.5': -0.5,
        '-12.25': -12.25,
        '1,5': 1.5,
        '١٢٫٥': 12.5,
        '১২৩.৫': 123.5,
        ' 12.5 ': 12.5,
        '1 250': 1250,
        '1 250.5': 1250.5,
        '2٬500': 2500,
      };
      for (final MapEntry(key: text, value: expected) in parsed.entries) {
        expect(NumberInput.parseDecimal(text), expected, reason: '"$text"');
      }
      expect(NumberInput.parseDecimal('9' * 400), isNull, reason: 'Infinity');
    });

    test('whole numbers', () {
      const parsed = <String?, int?>{
        null: null,
        '': null,
        '-': null,
        '.': null,
        '12': 12,
        '-3': -3,
        '12.0': 12,
        '12.00': 12,
        '12.': 12,
        '12.5': null,
        '.0': null,
        '١٢': 12,
        ' 7 ': 7,
        '1e3': null,
      };
      for (final MapEntry(key: text, value: expected) in parsed.entries) {
        expect(NumberInput.parseInteger(text), expected, reason: '"$text"');
      }
    });

    test('toAsciiDigits maps every script\'s digits, nothing else', () {
      expect(NumberInput.toAsciiDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(NumberInput.toAsciiDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(NumberInput.toAsciiDigits('০১২৩৪৫৬৭৮৯'), '0123456789');
      expect(NumberInput.toAsciiDigits('०१२३४५६७८९'), '0123456789');
      expect(NumberInput.toAsciiDigits('๐๑๒๓๔๕๖๗๘๙'), '0123456789');
      expect(NumberInput.toAsciiDigits('０１２３４５６７８９'), '0123456789');
      expect(NumberInput.toAsciiDigits('৳১,২৫০.৫০'), '৳1,250.50');
      const text = 'Micro Seller ১২ apples';
      expect(NumberInput.toAsciiDigits(text).length, text.length);
      expect(identical(NumberInput.toAsciiDigits('12.5'), '12.5'), isTrue);
    });
  });

  group('validators read what the fields type', () {
    test('amounts', () {
      expect(Validators.positiveNumber('1,5'), isNull);
      expect(Validators.positiveNumber('١٢٫٥'), isNull);
      expect(Validators.positiveNumber('12.50'), isNull);
      expect(Validators.positiveNumber(''), 'Amount is required');
      expect(Validators.positiveNumber('abc'), 'Please enter a valid number');
      expect(Validators.positiveNumber('.'), 'Please enter a valid number');
      expect(Validators.positiveNumber('-1'), 'Amount cannot be negative');
    });

    test('cost 1,5 against selling 10 is valid', () {
      expect(Validators.costPriceNotExceedingSelling('1,5', '10'), isNull);
      expect(Validators.costPriceNotExceedingSelling('١٫٥', '١٠'), isNull);
      expect(
        Validators.costPriceNotExceedingSelling('15', '10'),
        'Cost price exceeds selling price',
      );
      expect(Validators.costPriceNotExceedingSelling('15', ''), isNull);
    });

    test('whole numbers', () {
      expect(Validators.nonNegativeInt('12'), isNull);
      expect(Validators.nonNegativeInt('12.0'), isNull);
      expect(Validators.nonNegativeInt('١٢'), isNull);
      expect(
        Validators.nonNegativeInt('12.5'),
        'Please enter a valid whole number',
      );
      expect(Validators.nonNegativeInt('-1'), 'Quantity cannot be negative');
    });

    test('phone numbers in any script\'s digits', () {
      expect(Validators.phone('০১৭১২৩৪৫৬৭৮'), isNull);
      expect(Validators.phone('+৮৮০ ১৭১২-৩৪৫৬৭৮'), isNull);
      expect(Validators.phone('123'), 'Please enter a valid phone number');
      expect(
        Validators.phone('01712abc345'),
        'Phone number can only contain digits, +, -, spaces',
      );
    });
  });
}
