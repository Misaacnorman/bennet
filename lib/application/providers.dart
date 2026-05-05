import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities.dart';
import '../domain/ledger_repository.dart';
import 'backend_config.dart';
import '../data/database/sqlite_init.dart';
import '../data/ledger_repository_impl.dart';
import '../data/firebase/firestore_ledger_repository.dart';

/// Firebase auth stream (null when signed out).
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Resolved UID for data layer (handles brief AsyncLoading after startup).
final currentUidProvider = Provider<String?>((ref) {
  final async = ref.watch(firebaseAuthStateProvider);
  if (async.hasValue && async.requireValue != null) {
    return async.requireValue!.uid;
  }
  return FirebaseAuth.instance.currentUser?.uid;
});

final ledgerRepositoryProvider = FutureProvider<LedgerRepository>((ref) async {
  if (kUseSqliteBackend) {
    ensureSqlitePlatformInitialized();
    return openSqliteLedger();
  }
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw StateError('Not signed in');
  final repo = FirestoreLedgerRepository(uid: uid);
  await repo.ensureBootstrap();
  return repo;
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
  ref.invalidate(categoriesProvider);
}

extension LedgerRepoX on WidgetRef {
  Future<LedgerRepository> get ledger async =>
      read(ledgerRepositoryProvider.future);
}

/// Opens local SQLite ledger (no Firestore).
/// Enable alongside [`ClientAccountRepositoryImpl`] via `--dart-define=USE_SQLITE=true`.
Future<LedgerRepository> openSqliteLedger() async {
  ensureSqlitePlatformInitialized();
  return LedgerRepositoryImpl.open();
}
