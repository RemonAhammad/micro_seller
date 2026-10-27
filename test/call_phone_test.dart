// Calling a customer or supplier. A device without a phone (most iPads, an
// iPod touch, a tablet without a dialer) can't place the call: iOS answers
// false, Android throws. Instead of a call button that does nothing, the
// seller gets a sheet with the number, readable left to right in every
// language, and Copy number.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_strings.dart';
import 'package:micro_seller/shared/widgets/call_phone.dart';
// url_launcher's platform side, faked below so callPhone's real launchUrl
// runs without a device. A dependency of url_launcher, not of the app.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/layout_harness.dart';

/// url_launcher without a device: records what it was asked to open, and
/// answers [result], or throws it when it isn't a bool.
class _FakeLauncher extends UrlLauncherPlatform {
  final launched = <String>[];
  Object result = true;

  @override
  get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    final result = this.result;
    if (result is bool) return result;
    throw result;
  }
}

const _phone = '+880 1712-345678';

void main() {
  late UrlLauncherPlatform realLauncher;
  late _FakeLauncher launcher;

  setUpAll(() async {
    realLauncher = UrlLauncherPlatform.instance;
    await loadRoboto();
  });
  tearDownAll(() => UrlLauncherPlatform.instance = realLauncher);

  setUp(() {
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  /// A screen with a Call button for [phone], as the Due Book, supplier
  /// detail and order detail have.
  Widget callScreen([String phone = _phone]) => Scaffold(
    body: Center(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => callPhone(context, phone),
          child: const Text('Call'),
        ),
      ),
    ),
  );

  // The app's strings, in the language the app is shown in.
  strings(WidgetTester tester) =>
      AppStrings.of(tester.element(find.byType(Scaffold).first));

  test('telUri keeps what a phone dials', () {
    expect(telUri(_phone).toString(), 'tel:+8801712345678');
    expect(telUri('(555) 123-4567').toString(), 'tel:5551234567');
    expect(telUri(' +44 20 7946 0958 ').toString(), 'tel:+442079460958');
    expect(telUri('০১৭১২৩৪৫৬৭৮').toString(), 'tel:01712345678');
    expect(telUri('+৮৮০ ১৭১২').toString(), 'tel:+8801712');
    // A + after a digit isn't dialed.
    expect(telUri('880+1').toString(), 'tel:8801');
    // A USSD code: '#' would start a URI fragment, so it is escaped.
    expect(telUri('*123#').toString(), 'tel:*123%23');
    expect(Uri.decodeComponent(telUri('*123#')!.path), '*123#');
    // Nothing to dial.
    expect(telUri(''), isNull);
    expect(telUri('+'), isNull);
    expect(telUri('n/a'), isNull);
  });

  testWidgets('a phone calls, with no sheet', (tester) async {
    await pumpLayoutApp(tester, callScreen(), rail: false);
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['tel:+8801712345678']);
    expect(find.text(strings(tester).callNotAvailable), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  for (final (device, result) in [
    ('iOS', false as Object),
    ('Android', PlatformException(code: 'ACTIVITY_NOT_FOUND') as Object),
  ]) {
    testWidgets('a device that can\'t call ($device) shows the number', (
      tester,
    ) async {
      launcher.result = result;
      await pumpLayoutApp(tester, callScreen(), rail: false);
      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();
      expect(launcher.launched, ['tel:+8801712345678']);
      expect(tester.takeException(), isNull);
      final s = strings(tester);
      expect(find.text(s.callNotAvailable), findsOneWidget);
      expect(find.text(_phone), findsOneWidget);
      expect(find.text(s.copyNumber), findsOneWidget);
    });
  }

  testWidgets('a number with nothing to dial shows the sheet too', (
    tester,
  ) async {
    await pumpLayoutApp(tester, callScreen('n/a'), rail: false);
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    expect(launcher.launched, isEmpty);
    expect(find.text(strings(tester).callNotAvailable), findsOneWidget);
  });

  testWidgets('Copy number copies it, closes the sheet and says so', (
    tester,
  ) async {
    final copied = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add(call.arguments);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    launcher.result = false;
    await pumpLayoutApp(tester, callScreen(), rail: false);
    await tester.tap(find.text('Call'));
    await tester.pumpAndSettle();
    final s = strings(tester);
    await tester.tap(find.text(s.copyNumber));
    await tester.pumpAndSettle();
    expect(copied, [
      {'text': _phone},
    ]);
    expect(find.text(s.callNotAvailable), findsNothing);
    expect(find.text(s.numberCopied), findsOneWidget);
  });

  testWidgets('the sheet lays out at every size, in English and Arabic', (
    tester,
  ) async {
    launcher.result = false;
    addTearDown(tester.view.reset);
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      for (final width in kLayoutWidths) {
        for (final textScale in kLayoutTextScales) {
          final where = '${locale.languageCode} ${width}dp × $textScale';
          setLayoutScreen(tester, width);
          await pumpLayoutApp(
            tester,
            callScreen(),
            textScale: textScale,
            locale: locale,
          );
          await tester.tap(find.text('Call'));
          await tester.pumpAndSettle();
          expectCleanLayout(tester, where);
          final s = strings(tester);
          expectWholeText(tester, find.text(s.callNotAvailable), where);
          expectWholeText(tester, find.text(s.copyNumber), where);

          // The number: whole, on one line, inside the screen, and left to
          // right in an Arabic layout too. (Selectable, the Text puts its
          // paragraph under a MouseRegion.)
          final paragraph = find.descendant(
            of: find.text(_phone),
            matching: find.byType(RichText),
          );
          final number = tester.renderObject<RenderParagraph>(paragraph);
          expect(number.textDirection, TextDirection.ltr, reason: where);
          expect(number.didExceedMaxLines, isFalse, reason: where);
          final rect = tester.getRect(paragraph);
          expect(rect.left, greaterThanOrEqualTo(0), reason: where);
          expect(rect.right, lessThanOrEqualTo(width), reason: where);

          // Closed before the next size.
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });
}
