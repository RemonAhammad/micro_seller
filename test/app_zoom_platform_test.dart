// AppZoom and iOS's system edit menu (Cut / Copy / Paste). iOS keeps the
// system menu at every Display size, and when zoomed Flutter points it beside
// the selection: see app_zoom.dart's library comment. A Flutter upgrade that
// fixes the menu's target fails the offset check below; update that comment
// then.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/shared/widgets/app_zoom.dart';

void main() {
  for (final percent in [80, 100, 125]) {
    testWidgets(
      '$percent%: an editable field keeps the system edit menu',
      (tester) async {
        // An iPhone on iOS 16+, about 411 × 914 dp. The flag is read when
        // the window's MediaQuery is built, so it is set first.
        tester.platformDispatcher.supportsShowingSystemContextMenu = true;
        addTearDown(
          tester.platformDispatcher.resetSupportsShowingSystemContextMenu,
        );
        tester.view.physicalSize = const Size(1440, 3200);
        tester.view.devicePixelRatio = 3.5;
        addTearDown(tester.view.reset);

        final targets = <Rect>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'ContextMenu.showSystemContextMenu') {
            final rect = (call.arguments as Map)['targetRect'] as Map;
            targets.add(
              Rect.fromLTWH(
                rect['x'] as double,
                rect['y'] as double,
                rect['width'] as double,
                rect['height'] as double,
              ),
            );
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final controller = TextEditingController(text: 'one two three four');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            // As the app frame (app_frame.dart) wires it.
            builder: (context, child) =>
                AppZoom(displayPercent: percent, child: child!),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(left: 72, top: 120),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 240,
                    child: TextField(
                      controller: controller,
                      // The test font's glyphs are as wide as the font size:
                      // 'three' is 80–130 dp into the field.
                      style: const TextStyle(fontSize: 10, letterSpacing: 0),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();
        controller.selection = const TextSelection(
          baseOffset: 8,
          extentOffset: 13,
        );
        await tester.pump();
        final state = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(state.showToolbar(), isTrue);
        await tester.pump();

        expect(find.byType(SystemContextMenu), findsOneWidget);
        expect(targets, isNotEmpty);
        final target = targets.last;

        // The selection as drawn, in window dp.
        final editable = state.renderEditable;
        final ends = editable.getEndpointsForSelection(controller.selection);
        final left = editable.localToGlobal(ends.first.point).dx;
        final right = editable.localToGlobal(ends.last.point).dx;
        final centre = (left + right) / 2;
        final d = centre - editable.localToGlobal(Offset.zero).dx;
        final s = percent / 100;
        expect(d, moreOrLessEquals(105 * s, epsilon: 1e-6));

        // Exact at 100%. Zoomed, (1/s - 1) × d beside the selection, at its
        // unscaled width.
        expect(
          target.center.dx - centre,
          moreOrLessEquals((1 / s - 1) * d, epsilon: 1e-6),
        );
        expect(
          target.width,
          moreOrLessEquals((right - left) / s, epsilon: 1e-6),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
