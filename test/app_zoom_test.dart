// Display size (AppZoom) and its parts, on a phone like the owner's: about
// 411 × 914 dp with the system font size at 125%.
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/gestures.dart' show DeviceGestureSettings;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/shared/widgets/app_zoom.dart';

/// 1440 × 3200 px at 3.5 dpr (≈ 411 × 914 dp), font size 125%.
void _phone(WidgetTester tester, {Size physicalSize = const Size(1440, 3200)}) {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 3.5;
  tester.platformDispatcher.textScaleFactorTestValue = 1.25;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Size _window(WidgetTester tester) =>
    tester.view.physicalSize / tester.view.devicePixelRatio;

Matcher _sizeCloseTo(Size size) => within<Size>(distance: 1e-6, from: size);

int _inits = 0;
int _deactivations = 0;

/// Counts mounts and moves: a remount runs initState again, and a GlobalKey
/// reparent runs deactivate.
class _Counting extends StatefulWidget {
  const _Counting({super.key});

  @override
  State<_Counting> createState() => _CountingState();
}

class _CountingState extends State<_Counting> {
  @override
  void initState() {
    super.initState();
    _inits++;
  }

  @override
  void deactivate() {
    _deactivations++;
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 10);
}

/// 100 × 40 (as far as the constraints allow) with its baseline at 30. Its
/// intrinsic sizes keep that 2.5 : 1 shape.
class _BaselineBox extends LeafRenderObjectWidget {
  const _BaselineBox();

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBaselineBox();
}

class _RenderBaselineBox extends RenderBox {
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(const Size(100, 40));

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => 30;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => 30;

  @override
  double computeMinIntrinsicWidth(double height) =>
      height.isFinite ? 2.5 * height : 100;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      computeMinIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      width.isFinite ? 0.4 * width : 40;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);
}

void main() {
  group('percent rules', () {
    test('snapPercent rounds to the 5% step and clamps to 80–130', () {
      expect(snapPercent(100), 100);
      expect(snapPercent(93), 95);
      expect(snapPercent(92.4), 90);
      expect(snapPercent(112), 110);
      expect(snapPercent(112.5), 115);
      expect(snapPercent(37), 80);
      expect(snapPercent(1.5), 80);
      expect(snapPercent(-5), 80);
      expect(snapPercent(200), 130);
      expect(snapPercent(1e300), 130);
      expect(snapPercent(double.nan), 100);
      expect(snapPercent(double.infinity), 100);
      expect(snapPercent(double.negativeInfinity), 100);
    });

    test('maxDisplayPercentFor keeps the layout at least 320 dp wide', () {
      const cases = <(double, int)>[
        (320, 100),
        (336, 105),
        (360, 110),
        (384, 120),
        (400, 125),
        (1440 / 3.5, 125), // the test phone, ≈ 411 dp
        (412, 125),
        (416, 130),
        (700, 130),
        (300, 100), // narrower than 320: no zoom-in, but no forced zoom-out
        (0, 100),
        (-10, 100),
        (double.nan, 100),
        (double.infinity, 100),
      ];
      for (final (width, percent) in cases) {
        expect(maxDisplayPercentFor(width), percent, reason: 'width $width');
      }
      for (var width = 320.0; width <= 800; width += 0.25) {
        expect(
          width * 100 / maxDisplayPercentFor(width),
          greaterThanOrEqualTo(kMinZoomedLayoutWidth - 1e-6),
          reason: 'width $width',
        );
      }
    });

    test(
      'effectiveDisplayPercent caps zoom-in by the window, never zoom-out',
      () {
        expect(effectiveDisplayPercent(130, 360), 110);
        expect(effectiveDisplayPercent(130, 400), 125);
        expect(effectiveDisplayPercent(130, 700), 130);
        expect(effectiveDisplayPercent(85, 360), 85);
        expect(effectiveDisplayPercent(80, 300), 80);
        expect(effectiveDisplayPercent(120, 0), 100);
        expect(effectiveDisplayPercent(93, 400), 95);
        expect(effectiveDisplayPercent(500, 400), 125);
        expect(effectiveDisplayPercent(10, 400), 80);
      },
    );
  });

  group('zoomMediaQuery', () {
    const hinge = DisplayFeature(
      bounds: Rect.fromLTRB(0, 430, 400, 450),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    );
    // Every field off its default, so a field that isn't carried over shows.
    MediaQueryData window({BorderRadius? cornerRadii}) => MediaQueryData(
      size: const Size(400, 880),
      devicePixelRatio: 3,
      textScaler: const TextScaler.linear(1.25),
      platformBrightness: Brightness.dark,
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
      viewInsets: const EdgeInsets.only(bottom: 300),
      systemGestureInsets: const EdgeInsets.symmetric(horizontal: 20),
      alwaysUse24HourFormat: true,
      accessibleNavigation: true,
      invertColors: true,
      highContrast: true,
      onOffSwitchLabels: true,
      disableAnimations: true,
      boldText: true,
      supportsAnnounce: true,
      navigationMode: NavigationMode.directional,
      gestureSettings: const DeviceGestureSettings(touchSlop: 8),
      displayFeatures: const [hinge],
      supportsShowingSystemContextMenu: true,
      lineHeightScaleFactorOverride: 1.5,
      letterSpacingOverride: 0.5,
      wordSpacingOverride: 2,
      paragraphSpacingOverride: 4,
      displayCornerRadii: cornerRadii,
    );

    for (final scale in [0.85, 1.1]) {
      test('at $scale: window lengths ÷ scale, devicePixelRatio × scale', () {
        final outer = window(
          cornerRadii: const BorderRadius.all(Radius.circular(40)),
        );
        final zoomed = zoomMediaQuery(outer, scale);

        expect(zoomed.size.width, closeTo(400 / scale, 1e-9));
        expect(zoomed.size.height, closeTo(880 / scale, 1e-9));
        expect(
          zoomed.padding,
          EdgeInsets.only(top: 24 / scale, bottom: 16 / scale),
        );
        expect(
          zoomed.viewPadding,
          EdgeInsets.only(top: 24 / scale, bottom: 48 / scale),
        );
        expect(zoomed.viewInsets, EdgeInsets.only(bottom: 300 / scale));
        expect(
          zoomed.systemGestureInsets,
          EdgeInsets.symmetric(horizontal: 20 / scale),
        );
        expect(zoomed.displayCornerRadii, BorderRadius.circular(40 / scale));
        final feature = zoomed.displayFeatures.single;
        expect(
          feature.bounds,
          Rect.fromLTRB(0, 430 / scale, 400 / scale, 450 / scale),
        );
        expect(feature.type, DisplayFeatureType.hinge);
        expect(feature.state, DisplayFeatureState.postureFlat);

        expect(zoomed.devicePixelRatio, closeTo(3 * scale, 1e-9));
        // Still the screen's physical pixels, so images decode sharp.
        expect(
          zoomed.size.width * zoomed.devicePixelRatio,
          closeTo(1200, 1e-6),
        );

        // Drag slop is compared in window units.
        expect(zoomed.gestureSettings, outer.gestureSettings);
        // The phone's font size passes through unless replaced.
        expect(zoomed.textScaler, same(outer.textScaler));
        expect(
          zoomMediaQuery(
            outer,
            scale,
            textScaler: TextScaler.noScaling,
          ).textScaler,
          TextScaler.noScaling,
        );
      });
    }

    test('carries every field it does not rescale', () {
      // copyWith carries every field (any a later SDK adds too) except
      // displayCornerRadii, which is null here.
      final outer = window();
      final zoomed = zoomMediaQuery(outer, 0.85);
      expect(
        zoomed,
        outer.copyWith(
          size: zoomed.size,
          devicePixelRatio: zoomed.devicePixelRatio,
          padding: zoomed.padding,
          viewPadding: zoomed.viewPadding,
          viewInsets: zoomed.viewInsets,
          systemGestureInsets: zoomed.systemGestureInsets,
          displayFeatures: zoomed.displayFeatures,
        ),
      );
      expect(zoomed.displayCornerRadii, isNull);
      // Kept on purpose: iOS keeps its system edit menu when zoomed (see
      // app_zoom.dart's library comment and app_zoom_platform_test.dart).
      expect(zoomed.supportsShowingSystemContextMenu, isTrue);
    });

    test('at 1.0 the subtree gets the window\'s own data', () {
      final outer = window();
      expect(zoomMediaQuery(outer, 1.0), same(outer));
      expect(
        zoomMediaQuery(outer, 1.0, textScaler: outer.textScaler),
        same(outer),
      );
      final custom = zoomMediaQuery(
        outer,
        1.0,
        textScaler: const TextScaler.linear(0.9),
      );
      expect(custom.textScaler, const TextScaler.linear(0.9));
      expect(custom.size, outer.size);
    });
  });

  group('AppZoom', () {
    testWidgets('85%: the subtree sees the window in its own, larger dp', (
      tester,
    ) async {
      _phone(tester);
      tester.view.padding = const FakeViewPadding(top: 84, bottom: 56);
      tester.view.viewInsets = const FakeViewPadding(bottom: 1050);
      late MediaQueryData outer, inner;
      late AppZoomScope scope;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            outer = MediaQuery.of(context);
            return AppZoom(
              displayPercent: 85,
              child: Builder(
                builder: (context) {
                  inner = MediaQuery.of(context);
                  scope = AppZoomScope.maybeOf(context)!;
                  return const SizedBox.expand();
                },
              ),
            );
          },
        ),
      );

      expect(outer.size, _window(tester));
      expect(inner.size, _sizeCloseTo(_window(tester) / 0.85));
      expect(inner.padding.top, closeTo(24 / 0.85, 1e-9));
      expect(inner.padding.bottom, closeTo(16 / 0.85, 1e-9));
      expect(inner.viewInsets.bottom, closeTo(300 / 0.85, 1e-9));
      expect(inner.devicePixelRatio, closeTo(3.5 * 0.85, 1e-9));
      expect(inner.gestureSettings, outer.gestureSettings);
      expect(inner.textScaler, same(outer.textScaler));
      expect(scope.scale, 0.85);
      expect(scope.displayPercent, 85);
      expect(scope.outer, outer);
    });

    testWidgets('85%: the child fills the window and taps land where drawn', (
      tester,
    ) async {
      _phone(tester);
      final taps = <int>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppZoom(
            displayPercent: 85,
            child: Column(
              children: [
                for (var row = 0; row < 4; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < 4; col++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => taps.add(row * 4 + col),
                              child: SizedBox.expand(
                                key: ValueKey(row * 4 + col),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

      final window = _window(tester);
      // Laid out at window ÷ 0.85 ...
      expect(tester.getSize(find.byType(Column)), _sizeCloseTo(window / 0.85));
      // ... and painted over exactly the window.
      expect(
        tester.getRect(find.byType(Column)),
        rectMoreOrLessEquals(Offset.zero & window),
      );

      for (var row = 0; row < 4; row++) {
        for (var col = 0; col < 4; col++) {
          final center = Offset(
            (col + 0.5) * window.width / 4,
            (row + 0.5) * window.height / 4,
          );
          expect(
            tester.getCenter(find.byKey(ValueKey(row * 4 + col))),
            offsetMoreOrLessEquals(center),
          );
          await tester.tapAt(center);
          expect(taps.last, row * 4 + col, reason: 'cell $row, $col');
        }
      }
      expect(taps, List.generate(16, (i) => i));
    });

    testWidgets('changing the size never remounts the subtree', (tester) async {
      _phone(tester);
      _inits = 0;
      _deactivations = 0;
      final key = GlobalKey<_CountingState>();
      Widget app(int percent) => Directionality(
        textDirection: TextDirection.ltr,
        child: AppZoom(
          displayPercent: percent,
          child: Column(
            children: [
              _Counting(key: key),
              const _Counting(),
            ],
          ),
        ),
      );

      await tester.pumpWidget(app(100));
      final keyed = key.currentState!;
      final unkeyed = tester.state(find.byType(_Counting).last);
      final zoomBox = tester.renderObject<RenderZoomBox>(find.byType(ZoomBox));

      for (final percent in [85, 100, 120, 130, 80, 100]) {
        await tester.pumpWidget(app(percent));
        expect(key.currentState, same(keyed));
        expect(tester.state(find.byType(_Counting).last), same(unkeyed));
        expect(tester.renderObject(find.byType(ZoomBox)), same(zoomBox));
        expect(
          zoomBox.scale,
          effectiveDisplayPercent(percent, _window(tester).width) / 100,
        );
      }
      expect(_inits, 2);
      expect(_deactivations, 0);
    });

    testWidgets(
      'textPercent replaces the phone\'s font size; null follows it',
      (tester) async {
        _phone(tester);
        late TextScaler outer, inner;
        Widget app(int displayPercent, int? textPercent) => Builder(
          builder: (context) {
            outer = MediaQuery.textScalerOf(context);
            return AppZoom(
              displayPercent: displayPercent,
              textPercent: textPercent,
              child: Builder(
                builder: (context) {
                  inner = MediaQuery.textScalerOf(context);
                  return const SizedBox.expand();
                },
              ),
            );
          },
        );

        for (final displayPercent in [100, 85]) {
          await tester.pumpWidget(app(displayPercent, null));
          expect(outer.scale(10), closeTo(12.5, 1e-9));
          expect(inner, same(outer));

          await tester.pumpWidget(app(displayPercent, 100));
          expect(inner, const TextScaler.linear(1.0));
          expect(inner.scale(10), 10);

          // Snapped like the stored value.
          await tester.pumpWidget(app(displayPercent, 112));
          expect(inner, const TextScaler.linear(1.1));
        }
      },
    );

    testWidgets('100% paints without a transform layer; 85% pushes one', (
      tester,
    ) async {
      _phone(tester);
      // A repaint boundary below, as every route has, so the subtree is
      // composited and a scale needs a layer.
      Widget app(int percent) => AppZoom(
        displayPercent: percent,
        child: const RepaintBoundary(child: SizedBox.expand()),
      );

      await tester.pumpWidget(app(100));
      final box = tester.renderObject<RenderZoomBox>(find.byType(ZoomBox));
      expect(box.needsCompositing, isTrue);
      expect(box.debugLayer, isNull);

      await tester.pumpWidget(app(85));
      expect(box.debugLayer, isA<TransformLayer>());
      expect(
        (box.debugLayer! as TransformLayer).transform,
        Matrix4.diagonal3Values(0.85, 0.85, 1),
      );

      await tester.pumpWidget(app(100));
      expect(box.debugLayer, isNull);
    });

    testWidgets('a 360 dp phone caps 130% at 110%', (tester) async {
      _phone(tester, physicalSize: const Size(1260, 2800)); // 360 × 800 dp
      late double scale;
      late int percent;
      late Size inner;
      await tester.pumpWidget(
        AppZoom(
          displayPercent: 130,
          child: Builder(
            builder: (context) {
              scale = AppZoomScope.scaleOf(context);
              percent = AppZoomScope.maybeOf(context)!.displayPercent;
              inner = MediaQuery.sizeOf(context);
              return const SizedBox.expand();
            },
          ),
        ),
      );

      expect(_window(tester).width, 360);
      expect(percent, 110);
      expect(scale, 1.1);
      expect(inner.width, closeTo(360 / 1.1, 1e-9));
      expect(inner.width, greaterThanOrEqualTo(kMinZoomedLayoutWidth));
    });
  });

  group('AppZoomScope', () {
    const window = MediaQueryData(
      size: Size(400, 880),
      devicePixelRatio: 3,
      textScaler: TextScaler.linear(1.25),
      padding: EdgeInsets.only(top: 24, bottom: 48),
      viewPadding: EdgeInsets.only(top: 24, bottom: 48),
      systemGestureInsets: EdgeInsets.symmetric(horizontal: 20),
    );
    AppZoomScope scope(
      MediaQueryData outer, {
      double scale = 1.0,
      int displayPercent = 100,
    }) => AppZoomScope(
      scale: scale,
      displayPercent: displayPercent,
      outer: outer,
      child: const SizedBox(),
    );

    test('notifies for the zoom and the window, not its padding or insets', () {
      final old = scope(window);
      // What a keyboard frame changes: insets, and the padding they cover.
      for (final outer in [
        window.copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
        window.copyWith(
          padding: const EdgeInsets.only(top: 24),
          viewInsets: const EdgeInsets.only(bottom: 120),
        ),
        window.copyWith(viewPadding: const EdgeInsets.only(top: 24)),
        window.copyWith(systemGestureInsets: EdgeInsets.zero),
      ]) {
        expect(scope(outer).updateShouldNotify(old), isFalse, reason: '$outer');
      }
      expect(scope(window).updateShouldNotify(old), isFalse);

      for (final changed in [
        scope(window, scale: 0.85, displayPercent: 85),
        scope(window, displayPercent: 105),
        scope(window.copyWith(size: const Size(880, 400))),
        scope(window.copyWith(devicePixelRatio: 2)),
        scope(window.copyWith(textScaler: const TextScaler.linear(1.5))),
        scope(window.copyWith(platformBrightness: Brightness.dark)),
        scope(window.copyWith(supportsShowingSystemContextMenu: true)),
      ]) {
        expect(changed.updateShouldNotify(old), isTrue, reason: '$changed');
      }
    });

    testWidgets(
      'keyboard frames rebuild no reader; a new size, font size or zoom does',
      (tester) async {
        _phone(tester);
        tester.view.padding = const FakeViewPadding(top: 84, bottom: 168);
        var scaleBuilds = 0;
        var windowBuilds = 0;
        late double scale;
        late MediaQueryData windowSeen;
        late EdgeInsets insetsSeen;
        // Built once, so only a dependency can rebuild the readers.
        final readers = Column(
          children: [
            Builder(
              builder: (context) {
                scaleBuilds++;
                scale = AppZoomScope.scaleOf(context);
                return const SizedBox(height: 10);
              },
            ),
            Builder(
              builder: (context) {
                windowBuilds++;
                windowSeen = AppZoomScope.maybeOf(context)!.outer;
                return const SizedBox(height: 10);
              },
            ),
            // Rebuilt by MediaQuery, so it sees the latest window anyway.
            Builder(
              builder: (context) {
                MediaQuery.viewInsetsOf(context);
                insetsSeen = AppZoomScope.maybeOf(context)!.outer.viewInsets;
                return const SizedBox(height: 10);
              },
            ),
          ],
        );
        Widget app(int percent) => Directionality(
          textDirection: TextDirection.ltr,
          child: AppZoom(displayPercent: percent, child: readers),
        );

        // The keyboard rising: insets grow, and the bottom padding they
        // cover shrinks, a little on every frame.
        Future<void> keyboard() async {
          for (var frame = 1; frame <= 12; frame++) {
            tester.view.viewInsets = FakeViewPadding(bottom: frame * 87.5);
            tester.view.padding = FakeViewPadding(
              top: 84,
              bottom: frame >= 2 ? 0 : 168,
            );
            await tester.pump();
            expect(insetsSeen.bottom, closeTo(frame * 25, 1e-9));
          }
          tester.view.resetViewInsets();
          tester.view.padding = const FakeViewPadding(top: 84, bottom: 168);
          await tester.pump();
          expect(insetsSeen, EdgeInsets.zero);
        }

        for (final percent in [100, 85]) {
          await tester.pumpWidget(app(percent));
          final before = (scaleBuilds, windowBuilds);
          await keyboard();
          expect((scaleBuilds, windowBuilds), before, reason: '$percent%');
          expect(scale, percent / 100);
        }

        /// [change] rebuilds each reader exactly once.
        Future<void> rebuildsOnce(Future<void> Function() change) async {
          final before = (scaleBuilds, windowBuilds);
          await change();
          expect((scaleBuilds, windowBuilds), (before.$1 + 1, before.$2 + 1));
        }

        await rebuildsOnce(() => tester.pumpWidget(app(120)));
        expect(scale, 1.2);

        await rebuildsOnce(() {
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          return tester.pump();
        });
        expect(windowSeen.textScaler.scale(10), closeTo(15, 1e-9));

        await rebuildsOnce(() {
          tester.view.physicalSize = const Size(3200, 1440); // turned sideways
          return tester.pump();
        });
        expect(windowSeen.size, _window(tester));
      },
    );
  });

  group('ZoomBox', () {
    testWidgets('sizes, intrinsics and baselines are in the parent\'s units', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _BaselineBox(),
                ZoomBox(scale: 1.5, child: _BaselineBox()),
              ],
            ),
          ),
        ),
      );

      final box = tester.renderObject<RenderZoomBox>(find.byType(ZoomBox));
      expect(box.size, const Size(150, 60));
      // Baselines aligned: the zoomed box's is at 30 × 1.5 = 45, so the
      // plain one (baseline 30) sits 15 lower.
      expect(tester.getTopLeft(find.byType(ZoomBox)).dy, 0);
      expect(tester.getTopLeft(find.byType(_BaselineBox).first).dy, 15);

      const loose = BoxConstraints(maxWidth: 800, maxHeight: 600);
      expect(box.getDryLayout(loose), const Size(150, 60));
      expect(
        box.getDryLayout(BoxConstraints.tight(const Size(300, 90))),
        const Size(300, 90),
      );
      // A minimum the child must meet: it is asked for 300 ÷ 1.5 = 200.
      expect(
        box.getDryLayout(
          const BoxConstraints(minWidth: 300, maxWidth: 800, maxHeight: 600),
        ),
        const Size(300, 60),
      );
      expect(box.getDryBaseline(loose, TextBaseline.alphabetic), 45);
      // The child is asked at extent ÷ 1.5, its answer is × 1.5.
      expect(box.getMinIntrinsicWidth(60), 150);
      expect(box.getMaxIntrinsicWidth(double.infinity), 150);
      expect(box.getMinIntrinsicHeight(150), 60);
      expect(box.getMaxIntrinsicHeight(300), 120);
    });
  });

  group('ZoomNeutral', () {
    testWidgets('inside AppZoom: the window\'s dp, translation only', (
      tester,
    ) async {
      _phone(tester);
      tester.view.padding = const FakeViewPadding(top: 84);
      late MediaQueryData outer, neutral;
      late double neutralScale;
      final key = GlobalKey();
      var taps = 0;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            outer = MediaQuery.of(context);
            return AppZoom(
              displayPercent: 85,
              textPercent: 110,
              child: Padding(
                padding: const EdgeInsets.only(left: 40, top: 60),
                child: ZoomNeutral(
                  child: Builder(
                    builder: (context) {
                      neutral = MediaQuery.of(context);
                      neutralScale = AppZoomScope.scaleOf(context);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps++,
                        child: SizedBox.expand(key: key),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );

      expect(neutral.size, _sizeCloseTo(outer.size));
      expect(neutral.devicePixelRatio, closeTo(outer.devicePixelRatio, 1e-9));
      expect(neutral.padding.top, closeTo(24, 1e-9));
      // The Text size setting still applies.
      expect(neutral.textScaler, const TextScaler.linear(1.1));
      expect(neutralScale, 1.0);

      final box = tester.renderObject<RenderBox>(find.byKey(key));
      final origin = box.localToGlobal(Offset.zero);
      // The padding is zoomed dp: 40 of them are 34 window dp.
      expect(
        origin,
        offsetMoreOrLessEquals(const Offset(40 * 0.85, 60 * 0.85)),
      );
      // Translation only: 100 dp inside is 100 dp on screen.
      expect(
        box.localToGlobal(const Offset(100, 200)) - origin,
        offsetMoreOrLessEquals(const Offset(100, 200)),
      );
      expect(
        box.size,
        _sizeCloseTo(Size(outer.size.width - 34, outer.size.height - 51)),
      );

      await tester.tapAt(origin + const Offset(5, 5));
      expect(taps, 1);
    });

    testWidgets('outside an AppZoom it changes nothing', (tester) async {
      _phone(tester);
      late MediaQueryData outer, inner;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            outer = MediaQuery.of(context);
            return ZoomNeutral(
              child: Builder(
                builder: (context) {
                  inner = MediaQuery.of(context);
                  return const RepaintBoundary(child: SizedBox.expand());
                },
              ),
            );
          },
        ),
      );

      expect(inner, same(outer));
      final box = tester.renderObject<RenderZoomBox>(find.byType(ZoomBox));
      expect(box.scale, 1.0);
      expect(box.debugLayer, isNull);
    });
  });
}
