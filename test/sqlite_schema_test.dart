import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:bennet/data/database/sqlite_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  test('fresh v3 schema includes client-account tables', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await createBennetDatabaseSchemaV3(db);
        },
      ),
    );
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(
        names,
        containsAll(<String>{
          'clients',
          'client_charges',
          'client_payments',
          'payment_allocations',
          'client_adjustments',
          'client_statements',
          'client_receipts',
        }),
      );
      await db.rawQuery('SELECT COUNT(*) FROM clients');
    } finally {
      await db.close();
    }
  });
}
