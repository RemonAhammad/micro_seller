// Finding the product a scanned code names, on a real Isar database (the
// core library bundled in isar_community_flutter_libs; skipped when not
// found). The same barcode reads differently on each phone: iOS reports a
// 12-digit UPC-A as the 13-digit EAN-13 with a leading 0, Android as the 12
// digits. Whichever phone saved the code, the other one's scan finds the
// product. Letter case and spaces around the code don't matter, a variant's
// SKU finds its product, and a product in the Recycle Bin isn't found.
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/models/variant_combination.dart';
import 'package:micro_seller/data/repositories/product_repository.dart';
import 'package:micro_seller/data/services/device_channel.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/features/scanner/presentation/scanner_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'support/fake_camera.dart';
import 'support/fake_device_channel.dart';
import 'support/isar_core.dart';
import 'support/layout_harness.dart';

void main() {
  final coreLibrary = isarCoreLibrary();
  group('findByScannedCode',
      skip: coreLibrary == null ? 'Isar core library not found' : false, () {
    late Directory dir;
    late Isar isar;
    late ProductRepository products;

    setUpAll(() async {
      await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary!});
      dir = await Directory.systemTemp.createTemp('micro_seller_barcodes');
      isar = await Isar.open(kIsarSchemas,
          directory: dir.path, name: 'barcode_lookup_test', inspector: false);
      await isar.writeTxn(() => isar.products.putAll([
            // Scanned into the QR / barcode field on an Android phone.
            Product(
              name: 'Saved on Android',
              sellingPrice: 1,
              qrCode: '036000291452',
            ),
            // The same kind of code, scanned on an iPhone.
            Product(
              name: 'Saved on iPhone',
              sellingPrice: 1,
              qrCode: '0012345678905',
            ),
            // A UPC-A typed as the SKU.
            Product(name: 'UPC as SKU', sellingPrice: 1, sku: '725272730706'),
            // An EAN-13 that isn't a UPC-A: found only as it is.
            Product(name: 'EAN-13', sellingPrice: 1, qrCode: '5901234123457'),
            Product(name: 'Rice', sellingPrice: 1, sku: 'ABC-1'),
            Product(
              name: 'T-Shirt',
              sellingPrice: 1,
              sku: 'TS',
              variantCombinations: [
                VariantCombination(
                  combinationKey: 'Color:Red/Size:L',
                  displayLabel: 'Color: Red / Size: L',
                  sku: 'TS-RED-L',
                ),
                VariantCombination(
                  combinationKey: 'Color:Blue/Size:L',
                  displayLabel: 'Color: Blue / Size: L',
                  sku: '0725272730713',
                ),
              ],
            ),
            // In the Recycle Bin: a product an order still refers to is
            // deleted by turning it inactive.
            Product(
              name: 'Deleted',
              sellingPrice: 1,
              qrCode: 'TRASHED-1',
              sku: 'GONE',
              isActive: false,
            ),
            Product(
              name: 'Deleted twin',
              sellingPrice: 1,
              qrCode: 'SHARED-1',
              isActive: false,
            ),
            Product(name: 'Live twin', sellingPrice: 1, qrCode: 'SHARED-1'),
          ]));
      products = ProductRepository(isar);
    });

    tearDownAll(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    Future<String?> found(String code) async =>
        (await products.findByScannedCode(code))?.name;

    test('a UPC-A saved from either phone is found by the other\'s scan',
        () async {
      // Saved on Android (12 digits): an iPhone scan, and Android's own.
      expect(await found('0036000291452'), 'Saved on Android');
      expect(await found('036000291452'), 'Saved on Android');
      // Saved on an iPhone (13 digits): an Android scan, and the iPhone's.
      expect(await found('012345678905'), 'Saved on iPhone');
      expect(await found('0012345678905'), 'Saved on iPhone');
      // In the SKU field too.
      expect(await found('0725272730706'), 'UPC as SKU');
      expect(await found('725272730706'), 'UPC as SKU');
    });

    test('other codes are found only as they are', () async {
      expect(await found('5901234123457'), 'EAN-13');
      // Its last 12 digits are another code, not a spelling of this one.
      expect(await found('901234123457'), isNull);
      expect(await found('NO-SUCH-CODE'), isNull);
    });

    test('letter case and spaces around the code don\'t matter', () async {
      expect(await found(' abc-1\n'), 'Rice');
      expect(await found('abc-1'), 'Rice');
      expect(await found('\t0036000291452 '), 'Saved on Android');
    });

    test('a variant\'s SKU finds its product', () async {
      expect(await found('ts-red-l'), 'T-Shirt');
      // A variant's UPC-A, in the other phone's spelling.
      expect(await found('725272730713'), 'T-Shirt');
    });

    test('a product in the Recycle Bin isn\'t found', () async {
      expect(await found('TRASHED-1'), isNull);
      expect(await found('gone'), isNull);
      // An active product with the same code is.
      expect(await found('shared-1'), 'Live twin');
    });

    test('a blank code finds nothing', () async {
      expect(await found(''), isNull);
      expect(await found('  \n'), isNull);
    });

    testWidgets('the scanner matches an iPhone scan of an Android code',
        (tester) async {
      final camera = FakeCamera();
      MobileScannerPlatform.instance = camera;
      addTearDown(MobileScannerController.resetPlatformSessionOwner);
      await pumpLayoutApp(
        tester,
        const ScannerScreen(),
        rail: false,
        overrides: [
          isarProvider.overrideWith((ref) async => isar),
          deviceChannelProvider.overrideWithValue(FakeDeviceChannel()),
        ],
      );
      await tester.pump();
      expect(camera.starts, 1);

      camera.scan('0036000291452');
      // The lookup runs on Isar's thread.
      for (var i = 0;
          i < 200 && find.text('Product matched').evaluate().isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect(find.text('Product matched'), findsOneWidget);
      expect(find.text('Saved on Android'), findsOneWidget);
      expect(find.text('View product'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the scanner offers a new product with the code trimmed',
        (tester) async {
      final camera = FakeCamera();
      MobileScannerPlatform.instance = camera;
      addTearDown(MobileScannerController.resetPlatformSessionOwner);
      await pumpLayoutApp(
        tester,
        const ScannerScreen(),
        rail: false,
        overrides: [
          isarProvider.overrideWith((ref) async => isar),
          deviceChannelProvider.overrideWithValue(FakeDeviceChannel()),
        ],
      );
      await tester.pump();

      camera.scan(' NEW-CODE-7 \n');
      for (var i = 0;
          i < 200 && find.text('Add as new product').evaluate().isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect(find.text('No product matched this code'), findsOneWidget);
      expect(find.text('Scanned code: NEW-CODE-7'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
