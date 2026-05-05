import 'package:bennet/core/payment_allocation_math.dart';
import 'package:bennet/domain/client_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('summarizePaymentAllocations', () {
    test('empty allocations leaves full amount unallocated', () {
      final t = summarizePaymentAllocations(
        paymentAmountMinor: 5000,
        allocations: const [],
      );
      expect(t.allocatedSumMinor, 0);
      expect(t.unallocatedMinor, 5000);
    });

    test('partial allocation', () {
      final t = summarizePaymentAllocations(
        paymentAmountMinor: 5000,
        allocations: const [
          PaymentAllocationInput(chargeId: 1, amountMinor: 2000),
          PaymentAllocationInput(chargeId: 2, amountMinor: 500),
        ],
      );
      expect(t.allocatedSumMinor, 2500);
      expect(t.unallocatedMinor, 2500);
    });

    test('full allocation', () {
      final t = summarizePaymentAllocations(
        paymentAmountMinor: 100,
        allocations: const [
          PaymentAllocationInput(chargeId: 9, amountMinor: 100),
        ],
      );
      expect(t.unallocatedMinor, 0);
    });

    test('rejects non-positive payment amount', () {
      expect(
        () => summarizePaymentAllocations(
          paymentAmountMinor: 0,
          allocations: const [],
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive allocation line', () {
      expect(
        () => summarizePaymentAllocations(
          paymentAmountMinor: 100,
          allocations: const [
            PaymentAllocationInput(chargeId: 1, amountMinor: 0),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects allocations exceeding payment', () {
      expect(
        () => summarizePaymentAllocations(
          paymentAmountMinor: 100,
          allocations: const [
            PaymentAllocationInput(chargeId: 1, amountMinor: 60),
            PaymentAllocationInput(chargeId: 2, amountMinor: 50),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
