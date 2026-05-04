import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/period_math.dart';
import '../../domain/entities.dart';
import '../../domain/ledger_repository.dart';

/// Cloud Firestore backend: `users/{uid}/books/{bookId}/…`
class FirestoreLedgerRepository implements LedgerRepository {
  FirestoreLedgerRepository({
    required String uid,
    FirebaseFirestore? firestore,
    int defaultBookId = 1,
  }) : _uid = uid,
       _db = firestore ?? FirebaseFirestore.instance,
       _defaultBookId = defaultBookId;

  final String _uid;
  final FirebaseFirestore _db;
  final int _defaultBookId;

  DocumentReference<Map<String, dynamic>> get _bookDoc =>
      _db.doc('users/$_uid/books/$_defaultBookId');

  CollectionReference<Map<String, dynamic>> get _categories =>
      _bookDoc.collection('categories');

  CollectionReference<Map<String, dynamic>> get _accounts =>
      _bookDoc.collection('accounts');

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _bookDoc.collection('transactions');

  CollectionReference<Map<String, dynamic>> get _periodOpenings =>
      _bookDoc.collection('periodOpenings');

  CollectionReference<Map<String, dynamic>> get _statementLines =>
      _bookDoc.collection('statementLines');

  CollectionReference<Map<String, dynamic>> get _balanceSheetItems =>
      _bookDoc.collection('balanceSheetItems');

  DocumentReference<Map<String, dynamic>> get _metaIds =>
      _bookDoc.collection('_meta').doc('ids');

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _db.doc('users/$_uid/settings/app');

  static String _periodKey(int year, int month) =>
      '${year}_${month.toString().padLeft(2, '0')}';

  /// Creates default book, categories, cash account, and ID counters if missing.
  Future<void> ensureBootstrap() async {
    final snap = await _bookDoc.get();
    if (snap.exists) return;

    final batch = _db.batch();
    batch.set(_bookDoc, {
      'name': 'Main',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_categories.doc('1'), {'name': 'General income'});
    batch.set(_categories.doc('2'), {'name': 'General expense'});
    batch.set(_accounts.doc('1'), {
      'name': 'Cash',
      'kind': 'cash',
      'bookId': _defaultBookId,
    });
    batch.set(_metaIds, {
      'nextCategoryId': 3,
      'nextAccountId': 2,
      'nextTransactionId': 1,
      'nextStatementLineId': 1,
      'nextBalanceSheetItemId': 1,
    });
    await batch.commit();
  }

  Future<int> _allocateId(String counterField, int fallbackSeed) async {
    return _db.runTransaction<int>((txn) async {
      final snap = await txn.get(_metaIds);
      final data = snap.data();
      final next = (data?[counterField] as int?) ?? fallbackSeed;
      txn.set(_metaIds, {counterField: next + 1}, SetOptions(merge: true));
      return next;
    });
  }

  Future<Map<int, String>> _categoryNames() async {
    final snap = await _categories.get();
    return {
      for (final d in snap.docs) int.parse(d.id): d.data()['name'] as String,
    };
  }

  Future<Map<int, String>> _accountNames() async {
    final snap = await _accounts.get();
    return {
      for (final d in snap.docs) int.parse(d.id): d.data()['name'] as String,
    };
  }

  @override
  Future<Book> defaultBook() async {
    await ensureBootstrap();
    final snap = await _bookDoc.get();
    final name = snap.data()?['name'] as String? ?? 'Main';
    return Book(id: _defaultBookId, name: name);
  }

  @override
  Future<List<Category>> listCategories() async {
    await ensureBootstrap();
    final snap = await _categories.get();
    final list =
        snap.docs
            .map(
              (d) => Category(
                id: int.parse(d.id),
                name: d.data()['name'] as String,
              ),
            )
            .toList()
          ..sort(
            (Category a, Category b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return list;
  }

  @override
  Future<List<Account>> listAccounts(int bookId) async {
    await ensureBootstrap();
    final snap = await _accounts.get();
    final list =
        snap.docs.map((d) {
          final m = d.data();
          return Account(
            id: int.parse(d.id),
            bookId: bookId,
            name: m['name'] as String,
            kind: AccountKindSerialized.parse(m['kind'] as String),
          );
        }).toList()..sort((Account a, Account b) {
          final k = a.kind.name.compareTo(b.kind.name);
          if (k != 0) return k;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    return list;
  }

  @override
  Future<int?> cashAccountId(int bookId) async {
    final snap = await _accounts
        .where('kind', isEqualTo: 'cash')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return int.parse(snap.docs.first.id);
  }

  @override
  Future<int> addBankAccount({
    required int bookId,
    required String name,
  }) async {
    final id = await _allocateId('nextAccountId', 2);
    await _accounts.doc('$id').set({
      'name': name,
      'kind': 'bank',
      'bookId': bookId,
    });
    return id;
  }

  Query<Map<String, dynamic>> _transactionsQuery({
    int? year,
    int? month,
    int? accountId,
  }) {
    Query<Map<String, dynamic>> q = _transactions;
    if (accountId != null) {
      q = q.where('accountId', isEqualTo: accountId);
    }
    if (year != null && month != null) {
      final start = DateTime(year, month);
      final end = DateTime(year, month + 1);
      q = q
          .where(
            'occurredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          )
          .where('occurredAt', isLessThan: Timestamp.fromDate(end));
    }
    q = q.orderBy('occurredAt').orderBy(FieldPath.documentId);
    return q;
  }

  LedgerTransaction _txFromDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
    Map<int, String> catNames,
    Map<int, String> accNames,
  ) {
    final m = d.data()!;
    final cleared = m['clearedAt'] as Timestamp?;
    final oid = int.parse(d.id);
    return LedgerTransaction(
      id: oid,
      bookId: _defaultBookId,
      accountId: m['accountId'] as int,
      categoryId: m['categoryId'] as int,
      type: TxTypeSerialized.parse(m['type'] as String),
      amountMinor: (m['amountMinor'] as num).toInt(),
      occurredAt: (m['occurredAt'] as Timestamp).toDate(),
      notes: m['notes'] as String?,
      paymentMethod: m['paymentMethod'] as String?,
      counterparty: m['counterparty'] as String?,
      clearedAt: cleared?.toDate(),
      categoryName: catNames[m['categoryId'] as int],
      accountName: accNames[m['accountId'] as int],
    );
  }

  @override
  Future<List<LedgerTransaction>> listTransactions({
    required int bookId,
    int? year,
    int? month,
    int? accountId,
  }) async {
    await ensureBootstrap();
    final catNames = await _categoryNames();
    final accNames = await _accountNames();
    final snap = await _transactionsQuery(
      year: year,
      month: month,
      accountId: accountId,
    ).get();
    return snap.docs.map((d) => _txFromDoc(d, catNames, accNames)).toList();
  }

  @override
  Future<LedgerTransaction?> getTransaction(int id) async {
    await ensureBootstrap();
    final d = await _transactions.doc('$id').get();
    if (!d.exists) return null;
    final catNames = await _categoryNames();
    final accNames = await _accountNames();
    return _txFromDoc(d, catNames, accNames);
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
  }) async {
    final id = await _allocateId('nextTransactionId', 1);
    await _transactions.doc('$id').set({
      'bookId': bookId,
      'accountId': accountId,
      'categoryId': categoryId,
      'type': type.name,
      'amountMinor': amountMinor,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'notes': notes,
      'paymentMethod': paymentMethod,
      'counterparty': counterparty,
      'clearedAt': null,
    });
    return id;
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
    await _transactions.doc('$id').update({
      'accountId': accountId,
      'categoryId': categoryId,
      'type': type.name,
      'amountMinor': amountMinor,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'notes': notes,
      'paymentMethod': paymentMethod,
      'counterparty': counterparty,
      if (clearedAt != null)
        'clearedAt': Timestamp.fromDate(clearedAt)
      else
        'clearedAt': FieldValue.delete(),
    });
  }

  @override
  Future<void> deleteTransaction(int id) async {
    await _transactions.doc('$id').delete();
  }

  @override
  Future<int?> getOpeningMinor(int bookId, int year, int month) async {
    final d = await _periodOpenings.doc(_periodKey(year, month)).get();
    if (!d.exists) return null;
    return (d.data()?['openingMinor'] as num?)?.toInt();
  }

  @override
  Future<void> setOpeningMinor(
    int bookId,
    int year,
    int month,
    int minor,
  ) async {
    await _periodOpenings.doc(_periodKey(year, month)).set({
      'openingMinor': minor,
      'year': year,
      'month': month,
    }, SetOptions(merge: true));
  }

  Future<({DateTime monthStart, int openingMinor})?> _latestOpeningOnOrBefore(
    int year,
    int month,
  ) async {
    final snap = await _periodOpenings
        .where(
          FieldPath.documentId,
          isLessThanOrEqualTo: _periodKey(year, month),
        )
        .orderBy(FieldPath.documentId, descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;

    final data = snap.docs.first.data();
    final openingYear = data['year'] as int;
    final openingMonth = data['month'] as int;
    return (
      monthStart: DateTime(openingYear, openingMonth),
      openingMinor: (data['openingMinor'] as num).toInt(),
    );
  }

  Future<int> _netTransactionsBefore(DateTime to, {DateTime? from}) async {
    Query<Map<String, dynamic>> q = _transactions.where(
      'occurredAt',
      isLessThan: Timestamp.fromDate(to),
    );
    if (from != null) {
      q = q.where(
        'occurredAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }

    final snap = await q.get();
    var net = 0;
    for (final d in snap.docs) {
      final m = d.data();
      final amount = (m['amountMinor'] as num).toInt();
      net += m['type'] == TxType.income.name ? amount : -amount;
    }
    return net;
  }

  @override
  Future<int> resolveOpeningMinor(int bookId, int year, int month) async {
    final targetStart = DateTime(year, month);
    final base = await _latestOpeningOnOrBefore(year, month);
    final net = await _netTransactionsBefore(
      targetStart,
      from: base?.monthStart,
    );
    return (base?.openingMinor ?? 0) + net;
  }

  @override
  Future<MonthlySummary> monthlySummary(int bookId, int year, int month) async {
    final opening = await resolveOpeningMinor(bookId, year, month);
    final txs = await listTransactions(
      bookId: bookId,
      year: year,
      month: month,
    );
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

  BankStatementLine _lineFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    final matched = m['matchedTransactionId'];
    return BankStatementLine(
      id: int.parse(d.id),
      accountId: m['accountId'] as int,
      postedAt: (m['postedAt'] as Timestamp).toDate(),
      amountMinor: (m['amountMinor'] as num).toInt(),
      description: m['description'] as String,
      matchedTransactionId: matched != null ? (matched as num).toInt() : null,
    );
  }

  @override
  Future<List<BankStatementLine>> listStatementLines(int accountId) async {
    final snap = await _statementLines
        .where('accountId', isEqualTo: accountId)
        .get();
    final lines = snap.docs.map(_lineFromDoc).toList()
      ..sort((BankStatementLine a, BankStatementLine b) {
        final c = b.postedAt.compareTo(a.postedAt);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    return lines;
  }

  @override
  Future<int> insertStatementLine({
    required int accountId,
    required DateTime postedAt,
    required int amountMinor,
    required String description,
  }) async {
    final id = await _allocateId('nextStatementLineId', 1);
    await _statementLines.doc('$id').set({
      'accountId': accountId,
      'postedAt': Timestamp.fromDate(postedAt),
      'amountMinor': amountMinor,
      'description': description,
      'matchedTransactionId': null,
    });
    return id;
  }

  @override
  Future<void> deleteStatementLine(int id) async {
    await _statementLines.doc('$id').delete();
  }

  @override
  Future<void> matchStatementLine({
    required int statementLineId,
    required int transactionId,
  }) async {
    final batch = _db.batch();
    batch.update(_transactions.doc('$transactionId'), {
      'clearedAt': Timestamp.now(),
    });
    batch.update(_statementLines.doc('$statementLineId'), {
      'matchedTransactionId': transactionId,
    });
    await batch.commit();
  }

  @override
  Future<void> unmatchStatementLine(int statementLineId) async {
    final lineRef = _statementLines.doc('$statementLineId');
    final line = await lineRef.get();
    final txId = line.data()?['matchedTransactionId'] as int?;
    final batch = _db.batch();
    batch.update(lineRef, {'matchedTransactionId': null});
    if (txId != null) {
      batch.update(_transactions.doc('$txId'), {
        'clearedAt': FieldValue.delete(),
      });
    }
    await batch.commit();
  }

  @override
  Future<ReconciliationSummary> reconciliationSummary(int accountId) async {
    final lines = await listStatementLines(accountId);
    int stmtNet = 0;
    int unmatchedStmt = 0;
    int matchedBook = 0;
    for (final line in lines) {
      stmtNet += line.amountMinor;
      if (line.matchedTransactionId == null) {
        unmatchedStmt += line.amountMinor;
      } else {
        final tx = await getTransaction(line.matchedTransactionId!);
        if (tx != null) {
          matchedBook += tx.type == TxType.income
              ? tx.amountMinor
              : -tx.amountMinor;
        }
      }
    }

    final txs = await listTransactions(
      bookId: _defaultBookId,
      accountId: accountId,
    );
    int uncleared = 0;
    for (final t in txs) {
      if (t.clearedAt != null) continue;
      uncleared += t.type == TxType.income ? t.amountMinor : -t.amountMinor;
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
    final snap = await _balanceSheetItems.get();
    final list =
        snap.docs.map((d) {
          final m = d.data();
          return BalanceSheetItem(
            id: int.parse(d.id),
            bookId: bookId,
            section: BalanceSectionSerialized.parse(m['section'] as String),
            label: m['label'] as String,
            amountMinor: (m['amountMinor'] as num).toInt(),
            sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
          );
        }).toList()..sort((BalanceSheetItem a, BalanceSheetItem b) {
          final s = a.sortOrder.compareTo(b.sortOrder);
          return s != 0 ? s : a.id.compareTo(b.id);
        });
    return list;
  }

  @override
  Future<int> insertBalanceSheetItem({
    required int bookId,
    required BalanceSection section,
    required String label,
    required int amountMinor,
    int sortOrder = 0,
  }) async {
    final id = await _allocateId('nextBalanceSheetItemId', 1);
    await _balanceSheetItems.doc('$id').set({
      'section': section.name,
      'label': label,
      'amountMinor': amountMinor,
      'sortOrder': sortOrder,
      'bookId': bookId,
    });
    return id;
  }

  @override
  Future<void> updateBalanceSheetItem({
    required int id,
    required String label,
    required int amountMinor,
    required int sortOrder,
  }) async {
    await _balanceSheetItems.doc('$id').update({
      'label': label,
      'amountMinor': amountMinor,
      'sortOrder': sortOrder,
    });
  }

  @override
  Future<void> deleteBalanceSheetItem(int id) async {
    await _balanceSheetItems.doc('$id').delete();
  }

  @override
  Future<String?> getSetting(String key) async {
    final snap = await _settingsDoc.get();
    final data = snap.data();
    if (data == null) return null;
    return data[key] as String?;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _settingsDoc.set({key: value}, SetOptions(merge: true));
  }

  @override
  Future<List<CategoryRollup>> categoryRollups({
    required int bookId,
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _transactions
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('occurredAt', isLessThan: Timestamp.fromDate(to))
        .get();

    final catNames = await _categoryNames();
    final byCat = <int, ({int inc, int exp})>{};
    for (final d in snap.docs) {
      final m = d.data();
      final cid = m['categoryId'] as int;
      final type = m['type'] as String;
      final amt = (m['amountMinor'] as num).toInt();
      final cur = byCat[cid] ?? (inc: 0, exp: 0);
      if (type == TxType.income.name) {
        byCat[cid] = (inc: cur.inc + amt, exp: cur.exp);
      } else {
        byCat[cid] = (inc: cur.inc, exp: cur.exp + amt);
      }
    }

    return byCat.entries
        .map(
          (e) => CategoryRollup(
            categoryId: e.key,
            categoryName: catNames[e.key] ?? 'Category ${e.key}',
            incomeMinor: e.value.inc,
            expenseMinor: e.value.exp,
          ),
        )
        .toList()
      ..sort(
        (CategoryRollup a, CategoryRollup b) =>
            a.categoryName.compareTo(b.categoryName),
      );
  }
}
