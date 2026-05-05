import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/client_accounts.dart';
import '../domain/client_account_repository.dart';
import '../data/client_account_repository_impl.dart';
import '../data/firebase/firestore_client_account_repository.dart';
import 'backend_config.dart';
import 'providers.dart';

final clientAccountRepositoryProvider = FutureProvider<ClientAccountRepository>(
  (ref) async {
    final ledger = await ref.watch(ledgerRepositoryProvider.future);
    if (kUseSqliteBackend) {
      return ClientAccountRepositoryImpl.open(ledger);
    }
    final uid = ref.watch(currentUidProvider);
    if (uid == null) throw StateError('Not signed in');
    return FirestoreClientAccountRepository(uid: uid, ledger: ledger);
  },
);

final clientsProvider = FutureProvider<List<Client>>((ref) async {
  final repo = await ref.watch(clientAccountRepositoryProvider.future);
  return repo.listClients();
});

final clientProvider = FutureProvider.family<Client?, int>((ref, id) async {
  final repo = await ref.watch(clientAccountRepositoryProvider.future);
  return repo.getClient(id);
});

final clientSummaryProvider = FutureProvider.family<ClientAccountSummary, int>((
  ref,
  clientId,
) async {
  final repo = await ref.watch(clientAccountRepositoryProvider.future);
  return repo.clientSummary(clientId);
});

final clientSummariesProvider = FutureProvider<List<ClientAccountSummary>>((
  ref,
) async {
  final repo = await ref.watch(clientAccountRepositoryProvider.future);
  return repo.listClientSummaries();
});

final clientLedgerProvider =
    FutureProvider.family<
      List<ClientLedgerLine>,
      ({int clientId, DateTime? from, DateTime? to})
    >((ref, arg) async {
      final repo = await ref.watch(clientAccountRepositoryProvider.future);
      return repo.clientLedger(arg.clientId, from: arg.from, to: arg.to);
    });

final clientPaymentsProvider = FutureProvider.family<List<ClientPayment>, int?>(
  (ref, clientId) async {
    final repo = await ref.watch(clientAccountRepositoryProvider.future);
    return repo.listPayments(clientId: clientId);
  },
);

final clientChargesProvider = FutureProvider.family<List<ClientCharge>, int?>((
  ref,
  clientId,
) async {
  final repo = await ref.watch(clientAccountRepositoryProvider.future);
  return repo.listCharges(clientId: clientId);
});

final clientAdjustmentsProvider =
    FutureProvider.family<List<ClientAdjustment>, int>((ref, clientId) async {
      final repo = await ref.watch(clientAccountRepositoryProvider.future);
      return repo.listAdjustments(clientId);
    });

final chargesWithOpenAmountProvider =
    FutureProvider.family<List<({ClientCharge charge, int openMinor})>, int>((
      ref,
      clientId,
    ) async {
      final repo = await ref.watch(clientAccountRepositoryProvider.future);
      return repo.listChargesWithOpenAmount(clientId);
    });

final paymentsRegisterProvider = FutureProvider<List<ClientPayment>>((
  ref,
) async {
  final repo = await ref.watch(clientAccountRepositoryProvider.future);
  return repo.listPayments();
});

final chargesRegisterProvider = FutureProvider<List<ClientCharge>>((ref) async {
  final repo = await ref.watch(clientAccountRepositoryProvider.future);
  return repo.listCharges();
});

final statementPreviewProvider =
    FutureProvider.family<
      StatementPreview,
      ({int clientId, DateTime from, DateTime to})
    >((ref, arg) async {
      final repo = await ref.watch(clientAccountRepositoryProvider.future);
      return repo.buildStatementPreview(
        BuildStatementInput(
          clientId: arg.clientId,
          fromDate: arg.from,
          toDate: arg.to,
        ),
      );
    });

final statementsHistoryProvider =
    FutureProvider.family<List<ClientStatement>, int?>((ref, clientId) async {
      final repo = await ref.watch(clientAccountRepositoryProvider.future);
      return repo.listStatements(clientId: clientId);
    });

final overviewMetricsProvider = FutureProvider<OverviewMetrics>((ref) async {
  final repo = await ref.watch(clientAccountRepositoryProvider.future);
  return repo.overviewMetrics();
});

/// Alias for dashboards that prefer a shorter name (matches docs terminology).
final overviewProvider = overviewMetricsProvider;

final paymentDetailProvider =
    FutureProvider.family<({ClientPayment? payment, Client? client}), int>((
      ref,
      paymentId,
    ) async {
      final repo = await ref.watch(clientAccountRepositoryProvider.future);
      final payment = await repo.getPayment(paymentId);
      final client = payment != null
          ? await repo.getClient(payment.clientId)
          : null;
      return (payment: payment, client: client);
    });

/// After client-account writes, refresh dependent providers.
void invalidateClientAccounts(WidgetRef ref, {int? clientId}) {
  ref.invalidate(clientsProvider);
  ref.invalidate(clientSummariesProvider);
  ref.invalidate(overviewMetricsProvider);
  ref.invalidate(paymentsRegisterProvider);
  ref.invalidate(chargesRegisterProvider);
  ref.invalidate(paymentDetailProvider);
  ref.invalidate(statementPreviewProvider);
  if (clientId != null) {
    ref.invalidate(clientProvider(clientId));
    ref.invalidate(clientSummaryProvider(clientId));
    ref.invalidate(clientPaymentsProvider(clientId));
    ref.invalidate(clientChargesProvider(clientId));
    ref.invalidate(clientAdjustmentsProvider(clientId));
    ref.invalidate(chargesWithOpenAmountProvider(clientId));
    ref.invalidate(statementsHistoryProvider(clientId));
    ref.invalidate(clientLedgerProvider);
  }
}

extension ClientAccountRepoX on WidgetRef {
  Future<ClientAccountRepository> get clientAccounts =>
      read(clientAccountRepositoryProvider.future);
}
