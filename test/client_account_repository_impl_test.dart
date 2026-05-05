import 'dart:io';

import 'package:bennet/data/client_account_repository_impl.dart';
import 'package:bennet/data/database/sqlite_db.dart';
import 'package:bennet/data/ledger_repository_impl.dart';
import 'package:bennet/domain/client_accounts.dart';
import 'package:bennet/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  group('ClientAccountRepositoryImpl (SQLite)', () {
    late Database db;
    late ClientAccountRepositoryImpl repo;

    setUp(() async {
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (d, version) async {
            await createBennetDatabaseSchemaV3(d);
          },
        ),
      );
      final ledger = LedgerRepositoryImpl(db);
      repo = ClientAccountRepositoryImpl(db, ledger);
    });

    tearDown(() async {
      await db.close();
    });

    test('recordPayment with no allocations stores full unallocated', () async {
      final cid = await repo.createClient(
        const CreateClientInput(displayName: 'Acme', clientCode: 'ACM'),
      );
      final pid = await repo.recordPayment(
        RecordPaymentInput(
          clientId: cid,
          amountMinor: 2000,
          receivedAt: DateTime.utc(2026, 3, 1),
          method: PaymentMethod.cash,
          accountId: 1,
          categoryId: 1,
          syncLedgerIncome: false,
        ),
      );
      final p = await repo.getPayment(pid);
      expect(p, isNotNull);
      expect(p!.unallocatedMinor, 2000);
      final allocs = await repo.listAllocationsForPayment(pid);
      expect(allocs, isEmpty);
    });

    test('recordPayment rejects allocations exceeding payment', () async {
      final cid = await repo.createClient(
        const CreateClientInput(displayName: 'Beta', clientCode: 'BTA'),
      );
      final chg = await repo.createCharge(
        CreateChargeInput(
          clientId: cid,
          amountMinor: 10_000,
          issuedAt: DateTime.utc(2026, 3, 5),
        ),
      );
      expect(
        () => repo.recordPayment(
          RecordPaymentInput(
            clientId: cid,
            amountMinor: 1000,
            receivedAt: DateTime.utc(2026, 3, 6),
            method: PaymentMethod.cash,
            accountId: 1,
            categoryId: 1,
            allocations: [
              PaymentAllocationInput(chargeId: chg, amountMinor: 600),
              PaymentAllocationInput(chargeId: chg, amountMinor: 500),
            ],
            syncLedgerIncome: false,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('recordPayment persists allocations and unallocated remainder', () async {
      final cid = await repo.createClient(
        const CreateClientInput(displayName: 'Gamma', clientCode: 'GAM'),
      );
      final chg = await repo.createCharge(
        CreateChargeInput(
          clientId: cid,
          amountMinor: 10_000,
          issuedAt: DateTime.utc(2026, 4, 1),
        ),
      );
      final pid = await repo.recordPayment(
        RecordPaymentInput(
          clientId: cid,
          amountMinor: 4000,
          receivedAt: DateTime.utc(2026, 4, 10),
          method: PaymentMethod.bankTransfer,
          accountId: 1,
          categoryId: 1,
          allocations: [
            PaymentAllocationInput(chargeId: chg, amountMinor: 2500),
          ],
          syncLedgerIncome: false,
        ),
      );
      final p = await repo.getPayment(pid);
      expect(p!.unallocatedMinor, 1500);
      final allocs = await repo.listAllocationsForPayment(pid);
      expect(allocs, hasLength(1));
      expect(allocs.single.amountMinor, 2500);
      expect(allocs.single.chargeId, chg);

      final open = await repo.listChargesWithOpenAmount(cid);
      expect(open, hasLength(1));
      expect(open.single.openMinor, 7500);
    });

    test('clientSummary balance matches charges minus payments plus adjustments',
        () async {
      final cid = await repo.createClient(
        const CreateClientInput(displayName: 'Delta', clientCode: 'DLT'),
      );
      await repo.createCharge(
        CreateChargeInput(
          clientId: cid,
          amountMinor: 8000,
          issuedAt: DateTime.utc(2026, 5, 1),
        ),
      );
      await repo.recordPayment(
        RecordPaymentInput(
          clientId: cid,
          amountMinor: 3000,
          receivedAt: DateTime.utc(2026, 5, 2),
          method: PaymentMethod.cash,
          accountId: 1,
          categoryId: 1,
          syncLedgerIncome: false,
        ),
      );
      await repo.createAdjustment(
        CreateClientAdjustmentInput(
          clientId: cid,
          kind: AdjustmentKind.increase,
          amountMinor: 500,
          effectiveAt: DateTime.utc(2026, 5, 3),
          reason: 'fee',
        ),
      );

      final s = await repo.clientSummary(cid);
      expect(s.balanceMinor, 8000 - 3000 + 500);
      expect(s.outstandingChargesMinor, 8000);
    });

    test('reversed payment excluded from balance', () async {
      final cid = await repo.createClient(
        const CreateClientInput(displayName: 'Epsilon', clientCode: 'EPS'),
      );
      await repo.createCharge(
        CreateChargeInput(
          clientId: cid,
          amountMinor: 6000,
          issuedAt: DateTime.utc(2026, 6, 1),
        ),
      );
      final pid = await repo.recordPayment(
        RecordPaymentInput(
          clientId: cid,
          amountMinor: 6000,
          receivedAt: DateTime.utc(2026, 6, 2),
          method: PaymentMethod.cash,
          accountId: 1,
          categoryId: 1,
          syncLedgerIncome: false,
        ),
      );
      expect((await repo.clientSummary(cid)).balanceMinor, 0);

      await repo.reversePayment(pid, 'test reversal');
      expect((await repo.clientSummary(cid)).balanceMinor, 6000);
    });

    test('statement preview running balance and closing', () async {
      final cid = await repo.createClient(
        const CreateClientInput(displayName: 'Zeta', clientCode: 'ZTA'),
      );
      await repo.createCharge(
        CreateChargeInput(
          clientId: cid,
          amountMinor: 5000,
          issuedAt: DateTime(2026, 6, 10),
        ),
      );
      await repo.recordPayment(
        RecordPaymentInput(
          clientId: cid,
          amountMinor: 2000,
          receivedAt: DateTime(2026, 6, 20),
          method: PaymentMethod.cash,
          accountId: 1,
          categoryId: 1,
          syncLedgerIncome: false,
        ),
      );

      final preview = await repo.buildStatementPreview(
        BuildStatementInput(
          clientId: cid,
          fromDate: DateTime(2026, 6, 1),
          toDate: DateTime(2026, 6, 30),
        ),
      );

      expect(preview.openingBalanceMinor, 0);
      expect(preview.lines, hasLength(2));
      expect(preview.lines[0].deltaMinor, 5000);
      expect(preview.lines[0].runningBalanceMinor, 5000);
      expect(preview.lines[1].deltaMinor, -2000);
      expect(preview.lines[1].runningBalanceMinor, 3000);
      expect(preview.closingBalanceMinor, 3000);
    });

    test('recordPayment creates ledger income when syncLedgerIncome', () async {
      final cid = await repo.createClient(
        const CreateClientInput(displayName: 'Eta', clientCode: 'ETA'),
      );
      final ledger = LedgerRepositoryImpl(db);
      final book = await ledger.defaultBook();

      await repo.recordPayment(
        RecordPaymentInput(
          clientId: cid,
          amountMinor: 1200,
          receivedAt: DateTime.utc(2026, 7, 1),
          method: PaymentMethod.card,
          accountId: 1,
          categoryId: 1,
          syncLedgerIncome: true,
          notes: 'integration test',
        ),
      );

      final txs = await ledger.listTransactions(bookId: book.id);
      final income = txs.where((t) => t.type == TxType.income).toList();
      expect(income, isNotEmpty);
      expect(income.any((t) => t.amountMinor == 1200), isTrue);
    });
  });
}
