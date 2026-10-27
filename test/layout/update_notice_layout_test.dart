import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/dashboard/presentation/dashboard_screen.dart';
import 'package:micro_seller/features/updates/presentation/update_notice.dart';
import 'package:micro_seller/features/updates/providers/update_notice_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/layout_harness.dart';
import 'dashboard_reports_data.dart';

// Layout of the update notice (the Dashboard's banner and Settings → Check
// for updates' dialog) under the Display size / Text size settings: clean,
// every text whole and no word broken, from the narrowest layout (320 dp) to
// a large phone font (150%), in English, Arabic (right to left) and Bengali,
// with the iPhone's how-to and Android's.

const _eps = 0.01;

/// Languages: a Latin script measured in Roboto's real widths, right to
/// left, and a script the test font draws far wider.
const _langs = ['en', 'ar', 'bn'];

/// Short windows the dialog must still fit, scrolling: a phone, and the
/// narrowest layout zoomed in on a short one.
const _dialogHeights = [800.0, 480.0];

final _update = AvailableUpdate(
  tag: 'v1.0.12',
  url: Uri.parse(
    'https://github.com/RemonAhammad/micro_seller/releases/tag/v1.0.12',
  ),
);

/// The notice, without asking GitHub.
class _Notice extends UpdateNotice {
  @override
  Future<AvailableUpdate?> build() async => _update;
}

/// Every line break in [finder]'s text falls between words, or after a
/// hyphen ("arm64-|v8a"): a box too narrow for a word breaks it across lines
/// without reporting any overflow.
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
          text[i - 1].trim().isEmpty ||
              text[i - 1] == '-' ||
              text[i].trim().isEmpty,
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

/// [inner] lies inside [outer].
void _expectInside(Rect inner, Rect outer, String where) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - _eps), reason: where);
  expect(inner.top, greaterThanOrEqualTo(outer.top - _eps), reason: where);
  expect(inner.right, lessThanOrEqualTo(outer.right + _eps), reason: where);
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + _eps), reason: where);
}

/// The how-to this platform's notice shows.
String _howTo(BuildContext context) {
  final s = AppStrings.of(context);
  return defaultTargetPlatform == TargetPlatform.iOS
      ? s.updateHowToIos
      : s.updateHowToAndroid;
}

void main() {
  setUpAll(() async {
    await loadRoboto();
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
  });

  final platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });

  testWidgets('the Dashboard banner lays out at every size', (tester) async {
    requireRoboto();
    addTearDown(tester.view.reset);
    for (final lang in _langs) {
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          final where = '$lang, ${width.toInt()} dp at ${t}x';
          setLayoutScreen(tester, width, height: 1600);
          await pumpLayoutApp(
            tester,
            const DashboardScreen(),
            textScale: t,
            locale: Locale(lang),
            overrides: [
              ...dashboardOverrides(
                stats: typicalDashboardStats(),
                dues: typicalDues(),
                updates: UpdateChannel.github,
              ),
              updateNoticeProvider.overrideWith(_Notice.new),
            ],
          );
          await tester.pumpAndSettle();
          expectCleanLayout(tester, where);
          final context = tester.element(find.byType(DashboardScreen));
          final s = AppStrings.of(context);
          final banner = find.byType(UpdateNoticeBanner);
          expect(banner, findsOneWidget, reason: where);
          Finder inBanner(Finder f) => find.descendant(of: banner, matching: f);
          final title = inBanner(find.text(s.updateAvailable('1.0.12')));
          final howTo = inBanner(find.text(_howTo(context)));
          final download = inBanner(
            find.widgetWithText(FilledButton, s.download),
          );
          final dismiss = inBanner(find.byTooltip(s.dismiss));
          for (final text in [title, howTo, inBanner(find.text(s.download))]) {
            expectWholeText(tester, text, where);
            if (lang == 'en') _expectWholeWords(tester, text, where);
          }

          // Inside the banner, inside the screen beside the rail (the rail
          // is on the right in Arabic), with the Dashboard's margins.
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final box = tester.getRect(banner);
          final (left, right) = rtl
              ? (16.0, width - kRailWidth - 16)
              : (kRailWidth + 16, width - 16);
          expect(box.left, closeTo(left, _eps), reason: where);
          expect(box.right, closeTo(right, _eps), reason: where);
          for (final part in [title, howTo, download, dismiss]) {
            _expectInside(tester.getRect(part), box, where);
          }
          // Download under the texts, at their start; ✕ at the end.
          final text = tester.getRect(howTo);
          final button = tester.getRect(download);
          final x = tester.getRect(dismiss);
          expect(
            tester.getRect(title).bottom,
            lessThanOrEqualTo(text.top + _eps),
            reason: where,
          );
          expect(button.top, greaterThanOrEqualTo(text.bottom), reason: where);
          if (rtl) {
            expect(button.right, closeTo(text.right, _eps), reason: where);
            expect(x.right, lessThanOrEqualTo(text.left), reason: where);
          } else {
            expect(button.left, closeTo(text.left, _eps), reason: where);
            expect(x.left, greaterThanOrEqualTo(text.right), reason: where);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  }, variant: platforms);

  testWidgets('the dialog lays out at every size', (tester) async {
    requireRoboto();
    addTearDown(tester.view.reset);
    for (final lang in _langs) {
      for (final height in _dialogHeights) {
        for (final width in kLayoutWidths) {
          for (final t in kLayoutTextScales) {
            final where =
                '$lang, ${width.toInt()}×${height.toInt()} dp at ${t}x';
            setLayoutScreen(tester, width, height: height);
            await pumpLayoutApp(
              tester,
              Scaffold(
                body: Center(
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () =>
                          UpdateNoticeDialog.show(context, _update),
                      child: const Text('Check'),
                    ),
                  ),
                ),
              ),
              textScale: t,
              locale: Locale(lang),
            );
            await tester.tap(find.text('Check'));
            await tester.pumpAndSettle();
            expectCleanLayout(tester, where);
            final dialog = find.byType(UpdateNoticeDialog);
            expect(dialog, findsOneWidget, reason: where);
            final context = tester.element(dialog);
            final s = AppStrings.of(context);
            Finder inDialog(Finder f) =>
                find.descendant(of: dialog, matching: f);
            for (final text in [
              s.updateAvailable('1.0.12'),
              _howTo(context),
              s.close,
              s.download,
            ]) {
              expectWholeText(tester, inDialog(find.text(text)), where);
              if (lang == 'en') {
                _expectWholeWords(tester, inDialog(find.text(text)), where);
              }
            }
            // Both buttons on screen, under the scrolling texts.
            final screen = Offset.zero & Size(width, height);
            for (final label in [s.close, s.download]) {
              _expectInside(
                tester.getRect(inDialog(find.text(label))),
                screen,
                where,
              );
            }
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    }
  }, variant: platforms);
}
