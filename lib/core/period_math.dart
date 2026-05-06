import '../domain/entities.dart';

/// Pure helpers for tests and reporting.

class MonthlyTotals {
  const MonthlyTotals({required this.incomeMinor, required this.expenseMinor});

  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}

MonthlyTotals totalsForMonth(
  Iterable<LedgerTransaction> transactions,
  int year,
  int month,
) {
  var income = 0;
  var expense = 0;
  for (final t in transactions) {
    if (t.occurredAt.year != year || t.occurredAt.month != month) continue;
    if (t.type == TxType.income) {
      income += t.amountMinor;
    } else {
      expense += t.amountMinor;
    }
  }
  return MonthlyTotals(incomeMinor: income, expenseMinor: expense);
}

/// Closing balance for [month] given explicit [openingMinor] for that month.
int closingBalanceForMonth({
  required int openingMinor,
  required Iterable<LedgerTransaction> transactions,
  required int year,
  required int month,
}) {
  final m = totalsForMonth(transactions, year, month);
  return openingMinor + m.netMinor;
}

/// Running balance after each transaction when sorted ascending by [occurredAt], then [id].
List<int> runningBalances({
  required int openingMinor,
  required List<LedgerTransaction> sortedAscending,
}) {
  var bal = openingMinor;
  final out = <int>[];
  for (final t in sortedAscending) {
    if (t.type == TxType.income) {
      bal += t.amountMinor;
    } else {
      bal -= t.amountMinor;
    }
    out.add(bal);
  }
  return out;
}

/// Lifetime book balance from all-time transactions (no opening offset).
int lifetimeNetCashMovement(Iterable<LedgerTransaction> transactions) {
  var income = 0;
  var expense = 0;
  for (final t in transactions) {
    if (t.type == TxType.income) {
      income += t.amountMinor;
    } else {
      expense += t.amountMinor;
    }
  }
  return income - expense;
}
