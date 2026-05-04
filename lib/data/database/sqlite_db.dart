import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

const _dbName = 'bennet.db';
const dbVersion = 1;

Future<String> bennetDatabasePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, _dbName);
}

Future<Database> openBennetDatabase() async {
  final path = await bennetDatabasePath();
  return openDatabase(
    path,
    version: dbVersion,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
    onCreate: (db, version) async {
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
    },
  );
}
