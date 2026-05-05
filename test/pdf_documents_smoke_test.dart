import 'package:bennet/domain/client_accounts.dart';
import 'package:bennet/services/receipt_pdf_service.dart';
import 'package:bennet/services/statement_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final epoch = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;

  final client = Client(
    id: 1,
    bookId: 1,
    clientCode: 'TST',
    displayName: 'Test Client ${'x' * 80}',
    status: ClientStatus.active,
    createdAtMs: epoch,
    updatedAtMs: epoch,
  );

  test('buildStatementPdf produces non-empty PDF bytes', () async {
    final lines = <StatementPreviewLine>[
      for (var i = 0; i < 35; i++)
        StatementPreviewLine(
          occurredAtMs: DateTime.utc(2026, 6, i + 1).millisecondsSinceEpoch,
          label: 'Charge',
          detail: 'Line $i ${'n' * 40}',
          deltaMinor: 100,
          runningBalanceMinor: 100 * (i + 1),
        ),
    ];
    final preview = StatementPreview(
      client: client,
      fromDateMs: DateTime.utc(2026, 6, 1).millisecondsSinceEpoch,
      toDateMs: DateTime.utc(2026, 6, 30).millisecondsSinceEpoch,
      openingBalanceMinor: 0,
      lines: lines,
      closingBalanceMinor: lines.last.runningBalanceMinor,
    );
    final bytes = await buildStatementPdf(
      preview: preview,
      businessName: 'Snapshot Business Name',
      statementNumber: 7,
      issuedAt: DateTime.utc(2026, 7, 2),
    );
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('buildClientPaymentReceiptPdf handles allocations and reversal', () async {
    final doc = ReceiptDocument(
      paymentId: 1,
      receiptNumber: 12,
      issuedAtMs: DateTime.utc(2026, 5, 5).millisecondsSinceEpoch,
      clientId: 1,
      clientDisplayName: 'Paying Client ${'y' * 60}',
      clientCode: 'PC',
      amountMinor: 10_000,
      method: PaymentMethod.bankTransfer,
      businessName: 'Biz',
      allocations: [
        (chargeId: 3, amountMinor: 2500),
        (chargeId: 4, amountMinor: 500),
      ],
      paymentReversed: true,
    );
    final bytes = await buildClientPaymentReceiptPdf(receipt: doc);
    expect(bytes.length, greaterThan(400));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
