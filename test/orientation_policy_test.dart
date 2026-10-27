// Phones stay in portrait, tablets rotate and multitask
// (orientation_policy.dart): decided from the display, not the window (Split
// View narrows the window), applied again when the display changes the
// decision (a foldable), and only then.
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/utils/orientation_policy.dart';

const _portrait = [
  'DeviceOrientation.portraitUp',
  'DeviceOrientation.portraitDown',
];

/// Records the orientations the app asks the platform for.
List<List<Object?>> _recordOrientations(
  WidgetTester tester, {
  bool fail = false,
}) {
  final calls = <List<Object?>>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemChrome.setPreferredOrientations') {
      calls.add(call.arguments as List<Object?>);
      if (fail) throw PlatformException(code: 'unsupported');
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  addTearDown(OrientationPolicy.debugUninstall);
  addTearDown(tester.view.reset);
  addTearDown(tester.view.display.reset);
  return calls;
}

/// A [width] × [height] dp display at [ratio].
void _display(
  WidgetTester tester,
  double width,
  double height, {
  double ratio = 3,
}) {
  tester.view.display.devicePixelRatio = ratio;
  tester.view.display.size = Size(width * ratio, height * ratio);
}

class _Display implements Display {
  _Display(this.size, this.devicePixelRatio);

  @override
  final Size size;

  @override
  final double devicePixelRatio;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _View implements FlutterView {
  _View(this.physicalSize, this.devicePixelRatio);

  @override
  final Size physicalSize;

  @override
  final double devicePixelRatio;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Dispatcher implements PlatformDispatcher {
  _Dispatcher({this.displays = const [], this.implicitView});

  @override
  final Iterable<Display> displays;

  @override
  final FlutterView? implicitView;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a tablet allows every orientation, a phone portrait', () {
    expect(kTabletShortestSide, 600);
    expect(orientationsFor(600), isEmpty);
    expect(orientationsFor(744), isEmpty);
    expect(orientationsFor(1032), isEmpty);
    for (final side in [599.0, 411.0, 320.0, null]) {
      expect(orientationsFor(side), [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ], reason: '$side');
    }
  });

  test("the display's shortest side, else the app's view's", () {
    // A 1080 × 2400 px phone at 2.625: about 411 dp across.
    expect(
      OrientationPolicy.shortestDisplaySide(
        _Dispatcher(displays: [_Display(const Size(1080, 2400), 2.625)]),
      ),
      closeTo(411.43, 0.01),
    );
    // An iPad mini in landscape: 1133 × 744 dp.
    expect(
      OrientationPolicy.shortestDisplaySide(
        _Dispatcher(displays: [_Display(const Size(2266, 1488), 2)]),
      ),
      744,
    );
    // No display known yet (or one without a size): the view.
    expect(
      OrientationPolicy.shortestDisplaySide(
        _Dispatcher(
          displays: [_Display(Size.zero, 2)],
          implicitView: _View(const Size(1640, 2360), 2),
        ),
      ),
      820,
    );
    expect(
      OrientationPolicy.shortestDisplaySide(
        _Dispatcher(implicitView: _View(Size.zero, 0)),
      ),
      isNull,
    );
    expect(OrientationPolicy.shortestDisplaySide(_Dispatcher()), isNull);
  });

  testWidgets('a phone stays in portrait', (tester) async {
    final calls = _recordOrientations(tester);
    _display(tester, 411, 914);
    await OrientationPolicy.install();
    expect(calls, [_portrait]);
  });

  testWidgets('a tablet rotates', (tester) async {
    final calls = _recordOrientations(tester);
    _display(tester, 820, 1180, ratio: 2);
    await OrientationPolicy.install();
    expect(calls, [<Object?>[]]);
  });

  testWidgets('a display that changes the decision applies it again: a '
      'foldable unfolded and folded', (tester) async {
    final calls = _recordOrientations(tester);
    _display(tester, 374, 832);
    await OrientationPolicy.install();
    expect(calls, [_portrait]);

    // Unfolded: a 673 × 841 dp inner display.
    _display(tester, 673, 841);
    await tester.pump();
    expect(calls, [_portrait, <Object?>[]]);

    // Turned sideways: still a tablet, nothing to tell the platform.
    _display(tester, 841, 673);
    await tester.pump();
    expect(calls, hasLength(2));

    // Folded again.
    _display(tester, 374, 832);
    await tester.pump();
    expect(calls, [_portrait, <Object?>[], _portrait]);
  });

  testWidgets("the window doesn't decide: Split View on a tablet, the "
      'keyboard', (tester) async {
    final calls = _recordOrientations(tester);
    _display(tester, 1180, 820, ratio: 2);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(2360, 1640);
    await OrientationPolicy.install();
    expect(calls, [<Object?>[]]);

    // The app in a 375 dp Split View window, then with the keyboard up.
    tester.view.physicalSize = const Size(750, 1640);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pump();
    expect(calls, [<Object?>[]]);
  });

  testWidgets('installing twice follows the display once', (tester) async {
    final calls = _recordOrientations(tester);
    _display(tester, 411, 914);
    await OrientationPolicy.install();
    await OrientationPolicy.install();
    expect(calls, [_portrait]);
    _display(tester, 800, 1280);
    await tester.pump();
    expect(calls, [_portrait, <Object?>[]]);
  });

  testWidgets('a platform without orientations never fails the start', (
    tester,
  ) async {
    final calls = _recordOrientations(tester, fail: true);
    _display(tester, 411, 914);
    await expectLater(OrientationPolicy.install(), completes);
    expect(calls, [_portrait]);
  });

  testWidgets('after uninstalling, display changes are ignored', (
    tester,
  ) async {
    final calls = _recordOrientations(tester);
    _display(tester, 411, 914);
    await OrientationPolicy.install();
    OrientationPolicy.debugUninstall();
    _display(tester, 800, 1280);
    await tester.pump();
    expect(calls, [_portrait]);
  });
}
