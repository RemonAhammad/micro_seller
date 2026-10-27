// The catalog's share sheet points at the button that was tapped. On an
// iPad the share sheet is a popover anchored to a rect; without one it opens
// from the middle of the screen, pointing at nothing. The rect is read when
// the catalog is ready to share, so it is where the button is drawn then.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/features/products/presentation/catalog_share_screen.dart';
import 'package:micro_seller/features/products/providers/product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/layout_harness.dart';

/// share_plus's channel to the share sheet.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// path_provider's channel, for the temporary folder the catalog is saved to.
const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  late Directory temp;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    temp = Directory.systemTemp.createTempSync('catalog_share_origin_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      _pathChannel,
      (call) async => call.method == 'getTemporaryDirectory' ? temp.path : null,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(_pathChannel, null);
    temp.deleteSync(recursive: true);
  });

  // One test for both buttons: the PDF watermark's icon is decoded once per
  // run, and a second test couldn't await what the first one's fake clock
  // started.
  testWidgets('each share button points the share sheet at itself',
      (tester) async {
    // An iPad Air in portrait, beside the sidebar with labels.
    tester.view.physicalSize = const Size(820 * 2, 1180 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // What the share sheet was given, and where each button was then.
    final shared = <Map<Object?, Object?>>[];
    final drawnAt = <Rect>[];
    late Finder button;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, (call) async {
      shared.add(call.arguments as Map<Object?, Object?>);
      drawnAt.add(tester.getRect(button));
      return 'com.apple.UIKit.activity.AirDrop';
    });

    await pumpLayoutApp(
      tester,
      const CatalogShareScreen(),
      overrides: [
        productsProvider.overrideWithValue(AsyncValue.data([
          Product(id: 1, name: 'Tea', sku: 'T-1', sellingPrice: 50),
          Product(id: 2, name: 'Rice', sku: 'R-1', sellingPrice: 80),
        ])),
      ],
    );
    await tester.tap(find.text('Select All'));
    await tester.pump();

    for (final (label, file) in [
      ('Share as Image', 'catalog.png'),
      ('Share as PDF', 'catalog.pdf'),
    ]) {
      button = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      final shares = shared.length;
      await tester.tap(find.text(label));
      // The catalog is drawn and encoded for real, on the engine and (the
      // PDF) an isolate.
      for (var i = 0; i < 600 && shared.length == shares; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
          find.text('Could not create the catalog. Try fewer products.'),
          findsNothing,
          reason: label);
      expect(shared, hasLength(shares + 1),
          reason: '$label: the catalog was never shared');
      final arguments = shared.last;
      expect(arguments['subject'], file, reason: label);
      final origin = drawnAt.last;
      expect(arguments['originX'], origin.left, reason: label);
      expect(arguments['originY'], origin.top, reason: label);
      expect(arguments['originWidth'], origin.width, reason: label);
      expect(arguments['originHeight'], origin.height, reason: label);

      // Done: the progress bar goes.
      for (var i = 0;
          i < 40 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(LinearProgressIndicator), findsNothing,
          reason: label);
    }
    // Each pointed at its own button.
    expect(drawnAt.first, isNot(drawnAt.last));
  });
}
