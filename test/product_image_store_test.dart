// Product photos are stored relative to the app's documents directory and
// resolved when read: iOS can move that directory (the app's container) when
// the app is updated, so an absolute path saved before then points nowhere
// after. Checks the resolver, the stored form, the one-time
// migration of absolute paths on a real Isar database (the core library
// bundled in isar_community_flutter_libs; skipped when not found), and that
// the product list's card draws the resolved file.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:micro_seller/core/constants/app_icons.dart';
import 'package:micro_seller/data/models/product.dart';
import 'package:micro_seller/data/services/isar_service.dart';
import 'package:micro_seller/data/services/product_image_store.dart';
import 'package:micro_seller/features/products/presentation/widgets/product_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/isar_core.dart';

/// The documents directory of this install, and of the one before an update.
const _docs = '/var/mobile/Containers/Data/Application/NEW-UUID/Documents';
const _oldDocs = '/var/mobile/Containers/Data/Application/OLD-UUID/Documents';

/// Where an Android install keeps its documents (unchanged by updates).
const _androidDocs = '/data/user/0/com.blackshadowsoftware.micro_seller/app_flutter';

void main() {
  tearDown(() => ProductImageStore.documentsDirectory = null);

  group('resolveProductImagePath', () {
    test('a relative path is under the documents directory', () {
      expect(
        resolveProductImagePath('product_images/a.jpg', documentsDirectory: _docs),
        '$_docs/product_images/a.jpg',
      );
      // A trailing slash on the directory makes no double slash.
      expect(
        resolveProductImagePath('product_images/a.jpg',
            documentsDirectory: '$_docs/'),
        '$_docs/product_images/a.jpg',
      );
    });

    test('an absolute path in an old container moves to the current one', () {
      expect(
        resolveProductImagePath('$_oldDocs/product_images/a.jpg',
            documentsDirectory: _docs),
        '$_docs/product_images/a.jpg',
      );
      // Android's documents directory doesn't move: the same file.
      expect(
        resolveProductImagePath('$_androidDocs/product_images/a.jpg',
            documentsDirectory: _androidDocs),
        '$_androidDocs/product_images/a.jpg',
      );
    });

    test('a path outside the photos folder is used as stored', () {
      for (final foreign in [
        '/storage/emulated/0/DCIM/Camera/IMG_0001.jpg',
        r'C:\Users\seller\Pictures\shirt.jpg',
        '/data/product_images/', // the folder, no file
      ]) {
        expect(
          resolveProductImagePath(foreign, documentsDirectory: _docs),
          foreign,
          reason: foreign,
        );
      }
    });

    test('no photo resolves to none', () {
      expect(resolveProductImagePath(null, documentsDirectory: _docs), isNull);
      expect(resolveProductImagePath('', documentsDirectory: _docs), isNull);
    });

    test('the documents directory defaults to the one the database set', () {
      // Not known yet: a relative path is no file, an absolute one as stored.
      expect(resolveProductImagePath('product_images/a.jpg'), isNull);
      expect(
        resolveProductImagePath('$_oldDocs/product_images/a.jpg'),
        '$_oldDocs/product_images/a.jpg',
      );

      ProductImageStore.documentsDirectory = _docs;
      expect(
        resolveProductImagePath('product_images/a.jpg'),
        '$_docs/product_images/a.jpg',
      );
      expect(
        resolveProductImagePath('$_oldDocs/product_images/a.jpg'),
        '$_docs/product_images/a.jpg',
      );
    });
  });

  group('storedProductImagePath', () {
    test('a photo in the photos folder is stored relative', () {
      expect(storedProductImagePath('$_docs/product_images/a.jpg'),
          'product_images/a.jpg');
      expect(storedProductImagePath('$_oldDocs/product_images/b.jpg'),
          'product_images/b.jpg');
      expect(storedProductImagePath('$_androidDocs/product_images/c.jpg'),
          'product_images/c.jpg');
      expect(storedProductImagePath(r'C:\Users\x\Documents/product_images/d.jpg'),
          'product_images/d.jpg');
    });

    test('anything else is stored as it is', () {
      for (final path in [
        '',
        'product_images/a.jpg',
        '/storage/emulated/0/DCIM/Camera/IMG_0001.jpg',
        '/data/product_images/',
      ]) {
        expect(storedProductImagePath(path), path, reason: path);
      }
    });

    test('a stored path resolves back to the file it was made from', () {
      const file = '$_docs/product_images/a.jpg';
      expect(
        resolveProductImagePath(storedProductImagePath(file),
            documentsDirectory: _docs),
        file,
      );
    });
  });

  group('ProductCard', () {
    late Directory docs;

    setUp(() {
      // This install's documents directory, with one photo in it.
      docs = Directory.systemTemp.createTempSync('micro_seller_docs');
      File('${docs.path}/product_images/a.jpg')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_png);
    });

    tearDown(() => docs.deleteSync(recursive: true));

    testWidgets('draws the photo from the current documents directory', (
      tester,
    ) async {
      ProductImageStore.documentsDirectory = docs.path;
      for (final stored in [
        'product_images/a.jpg',
        // Saved by an earlier version, in the container before an update.
        '$_oldDocs/product_images/a.jpg',
      ]) {
        imageCache.clear();
        await tester.pumpWidget(_card(stored));
        final image = tester.widget<Image>(find.byType(Image)).image;
        expect(_fileOf(image)?.path, '${docs.path}/product_images/a.jpg',
            reason: stored);
        // It loads: the card draws the photo.
        await _settleImage(tester);
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull,
            reason: stored);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a photo whose file is gone draws the placeholder', (
      tester,
    ) async {
      ProductImageStore.documentsDirectory = docs.path;
      imageCache.clear();
      await tester.pumpWidget(_card('product_images/missing.jpg'));
      await _settleImage(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(RawImage), findsNothing);
      expect(find.byType(ThinIcon), findsOneWidget);
    });

    testWidgets('a relative photo with no documents directory yet is no photo',
        (tester) async {
      await tester.pumpWidget(_card('product_images/a.jpg'));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(ThinIcon), findsOneWidget);
    });
  });

  final coreLibrary = isarCoreLibrary();
  group('migrateProductImagePathsV1',
      skip: coreLibrary == null ? 'Isar core library not found' : false, () {
    late Directory dir;
    late Isar isar;

    setUpAll(() async {
      await Isar.initializeIsarCore(libraries: {Abi.current(): coreLibrary!});
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('micro_seller_photos');
      isar = await Isar.open(kIsarSchemas,
          directory: dir.path, name: 'product_image_store_test', inspector: false);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
      await dir.delete(recursive: true);
    });

    /// Every product's stored photo path, by name.
    Future<Map<String, String>> paths() async => {
          for (final p in await isar.products.where().findAll())
            p.name: p.imagePath,
        };

    test('rewrites absolute photo paths once, and nothing else', () async {
      final edited = DateTime(2026, 10, 1, 9, 30);
      await isar.writeTxn(() => isar.products.putAll([
            Product(
              name: 'iPhone, old container',
              sellingPrice: 1,
              imagePath: '$_oldDocs/product_images/a.jpg',
              stockQty: 7,
              updatedAt: edited,
            ),
            Product(
              name: 'Android',
              sellingPrice: 1,
              imagePath: '$_androidDocs/product_images/b.jpg',
            ),
            Product(
              name: 'already relative',
              sellingPrice: 1,
              imagePath: 'product_images/c.jpg',
            ),
            Product(
              name: 'foreign',
              sellingPrice: 1,
              imagePath: '/storage/emulated/0/DCIM/d.jpg',
            ),
            Product(name: 'no photo', sellingPrice: 1),
          ]));

      await migrateProductImagePathsV1(isar);
      final migrated = await paths();
      expect(migrated, {
        'iPhone, old container': 'product_images/a.jpg',
        'Android': 'product_images/b.jpg',
        'already relative': 'product_images/c.jpg',
        'foreign': '/storage/emulated/0/DCIM/d.jpg',
        'no photo': '',
      });
      // Only the path changed: not the stock, not the edit time.
      final moved = await isar.products
          .filter()
          .nameEqualTo('iPhone, old container')
          .findFirst();
      expect(moved!.stockQty, 7);
      expect(moved.updatedAt, edited);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('productImagePathsV1Migrated'), isTrue);

      // Once per install: an absolute path that arrives later (an older
      // backup restored) is left to the resolver ...
      await isar.writeTxn(() => isar.products.put(Product(
            name: 'restored later',
            sellingPrice: 1,
            imagePath: '$_oldDocs/product_images/e.jpg',
          )));
      await migrateProductImagePathsV1(isar);
      expect((await paths())['restored later'],
          '$_oldDocs/product_images/e.jpg');

      // ... and the rewrite is idempotent: run again, the relative paths
      // stay as they are.
      await prefs.remove('productImagePathsV1Migrated');
      await migrateProductImagePathsV1(isar);
      expect(await paths(), {
        ...migrated,
        'restored later': 'product_images/e.jpg',
      });
    });
  });
}

/// A 1 × 1 PNG, the photo's content.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// The card of a product whose photo is stored as [imagePath], at a product
/// grid tile's size.
Widget _card(String imagePath) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 170,
            height: 230,
            child: ProductCard(
              product: Product(
                id: 1,
                name: 'Shirt',
                sellingPrice: 500,
                imagePath: imagePath,
              ),
            ),
          ),
        ),
      ),
    );

/// Lets the card's photo load, or fail to: the file is read and decoded on
/// the real clock, and each step is delivered on the test's fake one. Stops
/// once the photo is drawn, or the image is gone (its placeholder built).
Future<void> _settleImage(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
    final raw = find.byType(RawImage);
    if (raw.evaluate().isEmpty || tester.widget<RawImage>(raw).image != null) {
      return;
    }
  }
}

/// The file [image] reads, through the resize the card decodes at.
File? _fileOf(ImageProvider image) => switch (image) {
      ResizeImage(imageProvider: FileImage(:final file)) => file,
      FileImage(:final file) => file,
      _ => null,
    };
