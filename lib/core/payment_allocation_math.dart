import '../domain/client_accounts.dart';

/// Breakdown of posted amounts for [RecordPaymentInput.allocations].
typedef PaymentAllocationTotals = ({
  int allocatedSumMinor,
  int unallocatedMinor,
});

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
