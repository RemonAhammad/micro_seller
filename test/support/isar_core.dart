import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:isar_community/isar.dart';

import 'package:micro_seller/data/services/isar_service.dart';

/// The Isar core library bundled in `isar_community_flutter_libs` for this
/// desktop host, so database tests run offline. Null when it isn't found;
/// tests then skip themselves (see [isarSkipReason]).
String? isarCoreLibrary() {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '';
  final pubCache = Platform.environment['PUB_CACHE'] ?? '$home/.pub-cache';
  final file = Platform.isMacOS
      ? 'macos/libisar.dylib'
      : Platform.isLinux
          ? 'linux/libisar.so'
          : Platform.isWindows
              ? 'windows/libisar.dll'
              : null;
  if (file == null) return null;
  final dir = Directory('$pubCache/hosted/pub.dev');
  if (!dir.existsSync()) return null;
  // The version the lockfile pins: Isar's generated schemas assert it.
  final path = '${dir.path}/isar_community_flutter_libs-${Isar.version}/$file';
  return File(path).existsSync() ? path : null;
}

String? get isarSkipReason =>
    isarCoreLibrary() == null ? 'Isar core library not found for this host' : null;

var _initialized = false;

/// A fresh, empty database with the app's schemas in a temp directory.
Future<Isar> openTestIsar(String name) async {
  if (!_initialized) {
    await Isar.initializeIsarCore(libraries: {Abi.current(): isarCoreLibrary()!});
    _initialized = true;
  }
  final dir = await Directory.systemTemp.createTemp('isar_test_');
  final isar = await Isar.open(kIsarSchemas, directory: dir.path, name: name);
  addTearDownClose(isar, dir);
  return isar;
}

final _open = <(Isar, Directory)>[];

void addTearDownClose(Isar isar, Directory dir) => _open.add((isar, dir));

/// Closes and deletes every database [openTestIsar] opened.
Future<void> closeTestIsars() async {
  for (final (isar, dir) in _open) {
    if (isar.isOpen) await isar.close(deleteFromDisk: true);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
  _open.clear();
}
