// Dev-only: writes a large, internally consistent Micro Seller backup for
// performance testing. Most slowdowns grow with data (orders, payments,
// movements), so measure on a dataset like this, not an empty install.
//
//   dart run tool/gen_perf_backup.dart
//     [--orders 10000] [--products 1000] [--customers 2000]
//     [--seed 42] [--out build/perf_backup.json]
//
// Import the file on a TEST phone only: Settings → Local Backup → Import
// replaces all data. Restore recalculates outstanding balances from orders.
//
// Not bundled with the app (tool/ is outside lib/). Builds the JSON through
// `buildBackupMap`, the same function `LocalBackupService.encodeAll` uses.
import 'dart:convert';
import 'dart:io';

import 'perf_dataset.dart';

void main(List<String> args) {
  final opts = _parseArgs(args);
  final gen = PerfDataset(
    orderCount: opts.intOf('orders', 10000),
    productCount: opts.intOf('products', 1000),
    customerCount: opts.intOf('customers', 2000),
    seed: opts.intOf('seed', 42),
  );
  final out = File(opts['out'] ?? 'build/perf_backup.json');

  final map = gen.build();
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(jsonEncode(map));

  final mb = (out.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
  stdout.writeln('Wrote ${out.path} ($mb MB)');
  for (final key in const [
    'products', 'customers', 'orders', 'payments', 'stockMovements',
    'purchases', 'expenses', 'cashRegisters', 'suppliers', 'categories',
  ]) {
    stdout.writeln('  ${key.padRight(15)} ${(map[key] as List).length}');
  }
}

class _Args {
  _Args(this._values);
  final Map<String, String> _values;
  String? operator [](String key) => _values[key];
  int intOf(String key, int fallback) => int.tryParse(_values[key] ?? '') ?? fallback;
}

_Args _parseArgs(List<String> args) {
  final values = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final eq = a.indexOf('=');
    if (eq > 0) {
      values[a.substring(2, eq)] = a.substring(eq + 1);
    } else if (i + 1 < args.length) {
      values[a.substring(2)] = args[++i];
    }
  }
  return _Args(values);
}
