import 'client_accounts.dart';

abstract class ClientAccountRepository {
  Future<List<Client>> listClients({ClientStatus? status, String? query});

  Future<Client?> getClient(int id);

  Future<int> createClient(CreateClientInput input);

  Future<void> updateClient(UpdateClientInput input);

  Future<void> archiveClient(int id);

  Future<ClientAccountSummary> clientSummary(int clientId);

  Future<List<ClientAccountSummary>> listClientSummaries({
    ClientStatus? status,
    String? query,
  });

  Future<List<ClientLedgerLine>> clientLedger(
    int clientId, {
    DateTime? from,
    DateTime? to,
  });

  Future<List<ClientCharge>> listCharges({int? clientId, ChargeStatus? status});

  Future<ClientCharge?> getCharge(int id);

  Future<int> createCharge(CreateChargeInput input);

  Future<void> voidCharge(int chargeId, String reason);

  Future<int> createAdjustment(CreateClientAdjustmentInput input);

  Future<List<ClientAdjustment>> listAdjustments(int clientId);

  /// Open (non-voided) charges with remaining collectible minor after allocations.
  Future<List<({ClientCharge charge, int openMinor})>>
  listChargesWithOpenAmount(int clientId);

  Future<List<ClientPayment>> listPayments({
    int? clientId,
    PaymentStatus? status,
  });

  Future<ClientPayment?> getPayment(int id);

  Future<List<PaymentAllocation>> listAllocationsForPayment(int paymentId);

  Future<int> recordPayment(RecordPaymentInput input);

  Future<void> reversePayment(int paymentId, String reason);

  Future<ReceiptDocument> receiptForPayment(int paymentId);

  Future<StatementPreview> buildStatementPreview(BuildStatementInput input);

  Future<int> saveStatement(BuildStatementInput input);

  Future<List<ClientStatement>> listStatements({int? clientId});

  /// Book-wide metrics for overview dashboard.
  Future<OverviewMetrics> overviewMetrics();
}

class OverviewMetrics {
  const OverviewMetrics({
    required this.totalBalanceMinor,
    required this.openChargesTotalMinor,
    required this.overdueOpenChargeCount,
    required this.postedPaymentsLast30DaysMinor,
    required this.activeClientCount,
  });

  final int totalBalanceMinor;
  final int openChargesTotalMinor;
  final int overdueOpenChargeCount;
  final int postedPaymentsLast30DaysMinor;
  final int activeClientCount;
}
