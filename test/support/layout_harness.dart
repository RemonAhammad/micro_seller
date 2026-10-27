import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';

// Shared harness for layout tests under the Display size / Text size
// settings: a screen must lay out cleanly down to the narrowest layout the
// Display size allows (320 dp) and up to a large phone font, and look the same
// as before at 100% text on a normal phone. Tablets too: iPads and Android
// tablets in both orientations, and the app's window in Split View
// ([forEachTabletLayout]).

/// Text scales a screen must survive: 100%, the Text size setting's top end
/// (130%) and a large phone font followed through (150%).
const kLayoutTextScales = [1.0, 1.3, 1.5];

/// Logical window widths in dp: the narrowest layout the Display size allows
/// (`kMinZoomedLayoutWidth`), a common small phone and the owner's phone.
const kLayoutWidths = [320.0, 360.0, 411.0];

/// The sidebar's icon rail beside every screen on a phone.
const kRailWidth = 56.0;

/// The sidebar with labels beside every screen in a window at least
/// [kWideRailMinWidth] wide (`app_router.dart`'s rule).
const kWideRailWidth = 200.0;

/// The narrowest window that gets the sidebar with labels.
const kWideRailMinWidth = 600.0;

/// The sidebar's width beside a screen in a [windowWidth] dp window, as the
/// app lays it out: the icon rail on a phone, labels from 600 dp.
double railWidthFor(double windowWidth) =>
    windowWidth >= kWideRailMinWidth ? kWideRailWidth : kRailWidth;

/// Tablet screens in logical dp, portrait and landscape: iPad mini 6
/// (744 × 1133), iPad Air 11" (820 × 1180), a 10" Android tablet
/// (800 × 1280) and iPad Pro 13" in landscape (1376 × 1032).
const kTabletScreens = [
  Size(744, 1133),
  Size(1133, 744),
  Size(820, 1180),
  Size(1180, 820),
  Size(800, 1280),
  Size(1280, 800),
  Size(1376, 1032),
];

/// The app's window widths in iPad Split View and Slide Over (and Android's
/// split screen): narrow as a phone up to two-thirds of an iPad. 1024 dp tall
/// in [forEachTabletLayout].
const kSplitViewWidths = [320.0, 375.0, 507.0, 694.0];

/// Text scales [forEachTabletLayout] checks by default: 100% and a large
/// phone font followed through (150%).
const kTabletTextScales = [1.0, 1.5];

/// Why a check that measures text in Roboto fails when the font is missing.
const kRobotoRequired = 'Roboto (the app bundles it in assets/fonts/roboto; '
    'the Flutter SDK cache has it in bin/cache/artifacts/material_fonts) is '
    'required';

/// Whether [loadRoboto] found and loaded Roboto.
var _robotoLoaded = false;

/// The folder [loadRoboto] loaded Roboto from: the app's own
/// (`assets/fonts/roboto`), the SDK cache's, or null when none was found.
String? get robotoSource => _robotoSource;
String? _robotoSource;

/// Loads Roboto so text measures as on a phone: Android's system font, and
/// the font the app bundles for iOS. Without it, tests draw every glyph as a
/// 1 em square, far wider than Roboto. Call it from `setUpAll`.
///
/// It loads the app's own files (`assets/fonts/roboto/`, the weights the app
/// uses: 400, 500, 700 and 900) under both names a theme gives them:
/// 'Roboto', which Android draws from the system, and 'RobotoStatic', the
/// bundled family iOS uses (`app_fonts.dart`). The Flutter SDK's cache is
/// the fallback. A missing font doesn't fail it: tests that don't measure
/// text in Roboto still run, and those that do call [requireRoboto].
Future<void> loadRoboto() async {
  final dirs = [
    // flutter test runs from the package root.
    'assets/fonts/roboto',
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts',
    // flutter_tester runs from bin/cache/artifacts/engine/<platform>/.
    for (var d = File(Platform.resolvedExecutable).parent;
        d.parent.path != d.path;
        d = d.parent)
      '${d.path}/material_fonts',
  ];
  const weights = ['Regular', 'Medium', 'Bold', 'Black'];
  for (final dir in dirs) {
    final files = [for (final w in weights) File('$dir/Roboto-$w.ttf')];
    if (!files.every((f) => f.existsSync())) continue;
    final fonts = [
      for (final f in files) ByteData.sublistView(f.readAsBytesSync()),
    ];
    for (final family in ['Roboto', 'RobotoStatic']) {
      final loader = FontLoader(family);
      for (final font in fonts) {
        loader.addFont(Future.value(font));
      }
      await loader.load();
    }
    _robotoLoaded = true;
    _robotoSource = dir;
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

/// The app's light theme as a phone draws it: [AppTheme.lightTheme] for the
/// platform the test runs as. Every text style the theme names a font in,
/// the app bar title and the elevated, filled and outlined button text
/// styles included, names `appFontFamily`: 'Roboto' on Android, the bundled
/// 'RobotoStatic' on iOS. [loadRoboto] loads both names, so text measures as
/// on a phone; without it, a test draws every glyph in its 1-em-square test
/// font, far wider.
ThemeData get layoutPhoneTheme => AppTheme.lightTheme;

/// Sets the test window to [width] × [height] logical dp. Call
/// `addTearDown(tester.view.reset)` in the test.
void setLayoutScreen(WidgetTester tester, double width,
    {double height = 800, double devicePixelRatio = 3}) {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize =
      Size(width * devicePixelRatio, height * devicePixelRatio);
}

/// Pumps [home] the way the app shows a screen: beside the sidebar (unless
/// [rail] is false), with the app's light theme as a phone draws it
/// ([layoutPhoneTheme]), strings and [textScale] applied over the whole app
/// the way a font size is. The sidebar is [railWidth] wide, by default the
/// app's rule for the test window ([railWidthFor]: the 56 dp icon rail on a
/// phone, 200 dp with labels in a window 600 dp or wider). [locale] is the
/// app language (English when null); with one, Flutter's own strings and the
/// text direction follow it too, as in the app.
Future<void> pumpLayoutApp(
  WidgetTester tester,
  Widget home, {
  double textScale = 1,
  List<Override> overrides = const [],
  bool rail = true,
  double? railWidth,
  Locale? locale,
}) async {
  final sidebar = railWidth ??
      railWidthFor(tester.view.physicalSize.width / tester.view.devicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: layoutPhoneTheme,
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        if (locale != null) ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: rail
          ? Row(
              children: [
                SizedBox(width: sidebar),
                Expanded(child: home),
              ],
            )
          : home,
    ),
  ));
  // The app's strings load asynchronously: the next frame has the content.
  await tester.pump();
}

/// Runs [body] in every tablet window: each of [screens] (portrait and
/// landscape, [kTabletScreens]) and each Split View width
/// ([splitViewWidths], 1024 dp tall), at each of [textScales], at a tablet's
/// pixel ratio (2). [body] gets a description of the layout, the window size
/// and the text scale; it pumps its screen (with [pumpLayoutApp], the
/// sidebar follows the window, as in the app). The screen is cleared after
/// each, and the window reset after all.
Future<void> forEachTabletLayout(
  WidgetTester tester,
  Future<void> Function(String where, Size window, double textScale) body, {
  List<Size> screens = kTabletScreens,
  List<double> splitViewWidths = kSplitViewWidths,
  List<double> textScales = kTabletTextScales,
}) async {
  addTearDown(tester.view.reset);
  final windows = [
    ...screens,
    for (final width in splitViewWidths) Size(width, 1024),
  ];
  for (final window in windows) {
    for (final t in textScales) {
      setLayoutScreen(tester, window.width,
          height: window.height, devicePixelRatio: 2);
      await body(
        '${window.width.toInt()} × ${window.height.toInt()} dp at ${t}x text',
        window,
        t,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  }
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
