// Settings → Display size and Text size: the two sheets and their Settings
// rows, on a phone like the owner's (≈ 411 × 914 dp, font size 125%), in an
// app zoomed from displayScaleProvider the way app.dart does it. The sheets
// open where the app opens them: in the branch Navigator beside the sidebar
// rail.
//
// A size applies only when it is committed: a finger lifting, a tap, an
// arrow key or a screen reader's adjust. A gesture that the sheet's drag or
// its scroll view takes from the slider, or that the system cancels, applies
// nothing.
import 'package:flutter/gestures.dart' show kPressTimeout, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsData;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/features/settings/presentation/settings_screen.dart';
import 'package:micro_seller/features/settings/presentation/widgets/display_size_sheets.dart';
import 'package:micro_seller/features/settings/providers/display_scale_provider.dart';
import 'package:micro_seller/shared/widgets/app_zoom.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sidebar's icon rail, beside every screen on a phone.
const _rail = 56.0;

/// 1440 × 3200 px at 3.5 dpr (≈ 411 × 914 dp), font size 125%. 1260 × 2800
/// px is a 360 dp phone.
void _phone(WidgetTester tester, {Size physicalSize = const Size(1440, 3200)}) {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 3.5;
  tester.platformDispatcher.textScaleFactorTestValue = 1.25;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// A phone font size as Android 14 scales it at its 130% step: small text
/// grows more than large text (AOSP's FontScaleConverter points, linear in
/// between), so 14 sp body text is 18.8 dp, 134%.
class _Android14At130 extends TextScaler {
  const _Android14At130();

  /// (sp, dp): a font size and the size the phone draws it at.
  static const _points = <(double, double)>[
    (0, 0),
    (8, 10.4),
    (10, 13),
    (12, 15.6),
    (14, 18.8),
    (18, 21.6),
    (20, 23.6),
    (24, 26.4),
    (30, 30),
    (100, 100),
  ];

  @override
  double scale(double fontSize) {
    for (var i = 1; i < _points.length; i++) {
      final (sp, dp) = _points[i];
      if (fontSize <= sp) {
        final (sp0, dp0) = _points[i - 1];
        return dp0 + (fontSize - sp0) / (sp - sp0) * (dp - dp0);
      }
    }
    return fontSize;
  }

  /// The step the phone's setting shows.
  @override
  double get textScaleFactor => 1.3;
}

/// The saved sizes applied around the app, as app.dart's _DisplayScaleScope
/// applies them.
class _Zoom extends ConsumerWidget {
  const _Zoom({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(displayScaleProvider);
    return AppZoom(
      displayPercent: scale.displayPercent,
      textPercent: scale.textPercent,
      child: child,
    );
  }
}

/// A screen with a button for each sheet.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () => showDisplaySizeSheet(context),
          child: const Text('open display size'),
        ),
        TextButton(
          onPressed: () => showTextSizeSheet(context),
          child: const Text('open text size'),
        ),
      ],
    ),
  );
}

/// Pumps [home] in the zoomed app, in a branch Navigator beside the rail,
/// and returns the app's provider container. [phoneText], when given, is the
/// phone's font size instead of the test window's.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  Widget home = const _Host(),
  Locale? locale,
  TextScaler? phoneText,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: locale,
        // As app.dart has them.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => phoneText == null
            ? _Zoom(child: child!)
            : MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: phoneText),
                child: _Zoom(child: child!),
              ),
        home: Row(
          children: [
            const SizedBox(width: _rail),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => home),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  // The app's strings load asynchronously: the next frame has the content.
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
}

Future<void> _open(WidgetTester tester, String button) async {
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
}

Finder get _sheet => find.byType(BottomSheet);
Finder _inSheet(Finder finder) => find.descendant(of: _sheet, matching: finder);
Finder get _slider => _inSheet(find.byType(Slider));
Slider _sliderOf(WidgetTester tester) => tester.widget<Slider>(_slider);

/// The preview box (the sample at the size being picked is inside it).
Finder get _frame => _inSheet(find.byType(OverflowBox));

/// The Display size preview's zoom. The app's own ZoomBox is around the
/// sheet, not in it.
Finder get _previewZoom =>
    find.descendant(of: _frame, matching: find.byType(ZoomBox));

/// What AppZoom applies to the sheet.
AppZoomScope _appZoom(WidgetTester tester) =>
    AppZoomScope.maybeOf(tester.element(_slider))!;

/// The text size the app applies to the sheet.
TextScaler _appText(WidgetTester tester) =>
    MediaQuery.textScalerOf(tester.element(_slider));

/// Where [percent] is on the sheet's slider, in window coordinates. The track
/// runs between the thumb overlay's radius (24 dp) in from either end.
Offset _at(WidgetTester tester, int percent) {
  final slider = _sliderOf(tester);
  final rect = tester.getRect(_slider);
  final inset = 24 * _appZoom(tester).scale;
  final t = (percent - slider.min) / (slider.max - slider.min);
  return Offset(
    rect.left + inset + t * (rect.width - 2 * inset),
    rect.center.dy,
  );
}

/// Puts a finger on the slider at [percent] and holds it past the press
/// timeout, where the thumb jumps under it as for a tap.
Future<TestGesture> _press(WidgetTester tester, int percent) async {
  final gesture = await tester.startGesture(_at(tester, percent));
  await tester.pump(kPressTimeout * 1.5);
  return gesture;
}

/// The sheet's slider as a screen reader finds it: one node, with its name.
SemanticsFinder get _sliderNode => find.semantics.byPredicate(
  (node) =>
      !node.isMergedIntoParent &&
      node.getSemanticsData().flagsCollection.isSlider,
);

/// What a screen reader gets from the sheet's slider.
SemanticsData _sliderSemantics() =>
    _sliderNode.evaluate().single.getSemanticsData();

/// Whether keyboard focus is on [finder]'s widget or inside it.
bool _focusIn(WidgetTester tester, Finder finder) {
  final target = tester.element(finder);
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  if (focused == target) return true;
  var inside = false;
  focused.visitAncestorElements((ancestor) {
    inside = ancestor == target;
    return !inside;
  });
  return inside;
}

/// Presses Tab until the slider has keyboard focus.
Future<void> _tabToSlider(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (_focusIn(tester, _slider)) return;
  }
  fail('Tab never reached the slider');
}

void main() {
  setUpAll(() {
    // SettingsScreen reads the .env feature flags. Off: the Security rows
    // would query the biometric hardware.
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=false\nENABLE_PIN_GATE=false',
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DisplayScale.debugResetPrimed();
  });
  tearDown(DisplayScale.debugResetPrimed);

  group('Display size sheet', () {
    testWidgets('the slider stops at 125% on a 411 dp phone', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      await _open(tester, 'open display size');

      final slider = _sliderOf(tester);
      expect(slider.min, 80);
      expect(slider.max, 125);
      expect(slider.divisions, 9);
      expect(slider.value, 100);
      expect(_inSheet(find.text('125%')), findsOneWidget);
    });

    testWidgets('the slider stops at 110% on a 360 dp phone', (tester) async {
      _phone(tester, physicalSize: const Size(1260, 2800));
      await _pumpApp(tester);
      await _open(tester, 'open display size');

      final slider = _sliderOf(tester);
      expect(slider.max, 110);
      expect(slider.divisions, 6);
      expect(_inSheet(find.text('110%')), findsOneWidget);
    });

    testWidgets(
      'dragging zooms only the preview; the app takes the size on release',
      (tester) async {
        _phone(tester);
        final container = await _pumpApp(tester);
        await _open(tester, 'open display size');

        expect(_appZoom(tester).displayPercent, 100);
        expect(tester.widget<ZoomBox>(_previewZoom).scale, 1.0);
        final sliderCenter = tester.getCenter(_slider);
        final frameSize = tester.getSize(_frame);
        // The drag starts once the finger passes the touch slop: the first
        // move (two steps) does.
        expect(
          (_at(tester, 90) - _at(tester, 100)).distance,
          greaterThan(kTouchSlop),
        );

        final gesture = await tester.startGesture(_at(tester, 100));
        for (final percent in [90, 85, 95]) {
          await gesture.moveTo(_at(tester, percent));
          await tester.pump();
          final where = 'dragged to $percent%';

          // The preview follows the finger ...
          expect(
            tester.widget<ZoomBox>(_previewZoom).scale,
            closeTo(percent / 100, 1e-9),
            reason: where,
          );
          expect(_inSheet(find.text('$percent%')), findsOneWidget);
          expect(
            tester.getSize(_previewZoom).height,
            lessThan(frameSize.height),
            reason: where,
          );
          // ... the app keeps its size until the finger lifts ...
          expect(
            container.read(displayScaleProvider).displayPercent,
            100,
            reason: where,
          );
          expect(_appZoom(tester).displayPercent, 100, reason: where);
          expect(_appZoom(tester).scale, 1.0, reason: where);
          // ... and nothing in the sheet moves under it.
          expect(tester.getCenter(_slider), sliderCenter, reason: where);
          expect(tester.getSize(_frame), frameSize, reason: where);
        }

        await gesture.up();
        await tester.pumpAndSettle();

        expect(container.read(displayScaleProvider).displayPercent, 95);
        expect(_appZoom(tester).displayPercent, 95);
        expect(_appZoom(tester).scale, 0.95);
        // The app is drawn at 95% now, so the preview needs no zoom of its
        // own: it shows the same size it showed under the finger.
        expect(tester.widget<ZoomBox>(_previewZoom).scale, 1.0);
        expect(_sliderOf(tester).value, 95);
      },
    );

    testWidgets('a larger size runs off the preview, never grows the sheet', (
      tester,
    ) async {
      _phone(tester);
      await _pumpApp(tester);
      await _open(tester, 'open display size');
      final sliderCenter = tester.getCenter(_slider);
      final frameSize = tester.getSize(_frame);

      final gesture = await tester.startGesture(_at(tester, 100));
      for (final percent in [110, 120, 125]) {
        await gesture.moveTo(_at(tester, percent));
        await tester.pump();
        expect(
          tester.widget<ZoomBox>(_previewZoom).scale,
          closeTo(percent / 100, 1e-9),
        );
        expect(
          tester.getSize(_previewZoom).height,
          greaterThan(frameSize.height),
        );
        expect(tester.getSize(_frame), frameSize);
        expect(tester.getCenter(_slider), sliderCenter);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_appZoom(tester).displayPercent, 125);
    });

    testWidgets('Reset goes back to 100%; Done closes the sheet', (
      tester,
    ) async {
      _phone(tester);
      final container = await _pumpApp(tester);
      container.read(displayScaleProvider.notifier).setDisplayPercent(90);
      await tester.pump();
      await _open(tester, 'open display size');
      final s = AppStrings.of(tester.element(_slider));
      final reset = _inSheet(
        find.widgetWithText(OutlinedButton, s.resetToDefault),
      );

      expect(_sliderOf(tester).value, 90);
      expect(_inSheet(find.text('90%')), findsOneWidget);
      expect(tester.widget<OutlinedButton>(reset).onPressed, isNotNull);

      await tester.tap(reset);
      await tester.pumpAndSettle();

      expect(container.read(displayScaleProvider).displayPercent, 100);
      expect(_appZoom(tester).displayPercent, 100);
      expect(_sliderOf(tester).value, 100);
      expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);

      await tester.tap(_inSheet(find.widgetWithText(FilledButton, s.done)));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
    });

    testWidgets('a tap applies at once; so does a finger held, then lifted', (
      tester,
    ) async {
      _phone(tester);
      final container = await _pumpApp(tester);
      await _open(tester, 'open display size');

      await tester.tapAt(_at(tester, 90));
      await tester.pumpAndSettle();
      expect(container.read(displayScaleProvider).displayPercent, 90);
      expect(_appZoom(tester).displayPercent, 90);

      final gesture = await _press(tester, 110);
      expect(_sliderOf(tester).value, 110);
      expect(container.read(displayScaleProvider).displayPercent, 90);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(container.read(displayScaleProvider).displayPercent, 110);
      expect(_appZoom(tester).displayPercent, 110);
    });

    testWidgets(
      'a finger held, then moved down, drags the sheet: nothing is applied',
      (tester) async {
        _phone(tester);
        final container = await _pumpApp(tester);
        await _open(tester, 'open display size');
        final sheetTop = tester.getTopLeft(_sheet).dy;

        // Held past the press timeout, the thumb jumps under the finger ...
        final gesture = await _press(tester, 120);
        expect(_sliderOf(tester).value, 120);
        expect(_inSheet(find.text('120%')), findsOneWidget);
        // ... but the move down is the sheet's drag. The slider gives the
        // size back, and the app never takes it, though the finger is down.
        for (var moved = 30; moved <= 60; moved += 30) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump();
          final where = 'moved $moved dp down';
          expect(
            container.read(displayScaleProvider).displayPercent,
            100,
            reason: where,
          );
          expect(_appZoom(tester).displayPercent, 100, reason: where);
          expect(_sliderOf(tester).value, 100, reason: where);
          expect(_inSheet(find.text('100%')), findsOneWidget, reason: where);
        }
        expect(tester.getTopLeft(_sheet).dy, greaterThan(sheetTop));

        await gesture.up();
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).displayPercent, 100);
        expect(tester.getTopLeft(_sheet).dy, sheetTop);
        expect(_sliderOf(tester).value, 100);

        // The next tap applies as usual.
        await tester.tapAt(_at(tester, 90));
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).displayPercent, 90);
      },
    );

    testWidgets(
      'a finger held, then moved up, scrolls the sheet: nothing is applied',
      (tester) async {
        _phone(tester);
        final container = await _pumpApp(tester);
        container.read(displayScaleProvider.notifier).setDisplayPercent(120);
        await tester.pump();
        await _open(tester, 'open display size');
        final scroll = tester
            .state<ScrollableState>(_inSheet(find.byType(Scrollable)))
            .position;
        // At 120% the sheet is taller than the window, so it scrolls.
        expect(scroll.maxScrollExtent, greaterThan(0));

        final gesture = await _press(tester, 100);
        expect(_sliderOf(tester).value, 100);
        for (var moved = 30; moved <= 60; moved += 30) {
          await gesture.moveBy(const Offset(0, -30));
          await tester.pump();
          final where = 'moved $moved dp up';
          expect(
            container.read(displayScaleProvider).displayPercent,
            120,
            reason: where,
          );
          expect(_appZoom(tester).displayPercent, 120, reason: where);
          expect(_sliderOf(tester).value, 120, reason: where);
        }
        // The first move only won the gesture; the second scrolled.
        expect(scroll.pixels, greaterThan(0));

        await gesture.up();
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).displayPercent, 120);
        expect(_sliderOf(tester).value, 120);
      },
    );

    testWidgets('a drag the system cancels applies nothing', (tester) async {
      _phone(tester);
      final container = await _pumpApp(tester);
      await _open(tester, 'open display size');

      final gesture = await tester.startGesture(_at(tester, 100));
      await gesture.moveTo(_at(tester, 90));
      await tester.pump();
      expect(_sliderOf(tester).value, 90);

      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(container.read(displayScaleProvider).displayPercent, 100);
      expect(_appZoom(tester).displayPercent, 100);
      expect(_sliderOf(tester).value, 100);

      // The next tap applies as usual.
      await tester.tapAt(_at(tester, 110));
      await tester.pumpAndSettle();
      expect(container.read(displayScaleProvider).displayPercent, 110);
    });

    testWidgets('Tab skips the preview; an arrow key applies at once', (
      tester,
    ) async {
      _phone(tester);
      final container = await _pumpApp(tester);
      await _open(tester, 'open display size');

      // The preview is a picture: its sample button takes no focus.
      var reachedSlider = false;
      for (var tab = 1; tab <= 6; tab++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusIn(tester, _frame), isFalse, reason: 'Tab $tab');
        reachedSlider |= _focusIn(tester, _slider);
      }
      expect(reachedSlider, isTrue);

      await _tabToSlider(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(container.read(displayScaleProvider).displayPercent, 105);
      expect(_appZoom(tester).displayPercent, 105);
      expect(_sliderOf(tester).value, 105);
      // The app took the new size around the slider, which kept its focus.
      expect(_focusIn(tester, _slider), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(container.read(displayScaleProvider).displayPercent, 100);
      expect(_appZoom(tester).displayPercent, 100);
    });

    testWidgets(
      'a screen reader hears the setting and its size; its adjust applies',
      (tester) async {
        final semantics = tester.ensureSemantics();
        _phone(tester);
        final container = await _pumpApp(tester);
        await _open(tester, 'open display size');
        final s = AppStrings.of(tester.element(_slider));

        // Named, with the size itself as the value (not "40%", the thumb's
        // place on the track), and said once: no value bubble, whose text
        // would also be the label.
        expect(_sliderSemantics().label, s.displaySize);
        expect(_sliderSemantics().value, '100%');
        expect(_sliderSemantics().increasedValue, '105%');
        expect(_sliderSemantics().decreasedValue, '95%');
        expect(_sliderOf(tester).label, isNull);
        expect(_sliderOf(tester).showValueIndicator, ShowValueIndicator.never);

        tester.semantics.increase(_sliderNode);
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).displayPercent, 105);
        expect(_appZoom(tester).displayPercent, 105);
        expect(_sliderSemantics().value, '105%');

        tester.semantics.decrease(_sliderNode);
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).displayPercent, 100);
        expect(_sliderSemantics().value, '100%');
        semantics.dispose();
      },
    );
  });

  group('Text size sheet', () {
    testWidgets(
      'follow phone; off is 100%; the slider applies on release; Reset follows again',
      (tester) async {
        _phone(tester);
        final container = await _pumpApp(tester);
        await _open(tester, 'open text size');
        final s = AppStrings.of(tester.element(_slider));
        final follow = _inSheet(find.byType(SwitchListTile));
        final reset = _inSheet(
          find.widgetWithText(OutlinedButton, s.resetToDefault),
        );
        TextScaler preview() => MediaQuery.textScalerOf(
          tester.element(
            find.descendant(of: _frame, matching: find.text(s.totalReceivable)),
          ),
        );

        // Following the phone: its 125%, with the slider and Reset off.
        expect(container.read(displayScaleProvider).textPercent, isNull);
        expect(tester.widget<SwitchListTile>(follow).value, isTrue);
        expect(_inSheet(find.text(s.phoneTextSize('125%'))), findsOneWidget);
        expect(_inSheet(find.text('125%')), findsOneWidget);
        expect(_sliderOf(tester).onChanged, isNull);
        expect(_sliderOf(tester).value, 125);
        expect(_appText(tester).scale(14), closeTo(17.5, 1e-9));
        expect(preview().scale(14), closeTo(17.5, 1e-9));
        expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);

        // Off: a custom size, from 100%.
        await tester.tap(follow);
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).textPercent, 100);
        expect(tester.widget<SwitchListTile>(follow).value, isFalse);
        expect(_appText(tester), const TextScaler.linear(1.0));
        expect(_sliderOf(tester).onChanged, isNotNull);
        expect(_sliderOf(tester).value, 100);
        expect(tester.widget<OutlinedButton>(reset).onPressed, isNotNull);

        // Dragging changes only the preview's text, and moves nothing.
        final sliderCenter = tester.getCenter(_slider);
        final frameSize = tester.getSize(_frame);
        expect(
          (_at(tester, 110) - _at(tester, 100)).distance,
          greaterThan(kTouchSlop),
        );
        final gesture = await tester.startGesture(_at(tester, 100));
        for (final percent in [110, 120, 115]) {
          await gesture.moveTo(_at(tester, percent));
          await tester.pump();
          final where = 'dragged to $percent%';
          expect(preview(), TextScaler.linear(percent / 100), reason: where);
          expect(
            container.read(displayScaleProvider).textPercent,
            100,
            reason: where,
          );
          expect(_appText(tester), const TextScaler.linear(1.0), reason: where);
          expect(tester.getCenter(_slider), sliderCenter, reason: where);
          expect(tester.getSize(_frame), frameSize, reason: where);
        }

        // Release: the app takes it.
        await gesture.up();
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).textPercent, 115);
        expect(_appText(tester), const TextScaler.linear(1.15));
        expect(preview(), const TextScaler.linear(1.15));
        expect(_sliderOf(tester).value, 115);

        // Reset: follow the phone again.
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).textPercent, isNull);
        expect(tester.widget<SwitchListTile>(follow).value, isTrue);
        expect(_appText(tester).scale(14), closeTo(17.5, 1e-9));
        expect(_sliderOf(tester).onChanged, isNull);
        expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);
      },
    );

    testWidgets('turning follow back on drops the custom size', (tester) async {
      _phone(tester);
      final container = await _pumpApp(tester);
      container.read(displayScaleProvider.notifier).setTextPercent(90);
      await tester.pump();
      await _open(tester, 'open text size');
      expect(_sliderOf(tester).value, 90);
      expect(_appText(tester), const TextScaler.linear(0.9));

      await tester.tap(_inSheet(find.byType(SwitchListTile)));
      await tester.pumpAndSettle();
      expect(container.read(displayScaleProvider).textPercent, isNull);
      expect(_appText(tester).scale(14), closeTo(17.5, 1e-9));
    });

    testWidgets(
      'a finger held, then moved down, drags the sheet: nothing is applied',
      (tester) async {
        _phone(tester);
        final container = await _pumpApp(tester);
        container.read(displayScaleProvider.notifier).setTextPercent(100);
        await tester.pump();
        await _open(tester, 'open text size');

        final gesture = await _press(tester, 120);
        expect(_sliderOf(tester).value, 120);
        for (var moved = 30; moved <= 60; moved += 30) {
          await gesture.moveBy(const Offset(0, 30));
          await tester.pump();
          final where = 'moved $moved dp down';
          expect(
            container.read(displayScaleProvider).textPercent,
            100,
            reason: where,
          );
          expect(_appText(tester), const TextScaler.linear(1.0), reason: where);
          expect(_sliderOf(tester).value, 100, reason: where);
        }

        await gesture.up();
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).textPercent, 100);
        expect(_appText(tester), const TextScaler.linear(1.0));
        expect(_sheet, findsOneWidget);
      },
    );

    testWidgets(
      'screen readers skip the slider while following the phone; a custom '
      'size is named, and its adjust and arrow keys apply at once',
      (tester) async {
        final semantics = tester.ensureSemantics();
        _phone(tester);
        final container = await _pumpApp(tester);
        await _open(tester, 'open text size');
        final s = AppStrings.of(tester.element(_slider));

        // The switch and the header give the phone's size.
        expect(_sliderNode, findsNothing);

        await tester.tap(_inSheet(find.byType(SwitchListTile)));
        await tester.pumpAndSettle();
        expect(_sliderSemantics().label, s.textSize);
        expect(_sliderSemantics().value, '100%');
        expect(_sliderSemantics().increasedValue, '105%');

        tester.semantics.increase(_sliderNode);
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).textPercent, 105);
        expect(_appText(tester), const TextScaler.linear(1.05));
        expect(_sliderSemantics().value, '105%');

        await _tabToSlider(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).textPercent, 110);
        expect(_appText(tester), const TextScaler.linear(1.1));
        expect(_focusIn(tester, _slider), isTrue);
        semantics.dispose();
      },
    );

    for (final (phoneText, phone) in [
      (const TextScaler.linear(1.17), '117%'),
      (const TextScaler.linear(1.5), '150%'),
      (const _Android14At130(), '134%'),
    ]) {
      testWidgets(
        "a phone font size of $phone, between the slider's steps or past its "
        'end, is shown and previewed as the phone sets it',
        (tester) async {
          final semantics = tester.ensureSemantics();
          _phone(tester);
          await _pumpApp(tester, phoneText: phoneText);
          await _open(tester, 'open text size');
          final s = AppStrings.of(tester.element(_slider));

          expect(_inSheet(find.text(s.phoneTextSize(phone))), findsOneWidget);
          expect(_inSheet(find.text(phone)), findsOneWidget);
          // The app and the preview draw text with the phone's own scaler.
          expect(_appText(tester), same(phoneText));
          expect(
            MediaQuery.textScalerOf(
              tester.element(
                find.descendant(
                  of: _frame,
                  matching: find.text(s.totalReceivable),
                ),
              ),
            ),
            same(phoneText),
          );
          // The slider can only sit on a step or at its end. Disabled, and
          // silent for screen readers, it can't contradict the header.
          expect(_sliderOf(tester).onChanged, isNull);
          expect(_sliderNode, findsNothing);
          semantics.dispose();
        },
      );
    }

    testWidgets(
      "a custom size and Reset leave and return to the phone's own scaler",
      (tester) async {
        _phone(tester);
        final container = await _pumpApp(
          tester,
          phoneText: const _Android14At130(),
        );
        await _open(tester, 'open text size');
        final s = AppStrings.of(tester.element(_slider));

        await tester.tap(_inSheet(find.byType(SwitchListTile)));
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).textPercent, 100);
        expect(_appText(tester), const TextScaler.linear(1.0));
        expect(_sliderOf(tester).value, 100);

        await tester.tap(
          _inSheet(find.widgetWithText(OutlinedButton, s.resetToDefault)),
        );
        await tester.pumpAndSettle();
        expect(container.read(displayScaleProvider).textPercent, isNull);
        // Not a linear 134%: the phone's curve itself.
        expect(_appText(tester), same(const _Android14At130()));
        expect(_inSheet(find.text('134%')), findsOneWidget);
      },
    );
  });

  testWidgets("the preview's label keeps Turkish i's dot in capitals", (
    tester,
  ) async {
    _phone(tester);
    await _pumpApp(tester, locale: const Locale('tr'));
    for (final button in ['open display size', 'open text size']) {
      await _open(tester, button);
      expect(_inSheet(find.text('ÖNİZLEME')), findsOneWidget, reason: button);
      expect(_inSheet(find.text('ÖNIZLEME')), findsNothing, reason: button);
      Navigator.pop(tester.element(_slider));
      await tester.pumpAndSettle();
    }
  });

  group('Settings → Display rows', () {
    Finder row(String title) => find.widgetWithText(ListTile, title);
    Finder value(String title, String text) =>
        find.descendant(of: row(title), matching: find.text(text));

    testWidgets('sit between Theme and Language and show the sizes in effect', (
      tester,
    ) async {
      _phone(tester);
      final container = await _pumpApp(tester, home: const SettingsScreen());
      final s = AppStrings.of(tester.element(find.byType(SettingsScreen)));

      final display = tester.getTopLeft(find.text(s.display.toUpperCase())).dy;
      expect(
        tester.getTopLeft(find.text(s.theme.toUpperCase())).dy,
        lessThan(display),
      );
      expect(
        tester.getTopLeft(find.text(s.language.toUpperCase())).dy,
        greaterThan(display),
      );

      expect(value(s.displaySize, '100%'), findsOneWidget);
      expect(value(s.textSize, s.phoneTextSize('125%')), findsOneWidget);

      container.read(displayScaleProvider.notifier).setDisplayPercent(90);
      container.read(displayScaleProvider.notifier).setTextPercent(115);
      await tester.pump();
      expect(value(s.displaySize, '90%'), findsOneWidget);
      expect(value(s.textSize, '115%'), findsOneWidget);

      // Each row opens its sheet at the size in effect.
      await tester.tap(row(s.displaySize));
      await tester.pumpAndSettle();
      expect(_sliderOf(tester).value, 90);
      await tester.tap(_inSheet(find.widgetWithText(FilledButton, s.done)));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);

      await tester.tap(row(s.textSize));
      await tester.pumpAndSettle();
      expect(_sliderOf(tester).value, 115);
      expect(
        tester
            .widget<SwitchListTile>(_inSheet(find.byType(SwitchListTile)))
            .value,
        isFalse,
      );
    });

    testWidgets('a 360 dp phone shows a saved 130% as the 110% it applies', (
      tester,
    ) async {
      _phone(tester, physicalSize: const Size(1260, 2800));
      final container = await _pumpApp(tester, home: const SettingsScreen());
      final s = AppStrings.of(tester.element(find.byType(SettingsScreen)));
      container.read(displayScaleProvider.notifier).setDisplayPercent(130);
      await tester.pump();

      expect(container.read(displayScaleProvider).displayPercent, 130);
      expect(value(s.displaySize, '110%'), findsOneWidget);
    });
  });
}
