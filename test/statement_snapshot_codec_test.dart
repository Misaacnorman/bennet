import 'package:flutter_test/flutter_test.dart';

import 'package:bennet/domain/client_accounts.dart';

void main() {
  test('statement line JSON codec round-trip', () {
    const lines = [
      StatementPreviewLine(
        occurredAtMs: 100,
        label: 'A',
        detail: 'd',
        deltaMinor: 50,
        runningBalanceMinor: 150,
      ),
      StatementPreviewLine(
        occurredAtMs: 200,
        label: 'B',
        deltaMinor: -25,
        runningBalanceMinor: 125,
      ),
    ];
    final json = encodeStatementLinesToJson(lines);
    final back = decodeStatementLinesFromJson(json);
    expect(back, hasLength(2));
    expect(back[0].label, 'A');
    expect(back[0].detail, 'd');
    expect(back[1].detail, isNull);
    expect(back[1].runningBalanceMinor, 125);
  });
}
