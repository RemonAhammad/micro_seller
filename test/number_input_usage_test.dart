import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the shared number input (`lib/core/utils/number_input.dart`): an
/// amount, quantity or phone field takes what any keypad types (Arabic-Indic,
/// Persian, Bengali or full-width digits, a ',' or '٫' decimal mark) through
/// `DecimalInputFormatter`, `IntegerInputFormatter` or `PhoneInputFormatter`,
/// and its text is read with `NumberInput.parseDecimal` / `parseInteger`.
///
/// The raw tools it replaced misread that text: `digitsOnly` drops every
/// digit that isn't 0-9 and the decimal mark, a `^\d` pattern refuses
/// '1,5', and `double.parse('1,5')` throws (`tryParse` gives null, so the
/// amount silently became 0 or the button did nothing).

/// `FilteringTextInputFormatter.digitsOnly`, anywhere in lib/.
final _digitsOnly = RegExp(r'\bdigitsOnly\b');

/// A pattern for field text that starts with a digit class (`^\d`), in any
/// string literal form, and a `FilteringTextInputFormatter` that filters by
/// digits (`\d` or `0-9`): the hand-made amount filters NumberInput's
/// formatters replaced. Checked in lib/features, where the fields are.
final _digitPatterns = [
  RegExp(r'''RegExp\(\s*r?['"]\^\\{1,2}d'''),
  RegExp(
    r'''FilteringTextInputFormatter\s*\.\s*(allow|deny)\s*\(\s*RegExp\(\s*'''
    r'''r?['"][^'"]*(\\{1,2}d|0-9)''',
  ),
];

/// A raw `double` / `int` / `num` parse, anywhere in lib/ but [_parseAllowed].
final _rawParse = RegExp(r'\b(double|int|num)\s*\.\s*(tryParse|parse)\s*\(');

/// Where a raw parse reads text no seller typed into a field, with the line
/// it must be on (null: anywhere in the file).
final _parseAllowed = <String, RegExp?>{
  // The parsers themselves, after converting the text to 0-9 and '.'.
  'lib/core/utils/number_input.dart': null,
  // Route ids in paths the app builds itself.
  'lib/core/router/app_router.dart': RegExp(r'pathParameters\['),
  // Cells of an imported CSV file.
  'lib/data/services/csv_import_service.dart': null,
  // Version numbers in GitHub release tags.
  'lib/data/services/release_update_service.dart': null,
  // A hex color code, once it matched [0-9a-fA-F]{6}.
  'lib/shared/widgets/color_picker.dart': RegExp(r'radix:\s*16'),
  // A PIN from the app's own keypad, which types 0-9 (a debug assert).
  'lib/data/services/auth_gate_service.dart': RegExp(r'\bassert\('),
};

/// Every hand-written Dart file under [root], as (path, text), by path.
List<(String, String)> _sources(String root) {
  final files =
      Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) =>
                !f.path.endsWith('.g.dart') &&
                !f.path.endsWith('.freezed.dart'),
          )
          .map((f) => (f.path.replaceAll(r'\', '/'), f))
          .toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (path, file) in files) (path, file.readAsStringSync())];
}

/// The first match of [patterns] on each line of [text] that isn't a
/// comment, as (line number, line, match), by line.
List<(int, String, String)> _matches(String text, List<RegExp> patterns) {
  final lines = text.split('\n');
  final code = [
    for (final line in lines) line.trimLeft().startsWith('//') ? '' : line,
  ].join('\n');
  final found = <int, (int, String, String)>{};
  for (final pattern in patterns) {
    for (final m in pattern.allMatches(code)) {
      final line = '\n'.allMatches(code.substring(0, m.start)).length;
      found.putIfAbsent(line, () => (line + 1, lines[line], m[0]!));
    }
  }
  return [for (final line in found.keys.toList()..sort()) found[line]!];
}

/// Each match of [patterns] in [text], as `path:line: match`, leaving out
/// the lines [allowed] lets through.
List<String> _hits(
  String path,
  String text,
  List<RegExp> patterns, {
  Map<String, RegExp?> allowed = const {},
}) => [
  for (final (number, line, match) in _matches(text, patterns))
    if (!(allowed.containsKey(path) &&
        (allowed[path] == null || allowed[path]!.hasMatch(line))))
      '$path:$number: ${match.replaceAll(RegExp(r'\s+'), ' ')}',
];

void main() {
  setUpAll(() {
    expect(
      Directory('lib').existsSync(),
      isTrue,
      reason: 'run the tests from the package root',
    );
  });

  test('the guards find what they look for', () {
    // Not vacuous: the patterns match the code they guard against, and
    // leave alone what replaced it.
    const old = r'''
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
        final ok = RegExp('^\\d{3,}\$').hasMatch(query);
        final amount = double.tryParse(_amount.text) ?? 0;
        final qty = int.parse(_qty.text.trim());
        final rate = num.tryParse(value);
''';
    const current = r'''
        inputFormatters: const [DecimalInputFormatter.money()],
        inputFormatters: const [IntegerInputFormatter()],
        inputFormatters: const [PhoneInputFormatter()],
        final amount = NumberInput.parseDecimal(_amount.text) ?? 0;
        final qty = NumberInput.parseInteger(_qty.text);
        final when = DateTime.tryParse(value);
        final version = AppVersion.tryParse(tag);
        final big = BigInt.parse(value);
        final isPhone = RegExp(r'^[0-9]{3,}$').hasMatch(digits);
        // double.tryParse read none of them.
''';
    expect(_hits('a', old, [_digitsOnly]), hasLength(1));
    expect(_hits('a', old, _digitPatterns), hasLength(4)); // one per line
    expect(_hits('a', old, [_rawParse]), hasLength(3));
    for (final patterns in [
      [_digitsOnly],
      _digitPatterns,
      [_rawParse],
    ]) {
      expect(_hits('a', current, patterns), isEmpty);
    }
    // The allow-list lets through only its own lines.
    const router = '''
          productId: int.parse(s.pathParameters['id']!),
          count: int.parse(text),
''';
    expect(
      _hits('lib/core/router/app_router.dart', router, [
        _rawParse,
      ], allowed: _parseAllowed),
      ['lib/core/router/app_router.dart:2: int.parse('],
    );
    expect(
      _matches(File('lib/core/utils/number_input.dart').readAsStringSync(), [
        _rawParse,
      ]),
      isNotEmpty,
      reason: 'NumberInput parses with double.tryParse / int.tryParse',
    );
  });

  test('every allow-listed file exists', () {
    for (final path in _parseAllowed.keys) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('no field filters its text with digitsOnly', () {
    final hits = [
      for (final (path, text) in _sources('lib'))
        ..._hits(path, text, [_digitsOnly]),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'digitsOnly drops Arabic-Indic, Bengali and full-width digits. Use '
          'IntegerInputFormatter() (lib/core/utils/number_input.dart).\n'
          '${hits.join('\n')}',
    );
  });

  test('no field in lib/features filters by a digit pattern', () {
    final hits = [
      for (final (path, text) in _sources('lib/features'))
        ..._hits(path, text, _digitPatterns),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'A digit pattern refuses what other keypads type. Use '
          'DecimalInputFormatter.money() / .percent(), IntegerInputFormatter() '
          'or PhoneInputFormatter() (lib/core/utils/number_input.dart), and '
          'NumberInput.toAsciiDigits before matching typed text.\n'
          '${hits.join('\n')}',
    );
  });

  test('field text is read with NumberInput, not a raw parse', () {
    final hits = [
      for (final (path, text) in _sources('lib'))
        ..._hits(path, text, [_rawParse], allowed: _parseAllowed),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'double.parse / int.parse misread what other keypads type (1,5; '
          'Bengali digits). Read field text with NumberInput.parseDecimal / '
          'parseInteger (lib/core/utils/number_input.dart). Text no seller '
          'typed (a route id, a file format) goes in _parseAllowed, with the '
          'reason.\n'
          '${hits.join('\n')}',
    );
  });
}
