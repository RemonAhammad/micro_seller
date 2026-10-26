import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

/// The folder, under the app's documents directory, that holds product
/// photos. A stored photo path starts with it.
const kProductImagesFolder = 'product_images';

/// Where product photos are, and how `Product.imagePath` names them.
///
/// A photo is saved in [kProductImagesFolder] under the app's documents
/// directory, and `imagePath` stores its path *relative* to that directory
/// (`product_images/<uuid>.jpg`), resolved when it is read
/// ([resolveProductImagePath]). iOS can move the app's data container, and
/// with it the documents directory's absolute path, when the app is updated
/// (a sideloaded build is reinstalled at every 7-day refresh). An absolute
/// path stored before then points nowhere after, although the photo moved
/// along. Android's documents directory doesn't move.
///
/// Earlier versions stored absolute paths. Reading maps one inside a
/// `product_images` folder into the current documents directory, and
/// [migrateProductImagePathsV1] rewrites them as relative paths once.
abstract final class ProductImageStore {
  /// The app's documents directory (absolute), which relative photo paths
  /// resolve against. The database provider sets it when it opens the
  /// database; every product comes from there, so it is known before any
  /// photo is shown. Null until then: a relative path resolves to no file.
  static String? documentsDirectory;
}

/// Where the photo [stored] in `Product.imagePath` is now, or null when there
/// is none to show:
///
/// - empty (or null): no photo, null.
/// - relative (`product_images/<file>`, as photos are saved now): under the
///   documents directory; null while that isn't known.
/// - absolute, inside a `product_images` folder (saved by an earlier version,
///   possibly in an old iOS container): the same file in the current
///   documents directory.
/// - any other absolute path: as stored.
///
/// [documentsDirectory] defaults to [ProductImageStore.documentsDirectory].
/// The file may be missing (a backup restored on another phone carries no
/// photos): every caller draws a placeholder then.
String? resolveProductImagePath(String? stored, {String? documentsDirectory}) {
  if (stored == null || stored.isEmpty) return null;
  final base = _withoutTrailingSlash(
    documentsDirectory ?? ProductImageStore.documentsDirectory,
  );
  if (!_isAbsolute(stored)) return base == null ? null : '$base/$stored';
  final relative = _inImagesFolder(stored);
  if (relative != null && base != null) return '$base/$relative';
  return stored;
}

/// What `Product.imagePath` stores for the photo at [path]: its path relative
/// to the documents directory (`product_images/<file>`) when it is inside a
/// `product_images` folder, whichever container that folder was in. Any other
/// path, and one already relative, is returned unchanged.
String storedProductImagePath(String path) {
  if (!_isAbsolute(path)) return path;
  return _inImagesFolder(path) ?? path;
}

/// [path] from its last `/product_images/` on (`product_images/<file>`), or
/// null when it has none, or nothing after it.
String? _inImagesFolder(String path) {
  const marker = '/$kProductImagesFolder/';
  final i = path.lastIndexOf(marker);
  if (i < 0 || i + marker.length == path.length) return null;
  return path.substring(i + 1);
}

/// A POSIX path (`/…`), a Windows drive path (`C:\…`, `C:/…`) or a UNC path
/// (`\\server\…`).
bool _isAbsolute(String path) =>
    path.startsWith('/') ||
    path.startsWith(r'\\') ||
    RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

String? _withoutTrailingSlash(String? dir) {
  if (dir == null || dir.isEmpty) return null;
  return dir.length > 1 && dir.endsWith('/')
      ? dir.substring(0, dir.length - 1)
      : dir;
}

const _imagePathsMigrationKey = 'productImagePathsV1Migrated';

/// One-time rewrite of the absolute photo paths saved before photos were
/// stored relative: `<old documents>/product_images/<file>` becomes
/// `product_images/<file>`, whichever container the old path named. A path
/// outside a `product_images` folder is left alone, and so is everything else
/// about the product (`updatedAt` included).
///
/// Idempotent, and guarded by a SharedPreferences flag like the other
/// migrations, so it runs once per install while the database opens. Paths
/// that arrive later (an older backup restored, a product restored from the
/// recycle bin) are resolved when read instead.
Future<void> migrateProductImagePathsV1(Isar isar) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_imagePathsMigrationKey) == true) return;
  final changed = await isar.writeTxn(() async {
    final products = await isar.products
        .filter()
        .imagePathContains('/$kProductImagesFolder/')
        .findAll();
    final updated = <Product>[];
    for (final product in products) {
      final stored = storedProductImagePath(product.imagePath);
      if (stored == product.imagePath) continue;
      updated.add(product..imagePath = stored);
    }
    if (updated.isNotEmpty) await isar.products.putAll(updated);
    return updated.length;
  });
  debugPrint('[Migration] Product photo paths made relative ($changed changed)');
  await prefs.setBool(_imagePathsMigrationKey, true);
}
