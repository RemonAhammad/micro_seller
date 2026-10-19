import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';

// Shared harness for layout tests under the Display size / Text size
// settings: a screen must lay out cleanly down to the narrowest layout the
// Display size allows (320 dp) and up to a large phone font, and look the same
// as before at 100% text on a normal phone.

/// Text scales a screen must survive: 100%, the Text size setting's top end
/// (130%) and a large phone font followed through (150%).
const kLayoutTextScales = [1.0, 1.3, 1.5];

/// Logical window widths in dp: the narrowest layout the Display size allows
/// (`kMinZoomedLayoutWidth`), a common small phone and the owner's phone.
const kLayoutWidths = [320.0, 360.0, 411.0];

/// The sidebar's icon rail beside every screen on a phone.
const kRailWidth = 56.0;

/// Why a check that measures text in Roboto fails when the font is missing.
const kRobotoRequired = 'Roboto from the Flutter SDK cache '
    '(bin/cache/artifacts/material_fonts) is required; run flutter precache';

/// Whether [loadRoboto] found and loaded Roboto.
var _robotoLoaded = false;

/// Loads Roboto, the family the app theme names, from the Flutter SDK's cache
/// so text measures as on an Android phone. Without it, tests draw every glyph
/// as a 1 em square, far wider than Roboto. Call it from `setUpAll`. A
/// missing font doesn't fail it: tests that don't measure text in Roboto
/// still run, and those that do call [requireRoboto].
Future<void> loadRoboto() async {
  final roots = [
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      Directory('$root/bin/cache/artifacts'),
    // flutter_tester runs from bin/cache/artifacts/engine/<platform>/.
    for (var d = File(Platform.resolvedExecutable).parent;
        d.parent.path != d.path;
        d = d.parent)
      d,
  ];
  for (final root in roots) {
    final dir = '${root.path}/material_fonts';
    if (!File('$dir/Roboto-Regular.ttf').existsSync()) continue;
    final loader = FontLoader('Roboto');
    for (final weight in [
      'Thin',
      'Light',
      'Regular',
      'Medium',
      'Bold',
      'Black',
    ]) {
      final bytes = File('$dir/Roboto-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
    _robotoLoaded = true;
    return;
  }
}

/// Fails the current test with [kRobotoRequired] unless [loadRoboto] loaded
/// Roboto. CI allows no skipped tests, so a missing font fails the test
/// instead of skipping it.
///
/// A test that measures text in Roboto calls it first, before it pumps
/// anything: one that checks a layout is unchanged at 100% text, or that
/// fails in the far wider test font (an overflow, a word broken across
/// lines). A shared helper that makes such a check calls it too. A test that
/// passes in any font doesn't call it, so it runs without Roboto.
void requireRoboto() {
  if (!_robotoLoaded) fail(kRobotoRequired);
}

/// The app's light theme as a phone draws it. The theme's app bar title and
/// elevated, filled and outlined button text styles name no font family: a
/// phone draws those in its system font (Roboto on Android), a test in its
/// 1-em-square test font, far wider. Naming Roboto there measures them as on
/// a phone, once [loadRoboto] has loaded it.
final ThemeData layoutPhoneTheme = () {
  final theme = AppTheme.lightTheme;
  ButtonStyle? roboto(ButtonStyle? style) => style?.copyWith(
        textStyle: WidgetStateProperty.resolveWith((states) => style.textStyle
            ?.resolve(states)
            ?.copyWith(fontFamily: 'Roboto')),
      );
  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle:
          theme.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto'),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: roboto(theme.elevatedButtonTheme.style)),
    filledButtonTheme:
        FilledButtonThemeData(style: roboto(theme.filledButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: roboto(theme.outlinedButtonTheme.style)),
  );
}();

/// Sets the test window to [width] × [height] logical dp. Call
/// `addTearDown(tester.view.reset)` in the test.
void setLayoutScreen(WidgetTester tester, double width,
    {double height = 800, double devicePixelRatio = 3}) {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize =
      Size(width * devicePixelRatio, height * devicePixelRatio);
}

/// Pumps [home] the way the app shows a screen on a phone: beside the
/// sidebar's icon rail (unless [rail] is false), with the app's light theme
/// as a phone draws it ([layoutPhoneTheme]), strings and [textScale] applied
/// over the whole app the way a font size is.
Future<void> pumpLayoutApp(
  WidgetTester tester,
  Widget home, {
  double textScale = 1,
  List<Override> overrides = const [],
  bool rail = true,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: layoutPhoneTheme,
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: rail
          ? Row(
              children: [
                const SizedBox(width: kRailWidth),
                Expanded(child: home),
              ],
            )
          : home,
    ),
  ));
  // The app's strings load asynchronously: the next frame has the content.
  await tester.pump();
}

/// No overflow (or any other error) was reported while laying out.
void expectCleanLayout(WidgetTester tester, String where) {
  final error = tester.takeException();
  expect(error, isNull, reason: '$where: $error');
}

/// Every paragraph [finder] matches is drawn whole: a box too short for its
/// line cuts the text off without reporting an overflow.
void expectWholeText(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    expect(p.size.height, greaterThanOrEqualTo(p.textSize.height - 0.01),
        reason: '$where: "${p.text.toPlainText()}" cut off');
  }
}
