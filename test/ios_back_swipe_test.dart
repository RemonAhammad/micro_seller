import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:micro_seller/core/constants/sidebar_items.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/router/app_router.dart';
import 'package:micro_seller/core/router/shell_back_swipe.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/data/services/device_channel.dart';
import 'package:micro_seller/data/services/release_update_service.dart';
import 'package:micro_seller/features/categories/presentation/category_screen.dart';
import 'package:micro_seller/features/categories/providers/category_provider.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/settings/presentation/sidebar_order_screen.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:micro_seller/features/updates/providers/update_notice_provider.dart';
import 'package:micro_seller/shared/widgets/app_zoom.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_device_channel.dart';
import 'support/layout_harness.dart';

// iOS's back swipe in the shell. A pushed screen is an iOS page: its slide,
// and the swipe from its own leading edge, which starts beside the sidebar.
// The strip over the sidebar starts the same swipe from the screen's edge,
// while the sidebar keeps its taps. Android keeps the fade and has no swipe.
// On the app's real router, from Settings → Sidebar Order.

final _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

/// The sidebar.
final _sidebar = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_Sidebar',
);

/// The pushed screen the tests swipe away.
final _page = find.byType(SidebarOrderScreen);

/// Pumps the app's router on the Settings tab, the one tab that needs no
/// database, in a [width] × 800 dp window, with the Display size at
/// [percent] and the app in [locale]. [prefs] are saved settings; the
/// first-run tour is done.
Future<void> _pumpApp(
  WidgetTester tester, {
  double width = 411,
  int percent = 100,
  Locale locale = const Locale('en'),
  Map<String, Object> prefs = const {},
}) async {
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'tour_completed': true, ...prefs});
  setLayoutScreen(tester, width);
  appRouter.go('/settings');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Offline, and no device behind the Security rows.
        updateChannelProvider.overrideWithValue(
          const AsyncData(UpdateChannel.none),
        ),
        deviceChannelProvider.overrideWithValue(FakeDeviceChannel()),
        // The Categories tab, without a database: an empty list.
        categoriesProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp.router(
        // A ThemeData keeps the platform it was built on. The app builds its
        // theme on the phone, so it has the phone's.
        theme: AppTheme.lightTheme.copyWith(platform: defaultTargetPlatform),
        routerConfig: appRouter,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            AppZoom(displayPercent: percent, child: child!),
      ),
    ),
  );
  // The app's strings and the saved settings load asynchronously.
  await tester.pump();
  await tester.pump();
}

/// Opens Settings → Sidebar Order, and returns the Settings tab's navigator.
Future<NavigatorState> _openSidebarOrder(WidgetTester tester) async {
  unawaited(appRouter.push('/settings/sidebar-order'));
  await tester.pumpAndSettle();
  expect(_page, findsOneWidget);
  return Navigator.of(tester.element(_page));
}

/// Whether the strip takes swipes.
bool _stripEnabled(WidgetTester tester) =>
    tester.widget<ShellEdgeBackSwipe>(find.byType(ShellEdgeBackSwipe)).enabled;

/// Whether the shell ignores touches, as it does while a page follows the
/// finger.
bool _shellIgnoresTouches(WidgetTester tester) => tester
    .widget<IgnorePointer>(
      find
          .descendant(
            of: find.byType(ShellEdgeBackSwipe),
            matching: find.byType(IgnorePointer),
          )
          .first,
    )
    .ignoring;

/// The Settings tab in the sidebar: its icon in the rail, its label in the
/// wide sidebar.
Finder _settingsTab(WidgetTester tester, {bool wide = false}) {
  final label = sidebarItemByKey('settings').label(tester.element(_sidebar));
  return find.descendant(
    of: _sidebar,
    matching: wide ? find.text(label) : find.byTooltip(label),
  );
}

/// Puts a finger down at [at] and moves it 30 dp sideways, towards the
/// trailing side (the left in [rtl]): past the touch slop, so a swipe
/// starts there.
Future<TestGesture> _startSwipe(
  WidgetTester tester,
  Offset at, {
  bool rtl = false,
}) async {
  final gesture = await tester.startGesture(at);
  await gesture.moveBy(Offset(rtl ? -30 : 30, 0));
  await tester.pump();
  return gesture;
}

/// Moves [gesture] [dx] dp sideways and expects the page to move exactly as
/// far on the screen.
Future<void> _expectFollows(
  WidgetTester tester,
  TestGesture gesture,
  double dx,
) async {
  final before = tester.getTopLeft(_page).dx;
  await gesture.moveBy(Offset(dx, 0));
  await tester.pump();
  expect(
    tester.getTopLeft(_page).dx - before,
    moreOrLessEquals(dx, epsilon: 0.01),
  );
}

/// Every route pushed above a tab's first screen, with its full path.
List<(String, GoRoute)> _subRoutes(StatefulShellRoute shell) {
  final found = <(String, GoRoute)>[];
  void visit(String parent, GoRoute route) {
    final path = '$parent/${route.path}';
    found.add((path, route));
    for (final child in route.routes.whereType<GoRoute>()) {
      visit(path, child);
    }
  }

  for (final branch in shell.branches) {
    for (final root in branch.routes.whereType<GoRoute>()) {
      for (final child in root.routes.whereType<GoRoute>()) {
        visit(root.path == '/' ? '' : root.path, child);
      }
    }
  }
  return found;
}

void main() {
  setUpAll(() {
    // No Security rows: they would ask for the biometric hardware.
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=false\nENABLE_PIN_GATE=false',
    );
  });
  setUp(Settings.debugResetPrimed);

  testWidgets('a drag from the screen edge, over the rail, pops the page, '
      'which follows the finger', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);
    expect(_stripEnabled(tester), isTrue);
    expect(tester.getTopLeft(_page).dx, kSidebarRailWidth);

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    expect(navigator.userGestureInProgress, isTrue);
    // Meanwhile the rail and the screens take no other touch.
    expect(_shellIgnoresTouches(tester), isTrue);
    await _expectFollows(tester, gesture, 100);
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    final released = tester.getTopLeft(_page).dx;
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // It slides on from where the finger left it, without jumping back in.
    expect(tester.getTopLeft(_page).dx, greaterThan(released));
    expect(navigator.userGestureInProgress, isTrue);
    await tester.pumpAndSettle();

    expect(_page, findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(navigator.userGestureInProgress, isFalse);
    expect(_shellIgnoresTouches(tester), isFalse);
  }, variant: _iOS);

  testWidgets("a drag from beside the rail, the page's own edge, pops", (
    tester,
  ) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);

    final gesture = await _startSwipe(
      tester,
      const Offset(kSidebarRailWidth + 6, 400),
    );
    await _expectFollows(tester, gesture, 100);
    await gesture.moveBy(const Offset(150, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_page, findsNothing);
    expect(navigator.userGestureInProgress, isFalse);
  }, variant: _iOS);

  testWidgets('a slow, short drag snaps back, and the page still takes taps', (
    tester,
  ) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);

    await tester.timedDragFrom(
      const Offset(2, 400),
      const Offset(60, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(_page, findsOneWidget);
    expect(tester.getTopLeft(_page).dx, kSidebarRailWidth);
    expect(navigator.userGestureInProgress, isFalse);
    expect(_shellIgnoresTouches(tester), isFalse);
    final toggle = find.byType(CupertinoSwitch).first;
    final wasOn = tester.widget<CupertinoSwitch>(toggle).value;
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<CupertinoSwitch>(toggle).value, !wasOn);
  }, variant: _iOS);

  testWidgets('a short fling pops', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);

    // Not far enough to pop by itself (test above): the speed does.
    await tester.flingFrom(const Offset(2, 400), const Offset(80, 0), 1000);
    await tester.pumpAndSettle();

    expect(_page, findsNothing);
    expect(navigator.userGestureInProgress, isFalse);
  }, variant: _iOS);

  testWidgets("on a tab's first screen an edge drag does nothing, and the "
      'rail under the strip still takes taps', (tester) async {
    await _pumpApp(tester);
    final settings = find.byType(SettingsScreen);
    final navigator = Navigator.of(tester.element(settings));

    await tester.dragFrom(const Offset(2, 400), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(settings, findsOneWidget);
    expect(navigator.userGestureInProgress, isFalse);
    expect(_shellIgnoresTouches(tester), isFalse);

    // On a pushed screen, a tap on the Settings icon, inside the strip,
    // still goes back to the tab's first screen.
    await _openSidebarOrder(tester);
    await tester.tapAt(Offset(10, tester.getCenter(_settingsTab(tester)).dy));
    await tester.pumpAndSettle();
    expect(_page, findsNothing);
    expect(settings, findsOneWidget);
  }, variant: _iOS);

  testWidgets('a screen pushed with Navigator.push swipes back too, unless it '
      'refuses a pop', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);
    final editor = find.text('editor');

    // As the color theme editor and the product form's scanner are pushed.
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('editor')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(2, 400), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
    expect(_page, findsOneWidget);

    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const PopScope(
            canPop: false,
            child: Scaffold(body: Text('editor')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await _startSwipe(tester, const Offset(2, 400));
    expect(navigator.userGestureInProgress, isFalse);
    await gesture.moveBy(const Offset(270, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(editor, findsOneWidget);
  }, variant: _iOS);

  testWidgets('a page with a transition of its own, not iOS\'s slide, is not '
      'swiped', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);
    unawaited(
      navigator.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const Scaffold(body: Text('custom')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    expect(navigator.userGestureInProgress, isFalse);
    await gesture.moveBy(const Offset(270, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('custom'), findsOneWidget);
  }, variant: _iOS);

  testWidgets("a second finger on the edge during a swipe from the page's own "
      'edge does nothing', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);

    final first = await _startSwipe(
      tester,
      const Offset(kSidebarRailWidth + 6, 400),
    );
    expect(navigator.userGestureInProgress, isTrue);
    final second = await _startSwipe(tester, const Offset(2, 300));
    await second.moveBy(const Offset(270, 0));
    await tester.pump();
    expect(tester.getTopLeft(_page).dx, kSidebarRailWidth);
    await second.up();
    await first.up();
    await tester.pumpAndSettle();
    expect(_page, findsOneWidget);
    expect(navigator.userGestureInProgress, isFalse);
  }, variant: _iOS);

  testWidgets('a page still sliding in starts no swipe', (tester) async {
    await _pumpApp(tester);
    unawaited(appRouter.push('/settings/sidebar-order'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final navigator = Navigator.of(tester.element(_page));

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    expect(navigator.userGestureInProgress, isFalse);
    await gesture.moveBy(const Offset(270, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_page, findsOneWidget);
    expect(tester.getTopLeft(_page).dx, kSidebarRailWidth);
  }, variant: _iOS);

  testWidgets('a finger resting on the edge, or moving along it, starts no '
      'swipe', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);

    // Below the rail's icons nothing else wants the touch.
    final gesture = await tester.startGesture(const Offset(2, 760));
    await tester.pump(const Duration(seconds: 1));
    expect(navigator.userGestureInProgress, isFalse);
    expect(_shellIgnoresTouches(tester), isFalse);
    await gesture.moveBy(const Offset(4, -60));
    await tester.pump();
    expect(navigator.userGestureInProgress, isFalse);
    expect(tester.getTopLeft(_page).dx, kSidebarRailWidth);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_page, findsOneWidget);
  }, variant: _iOS);

  testWidgets(
    'Android: pushed screens fade in, and an edge drag does nothing',
    (tester) async {
      await _pumpApp(tester);
      await _openSidebarOrder(tester);

      final route = ModalRoute.of(tester.element(_page))!;
      expect(route.settings, isA<CustomTransitionPage<dynamic>>());
      expect(_stripEnabled(tester), isFalse);
      for (final x in [2.0, kSidebarRailWidth + 6]) {
        await tester.dragFrom(Offset(x, 400), const Offset(300, 0));
        await tester.pumpAndSettle();
        expect(_page, findsOneWidget);
        expect(tester.getTopLeft(_page).dx, kSidebarRailWidth);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('Arabic: the rail is on the right, and a drag from the right '
      'edge pops', (tester) async {
    await _pumpApp(tester, locale: const Locale('ar'));
    final navigator = await _openSidebarOrder(tester);
    expect(tester.getRect(_sidebar).right, 411);
    expect(_stripEnabled(tester), isTrue);

    final gesture = await _startSwipe(
      tester,
      const Offset(409, 400),
      rtl: true,
    );
    expect(navigator.userGestureInProgress, isTrue);
    await _expectFollows(tester, gesture, -100);
    await gesture.moveBy(const Offset(-150, 0));
    await tester.pump();
    final released = tester.getTopLeft(_page).dx;
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(_page).dx, lessThan(released));
    await tester.pumpAndSettle();

    expect(_page, findsNothing);
    expect(navigator.userGestureInProgress, isFalse);
  }, variant: _iOS);

  testWidgets("with the rail on the right, the page's own edge is the "
      "screen's: no strip, and a drag from x = 2 pops", (tester) async {
    await _pumpApp(tester, prefs: {'sidebarPosition': 'right'});
    final navigator = await _openSidebarOrder(tester);
    expect(tester.getRect(_sidebar).right, 411);
    expect(tester.getTopLeft(_page).dx, 0);
    expect(_stripEnabled(tester), isFalse);

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    await _expectFollows(tester, gesture, 100);
    await gesture.moveBy(const Offset(150, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_page, findsNothing);
    expect(navigator.userGestureInProgress, isFalse);
  }, variant: _iOS);

  for (final percent in [125, 80]) {
    testWidgets('Display size $percent%: a drag from the screen edge pops, '
        'the page following the finger 1:1', (tester) async {
      await _pumpApp(tester, percent: percent);
      final navigator = await _openSidebarOrder(tester);
      expect(
        tester.getTopLeft(_page).dx,
        moreOrLessEquals(kSidebarRailWidth * percent / 100),
      );

      final gesture = await _startSwipe(tester, const Offset(2, 400));
      expect(navigator.userGestureInProgress, isTrue);
      await _expectFollows(tester, gesture, 100);
      await gesture.moveBy(const Offset(150, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_page, findsNothing);
      expect(navigator.userGestureInProgress, isFalse);
    }, variant: _iOS);
  }

  testWidgets('an 800 dp window, with the 200 dp sidebar: a drag from the '
      'screen edge pops, and a tap at x = 10 still opens a tab', (
    tester,
  ) async {
    await _pumpApp(tester, width: 800);
    expect(tester.getSize(_sidebar).width, kSidebarExpandedWidth);
    final navigator = await _openSidebarOrder(tester);
    expect(tester.getTopLeft(_page).dx, kSidebarExpandedWidth);

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    await _expectFollows(tester, gesture, 100);
    await gesture.moveBy(const Offset(300, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_page, findsNothing);
    expect(navigator.userGestureInProgress, isFalse);

    await _openSidebarOrder(tester);
    await tester.tapAt(
      Offset(10, tester.getCenter(_settingsTab(tester, wide: true)).dy),
    );
    await tester.pumpAndSettle();
    expect(_page, findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
  }, variant: _iOS);

  testWidgets('a page the app pops mid-swipe ends the swipe with it', (
    tester,
  ) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(navigator.userGestureInProgress, isTrue);
    appRouter.go('/settings');
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_page, findsNothing);
    expect(navigator.userGestureInProgress, isFalse);
    expect(_shellIgnoresTouches(tester), isFalse);

    // Nothing is left half done: the next swipe works.
    await _openSidebarOrder(tester);
    await tester.dragFrom(const Offset(2, 400), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(_page, findsNothing);
  }, variant: _iOS);

  testWidgets('a route the app pushes mid-swipe leaves the page sliding back '
      'in, not where the finger left it', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);
    final route = ModalRoute.of(tester.element(_page))!;

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(route.animation!.value, lessThan(1));
    // As the order form shows "Order created" on its tab once it saved.
    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(_page),
        builder: (_) => const SizedBox(height: 200, child: Text('Sheet')),
      ),
    );
    await tester.pump();
    expect(route.isCurrent, isFalse);
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await tester.pump();
    // Still following the swipe until it's back in: its slide stays linear.
    expect(navigator.userGestureInProgress, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsOneWidget);
    expect(route.animation!.status, AnimationStatus.completed);
    expect(tester.getTopLeft(_page).dx, kSidebarRailWidth);
    expect(navigator.userGestureInProgress, isFalse);
    expect(_shellIgnoresTouches(tester), isFalse);

    // The sheet closed, the page is in place, and the next swipe works.
    Navigator.of(tester.element(find.text('Sheet'))).pop();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_page).dx, kSidebarRailWidth);
    await tester.dragFrom(const Offset(2, 400), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(_page, findsNothing);
  }, variant: _iOS);

  testWidgets('another tab shown while a pushed route covers the swiped '
      'page puts it back in place at once', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);
    final route = ModalRoute.of(tester.element(_page))!;

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(_page),
        builder: (_) => const SizedBox(height: 200, child: Text('Sheet')),
      ),
    );
    await tester.pump();
    appRouter.go('/categories');
    await tester.pump();
    await tester.pump();
    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(route.animation!.status, AnimationStatus.completed);
    expect(navigator.userGestureInProgress, isFalse);
    expect(_shellIgnoresTouches(tester), isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(navigator.userGestureInProgress, isFalse);
  }, variant: _iOS);

  testWidgets('a page gone between the touch and the drag: nothing is swiped, '
      'not even the screen under it', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);

    final gesture = await tester.startGesture(const Offset(2, 400));
    appRouter.go('/settings');
    await tester.pumpAndSettle();
    expect(_page, findsNothing);
    final settings = find.byType(SettingsScreen);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(navigator.userGestureInProgress, isFalse);
    await gesture.moveBy(const Offset(270, 0));
    await tester.pump();
    expect(tester.getTopLeft(settings).dx, kSidebarRailWidth);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(settings, findsOneWidget);
    expect(navigator.userGestureInProgress, isFalse);
  }, variant: _iOS);

  testWidgets('another tab shown mid-swipe ends the swipe, the page back in '
      'place', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);
    final route = ModalRoute.of(tester.element(_page))!;

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(navigator.userGestureInProgress, isTrue);
    expect(route.animation!.value, lessThan(1));
    appRouter.go('/categories');
    await tester.pump();
    await tester.pump();
    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(navigator.userGestureInProgress, isFalse);
    expect(_shellIgnoresTouches(tester), isFalse);
    expect(route.animation!.status, AnimationStatus.completed);

    // The rest of that touch is ignored.
    await gesture.moveBy(const Offset(200, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(navigator.userGestureInProgress, isFalse);

    // Back on the Settings tab, the page is where it was.
    await tester.tap(_settingsTab(tester));
    await tester.pumpAndSettle();
    expect(ModalRoute.of(tester.element(_page)), same(route));
    expect(tester.getTopLeft(_page).dx, kSidebarRailWidth);
  }, variant: _iOS);

  testWidgets('the shell going away mid-swipe leaves no error', (tester) async {
    await _pumpApp(tester);
    final navigator = await _openSidebarOrder(tester);

    final gesture = await _startSwipe(tester, const Offset(2, 400));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(navigator.userGestureInProgress, isTrue);
    await tester.pumpWidget(const SizedBox());
    await gesture.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: _iOS);

  testWidgets(
    'every pushed screen is an iOS page on iOS and fades elsewhere, '
    'and every tab tells the strip its top page',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      final shell = appRouter.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;
      expect(shell.branches, hasLength(14));
      for (final branch in shell.branches) {
        expect(
          branch.observers?.whereType<BranchTopRouteObserver>(),
          hasLength(1),
        );
      }

      final subRoutes = _subRoutes(shell);
      expect(subRoutes, hasLength(23));
      for (final (fullPath, route) in subRoutes) {
        expect(route.builder, isNull, reason: fullPath);
        final location = fullPath.replaceAll(':id', '1');
        final state = GoRouterState(
          appRouter.configuration,
          uri: Uri.parse(location),
          matchedLocation: location,
          path: route.path,
          fullPath: fullPath,
          pathParameters: const {'id': '1'},
          pageKey: ValueKey(location),
        );
        final page = route.pageBuilder!(context, state);
        expect(page.key, state.pageKey, reason: fullPath);
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          expect(page, isA<MaterialPage<dynamic>>(), reason: fullPath);
          expect(page.name, route.path, reason: fullPath);
        } else {
          expect(page, isA<CustomTransitionPage<dynamic>>(), reason: fullPath);
        }
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  test("the theme slides an iOS page in as iOS does: it sets no page "
      'transitions of its own', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    }
  });

  test("the layout tests' sidebar widths are the app's", () {
    expect(kRailWidth, kSidebarRailWidth);
    expect(kWideRailWidth, kSidebarExpandedWidth);
    expect(kWideRailMinWidth, kSidebarExpandMinWidth);
    for (final width in [599.0, 600.0]) {
      expect(
        railWidthFor(width),
        width >= kSidebarExpandMinWidth
            ? kSidebarExpandedWidth
            : kSidebarRailWidth,
      );
    }
  });
}
