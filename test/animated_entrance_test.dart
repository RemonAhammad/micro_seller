import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/shared/widgets/animated_entrance.dart';

/// 200 rows of 50 px in the 800×600 test surface: rows 0–16 are built at
/// offset 0 (viewport + cache extent), so row 25 only mounts after scrolling.
Widget _list({ScrollController? controller}) => Directionality(
      textDirection: TextDirection.ltr,
      child: ListView.builder(
        controller: controller,
        itemExtent: 50,
        itemCount: 200,
        itemBuilder: (_, i) =>
            AnimatedEntrance(index: i, child: Text('Item $i')),
      ),
    );

/// The FadeTransition an AnimatedEntrance puts around the row showing [text].
/// Not skipping offstage: rows in the cache extent count as offstage.
Finder _entranceFade(String text) => find.descendant(
      of: find.ancestor(
        of: find.text(text, skipOffstage: false),
        matching: find.byType(AnimatedEntrance, skipOffstage: false),
      ),
      matching: find.byType(FadeTransition, skipOffstage: false),
      skipOffstage: false,
    );

double _opacity(WidgetTester tester, String text) =>
    tester.widget<FadeTransition>(_entranceFade(text)).opacity.value;

void main() {
  testWidgets('the first screenful animates in at scroll offset 0',
      (tester) async {
    await tester.pumpWidget(_list());
    // Fires item 0's zero-length stagger; the animation's first frame.
    await tester.pump(Duration.zero);
    expect(_opacity(tester, 'Item 0'), lessThan(1));

    await tester.pump(const Duration(milliseconds: 100));
    expect(_opacity(tester, 'Item 0'), greaterThan(0));
    expect(_opacity(tester, 'Item 0'), lessThan(1));
    // Past maxStaggerIndex but on the first screen: still animates.
    expect(_entranceFade('Item 15'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(_opacity(tester, 'Item 0'), 1);
    expect(_opacity(tester, 'Item 15'), 1);
  });

  testWidgets('items built after scrolling appear immediately',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_list(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Item 25'), findsNothing);

    controller.jumpTo(1000);
    await tester.pump();

    // Index 25 is within 3 * maxStaggerIndex, so the scroll offset alone
    // decides that it skips the entrance.
    expect(find.text('Item 25'), findsOneWidget);
    expect(_entranceFade('Item 25'), findsNothing);
  });

  testWidgets('an index past 3 * maxStaggerIndex shows immediately',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedEntrance(index: 37, child: Text('Late')),
    ));
    expect(_entranceFade('Late'), findsNothing);
  });

  testWidgets('disposing mid-stagger leaves no pending timer', (tester) async {
    await tester.pumpWidget(_list());
    // Item 12's 480 ms stagger timer is still pending.
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    // The test framework fails the test if a timer outlives the tree.
  });
}
