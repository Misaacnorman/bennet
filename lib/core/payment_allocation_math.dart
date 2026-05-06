import '../domain/client_accounts.dart';

/// Breakdown of posted amounts for [RecordPaymentInput.allocations].
typedef PaymentAllocationTotals = ({
  int allocatedSumMinor,
  int unallocatedMinor,
});

/// Collapses duplicate [chargeId] lines by summing amounts.
List<PaymentAllocationInput> mergePaymentAllocationsByCharge(
  List<PaymentAllocationInput> allocations,
) {
  final map = <int, int>{};
  for (final a in allocations) {
    map[a.chargeId] = (map[a.chargeId] ?? 0) + a.amountMinor;
  }
  return [
    for (final e in map.entries)
      PaymentAllocationInput(chargeId: e.key, amountMinor: e.value),
  ];
}

/// Validates allocation lines (positive amounts, sum ≤ payment) and returns totals.
/// Matches rules enforced by [ClientAccountRepository.recordPayment] implementations.
PaymentAllocationTotals summarizePaymentAllocations({
  required int paymentAmountMinor,
  required List<PaymentAllocationInput> allocations,
}) {
  if (paymentAmountMinor <= 0) throw ArgumentError('amount');
  var allocSum = 0;
  for (final a in allocations) {
    if (a.amountMinor <= 0) throw ArgumentError('allocation');
    allocSum += a.amountMinor;
  }
  if (allocSum > paymentAmountMinor) {
    throw ArgumentError('allocations exceed payment');
  }
  return (
    allocatedSumMinor: allocSum,
    unallocatedMinor: paymentAmountMinor - allocSum,
  );
}

/// Validates merged allocation lines against charge ownership, voided state, and open
/// amounts from **posted** payments only ([postedAllocationsByChargeId]).
void validateRecordPaymentAllocations({
  required int paymentClientId,
  required List<PaymentAllocationInput> mergedAllocations,
  required Iterable<ClientCharge> clientCharges,
  required Map<int, int> postedAllocationsByChargeId,
}) {
  final byId = {for (final c in clientCharges) c.id: c};
  for (final a in mergedAllocations) {
    final ch = byId[a.chargeId];
    if (ch == null) {
      throw ArgumentError.value(a.chargeId, 'chargeId', 'Charge not found');
    }
    if (ch.clientId != paymentClientId) {
      throw ArgumentError.value(
        a.chargeId,
        'chargeId',
        'Charge does not belong to this client',
      );
    }
    if (ch.status == ChargeStatus.voided) {
      throw ArgumentError.value(
        a.chargeId,
        'chargeId',
        'Cannot allocate to a voided charge',
      );
    }
    final already = postedAllocationsByChargeId[a.chargeId] ?? 0;
    final rawOpen = ch.amountMinor - already;
    final openClamp = rawOpen > 0 ? rawOpen : 0;
    if (a.amountMinor > openClamp) {
      throw ArgumentError(
        'Allocation for charge #${a.chargeId} exceeds remaining open amount',
      );
    }
  }
}
