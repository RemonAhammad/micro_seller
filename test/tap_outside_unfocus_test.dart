// A tap outside the focused text field closes the keyboard
// (tap_outside_unfocus.dart), as the app frame wires it, on Android and
// iOS: a tap or a wobbling finger does, a drag or a scroll doesn't; another
// field takes the focus; a button still fires; the field's own paste and
// clear buttons, its toolbar and its handles count as inside; a mouse
// closes it as it goes down. The same at a 125% Display size.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/features/settings/providers/display_scale_provider.dart';
import 'package:micro_seller/shared/widgets/app_frame.dart';
import 'package:micro_seller/shared/widgets/app_text_field.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

final _mobile = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});

/// A phone like the owner's: about 411 × 914 dp.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 3200);
  tester.view.devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
}

/// A clipboard holding '7'.
void _clipboard(WidgetTester tester) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method == 'Clipboard.getData'
        ? <String, Object>{'text': '7'}
        : null,
  );
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

/// A form: an amount (with the paste button and a clear button), a note, a
/// Save button and a long list under them.
class _Form {
  _Form(this.tester);

  final WidgetTester tester;
  final amount = TextEditingController(text: '1250.50');
  final note = TextEditingController(text: 'Two boxes for the shop');
  final amountFocus = FocusNode();
  final noteFocus = FocusNode();
  var saves = 0;

  Future<void> pump({int percent = 100}) async {
    addTearDown(() {
      amount.dispose();
      note.dispose();
      amountFocus.dispose();
      noteFocus.dispose();
    });
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
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppTextField(
                  label: 'Amount',
                  controller: amount,
                  focusNode: amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Clear',
                    icon: const ThinIcon(tabler.X.new),
                    onPressed: amount.clear,
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Note',
                  controller: note,
                  focusNode: noteFocus,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => saves++,
                  child: const Text('Save'),
                ),
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 48, child: Text('row $i')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder get amountField => find.widgetWithText(AppTextField, 'Amount');

  Future<void> focusAmount() async {
    await tester.tap(amountField);
    await tester.pump();
    expect(amountFocus.hasFocus, isTrue);
  }

  /// A spot on the list away from every control.
  Offset get outside => tester.getCenter(find.text('row 3'));
}

void main() {
  for (final percent in [100, 125]) {
    group('at $percent%', () {
      testWidgets('a tap outside closes the keyboard, as the finger lifts', (
        tester,
      ) async {
        _phone(tester);
        final form = _Form(tester);
        await form.pump(percent: percent);
        await form.focusAmount();

        final gesture = await tester.startGesture(form.outside);
        await tester.pump();
        // Down alone may be the start of a scroll.
        expect(form.amountFocus.hasFocus, isTrue);
        await gesture.up();
        await tester.pump();
        expect(form.amountFocus.hasFocus, isFalse);
      }, variant: _mobile);

      testWidgets('a finger that wobbles a little still taps', (tester) async {
        _phone(tester);
        final form = _Form(tester);
        await form.pump(percent: percent);
        await form.focusAmount();

        final gesture = await tester.startGesture(form.outside);
        await gesture.moveBy(const Offset(4, 3));
        await tester.pump();
        await gesture.up();
        await tester.pump();
        expect(form.amountFocus.hasFocus, isFalse);
      }, variant: _mobile);

      testWidgets('a drag or a scroll keeps the keyboard open', (tester) async {
        _phone(tester);
        final form = _Form(tester);
        await form.pump(percent: percent);
        await form.focusAmount();

        await tester.drag(find.text('row 8'), const Offset(0, -120));
        await tester.pumpAndSettle();
        expect(form.amountFocus.hasFocus, isTrue);

        // A short sideways drag, past the touch slop.
        final gesture = await tester.startGesture(form.outside);
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump();
        expect(form.amountFocus.hasFocus, isTrue);
      }, variant: _mobile);

      testWidgets('tapping another field moves the focus there', (
        tester,
      ) async {
        _phone(tester);
        final form = _Form(tester);
        await form.pump(percent: percent);
        await form.focusAmount();

        await tester.tap(find.widgetWithText(AppTextField, 'Note'));
        await tester.pump();
        expect(form.noteFocus.hasFocus, isTrue);
        expect(form.amountFocus.hasFocus, isFalse);
      }, variant: _mobile);

      testWidgets('a button outside fires, and the field unfocuses', (
        tester,
      ) async {
        _phone(tester);
        final form = _Form(tester);
        await form.pump(percent: percent);
        await form.focusAmount();

        await tester.tap(find.text('Save'));
        await tester.pump();
        expect(form.saves, 1);
        expect(form.amountFocus.hasFocus, isFalse);
      }, variant: _mobile);

      testWidgets("the field's paste and clear buttons keep the keyboard", (
        tester,
      ) async {
        _phone(tester);
        _clipboard(tester);
        final form = _Form(tester);
        await form.pump(percent: percent);
        await form.focusAmount();

        await tester.tap(
          find.descendant(
            of: form.amountField,
            matching: find.byTooltip('Paste'),
          ),
        );
        await tester.pump();
        expect(form.amount.text, '7');
        expect(form.amountFocus.hasFocus, isTrue);

        await tester.tap(find.byTooltip('Clear'));
        await tester.pump();
        expect(form.amount.text, isEmpty);
        expect(form.amountFocus.hasFocus, isTrue);
      }, variant: _mobile);

      testWidgets('the selection toolbar and handles keep the keyboard', (
        tester,
      ) async {
        _phone(tester);
        _clipboard(tester);
        final form = _Form(tester);
        await form.pump(percent: percent);
        final note = find.widgetWithText(AppTextField, 'Note');
        await tester.tap(note);
        await tester.pump(const Duration(milliseconds: 500));
        expect(form.noteFocus.hasFocus, isTrue);

        // Double-tap the first word: it is selected, and its toolbar and
        // handles show.
        final box = tester
            .state<EditableTextState>(
              find.descendant(of: note, matching: find.byType(EditableText)),
            )
            .renderEditable;
        final firstWord = box.localToGlobal(
          box.getLocalRectForCaret(const TextPosition(offset: 1)).center,
        );
        await tester.tapAt(firstWord);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(firstWord);
        await tester.pumpAndSettle();
        expect(
          form.note.selection,
          const TextSelection(baseOffset: 0, extentOffset: 3),
        );
        expect(find.text('Copy'), findsOneWidget);
        expect(form.noteFocus.hasFocus, isTrue);

        // Drag the end handle on over the next word.
        final end = box.getEndpointsForSelection(form.note.selection).last;
        final handle =
            box.localToGlobal(end.point) +
            switch (defaultTargetPlatform) {
              // Cupertino's handle is a line ending in a dot; Material's
              // hangs below the line.
              TargetPlatform.iOS => const Offset(0, -4),
              _ => const Offset(4, 10),
            };
        final drag = await tester.startGesture(handle);
        await tester.pump(const Duration(milliseconds: 50));
        for (var i = 0; i < 3; i++) {
          await drag.moveBy(const Offset(20, 0));
          await tester.pump();
        }
        await drag.up();
        await tester.pumpAndSettle();
        expect(form.note.selection.end, greaterThan(3));
        expect(form.noteFocus.hasFocus, isTrue);

        // Select all, where the toolbar offers it (Android; iOS offers it
        // only for a caret, and at 125% it moves into the overflow menu).
        if (find.text('Select all').evaluate().isNotEmpty) {
          await tester.tap(find.text('Select all'));
          await tester.pumpAndSettle();
          expect(
            form.note.selection.textInside(form.note.text),
            form.note.text,
          );
          expect(form.noteFocus.hasFocus, isTrue);
        }

        // A toolbar button.
        if (find.text('Copy').evaluate().isEmpty) {
          await tester.tapAt(firstWord);
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tapAt(firstWord);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Copy'));
        await tester.pumpAndSettle();
        expect(form.noteFocus.hasFocus, isTrue);
      }, variant: _mobile);

      testWidgets('a mouse click outside closes it as it goes down', (
        tester,
      ) async {
        _phone(tester);
        final form = _Form(tester);
        await form.pump(percent: percent);
        await form.focusAmount();

        final gesture = await tester.startGesture(
          form.outside,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(form.amountFocus.hasFocus, isFalse);
        await gesture.up();
        await gesture.removePointer();
      }, variant: _mobile);
    });
  }

  testWidgets('on desktop a touch outside closes it as it goes down, as '
      "Flutter's own default does", (tester) async {
    final form = _Form(tester);
    await form.pump();
    await form.focusAmount();

    final gesture = await tester.startGesture(form.outside);
    await tester.pump();
    expect(form.amountFocus.hasFocus, isFalse);
    await gesture.up();
  }, variant: TargetPlatformVariant.desktop());

  testWidgets("a field's own onTapOutside still wins", (tester) async {
    _phone(tester);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var outside = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => AppFrame(child: child!),
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focus, onTapOutside: (_) => outside++),
                const Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tapAt(const Offset(200, 600));
    await tester.pump();
    expect(outside, 1);
    expect(focus.hasFocus, isTrue);
  }, variant: _mobile);
}
