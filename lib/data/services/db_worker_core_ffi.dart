import 'dart:ffi';

import 'package:isar_community/isar.dart';

Future<void> initIsarCoreLibrary(String path) =>
    Isar.initializeIsarCore(libraries: {Abi.current(): path});
