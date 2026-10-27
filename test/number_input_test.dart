// Typing and pasting amounts, whole numbers and phone numbers on any phone's
// keyboard. A number pad types its region's digits and decimal separator
// (an iPhone set to France types 12,50, one set to an Arabic region ١٢٫٥٠),
// and a paste can be 1,250.00, 1.250,00 or ৳১,২৫০. The formatters keep a
// field's text canonical (ASCII digits, '.' as the point) and the parsers
// read it back, so every field, validator and save reads the same amount.
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

const _money = DecimalInputFormatter.money();
const _signedMoney = DecimalInputFormatter.money(signed: true);
const _percent = DecimalInputFormatter.percent();
const _integer = IntegerInputFormatter();
const _phone = PhoneInputFormatter();

void main() {
  tearDown(() => CurrencyFormatter.setSymbol('\$'));

  group('typing', () {
    test('any script\'s digits and decimal separator, one key at a time', () {
      const typed = {
        '12,50': '12.50',
        '12٫5': '12.5',
        '١٢٫٥': '12.5',
        '١٢٫٥٠': '12.50',
        '۱۲۳': '123',
        '১২৩.৫': '123.5',
        '१२': '12',
        '๑๒': '12',
        '１２': '12',
        '１２．５': '12.5',
        '１２，５': '12.5',
      };
      for (final MapEntry(key: keys, value: expected) in typed.entries) {
        final value = _type(_money, keys);
        expect(value.text, expected, reason: keys);
        expect(
          value.selection,
          TextSelection.collapsed(offset: expected.length),
          reason: '$keys: the caret stays after what was typed',
        );
      }
    });

    test('a second point is ignored', () {
      expect(_type(_money, '1.2.3').text, '1.23');
      expect(_type(_money, '1,2,3').text, '1.23');
      expect(_type(_money, '1.2٫3').text, '1.23');
    });

    test('a point typed first becomes 0.', () {
      final point = _type(_money, '.');
      expect(point.text, '0.');
      expect(point.selection, const TextSelection.collapsed(offset: 2));
      expect(_type(_money, ',5').text, '0.5');
      expect(_type(_money, '٫٥').text, '0.5');
      // Before digits already there.
      expect(_enter(_money, _at('5', 0), '.').text, '0.5');
      // After a minus.
      expect(_type(_signedMoney, '-.5').text, '-0.5');
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

    test('text an input method rewrote is read as a paste', () {
      // Not an edit at the caret: the whole text changed.
      final value = _money.formatEditUpdate(
        _at('12', 0),
        const TextEditingValue(
          text: '١٢٣٫٥',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(value.text, '123.5');
      expect(value.selection, const TextSelection.collapsed(offset: 5));
    });
  });

  group('pasting', () {
    // Pasted → (money, percent, whole number); null is refused.
    const table = <String, (String?, String?, String?)>{
      '1,250.00': ('1250.00', '1250.00', '1250'),
      '1.250,00': ('1250.00', '1250.00', '1250'),
      '1,5': ('1.5', '1.5', null),
      '12,50': ('12.50', '12.50', null),
      '1,250': ('1250', '1.25', '1250'),
      '25.000': ('25000', '25.00', '25000'),
      '1.250.000': ('1250000', '1250000', '1250000'),
      '0.125': ('0.13', '0.13', null),
      '৳১,২৫০': ('1250', '1.25', '1250'),
      '٢٬٥٠٠٫٧٥': ('2500.75', '2500.75', null),
      'Rp 25.000': ('25000', '25.00', '25000'),
      'abc': (null, null, null),
      '12 apples 3': (null, null, null),
    };

    void check(String field, TextInputFormatter formatter, int column) {
      for (final MapEntry(key: pasted, value: row) in table.entries) {
        final expected = [row.$1, row.$2, row.$3][column];

        // Over the whole text.
        final all = _selected('7');
        final replaced = _enter(formatter, all, pasted);
        if (expected == null) {
          expect(replaced, all, reason: '$field: "$pasted" refused');
        } else {
          expect(replaced.text, expected, reason: '$field: "$pasted"');
          expect(
            replaced.selection,
            TextSelection.collapsed(offset: expected.length),
            reason: '$field: "$pasted" caret',
          );
        }

        // At the caret, after a 7 already typed.
        final seven = _at('7');
        final inserted = _enter(formatter, seven, pasted);
        if (expected == null) {
          expect(inserted, seven, reason: '$field: "$pasted" refused');
        } else {
          expect(inserted.text, '7$expected', reason: '$field: 7|"$pasted"');
          expect(
            inserted.selection,
            TextSelection.collapsed(offset: 1 + expected.length),
            reason: '$field: 7|"$pasted" caret',
          );
        }
      }
    }

    test('into a money field', () => check('money', _money, 0));
    test('into a percent field', () => check('percent', _percent, 1));
    test('into a whole-number field', () => check('integer', _integer, 2));

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

    test('a negative number keeps its sign only in a signed field', () {
      expect(_enter(_signedMoney, _selected('7'), '-12.50').text, '-12.50');
      expect(
        _enter(_signedMoney, _selected('7'), '(1,250.00)').text,
        '-1250.00',
      );
      expect(_enter(_money, _selected('7'), '-12.50').text, '12.50');
      expect(_enter(_money, _selected('7'), '(1,250.00)').text, '1250.00');
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
      // Without the thousands rule (a percentage): binary floating point
      // would make these 1.00 and -2.67.
      expect(NumberInput.normalize('1.005', maxDecimals: 2), '1.01');
      expect(
        NumberInput.normalize('-2.675', signed: true, maxDecimals: 2),
        '-2.68',
      );
      // In a money field one '.' with 3 digits after 1 to 3 digits groups
      // thousands, as in 25.000.
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
      expect(money('  12.5\n'), '12.5');
    });

    test('grouping: spaces, apostrophes, ٬ and repeated separators', () {
      expect(money('1 250,50'), '1250.50');
      expect(money('1 250,50'), '1250.50');
      expect(money('1 250,50'), '1250.50');
      expect(money("1'250.50"), '1250.50');
      expect(money('1,25,000'), '125000');
      expect(money('١٬٢٥٠٫٥'), '1250.5');
      expect(NumberInput.normalize('12 345,678', maxDecimals: 2), '12345.68');
    });

    test('a point right before the first digit', () {
      expect(money('.5'), '.5');
      expect(money('\$.50'), '.50');
      expect(money('-.5', signed: true), '-.5');
      expect(money('.995'), '1.00');
      expect(NumberInput.normalize('.5', integer: true), isNull);
    });

    test('the thousands rule needs 1 to 3 digits before, not starting 0', () {
      expect(money('1,250'), '1250');
      expect(money('999.999'), '999999');
      expect(money('1250.000'), '1250.00');
      expect(money('0,250'), '0.25');
      // Off without grouping, or with 3 decimals.
      expect(NumberInput.normalize('1,250', maxDecimals: 2), '1.25');
      expect(
        NumberInput.normalize('1,250', maxDecimals: 3, grouping: true),
        '1.250',
      );
      expect(NumberInput.normalize('1,250', grouping: true), '1.250');
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
      expect(whole('-3'), '3');
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
      expect(_type(_money, '1,2505').text, '1.250');
      expect(_enter(_money, _selected('7'), '0.1255').text, '0.126');
      // 1,250 and 25.000 are amounts with fils here, not thousands.
      expect(_enter(_money, _selected('7'), '1,250').text, '1.250');
      expect(_enter(_money, _selected('7'), '25.000').text, '25.000');
      expect(_enter(_money, _selected('7'), '1,250.500').text, '1250.500');
    });
  });

  group('whole numbers', () {
    test('typing', () {
      expect(_type(_integer, '١٢').text, '12');
      expect(_type(_integer, '12.5').text, '125');
      expect(_type(_integer, '1,000').text, '1000');
      expect(_type(_integer, '-3').text, '3');
      expect(_type(const IntegerInputFormatter(signed: true), '-3').text, '-3');
    });

    test('pasting', () {
      expect(_enter(_integer, _selected('7'), '12.0').text, '12');
      expect(_enter(_integer, _selected('7'), '১২').text, '12');
      expect(_enter(_integer, _selected('7'), '12.5').text, '7');
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
      expect(_enter(_phone, _selected('7'), '+1 555‑123').text, '+1 555-123');
      // What is dropped before the caret moves it back.
      final dropped = _enter(_phone, _at('9', 0), 'a1b2');
      expect(dropped.text, '129');
      expect(dropped.selection, const TextSelection.collapsed(offset: 2));
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
        '1 250.5': 1250.5,
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
