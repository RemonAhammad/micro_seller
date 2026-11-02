import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/shared/widgets/entry_date_field.dart';

// The date and time row used to enter something later than it happened:
// orders, payments, collections, purchases and stock changes.

Future<void> _pump(WidgetTester tester, Widget child,
    {bool use24Hour = false}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [AppLocalizations.delegate],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24Hour),
      child: child!,
    ),
    home: Scaffold(body: Center(child: child)),
  ));
  await tester.pump();
}

void main() {
  group('snapEntryDateTime', () {
    final now = DateTime(2026, 11, 2, 15, 30, 45);
    final earliest = DateTime(2026, 10, 1, 9, 15, 20);

    test('keeps a time between the bounds', () {
      final picked = DateTime(2026, 10, 20, 18, 5, 45);
      expect(snapEntryDateTime(picked, earliest: earliest, now: now), picked);
    });

    test('refuses a later minute, snaps the current one to now', () {
      expect(
          snapEntryDateTime(DateTime(2026, 11, 2, 15, 31),
              earliest: earliest, now: now),
          isNull);
      expect(
          snapEntryDateTime(DateTime(2026, 11, 2, 15, 30, 59),
              earliest: earliest, now: now),
          now);
    });

    test('refuses an earlier minute, snaps the first one to the bound', () {
      expect(
          snapEntryDateTime(DateTime(2026, 10, 1, 9, 14, 59),
              earliest: earliest, now: now),
          isNull);
      expect(
          snapEntryDateTime(DateTime(2026, 10, 1, 9, 15, 2),
              earliest: earliest, now: now),
          earliest);
    });
  });

  testWidgets('says Now with the hint until a date is picked', (tester) async {
    await _pump(
      tester,
      EntryDateField(
        label: 'Order date',
        value: null,
        hint: 'Entering it later? Tap to set when it happened.',
        onChanged: (_) {},
        onReset: () {},
      ),
    );
    expect(find.text('Order date'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Entering it later? Tap to set when it happened.'),
        findsOneWidget);
    expect(find.byTooltip('Use the current time'), findsNothing);
  });

  testWidgets('shows a set date in the app language, with a way back to now',
      (tester) async {
    var reset = false;
    await _pump(
      tester,
      EntryDateField(
        label: 'Order date',
        value: DateTime(2026, 10, 31, 18, 5),
        hint: 'hint',
        onChanged: (_) {},
        onReset: () => reset = true,
      ),
    );
    expect(find.text('Oct 31, 2026, 6:05 PM'), findsOneWidget);
    expect(find.text('hint'), findsNothing);
    await tester.tap(find.byTooltip('Use the current time'));
    expect(reset, isTrue);
  });

  testWidgets('follows the phone\'s 24-hour setting', (tester) async {
    await _pump(
      tester,
      EntryDateField(
        label: 'Payment date',
        value: DateTime(2026, 10, 31, 18, 5),
        onChanged: (_) {},
      ),
      use24Hour: true,
    );
    expect(find.text('Oct 31, 2026, 18:05'), findsOneWidget);
    expect(find.byTooltip('Use the current time'), findsNothing,
        reason: 'no reset when editing keeps a date');
  });

  testWidgets('a tap asks for the date, then the time', (tester) async {
    DateTime? picked;
    final before = DateTime.now();
    await _pump(
      tester,
      EntryDateField(
        label: 'Order date',
        value: null,
        onChanged: (d) => picked = d,
      ),
    );
    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.isAfter(DateTime.now()), isFalse);
    expect(picked!.difference(before).inMinutes.abs(), lessThanOrEqualTo(1));
  });

  testWidgets('cancelling the time picker changes nothing', (tester) async {
    DateTime? picked;
    await _pump(
      tester,
      EntryDateField(
        label: 'Order date',
        value: DateTime.now().subtract(const Duration(days: 2)),
        onChanged: (d) => picked = d,
      ),
    );
    await tester.tap(find.text('Order date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });
}
