import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:micro_seller/data/services/tutorial_service.dart';
import 'package:micro_seller/shared/widgets/screen_guide.dart';

void main() {
  group('TutorialService — per-screen flags', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isScreenGuideShown returns false before set', () async {
      expect(await TutorialService.isScreenGuideShown('products'), isFalse);
    });

    test('isScreenGuideShown returns true after setScreenGuideShown', () async {
      await TutorialService.setScreenGuideShown('products');
      expect(await TutorialService.isScreenGuideShown('products'), isTrue);
    });

    test('different screen IDs are tracked independently', () async {
      await TutorialService.setScreenGuideShown('orders');
      expect(await TutorialService.isScreenGuideShown('orders'), isTrue);
      expect(await TutorialService.isScreenGuideShown('customers'), isFalse);
    });

    test('resetAll clears screen_guide_* keys', () async {
      await TutorialService.setScreenGuideShown('products');
      await TutorialService.setScreenGuideShown('orders');
      await TutorialService.setScreenGuideShown('customers');

      await TutorialService.resetAll();

      expect(await TutorialService.isScreenGuideShown('products'), isFalse);
      expect(await TutorialService.isScreenGuideShown('orders'), isFalse);
      expect(await TutorialService.isScreenGuideShown('customers'), isFalse);
    });

    test('resetAll does not affect unrelated prefs', () async {
      SharedPreferences.setMockInitialValues({'some_other_key': true});
      await TutorialService.setScreenGuideShown('products');

      await TutorialService.resetAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('some_other_key'), isTrue);
    });
  });

  group('ScreenGuide widget', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'screen_guide_test_id': true});
    });

    testWidgets('renders builder child', (tester) async {
      await tester.pumpWidget(
        ShowCaseWidget(
          builder: (context) => MaterialApp(
            home: ScreenGuide(
              id: 'test_id',
              steps: const [
                GuideStep(title: 'Step 1', description: 'Desc 1'),
              ],
              builder: (context, guide) => Scaffold(
                body: const Text('Screen Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Screen Content'), findsOneWidget);
    });

    testWidgets('guide.wrap returns a widget containing the child', (tester) async {
      late GuideHandle capturedGuide;

      await tester.pumpWidget(
        ShowCaseWidget(
          builder: (context) => MaterialApp(
            home: ScreenGuide(
              id: 'test_id',
              steps: const [
                GuideStep(title: 'Step 1', description: 'Desc 1'),
              ],
              builder: (context, guide) {
                capturedGuide = guide;
                return Scaffold(
                  body: guide.wrap(0, const Text('Target Widget')),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Target Widget'), findsOneWidget);
    });

    testWidgets('does not crash on mount and unmount', (tester) async {
      await tester.pumpWidget(
        ShowCaseWidget(
          builder: (context) => MaterialApp(
            home: ScreenGuide(
              id: 'test_id',
              steps: const [
                GuideStep(title: 'Step 1', description: 'Desc 1'),
              ],
              builder: (context, guide) => const Scaffold(
                body: Text('Hello'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));

      // Unmount cleanly
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      // Should not throw
    });
  });
}
