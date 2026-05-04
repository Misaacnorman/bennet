import 'package:test/test.dart';

import 'package:bennet/core/period_math.dart';
import 'package:bennet/domain/entities.dart';

void main() {
  final sample = [
    LedgerTransaction(
      id: 1,
      bookId: 1,
      accountId: 1,
      categoryId: 1,
      type: TxType.income,
      amountMinor: 10000,
      occurredAt: DateTime(2026, 5, 3),
    ),
    LedgerTransaction(
      id: 2,
      bookId: 1,
      accountId: 1,
      categoryId: 2,
      type: TxType.expense,
      amountMinor: 2500,
      occurredAt: DateTime(2026, 5, 10),
    ),
    LedgerTransaction(
      id: 3,
      bookId: 1,
      accountId: 1,
      categoryId: 1,
      type: TxType.income,
      amountMinor: 500,
      occurredAt: DateTime(2026, 4, 1),
    ),
  ];

  test('totalsForMonth filters by calendar month', () {
    final m = totalsForMonth(sample, 2026, 5);
    expect(m.incomeMinor, 10000);
    expect(m.expenseMinor, 2500);
    expect(m.netMinor, 7500);
  });

  test('closingBalanceForMonth', () {
    final c = closingBalanceForMonth(
      openingMinor: 1000,
      transactions: sample,
      year: 2026,
      month: 5,
    );
    expect(c, 1000 + 7500);
  });

  test('runningBalances matches sequential cash book', () {
    final mayOnly = sample.where((t) => t.occurredAt.month == 5).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final runs = runningBalances(openingMinor: 0, sortedAscending: mayOnly);
    expect(runs.length, 2);
    expect(runs[0], 10000);
    expect(runs[1], 7500);
  });

  test('lifetimeNetCashMovement', () {
    expect(lifetimeNetCashMovement(sample), 10000 - 2500 + 500);
  });
}
