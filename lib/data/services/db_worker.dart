import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import 'db_worker_core_stub.dart'
    if (dart.library.ffi) 'db_worker_core_ffi.dart';
import 'isar_service.dart';

/// Isar core library for worker isolates in tests (the app loads the bundled
/// one automatically). Set once by tests that run [runDbJob].
@visibleForTesting
String? dbWorkerCoreLibrary;

/// Runs [job] on a background isolate against the same database as [isar],
/// and returns its result to the calling isolate without copying it.
///
/// Isar deserializes query results on the isolate that runs the query, so a
/// load of thousands of orders — and the Dart work done on them — freezes
/// whichever isolate does it. Here that is a worker, not the UI isolate.
///
/// The worker opens the database with the shared [kIsarSchemas]; Isar shares
/// the native instance between isolates, and `close()` only releases the
/// worker's reference, never the app's. [job] must use the synchronous APIs
/// (`findAllSync`, `txnSync`, …) and be built by a top-level function from
/// plain values — never a `Ref`, a `BuildContext` or the caller's `Isar` —
/// because a closure carries its whole context across isolates.
///
/// `compute` is `Isolate.run` on native platforms (the result comes back via
/// `Isolate.exit`, uncopied); on web, where Isar has no worker support, the
/// job runs inline.
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
