// Pure helpers for statement-style running totals (tests / reuse).

int runningBalanceAfterLine({
  required int openingMinor,
  required List<int> orderedDeltasMinor,
  required int lineIndexInclusive,
}) {
  var b = openingMinor;
  for (var i = 0; i <= lineIndexInclusive && i < orderedDeltasMinor.length; i++) {
    b += orderedDeltasMinor[i];
  }
  return b;
}

int closingFromOpeningAndDeltas({
  required int openingMinor,
  required List<int> orderedDeltasMinor,
}) {
  var b = openingMinor;
  for (final d in orderedDeltasMinor) {
    b += d;
  }
  return b;
}
