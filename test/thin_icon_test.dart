// ThinIcon draws at its own size, centered in whatever box its parent
// forces, as Material's Icon centers its glyph. The Tabler SVG fills the box
// it gets, so a tight or minimum constraint bigger than the icon used to draw
// it that big: an InputDecoration prefix icon's 48 dp slot drew a 20 dp icon
// at 48, a 40 × 40 Container without an alignment at 40.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' show SvgPicture;
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

/// Pumps [child] in a plain Material app. The SVG's picture loads after the
/// first frame, so one more frame draws it.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

/// The icon's own box: what its parent lays out.
Finder get _icon => find.byType(ThinIcon);

/// The drawn icon: the Tabler SVG.
Finder get _svg => find.byType(SvgPicture);

/// The SVG is drawn at [size], centered on the icon's box.
void _expectDrawnAt(WidgetTester tester, double size) {
  expect(tester.getSize(_svg), Size.square(size));
  expect(tester.getCenter(_svg), tester.getCenter(_icon));
}

void main() {
  group('in a box bigger than the icon', () {
    testWidgets('a tight 48 dp box draws a 20 dp icon at 20, centered', (
      tester,
    ) async {
      await _pump(
        tester,
        const Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: ThinIcon(tabler.Box.new, size: 20),
          ),
        ),
      );
      // The icon's box still fills the forced size: layout is unchanged.
      expect(tester.getSize(_icon), const Size(48, 48));
      _expectDrawnAt(tester, 20);
      // The real picture, not only its placeholder, is drawn at 20.
      final picture = find.descendant(
        of: _svg,
        matching: find.byType(FittedBox),
      );
      expect(picture, findsOneWidget);
      expect(tester.getSize(picture), const Size(20, 20));
    });

    testWidgets("an InputDecoration's min-48 prefix slot keeps the coded size", (
      tester,
    ) async {
      await _pump(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: ThinIcon(tabler.Search.new, size: 20),
            ),
          ),
        ),
      );
      expect(tester.getSize(_icon), const Size(48, 48));
      _expectDrawnAt(tester, 20);
    });

    testWidgets("an unsized prefix icon is drawn at the field's 24, not 48", (
      tester,
    ) async {
      await _pump(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: ThinIcon(tabler.Search.new),
            ),
          ),
        ),
      );
      expect(tester.getSize(_icon), const Size(48, 48));
      _expectDrawnAt(tester, 24);
    });

    testWidgets('a 40 × 40 Container without an alignment', (tester) async {
      await _pump(
        tester,
        Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const ThinIcon(tabler.Settings.new, size: 20),
          ),
        ),
      );
      expect(tester.getSize(_icon), const Size(40, 40));
      _expectDrawnAt(tester, 20);
    });

    testWidgets("a Container's padding shrinks the box, not the icon", (
      tester,
    ) async {
      await _pump(
        tester,
        Center(
          child: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(6),
            color: Colors.teal.withValues(alpha: 0.1),
            child: const ThinIcon(tabler.Settings.new, size: 18),
          ),
        ),
      );
      expect(tester.getSize(_icon), const Size(28, 28));
      _expectDrawnAt(tester, 18);
    });

    testWidgets('a forced height alone keeps the width and the drawing', (
      tester,
    ) async {
      await _pump(
        tester,
        const Center(
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [ThinIcon(tabler.Box.new, size: 18), Text('Label')],
            ),
          ),
        ),
      );
      expect(tester.getSize(_icon), const Size(18, 48));
      _expectDrawnAt(tester, 18);
    });

    testWidgets('the whole box still takes taps, as the stretched icon did', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        Center(
          child: GestureDetector(
            onTap: () => taps++,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: ThinIcon(tabler.X.new, size: 16),
            ),
          ),
        ),
      );
      final box = tester.getRect(_icon);
      // A corner, well outside the 16 dp drawing.
      await tester.tapAt(box.topLeft + const Offset(3, 3));
      expect(taps, 1);
      await tester.tapAt(box.center);
      expect(taps, 2);
    });
  });

  group('under loose constraints the size is unchanged', () {
    testWidgets('centered: its coded size', (tester) async {
      await _pump(
        tester,
        const Center(child: ThinIcon(tabler.Box.new, size: 20)),
      );
      expect(tester.getSize(_icon), const Size(20, 20));
      _expectDrawnAt(tester, 20);
    });

    testWidgets('in a Row: its coded size', (tester) async {
      await _pump(
        tester,
        const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [ThinIcon(tabler.Box.new, size: 18), Text('Label')],
          ),
        ),
      );
      expect(tester.getSize(_icon), const Size(18, 18));
      _expectDrawnAt(tester, 18);
    });

    testWidgets('unbounded: its coded size', (tester) async {
      await _pump(
        tester,
        const UnconstrainedBox(child: ThinIcon(tabler.Box.new, size: 30)),
      );
      expect(tester.getSize(_icon), const Size(30, 30));
      _expectDrawnAt(tester, 30);
    });

    testWidgets("unsized: the ambient IconTheme's size", (tester) async {
      await _pump(
        tester,
        const Center(
          child: IconTheme(
            data: IconThemeData(size: 30),
            child: ThinIcon(tabler.Box.new),
          ),
        ),
      );
      expect(tester.getSize(_icon), const Size(30, 30));
      _expectDrawnAt(tester, 30);
    });

    testWidgets('its intrinsic size is its coded size', (tester) async {
      await _pump(
        tester,
        const Center(
          child: IntrinsicWidth(
            child: IntrinsicHeight(child: ThinIcon(tabler.Box.new, size: 20)),
          ),
        ),
      );
      expect(tester.getSize(_icon), const Size(20, 20));
      final box = tester.renderObject<RenderBox>(_icon);
      expect(box.getMinIntrinsicWidth(double.infinity), 20);
      expect(box.getMaxIntrinsicWidth(double.infinity), 20);
      expect(box.getMinIntrinsicHeight(double.infinity), 20);
      expect(box.getMaxIntrinsicHeight(double.infinity), 20);
    });
  });

  testWidgets('a box smaller than the icon still shrinks it to fit', (
    tester,
  ) async {
    await _pump(
      tester,
      const Center(
        child: SizedBox(
          width: 12,
          height: 12,
          child: ThinIcon(tabler.Box.new, size: 20),
        ),
      ),
    );
    expect(tester.getSize(_icon), const Size(12, 12));
    _expectDrawnAt(tester, 12);
  });

  testWidgets('the Tabler icon gets the size and stroke warmThinIcons caches', (
    tester,
  ) async {
    await _pump(
      tester,
      const Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: ThinIcon(tabler.Box.new, size: 20, color: Colors.teal),
        ),
      ),
    );
    final icon = tester.widget<tabler.Icon>(find.byType(tabler.Box));
    expect(icon.width, 20);
    expect(icon.height, 20);
    expect(icon.strokeWidth, kIconStroke);
    // ignore: deprecated_member_use
    expect(icon.color, Colors.teal);
  });
}
