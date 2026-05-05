import 'package:bennet/core/client_account_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runningBalanceAfterLine', () {
    test('empty deltas keeps opening', () {
      expect(
        runningBalanceAfterLine(
          openingMinor: 100,
          orderedDeltasMinor: const [],
          lineIndexInclusive: 0,
        ),
        100,
      );
    });

    test('sums through inclusive index', () {
      expect(
        runningBalanceAfterLine(
          openingMinor: 50,
          orderedDeltasMinor: const [10, -30, 5],
          lineIndexInclusive: 1,
        ),
        30,
      );
    });

    test('index beyond last uses all deltas', () {
      expect(
        runningBalanceAfterLine(
          openingMinor: 0,
          orderedDeltasMinor: const [100, -40],
          lineIndexInclusive: 99,
        ),
        60,
      );
    });
  });

  group('closingFromOpeningAndDeltas', () {
    test('matches fold of deltas', () {
      expect(
        closingFromOpeningAndDeltas(
          openingMinor: 200,
          orderedDeltasMinor: const [-50, 120, -30],
        ),
        240,
      );
    });
  });
}
