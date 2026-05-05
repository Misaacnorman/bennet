import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

const _dbName = 'bennet.db';
const dbVersion = 4;

Future<String> bennetDatabasePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, _dbName);
}

/// Ledger/core tables plus default rows — same as a fresh v3 [onCreate] before client module.
Future<void> _createLedgerTablesAndSeed(Database db) async {
  await db.execute('''
CREATE TABLE books (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
)''');
  await db.execute('''
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
)''');
  await db.execute('''
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  kind TEXT NOT NULL
)''');
  await db.execute('''
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  category_id INTEGER NOT NULL REFERENCES categories(id),
  type TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  occurred_at INTEGER NOT NULL,
  notes TEXT,
  payment_method TEXT,
  counterparty TEXT,
  cleared_at INTEGER
)''');
  await db.execute('''
CREATE TABLE period_openings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  month INTEGER NOT NULL,
  opening_balance_minor INTEGER NOT NULL,
  UNIQUE(book_id, year, month)
)''');
  await db.execute('''
CREATE TABLE bank_statement_lines (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  posted_at INTEGER NOT NULL,
  amount_minor INTEGER NOT NULL,
  description TEXT NOT NULL,
  matched_transaction_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL
)''');
  await db.execute('''
CREATE TABLE balance_sheet_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  section TEXT NOT NULL,
  label TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0
)''');
  await db.execute('''
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''');

  final bookId = await db.insert('books', {'name': 'Main'});
  await db.insert('categories', {'name': 'General income'});
  await db.insert('categories', {'name': 'General expense'});
  await db.insert('accounts', {
    'book_id': bookId,
    'name': 'Cash',
    'kind': 'cash',
  });
}

/// Client-account tables + indexes (migration v2). Requires ledger tables + seed.
Future<void> installClientAccountsSchemaV2(Database db) async {
  await db.execute('''
CREATE TABLE clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  client_code TEXT NOT NULL,
  display_name TEXT NOT NULL,
  legal_name TEXT,
  status TEXT NOT NULL,
  primary_email TEXT,
  primary_phone TEXT,
  notes TEXT,
  opening_balance_minor INTEGER NOT NULL DEFAULT 0,
  opening_balance_at INTEGER,
  default_category_id INTEGER REFERENCES categories(id),
  default_account_id INTEGER REFERENCES accounts(id),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  archived_at INTEGER,
  UNIQUE(book_id, client_code)
)''');
  await db.execute('''
CREATE TABLE client_charges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  amount_minor INTEGER NOT NULL,
  status TEXT NOT NULL,
  issued_at INTEGER NOT NULL,
  due_date INTEGER,
  description TEXT,
  void_reason TEXT
)''');
  await db.execute('''
CREATE TABLE client_payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  amount_minor INTEGER NOT NULL,
  unallocated_minor INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  method TEXT NOT NULL,
  received_at INTEGER NOT NULL,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  category_id INTEGER NOT NULL REFERENCES categories(id),
  reference TEXT,
  notes TEXT,
  receipt_number INTEGER,
  ledger_transaction_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
  reversal_reason TEXT,
  created_at INTEGER
)''');
  await db.execute('''
CREATE TABLE payment_allocations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_id INTEGER NOT NULL REFERENCES client_payments(id) ON DELETE CASCADE,
  charge_id INTEGER NOT NULL REFERENCES client_charges(id),
  amount_minor INTEGER NOT NULL,
  client_id INTEGER NOT NULL REFERENCES clients(id)
)''');
  await db.execute('''
CREATE TABLE client_adjustments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  effective_at INTEGER NOT NULL,
  reason TEXT
)''');
  await db.execute('''
CREATE TABLE client_statements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  from_date INTEGER NOT NULL,
  to_date INTEGER NOT NULL,
  opening_balance_minor INTEGER NOT NULL,
  closing_balance_minor INTEGER NOT NULL,
  issued_at INTEGER NOT NULL,
  statement_number INTEGER NOT NULL
)''');
  await db.execute(
    'CREATE INDEX idx_clients_book_status ON clients(book_id, status)',
  );
  await db.execute(
    'CREATE INDEX idx_charges_client ON client_charges(client_id)',
  );
  await db.execute(
    'CREATE INDEX idx_payments_client ON client_payments(client_id)',
  );
  await db.execute(
    'CREATE INDEX idx_alloc_client ON payment_allocations(client_id)',
  );
  await db.execute(
    'CREATE INDEX idx_stmt_client ON client_statements(client_id)',
  );
}

/// Receipt snapshots (migration v3). Requires [client_payments].
Future<void> installClientReceiptsSchemaV3(Database db) async {
  await db.execute('''
CREATE TABLE client_receipts (
  payment_id INTEGER PRIMARY KEY REFERENCES client_payments(id) ON DELETE CASCADE,
  receipt_number INTEGER NOT NULL,
  issued_at INTEGER NOT NULL,
  client_id INTEGER NOT NULL,
  client_display_name TEXT NOT NULL,
  client_code TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  method TEXT NOT NULL,
  business_name TEXT,
  reference TEXT,
  notes TEXT,
  allocations_json TEXT NOT NULL,
  payment_reversed INTEGER NOT NULL DEFAULT 0
)''');
}

/// Performance indexes for ledger summary and cash-book queries (migration v4).
Future<void> installLedgerPerformanceIndexesV4(Database db) async {
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_tx_book_occurred ON transactions(book_id, occurred_at)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_tx_account_occurred ON transactions(account_id, occurred_at)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_period_openings_book_period ON period_openings(book_id, year DESC, month DESC)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_balance_sheet_book_order ON balance_sheet_items(book_id, section, sort_order, id)',
  );
}

/// Full v3 schema for a new database (tests and older migrations).
@visibleForTesting
Future<void> createBennetDatabaseSchemaV3(Database db) async {
  await _createLedgerTablesAndSeed(db);
  await installClientAccountsSchemaV2(db);
  await installClientReceiptsSchemaV3(db);
}

/// Full v4 schema for new databases.
@visibleForTesting
Future<void> createBennetDatabaseSchemaV4(Database db) async {
  await createBennetDatabaseSchemaV3(db);
  await installLedgerPerformanceIndexesV4(db);
}

Future<Database> openBennetDatabase() async {
  final path = await bennetDatabasePath();
  return openDatabase(
    path,
    version: dbVersion,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await installClientAccountsSchemaV2(db);
      }
      if (oldVersion < 3) {
        await installClientReceiptsSchemaV3(db);
      }
      if (oldVersion < 4) {
        await installLedgerPerformanceIndexesV4(db);
      }
    },
    onCreate: (db, version) async {
      await createBennetDatabaseSchemaV4(db);
    },
  );
}
