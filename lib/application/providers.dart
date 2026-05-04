import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities.dart';
import '../domain/ledger_repository.dart';
import '../data/database/sqlite_init.dart';
import '../data/ledger_repository_impl.dart';

final ledgerRepositoryProvider = FutureProvider<LedgerRepository>((ref) async {
  ensureSqlitePlatformInitialized();
  return LedgerRepositoryImpl.open();
});

final defaultBookProvider = FutureProvider<Book>((ref) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.defaultBook();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.listCategories();
});

final accountsProvider = FutureProvider.family<List<Account>, int>((ref, bookId) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.listAccounts(bookId);
});

final monthlySummaryProvider =
    FutureProvider.family<MonthlySummary, ({int bookId, int year, int month})>(
  (ref, arg) async {
    final repo = await ref.watch(ledgerRepositoryProvider.future);
    return repo.monthlySummary(arg.bookId, arg.year, arg.month);
  },
);

final openingBalanceProvider =
    FutureProvider.family<int, ({int bookId, int year, int month})>((ref, arg) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.resolveOpeningMinor(arg.bookId, arg.year, arg.month);
});

final transactionsProvider = FutureProvider.family<
    List<LedgerTransaction>,
    ({int bookId, int? year, int? month})>((ref, arg) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.listTransactions(
    bookId: arg.bookId,
    year: arg.year,
    month: arg.month,
  );
});

final businessNameProvider = FutureProvider<String?>((ref) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.getSetting('business_name');
});

final reconciliationBundleProvider = FutureProvider.family<
    ({
      List<BankStatementLine> lines,
      ReconciliationSummary summary,
    }),
    int>((ref, accountId) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  final lines = await repo.listStatementLines(accountId);
  final summary = await repo.reconciliationSummary(accountId);
  return (lines: lines, summary: summary);
});

final balanceSheetItemsProvider =
    FutureProvider.family<List<BalanceSheetItem>, int>((ref, bookId) async {
  final repo = await ref.watch(ledgerRepositoryProvider.future);
  return repo.listBalanceSheetItems(bookId);
});

/// Invalidates data-heavy providers after writes.
void invalidateLedger(WidgetRef ref) {
  ref.invalidate(transactionsProvider);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(openingBalanceProvider);
  ref.invalidate(reconciliationBundleProvider);
  ref.invalidate(balanceSheetItemsProvider);
  ref.invalidate(defaultBookProvider);
}

extension LedgerRepoX on WidgetRef {
  Future<LedgerRepository> get ledger async =>
      read(ledgerRepositoryProvider.future);
}
