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

  test(
    'fresh v4 schema includes client-account tables and ledger indexes',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, version) async {
            await createBennetDatabaseSchemaV4(db);
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
        final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name",
        );
        final indexNames = indexes.map((r) => r['name'] as String).toSet();
        expect(
          indexNames,
          containsAll(<String>{
            'idx_tx_book_occurred',
            'idx_period_openings_book_period',
            'idx_balance_sheet_book_order',
          }),
        );
      } finally {
        await db.close();
      }
    },
  );
}
