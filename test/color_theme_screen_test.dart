// Settings → Color theme: applying a preset, creating, customizing, editing
// and deleting a theme of one's own, Phone colors only where the phone has
// them, the limit of twelve, the editor's White / Black text color
// (Recommended, chosen by hand, used exactly in light and dark), a copy of
// a preset keeping its dark colors, and the name checked wherever the
// editor is scrolled.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/router/app_router.dart';
import 'package:micro_seller/core/theme/app_color_theme.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/theme/dynamic_color_support.dart';
import 'package:micro_seller/features/settings/presentation/color_theme_screen.dart';
import 'package:micro_seller/features/settings/presentation/widgets/color_theme_editor.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:micro_seller/shared/widgets/app_preview_sample.dart';
import 'package:micro_seller/shared/widgets/confirm_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

/// The app's theme wiring (app.dart): the saved color theme, light mode.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(settingsProvider.select((m) => m[Settings.keyColorThemeId]));
    ref.watch(settingsProvider.select((m) => m[Settings.keyCustomColorThemes]));
    final colorTheme = ref.read(settingsProvider.notifier).activeColorTheme;
    return MaterialApp(
      theme: AppTheme.build(Brightness.light, colorTheme),
      darkTheme: AppTheme.build(Brightness.dark, colorTheme),
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ColorThemeScreen(),
    );
  }
}

/// Pumps the Color theme screen with [prefs] saved, on a phone [height] dp
/// tall: by default tall enough for the whole screen and the editor to be
/// built. [phone] is whether the phone offers Phone colors; without
/// [phoneAnswers], the phone never answers. Returns the Settings notifier.
Future<Settings> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool phone = false,
  bool phoneAnswers = true,
  double height = 2600,
}) async {
  // A fresh ProviderScope, so the saved settings are read again.
  await tester.pumpWidget(const SizedBox());
  Settings.debugResetPrimed();
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(411 * 3, height * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dynamicColorAvailableProvider.overrideWith(
          (ref) =>
              phoneAnswers ? Future.value(phone) : Completer<bool>().future,
        ),
      ],
      child: const _App(),
    ),
  );
  // The strings and the saved settings load asynchronously.
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(ColorThemeScreen)),
  ).read(settingsProvider.notifier);
}

/// A context inside the screen on top, for its strings.
BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).last);

/// The app's theme where [finder] is.
ThemeData _themeAt(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder));

/// A [ThinIcon] drawing [icon].
Finder _icon(ThinIconBuilder icon) =>
    find.byWidgetPredicate((w) => w is ThinIcon && w.builder == icon);

/// The tappable tile [label] is in.
Finder _tile(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

/// Whether [label]'s tile is marked as the active theme (its check).
bool _checked(WidgetTester tester, String label) => find
    .descendant(of: _tile(label), matching: _icon(tabler.Check.new))
    .evaluate()
    .isNotEmpty;

/// The main color's hex code field (the accent's comes after it).
Finder _hexField(WidgetTester tester) => find
    .widgetWithText(TextField, AppStrings.of(_context(tester)).hexColor)
    .first;

/// The editor's name field.
Finder _nameField(WidgetTester tester) =>
    find.widgetWithText(TextField, AppStrings.of(_context(tester)).themeName);

/// A button of [type], subclasses included (`FilledButton.icon` makes one).
Finder _button<T extends ButtonStyleButton>() =>
    find.byWidgetPredicate((w) => w is T);

String _fieldText(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

/// The editor's White or Black option.
Finder _option(OnColor on) => find.byKey(ValueKey('textColor-${on.name}'));

/// Whether [on]'s option is the one selected.
bool _selected(WidgetTester tester, OnColor on) => find
    .descendant(of: _option(on), matching: _icon(tabler.CircleCheck.new))
    .evaluate()
    .isNotEmpty;

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens a saved theme's menu (in its row) and picks [item].
Future<void> _menu(WidgetTester tester, String theme, String item) async {
  final row = find.ancestor(
    of: find.text(theme),
    matching: find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_CustomThemeTile',
    ),
  );
  await _tapAndSettle(
    tester,
    find.descendant(
      of: row,
      matching: find.byWidgetPredicate((w) => w is PopupMenuButton),
    ),
  );
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

AppColorTheme _custom(String id, String name, int seed, {OnColor? on}) =>
    AppColorTheme(
      id: id,
      name: name,
      seed: seed,
      onPrimary: on ?? recommendedOnColor(Color(seed)),
    );

Map<String, Object> _saved(List<AppColorTheme> customs, {String? active}) => {
  Settings.keyCustomColorThemes: encodeCustomColorThemes(customs),
  Settings.keyColorThemeId: ?active,
};

void main() {
  setUp(Settings.debugResetPrimed);

  testWidgets('the route is a Settings sub-route', (tester) async {
    final match = appRouter.configuration.findMatch(
      Uri.parse('/settings/color-theme'),
    );
    expect(match.isError, isFalse);
    expect(match.last.route.path, 'color-theme');
  });

  testWidgets('tapping a preset applies it to the whole app', (tester) async {
    final settings = await _pump(tester);
    final s = AppStrings.of(_context(tester));
    expect(settings.colorThemeId, kDefaultColorThemeId);
    expect(_checked(tester, s.presetThemeName('teal')), isTrue);

    await _tapAndSettle(tester, find.text(s.presetThemeName('blue')));
    expect(settings.colorThemeId, 'blue');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(Settings.keyColorThemeId), 'blue');
    // The app's theme is Blue's pair, and the preview draws in it.
    final cs = _themeAt(tester, find.byType(AppPreviewFrame)).colorScheme;
    expect(cs.primary, const Color(0xFF1976D2));
    expect(cs.onPrimary, const Color(0xFFFFFFFF));
    // Blue is marked, Teal no longer is; Amber's swatch draws its black text.
    expect(_checked(tester, s.presetThemeName('blue')), isTrue);
    expect(_checked(tester, s.presetThemeName('teal')), isFalse);
    final amberIcon = tester.widget<ThinIcon>(
      find.descendant(
        of: _tile(s.presetThemeName('amber')),
        matching: find.byType(ThinIcon),
      ),
    );
    expect(amberIcon.color, const Color(0xFF000000));
  });

  testWidgets('a theme with Black text: onPrimary is black in the app', (
    tester,
  ) async {
    final settings = await _pump(tester);
    final s = AppStrings.of(_context(tester));
    await _tapAndSettle(tester, find.text(s.createTheme));
    expect(find.byType(ColorThemeEditor), findsOneWidget);
    await tester.enterText(_nameField(tester), 'Night market');
    await tester.enterText(_hexField(tester), '1565c0');
    await tester.pump();
    // White reads better on #1565C0, so it starts there; Black by hand.
    expect(_selected(tester, OnColor.white), isTrue);
    await _tapAndSettle(tester, _option(OnColor.black));
    expect(_selected(tester, OnColor.black), isTrue);
    // Nothing is saved before Save.
    expect(settings.customColorThemes, isEmpty);
    expect(settings.colorThemeId, kDefaultColorThemeId);

    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();
    expect(find.byType(ColorThemeEditor), findsNothing);
    final saved = settings.customColorThemes.single;
    expect(saved.isCustom, isTrue);
    expect(saved.name, 'Night market');
    expect(saved.seed, 0xFF1565C0);
    expect(saved.onPrimary, OnColor.black);
    expect(saved.accent, isNull);
    expect(settings.colorThemeId, saved.id);

    // The app's buttons draw black on the main color ...
    final cs = _themeAt(tester, find.byType(ColorThemeScreen)).colorScheme;
    expect(cs.primary, const Color(0xFF1565C0));
    expect(cs.onPrimary, const Color(0xFF000000));
    final label = tester.widget<RichText>(
      find.descendant(
        of: find.descendant(
          of: find.byType(AppPreviewFrame),
          matching: _button<FilledButton>(),
        ),
        matching: find.byType(RichText),
      ),
    );
    expect(label.text.style?.color, const Color(0xFF000000));
    // ... and so does dark mode: the seller's pair, exactly.
    final dark = AppTheme.build(Brightness.dark, saved).colorScheme;
    expect(dark.primary, const Color(0xFF1565C0));
    expect(dark.onPrimary, const Color(0xFF000000));
    // The new theme is listed under My themes, marked active.
    expect(_checked(tester, 'Night market'), isTrue);
  });

  testWidgets('Customize copies a preset into a new theme', (tester) async {
    final settings = await _pump(tester);
    final s = AppStrings.of(_context(tester));
    await _tapAndSettle(tester, find.text(s.presetThemeName('amber')));
    await _tapAndSettle(tester, find.text(s.customizeTheme));
    expect(find.byType(ColorThemeEditor), findsOneWidget);
    expect(_fieldText(tester, _nameField(tester)), s.presetThemeName('amber'));
    expect(_fieldText(tester, _hexField(tester)), 'B07D00');
    expect(_selected(tester, OnColor.black), isTrue);

    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();
    final saved = settings.customColorThemes.single;
    final amber = kPresetColorThemes.singleWhere((p) => p.id == 'amber');
    expect(saved.id, isNot(amber.id));
    expect(saved.isCustom, isTrue);
    expect(saved.name, s.presetThemeName('amber'));
    expect(saved.seed, amber.seed);
    expect(saved.style, amber.style);
    expect(saved.onPrimary, amber.onPrimary);
    // Its curated dark colors too: unchanged, the copy is Amber in both
    // modes (#FFC107 in dark mode, not the deep amber).
    expect(saved.darkPrimary, amber.darkPrimary);
    expect(saved.darkOnPrimary, amber.darkOnPrimary);
    for (final b in Brightness.values) {
      expect(
        identical(AppTheme.build(b, saved), AppTheme.build(b, amber)),
        isTrue,
        reason: b.name,
      );
    }
    expect(settings.colorThemeId, saved.id);
  });

  testWidgets(
    'a long press customizes a preset, on the text color that reads better',
    (tester) async {
      final settings = await _pump(tester);
      final s = AppStrings.of(_context(tester));
      // Teal is active: its name is also beside the preview.
      await tester.longPress(_tile(s.presetThemeName('teal')));
      await tester.pumpAndSettle();
      expect(find.byType(ColorThemeEditor), findsOneWidget);
      expect(_fieldText(tester, _hexField(tester)), '00897B');
      // Like every new theme, it starts on the recommended text color:
      // black reads a little better on #00897B than Teal's white does.
      expect(_selected(tester, OnColor.black), isTrue);
      expect(
        find.descendant(
          of: _option(OnColor.black),
          matching: find.text(s.recommended),
        ),
        findsOneWidget,
      );
      // Not chosen here: a new main color moves it to the new
      // recommendation, and back.
      await tester.enterText(_hexField(tester), '1565C0');
      await tester.pump();
      expect(_selected(tester, OnColor.white), isTrue);
      await tester.enterText(_hexField(tester), '00897B');
      await tester.pump();
      expect(_selected(tester, OnColor.black), isTrue);

      // With Teal's own White, the copy is Teal, its dark colors included.
      await _tapAndSettle(tester, _option(OnColor.white));
      expect(_selected(tester, OnColor.white), isTrue);
      await tester.tap(find.widgetWithText(FilledButton, s.save));
      await tester.pumpAndSettle();
      final saved = settings.customColorThemes.single;
      expect(saved.onPrimary, OnColor.white);
      expect(saved.darkPrimary, kDefaultColorTheme.darkPrimary);
      expect(saved.darkOnPrimary, kDefaultColorTheme.darkOnPrimary);
      for (final b in Brightness.values) {
        expect(
          identical(
            AppTheme.build(b, saved),
            AppTheme.build(b, kDefaultColorTheme),
          ),
          isTrue,
          reason: b.name,
        );
      }
    },
  );

  testWidgets("a copy keeps the preset's dark colors only while its main "
      "color and text color are the preset's", (tester) async {
    final settings = await _pump(tester);
    final s = AppStrings.of(_context(tester));
    final mono = kPresetColorThemes.singleWhere((p) => p.id == 'mono');
    await tester.longPress(_tile(s.presetThemeName('mono')));
    await tester.pumpAndSettle();
    expect(_selected(tester, OnColor.white), isTrue);
    await _tapAndSettle(tester, find.widgetWithText(ChoiceChip, s.dark));
    ColorScheme preview() => _themeAt(
      tester,
      find.descendant(
        of: find.byType(AppPreviewFrame),
        matching: _button<FilledButton>(),
      ),
    ).colorScheme;
    // Mono's dark mode: white with black text, not black on the dark
    // background.
    expect(preview().primary, Color(mono.darkPrimary!));
    expect(preview().onPrimary, const Color(0xFF000000));
    expect(find.text(s.hardToSeeOnDark), findsNothing);

    // Another main color: the seller's pair, in dark mode too.
    await tester.enterText(_hexField(tester), '000080');
    await tester.pump();
    expect(preview().primary, const Color(0xFF000080));
    expect(preview().onPrimary, const Color(0xFFFFFFFF));
    expect(find.text(s.hardToSeeOnDark), findsOneWidget);

    // Mono's own pair again: its dark colors again.
    await tester.enterText(_hexField(tester), '000000');
    await tester.pump();
    expect(preview().primary, Color(mono.darkPrimary!));
    expect(find.text(s.hardToSeeOnDark), findsNothing);

    // Another text color: the seller's pair, exactly.
    await _tapAndSettle(tester, _option(OnColor.black));
    expect(preview().primary, const Color(0xFF000000));
    expect(preview().onPrimary, const Color(0xFF000000));
    expect(find.text(s.hardToSeeOnDark), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();
    final saved = settings.customColorThemes.single;
    expect(saved.seed, 0xFF000000);
    expect(saved.onPrimary, OnColor.black);
    expect(saved.darkPrimary, isNull);
    expect(saved.darkOnPrimary, isNull);
  });

  testWidgets('editing a theme keeps its id and applies the change', (
    tester,
  ) async {
    final theme = _custom('custom-1', 'Old name', 0xFF6A1B9A);
    final settings = await _pump(
      tester,
      prefs: _saved([theme], active: theme.id),
    );
    final s = AppStrings.of(_context(tester));
    await _menu(tester, 'Old name', s.edit);
    expect(find.byType(ColorThemeEditor), findsOneWidget);
    expect(_fieldText(tester, _nameField(tester)), 'Old name');
    expect(_fieldText(tester, _hexField(tester)), '6A1B9A');
    await tester.enterText(_nameField(tester), '  New name ');
    await tester.enterText(_hexField(tester), '2E7D32');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();

    final saved = settings.customColorThemes.single;
    expect(saved.id, theme.id);
    expect(saved.name, 'New name');
    expect(saved.seed, 0xFF2E7D32);
    expect(settings.colorThemeId, theme.id);
    expect(
      _themeAt(tester, find.byType(ColorThemeScreen)).colorScheme.primary,
      const Color(0xFF2E7D32),
    );
  });

  testWidgets('a name is required', (tester) async {
    final settings = await _pump(tester);
    final s = AppStrings.of(_context(tester));
    await _tapAndSettle(tester, find.text(s.createTheme));
    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();
    expect(find.text(s.themeNameRequired), findsOneWidget);
    expect(find.byType(ColorThemeEditor), findsOneWidget);
    expect(settings.customColorThemes, isEmpty);
    // Back without saving changes nothing.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(settings.customColorThemes, isEmpty);
    expect(settings.colorThemeId, kDefaultColorThemeId);
  });

  testWidgets('a name is required wherever the editor is scrolled', (
    tester,
  ) async {
    // A normal phone, where the editor's list builds only the rows near the
    // screen: with the accent's picker open and the list scrolled to Save,
    // the name field is far out of view.
    final settings = await _pump(tester, height: 820);
    final s = AppStrings.of(_context(tester));
    Finder listOf(Type screen) => find
        .descendant(of: find.byType(screen), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text(s.createTheme),
      300,
      scrollable: listOf(ColorThemeScreen),
    );
    await _tapAndSettle(tester, find.text(s.createTheme));
    final list = listOf(ColorThemeEditor);
    await tester.scrollUntilVisible(
      find.text(s.useAccentColor),
      300,
      scrollable: list,
    );
    await _tapAndSettle(tester, find.text(s.useAccentColor));
    await tester.drag(list, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, s.themeName),
      findsNothing,
      reason: 'scrolled out of view',
    );

    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();
    // Nothing is saved; the list scrolls back to the name, which says why.
    expect(settings.customColorThemes, isEmpty);
    expect(settings.colorThemeId, kDefaultColorThemeId);
    expect(find.byType(ColorThemeEditor), findsOneWidget);
    expect(find.text(s.themeNameRequired), findsOneWidget);
    expect(find.widgetWithText(TextField, s.themeName), findsOneWidget);
  });

  testWidgets('deleting the active theme falls back to Teal', (tester) async {
    final mine = _custom('custom-1', 'Mine', 0xFF6A1B9A);
    final other = _custom('custom-2', 'Other', 0xFF1565C0);
    final settings = await _pump(
      tester,
      prefs: _saved([mine, other], active: mine.id),
    );
    final s = AppStrings.of(_context(tester));
    await _menu(tester, 'Mine', s.delete);
    expect(find.text(s.deleteThemeConfirm('Mine')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ConfirmDialog),
        matching: find.widgetWithText(FilledButton, s.delete),
      ),
    );
    await tester.pumpAndSettle();
    expect(settings.customColorThemes.map((t) => t.id), [other.id]);
    expect(settings.colorThemeId, kDefaultColorThemeId);
    expect(find.text('Mine'), findsNothing);
    expect(_checked(tester, s.presetThemeName('teal')), isTrue);
    expect(
      _themeAt(tester, find.byType(ColorThemeScreen)).colorScheme.primary,
      kDefaultColorTheme.seedColor,
    );

    // From the editor too, after a Cancel that keeps it.
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await _menu(tester, 'Other', s.edit);
    await tester.tap(find.byTooltip(s.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, s.cancel));
    await tester.pumpAndSettle();
    expect(settings.customColorThemes, hasLength(1));
    await tester.tap(find.byTooltip(s.delete));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ConfirmDialog),
        matching: find.widgetWithText(FilledButton, s.delete),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ColorThemeEditor), findsNothing);
    expect(settings.customColorThemes, isEmpty);
    expect(settings.colorThemeId, kDefaultColorThemeId);
  });

  testWidgets('Phone colors only where the phone has them', (tester) async {
    await _pump(tester);
    var s = AppStrings.of(_context(tester));
    expect(find.text(s.phoneColors), findsNothing);
    expect(find.text(s.phoneColorsDesc), findsNothing);

    final settings = await _pump(tester, phone: true);
    s = AppStrings.of(_context(tester));
    expect(find.text(s.phoneColorsDesc), findsOneWidget);
    await _tapAndSettle(tester, find.text(s.phoneColorsDesc));
    expect(settings.colorThemeId, kPhoneColorThemeId);
    expect(_checked(tester, s.phoneColorsDesc), isTrue);
    // Phone colors can't be customized: its colors aren't the app's own.
    expect(find.text(s.customizeTheme), findsNothing);

    // Saved, on a phone without them (a restored backup): still listed and
    // marked, and it says the app shows Teal instead.
    await _pump(tester, prefs: {Settings.keyColorThemeId: kPhoneColorThemeId});
    s = AppStrings.of(_context(tester));
    final missing = s.phoneColorsUnavailable(s.presetThemeName('teal'));
    expect(missing, contains(s.presetThemeName('teal')));
    expect(find.text(missing), findsOneWidget);
    expect(find.text(s.phoneColorsDesc), findsNothing);
    expect(_checked(tester, missing), isTrue);
    expect(
      _themeAt(tester, find.byType(ColorThemeScreen)).colorScheme.primary,
      kDefaultColorTheme.seedColor,
    );

    // Not before the phone has answered: one that has them must not flash
    // the note while it's asked.
    await _pump(
      tester,
      prefs: {Settings.keyColorThemeId: kPhoneColorThemeId},
      phoneAnswers: false,
    );
    s = AppStrings.of(_context(tester));
    expect(find.text(s.phoneColorsDesc), findsOneWidget);
    expect(
      find.text(s.phoneColorsUnavailable(s.presetThemeName('teal'))),
      findsNothing,
    );
  });

  testWidgets('at most twelve themes of ones own', (tester) async {
    final eleven = [
      for (var i = 0; i < kMaxCustomColorThemes - 1; i++)
        _custom('custom-$i', 'Theme $i', 0xFF1565C0 + i * 0x1000),
    ];
    final settings = await _pump(tester, prefs: _saved(eleven));
    final s = AppStrings.of(_context(tester));
    expect(find.text(s.themeLimitReached(kMaxCustomColorThemes)), findsNothing);

    // The twelfth can be made ...
    await _tapAndSettle(tester, find.text(s.createTheme));
    await tester.enterText(_nameField(tester), 'Twelfth');
    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();
    expect(settings.customColorThemes, hasLength(kMaxCustomColorThemes));

    // ... then Create theme and Customize are off, and the screen says why.
    final create = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text(s.createTheme),
        matching: _button<OutlinedButton>(),
      ),
    );
    expect(create.onPressed, isNull);
    expect(
      find.text(s.themeLimitReached(kMaxCustomColorThemes)),
      findsOneWidget,
    );
    await _tapAndSettle(tester, find.text(s.presetThemeName('green')));
    final customize = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text(s.customizeTheme),
        matching: _button<OutlinedButton>(),
      ),
    );
    expect(customize.onPressed, isNull);
    await tester.longPress(_tile(s.presetThemeName('green')));
    await tester.pumpAndSettle();
    expect(find.byType(ColorThemeEditor), findsNothing);
    expect(
      find.text(s.themeLimitReached(kMaxCustomColorThemes)),
      findsNWidgets(2),
    );
    expect(settings.customColorThemes, hasLength(kMaxCustomColorThemes));
  });

  testWidgets('a yellow main color recommends Black', (tester) async {
    await _pump(tester);
    final s = AppStrings.of(_context(tester));
    await _tapAndSettle(tester, find.text(s.createTheme));
    await tester.enterText(_hexField(tester), 'FFFF00');
    await tester.pump();
    Finder inOption(OnColor on, String text) =>
        find.descendant(of: _option(on), matching: find.text(text));
    expect(inOption(OnColor.black, s.recommended), findsOneWidget);
    expect(inOption(OnColor.white, s.recommended), findsNothing);
    expect(inOption(OnColor.black, s.readabilityEasy), findsOneWidget);
    expect(inOption(OnColor.white, s.readabilityHard), findsOneWidget);
    expect(_selected(tester, OnColor.black), isTrue);
    // Yellow is hard to see on the light background, not on the dark one.
    expect(find.text(s.hardToSeeOnLight), findsOneWidget);
    expect(find.text(s.hardToSeeOnDark), findsNothing);

    // White, chosen by hand, stays when the main color changes ...
    await _tapAndSettle(tester, _option(OnColor.white));
    await tester.enterText(_hexField(tester), 'FFC107');
    await tester.pump();
    expect(_selected(tester, OnColor.white), isTrue);
    expect(inOption(OnColor.black, s.recommended), findsOneWidget);
    // ... and the preview shows it as picked: white on amber.
    final cs = _themeAt(
      tester,
      find.descendant(
        of: find.byType(AppPreviewFrame),
        matching: _button<FilledButton>(),
      ),
    ).colorScheme;
    expect(cs.primary, const Color(0xFFFFC107));
    expect(cs.onPrimary, const Color(0xFFFFFFFF));
  });

  testWidgets('the preview shows the draft in light or dark mode', (
    tester,
  ) async {
    await _pump(tester);
    final s = AppStrings.of(_context(tester));
    await _tapAndSettle(tester, find.text(s.createTheme));
    await tester.enterText(_hexField(tester), '000080');
    await tester.pump();
    ThemeData preview() => _themeAt(
      tester,
      find.descendant(
        of: find.byType(AppPreviewFrame),
        matching: _button<FilledButton>(),
      ),
    );
    expect(preview().brightness, Brightness.light);
    // Navy is hard to see on the dark background.
    expect(find.text(s.hardToSeeOnDark), findsOneWidget);
    expect(find.text(s.hardToSeeOnLight), findsNothing);
    await _tapAndSettle(tester, find.widgetWithText(ChoiceChip, s.dark));
    expect(preview().brightness, Brightness.dark);
    expect(preview().colorScheme.primary, const Color(0xFF000080));
    expect(preview().colorScheme.onPrimary, const Color(0xFFFFFFFF));
  });

  testWidgets('the accent and the style are saved as picked', (tester) async {
    final settings = await _pump(tester);
    final s = AppStrings.of(_context(tester));
    await _tapAndSettle(tester, find.text(s.createTheme));
    await tester.enterText(_nameField(tester), 'Accented');
    await _tapAndSettle(
      tester,
      find.widgetWithText(ChoiceChip, s.themeStyleMuted),
    );
    await _tapAndSettle(tester, find.text(s.useAccentColor));
    // The accent's own picker: its hex field is the second one.
    final accentHex = find.widgetWithText(TextField, s.hexColor).last;
    await tester.enterText(accentHex, 'FF6F00');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();
    final saved = settings.customColorThemes.single;
    expect(saved.style, ThemeStyle.muted);
    expect(saved.accent, 0xFFFF6F00);
  });
}
