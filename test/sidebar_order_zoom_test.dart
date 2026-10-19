// Settings → Sidebar Order under the Display size zoom. ReorderableListView
// mixes window and local coordinates (its drag proxy, its drop slots), and
// the two only agree at 100%: under a zoom the dragged row was drawn away
// from the finger. The screen is pumped where the app shows it, in a branch
// Navigator beside the sidebar rail and under the status bar, on a phone
// like the owner's.
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/sidebar_items.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/features/settings/presentation/sidebar_order_screen.dart';
import 'package:micro_seller/features/settings/providers/settings_provider.dart';
import 'package:micro_seller/shared/widgets/app_zoom.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sidebar's icon rail and the status bar, around every screen.
const _rail = 56.0;
const _statusBar = 24.0;

/// Display sizes: the whole range this phone offers (it caps 130% at 125%).
const _percents = [80, 85, 100, 115, 125];

/// 1440 × 3200 px at 3.5 dpr (≈ 411 × 914 dp), font size 125%.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 3.5;
  tester.platformDispatcher.textScaleFactorTestValue = 1.25;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Sidebar Order at Display size [percent], where the app shows it.
Widget _app(int percent) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: const [AppLocalizations.delegate],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        AppZoom(displayPercent: percent, child: child!),
    home: Row(
      children: [
        const SizedBox(width: _rail),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: _statusBar),
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const SidebarOrderScreen(),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);

/// Pumps [_app] and returns its provider container. Pumping again with
/// another size keeps the screen and the container.
Future<ProviderContainer> _pump(WidgetTester tester, int percent) async {
  await tester.pumpWidget(_app(percent));
  // The app's strings load asynchronously: the next frame has the content.
  await tester.pump();
  final screen = tester.element(find.byType(SidebarOrderScreen));
  expect(AppZoomScope.scaleOf(screen), percent / 100);
  return ProviderScope.containerOf(screen, listen: false);
}

/// [key]'s row. While it is dragged, the drag proxy's copy of it.
Finder _row(String key) => find.byKey(ValueKey(key));

/// [key]'s grip handle (not the row-wide long-press listener the list adds:
/// that one is a subtype, which byType doesn't match).
Finder _grip(String key) => find.descendant(
  of: _row(key),
  matching: find.byType(ReorderableDragStartListener),
);

/// Drags [key]'s row by its grip over the rows [past] (all below it or all
/// above it), the last of them only [last] of the way, in small steps, and
/// lets go. Once the drag is live (past the touch slop) the row is drawn by
/// the drag proxy, which must stay where the finger holds it. The list moves
/// the row past another once it is halfway over it; let go, the row must
/// settle in the gap that leaves.
///
/// Distances are the rows' own heights: in the test font some names wrap at
/// some sizes, so the rows aren't all as tall.
///
/// One move per 16 ms frame, as a finger gives. (A drop while the proxy's
/// lift animation is still at 0 leaves the list a stale drop position that
/// pins the next drag's proxy: a Flutter quirk no real drag reaches.)
Future<void> _drag(
  WidgetTester tester,
  String key,
  List<String> past, {
  double last = 1,
  required String where,
}) async {
  const frame = Duration(milliseconds: 16);
  const steps = 24;
  final grabbed = tester.getRect(_row(key));
  final down = tester.getCenter(_grip(key));
  final hold = down - grabbed.topLeft;
  final heights = [for (final k in past) tester.getRect(_row(k)).height];
  final before = heights.fold(0.0, (sum, h) => sum + h) - heights.last;
  final travel = before + last * heights.last;
  final gap = before + (last > 0.5 ? heights.last : 0);
  final sign = tester.getRect(_row(past.first)).top < grabbed.top ? -1 : 1;
  var checked = 0;

  final gesture = await tester.startGesture(down);
  await tester.pump(frame);
  for (var i = 1; i <= steps; i++) {
    final finger = down + Offset(0, sign * travel * i / steps);
    await gesture.moveTo(finger);
    await tester.pump(frame);
    if ((finger - down).distance <= kTouchSlop + 1) continue;
    expect(
      finger - tester.getRect(_row(key)).topLeft,
      offsetMoreOrLessEquals(hold, epsilon: 4),
      reason: '$where: the dragged row left the finger at step $i',
    );
    checked++;
  }
  expect(checked, greaterThanOrEqualTo(steps ~/ 2), reason: where);
  await gesture.up();
  await tester.pumpAndSettle();
  expect(
    tester.getRect(_row(key)).top,
    moreOrLessEquals(grabbed.top + sign * gap, epsilon: 1),
    reason: '$where: the row did not settle in the gap',
  );
}

/// The saved order, the persisted one and the one on screen are [expected].
Future<void> _expectOrder(
  WidgetTester tester,
  ProviderContainer container,
  List<String> expected,
  String where,
) async {
  expect(
    container.read(settingsProvider.notifier).sidebarOrder,
    expected,
    reason: where,
  );
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getString('sidebarOrder'), jsonEncode(expected), reason: where);
  // Top to bottom on screen. The list builds a prefix of its rows.
  final shown =
      [
        for (final key in expected)
          if (_row(key).evaluate().isNotEmpty) key,
      ]..sort(
        (a, b) =>
            tester.getRect(_row(a)).top.compareTo(tester.getRect(_row(b)).top),
      );
  expect(shown.length, greaterThanOrEqualTo(6), reason: where);
  expect(shown, expected.take(shown.length).toList(), reason: where);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final percent in _percents) {
    group('$percent%', () {
      testWidgets('a dragged row stays under the finger and drops there', (
        tester,
      ) async {
        _phone(tester);
        final container = await _pump(tester, percent);

        // Dashboard down past Products and Orders.
        await _drag(tester, 'dashboard', [
          'products',
          'orders',
        ], where: '$percent% down');
        // Products, Orders, Dashboard, Returns, Customers, …
        final down = [...defaultSidebarOrder]
          ..remove('dashboard')
          ..insert(2, 'dashboard');
        await _expectOrder(tester, container, down, '$percent% down');

        // Customers back up past Returns and Dashboard.
        await _drag(tester, 'customers', [
          'returns',
          'dashboard',
        ], where: '$percent% up');
        final up = [...down]
          ..remove('customers')
          ..insert(2, 'customers');
        await _expectOrder(tester, container, up, '$percent% up');
      });

      testWidgets('a row passes another once it is halfway over it', (
        tester,
      ) async {
        _phone(tester);
        final container = await _pump(tester, percent);

        // Customers up over Returns and 40% of Orders: past Returns only.
        await _drag(
          tester,
          'customers',
          ['returns', 'orders'],
          last: 0.4,
          where: '$percent% at 40%',
        );
        final first = [...defaultSidebarOrder]
          ..remove('customers')
          ..insert(3, 'customers');
        await _expectOrder(tester, container, first, '$percent% at 40%');

        // Due Book up over Returns and 60% of Customers: past both.
        await _drag(
          tester,
          'dues',
          ['returns', 'customers'],
          last: 0.6,
          where: '$percent% at 60%',
        );
        final second = [...first]
          ..remove('dues')
          ..insert(3, 'dues');
        await _expectOrder(tester, container, second, '$percent% at 60%');
      });

      testWidgets('a visibility switch hides and shows its tab', (
        tester,
      ) async {
        _phone(tester);
        final container = await _pump(tester, percent);
        final settings = container.read(settingsProvider.notifier);
        final toggle = find.descendant(
          of: _row('orders'),
          matching: find.byType(CupertinoSwitch),
        );

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(settings.hiddenSidebarItems, ['orders']);
        expect(tester.widget<CupertinoSwitch>(toggle).value, isFalse);

        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(settings.hiddenSidebarItems, isEmpty);
        expect(tester.widget<CupertinoSwitch>(toggle).value, isTrue);

        // The Settings tab's switch stays on and disabled.
        final pinned = find.descendant(
          of: _row('settings'),
          matching: find.byType(CupertinoSwitch),
        );
        await tester.scrollUntilVisible(pinned, 100);
        // Its last scroll is a jump, laid out in the next frame.
        await tester.pump();
        expect(tester.widget<CupertinoSwitch>(pinned).value, isTrue);
        expect(tester.widget<CupertinoSwitch>(pinned).onChanged, isNull);
        await tester.tap(pinned);
        await tester.pumpAndSettle();
        expect(settings.hiddenSidebarItems, isEmpty);
      });
    });
  }

  testWidgets('rows are drawn at the Display size; 100% draws no transform', (
    tester,
  ) async {
    _phone(tester);
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    Rect switchRect() => tester.getRect(
      find.descendant(
        of: _row('dashboard'),
        matching: find.byType(CupertinoSwitch),
      ),
    );

    await _pump(tester, 100);
    for (final box in tester.renderObjectList<RenderZoomBox>(
      find.byType(ZoomBox),
    )) {
      expect(box.debugLayer, isNull);
    }
    final row = tester.getRect(_row('dashboard'));
    expect(row.left, closeTo(_rail + 12, 0.01));
    expect(row.right, closeTo(window.width - 12, 0.01));
    expect(tester.getSize(_grip('dashboard')), const Size(24, 24));
    final toggle = switchRect().size;

    for (final percent in _percents) {
      final s = percent / 100;
      final where = '$percent%';
      await _pump(tester, percent);
      // The list's 12 dp inset is zoomed like the rest of the screen ...
      final row = tester.getRect(_row('dashboard'));
      expect(row.left, closeTo((_rail + 12) * s, 0.01), reason: where);
      expect(row.right, closeTo(window.width - 12 * s, 0.01), reason: where);
      // ... and so is what the rows draw.
      final grip = tester.getRect(_grip('dashboard'));
      expect(grip.width, closeTo(24 * s, 0.01), reason: where);
      expect(grip.height, closeTo(24 * s, 0.01), reason: where);
      expect(
        switchRect().width,
        closeTo(toggle.width * s, 0.01),
        reason: where,
      );
      expect(
        switchRect().height,
        closeTo(toggle.height * s, 0.01),
        reason: where,
      );
    }
  });
}
