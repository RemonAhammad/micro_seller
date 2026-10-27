// The layout harness's tablet support (test/support/layout_harness.dart):
// the sidebar beside a screen follows the app's rule for the window, and
// forEachTabletLayout visits every tablet screen and Split View width.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/layout_harness.dart';

/// Where the screen [pumpLayoutApp] pumped starts: the sidebar's width.
double _screenLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('screen'))).dx;

const _screen = SizedBox.expand(key: ValueKey('screen'));

void main() {
  test("railWidthFor is the app's rule: labels from 600 dp", () {
    for (final width in [320.0, 360.0, 411.0, 507.0, 599.9]) {
      expect(railWidthFor(width), kRailWidth, reason: '$width');
    }
    for (final width in [600.0, 694.0, 744.0, 1376.0]) {
      expect(railWidthFor(width), kWideRailWidth, reason: '$width');
    }
    expect(kRailWidth, 56);
    expect(kWideRailWidth, 200);
    expect(kWideRailMinWidth, 600);
  });

  testWidgets('pumpLayoutApp puts the sidebar the window gets beside the '
      'screen', (tester) async {
    addTearDown(tester.view.reset);
    for (final (width, left) in [
      (320.0, 56.0),
      (411.0, 56.0),
      (600.0, 200.0),
      (800.0, 200.0),
    ]) {
      setLayoutScreen(tester, width);
      await pumpLayoutApp(tester, _screen);
      expect(_screenLeft(tester), left, reason: '$width dp');
    }
    setLayoutScreen(tester, 800);
    await pumpLayoutApp(tester, _screen, railWidth: kRailWidth);
    expect(_screenLeft(tester), kRailWidth, reason: 'a given width wins');
    await pumpLayoutApp(tester, _screen, rail: false);
    expect(_screenLeft(tester), 0, reason: 'no sidebar');
  });

  testWidgets('forEachTabletLayout visits every tablet window at a tablet '
      'pixel ratio', (tester) async {
    final seen = <(Size, double)>[];
    await forEachTabletLayout(tester, (where, window, t) async {
      expect(tester.view.devicePixelRatio, 2, reason: where);
      expect(tester.view.physicalSize / 2, window, reason: where);
      await pumpLayoutApp(tester, _screen, textScale: t);
      expect(_screenLeft(tester), railWidthFor(window.width), reason: where);
      seen.add((window, t));
    });
    expect(seen, [
      for (final window in [
        ...kTabletScreens,
        for (final width in kSplitViewWidths) Size(width, 1024),
      ])
        for (final t in kTabletTextScales) (window, t),
    ]);
    expect(seen, hasLength((7 + 4) * 2));
    expect(find.byKey(const ValueKey('screen')), findsNothing,
        reason: 'the screen is cleared after each');
  });

  testWidgets('forEachTabletLayout narrows to the windows asked for',
      (tester) async {
    final seen = <String>[];
    await forEachTabletLayout(
      tester,
      (where, window, t) async => seen.add(where),
      screens: const [Size(1133, 744)],
      splitViewWidths: const [694],
      textScales: const [1.3],
    );
    expect(seen, [
      '1133 × 744 dp at 1.3x text',
      '694 × 1024 dp at 1.3x text',
    ]);
  });
}
