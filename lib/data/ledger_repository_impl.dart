import 'package:sqflite/sqflite.dart';

import '../core/period_math.dart';
import 'database/sqlite_db.dart';
import '../domain/entities.dart';
import '../domain/ledger_repository.dart';

class LedgerRepositoryImpl implements LedgerRepository {
  LedgerRepositoryImpl(this._db);

  final Database _db;

  static Future<LedgerRepositoryImpl> open() async {
    final db = await openBennetDatabase();
    return LedgerRepositoryImpl(db);
  }

  @override
  Future<Book> defaultBook() async {
    final rows = await _db.query('books', limit: 1, orderBy: 'id ASC');
    final r = rows.first;
    return Book(id: r['id'] as int, name: r['name'] as String);
  }

  @override
  Future<List<Category>> listCategories() async {
    final rows = await _db.query('categories', orderBy: 'name COLLATE NOCASE');
    return rows
        .map(
          (r) => Category(id: r['id'] as int, name: r['name'] as String),
        )
        .toList();
  }

  @override
  Future<List<Account>> listAccounts(int bookId) async {
    final rows = await _db.query(
      'accounts',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'kind ASC, name COLLATE NOCASE',
    );
    return rows.map(_accountFromRow).toList();
  }

  Account _accountFromRow(Map<String, Object?> r) => Account(
        id: r['id'] as int,
        bookId: r['book_id'] as int,
        name: r['name'] as String,
        kind: AccountKindSerialized.parse(r['kind'] as String),
      );

  @override
  Future<int?> cashAccountId(int bookId) async {
    final rows = await _db.query(
      'accounts',
      columns: ['id'],
      where: 'book_id = ? AND kind = ?',
      whereArgs: [bookId, 'cash'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  @override
  Future<int> addBankAccount({
    required int bookId,
    required String name,
  }) {
    return _db.insert('accounts', {
      'book_id': bookId,
      'name': name,
      'kind': 'bank',
    });
  }

  @override
  Future<List<LedgerTransaction>> listTransactions({
    required int bookId,
    int? year,
    int? month,
    int? accountId,
  }) async {
    final where = <String>['t.book_id = ?'];
    final args = <Object?>[bookId];
    if (year != null && month != null) {
      final start = DateTime(year, month).millisecondsSinceEpoch;
      final end = DateTime(year, month + 1).millisecondsSinceEpoch;
      where.add('t.occurred_at >= ? AND t.occurred_at < ?');
      args.addAll([start, end]);
    }
    if (accountId != null) {
      where.add('t.account_id = ?');
      args.add(accountId);
    }
    final rows = await _db.rawQuery(
      '''
SELECT t.*, c.name AS category_name, a.name AS account_name
FROM transactions t
JOIN categories c ON c.id = t.category_id
JOIN accounts a ON a.id = t.account_id
WHERE ${where.join(' AND ')}
ORDER BY t.occurred_at ASC, t.id ASC
''',
      args,
    );
    return rows.map(_txFromRow).toList();
  }

  LedgerTransaction _txFromRow(Map<String, Object?> r) {
    final cleared = r['cleared_at'] as int?;
    return LedgerTransaction(
      id: r['id'] as int,
      bookId: r['book_id'] as int,
      accountId: r['account_id'] as int,
      categoryId: r['category_id'] as int,
      type: TxTypeSerialized.parse(r['type'] as String),
      amountMinor: r['amount_minor'] as int,
      occurredAt: DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int),
      notes: r['notes'] as String?,
      paymentMethod: r['payment_method'] as String?,
      counterparty: r['counterparty'] as String?,
      clearedAt:
          cleared != null ? DateTime.fromMillisecondsSinceEpoch(cleared) : null,
      categoryName: r['category_name'] as String?,
      accountName: r['account_name'] as String?,
    );
  }

  @override
  Future<LedgerTransaction?> getTransaction(int id) async {
    final rows = await _db.rawQuery(
      '''
SELECT t.*, c.name AS category_name, a.name AS account_name
FROM transactions t
JOIN categories c ON c.id = t.category_id
JOIN accounts a ON a.id = t.account_id
WHERE t.id = ?
LIMIT 1
''',
      [id],
    );
    if (rows.isEmpty) return null;
    return _txFromRow(rows.first);
  }

  @override
  Future<int> insertTransaction({
    required int bookId,
    required int accountId,
    required int categoryId,
    required TxType type,
    required int amountMinor,
    required DateTime occurredAt,
    String? notes,
    String? paymentMethod,
    String? counterparty,
  }) {
    return _db.insert('transactions', {
      'book_id': bookId,
      'account_id': accountId,
      'category_id': categoryId,
      'type': type.name,
      'amount_minor': amountMinor,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'notes': notes,
      'payment_method': paymentMethod,
      'counterparty': counterparty,
      'cleared_at': null,
    });
  }

  @override
  Future<void> updateTransaction({
    required int id,
    required int accountId,
    required int categoryId,
    required TxType type,
    required int amountMinor,
    required DateTime occurredAt,
    String? notes,
    String? paymentMethod,
    String? counterparty,
    DateTime? clearedAt,
  }) async {
    await _db.update(
      'transactions',
      {
        'account_id': accountId,
        'category_id': categoryId,
        'type': type.name,
        'amount_minor': amountMinor,
        'occurred_at': occurredAt.millisecondsSinceEpoch,
        'notes': notes,
        'payment_method': paymentMethod,
        'counterparty': counterparty,
        'cleared_at': clearedAt?.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    await _db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int?> getOpeningMinor(int bookId, int year, int month) async {
    final rows = await _db.query(
      'period_openings',
      columns: ['opening_balance_minor'],
      where: 'book_id = ? AND year = ? AND month = ?',
      whereArgs: [bookId, year, month],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['opening_balance_minor'] as int;
  }

  @override
  Future<void> setOpeningMinor(
    int bookId,
    int year,
    int month,
    int minor,
  ) async {
    final existing = await _db.query(
      'period_openings',
      columns: ['id'],
      where: 'book_id = ? AND year = ? AND month = ?',
      whereArgs: [bookId, year, month],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _db.insert('period_openings', {
        'book_id': bookId,
        'year': year,
        'month': month,
        'opening_balance_minor': minor,
      });
    } else {
      await _db.update(
        'period_openings',
        {'opening_balance_minor': minor},
        where: 'book_id = ? AND year = ? AND month = ?',
        whereArgs: [bookId, year, month],
      );
    }
  }

  (int, int) _prevMonth(int year, int month) {
    if (month == 1) return (year - 1, 12);
    return (year, month - 1);
  }

  @override
  Future<int> resolveOpeningMinor(
    int bookId,
    int year,
    int month, [
    int guard = 0,
  ]) async {
    if (guard > 800) return 0;
    final stored = await getOpeningMinor(bookId, year, month);
    if (stored != null) return stored;
    final (py, pm) = _prevMonth(year, month);
    final prevOpen = await resolveOpeningMinor(bookId, py, pm, guard + 1);
    final txs = await listTransactions(bookId: bookId, year: py, month: pm);
    final net = totalsForMonth(txs, py, pm).netMinor;
    return prevOpen + net;
  }

  @override
  Future<MonthlySummary> monthlySummary(
    int bookId,
    int year,
    int month,
  ) async {
    final opening = await resolveOpeningMinor(bookId, year, month);
    final txs = await listTransactions(bookId: bookId, year: year, month: month);
    final totals = totalsForMonth(txs, year, month);
    final closing = opening + totals.netMinor;
    return MonthlySummary(
      openingMinor: opening,
      totalIncomeMinor: totals.incomeMinor,
      totalExpenseMinor: totals.expenseMinor,
      netMinor: totals.netMinor,
      closingMinor: closing,
    );
  }

  @override
  Future<List<BankStatementLine>> listStatementLines(int accountId) async {
    final rows = await _db.query(
      'bank_statement_lines',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'posted_at DESC, id DESC',
    );
    return rows.map(_stmtFromRow).toList();
  }

  BankStatementLine _stmtFromRow(Map<String, Object?> r) => BankStatementLine(
        id: r['id'] as int,
        accountId: r['account_id'] as int,
        postedAt:
            DateTime.fromMillisecondsSinceEpoch(r['posted_at'] as int),
        amountMinor: r['amount_minor'] as int,
        description: r['description'] as String,
        matchedTransactionId: r['matched_transaction_id'] as int?,
      );

  @override
  Future<int> insertStatementLine({
    required int accountId,
    required DateTime postedAt,
    required int amountMinor,
    required String description,
  }) {
    return _db.insert('bank_statement_lines', {
      'account_id': accountId,
      'posted_at': postedAt.millisecondsSinceEpoch,
      'amount_minor': amountMinor,
      'description': description,
      'matched_transaction_id': null,
    });
  }

  @override
  Future<void> deleteStatementLine(int id) async {
    await _db.delete('bank_statement_lines', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> matchStatementLine({
    required int statementLineId,
    required int transactionId,
  }) async {
    await _db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'cleared_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      await txn.update(
        'bank_statement_lines',
        {'matched_transaction_id': transactionId},
        where: 'id = ?',
        whereArgs: [statementLineId],
      );
    });
  }

  @override
  Future<void> unmatchStatementLine(int statementLineId) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        'bank_statement_lines',
        columns: ['matched_transaction_id'],
        where: 'id = ?',
        whereArgs: [statementLineId],
        limit: 1,
      );
      final txId = rows.first['matched_transaction_id'] as int?;
      await txn.update(
        'bank_statement_lines',
        {'matched_transaction_id': null},
        where: 'id = ?',
        whereArgs: [statementLineId],
      );
      if (txId != null) {
        await txn.update(
          'transactions',
          {'cleared_at': null},
          where: 'id = ?',
          whereArgs: [txId],
        );
      }
    });
  }

  int _signedTx(LedgerTransaction t) =>
      t.type == TxType.income ? t.amountMinor : -t.amountMinor;

  @override
  Future<ReconciliationSummary> reconciliationSummary(int accountId) async {
    final lines = await listStatementLines(accountId);
    var stmtNet = 0;
    var unmatchedStmt = 0;
    var matchedBook = 0;
    for (final line in lines) {
      stmtNet += line.amountMinor;
      if (line.matchedTransactionId == null) {
        unmatchedStmt += line.amountMinor;
      } else {
        final tx = await getTransaction(line.matchedTransactionId!);
        if (tx != null) matchedBook += _signedTx(tx);
      }
    }

    final bookRows = await _db.rawQuery(
      '''
SELECT * FROM transactions WHERE account_id = ?
''',
      [accountId],
    );
    var uncleared = 0;
    for (final r in bookRows) {
      if (r['cleared_at'] != null) continue;
      final typeStr = r['type'] as String;
      final amt = r['amount_minor'] as int;
      final type = TxTypeSerialized.parse(typeStr);
      uncleared += type == TxType.income ? amt : -amt;
    }

    return ReconciliationSummary(
      statementNetMinor: stmtNet,
      matchedBookNetMinor: matchedBook,
      unmatchedStatementMinor: unmatchedStmt,
      unclearedBookMinor: uncleared,
    );
  }

  @override
  Future<List<BalanceSheetItem>> listBalanceSheetItems(int bookId) async {
    final rows = await _db.query(
      'balance_sheet_items',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'section ASC, sort_order ASC, id ASC',
    );
    return rows.map(_bsFromRow).toList();
  }

  BalanceSheetItem _bsFromRow(Map<String, Object?> r) => BalanceSheetItem(
        id: r['id'] as int,
        bookId: r['book_id'] as int,
        section: BalanceSectionSerialized.parse(r['section'] as String),
        label: r['label'] as String,
        amountMinor: r['amount_minor'] as int,
        sortOrder: r['sort_order'] as int,
      );

  @override
  Future<int> insertBalanceSheetItem({
    required int bookId,
    required BalanceSection section,
    required String label,
    required int amountMinor,
    int sortOrder = 0,
  }) {
    return _db.insert('balance_sheet_items', {
      'book_id': bookId,
      'section': section.name,
      'label': label,
      'amount_minor': amountMinor,
      'sort_order': sortOrder,
    });
  }

  @override
  Future<void> updateBalanceSheetItem({
    required int id,
    required String label,
    required int amountMinor,
    required int sortOrder,
  }) async {
    await _db.update(
      'balance_sheet_items',
      {
        'label': label,
        'amount_minor': amountMinor,
        'sort_order': sortOrder,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteBalanceSheetItem(int id) async {
    await _db.delete('balance_sheet_items', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<String?> getSetting(String key) async {
    final rows = await _db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<CategoryRollup>> categoryRollups({
    required int bookId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.rawQuery(
      '''
SELECT c.id AS cid, c.name AS cname,
  SUM(CASE WHEN t.type = 'income' THEN t.amount_minor ELSE 0 END) AS inc,
  SUM(CASE WHEN t.type = 'expense' THEN t.amount_minor ELSE 0 END) AS exp
FROM transactions t
JOIN categories c ON c.id = t.category_id
WHERE t.book_id = ?
  AND t.occurred_at >= ?
  AND t.occurred_at < ?
GROUP BY c.id, c.name
ORDER BY c.name COLLATE NOCASE
''',
      [
        bookId,
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch,
      ],
    );
    return rows
        .map(
          (r) => CategoryRollup(
            categoryId: r['cid'] as int,
            categoryName: r['cname'] as String,
            incomeMinor: (r['inc'] as num?)?.toInt() ?? 0,
            expenseMinor: (r['exp'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }
}
