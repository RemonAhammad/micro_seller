import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/core/l10n/app_localizations.dart';
import 'package:micro_seller/core/theme/app_theme.dart';
import 'package:micro_seller/core/utils/currency_formatter.dart';
import 'package:micro_seller/core/utils/validators.dart';
import 'package:micro_seller/data/models/order.dart';
import 'package:micro_seller/data/models/trash_entry.dart';
import 'package:micro_seller/data/services/auth_gate_service.dart';
import 'package:micro_seller/features/settings/presentation/recycle_bin_screen.dart';
import 'package:micro_seller/features/settings/providers/trash_provider.dart';
import 'package:micro_seller/shared/widgets/aging_bar.dart';
import 'package:micro_seller/shared/widgets/app_button.dart';
import 'package:micro_seller/shared/widgets/app_text_field.dart';
import 'package:micro_seller/shared/widgets/auth_gate.dart';
import 'package:micro_seller/shared/widgets/bottom_sheet_handle.dart';
import 'package:micro_seller/shared/widgets/confirm_dialog.dart';
import 'package:micro_seller/shared/widgets/drawer_menu_button.dart';
import 'package:micro_seller/shared/widgets/empty_state.dart';
import 'package:micro_seller/shared/widgets/keyboard_accessory_bar.dart';
import 'package:micro_seller/shared/widgets/loading_overlay.dart';
import 'package:micro_seller/shared/widgets/payment_method_chips.dart';
import 'package:micro_seller/shared/widgets/pdf_saved_sheet.dart';
import 'package:micro_seller/shared/widgets/rate_app_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../support/layout_harness.dart';

// Layout of the shared widgets (dialogs, sheets, PIN pad, buttons, empty
// state) and the Recycle Bin under the Display size / Text size settings:
// clean from the narrowest layout (320 dp) to a large phone font (150%), in
// long translations, and unchanged at 100% text on a normal phone.

/// A short phone, and the narrowest layout zoomed in on one (Display size).
const _shortHeights = [800.0, 600.0];

/// Latin-script languages with long labels: measured with real Roboto
/// widths, unlike scripts the test fonts don't carry.
const _langs = ['en', 'pt', 'fr'];

const _longName = 'Mohammad Abdur Rahman Chowdhury Trading Co.';

const _eps = 0.01;

class _FakeAuth extends AuthGateService {
  _FakeAuth({this.pin});

  String? pin;

  @override
  Future<bool> isBiometricAvailable() async => false;

  @override
  Future<bool> hasPin() async => pin != null;

  @override
  Future<bool> verifyPin(String value) async => value == pin;

  @override
  Future<void> setPin(String value) async => pin = value;
}

/// Pumps [home] the way the app shows a screen on a phone: in a shell
/// branch's Navigator beside the sidebar rail, so a bottom sheet opens beside
/// the rail and a dialog over the whole window, with the app's theme, [lang]
/// strings and [textScale] applied over the whole app. Returns a context
/// inside the branch.
Future<BuildContext> _pumpShell(
  WidgetTester tester,
  Widget home, {
  double textScale = 1,
  String lang = 'en',
  List<Override> overrides = const [],
}) async {
  late BuildContext branch;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: layoutPhoneTheme,
        locale: Locale(lang),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Row(
          children: [
            const SizedBox(width: kRailWidth),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) {
                    branch = context;
                    return home;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  // The app's strings load asynchronously: the next frame has the content.
  await tester.pump();
  return branch;
}

/// Runs [body] at every layout width × text scale × [heights] × [langs],
/// clearing the screen after each.
Future<void> _forEachLayout(
  WidgetTester tester,
  Future<void> Function(
    String where,
    double width,
    double textScale,
    String lang,
  )
  body, {
  List<double> heights = const [800],
  List<String> langs = const ['en'],
}) async {
  addTearDown(tester.view.reset);
  for (final lang in langs) {
    for (final height in heights) {
      for (final width in kLayoutWidths) {
        for (final t in kLayoutTextScales) {
          setLayoutScreen(tester, width, height: height);
          await body(
            '$lang, ${width.toInt()}×${height.toInt()} dp at ${t}x',
            width,
            t,
            lang,
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  }
}

AppLocalizations _s(BuildContext context) => AppLocalizations.of(context);

/// Every line break in [finder]'s text falls between words: a box too narrow
/// for a word breaks it across lines without reporting any overflow.
void _expectWholeWords(WidgetTester tester, Finder finder, String where) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder);
  expect(paragraphs, isNotEmpty, reason: where);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    double? lastTop;
    for (var i = 0; i < text.length; i++) {
      final top = p.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dy;
      if (lastTop != null && top > lastTop + 0.5) {
        expect(
          text[i - 1].trim().isEmpty || text[i].trim().isEmpty,
          isTrue,
          reason:
              '$where: "$text" broken inside a word at '
              '"${text.substring(0, i)}|${text.substring(i)}"',
        );
      }
      lastTop = top;
    }
  }
}

/// [finder]'s text is drawn in full: not cut short with an ellipsis.
void _expectNotTruncated(WidgetTester tester, Finder finder, String where) {
  for (final p in tester.renderObjectList<RenderParagraph>(finder)) {
    expect(
      p.didExceedMaxLines,
      isFalse,
      reason: '$where: "${p.text.toPlainText()}" truncated',
    );
  }
}

/// Where every text, input, icon and button inside [finder] sits, relative to
/// it, in tree order.
List<Rect> _partRects(WidgetTester tester, Finder finder) {
  final origin = tester.getTopLeft(finder);
  final parts = find.descendant(
    of: finder,
    matching: find.byWidgetPredicate(
      (w) =>
          w is RichText ||
          w is EditableText ||
          w is ThinIcon ||
          w is ButtonStyleButton,
    ),
  );
  return [
    for (final element in parts.evaluate())
      if (element.renderObject case final RenderBox box)
        MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        ).shift(-origin),
  ];
}

/// Whether the text field [field] shows its paste button.
bool _hasPaste(Finder field) => find
    .descendant(of: field, matching: find.byTooltip('Paste'))
    .evaluate()
    .isNotEmpty;

/// The two buttons of the [ButtonPair] on screen, in child order.
List<Rect> _pairRects(WidgetTester tester) {
  final pair = tester.renderObject<RenderBox>(find.byType(ButtonPair));
  final rects = <Rect>[];
  pair.visitChildren((child) {
    final box = child as RenderBox;
    rects.add(
      MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      ),
    );
  });
  return rects;
}

void _expectSideBySide(WidgetTester tester, String where) {
  final [first, second] = _pairRects(tester);
  expect(first.center.dy, closeTo(second.center.dy, _eps), reason: where);
  expect(first.width, closeTo(second.width, _eps), reason: where);
  expect(second.left - first.right, closeTo(12, _eps), reason: where);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRoboto();
    // No biometrics in tests: the Recycle Bin's gate goes to the PIN path.
    dotenv.loadFromString(
      envString: 'ENABLE_FINGERPRINT_GATE=false\nENABLE_PIN_GATE=true',
    );
    CurrencyFormatter.setSymbol('৳');
  });

  setUp(() {
    // The settings provider reloads the symbol from preferences.
    SharedPreferences.setMockInitialValues({'currencySymbol': '৳'});
  });

  group('PIN sheet', () {
    Finder key(String digit) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(digit),
    );

    Future<void> checkSheet(
      WidgetTester tester,
      String where,
      double width,
    ) async {
      expectCleanLayout(tester, where);
      final sheet = tester.getRect(find.byType(BottomSheet));
      for (final digit in ['1', '3', '7', '9', '0']) {
        final pad = tester.getRect(
          find.ancestor(of: key(digit), matching: find.byType(InkWell)),
        );
        // Inside the sheet, and never shrunk below a comfortable target.
        expect(pad.left, greaterThanOrEqualTo(sheet.left), reason: where);
        expect(pad.right, lessThanOrEqualTo(sheet.right), reason: where);
        expect(pad.width, greaterThanOrEqualTo(48), reason: where);
        // Full size wherever it fits, as before (≥ 360 dp).
        if (width >= 360) expect(pad.width, closeTo(64, _eps), reason: where);
      }
    }

    testWidgets('setting a PIN lays out at every size', (tester) async {
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final branch = await _pumpShell(
            tester,
            const Scaffold(),
            textScale: t,
            lang: lang,
          );
          runPinSetup(
            branch,
            reason: _s(branch).tr('clearDataConfirmation'),
            service: _FakeAuth(),
          );
          await tester.pumpAndSettle();
          await checkSheet(tester, where, width);
          expectWholeText(tester, find.text(_s(branch).tr('createPin')), where);

          // Two different PINs: the mismatch error shows whole.
          for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8']) {
            await tester.ensureVisible(key(digit));
            await tester.tap(key(digit));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          final error = find.text(_s(branch).tr('pinDoesNotMatch'));
          expect(error, findsOneWidget, reason: where);
          expectWholeText(tester, error, where);
          await checkSheet(tester, where, width);
        },
        heights: _shortHeights,
        langs: _langs,
      );
    });

    testWidgets('a wrong PIN error shows whole at every size', (tester) async {
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final branch = await _pumpShell(
            tester,
            const Scaffold(),
            textScale: t,
            lang: lang,
          );
          runAuthGate(
            branch,
            reason: _s(branch).tr('emptyBin'),
            fingerprintEnabled: false,
            pinEnabled: true,
            service: _FakeAuth(pin: '1234'),
          );
          await tester.pumpAndSettle();
          expectWholeText(tester, find.text(_s(branch).tr('enterPin')), where);
          for (var i = 0; i < 4; i++) {
            await tester.ensureVisible(key('9'));
            await tester.tap(key('9'));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          final error = find.text(_s(branch).tr('incorrectPin'));
          expect(error, findsOneWidget, reason: where);
          expectWholeText(tester, error, where);
          await checkSheet(tester, where, width);
        },
        heights: _shortHeights,
        langs: _langs,
      );
    });

    testWidgets('keeps the error line at 18 px at 100%', (tester) async {
      addTearDown(tester.view.reset);
      setLayoutScreen(tester, 411);
      final branch = await _pumpShell(tester, const Scaffold());
      runAuthGate(
        branch,
        reason: 'Empty Bin',
        fingerprintEnabled: false,
        pinEnabled: true,
        service: _FakeAuth(pin: '1234'),
      );
      await tester.pumpAndSettle();
      final dots = tester.getRect(find.byType(Row).at(1));
      final firstKey = tester.getRect(
        find.ancestor(of: key('1'), matching: find.byType(InkWell)),
      );
      // Dots, 8, the 18 px error line, 8, then the pad (6 px key inset).
      final gapWithout = firstKey.top - dots.bottom;
      for (var i = 0; i < 4; i++) {
        await tester.tap(key('9'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final withError = tester
          .getRect(find.ancestor(of: key('1'), matching: find.byType(InkWell)))
          .top;
      expect(withError, closeTo(firstKey.top, _eps));
      expect(gapWithout, greaterThanOrEqualTo(8 + 18 + 8));
    });
  });

  group('ConfirmDialog', () {
    Future<void> check(
      WidgetTester tester, {
      required String Function(AppLocalizations s) title,
      required String Function(AppLocalizations s) message,
      required String Function(AppLocalizations s) confirm,
    }) async {
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final branch = await _pumpShell(
            tester,
            const Scaffold(),
            textScale: t,
            lang: lang,
          );
          final s = _s(branch);
          ConfirmDialog.show(
            branch,
            title: title(s),
            message: message(s),
            confirmText: confirm(s),
            cancelText: s.tr('cancel'),
            isDestructive: true,
            icon: tabler.TrashX.new,
          );
          await tester.pumpAndSettle();
          expectCleanLayout(tester, where);
          // A long title or message scrolls; never cut off.
          expectWholeText(tester, find.text(title(s)), where);
          expectWholeText(tester, find.text(message(s)), where);
          _expectWholeWords(tester, find.text(s.tr('cancel')), where);
          _expectWholeWords(tester, find.text(confirm(s)), where);
          // Unchanged on a phone at 100%: the buttons side by side.
          if (lang == 'en' && t == 1 && width >= 360) {
            requireRoboto();
            _expectSideBySide(tester, where);
          }
        },
        heights: [800, 568],
        langs: _langs,
      );
    }

    testWidgets('a short confirmation lays out at every size', (tester) async {
      requireRoboto();
      await check(
        tester,
        title: (s) => s.tr('deleteForever'),
        message: (s) => s.tr('deleteForeverConfirm'),
        confirm: (s) => s.tr('delete'),
      );
    });

    testWidgets(
      'a long title, message and confirm label lay out at every size',
      (tester) async {
        requireRoboto();
        await check(
          tester,
          title: (s) => s.tr('clearAllData'),
          message: (s) => s.tr('clearDataConfirmation'),
          confirm: (s) => s.tr('clearAllData'),
        );
      },
    );

    testWidgets('a long name in the message lays out at every size', (
      tester,
    ) async {
      requireRoboto();
      await check(
        tester,
        title: (s) => s.tr('deleteSupplier'),
        message: (s) =>
            '${s.tr('delete')} "$_longName"? ${s.tr('deleteSupplierConfirm')}',
        confirm: (s) => s.tr('delete'),
      );
    });

    testWidgets('keeps reading order in RTL, side by side or stacked', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      // A confirm label too long for half the dialog makes it stack.
      const long = 'Supercalifragilisticexpialidocious';
      for (final (width, t, label) in [
        (411.0, 1.0, null),
        (320.0, 1.5, long),
      ]) {
        final stacked = label != null;
        final where = 'ar at ${width}dp, ${t}x';
        setLayoutScreen(tester, width);
        final branch = await _pumpShell(
          tester,
          const Scaffold(),
          textScale: t,
          lang: 'ar',
        );
        final s = _s(branch);
        ConfirmDialog.show(
          branch,
          title: s.tr('deleteForever'),
          message: s.tr('deleteForeverConfirm'),
          confirmText: label ?? s.tr('delete'),
        );
        await tester.pumpAndSettle();
        expectCleanLayout(tester, where);
        final [cancel, confirm] = _pairRects(tester);
        if (stacked) {
          // Cancel first, on top.
          expect(cancel.bottom, lessThan(confirm.top), reason: where);
          expect(cancel.width, closeTo(confirm.width, _eps), reason: where);
        } else {
          // Cancel at the start, which is the right in RTL.
          expect(
            cancel.center.dy,
            closeTo(confirm.center.dy, _eps),
            reason: where,
          );
          expect(cancel.left, greaterThan(confirm.right), reason: where);
        }
        // The default cancel label is the localized one.
        expect(find.text(s.tr('cancel')), findsOneWidget, reason: where);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('ButtonPair', () {
    Widget pair({String first = 'Cancel', String second = 'Delete'}) =>
        ButtonPair(
          first: OutlinedButton(onPressed: () {}, child: Text(first)),
          second: FilledButton(onPressed: () {}, child: Text(second)),
        );

    // What ConfirmDialog and the PDF saved sheet used before.
    Widget row({String first = 'Cancel', String second = 'Delete'}) => Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: () {}, child: Text(first)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(onPressed: () {}, child: Text(second)),
        ),
      ],
    );

    testWidgets('lays out and sizes as a Row of two Expanded buttons when '
        'they fit', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      setLayoutScreen(tester, 411);
      for (final (first, second) in [
        ('Cancel', 'Delete'),
        // Wrapped between words in its half, as the Row did.
        ('Cancel', 'Clear all of the data'),
      ]) {
        await _pumpShell(
          tester,
          Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 248,
                  child: pair(first: first, second: second),
                ),
                SizedBox(
                  width: 248,
                  child: row(first: first, second: second),
                ),
              ],
            ),
          ),
        );
        expectCleanLayout(tester, '$first / $second');
        final pairBox = tester.renderObject<RenderBox>(find.byType(ButtonPair));
        final rowBox = tester.renderObject<RenderBox>(find.byType(Row).last);
        expect(pairBox.size, rowBox.size);
        // Dialogs size themselves from these.
        expect(
          pairBox.getMaxIntrinsicWidth(double.infinity),
          closeTo(rowBox.getMaxIntrinsicWidth(double.infinity), _eps),
        );
        expect(
          pairBox.getMaxIntrinsicHeight(248),
          closeTo(rowBox.getMaxIntrinsicHeight(248), _eps),
        );
        expect(
          pairBox.getDryLayout(const BoxConstraints(maxWidth: 248)),
          pairBox.size,
        );
        const constraints = BoxConstraints(maxWidth: 248);
        expect(
          pairBox.getDryBaseline(constraints, TextBaseline.alphabetic),
          rowBox.getDryBaseline(constraints, TextBaseline.alphabetic),
        );
        // The buttons sit where the Row put them.
        for (final label in [first, second]) {
          final buttons = find.ancestor(
            of: find.text(label),
            matching: find.byType(Material),
          );
          final inPair = tester.getRect(buttons.first);
          final inRow = tester.getRect(
            buttons.at(buttons.evaluate().length ~/ 2),
          );
          expect(
            inPair.shift(
              Offset(
                0,
                rowBox.localToGlobal(Offset.zero).dy -
                    pairBox.localToGlobal(Offset.zero).dy,
              ),
            ),
            inRow,
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('stacks the buttons full width when a word would not fit', (
      tester,
    ) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      setLayoutScreen(tester, 411);
      await _pumpShell(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: pair(first: 'Cancel', second: 'Supercalifragilistic'),
            ),
          ),
        ),
      );
      expectCleanLayout(tester, 'stacked');
      final [first, second] = _pairRects(tester);
      expect(first.width, closeTo(200, _eps));
      expect(second.width, closeTo(200, _eps));
      expect(second.top - first.bottom, closeTo(8, _eps));
      _expectWholeWords(tester, find.text('Supercalifragilistic'), 'stacked');
      final box = tester.renderObject<RenderBox>(find.byType(ButtonPair));
      expect(box.getDryLayout(const BoxConstraints(maxWidth: 200)), box.size);
      expect(box.getMinIntrinsicHeight(200), closeTo(box.size.height, _eps));
      // Each stays tappable.
      await tester.tap(find.text('Supercalifragilistic'));
      await tester.tap(find.text('Cancel'));
    });
  });

  testWidgets('the rate dialog lays out at every size', (tester) async {
    requireRoboto();
    await _forEachLayout(
      tester,
      (where, width, t, lang) async {
        final branch = await _pumpShell(
          tester,
          const Scaffold(),
          textScale: t,
          lang: lang,
        );
        showDialog<RateAppChoice>(
          context: branch,
          builder: (_) => const RateAppDialog(),
        );
        await tester.pumpAndSettle();
        expectCleanLayout(tester, where);
        // The message scrolls on a short screen; never cut off.
        expectWholeText(tester, find.textContaining('Micro Seller'), where);
        for (final key in ['noThanks', 'rateLater', 'rateNow']) {
          _expectWholeWords(tester, find.text(_s(branch).tr(key)), where);
        }
      },
      heights: [800, 568],
      langs: ['en', 'pt', 'fr', 'es', 'tr', 'id'],
    );
  });

  testWidgets('the PDF saved sheet lays out at every size', (tester) async {
    requireRoboto();
    await _forEachLayout(
      tester,
      (where, width, t, lang) async {
        final branch = await _pumpShell(
          tester,
          const Scaffold(),
          textScale: t,
          lang: lang,
        );
        showPdfSavedSheet(
          context: branch,
          filePath: '/storage/emulated/0/Download/INV-12345.pdf',
          savedToDirectory:
              '/storage/emulated/0/Download/Micro Seller/Invoices/$_longName',
        );
        await tester.pumpAndSettle();
        expectCleanLayout(tester, where);
        final s = _s(branch);
        expectWholeText(tester, find.text(s.tr('pdfSavedTo')), where);
        _expectWholeWords(tester, find.text(s.tr('close')), where);
        _expectWholeWords(tester, find.text(s.tr('open')), where);
        // Unchanged on a phone at 100%: the buttons side by side.
        if (lang == 'en' && t == 1 && width >= 360) {
          _expectSideBySide(tester, where);
        }
      },
      heights: [800, 568],
      langs: _langs,
    );
  });

  group('EmptyState', () {
    Widget screen(String title, String subtitle, String action) => Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(64),
          child: Padding(padding: EdgeInsets.all(8), child: TextField()),
        ),
      ),
      body: EmptyState(
        icon: tabler.Users.new,
        title: title,
        subtitle: subtitle,
        actionLabel: action,
        onAction: () {},
      ),
    );

    testWidgets('scrolls instead of overflowing, keyboard up or down', (
      tester,
    ) async {
      for (final keyboard in [0.0, 300.0]) {
        await _forEachLayout(tester, (where, width, t, lang) async {
          if (keyboard > 0) {
            tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
          }
          await _pumpShell(
            tester,
            screen(
              'No customers found for "$_longName"',
              'Add your first customer to start tracking orders and dues',
              'Add Customer',
            ),
            textScale: t,
            lang: lang,
          );
          final at = '$where, keyboard $keyboard';
          expectCleanLayout(tester, at);
          expectWholeText(tester, find.textContaining('No customers'), at);
          expectWholeText(tester, find.textContaining('first customer'), at);
          // The action label is shrunk to fit rather than broken mid-word.
          _expectWholeWords(tester, find.text('Add Customer'), at);
          await tester.dragUntilVisible(
            find.text('Add Customer'),
            find.byType(SingleChildScrollView),
            const Offset(0, -100),
          );
          await tester.tap(find.text('Add Customer'));
        }, heights: [800, 640]);
      }
    });

    testWidgets('is unchanged where it fits', (tester) async {
      requireRoboto();
      addTearDown(tester.view.reset);
      for (final width in [360.0, 411.0]) {
        setLayoutScreen(tester, width);
        await _pumpShell(
          tester,
          screen('No customers yet', 'Add your first customer', 'Add Customer'),
        );
        expectCleanLayout(tester, '$width dp');
        final body = tester.getRect(find.byType(EmptyState));
        final column = tester.getRect(
          find
              .descendant(
                of: find.byType(EmptyState),
                matching: find.byType(Column),
              )
              .first,
        );
        // Centered both ways, 48 px in from its edges at most.
        expect(column.center.dx, closeTo(body.center.dx, _eps));
        expect(column.center.dy, closeTo(body.center.dy, _eps));
        final label = find.text('Add Customer');
        expect(
          tester.getRect(label).width,
          closeTo(tester.getSize(label).width, _eps),
          reason: 'drawn at full size',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  testWidgets('full-width buttons wrap long labels instead of overflowing', (
    tester,
  ) async {
    requireRoboto();
    await _forEachLayout(tester, (where, width, t, lang) async {
      await _pumpShell(
        tester,
        Builder(
          builder: (context) {
            final s = _s(context);
            return Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final key in ['submitReturnRequest', 'applyAdjustment'])
                    for (final variant in AppButtonVariant.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppButton(
                          label: s.tr(key),
                          icon: tabler.Check.new,
                          variant: variant,
                          isFullWidth: true,
                          height: 52,
                          onPressed: () {},
                        ),
                      ),
                ],
              ),
            );
          },
        ),
        textScale: t,
        lang: lang,
      );
      expectCleanLayout(tester, where);
      for (final p in tester.renderObjectList<RenderParagraph>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(RichText),
        ),
      )) {
        _expectWholeWords(
          tester,
          find.byElementPredicate((e) => e.renderObject == p),
          where,
        );
      }
    }, langs: ['en', 'pt', 'fr', 'id']);
  });

  testWidgets('buttons are unchanged where the label fits', (tester) async {
    requireRoboto();
    addTearDown(tester.view.reset);
    // AppButton as it was before its label could wrap: the icon and a label
    // as wide as its text in a Row.
    Widget before(AppButtonVariant variant, String label, {double? height}) {
      final minimumSize = height == null ? null : Size.fromHeight(height);
      final child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ThinIcon(tabler.Check.new, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
      return switch (variant) {
        AppButtonVariant.filled => FilledButton(
          onPressed: () {},
          style: minimumSize == null
              ? null
              : FilledButton.styleFrom(minimumSize: minimumSize),
          child: child,
        ),
        AppButtonVariant.outlined => OutlinedButton(
          onPressed: () {},
          style: minimumSize == null
              ? null
              : OutlinedButton.styleFrom(minimumSize: minimumSize),
          child: child,
        ),
        AppButtonVariant.text => TextButton(onPressed: () {}, child: child),
        AppButtonVariant.destructive => FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: minimumSize,
          ),
          child: Text(label),
        ),
      };
    }

    const labels = ['Save', 'Apply Adjustment'];
    for (final (width, t) in [(360.0, 1.0), (411.0, 1.0), (411.0, 1.5)]) {
      final where = '${width.toInt()} dp at ${t}x';
      setLayoutScreen(tester, width);
      await _pumpShell(
        tester,
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final label in labels)
                for (final variant in AppButtonVariant.values) ...[
                  // Full width, then as wide as its content.
                  KeyedSubtree(
                    key: ValueKey('app $label $variant'),
                    child: AppButton(
                      label: label,
                      icon: tabler.Check.new,
                      variant: variant,
                      isFullWidth: true,
                      height: 52,
                      onPressed: () {},
                    ),
                  ),
                  KeyedSubtree(
                    key: ValueKey('before $label $variant'),
                    child: SizedBox(
                      width: double.infinity,
                      child: before(variant, label, height: 52),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: KeyedSubtree(
                      key: ValueKey('app $label $variant, wrapped'),
                      child: AppButton(
                        label: label,
                        icon: tabler.Check.new,
                        variant: variant,
                        onPressed: () {},
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: KeyedSubtree(
                      key: ValueKey('before $label $variant, wrapped'),
                      child: before(variant, label),
                    ),
                  ),
                ],
            ],
          ),
        ),
        textScale: t,
      );
      expectCleanLayout(tester, where);
      for (final label in labels) {
        for (final variant in AppButtonVariant.values) {
          for (final kind in ['', ', wrapped']) {
            final at = '$where: $label, $variant$kind';
            final app = find.byKey(ValueKey('app $label $variant$kind'));
            final old = find.byKey(ValueKey('before $label $variant$kind'));
            await tester.ensureVisible(app);
            await tester.pump();
            expect(tester.getSize(app), tester.getSize(old), reason: at);
            final parts = _partRects(tester, app);
            expect(parts, isNotEmpty, reason: at);
            expect(parts, _partRects(tester, old), reason: at);
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the aging legend wraps in a narrow card', (tester) async {
    await _forEachLayout(tester, (where, width, t, lang) async {
      await _pumpShell(
        tester,
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AgingBar(
                  under30: 12345678.9,
                  from30to60: 2345678.9,
                  over60: 98765432.1,
                ),
              ),
            ),
          ),
        ),
        textScale: t,
        lang: lang,
      );
      expectCleanLayout(tester, where);
      expectWholeText(tester, find.textContaining('৳'), where);
    }, langs: ['en', 'pt', 'fr', 'id']);
  });

  testWidgets('text fields show helper and error texts whole', (tester) async {
    requireRoboto();
    await _forEachLayout(tester, (where, width, t, lang) async {
      final formKey = GlobalKey<FormState>();
      await _pumpShell(
        tester,
        Builder(
          builder: (context) {
            return Scaffold(
              body: Form(
                key: formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AppTextField(
                      label: 'Phone',
                      controller: TextEditingController(text: '01712abc345'),
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Quantity',
                      controller: TextEditingController(text: '12345678'),
                      helperText: _s(context).tr('willDeductFromStock'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        textScale: t,
        lang: lang,
      );
      formKey.currentState!.validate();
      await tester.pump();
      expectCleanLayout(tester, where);
      final error = find.text(Validators.phone('01712abc345')!);
      expect(error, findsOneWidget, reason: where);
      _expectNotTruncated(tester, error, where);
      _expectNotTruncated(
        tester,
        find.textContaining(RegExp('stock|stoque|stock')),
        where,
      );
    }, langs: _langs);
  });

  group('the paste button', () {
    Widget scan() => IconButton(
      icon: const ThinIcon(tabler.Scan.new),
      tooltip: 'Scan',
      onPressed: () {},
    );

    Widget field(
      String label, {
      String text = '12345',
      String? hint,
      String? helper,
      Widget? prefixIcon,
      Widget? suffixIcon,
      int maxLines = 1,
      bool readOnly = false,
    }) => AppTextField(
      label: label,
      hint: hint,
      controller: TextEditingController(text: text),
      helperText: helper,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      maxLines: maxLines,
      readOnly: readOnly,
    );

    // AppTextField as it was before its paste button could give way and its
    // helper text wrap.
    Widget before(
      String label, {
      String text = '12345',
      String? hint,
      String? helper,
      Widget? prefixIcon,
      Widget? suffixIcon,
      int maxLines = 1,
      bool readOnly = false,
    }) {
      final paste = IconButton(
        icon: const ThinIcon(tabler.Clipboard.new, size: 18),
        tooltip: 'Paste',
        onPressed: () {},
      );
      return TextFormField(
        controller: TextEditingController(text: text),
        maxLines: maxLines,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon,
          suffixIcon: readOnly
              ? suffixIcon
              : suffixIcon == null
              ? paste
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [paste, suffixIcon],
                ),
          helperText: helper,
          counterText: '',
        ),
      );
    }

    testWidgets('gives way where the value would get less than 3 em', (
      tester,
    ) async {
      requireRoboto();
      const pair = ['Discount', 'Delivery Fee'];
      const labels = [...pair, 'Amount Paid', 'Tax / VAT (%)', 'QR / Barcode'];
      await _forEachLayout(tester, (where, width, t, lang) async {
        // As the forms lay them out: two side by side (the order form's
        // discount, empty, and delivery fee), one beside a button (amount
        // paid and Pay Full), one with a prefix icon (tax rate) and one
        // with a suffix icon of its own (the product form's QR code).
        await _pumpShell(
          tester,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: field(pair[0], text: '')),
                    const SizedBox(width: 12),
                    Expanded(child: field(pair[1])),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: field('Amount Paid')),
                    const SizedBox(width: 8),
                    TextButton(onPressed: () {}, child: const Text('Pay Full')),
                  ],
                ),
                const SizedBox(height: 12),
                field(
                  'Tax / VAT (%)',
                  prefixIcon: const ThinIcon(tabler.Percentage.new, size: 18),
                ),
                const SizedBox(height: 12),
                field('QR / Barcode', suffixIcon: scan()),
              ],
            ),
          ),
          textScale: t,
          lang: lang,
        );
        expectCleanLayout(tester, where);
        for (final label in labels) {
          final at = '$where, $label';
          final box = find.widgetWithText(AppTextField, label);
          final input = tester
              .getSize(
                find.descendant(of: box, matching: find.byType(EditableText)),
              )
              .width;
          // What the button takes from the value: its 48 dp box instead of
          // the 16 dp end padding, or beside the suffix icon.
          final cost = label == 'QR / Barcode' ? 48.0 : 32.0;
          if (_hasPaste(box)) {
            // 3 em of the field's 16 px text, at the current text size.
            expect(input, greaterThanOrEqualTo(48 * t - _eps), reason: at);
          } else {
            // Left out only where the value would have got less.
            expect(input - cost, lessThan(48 * t), reason: at);
          }
          // As before on a phone at 100%.
          if (width >= 360 && t == 1) {
            expect(_hasPaste(box), isTrue, reason: at);
          }
        }
        // Two side by side on the narrowest layout: the value and the label
        // get the button's room.
        if (width == 320) {
          for (final label in pair) {
            final box = find.widgetWithText(AppTextField, label);
            expect(_hasPaste(box), isFalse, reason: '$where, $label');
          }
          if (t == 1) {
            _expectNotTruncated(tester, find.text(pair[0]), where);
          }
        }
      });
    });

    testWidgets('is unchanged where it fits', (tester) async {
      addTearDown(tester.view.reset);
      const percent = ThinIcon(tabler.Percentage.new, size: 18);
      for (final (width, t) in [
        (360.0, 1.0),
        (411.0, 1.0),
        (411.0, 1.3),
        (411.0, 1.5),
      ]) {
        final where = '${width.toInt()} dp at ${t}x';
        setLayoutScreen(tester, width);
        const hint = 'Leave empty if the customer will pay later';
        const helper = 'Tax: ৳12.50';
        final pairs = <(Widget, Widget)>[
          (field('Customer Name', text: ''), before('Customer Name', text: '')),
          (
            field('Amount Paid', text: '', hint: hint),
            before('Amount Paid', text: '', hint: hint),
          ),
          (
            field('Tax / VAT (%)', prefixIcon: percent, helper: helper),
            before('Tax / VAT (%)', prefixIcon: percent, helper: helper),
          ),
          (
            field('QR / Barcode', text: '', suffixIcon: scan()),
            before('QR / Barcode', text: '', suffixIcon: scan()),
          ),
          (
            field('Notes', text: 'After 5 pm, please', maxLines: 2),
            before('Notes', text: 'After 5 pm, please', maxLines: 2),
          ),
          (
            field('Order Number', readOnly: true),
            before('Order Number', readOnly: true),
          ),
        ];
        await _pumpShell(
          tester,
          Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Two side by side, as the order form's discount and
                // delivery fee.
                Row(
                  children: [
                    Expanded(
                      child: KeyedSubtree(
                        key: const ValueKey('app 0'),
                        child: field('Discount'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KeyedSubtree(
                        key: const ValueKey('before 0'),
                        child: before('Discount'),
                      ),
                    ),
                  ],
                ),
                for (final (i, (app, old)) in pairs.indexed) ...[
                  const SizedBox(height: 12),
                  KeyedSubtree(key: ValueKey('app ${i + 1}'), child: app),
                  const SizedBox(height: 12),
                  KeyedSubtree(key: ValueKey('before ${i + 1}'), child: old),
                ],
              ],
            ),
          ),
          textScale: t,
        );
        await tester.pumpAndSettle();
        expectCleanLayout(tester, where);
        for (var i = 0; i <= pairs.length; i++) {
          final at = '$where, field $i';
          final app = find.byKey(ValueKey('app $i'));
          final old = find.byKey(ValueKey('before $i'));
          await tester.ensureVisible(app);
          await tester.pump();
          expect(tester.getSize(app), tester.getSize(old), reason: at);
          final parts = _partRects(tester, app);
          expect(parts, isNotEmpty, reason: at);
          expect(parts, _partRects(tester, old), reason: at);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('keeps the text and the focus when it comes and goes', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final controller = TextEditingController(text: '12345');
      final focus = FocusNode();
      setLayoutScreen(tester, 411);
      await _pumpShell(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Discount',
                    controller: controller,
                    focusNode: focus,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      final box = find.byType(AppTextField);
      expect(_hasPaste(box), isTrue);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      final editable = tester.state(find.byType(EditableText));
      // The window narrows (Display size), and back.
      for (final (width, paste) in [(320.0, false), (411.0, true)]) {
        setLayoutScreen(tester, width);
        await tester.pump();
        expect(_hasPaste(box), paste, reason: '$width dp');
        expect(focus.hasFocus, isTrue, reason: '$width dp');
        expect(controller.text, '12345', reason: '$width dp');
        expect(
          tester.state(find.byType(EditableText)),
          same(editable),
          reason: '$width dp',
        );
      }
    });

    testWidgets('pastes the clipboard text', (tester) async {
      addTearDown(tester.view.reset);
      setLayoutScreen(tester, 411);
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object>{'text': '01712-345678'}
            : null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final controller = TextEditingController(text: '017');
      await _pumpShell(
        tester,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(label: 'Phone', controller: controller),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Paste'));
      await tester.pump();
      expect(controller.text, '01712-345678');
      expect(controller.selection, const TextSelection.collapsed(offset: 12));
    });
  });

  testWidgets('the payment method chips wrap in a bottom sheet', (
    tester,
  ) async {
    await _forEachLayout(tester, (where, width, t, lang) async {
      final branch = await _pumpShell(
        tester,
        const Scaffold(),
        textScale: t,
        lang: lang,
      );
      AppBottomSheet.show<void>(
        branch,
        title: 'Collect · $_longName · ৳12,345,678.90',
        child: PaymentMethodChips(
          selected: PaymentMethod.mfs,
          onChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      expectCleanLayout(tester, where);
      expectWholeText(tester, find.textContaining(_longName), where);
      for (final chip in tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      )) {
        final rect = tester.getRect(find.byWidget(chip));
        expect(rect.right, lessThanOrEqualTo(width + _eps), reason: where);
      }
    }, langs: _langs);
  });

  testWidgets('the loading overlay and progress spinner fit', (tester) async {
    await _forEachLayout(tester, (where, width, t, lang) async {
      final branch = await _pumpShell(
        tester,
        Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              leading: const DrawerMenuButton(),
              title: Text(_s(context).tr('recycleBin')),
            ),
            body: LoadingOverlay(
              isLoading: true,
              message: _s(context).tr('clearDataConfirmation'),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        textScale: t,
        lang: lang,
      );
      expectCleanLayout(tester, where);
      expectWholeText(
        tester,
        find.text(_s(branch).tr('clearDataConfirmation')),
        where,
      );
      final task = Completer<void>();
      final progress = runWithProgress(branch, () => task.future);
      await tester.pump();
      await tester.pump();
      expect(
        find.byType(CircularProgressIndicator),
        findsNWidgets(2),
        reason: where,
      );
      expectCleanLayout(tester, '$where, progress');
      task.complete();
      await progress;
      await tester.pump();
    }, langs: _langs);
  });

  group('Recycle Bin', () {
    final now = DateTime.now();
    final entries = [
      for (final kind in TrashKind.values)
        TrashEntry(
          id: kind.index + 1,
          kind: kind,
          originalId: kind.index + 1,
          payload: '{}',
          label: '$_longName ${kind.name}',
          sublabel: '৳12,345,678.90 · SKU-LONG-PRODUCT-CODE-0001-XL',
          deletedAt: now.subtract(Duration(days: kind.index * 4)),
        ),
      // No label: the kind's name stands in.
      TrashEntry(
        id: 99,
        kind: TrashKind.purchase,
        originalId: 9,
        payload: '{}',
        label: '',
      ),
    ];

    Future<BuildContext> pumpBin(
      WidgetTester tester,
      double t,
      String lang,
      List<TrashEntry> entries,
    ) async {
      final branch = await _pumpShell(
        tester,
        const Scaffold(),
        textScale: t,
        lang: lang,
        overrides: [
          trashEntriesProvider.overrideWithValue(AsyncValue.data(entries)),
        ],
      );
      // Opened from Settings, as in the app: under a back button.
      Navigator.of(
        branch,
      ).push(MaterialPageRoute<void>(builder: (_) => const RecycleBinScreen()));
      await tester.pumpAndSettle();
      return branch;
    }

    testWidgets('lists long entries at every size', (tester) async {
      requireRoboto();
      await _forEachLayout(tester, (where, width, t, lang) async {
        final branch = await pumpBin(tester, t, lang, entries);
        expectCleanLayout(tester, where);
        final s = _s(branch);
        expectWholeText(tester, find.text(s.tr('recycleBin')), where);
        expectWholeText(
          tester,
          find.text(s.tr('recycleBinRetentionNote')),
          where,
        );
        expectWholeText(tester, find.textContaining(_longName), where);
        expectWholeText(tester, find.textContaining('SKU-LONG'), where);
        // Restore and delete stay inside the screen.
        for (final button in tester.widgetList(find.byType(IconButton))) {
          final rect = tester.getRect(find.byWidget(button));
          expect(rect.right, lessThanOrEqualTo(width + _eps), reason: where);
        }

        // Delete forever asks first.
        await tester.tap(find.byTooltip(s.tr('deleteForever')).first);
        await tester.pumpAndSettle();
        expectCleanLayout(tester, '$where, delete forever');
        expectWholeText(tester, find.text(s.tr('deleteForeverConfirm')), where);
        _expectWholeWords(tester, find.text(s.tr('delete')), where);
        await tester.tap(find.text(s.tr('cancel')));
        await tester.pumpAndSettle();

        // Emptying the bin asks, then goes through the PIN gate.
        await tester.tap(find.text(s.tr('emptyBin')));
        await tester.pumpAndSettle();
        expectCleanLayout(tester, '$where, empty bin');
        expectWholeText(tester, find.text(s.tr('emptyBinConfirm')), where);
        await tester.tap(find.text(s.tr('delete')));
        await tester.pumpAndSettle();
        expectCleanLayout(tester, '$where, PIN');
        expect(find.text(s.tr('createPin')), findsOneWidget, reason: where);
        expectWholeText(tester, find.text(s.tr('createPin')), where);
        await tester.tap(find.byType(IconButton).last);
        await tester.pumpAndSettle();
      }, langs: ['en', 'pt', 'fr', 'tr']);
    });

    testWidgets('shows its empty state at every size', (tester) async {
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final branch = await pumpBin(tester, t, lang, const []);
          expectCleanLayout(tester, where);
          final s = _s(branch);
          expectWholeText(tester, find.text(s.tr('recycleBinEmpty')), where);
          expectWholeText(
            tester,
            find.text(s.tr('recycleBinEmptyHint')),
            where,
          );
        },
        heights: [800, 600],
        langs: ['en', 'pt', 'fr', 'tr'],
      );
    });
  });

  group('the keyboard bar over the number pads (iOS)', () {
    const keyboard = 300.0;

    /// The app's iOS theme and strings in [lang] at [textScale], the bar's
    /// host around the router as the app frame has it, and a decimal field
    /// whose action is next, focused, with the keyboard up.
    Future<BuildContext> pumpBar(
      WidgetTester tester, {
      required double textScale,
      required String lang,
    }) async {
      late BuildContext screen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: Locale(lang),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: KeyboardAccessoryHost(child: child!),
          ),
          home: Row(
            children: [
              const SizedBox(width: kRailWidth),
              Expanded(
                child: Scaffold(
                  body: Builder(
                    builder: (context) {
                      screen = context;
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: TextField(
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding(
        bottom: keyboard * tester.view.devicePixelRatio,
      );
      await tester.pump();
      return screen;
    }

    Finder bar(BuildContext screen) => find.ancestor(
      of: find.text(_s(screen).tr('done')),
      matching: find.byType(TextFieldTapRegion),
    );

    testWidgets('Next and Done lay out on one line at every size', (
      tester,
    ) async {
      requireRoboto();
      await _forEachLayout(
        tester,
        (where, width, t, lang) async {
          final screen = await pumpBar(tester, textScale: t, lang: lang);
          expectCleanLayout(tester, where);
          final s = _s(screen);
          final next = find.text(s.tr('next'));
          final done = find.text(s.tr('done'));
          final rect = tester.getRect(bar(screen));
          // The whole window wide, on the keyboard, 44 dp or taller.
          expect(rect.left, closeTo(0, _eps), reason: where);
          expect(rect.right, closeTo(width, _eps), reason: where);
          expect(rect.bottom, closeTo(800 - keyboard, _eps), reason: where);
          expect(
            rect.height,
            closeTo(
              keyboardAccessoryBarHeight(TextScaler.linear(t)),
              _eps,
            ),
            reason: where,
          );
          for (final label in [next, done]) {
            expectWholeText(tester, label, where);
            _expectNotTruncated(tester, label, where);
            // One line: the text ends on the line it starts on.
            final p = tester.renderObject<RenderParagraph>(label);
            final length = p.text.toPlainText().length;
            expect(
              p.getOffsetForCaret(TextPosition(offset: length), Rect.zero).dy,
              closeTo(
                p.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dy,
                1,
              ),
              reason: where,
            );
            final drawn = tester.getRect(label);
            expect(drawn.top, greaterThanOrEqualTo(rect.top - _eps));
            expect(drawn.bottom, lessThanOrEqualTo(rect.bottom + _eps));
          }
          // Next at the start, Done at the end, apart.
          expect(
            tester.getRect(next).right,
            lessThan(tester.getRect(done).left),
            reason: where,
          );
          // Drawn at full size where it fits: English on a phone.
          if (lang == 'en' && width >= 360) {
            for (final label in [next, done]) {
              expect(
                tester.getSize(label),
                tester.renderObject<RenderParagraph>(label).size,
                reason: where,
              );
            }
          }
          tester.view.resetViewInsets();
        },
        langs: ['en', 'pt', 'ms', 'bn'],
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('right to left, Next is on the right and Done on the left', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      setLayoutScreen(tester, 360);
      final screen = await pumpBar(tester, textScale: 1, lang: 'ar');
      expectCleanLayout(tester, 'ar');
      final s = _s(screen);
      expect(
        tester.getRect(find.text(s.tr('next'))).left,
        greaterThan(tester.getRect(find.text(s.tr('done'))).right),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
