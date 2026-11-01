import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import 'db_worker_core_stub.dart'
    if (dart.library.ffi) 'db_worker_core_ffi.dart';
import 'isar_service.dart';

@visibleForTesting
String? dbWorkerCoreLibrary;

Future<R> runDbJob<R>(Isar isar, R Function(Isar db) job) {
  if (kIsWeb) return Future.sync(() => job(isar));
  return compute(
    _runJob<R>,
    (
      directory: isar.directory!,
      name: isar.name,
      coreLibrary: dbWorkerCoreLibrary,
      job: job,
    ),
    debugLabel: 'db-job',
  );
}

Future<R> _runJob<R>(
    ({
      String directory,
      String name,
      String? coreLibrary,
      R Function(Isar db) job,
    }) a) async {
  if (a.coreLibrary != null) await initIsarCoreLibrary(a.coreLibrary!);
  final db = Isar.getInstance(a.name) ??
      Isar.openSync(kIsarSchemas,
          directory: a.directory, name: a.name, inspector: false);
  try {
    return a.job(db);
  } finally {
    await db.close();
  }
}
