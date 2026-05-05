import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database/sqlite_db.dart';
import '../core/payment_allocation_math.dart';
import '../domain/client_accounts.dart';
import '../domain/client_account_repository.dart';
import '../domain/entities.dart';
import '../domain/ledger_repository.dart';

/// SQLite implementation of [ClientAccountRepository] (local book mirror).
class ClientAccountRepositoryImpl implements ClientAccountRepository {
  ClientAccountRepositoryImpl(this._db, this._ledger);

  final Database _db;
  final LedgerRepository _ledger;

  static Future<ClientAccountRepositoryImpl> open(
    LedgerRepository ledger,
  ) async {
    final db = await openBennetDatabase();
    return ClientAccountRepositoryImpl(db, ledger);
  }

  Future<int> _bookId() async {
    final rows = await _db.query('books', limit: 1, orderBy: 'id ASC');
    return rows.first['id'] as int;
  }

  Client _clientFromRow(Map<String, Object?> r) {
    final openingAt = r['opening_balance_at'] as int?;
    return Client(
      id: r['id'] as int,
      bookId: r['book_id'] as int,
      clientCode: r['client_code'] as String,
      displayName: r['display_name'] as String,
      legalName: r['legal_name'] as String?,
      status: ClientStatusWire.parse(r['status'] as String),
      primaryEmail: r['primary_email'] as String?,
      primaryPhone: r['primary_phone'] as String?,
      notes: r['notes'] as String?,
      openingBalanceMinor: r['opening_balance_minor'] as int? ?? 0,
      openingBalanceDate: openingAt != null
          ? DateTime.fromMillisecondsSinceEpoch(openingAt, isUtc: true)
          : null,
      defaultCategoryId: r['default_category_id'] as int?,
      defaultAccountId: r['default_account_id'] as int?,
      createdAtMs: r['created_at'] as int,
      updatedAtMs: r['updated_at'] as int,
      archivedAtMs: r['archived_at'] as int?,
    );
  }

  ClientCharge _chargeFromRow(Map<String, Object?> r) => ClientCharge(
    id: r['id'] as int,
    clientId: r['client_id'] as int,
    amountMinor: r['amount_minor'] as int,
    status: ChargeStatusWire.parse(r['status'] as String),
    issuedAtMs: r['issued_at'] as int,
    dueDateMs: r['due_date'] as int?,
    description: r['description'] as String?,
    voidReason: r['void_reason'] as String?,
  );

  ClientPayment _paymentFromRow(Map<String, Object?> r) => ClientPayment(
    id: r['id'] as int,
    clientId: r['client_id'] as int,
    amountMinor: r['amount_minor'] as int,
    unallocatedMinor: r['unallocated_minor'] as int? ?? 0,
    status: PaymentStatusWire.parse(r['status'] as String),
    method: PaymentMethodWire.parse(r['method'] as String),
    receivedAtMs: r['received_at'] as int,
    accountId: r['account_id'] as int,
    categoryId: r['category_id'] as int,
    reference: r['reference'] as String?,
    notes: r['notes'] as String?,
    receiptNumber: r['receipt_number'] as int?,
    ledgerTransactionId: r['ledger_transaction_id'] as int?,
    reversalReason: r['reversal_reason'] as String?,
    createdAtMs: r['created_at'] as int?,
  );

  PaymentAllocation _allocFromRow(Map<String, Object?> r) => PaymentAllocation(
    id: r['id'] as int,
    paymentId: r['payment_id'] as int,
    chargeId: r['charge_id'] as int,
    amountMinor: r['amount_minor'] as int,
  );

  ClientAdjustment _adjFromRow(Map<String, Object?> r) => ClientAdjustment(
    id: r['id'] as int,
    clientId: r['client_id'] as int,
    kind: AdjustmentKindWire.parse(r['kind'] as String),
    amountMinor: r['amount_minor'] as int,
    effectiveAtMs: r['effective_at'] as int,
    reason: r['reason'] as String?,
  );

  ClientStatement _stmtFromRow(Map<String, Object?> r) => ClientStatement(
    id: r['id'] as int,
    clientId: r['client_id'] as int,
    fromDateMs: r['from_date'] as int,
    toDateMs: r['to_date'] as int,
    openingBalanceMinor: r['opening_balance_minor'] as int,
    closingBalanceMinor: r['closing_balance_minor'] as int,
    issuedAtMs: r['issued_at'] as int,
    statementNumber: r['statement_number'] as int,
  );

  @override
  Future<List<Client>> listClients({
    ClientStatus? status,
    String? query,
  }) async {
    final bid = await _bookId();
    final where = <String>['book_id = ?'];
    final args = <Object?>[bid];
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    final rows = await _db.query(
      'clients',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'display_name COLLATE NOCASE',
    );
    var list = rows.map(_clientFromRow).toList();
    final qTrim = query?.trim().toLowerCase();
    if (qTrim != null && qTrim.isNotEmpty) {
      list = list.where((c) => c.matchesClientDirectoryQuery(qTrim)).toList();
    }
    return list;
  }

  @override
  Future<Client?> getClient(int id) async {
    final rows = await _db.query('clients', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _clientFromRow(rows.first);
  }

  @override
  Future<int> createClient(CreateClientInput input) async {
    final bid = await _bookId();
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.insert('clients', {
      'book_id': bid,
      'client_code': input.clientCode.trim(),
      'display_name': input.displayName.trim(),
      'legal_name': input.legalName?.trim(),
      'status': ClientStatus.active.name,
      'primary_email': input.primaryEmail?.trim(),
      'primary_phone': input.primaryPhone?.trim(),
      'notes': input.notes?.trim(),
      'opening_balance_minor': input.openingBalanceMinor,
      'opening_balance_at': input.openingBalanceDate?.millisecondsSinceEpoch,
      'default_category_id': input.defaultCategoryId,
      'default_account_id': input.defaultAccountId,
      'created_at': now,
      'updated_at': now,
    });
  }

  @override
  Future<void> updateClient(UpdateClientInput input) async {
    final existing = await getClient(input.id);
    if (existing == null) throw StateError('Client not found');
    final data = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (input.displayName != null) {
      data['display_name'] = input.displayName!.trim();
    }
    if (input.legalName != null) data['legal_name'] = input.legalName!.trim();
    if (input.clientCode != null) {
      data['client_code'] = input.clientCode!.trim();
    }
    if (input.status != null) data['status'] = input.status!.name;
    if (input.primaryEmail != null) {
      data['primary_email'] = input.primaryEmail!.trim();
    }
    if (input.primaryPhone != null) {
      data['primary_phone'] = input.primaryPhone!.trim();
    }
    if (input.notes != null) data['notes'] = input.notes!.trim();
    if (input.openingBalanceMinor != null) {
      data['opening_balance_minor'] = input.openingBalanceMinor;
    }
    if (input.openingBalanceDate != null) {
      data['opening_balance_at'] =
          input.openingBalanceDate!.millisecondsSinceEpoch;
    }
    if (input.defaultCategoryId != null) {
      data['default_category_id'] = input.defaultCategoryId;
    }
    if (input.defaultAccountId != null) {
      data['default_account_id'] = input.defaultAccountId;
    }
    await _db.update('clients', data, where: 'id = ?', whereArgs: [input.id]);
  }

  @override
  Future<void> archiveClient(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'clients',
      {
        'status': ClientStatus.archived.name,
        'archived_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ClientCharge>> _chargesForClient(int clientId) async {
    final rows = await _db.query(
      'client_charges',
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
    return rows.map(_chargeFromRow).toList();
  }

  Future<List<ClientPayment>> _paymentsForClient(int clientId) async {
    final rows = await _db.query(
      'client_payments',
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
    return rows.map(_paymentFromRow).toList();
  }

  Future<List<ClientAdjustment>> _adjustmentsForClient(int clientId) async {
    final rows = await _db.query(
      'client_adjustments',
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
    return rows.map(_adjFromRow).toList();
  }

  Future<Map<int, int>> _allocationsByCharge(int clientId) async {
    final rows = await _db.query(
      'payment_allocations',
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
    final map = <int, int>{};
    for (final r in rows) {
      final a = _allocFromRow(r);
      map[a.chargeId] = (map[a.chargeId] ?? 0) + a.amountMinor;
    }
    return map;
  }

  int _openAmount(ClientCharge c, int allocated) {
    if (c.status == ChargeStatus.voided) return 0;
    final raw = c.amountMinor - allocated;
    return raw > 0 ? raw : 0;
  }

  @override
  Future<ClientAccountSummary> clientSummary(int clientId) async {
    final results = await Future.wait<Object?>([
      getClient(clientId),
      _chargesForClient(clientId),
      _paymentsForClient(clientId),
      _adjustmentsForClient(clientId),
      _allocationsByCharge(clientId),
    ]);

    final client = results[0] as Client?;
    if (client == null) throw StateError('Client not found');
    final charges = results[1] as List<ClientCharge>;
    final payments = results[2] as List<ClientPayment>;
    final adjustments = results[3] as List<ClientAdjustment>;
    final allocByCharge = results[4] as Map<int, int>;

    return _summaryFromData(
      client: client,
      charges: charges,
      payments: payments,
      adjustments: adjustments,
      allocByCharge: allocByCharge,
    );
  }

  @override
  Future<List<ClientAccountSummary>> listClientSummaries({
    ClientStatus? status,
    String? query,
  }) async {
    final clients = await listClients(status: status, query: query);
    if (clients.isEmpty) return const [];

    final selectedIds = clients.map((c) => c.id).toSet();
    final results = await Future.wait<List<Map<String, Object?>>>([
      _db.query('client_charges'),
      _db.query('client_payments'),
      _db.query('client_adjustments'),
      _db.query('payment_allocations'),
    ]);

    final chargesByClient = <int, List<ClientCharge>>{};
    for (final r in results[0]) {
      final clientId = r['client_id'] as int;
      if (!selectedIds.contains(clientId)) continue;
      (chargesByClient[clientId] ??= []).add(_chargeFromRow(r));
    }

    final paymentsByClient = <int, List<ClientPayment>>{};
    for (final r in results[1]) {
      final clientId = r['client_id'] as int;
      if (!selectedIds.contains(clientId)) continue;
      (paymentsByClient[clientId] ??= []).add(_paymentFromRow(r));
    }

    final adjustmentsByClient = <int, List<ClientAdjustment>>{};
    for (final r in results[2]) {
      final clientId = r['client_id'] as int;
      if (!selectedIds.contains(clientId)) continue;
      (adjustmentsByClient[clientId] ??= []).add(_adjFromRow(r));
    }

    final allocationsByClient = <int, Map<int, int>>{};
    for (final r in results[3]) {
      final clientId = r['client_id'] as int;
      if (!selectedIds.contains(clientId)) continue;
      final allocation = _allocFromRow(r);
      final allocByCharge = allocationsByClient[clientId] ??= {};
      allocByCharge[allocation.chargeId] =
          (allocByCharge[allocation.chargeId] ?? 0) + allocation.amountMinor;
    }

    return [
      for (final client in clients)
        _summaryFromData(
          client: client,
          charges: chargesByClient[client.id] ?? const [],
          payments: paymentsByClient[client.id] ?? const [],
          adjustments: adjustmentsByClient[client.id] ?? const [],
          allocByCharge: allocationsByClient[client.id] ?? const {},
        ),
    ];
  }

  ClientAccountSummary _summaryFromData({
    required Client client,
    required List<ClientCharge> charges,
    required List<ClientPayment> payments,
    required List<ClientAdjustment> adjustments,
    required Map<int, int> allocByCharge,
  }) {
    var chargeTotal = 0;
    var outstanding = 0;
    var openCount = 0;
    var overdue = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final c in charges) {
      if (c.status == ChargeStatus.voided) continue;
      chargeTotal += c.amountMinor;
      final alloc = allocByCharge[c.id] ?? 0;
      final open = _openAmount(c, alloc);
      outstanding += open;
      if (open > 0) {
        openCount++;
        final due = c.dueDate;
        if (due != null && due.isBefore(today)) overdue++;
      }
    }

    var paymentTotal = 0;
    for (final p in payments) {
      if (p.status == PaymentStatus.reversed) continue;
      paymentTotal += p.amountMinor;
    }

    var adjEffect = 0;
    for (final a in adjustments) {
      adjEffect += a.kind == AdjustmentKind.increase
          ? a.amountMinor
          : -a.amountMinor;
    }

    final balance =
        client.openingBalanceMinor + chargeTotal - paymentTotal + adjEffect;

    return ClientAccountSummary(
      client: client,
      balanceMinor: balance,
      outstandingChargesMinor: outstanding,
      openChargeCount: openCount,
      overdueOpenChargeCount: overdue,
    );
  }

  bool _inRange(DateTime at, DateTime? from, DateTime? to) {
    final ad = DateTime(at.year, at.month, at.day);
    if (from != null) {
      final fd = DateTime(from.year, from.month, from.day);
      if (ad.isBefore(fd)) return false;
    }
    if (to != null) {
      final td = DateTime(to.year, to.month, to.day);
      if (ad.isAfter(td)) return false;
    }
    return true;
  }

  @override
  Future<List<ClientLedgerLine>> clientLedger(
    int clientId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final results = await Future.wait<Object?>([
      getClient(clientId),
      _chargesForClient(clientId),
      _paymentsForClient(clientId),
      _adjustmentsForClient(clientId),
    ]);

    final client = results[0] as Client?;
    if (client == null) throw StateError('Client not found');
    final charges = results[1] as List<ClientCharge>;
    final payments = results[2] as List<ClientPayment>;
    final adjustments = results[3] as List<ClientAdjustment>;

    final rows = <_LedRow>[];

    rows.add(
      _LedRow(
        client.openingBalanceDate ?? client.createdAt,
        ClientLedgerEntryKind.opening,
        'Opening balance',
        null,
        client.openingBalanceMinor,
      ),
    );

    for (final c in charges) {
      if (c.status == ChargeStatus.voided) continue;
      rows.add(
        _LedRow(
          c.issuedAt,
          ClientLedgerEntryKind.charge,
          'Charge',
          c.description,
          c.amountMinor,
          refId: c.id,
        ),
      );
    }
    for (final p in payments) {
      if (p.status == PaymentStatus.reversed) continue;
      rows.add(
        _LedRow(
          p.receivedAt,
          ClientLedgerEntryKind.payment,
          'Payment',
          p.reference,
          -p.amountMinor,
          refId: p.id,
        ),
      );
    }
    for (final a in adjustments) {
      final d = a.kind == AdjustmentKind.increase
          ? a.amountMinor
          : -a.amountMinor;
      rows.add(
        _LedRow(
          a.effectiveAt,
          ClientLedgerEntryKind.adjustment,
          'Adjustment',
          a.reason,
          d,
          refId: a.id,
        ),
      );
    }

    rows.sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.kind.index.compareTo(b.kind.index);
    });

    var balance = 0;
    final out = <ClientLedgerLine>[];
    for (final r in rows) {
      balance += r.delta;
      if (!_inRange(r.at, from, to)) continue;
      out.add(
        ClientLedgerLine(
          sortAtMs: r.at.toUtc().millisecondsSinceEpoch,
          kind: r.kind,
          title: r.title,
          subtitle: r.subtitle,
          deltaMinor: r.delta,
          balanceAfterMinor: balance,
          refId: r.refId,
        ),
      );
    }
    return out;
  }

  @override
  Future<List<ClientCharge>> listCharges({
    int? clientId,
    ChargeStatus? status,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (clientId != null) {
      where.add('client_id = ?');
      args.add(clientId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    final rows = await _db.query(
      'client_charges',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'issued_at DESC, id DESC',
    );
    return rows.map(_chargeFromRow).toList();
  }

  @override
  Future<ClientCharge?> getCharge(int id) async {
    final rows = await _db.query(
      'client_charges',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _chargeFromRow(rows.first);
  }

  @override
  Future<int> createCharge(CreateChargeInput input) async {
    final client = await getClient(input.clientId);
    if (client == null) throw StateError('Client not found');
    if (input.amountMinor <= 0) throw ArgumentError('amount');
    final due = input.dueDate;
    if (due != null && due.isBefore(input.issuedAt)) {
      throw ArgumentError('dueDate');
    }
    return _db.insert('client_charges', {
      'client_id': input.clientId,
      'amount_minor': input.amountMinor,
      'status': ChargeStatus.open.name,
      'issued_at': input.issuedAt.millisecondsSinceEpoch,
      'due_date': due?.millisecondsSinceEpoch,
      'description': input.description?.trim(),
    });
  }

  @override
  Future<void> voidCharge(int chargeId, String reason) async {
    await _db.update(
      'client_charges',
      {'status': ChargeStatus.voided.name, 'void_reason': reason.trim()},
      where: 'id = ?',
      whereArgs: [chargeId],
    );
  }

  @override
  Future<int> createAdjustment(CreateClientAdjustmentInput input) async {
    if (input.amountMinor <= 0) throw ArgumentError('amount');
    final client = await getClient(input.clientId);
    if (client == null) throw StateError('Client not found');
    return _db.insert('client_adjustments', {
      'client_id': input.clientId,
      'kind': input.kind.name,
      'amount_minor': input.amountMinor,
      'effective_at': input.effectiveAt.millisecondsSinceEpoch,
      'reason': input.reason?.trim(),
    });
  }

  @override
  Future<List<ClientAdjustment>> listAdjustments(int clientId) async {
    final rows = await _db.query(
      'client_adjustments',
      where: 'client_id = ?',
      whereArgs: [clientId],
      orderBy: 'effective_at ASC, id ASC',
    );
    return rows.map(_adjFromRow).toList();
  }

  @override
  Future<List<({ClientCharge charge, int openMinor})>>
  listChargesWithOpenAmount(int clientId) async {
    final results = await Future.wait<Object>([
      _chargesForClient(clientId),
      _allocationsByCharge(clientId),
    ]);
    final charges = results[0] as List<ClientCharge>;
    final allocByCharge = results[1] as Map<int, int>;
    final out = <({ClientCharge charge, int openMinor})>[];
    for (final c in charges) {
      if (c.status == ChargeStatus.voided) continue;
      final open = _openAmount(c, allocByCharge[c.id] ?? 0);
      if (open > 0) out.add((charge: c, openMinor: open));
    }
    out.sort((a, b) => a.charge.issuedAt.compareTo(b.charge.issuedAt));
    return out;
  }

  @override
  Future<List<ClientPayment>> listPayments({
    int? clientId,
    PaymentStatus? status,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (clientId != null) {
      where.add('client_id = ?');
      args.add(clientId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status.name);
    }
    final rows = await _db.query(
      'client_payments',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'received_at DESC, id DESC',
    );
    return rows.map(_paymentFromRow).toList();
  }

  @override
  Future<ClientPayment?> getPayment(int id) async {
    final rows = await _db.query(
      'client_payments',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _paymentFromRow(rows.first);
  }

  @override
  Future<List<PaymentAllocation>> listAllocationsForPayment(
    int paymentId,
  ) async {
    final rows = await _db.query(
      'payment_allocations',
      where: 'payment_id = ?',
      whereArgs: [paymentId],
    );
    return rows.map(_allocFromRow).toList();
  }

  Future<int> _nextReceiptNumber(Transaction txn) async {
    final rows = await txn.rawQuery(
      'SELECT MAX(receipt_number) as m FROM client_payments',
    );
    final m = rows.first['m'] as int?;
    return (m ?? 0) + 1;
  }

  @override
  Future<int> recordPayment(RecordPaymentInput input) async {
    if (input.amountMinor <= 0) throw ArgumentError('amount');
    final client = await getClient(input.clientId);
    if (client == null) throw StateError('Client not found');

    final allocTotals = summarizePaymentAllocations(
      paymentAmountMinor: input.amountMinor,
      allocations: input.allocations,
    );
    final unallocated = allocTotals.unallocatedMinor;

    int? ledgerTxId;
    if (input.syncLedgerIncome) {
      final book = await _ledger.defaultBook();
      ledgerTxId = await _ledger.insertTransaction(
        bookId: book.id,
        accountId: input.accountId,
        categoryId: input.categoryId,
        type: TxType.income,
        amountMinor: input.amountMinor,
        occurredAt: input.receivedAt,
        notes: input.notes,
        paymentMethod: input.method.name,
        counterparty: client.displayName,
      );
    }

    try {
      final pid = await _db.transaction<int>((txn) async {
        final rn = await _nextReceiptNumber(txn);
        final paymentId = await txn.insert('client_payments', {
          'client_id': input.clientId,
          'amount_minor': input.amountMinor,
          'unallocated_minor': unallocated,
          'status': PaymentStatus.posted.name,
          'method': input.method.name,
          'received_at': input.receivedAt.millisecondsSinceEpoch,
          'account_id': input.accountId,
          'category_id': input.categoryId,
          'reference': input.reference?.trim(),
          'notes': input.notes?.trim(),
          'receipt_number': rn,
          'ledger_transaction_id': ledgerTxId,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
        for (final a in input.allocations) {
          await txn.insert('payment_allocations', {
            'payment_id': paymentId,
            'charge_id': a.chargeId,
            'amount_minor': a.amountMinor,
            'client_id': input.clientId,
          });
        }
        return paymentId;
      });
      final savedResults = await Future.wait<Object?>([
        getPayment(pid),
        listAllocationsForPayment(pid),
      ]);
      final saved = savedResults[0] as ClientPayment?;
      final allocsSaved = savedResults[1] as List<PaymentAllocation>;
      if (saved != null) {
        await _insertReceiptSnapshot(
          paymentId: pid,
          client: client,
          payment: saved,
          allocations: allocsSaved,
        );
      }
      return pid;
    } catch (e) {
      if (ledgerTxId != null) await _ledger.deleteTransaction(ledgerTxId);
      rethrow;
    }
  }

  @override
  Future<void> reversePayment(int paymentId, String reason) async {
    final p = await getPayment(paymentId);
    if (p == null) throw StateError('Payment not found');
    if (p.status == PaymentStatus.reversed) return;

    await _db.update(
      'client_payments',
      {'status': PaymentStatus.reversed.name, 'reversal_reason': reason.trim()},
      where: 'id = ?',
      whereArgs: [paymentId],
    );

    await _db.update(
      'client_receipts',
      {'payment_reversed': 1},
      where: 'payment_id = ?',
      whereArgs: [paymentId],
    );

    final ledgerId = p.ledgerTransactionId;
    if (ledgerId != null) {
      final tx = await _ledger.getTransaction(ledgerId);
      if (tx != null) {
        await _ledger.insertTransaction(
          bookId: tx.bookId,
          accountId: tx.accountId,
          categoryId: tx.categoryId,
          type: TxType.expense,
          amountMinor: tx.amountMinor,
          occurredAt: DateTime.now(),
          notes: 'Reversal: payment #$paymentId',
          paymentMethod: tx.paymentMethod,
          counterparty: tx.counterparty,
        );
      }
    }
  }

  @override
  Future<ReceiptDocument> receiptForPayment(int paymentId) async {
    final rRows = await _db.query(
      'client_receipts',
      where: 'payment_id = ?',
      whereArgs: [paymentId],
    );
    if (rRows.isNotEmpty) {
      return _receiptDocumentFromSql(rRows.first);
    }

    final p = await getPayment(paymentId);
    if (p == null) throw StateError('Payment not found');
    final results = await Future.wait<Object?>([
      getClient(p.clientId),
      listAllocationsForPayment(paymentId),
      _ledger.getSetting('business_name'),
    ]);
    final client = results[0] as Client?;
    if (client == null) throw StateError('Client not found');
    final allocs = results[1] as List<PaymentAllocation>;
    final bn = results[2] as String?;
    final rn = p.receiptNumber ?? paymentId;
    return ReceiptDocument(
      paymentId: paymentId,
      receiptNumber: rn,
      issuedAtMs: p.receivedAt.toUtc().millisecondsSinceEpoch,
      clientId: client.id,
      clientDisplayName: client.displayName,
      clientCode: client.clientCode,
      amountMinor: p.amountMinor,
      method: p.method,
      businessName: bn,
      reference: p.reference,
      notes: p.notes,
      allocations: [
        for (final a in allocs)
          (chargeId: a.chargeId, amountMinor: a.amountMinor),
      ],
      paymentReversed: p.status == PaymentStatus.reversed,
    );
  }

  int _balanceBeforeStartOfDay({
    required Client client,
    required List<ClientCharge> charges,
    required List<ClientPayment> payments,
    required List<ClientAdjustment> adjustments,
    required DateTime day,
  }) {
    final boundary = DateTime(day.year, day.month, day.day);
    final openD = client.openingBalanceDate ?? client.createdAt;
    final openDay = DateTime(openD.year, openD.month, openD.day);

    var bal = 0;
    if (!boundary.isBefore(openDay)) {
      bal += client.openingBalanceMinor;
    }

    for (final c in charges) {
      if (c.status == ChargeStatus.voided) continue;
      if (c.issuedAt.isBefore(boundary)) bal += c.amountMinor;
    }
    for (final p in payments) {
      if (p.status == PaymentStatus.reversed) continue;
      if (p.receivedAt.isBefore(boundary)) bal -= p.amountMinor;
    }
    for (final a in adjustments) {
      if (a.effectiveAt.isBefore(boundary)) {
        bal += a.kind == AdjustmentKind.increase
            ? a.amountMinor
            : -a.amountMinor;
      }
    }
    return bal;
  }

  @override
  Future<StatementPreview> buildStatementPreview(
    BuildStatementInput input,
  ) async {
    if (input.toDate.isBefore(input.fromDate)) {
      throw ArgumentError('date range');
    }

    final fromMs = input.fromDate.toUtc().millisecondsSinceEpoch;
    final toMs = input.toDate.toUtc().millisecondsSinceEpoch;
    final fromDay = DateTime(
      input.fromDate.year,
      input.fromDate.month,
      input.fromDate.day,
    );
    final toDay = DateTime(
      input.toDate.year,
      input.toDate.month,
      input.toDate.day,
    );

    final results = await Future.wait<Object?>([
      getClient(input.clientId),
      _chargesForClient(input.clientId),
      _paymentsForClient(input.clientId),
      _adjustmentsForClient(input.clientId),
    ]);

    final client = results[0] as Client?;
    if (client == null) throw StateError('Client not found');
    final charges = results[1] as List<ClientCharge>;
    final payments = results[2] as List<ClientPayment>;
    final adjustments = results[3] as List<ClientAdjustment>;
    final opening = _balanceBeforeStartOfDay(
      client: client,
      charges: charges,
      payments: payments,
      adjustments: adjustments,
      day: fromDay,
    );

    final events = <({DateTime at, String label, String? detail, int delta})>[];
    for (final c in charges) {
      if (c.status == ChargeStatus.voided) continue;
      events.add((
        at: c.issuedAt,
        label: 'Charge',
        detail: c.description,
        delta: c.amountMinor,
      ));
    }
    for (final p in payments) {
      if (p.status == PaymentStatus.reversed) continue;
      events.add((
        at: p.receivedAt,
        label: 'Payment',
        detail: p.reference,
        delta: -p.amountMinor,
      ));
    }
    for (final a in adjustments) {
      final d = a.kind == AdjustmentKind.increase
          ? a.amountMinor
          : -a.amountMinor;
      events.add((
        at: a.effectiveAt,
        label: 'Adjustment',
        detail: a.reason,
        delta: d,
      ));
    }
    events.sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.label.compareTo(b.label);
    });

    bool inRange(DateTime at) {
      final ad = DateTime(at.year, at.month, at.day);
      return !ad.isBefore(fromDay) && !ad.isAfter(toDay);
    }

    final lines = <StatementPreviewLine>[];
    var running = opening;
    for (final e in events) {
      if (!inRange(e.at)) continue;
      running += e.delta;
      lines.add(
        StatementPreviewLine(
          occurredAtMs: e.at.toUtc().millisecondsSinceEpoch,
          label: e.label,
          detail: e.detail,
          deltaMinor: e.delta,
          runningBalanceMinor: running,
        ),
      );
    }

    return StatementPreview(
      client: client,
      fromDateMs: fromMs,
      toDateMs: toMs,
      openingBalanceMinor: opening,
      lines: lines,
      closingBalanceMinor: running,
    );
  }

  Future<int> _nextStatementNumber(Transaction txn) async {
    final rows = await txn.rawQuery(
      'SELECT MAX(statement_number) as m FROM client_statements',
    );
    final m = rows.first['m'] as int?;
    return (m ?? 0) + 1;
  }

  @override
  Future<int> saveStatement(BuildStatementInput input) async {
    final preview = await buildStatementPreview(input);
    return _db.transaction<int>((txn) async {
      final sn = await _nextStatementNumber(txn);
      final now = DateTime.now().millisecondsSinceEpoch;
      return txn.insert('client_statements', {
        'client_id': input.clientId,
        'from_date': preview.fromDateMs,
        'to_date': preview.toDateMs,
        'opening_balance_minor': preview.openingBalanceMinor,
        'closing_balance_minor': preview.closingBalanceMinor,
        'issued_at': now,
        'statement_number': sn,
      });
    });
  }

  @override
  Future<List<ClientStatement>> listStatements({int? clientId}) async {
    final where = clientId != null ? 'client_id = ?' : null;
    final args = clientId != null ? [clientId] : null;
    final rows = await _db.query(
      'client_statements',
      where: where,
      whereArgs: args,
      orderBy: 'issued_at DESC, id DESC',
    );
    return rows.map(_stmtFromRow).toList();
  }

  Future<void> _insertReceiptSnapshot({
    required int paymentId,
    required Client client,
    required ClientPayment payment,
    required List<PaymentAllocation> allocations,
  }) async {
    final bn = await _ledger.getSetting('business_name');
    final payload = [
      for (final a in allocations)
        {'chargeId': a.chargeId, 'amountMinor': a.amountMinor},
    ];
    await _db.insert('client_receipts', {
      'payment_id': paymentId,
      'receipt_number': payment.receiptNumber ?? paymentId,
      'issued_at': payment.receivedAt.millisecondsSinceEpoch,
      'client_id': client.id,
      'client_display_name': client.displayName,
      'client_code': client.clientCode,
      'amount_minor': payment.amountMinor,
      'method': payment.method.name,
      'business_name': bn,
      'reference': payment.reference,
      'notes': payment.notes,
      'allocations_json': jsonEncode(payload),
      'payment_reversed': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  ReceiptDocument _receiptDocumentFromSql(Map<String, Object?> r) {
    final paymentId = r['payment_id'] as int;
    final decoded =
        jsonDecode(r['allocations_json'] as String) as List<dynamic>;
    final allocations = <({int chargeId, int amountMinor})>[];
    for (final item in decoded) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        allocations.add((
          chargeId: (m['chargeId'] as num).toInt(),
          amountMinor: (m['amountMinor'] as num).toInt(),
        ));
      }
    }
    return ReceiptDocument(
      paymentId: paymentId,
      receiptNumber: r['receipt_number'] as int,
      issuedAtMs: r['issued_at'] as int,
      clientId: r['client_id'] as int,
      clientDisplayName: r['client_display_name'] as String,
      clientCode: r['client_code'] as String,
      amountMinor: r['amount_minor'] as int,
      method: PaymentMethodWire.parse(r['method'] as String),
      businessName: r['business_name'] as String?,
      reference: r['reference'] as String?,
      notes: r['notes'] as String?,
      allocations: allocations,
      paymentReversed: ((r['payment_reversed'] as num?)?.toInt() ?? 0) != 0,
    );
  }

  @override
  Future<OverviewMetrics> overviewMetrics() async {
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final cutoff = now
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;

    final results = await Future.wait<List<Map<String, Object?>>>([
      _db.rawQuery(
        '''
SELECT
  COUNT(*) AS active_count,
  COALESCE(SUM(opening_balance_minor), 0) AS opening_total
FROM clients
WHERE status = ?
''',
        [ClientStatus.active.name],
      ),
      _db.rawQuery(
        '''
SELECT
  (SELECT COALESCE(SUM(ch.amount_minor), 0)
   FROM client_charges ch
   JOIN clients c ON c.id = ch.client_id
   WHERE c.status = ? AND ch.status != ?) AS charge_total,
  (SELECT COALESCE(SUM(p.amount_minor), 0)
   FROM client_payments p
   JOIN clients c ON c.id = p.client_id
   WHERE c.status = ? AND p.status != ?) AS payment_total,
  (SELECT COALESCE(SUM(
    CASE a.kind
      WHEN 'increase' THEN a.amount_minor
      ELSE -a.amount_minor
    END
   ), 0)
   FROM client_adjustments a
   JOIN clients c ON c.id = a.client_id
   WHERE c.status = ?) AS adjustment_total
''',
        [
          ClientStatus.active.name,
          ChargeStatus.voided.name,
          ClientStatus.active.name,
          PaymentStatus.reversed.name,
          ClientStatus.active.name,
        ],
      ),
      _db.rawQuery(
        '''
WITH alloc AS (
  SELECT charge_id, SUM(amount_minor) AS allocated
  FROM payment_allocations
  GROUP BY charge_id
)
SELECT
  COALESCE(SUM(
    CASE
      WHEN ch.amount_minor - COALESCE(alloc.allocated, 0) > 0
        THEN ch.amount_minor - COALESCE(alloc.allocated, 0)
      ELSE 0
    END
  ), 0) AS open_total,
  COALESCE(SUM(
    CASE
      WHEN ch.due_date IS NOT NULL
        AND ch.due_date < ?
        AND ch.amount_minor - COALESCE(alloc.allocated, 0) > 0
        THEN 1
      ELSE 0
    END
  ), 0) AS overdue_count
FROM client_charges ch
JOIN clients c ON c.id = ch.client_id
LEFT JOIN alloc ON alloc.charge_id = ch.id
WHERE c.status = ?
  AND ch.status != ?
''',
        [todayStart, ClientStatus.active.name, ChargeStatus.voided.name],
      ),
      _db.rawQuery(
        '''
SELECT COALESCE(SUM(amount_minor), 0) AS last30
FROM client_payments
WHERE status = ?
  AND received_at >= ?
''',
        [PaymentStatus.posted.name, cutoff],
      ),
    ]);

    final clientRow = results[0].first;
    final balanceRow = results[1].first;
    final openRow = results[2].first;
    final paymentRow = results[3].first;

    final openingTotal = (clientRow['opening_total'] as num).toInt();
    final chargeTotal = (balanceRow['charge_total'] as num).toInt();
    final paymentTotal = (balanceRow['payment_total'] as num).toInt();
    final adjustmentTotal = (balanceRow['adjustment_total'] as num).toInt();

    return OverviewMetrics(
      totalBalanceMinor:
          openingTotal + chargeTotal - paymentTotal + adjustmentTotal,
      openChargesTotalMinor: (openRow['open_total'] as num).toInt(),
      overdueOpenChargeCount: (openRow['overdue_count'] as num).toInt(),
      postedPaymentsLast30DaysMinor: (paymentRow['last30'] as num).toInt(),
      activeClientCount: (clientRow['active_count'] as num).toInt(),
    );
  }
}

class _LedRow {
  _LedRow(
    this.at,
    this.kind,
    this.title,
    this.subtitle,
    this.delta, {
    this.refId,
  });

  final DateTime at;
  final ClientLedgerEntryKind kind;
  final String title;
  final String? subtitle;
  final int delta;
  final int? refId;
}
