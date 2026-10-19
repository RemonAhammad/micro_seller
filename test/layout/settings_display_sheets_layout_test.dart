import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/features/settings/presentation/widgets/display_size_sheets.dart';
import 'package:micro_seller/features/settings/providers/display_scale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';

// Layout of Settings → Display size and Text size under the sizes they set:
// both sheets lay out cleanly from the narrowest layout (320 dp) to a large
// phone font (150%, and Android 14's largest, which grows body text past
// it), on a short phone, in every language and with a long currency symbol,
// and look as before at 100% text on a phone.

const _eps = 0.01;

/// A font size step of Android 14, which scales text nonlinearly: small text
/// grows more than large text (AOSP's FontScaleConverter points, linear in
/// between). The app follows it unless a custom Text size is set.
class _AndroidFontSize extends TextScaler {
  const _AndroidFontSize(this.textScaleFactor, this._points);

  /// The step the phone's setting shows.
  @override
  final double textScaleFactor;

  /// (sp, dp): a font size and the size the phone draws it at.
  final List<(double, double)> _points;

  @override
  double scale(double fontSize) {
    for (var i = 1; i < _points.length; i++) {
      final (sp, dp) = _points[i];
      if (fontSize <= sp) {
        final (sp0, dp0) = _points[i - 1];
        return dp0 + (fontSize - sp0) / (sp - sp0) * (dp - dp0);
      }
    }
    return fontSize;
  }
}

/// Android 14's 150% step: 14 sp body text at 22 dp (157%), past the linear
/// sweep's 150%.
const _android150 = _AndroidFontSize(1.5, [
  (0, 0),
  (8, 12),
  (10, 15),
  (12, 18),
  (14, 22),
  (18, 24),
  (20, 26),
  (24, 28),
  (30, 30),
  (100, 100),
]);

/// Android 14's largest step, 200%: 14 sp body text at 26 dp (186%).
const _android200 = _AndroidFontSize(2, [
  (0, 0),
  (8, 16),
  (10, 20),
  (12, 24),
  (14, 26),
  (18, 30),
  (20, 34),
  (24, 36),
  (30, 38),
  (100, 100),
]);

/// Every language the app ships.
final _langs = [
  for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
];

/// Languages in Latin script, which the test draws in Roboto's real widths:
/// where a broken word is a layout fault and not the test font's.
const _latin = {'en', 'es', 'fr', 'pt', 'tr', 'id', 'vi', 'ms'};

/// The app's light theme as a phone draws it. The theme's button styles name
/// no font family: a phone draws them in its system font (Roboto on
/// Android), a test in its square test font, far wider.
final ThemeData _phoneTheme = () {
  final theme = AppTheme.lightTheme;
  ButtonStyle? roboto(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) =>
          style.textStyle?.resolve(states)?.copyWith(fontFamily: 'Roboto'),
    ),
  );
  return theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: roboto(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: roboto(theme.outlinedButtonTheme.style),
    ),
  );
}();

/// Pumps an empty screen the way the app shows one on a phone (in a shell
/// branch's Navigator beside the sidebar rail, where the sheets open), with
/// [lang] strings and [textScaler] over the whole app. Returns a context
/// inside the branch.
Future<BuildContext> _pumpBranch(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
  String lang = 'en',
}) async {
  late BuildContext branch;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: _phoneTheme,
        locale: Locale(lang),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Row(
          children: [
            const SizedBox(width: kRailWidth),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) {
                    branch = context;
                    return const Scaffold();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  // The app's strings and the saved settings load asynchronously.
  await tester.pump();
  await tester.pump();
  return branch;
}

/// Runs [body] at every layout width × text scale × [heights] × language,
/// clearing the screen after each.
Future<void> _forEachLayout(
  WidgetTester tester,
  Future<void> Function(
    String where,
    double width,
    double textScale,
    String lang,
  )
  body, {
  List<double> heights = const [800, 600],
}) async {
  addTearDown(tester.view.reset);
  for (final lang in _langs) {
    for (final height in heights) {
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          SharedPreferences.setMockInitialValues({});
          DisplayScale.debugResetPrimed();
          setLayoutScreen(tester, width, height: height);
          await body(
            '$lang, ${width.toInt()}×${height.toInt()} dp at ${t}x',
            width,
            t,
            lang,
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  }
}

Finder get _sheet => find.byType(BottomSheet);
Finder _inSheet(Finder finder) => find.descendant(of: _sheet, matching: finder);

/// No text in the sheet is cut off: not too short for its lines, and not
/// narrower than a glyph that won't wrap.
void _expectNothingCut(WidgetTester tester, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(
    _inSheet(find.byType(RichText)),
  );
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    expect(
      p.size.height,
      greaterThanOrEqualTo(p.textSize.height - _eps),
      reason: '$where: "$text" cut off at the bottom',
    );
    expect(
      p.size.width,
      greaterThanOrEqualTo(p.textSize.width - _eps),
      reason: '$where: "$text" cut off at the side',
    );
  }
}

/// Every line break in [finder]'s text falls between words: a box too narrow
/// for a word breaks it across lines without reporting any overflow.
void _expectWholeWords(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    double? lastTop;
    for (var i = 0; i < text.length; i++) {
      final top = p.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dy;
      if (lastTop != null && top > lastTop + 0.5) {
        expect(
          text[i - 1].trim().isEmpty || text[i].trim().isEmpty,
          isTrue,
          reason:
              '$where: "$text" broken inside a word at '
              '"${text.substring(0, i)}|${text.substring(i)}"',
        );
      }
      lastTop = top;
    }
  }
}

/// Reset and Done: side by side as before, or stacked, never with a word of
/// either broken.
void _checkButtons(
  WidgetTester tester,
  String where,
  double width,
  double textScale,
  String lang,
) {
  final s = AppStrings.of(tester.element(_sheet));
  final reset = _inSheet(find.widgetWithText(OutlinedButton, s.resetToDefault));
  final done = _inSheet(find.widgetWithText(FilledButton, s.done));
  if (_latin.contains(lang)) {
    _expectWholeWords(tester, _inSheet(find.text(s.resetToDefault)), where);
    _expectWholeWords(tester, _inSheet(find.text(s.done)), where);
  }
  if (lang == 'en' && textScale == 1 && width >= 360) {
    requireRoboto();
    // As the Row of two Expanded buttons laid them out.
    final a = tester.getRect(reset), b = tester.getRect(done);
    expect(a.center.dy, closeTo(b.center.dy, _eps), reason: where);
    expect(a.width, closeTo(b.width, _eps), reason: where);
    expect(b.left - a.right, closeTo(12, _eps), reason: where);
  }
}

void main() {
  setUpAll(() async {
    await loadRoboto();
    // The longest symbol the app offers, in the samples' amounts.
    CurrencyFormatter.setSymbol('KSh');
  });
  tearDown(DisplayScale.debugResetPrimed);

  testWidgets('the Display size sheet lays out at every size', (tester) async {
    requireRoboto();
    await _forEachLayout(tester, (where, width, t, lang) async {
      final branch = await _pumpBranch(
        tester,
        textScaler: TextScaler.linear(t),
        lang: lang,
      );
      showDisplaySizeSheet(branch);
      await tester.pumpAndSettle();
      expectCleanLayout(tester, where);
      _expectNothingCut(tester, where);
      _checkButtons(tester, where, width, t, lang);
    });
  });

  testWidgets('the Text size sheet lays out at every size', (tester) async {
    requireRoboto();
    await _forEachLayout(tester, (where, width, t, lang) async {
      final branch = await _pumpBranch(
        tester,
        textScaler: TextScaler.linear(t),
        lang: lang,
      );
      showTextSizeSheet(branch);
      await tester.pumpAndSettle();
      final s = AppStrings.of(branch);
      expectCleanLayout(tester, where);
      _expectNothingCut(tester, where);
      _checkButtons(tester, where, width, t, lang);
      // The sample's label (its amount beside it took all but a letter's
      // width at 150%) never has a word broken: the amount goes under it.
      final label = _inSheet(find.text(s.totalReceivable));
      final amount = _inSheet(find.text(CurrencyFormatter.format(12400)));
      expect(label, findsNWidgets(2), reason: where);
      if (_latin.contains(lang)) _expectWholeWords(tester, label, where);
      if (lang == 'en' && t == 1 && width >= 360) {
        // Beside the label as before.
        for (var i = 0; i < 2; i++) {
          final l = tester.getRect(label.at(i));
          final a = tester.getRect(amount.at(i));
          expect(a.left, greaterThan(l.right), reason: where);
          expect(a.center.dy, closeTo(l.center.dy, _eps), reason: where);
        }
      }
    });
  });

  testWidgets("both sheets lay out at Android 14's larger font sizes", (
    tester,
  ) async {
    requireRoboto();
    addTearDown(tester.view.reset);
    for (final lang in _langs) {
      for (final width in kLayoutWidths) {
        for (final phone in const [_android150, _android200]) {
          for (final (sheet, open) in [
            ('Display size', showDisplaySizeSheet),
            ('Text size', showTextSizeSheet),
          ]) {
            SharedPreferences.setMockInitialValues({});
            DisplayScale.debugResetPrimed();
            setLayoutScreen(tester, width, height: 600);
            final branch = await _pumpBranch(
              tester,
              textScaler: phone,
              lang: lang,
            );
            open(branch);
            await tester.pumpAndSettle();
            final where =
                '$sheet, $lang, ${width.toInt()} dp, Android '
                '${(phone.textScaleFactor * 100).toInt()}%';
            expectCleanLayout(tester, where);
            _expectNothingCut(tester, where);
            // At 200% one word is wider than a whole-width button (Spanish
            // "predeterminado" in a 320 dp layout), so only 150% keeps every
            // word whole.
            if (phone == _android150) {
              _checkButtons(tester, where, width, phone.textScaleFactor, lang);
            }
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    }
  });

  testWidgets('both sheets lay out with Bold text on', (tester) async {
    requireRoboto();
    addTearDown(tester.view.reset);
    // The phone's Bold text setting draws every Text heavier, so wider.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    for (final lang in _langs) {
      for (final (sheet, open) in [
        ('Display size', showDisplaySizeSheet),
        ('Text size', showTextSizeSheet),
      ]) {
        SharedPreferences.setMockInitialValues({});
        DisplayScale.debugResetPrimed();
        setLayoutScreen(tester, 320, height: 600);
        final branch = await _pumpBranch(
          tester,
          textScaler: const TextScaler.linear(1.3),
          lang: lang,
        );
        open(branch);
        await tester.pumpAndSettle();
        final where = '$sheet, $lang, 320 dp at 1.3x, bold text';
        expectCleanLayout(tester, where);
        _expectNothingCut(tester, where);
        _checkButtons(tester, where, 320, 1.3, lang);
        // The sample's label never has a word broken beside its amount.
        if (sheet == 'Text size' && _latin.contains(lang)) {
          final label = AppStrings.of(branch).totalReceivable;
          _expectWholeWords(tester, _inSheet(find.text(label)), where);
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets("the Text size sheet's icon keeps its coded size", (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    setLayoutScreen(tester, 411);
    final branch = await _pumpBranch(tester);
    showTextSizeSheet(branch);
    await tester.pumpAndSettle();
    final box = _inSheet(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints ==
                const BoxConstraints.tightFor(width: 40, height: 40),
      ),
    );
    final icon = find.descendant(of: box, matching: find.byType(ThinIcon));
    expect(tester.getSize(box), const Size(40, 40));
    // The box's tight size used to stretch it to 40.
    expect(tester.getSize(icon), const Size(20, 20));
    expect(tester.getCenter(icon), tester.getCenter(box));
  });
}
