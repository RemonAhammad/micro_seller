import 'dart:ffi';

import 'package:isar_community/isar.dart';

/// Loads the Isar core library from [path] in the current isolate (tests).
Future<void> initIsarCoreLibrary(String path) =>
    Isar.initializeIsarCore(libraries: {Abi.current(): path});
