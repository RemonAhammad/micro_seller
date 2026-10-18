import 'dart:convert';
import 'dart:io';

/// Path of the Isar core library bundled with isar_community_flutter_libs for
/// this desktop OS, or null when it isn't available (tests then skip).
String? isarCoreLibrary() {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final packages = (jsonDecode(config.readAsStringSync())['packages'] as List)
      .cast<Map<String, dynamic>>();
  final pkg = packages
      .where((p) => p['name'] == 'isar_community_flutter_libs')
      .firstOrNull;
  if (pkg == null) return null;
  final root =
      Directory.fromUri(config.absolute.uri.resolve('${pkg['rootUri']}/'));
  final file = switch (Platform.operatingSystem) {
    'macos' => 'macos/libisar.dylib',
    'linux' => 'linux/libisar.so',
    'windows' => 'windows/libisar.dll',
    _ => null,
  };
  if (file == null) return null;
  final path = '${root.path}$file';
  return File(path).existsSync() ? path : null;
}
