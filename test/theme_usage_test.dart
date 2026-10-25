import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the color-theme migration: widgets take the brand colors from the
/// active theme (`context.brand`, lib/core/theme/brand_colors.dart, or the
/// color scheme), never from the fixed Teal constants in `AppColors`, so
/// every color theme reaches every screen.
///
/// Only the brand constants are checked. The fixed colors (sidebar, status,
/// payment, tag, chart series, aging) stay in `AppColors` on purpose.

/// A use of one of `AppColors`' Teal brand constants.
final _brandConstant = RegExp(
  r'\bAppColors\.(primary|primaryDark|primaryLight|accent|dashboardGradient)\b',
);

/// White set as the foreground of a primary (or primaryDark / primaryLight)
/// background in one style or widget, in either order. The theme's own text
/// color, `onPrimary`, belongs there: a theme can put black text on its main
/// color.
final _whiteOnPrimary = [
  RegExp(
    r'backgroundColor:\s*[^,;]*\bprimary(Dark|Light)?\b[^,;]*,\s*'
    r'foregroundColor:\s*(const\s+)?Colors\.white',
  ),
  RegExp(
    r'foregroundColor:\s*(const\s+)?Colors\.white\w*,\s*'
    r'backgroundColor:\s*[^,;]*\bprimary(Dark|Light)?\b',
  ),
];

/// Where the brand constants may appear: the theme itself, the constants'
/// own file, and the first-launch splash, which stays Teal on purpose.
const _allowed = [
  'lib/core/theme/',
  'lib/core/constants/app_colors.dart',
  'lib/features/splash/',
];

/// Every Dart file in lib/ the guards apply to, as (path, text), by path.
List<(String, String)> _checkedSources() {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => (f.path.replaceAll(r'\', '/'), f))
          .where((e) => !_allowed.any(e.$1.startsWith))
          .toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (path, file) in files) (path, file.readAsStringSync())];
}

/// [text] without its line comments (`//` and `///` lines), with the line
/// numbers kept.
String _withoutCommentLines(String text) => text
    .split('\n')
    .map((line) => line.trimLeft().startsWith('//') ? '' : line)
    .join('\n');

/// Each match of [patterns] in [text], as `path:line: match`.
List<String> _hits(String path, String text, List<RegExp> patterns) {
  final code = _withoutCommentLines(text);
  return [
    for (final pattern in patterns)
      for (final m in pattern.allMatches(code))
        '$path:${'\n'.allMatches(code.substring(0, m.start)).length + 1}: '
            '${m[0]!.replaceAll(RegExp(r'\s+'), ' ')}',
  ];
}

void main() {
  setUpAll(() {
    expect(
      Directory('lib').existsSync(),
      isTrue,
      reason: 'run the tests from the package root',
    );
  });

  test('the guards find what they look for', () {
    // Not vacuous: the patterns match the code they guard against.
    final brand = File('lib/core/theme/brand_colors.dart').readAsStringSync();
    expect(
      _brandConstant.hasMatch(brand),
      isTrue,
      reason: 'BrandColors.teal is made of the AppColors constants',
    );
    const header = '''
    return SliverAppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
''';
    const button = '''
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white70,
        backgroundColor: theme.colorScheme.primary,
''';
    const themed = '''
      backgroundColor: brand.primary,
      foregroundColor: brand.onPrimary,
''';
    const fixed = '''
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
''';
    expect(_hits('a', header, _whiteOnPrimary), hasLength(1));
    expect(_hits('a', button, _whiteOnPrimary), hasLength(1));
    expect(_hits('a', themed, _whiteOnPrimary), isEmpty);
    expect(_hits('a', fixed, _whiteOnPrimary), isEmpty);
    expect(
      _hits('a', '  // was AppColors.primary\n', [_brandConstant]),
      isEmpty,
    );
  });

  test('lib/ takes the brand colors from the theme, not AppColors', () {
    final hits = [
      for (final (path, text) in _checkedSources())
        ..._hits(path, text, [_brandConstant]),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'Read the active color theme instead: context.brand.primary / '
          '.onPrimary / .primaryDark / .primaryLight / .accent / .gradient '
          '(lib/core/theme/brand_colors.dart), or the color scheme. Fixed '
          'chart series use AppColors.chartRevenue / chartProfit.\n'
          '${hits.join('\n')}',
    );
  });

  test('no white text is set on a primary background', () {
    final hits = [
      for (final (path, text) in _checkedSources())
        ..._hits(path, text, _whiteOnPrimary),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'A color theme may put black text on its main color: use '
          'context.brand.onPrimary or colorScheme.onPrimary.\n'
          '${hits.join('\n')}',
    );
  });
}
