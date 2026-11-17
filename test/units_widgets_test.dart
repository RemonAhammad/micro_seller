import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/scale_barcode.dart';
import 'package:micro_seller/data/models/quantity_unit.dart';
import 'package:micro_seller/features/settings/presentation/widgets/scale_label_sheet.dart';
import 'package:micro_seller/shared/widgets/quantity_sheet.dart';

/// The quantity sheet, the Scale labels sheet and the unit texts.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CurrencyFormatter.setSymbol('৳');
  });

  Widget app(Widget Function(BuildContext) builder, {Locale locale = const Locale('en')}) => MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Builder(builder: builder)),
      );

  /// Opens the sheet from a button and returns what it popped (null until).
  Future<List<double?>> openSheet(
    WidgetTester tester, {
    QuantityUnit unit = QuantityUnit.kg,
    double unitPrice = 600,
    double? available = 5,
    double? initial,
    bool allowZero = false,
  }) async {
    final results = <double?>[];
    await tester.pumpWidget(app((context) => TextButton(
          onPressed: () async => results.add(await showQuantitySheet(
            context,
            productName: 'Rui fish',
            unit: unit,
            unitPrice: unitPrice,
            available: available,
            initial: initial,
            allowZero: allowZero,
          )),
          child: const Text('open'),
        )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }


  bool addEnabled(WidgetTester tester, String label) {
    final button = find.ancestor(of: find.text(label).last, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    return tester.widget<ButtonStyleButton>(button.first).onPressed != null;
  }

  group('QuantitySheet', () {
    testWidgets('typed 1.25 kg: price per kg, line total, Add returns it', (tester) async {
      final results = await openSheet(tester);
      expect(find.text('Rui fish'), findsOneWidget);
      expect(find.text('৳600 / kg'), findsOneWidget);
      expect(addEnabled(tester, 'Add'), isFalse, reason: 'nothing typed');

      await tester.enterText(find.byType(TextField), '1.25');
      await tester.pump();
      expect(find.textContaining('৳750'), findsOneWidget);
      expect(addEnabled(tester, 'Add'), isTrue);

      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(results, [1.25]);
    });

    testWidgets('the quick chips: ½ kg', (tester) async {
      final results = await openSheet(tester);
      expect(find.text('¼ kg'), findsOneWidget);
      await tester.tap(find.text('½ kg'));
      await tester.pump();
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(results, [0.5]);
    });

    testWidgets('by amount: ৳200 is 0.333 kg, and switching back shows it', (tester) async {
      final results = await openSheet(tester);
      await tester.tap(find.text('By amount'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '200');
      await tester.pump();
      expect(find.textContaining('0.333 kg'), findsWidgets);

      await tester.tap(find.text('By quantity'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '0.333');

      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(results, [0.333]);
    });

    testWidgets('more than the stock left is refused', (tester) async {
      await openSheet(tester, available: 1);
      await tester.enterText(find.byType(TextField), '1.5');
      await tester.pump();
      expect(find.text('1 kg left'), findsOneWidget);
      expect(addEnabled(tester, 'Add'), isFalse);

      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      expect(addEnabled(tester, 'Add'), isTrue, reason: 'the last kilogram can be sold');
    });

    testWidgets('a line already in the cart: its quantity, and Update', (tester) async {
      final results = await openSheet(tester, initial: 2);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '2');
      await tester.enterText(find.byType(TextField), '2.75');
      await tester.pump();
      await tester.tap(find.text('Update').last);
      await tester.pumpAndSettle();
      expect(results, [2.75]);
    });

    testWidgets('a purchase has no cap; a free item has no By amount', (tester) async {
      final results = await openSheet(tester, available: null, unitPrice: 0);
      expect(find.text('By amount'), findsNothing);
      await tester.enterText(find.byType(TextField), '250');
      await tester.pump();
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(results, [250]);
    });

    testWidgets('dozens: whole chips only, decimals refused by the field', (tester) async {
      await openSheet(tester, unit: QuantityUnit.dozen, unitPrice: 120);
      expect(find.textContaining('¼'), findsNothing);
      expect(find.text('2 dozen'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1.5');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isNot(contains('.')));
    });

    testWidgets('dismissed: nothing', (tester) async {
      final results = await openSheet(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(results, [null]);
    });

    testWidgets('allowZero off: an empty field cannot be confirmed', (tester) async {
      await openSheet(tester, initial: 2);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      // Still "Update" (initial > 0), and disabled with nothing to confirm.
      expect(addEnabled(tester, 'Update'), isFalse);
      expect(find.text('Remove'), findsNothing);
    });

    testWidgets('allowZero: clearing the field confirms 0 via Remove', (tester) async {
      final results = await openSheet(tester, initial: 2, allowZero: true);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '2');

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      // Empty field in return context means "remove the line".
      expect(find.text('Remove'), findsWidgets);
      expect(addEnabled(tester, 'Remove'), isTrue);

      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(results, [0.0]);
    });

    testWidgets('allowZero: typing 0 confirms 0', (tester) async {
      final results = await openSheet(tester, initial: 2, allowZero: true);
      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      expect(addEnabled(tester, 'Remove'), isTrue);
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(results, [0.0]);
    });

    testWidgets('allowZero: a positive value still returns it', (tester) async {
      final results = await openSheet(tester, initial: 2, allowZero: true);
      await tester.enterText(find.byType(TextField), '1.5');
      await tester.pump();
      expect(find.text('Remove'), findsNothing, reason: 'positive qty is Update, not Remove');
      await tester.tap(find.text('Update').last);
      await tester.pumpAndSettle();
      expect(results, [1.5]);
    });
  });

  group('Scale labels sheet', () {
    Future<void> openScaleSheet(WidgetTester tester) async {
      await tester.pumpWidget(app((context) => TextButton(
            onPressed: () => showScaleLabelSheet(context),
            child: const Text('open'),
          )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('off by default; turning it on shows the choices and saves at once', (tester) async {
      await openScaleSheet(tester);
      expect(find.text('Read scale labels'), findsOneWidget);
      expect(find.text('Weight (grams)'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Weight (grams)'), findsOneWidget);
      expect(find.text('2X  12345  01250  C'), findsOneWidget, reason: 'the 5-digit layout');
      expect((await ScaleLabelSettings.load()).enabled, isTrue);

      await tester.tap(find.text('Price (2 decimals)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(find.text('2X  1234  001250  C'), findsOneWidget);
      expect(await ScaleLabelSettings.load(),
          const ScaleLabelSettings(enabled: true, value: ScaleLabelValue.price, itemCodeDigits: 4));
    });

    testWidgets('opens with what was saved', (tester) async {
      SharedPreferences.setMockInitialValues({
        ScaleLabelSettings.keyEnabled: true,
        ScaleLabelSettings.keyValue: 'priceWhole',
        ScaleLabelSettings.keyItemCodeDigits: 6,
      });
      await openScaleSheet(tester);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Price (whole)')).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '6')).selected, isTrue);
    });
  });

  group('unit texts', () {
    testWidgets('quantities, prices per unit and field labels', (tester) async {
      late dynamic s;
      await tester.pumpWidget(app((context) {
        s = AppStrings.of(context);
        return const SizedBox();
      }));
      await tester.pumpAndSettle();
      expect(s.qty(3, QuantityUnit.piece), '3');
      expect(s.qty(3.0, QuantityUnit.piece), '3', reason: 'never "3.0"');
      expect(s.qty(1.25, QuantityUnit.kg), '1.25 kg');
      expect(s.qty(1250, QuantityUnit.g), '1,250 g');
      expect(s.pricePer('৳600', QuantityUnit.kg), '৳600 / kg');
      expect(s.pricePer('৳40', QuantityUnit.piece), '৳40');
      expect(s.pricePerUnit('Selling Price', QuantityUnit.metre), 'Selling Price (per m)');
      expect(s.pricePerUnit('Selling Price', QuantityUnit.piece), 'Selling Price');
      for (final u in QuantityUnit.values) {
        expect(s.unitName(u), isNot(startsWith('unitName')), reason: '$u has a name');
      }
    });

    testWidgets('every language names every unit', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        late dynamic s;
        await tester.pumpWidget(app((context) {
          s = AppStrings.of(context);
          return const SizedBox();
        }, locale: locale));
        await tester.pumpAndSettle();
        for (final u in QuantityUnit.values) {
          expect(s.unitName(u), isNot(startsWith('unitName')), reason: '$locale $u');
          if (u != QuantityUnit.piece) expect(s.unitSymbol(u), isNotEmpty, reason: '$locale $u');
        }
      }
    });
  });
}
