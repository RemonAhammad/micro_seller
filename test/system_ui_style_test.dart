// The status bar's style (system_ui_style.dart): readable over the app's own
// light or dark theme whatever the phone's mode, set by the app frame's
// AnnotatedRegion on Android and iOS alike (Android reads
// statusBarIconBrightness, iOS statusBarBrightness). The first-launch
// splash keeps light icons over its teal while it shows, and the app's
// style comes back after it. The navigation bar's fields stay null, so
// Android's navigation bar is as it was. main()'s first-frame style comes
// from initialSystemUiStyle.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/theme/system_ui_style.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:micro_seller/features/splash/presentation/splash_screen.dart';
import 'package:micro_seller/shared/widgets/app_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A style nothing in the app sets: SystemChrome.latestStyle is static, so
/// each test starts from it and sees what its own frames set.
const _sentinel = SystemUiOverlayStyle(statusBarColor: Color(0x12345678));

final _mobile = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});

/// A phone with a 47 dp status bar, as an iPhone has.
void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
}

Future<void> _startFromSentinel(WidgetTester tester) async {
  SystemChrome.setSystemUIOverlayStyle(_sentinel);
  await tester.pump();
  expect(SystemChrome.latestStyle, _sentinel);
}

/// The app's shell: a Scaffold whose body is a SafeArea, with a screen and
/// its AppBar inside it, below the status bar.
class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Orders')),
        body: const Center(child: Text('content')),
      ),
    ),
  );
}

Widget _app({
  ThemeMode mode = ThemeMode.light,
  bool frame = true,
  RouterConfig<Object>? router,
}) {
  final theme = AppTheme.lightTheme;
  final darkTheme = AppTheme.darkTheme;
  const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  Widget builder(BuildContext context, Widget? child) =>
      frame ? AppFrame(child: child!) : child!;
  return ProviderScope(
    child: router == null
        ? MaterialApp(
            theme: theme,
            darkTheme: darkTheme,
            themeMode: mode,
            localizationsDelegates: delegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: builder,
            home: const _Shell(),
          )
        : MaterialApp.router(
            theme: theme,
            darkTheme: darkTheme,
            themeMode: mode,
            localizationsDelegates: delegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: builder,
            routerConfig: router,
          ),
  );
}

void _expectStyle(SystemUiOverlayStyle expected, {String? reason}) {
  final style = SystemChrome.latestStyle;
  expect(style, expected, reason: reason);
  // Android's navigation bar keeps the look it has without these.
  expect(style!.systemNavigationBarColor, isNull, reason: reason);
  expect(style.systemNavigationBarIconBrightness, isNull, reason: reason);
  expect(style.systemNavigationBarDividerColor, isNull, reason: reason);
  expect(style.systemNavigationBarContrastEnforced, isNull, reason: reason);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the styles', () {
    test('over a light theme: dark icons on Android, dark text on iOS', () {
      final style = appSystemUiStyle(Brightness.light);
      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      // iOS: what's behind the bar is light.
      expect(style.statusBarBrightness, Brightness.light);
    });

    test('over a dark theme: the reverse', () {
      final style = appSystemUiStyle(Brightness.dark);
      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.statusBarBrightness, Brightness.dark);
    });

    test('the splash: light icons and text over its teal', () {
      expect(kSplashSystemUiStyle.statusBarColor, Colors.transparent);
      expect(kSplashSystemUiStyle.statusBarIconBrightness, Brightness.light);
      expect(kSplashSystemUiStyle.statusBarBrightness, Brightness.dark);
    });

    test('none of them touches the navigation bar', () {
      for (final style in [
        appSystemUiStyle(Brightness.light),
        appSystemUiStyle(Brightness.dark),
        kSplashSystemUiStyle,
      ]) {
        expect(style.systemNavigationBarColor, isNull);
        expect(style.systemNavigationBarIconBrightness, isNull);
        expect(style.systemNavigationBarDividerColor, isNull);
        expect(style.systemNavigationBarContrastEnforced, isNull);
        expect(style.systemStatusBarContrastEnforced, isNull);
      }
    });
  });

  group('initialSystemUiStyle (main, before the first frame)', () {
    test("the splash's while the splash will show, whatever the mode", () {
      for (final mode in ['light', 'dark', 'system']) {
        for (final platform in Brightness.values) {
          expect(
            initialSystemUiStyle(
              splash: true,
              themeMode: mode,
              platform: platform,
            ),
            kSplashSystemUiStyle,
          );
        }
      }
    });

    test("else the saved mode's; System follows the phone", () {
      for (final platform in Brightness.values) {
        SystemUiOverlayStyle initial(String mode) => initialSystemUiStyle(
          splash: false,
          themeMode: mode,
          platform: platform,
        );
        expect(initial('light'), appSystemUiStyle(Brightness.light));
        expect(initial('dark'), appSystemUiStyle(Brightness.dark));
        expect(initial('system'), appSystemUiStyle(platform));
        // A value main() never passes still gives a readable bar.
        expect(initial('sepia'), appSystemUiStyle(platform));
      }
    });

    test(
      'Settings.primedThemeMode is the saved mode, System by default',
      () async {
        addTearDown(Settings.debugResetPrimed);
        Settings.debugResetPrimed();
        expect(Settings.primedThemeMode, 'system');
        for (final (Object stored, expected) in [
          ('dark', 'dark'),
          ('light', 'light'),
          ('system', 'system'),
          ('sepia', 'system'),
          (3, 'system'),
        ]) {
          SharedPreferences.setMockInitialValues({'themeMode': stored});
          Settings.primeFrom(await SharedPreferences.getInstance());
          expect(Settings.primedThemeMode, expected, reason: '$stored');
        }
      },
    );
  });

  group('the app frame', () {
    testWidgets('a light theme gets the light style', (tester) async {
      _phone(tester);
      await _startFromSentinel(tester);
      await tester.pumpWidget(_app(mode: ThemeMode.light));
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.light));
    }, variant: _mobile);

    testWidgets('a dark theme gets the dark style', (tester) async {
      _phone(tester);
      await _startFromSentinel(tester);
      await tester.pumpWidget(_app(mode: ThemeMode.dark));
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.dark));
    }, variant: _mobile);

    testWidgets('System follows the phone, also when the phone switches', (
      tester,
    ) async {
      _phone(tester);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      for (final phone in [Brightness.light, Brightness.dark]) {
        tester.platformDispatcher.platformBrightnessTestValue = phone;
        await _startFromSentinel(tester);
        await tester.pumpWidget(_app(mode: ThemeMode.system));
        await tester.pumpAndSettle();
        _expectStyle(appSystemUiStyle(phone), reason: phone.name);
        await tester.pumpWidget(const SizedBox());
      }

      // The phone switches while the app is open.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(_app(mode: ThemeMode.system));
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.light));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.dark));
    }, variant: _mobile);

    testWidgets("the app's theme over the phone's: a light app on a dark "
        'phone and the reverse', (tester) async {
      _phone(tester);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await _startFromSentinel(tester);
      await tester.pumpWidget(_app(mode: ThemeMode.light));
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.light));

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpWidget(const SizedBox());
      await _startFromSentinel(tester);
      await tester.pumpWidget(_app(mode: ThemeMode.dark));
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.dark));
    }, variant: _mobile);

    testWidgets('switching the theme mode in Settings flips it', (
      tester,
    ) async {
      _phone(tester);
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      await _startFromSentinel(tester);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (context, value, _) => _app(mode: value),
        ),
      );
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.light));

      mode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.dark));

      mode.value = ThemeMode.light;
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.light));
    }, variant: _mobile);

    testWidgets("an AppBar below the status bar doesn't reach it, and the "
        'theme names no AppBar style', (tester) async {
      _phone(tester);
      await _startFromSentinel(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => AppFrame(child: child!),
            home: Scaffold(
              body: SafeArea(
                child: Scaffold(
                  appBar: AppBar(
                    systemOverlayStyle: const SystemUiOverlayStyle(
                      statusBarColor: Color(0xFF00FF00),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectStyle(appSystemUiStyle(Brightness.light));
      expect(AppTheme.lightTheme.appBarTheme.systemOverlayStyle, isNull);
      expect(AppTheme.darkTheme.appBarTheme.systemOverlayStyle, isNull);
    }, variant: _mobile);

    testWidgets("a theme build or switch sends the frame's style, never "
        "MaterialApp's own (a black navigation bar): the frame's wins in the "
        'same frame', (tester) async {
      _phone(tester);
      final sent = <Map<Object?, Object?>>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
          sent.add(call.arguments as Map<Object?, Object?>);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);

      // Without the frame (as before), Flutter's MaterialApp sends
      // SystemUiOverlayStyle.dark / .light on each theme build.
      await _startFromSentinel(tester);
      sent.clear();
      await tester.pumpWidget(_app(mode: ThemeMode.light, frame: false));
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle, SystemUiOverlayStyle.dark);
      expect(sent.last['systemNavigationBarColor'], isNotNull);

      // With it, every style the platform gets leaves the navigation bar
      // alone, through theme builds and switches.
      await tester.pumpWidget(const SizedBox());
      await _startFromSentinel(tester);
      sent.clear();
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (context, value, _) => _app(mode: value),
        ),
      );
      await tester.pumpAndSettle();
      mode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      mode.value = ThemeMode.light;
      await tester.pumpAndSettle();
      expect(sent, isNotEmpty);
      for (final style in sent) {
        expect(style['systemNavigationBarColor'], isNull, reason: '$style');
        expect(
          style['systemNavigationBarIconBrightness'],
          isNull,
          reason: '$style',
        );
        expect(
          style['systemNavigationBarDividerColor'],
          isNull,
          reason: '$style',
        );
      }
      _expectStyle(appSystemUiStyle(Brightness.light));
    }, variant: _mobile);
  });

  group('the first-launch splash', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final brightness = mode == ThemeMode.dark
          ? Brightness.dark
          : Brightness.light;
      testWidgets("shows light icons, then the ${mode.name} app's style", (
        tester,
      ) async {
        _phone(tester);
        final router = GoRouter(
          initialLocation: '/splash',
          routes: [
            GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
            GoRoute(path: '/', builder: (_, _) => const _Shell()),
          ],
        );
        addTearDown(router.dispose);
        await _startFromSentinel(tester);
        await tester.pumpWidget(_app(mode: mode, router: router));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(SplashScreen), findsOneWidget);
        _expectStyle(kSplashSystemUiStyle);

        // The splash runs 2.5 s, then goes to the dashboard.
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.text('content'), findsOneWidget);
        _expectStyle(appSystemUiStyle(brightness));
      }, variant: _mobile);
    }
  });
}
