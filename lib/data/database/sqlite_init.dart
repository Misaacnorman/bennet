import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Windows/Linux desktop need FFI factory before opening SQLite.
void ensureSqlitePlatformInitialized() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
