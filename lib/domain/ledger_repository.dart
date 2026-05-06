import 'entities.dart';

abstract class LedgerRepository {
  Future<Book> defaultBook();

  Future<List<Category>> listCategories();

  Future<List<Account>> listAccounts(int bookId);

  Future<int?> cashAccountId(int bookId);

  Future<int> addBankAccount({required int bookId, required String name});

  Future<List<LedgerTransaction>> listTransactions({
    required int bookId,
    int? year,
    int? month,
    int? accountId,
  });

  Future<LedgerTransaction?> getTransaction(int id);

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
    int? clientId,
    String? sourceType,
    int? sourceId,
    String? sourceNumber,
  });

  /// Sets optional traceability columns (client link and document source).
  Future<void> setTransactionTraceability({
    required int transactionId,
    int? clientId,
    String? sourceType,
    int? sourceId,
    String? sourceNumber,
  });

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
  });

  Future<void> deleteTransaction(int id);

  Future<int?> getOpeningMinor(int bookId, int year, int month);

  Future<void> setOpeningMinor(int bookId, int year, int month, int minor);

  /// Resolves opening: stored value for month, else derived closing of prior month, else 0.
  Future<int> resolveOpeningMinor(int bookId, int year, int month);

  Future<MonthlySummary> monthlySummary(int bookId, int year, int month);

  Future<List<BankStatementLine>> listStatementLines(int accountId);

  Future<int> insertStatementLine({
    required int accountId,
    required DateTime postedAt,
    required int amountMinor,
    required String description,
  });

  Future<void> deleteStatementLine(int id);

  Future<void> matchStatementLine({
    required int statementLineId,
    required int transactionId,
  });

  Future<void> unmatchStatementLine(int statementLineId);

  Future<ReconciliationSummary> reconciliationSummary(int accountId);

  Future<List<BalanceSheetItem>> listBalanceSheetItems(int bookId);

  Future<int> insertBalanceSheetItem({
    required int bookId,
    required BalanceSection section,
    required String label,
    required int amountMinor,
    int sortOrder = 0,
  });

  Future<void> updateBalanceSheetItem({
    required int id,
    required String label,
    required int amountMinor,
    required int sortOrder,
  });

  Future<void> deleteBalanceSheetItem(int id);

  Future<String?> getSetting(String key);

  Future<void> setSetting(String key, String value);

  Future<List<CategoryRollup>> categoryRollups({
    required int bookId,
    required DateTime from,
    required DateTime to,
  });
}

class MonthlySummary {
  const MonthlySummary({
    required this.openingMinor,
    required this.totalIncomeMinor,
    required this.totalExpenseMinor,
    required this.netMinor,
    required this.closingMinor,
  });

  final int openingMinor;
  final int totalIncomeMinor;
  final int totalExpenseMinor;
  final int netMinor;
  final int closingMinor;
}

class ReconciliationSummary {
  const ReconciliationSummary({
    required this.statementNetMinor,
    required this.matchedBookNetMinor,
    required this.unmatchedStatementMinor,
    required this.unclearedBookMinor,
  });

  final int statementNetMinor;
  final int matchedBookNetMinor;
  final int unmatchedStatementMinor;
  final int unclearedBookMinor;
}
