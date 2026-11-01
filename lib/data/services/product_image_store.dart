import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

const kProductImagesFolder = 'product_images';

abstract final class ProductImageStore {

  static String? documentsDirectory;
}

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

String storedProductImagePath(String path) {
  if (!_isAbsolute(path)) return path;
  return _inImagesFolder(path) ?? path;
}

String? _inImagesFolder(String path) {
  const marker = '/$kProductImagesFolder/';
  final i = path.lastIndexOf(marker);
  if (i < 0 || i + marker.length == path.length) return null;
  return path.substring(i + 1);
}

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
