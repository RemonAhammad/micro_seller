// The app's font in the theme and in the PDFs: wherever the theme names a
// font it names appFontFamily, the bundled Roboto (RobotoStatic) on iOS and
// Android's system Roboto elsewhere. That includes the app bar title and the
// button text styles, which replace the text theme's (naming none, iOS drew
// them in San Francisco). iOS and Android each get their own cached theme;
// the family iOS names is bundled, every font file pubspec.yaml lists exists,
// and no bundled family is named Roboto. A screen measures, and a PDF page
// draws, the same on iOS as on Android.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/theme/app_color_theme.dart';
import 'package:micro_seller/core/theme/app_fonts.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/data/services/widget_capture.dart';

import 'support/layout_harness.dart';

final _mobile = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});

String _expectedFamily(TargetPlatform platform) =>
    platform == TargetPlatform.iOS ? 'RobotoStatic' : 'Roboto';

/// Runs [body] with the platform overridden, and restores it.
T _on<T>(TargetPlatform platform, T Function() body) {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Every text style [theme] names, by where it is.
Map<String, TextStyle?> _styles(ThemeData theme) {
  TextStyle? button(ButtonStyle? style) => style?.textStyle?.resolve({});
  Map<String, TextStyle?> texts(String name, TextTheme t) => {
    '$name.displayLarge': t.displayLarge,
    '$name.displayMedium': t.displayMedium,
    '$name.displaySmall': t.displaySmall,
    '$name.headlineLarge': t.headlineLarge,
    '$name.headlineMedium': t.headlineMedium,
    '$name.headlineSmall': t.headlineSmall,
    '$name.titleLarge': t.titleLarge,
    '$name.titleMedium': t.titleMedium,
    '$name.titleSmall': t.titleSmall,
    '$name.bodyLarge': t.bodyLarge,
    '$name.bodyMedium': t.bodyMedium,
    '$name.bodySmall': t.bodySmall,
    '$name.labelLarge': t.labelLarge,
    '$name.labelMedium': t.labelMedium,
    '$name.labelSmall': t.labelSmall,
  };
  return {
    ...texts('textTheme', theme.textTheme),
    ...texts('primaryTextTheme', theme.primaryTextTheme),
    'appBar.title': theme.appBarTheme.titleTextStyle,
    'elevated': button(theme.elevatedButtonTheme.style),
    'filled': button(theme.filledButtonTheme.style),
    'outlined': button(theme.outlinedButtonTheme.style),
  };
}

/// The themes the app builds: Teal and a custom theme in both modes, and
/// Phone colors' system schemes.
List<(String, ThemeData)> _themes() {
  const custom = AppColorTheme(
    id: 'custom-1',
    name: 'Mine',
    seed: 0xFF6A1B9A,
    onPrimary: OnColor.white,
  );
  final system = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
  final systemDark = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6750A4),
    brightness: Brightness.dark,
  );
  return [
    ('teal light', AppTheme.lightTheme),
    ('teal dark', AppTheme.darkTheme),
    ('custom light', AppTheme.build(Brightness.light, custom)),
    ('custom dark', AppTheme.build(Brightness.dark, custom)),
    (
      'phone light',
      AppTheme.build(Brightness.light, kPhoneColorTheme, dynamicScheme: system),
    ),
    (
      'phone dark',
      AppTheme.build(
        Brightness.dark,
        kPhoneColorTheme,
        dynamicScheme: systemDark,
      ),
    ),
  ];
}

/// A screen with an app bar title, body text and every kind of button.
Widget _screen(ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(
    appBar: AppBar(title: const Text('Orders')),
    body: Column(
      children: [
        const Text('Mohammad Abdur Rahman · 1,234,567.89'),
        ElevatedButton(onPressed: () {}, child: const Text('Save order')),
        FilledButton(onPressed: () {}, child: const Text('Pay in full')),
        OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
        TextButton(onPressed: () {}, child: const Text('Skip for now')),
      ],
    ),
  ),
);

const _screenTexts = [
  'Orders',
  'Mohammad Abdur Rahman · 1,234,567.89',
  'Save order',
  'Pay in full',
  'Cancel',
  'Skip for now',
];

/// A document page built as the PDF services build theirs: its own
/// DefaultTextStyle, its text on a Material.
Widget _page() => MediaQuery(
  data: const MediaQueryData(size: Size(320, 120)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: DefaultTextStyle(
      style: const TextStyle(color: Colors.black, fontSize: 12),
      child: Material(
        color: Colors.white,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice INV-0042',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text('Total 1,250.00 · Paid 1,000.00'),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('the theme', () {
    test('names RobotoStatic on iOS and Roboto elsewhere, wherever it names '
        'a font', () {
      for (final platform in TargetPlatform.values) {
        _on(platform, () {
          final family = _expectedFamily(platform);
          expect(appFontFamily, family);
          for (final (name, theme) in _themes()) {
            final styles = _styles(theme);
            // The title and the buttons the theme sets are named too.
            expect(styles['appBar.title'], isNotNull);
            expect(styles['elevated'], isNotNull);
            styles.forEach((where, style) {
              if (style == null) return;
              expect(
                style.fontFamily,
                family,
                reason: '${platform.name} $name $where',
              );
            });
          }
        });
      }
    });

    test('iOS and Android each get their own cached theme', () {
      final android = _on(TargetPlatform.android, () => AppTheme.lightTheme);
      final iOS = _on(TargetPlatform.iOS, () => AppTheme.lightTheme);
      expect(identical(android, iOS), isFalse);
      expect(android.textTheme.bodyMedium!.fontFamily, 'Roboto');
      expect(iOS.textTheme.bodyMedium!.fontFamily, 'RobotoStatic');
      expect(iOS.platform, TargetPlatform.iOS);
      // And each is still memoized.
      expect(
        identical(
          _on(TargetPlatform.android, () => AppTheme.lightTheme),
          android,
        ),
        isTrue,
      );
      expect(
        identical(_on(TargetPlatform.iOS, () => AppTheme.lightTheme), iOS),
        isTrue,
      );
    });

    test('the family iOS names is bundled; every font file pubspec.yaml '
        'lists exists; no bundled family is named Roboto', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final families = RegExp(
        r'^\s*-\s*family:\s*(\S+)\s*$',
        multiLine: true,
      ).allMatches(pubspec).map((m) => m[1]).toList();
      expect(families, contains(_expectedFamily(TargetPlatform.iOS)));
      // A bundled family named Roboto would replace Android's system Roboto
      // (and lose its real 600 and 800 weights).
      expect(families, isNot(contains(kSystemRobotoFamily)));
      final assets = RegExp(
        r'^\s*-\s*asset:\s*(\S+)\s*$',
        multiLine: true,
      ).allMatches(pubspec).map((m) => m[1]!).toList();
      expect(assets, isNotEmpty);
      for (final asset in assets) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    });
  });

  group('drawn', () {
    setUpAll(loadRoboto);

    testWidgets('the body text, the app bar title and every button', (
      tester,
    ) async {
      final family = _expectedFamily(defaultTargetPlatform);
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(_screen(theme));
        for (final text in _screenTexts) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(text),
          );
          expect(paragraph.text.style?.fontFamily, family, reason: text);
        }
      }
    }, variant: _mobile);

    testWidgets('a screen measures the same on iOS as on Android', (
      tester,
    ) async {
      requireRoboto();
      Future<List<Size>> measure(TargetPlatform platform) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await tester.pumpWidget(_screen(AppTheme.lightTheme));
          return [
            for (final text in _screenTexts) tester.getSize(find.text(text)),
          ];
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }

      final android = await measure(TargetPlatform.android);
      await tester.pumpWidget(const SizedBox());
      final iOS = await measure(TargetPlatform.iOS);
      expect(iOS, android);
      // Real glyphs, not the test font's 1 em squares.
      expect(android[1].width, lessThan(_screenTexts[1].length * 14 * 0.7));
    });
  });

  group('PDF capture', () {
    setUpAll(loadRoboto);

    testWidgets("a page's text draws in the app font, under the page's own "
        'DefaultTextStyle and Material', (tester) async {
      await tester.pumpWidget(captureScope(_page()));
      for (final text in [
        'Invoice INV-0042',
        'Total 1,250.00 · Paid 1,000.00',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(
          paragraph.text.style?.fontFamily,
          _expectedFamily(defaultTargetPlatform),
          reason: text,
        );
      }
      // Text outside a Material too.
      await tester.pumpWidget(captureScope(const Text('Thanks!')));
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Thanks!'))
            .text
            .style
            ?.fontFamily,
        _expectedFamily(defaultTargetPlatform),
      );
    }, variant: _mobile);

    testWidgets(
      "the capture's theme is Flutter's fallback but for the font",
      (tester) async {
        final theme = captureTheme();
        final fallback = ThemeData.fallback();
        expect(identical(captureTheme(), theme), isTrue);
        expect(theme.colorScheme, fallback.colorScheme);
        expect(theme.brightness, fallback.brightness);
        expect(theme.iconTheme, const IconThemeData.fallback());
        final mine = theme.textTheme.bodyMedium!;
        final theirs = fallback.textTheme.bodyMedium!;
        expect(mine.fontFamily, _expectedFamily(defaultTargetPlatform));
        expect(
          mine.copyWith(fontFamily: 'x', debugLabel: ''),
          theirs.copyWith(fontFamily: 'x', debugLabel: ''),
        );
      },
      variant: _mobile,
    );

    testWidgets('a page captures to the same pixels on iOS as on Android', (
      tester,
    ) async {
      requireRoboto();
      Future<Uint8List> capture(TargetPlatform platform) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          return (await tester.runAsync(
            () => captureWidgetPng(
              _page(),
              targetSize: const Size(320, 120),
              delay: Duration.zero,
            ),
          ))!;
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }

      final android = await capture(TargetPlatform.android);
      final iOS = await capture(TargetPlatform.iOS);
      expect(iOS, android);
    });
  });
}
