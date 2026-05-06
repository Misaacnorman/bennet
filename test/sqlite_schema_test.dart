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
    'fresh v5 schema includes client-account tables and performance indexes',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            await createBennetDatabaseSchemaV5(db);
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
            'idx_clients_book_status_name',
            'idx_charges_client_status_due',
            'idx_payments_client_status_received',
            'idx_alloc_client_charge',
            'idx_statement_lines_account_match',
          }),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'fresh v6 schema includes statement snapshots and ledger trace columns',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (db, version) async {
            await createBennetDatabaseSchemaV6(db);
          },
        ),
      );
      try {
        final txCols = await db.rawQuery('PRAGMA table_info(transactions)');
        final txnNames =
            txCols.map((r) => r['name'] as String).toSet();
        expect(
          txnNames,
          containsAll(<String>[
            'client_id',
            'source_type',
            'source_id',
            'source_number',
          ]),
        );

        final stCols =
            await db.rawQuery('PRAGMA table_info(client_statements)');
        final stmtNames =
            stCols.map((r) => r['name'] as String).toSet();
        expect(
          stmtNames,
          containsAll(<String>[
            'business_name_snap',
            'client_display_name_snap',
            'client_code_snap',
            'lines_json',
          ]),
        );
      } finally {
        await db.close();
      }
    },
  );
}
