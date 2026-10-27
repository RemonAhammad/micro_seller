// iOS's bar over the number, decimal and phone pads
// (keyboard_accessory_bar.dart), as the app frame wires it: which keyboards
// get it, Next and Done, the focused field kept clear of it (screens,
// dialogs and sheets), and its place and size at every Display size. The
// keyboard is simulated with the window's bottom inset.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/features/settings/providers/display_scale_provider.dart';
import 'package:micro_seller/shared/widgets/app_frame.dart';
import 'package:micro_seller/shared/widgets/keyboard_accessory_bar.dart';

final _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

const _decimal = TextInputType.numberWithOptions(decimal: true);

/// The keyboard's height in window dp.
const _keyboard = 300.0;

/// A phone like the owner's: about 411 × 914 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
}

Size _window(WidgetTester tester) =>
    tester.view.physicalSize / tester.view.devicePixelRatio;

/// Opens (or, with 0, closes) the keyboard to [dp] window dp at the bottom,
/// over a few frames as the iOS keyboard slides: a focused field is
/// revealed on every frame of it.
Future<void> _showKeyboard(WidgetTester tester, [double dp = _keyboard]) async {
  final ratio = tester.view.devicePixelRatio;
  final from = tester.view.viewInsets.bottom / ratio;
  const frames = 6;
  for (var i = 1; i <= frames; i++) {
    tester.view.viewInsets = FakeViewPadding(
      bottom: (from + (dp - from) * i / frames) * ratio,
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  int percent = 100,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        displayScaleProvider.overrideWithBuild(
          (ref, notifier) => (displayPercent: percent, textPercent: null),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppFrame(child: child!),
        home: home,
      ),
    ),
  );
  await tester.pump();
}

/// A list of text fields, one per keyboard type, with [action] each.
Widget _form(
  List<TextInputType> types, {
  TextInputAction? action,
  bool readOnly = false,
}) => Scaffold(
  body: ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final (i, type) in types.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            key: ValueKey('field $i'),
            keyboardType: type,
            textInputAction: action,
            readOnly: readOnly,
            decoration: InputDecoration(labelText: 'Field $i'),
          ),
        ),
    ],
  ),
);

Finder _field(int i) => find.byKey(ValueKey('field $i'));

bool _hasFocus(WidgetTester tester, int i) => tester
    .state<EditableTextState>(
      find.descendant(of: _field(i), matching: find.byType(EditableText)),
    )
    .widget
    .focusNode
    .hasFocus;

Future<void> _focus(WidgetTester tester, int i) async {
  await tester.tap(_field(i));
  await tester.pump();
  expect(_hasFocus(tester, i), isTrue);
}

/// The bar: the one tap region the Done label is in.
final _bar = find.ancestor(
  of: find.text('Done'),
  matching: find.byType(TextFieldTapRegion),
);

TextButton _button(WidgetTester tester, String label) => tester.widget(
  find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
);

/// Counts mounts: the router must never remount as the bar comes and goes.
class _Counted extends StatefulWidget {
  const _Counted({required this.child});

  final Widget child;

  static var inits = 0;

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    _Counted.inits++;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  test('the keyboards without a return key', () {
    expect(hasNoReturnKey(TextInputType.number), isTrue);
    expect(hasNoReturnKey(_decimal), isTrue);
    expect(hasNoReturnKey(TextInputType.phone), isTrue);
    expect(
      hasNoReturnKey(const TextInputType.numberWithOptions(signed: true)),
      isFalse,
    );
    expect(
      hasNoReturnKey(
        const TextInputType.numberWithOptions(signed: true, decimal: true),
      ),
      isFalse,
    );
    for (final type in [
      TextInputType.text,
      TextInputType.multiline,
      TextInputType.emailAddress,
      TextInputType.url,
      TextInputType.name,
      TextInputType.datetime,
      TextInputType.visiblePassword,
    ]) {
      expect(hasNoReturnKey(type), isFalse, reason: '$type');
    }
  });

  test('its height: 44 dp, taller for a large font', () {
    expect(keyboardAccessoryBarHeight(TextScaler.noScaling), 44);
    expect(keyboardAccessoryBarHeight(const TextScaler.linear(1.3)), 44);
    expect(
      keyboardAccessoryBarHeight(const TextScaler.linear(1.5)),
      closeTo(24 * 1.4 + 12, 1e-9),
    );
    expect(
      keyboardAccessoryBarHeight(const TextScaler.linear(2)),
      closeTo(32 * 1.4 + 12, 1e-9),
    );
  });

  testWidgets('the number, decimal and phone pads get it', (tester) async {
    _phone(tester);
    for (final type in [TextInputType.number, _decimal, TextInputType.phone]) {
      await _pump(tester, _form([type]));
      await _focus(tester, 0);
      await _showKeyboard(tester);
      expect(_bar, findsOneWidget, reason: '$type');
      expect(find.text('Next'), findsNothing, reason: '$type');
      await _showKeyboard(tester, 0);
      await tester.pumpWidget(const SizedBox());
    }
  }, variant: _iOS);

  testWidgets("keyboards with a return key don't", (tester) async {
    _phone(tester);
    for (final type in [
      TextInputType.text,
      TextInputType.multiline,
      TextInputType.emailAddress,
      const TextInputType.numberWithOptions(signed: true, decimal: true),
    ]) {
      await _pump(tester, _form([type]));
      await _focus(tester, 0);
      await _showKeyboard(tester);
      expect(find.text('Done'), findsNothing, reason: '$type');
      await _showKeyboard(tester, 0);
      await tester.pumpWidget(const SizedBox());
    }
  }, variant: _iOS);

  testWidgets('no keyboard, no bar; nor for a read-only field', (tester) async {
    _phone(tester);
    await _pump(tester, _form([_decimal]));
    await _focus(tester, 0);
    expect(find.text('Done'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, _form([_decimal], readOnly: true));
    await _focus(tester, 0);
    await _showKeyboard(tester);
    expect(find.text('Done'), findsNothing);
  }, variant: _iOS);

  testWidgets(
    'not on other platforms, where the host adds nothing',
    (tester) async {
      _phone(tester);
      await _pump(tester, _form([_decimal]));
      await _focus(tester, 0);
      await _showKeyboard(tester);
      expect(find.text('Done'), findsNothing);
      final host = tester.element(find.byType(KeyboardAccessoryHost));
      Widget? child;
      host.visitChildElements((element) => child = element.widget);
      expect(
        child,
        same(
          tester
              .widget<KeyboardAccessoryHost>(find.byType(KeyboardAccessoryHost))
              .child,
        ),
      );
    },
    variant: TargetPlatformVariant.all(excluding: {TargetPlatform.iOS}),
  );

  testWidgets('Next only for a field whose action is next', (tester) async {
    _phone(tester);
    for (final action in [
      null,
      TextInputAction.done,
      TextInputAction.go,
      TextInputAction.next,
    ]) {
      await _pump(tester, _form([_decimal], action: action));
      await _focus(tester, 0);
      await _showKeyboard(tester);
      expect(find.text('Done'), findsOneWidget, reason: '$action');
      expect(
        find.text('Next'),
        action == TextInputAction.next ? findsOneWidget : findsNothing,
        reason: '$action',
      );
      await _showKeyboard(tester, 0);
      await tester.pumpWidget(const SizedBox());
    }
  }, variant: _iOS);

  testWidgets('Next does what the return key would: the next field', (
    tester,
  ) async {
    _phone(tester);
    await _pump(
      tester,
      _form([
        _decimal,
        TextInputType.phone,
        TextInputType.text,
      ], action: TextInputAction.next),
    );
    await _focus(tester, 0);
    await _showKeyboard(tester);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(_hasFocus(tester, 0), isFalse);
    expect(_hasFocus(tester, 1), isTrue);
    // The phone pad has no return key either.
    expect(_bar, findsOneWidget);

    // A text keyboard has one: the bar goes at once, the keyboard stays.
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(_hasFocus(tester, 2), isTrue);
    expect(find.text('Done'), findsNothing);
  }, variant: _iOS);

  testWidgets('Done closes the keyboard; the bar goes down with it', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester, _form([_decimal], action: TextInputAction.next));
    await _focus(tester, 0);
    await _showKeyboard(tester);
    expect(_button(tester, 'Done').onPressed, isNotNull);

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(_hasFocus(tester, 0), isFalse);
    // The keyboard slides down: the bar stays on it, its buttons off.
    expect(_bar, findsOneWidget);
    expect(_button(tester, 'Done').onPressed, isNull);
    expect(_button(tester, 'Next').onPressed, isNull);
    await _showKeyboard(tester, 120);
    expect(
      tester.getRect(_bar).bottom,
      closeTo(_window(tester).height - 120, 0.01),
    );
    await _showKeyboard(tester, 0);
    expect(find.text('Done'), findsNothing);

    // Focused again, it comes back with the keyboard.
    await _focus(tester, 0);
    await _showKeyboard(tester);
    expect(_button(tester, 'Done').onPressed, isNotNull);
  }, variant: _iOS);

  testWidgets("a tap on the bar's background keeps the focus", (tester) async {
    _phone(tester);
    await _pump(tester, _form([_decimal]));
    await _focus(tester, 0);
    await _showKeyboard(tester);
    final bar = tester.getRect(_bar);
    await tester.tapAt(bar.centerLeft + const Offset(40, 0));
    await tester.pump();
    expect(_hasFocus(tester, 0), isTrue);
    expect(_bar, findsOneWidget);
  }, variant: _iOS);

  testWidgets('the screen below sees the bar as part of the keyboard', (
    tester,
  ) async {
    _phone(tester);
    double? inset;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          inset = MediaQuery.viewInsetsOf(context).bottom;
          return _form([_decimal]);
        },
      ),
    );
    await _focus(tester, 0);
    await _showKeyboard(tester);
    expect(inset, closeTo(_keyboard + 44, 1e-9));
    await tester.tap(find.text('Done'));
    await _showKeyboard(tester, 0);
    expect(inset, 0);
  }, variant: _iOS);

  testWidgets('the last field of a long form ends up above the bar', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester, _form(List.filled(14, _decimal)));
    // Scrolled to the end: the last field sits at the bottom of the screen.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    await _focus(tester, 13);
    await _showKeyboard(tester);
    await tester.pumpAndSettle();
    final bar = tester.getRect(_bar);
    expect(tester.getRect(_field(13)).bottom, lessThanOrEqualTo(bar.top));
    expect(bar.bottom, closeTo(_window(tester).height - _keyboard, 0.01));
  }, variant: _iOS);

  testWidgets('over a dialog: it lifts above the bar, and Done works', (
    tester,
  ) async {
    _phone(tester);
    await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('Pay'),
                content: TextField(
                  key: ValueKey('field 0'),
                  keyboardType: _decimal,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _focus(tester, 0);
    await _showKeyboard(tester);
    await tester.pumpAndSettle();
    final bar = tester.getRect(_bar);
    final dialog = tester.getRect(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(dialog.bottom, lessThanOrEqualTo(bar.top));
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(_hasFocus(tester, 0), isFalse);
    // The dialog stays open.
    expect(find.text('Pay'), findsOneWidget);
  }, variant: _iOS);

  testWidgets('over a sheet: its field stays above the bar', (tester) async {
    _phone(tester);
    await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    key: ValueKey('field 0'),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _focus(tester, 0);
    await _showKeyboard(tester);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(_field(0)).bottom,
      lessThanOrEqualTo(tester.getRect(_bar).top),
    );
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(_hasFocus(tester, 0), isFalse);
  }, variant: _iOS);

  testWidgets('the router is never remounted as the bar comes and goes', (
    tester,
  ) async {
    _phone(tester);
    _Counted.inits = 0;
    await _pump(tester, _Counted(child: _form([_decimal])));
    expect(_Counted.inits, 1);
    await _focus(tester, 0);
    await _showKeyboard(tester);
    expect(_bar, findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await _showKeyboard(tester, 0);
    expect(find.text('Done'), findsNothing);
    expect(_Counted.inits, 1);
  }, variant: _iOS);

  for (final percent in [80, 100, 125]) {
    testWidgets('$percent%: it sits on the keyboard, 44 dp × the zoom tall', (
      tester,
    ) async {
      _phone(tester);
      await _pump(
        tester,
        _form([_decimal], action: TextInputAction.next),
        percent: percent,
      );
      await _focus(tester, 0);
      await _showKeyboard(tester);
      final scale = percent / 100;
      final bar = tester.getRect(_bar);
      expect(bar.bottom, closeTo(_window(tester).height - _keyboard, 0.01));
      expect(bar.height, closeTo(44 * scale, 0.01));
      expect(bar.left, closeTo(0, 0.01));
      expect(bar.right, closeTo(_window(tester).width, 0.01));
      // Next at the start, Done at the end.
      expect(
        tester.getCenter(find.text('Next')).dx,
        lessThan(tester.getCenter(find.text('Done')).dx),
      );
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(_hasFocus(tester, 0), isFalse);
    }, variant: _iOS);
  }

  testWidgets('a large phone font makes it taller', (tester) async {
    _phone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, _form([_decimal]));
    await _focus(tester, 0);
    await _showKeyboard(tester);
    expect(
      tester.getRect(_bar).height,
      closeTo(keyboardAccessoryBarHeight(const TextScaler.linear(1.5)), 0.01),
    );
  }, variant: _iOS);
}
