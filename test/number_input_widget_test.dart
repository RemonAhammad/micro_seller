// An amount field typed and pasted into as the app's fields are, on Android
// and iOS: an AppTextField with the money formatter and the amount validator
// in a Form. A French iPhone's number pad types 12,50 and an Arabic one
// ١٢٫٥٠; both must save 12.5. On Android a keyboard may have both ',' and
// '.': a ',' is the point where the region writes decimals with one, and
// groups thousands in Bangladesh. The paste button runs the field's
// formatters too: it used to set the clipboard text as it was, so 1,250.00
// reached double.parse; and text the field refuses leaves it as it was.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/utils/number_input.dart';
import 'package:micro_seller/core/utils/validators.dart';
import 'package:micro_seller/shared/widgets/app_text_field.dart';

final _platforms = TargetPlatformVariant(const {
  TargetPlatform.android,
  TargetPlatform.iOS,
});

void main() {
  late TextEditingController controller;
  late GlobalKey<FormState> form;
  late List<String> changes;

  Future<void> pumpAmountField(WidgetTester tester) async {
    controller = TextEditingController();
    addTearDown(controller.dispose);
    form = GlobalKey<FormState>();
    changes = [];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: form,
              child: AppTextField(
                label: 'Amount',
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [DecimalInputFormatter.money()],
                validator: (v) => Validators.positiveNumber(v, 'Amount'),
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Types [keys] one key at a time at the end of the field, as a keyboard
  /// sends them.
  Future<void> typeKeys(WidgetTester tester, String keys) async {
    for (final key in keys.split('')) {
      await tester.enterText(find.byType(TextField), controller.text + key);
      await tester.pump();
    }
  }

  /// The clipboard, holding [text].
  void mockClipboard(WidgetTester tester, String text) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object>{'text': text}
          : null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  /// The phone is in [locale]'s region, until the test ends.
  void region(Locale locale) {
    NumberInput.debugDeviceLocale = locale;
    addTearDown(() => NumberInput.debugDeviceLocale = null);
  }

  testWidgets('a comma typed as the point saves 12.5: on an iPhone in any '
      'region, on Android where the region writes decimals with one', (
    tester,
  ) async {
    region(
      defaultTargetPlatform == TargetPlatform.iOS
          ? const Locale('bn', 'BD')
          : const Locale('fr', 'FR'),
    );
    await pumpAmountField(tester);
    await typeKeys(tester, '12,50');
    expect(controller.text, '12.50');
    expect(form.currentState!.validate(), isTrue);
    expect(NumberInput.parseDecimal(controller.text), 12.5);
    expect(changes.last, '12.50');
  }, variant: _platforms);

  testWidgets('on Android in Bangladesh a comma groups thousands: 1,250 '
      'saves 1250', (tester) async {
    region(const Locale('bn', 'BD'));
    await pumpAmountField(tester);
    await typeKeys(tester, '1,250');
    expect(controller.text, '1250');
    expect(NumberInput.parseDecimal(controller.text), 1250);
    // '.' is the point there.
    await typeKeys(tester, '.5');
    expect(controller.text, '1250.5');
  });

  testWidgets('Arabic digits and ٫ save 12.5', (tester) async {
    await pumpAmountField(tester);
    await typeKeys(tester, '١٢٫٥٠');
    expect(controller.text, '12.50');
    expect(form.currentState!.validate(), isTrue);
    expect(NumberInput.parseDecimal(controller.text), 12.5);
  }, variant: _platforms);

  testWidgets('a third decimal is refused', (tester) async {
    await pumpAmountField(tester);
    await typeKeys(tester, '12.505');
    expect(controller.text, '12.50');
    expect(controller.selection, const TextSelection.collapsed(offset: 5));
  }, variant: _platforms);

  testWidgets('the paste button pastes through the formatters', (tester) async {
    mockClipboard(tester, '1,250.00');
    await pumpAmountField(tester);
    controller.text = '99';
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    expect(controller.text, '1250.00');
    expect(controller.selection, const TextSelection.collapsed(offset: 7));
    expect(changes, ['1250.00']);
    expect(form.currentState!.validate(), isTrue);
    expect(NumberInput.parseDecimal(controller.text), 1250);
  }, variant: _platforms);

  testWidgets('a paste the field refuses leaves it as it was', (tester) async {
    // Junk, a negative amount the field can't take, and one character
    // without a digit: read as a key typed over the whole value, it used to
    // empty the field, or make it 0.
    for (final clipboard in [
      '12 apples 3',
      '-50',
      '-',
      'x',
      '%',
      '৳',
      ' ',
      '.',
      ',',
    ]) {
      mockClipboard(tester, clipboard);
      await pumpAmountField(tester);
      controller.value = const TextEditingValue(
        text: '1250',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.tap(find.byTooltip('Paste'));
      await tester.pump();
      expect(controller.text, '1250', reason: '"$clipboard"');
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 1),
        reason: '"$clipboard"',
      );
      expect(changes, isEmpty, reason: '"$clipboard"');
    }
  }, variant: _platforms);

  testWidgets('a phone field keeps its number when the clipboard holds a '
      'name', (tester) async {
    final phone = TextEditingController(text: '01712345678');
    addTearDown(phone.dispose);
    final pasted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(
              label: 'Phone',
              controller: phone,
              keyboardType: TextInputType.phone,
              inputFormatters: const [PhoneInputFormatter()],
              onChanged: pasted.add,
            ),
          ),
        ),
      ),
    );
    for (final clipboard in ['John Smith', '+', ' - ']) {
      mockClipboard(tester, clipboard);
      await tester.tap(find.byTooltip('Paste'));
      await tester.pump();
      expect(phone.text, '01712345678', reason: '"$clipboard"');
    }
    expect(pasted, isEmpty);
  }, variant: _platforms);

  testWidgets('a text field still pastes a name', (tester) async {
    mockClipboard(tester, 'John Smith');
    final name = TextEditingController(text: 'Karim');
    addTearDown(name.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(label: 'Name', controller: name),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    expect(name.text, 'John Smith');
  });

  testWidgets('the paste button keeps to the field\'s max length', (
    tester,
  ) async {
    mockClipboard(tester, '+৮৮০ ১৭১২-৩৪৫৬৭৮');
    final phone = TextEditingController();
    addTearDown(phone.dispose);
    final pasted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(
              label: 'Phone',
              controller: phone,
              keyboardType: TextInputType.phone,
              inputFormatters: const [PhoneInputFormatter()],
              maxLength: 9,
              onChanged: pasted.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Paste'));
    await tester.pump();
    expect(phone.text, '+880 1712');
    expect(pasted, ['+880 1712']);
  }, variant: _platforms);
}
