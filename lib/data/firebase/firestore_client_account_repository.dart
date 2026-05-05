import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/payment_allocation_math.dart';
import '../../domain/client_accounts.dart';
import '../../domain/client_account_repository.dart';
import '../../domain/entities.dart';
import '../../domain/ledger_repository.dart';

/// Client-account persistence under `users/{uid}/books/{bookId}/…`.
class FirestoreClientAccountRepository implements ClientAccountRepository {
  FirestoreClientAccountRepository({
    required String uid,
    required LedgerRepository ledger,
    FirebaseFirestore? firestore,
    int defaultBookId = 1,
  }) : _uid = uid,
       _ledger = ledger,
       _db = firestore ?? FirebaseFirestore.instance,
       _defaultBookId = defaultBookId;

  final String _uid;
  final LedgerRepository _ledger;
  final FirebaseFirestore _db;
  final int _defaultBookId;

  DocumentReference<Map<String, dynamic>> get _bookDoc =>
      _db.doc('users/$_uid/books/$_defaultBookId');

  CollectionReference<Map<String, dynamic>> get _clients =>
      _bookDoc.collection('clients');

  CollectionReference<Map<String, dynamic>> get _charges =>
      _bookDoc.collection('clientCharges');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _bookDoc.collection('clientPayments');

  CollectionReference<Map<String, dynamic>> get _allocations =>
      _bookDoc.collection('paymentAllocations');

  CollectionReference<Map<String, dynamic>> get _adjustments =>
      _bookDoc.collection('clientAdjustments');

  CollectionReference<Map<String, dynamic>> get _statements =>
      _bookDoc.collection('statements');

  CollectionReference<Map<String, dynamic>> get _receipts =>
      _bookDoc.collection('receipts');

  DocumentReference<Map<String, dynamic>> get _metaClient =>
      _bookDoc.collection('_meta').doc('clientAccounts');

  static int _tsMs(Timestamp? t) =>
      t?.millisecondsSinceEpoch ??
      DateTime.now().toUtc().millisecondsSinceEpoch;

  Future<void> _ensureMeta() async {
    final snap = await _metaClient.get();
    if (snap.exists) return;
    await _metaClient.set({
      'nextClientId': 1,
      'nextChargeId': 1,
      'nextPaymentId': 1,
      'nextAllocationId': 1,
      'nextAdjustmentId': 1,
      'nextStatementId': 1,
      'nextStatementNumber': 1,
      'nextReceiptNumber': 1,
    });
  }

  Future<int> _allocate(String field, int fallback) async {
    await _ensureMeta();
    return _db.runTransaction<int>((txn) async {
      final snap = await txn.get(_metaClient);
      final data = snap.data();
      final next = (data?[field] as num?)?.toInt() ?? fallback;
      txn.set(_metaClient, {field: next + 1}, SetOptions(merge: true));
      return next;
    });
  }

  Client _clientFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    final openingDate = m['openingBalanceDate'] as Timestamp?;
    return Client(
      id: int.parse(d.id),
      bookId: _defaultBookId,
      clientCode: m['clientCode'] as String,
      displayName: m['displayName'] as String,
      legalName: m['legalName'] as String?,
      status: ClientStatusWire.parse(m['status'] as String),
      primaryEmail: m['primaryEmail'] as String?,
      primaryPhone: m['primaryPhone'] as String?,
      notes: m['notes'] as String?,
      openingBalanceMinor: (m['openingBalanceMinor'] as num?)?.toInt() ?? 0,
      openingBalanceDate: openingDate?.toDate(),
      defaultCategoryId: (m['defaultCategoryId'] as num?)?.toInt(),
      defaultAccountId: (m['defaultAccountId'] as num?)?.toInt(),
      createdAtMs: _tsMs(m['createdAt'] as Timestamp?),
      updatedAtMs: _tsMs(m['updatedAt'] as Timestamp?),
      archivedAtMs: (m['archivedAt'] as Timestamp?)?.millisecondsSinceEpoch,
    );
  }

  ClientCharge _chargeFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return ClientCharge(
      id: int.parse(d.id),
      clientId: (m['clientId'] as num).toInt(),
      amountMinor: (m['amountMinor'] as num).toInt(),
      status: ChargeStatusWire.parse(m['status'] as String),
      issuedAtMs: _tsMs(m['issuedAt'] as Timestamp?),
      dueDateMs: (m['dueDate'] as Timestamp?)?.millisecondsSinceEpoch,
      description: m['description'] as String?,
      voidReason: m['voidReason'] as String?,
    );
  }

  ClientPayment _paymentFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return ClientPayment(
      id: int.parse(d.id),
      clientId: (m['clientId'] as num).toInt(),
      amountMinor: (m['amountMinor'] as num).toInt(),
      unallocatedMinor: (m['unallocatedMinor'] as num?)?.toInt() ?? 0,
      status: PaymentStatusWire.parse(m['status'] as String),
      method: PaymentMethodWire.parse(m['method'] as String),
      receivedAtMs: _tsMs(m['receivedAt'] as Timestamp?),
      accountId: (m['accountId'] as num).toInt(),
      categoryId: (m['categoryId'] as num).toInt(),
      reference: m['reference'] as String?,
      notes: m['notes'] as String?,
      receiptNumber: (m['receiptNumber'] as num?)?.toInt(),
      ledgerTransactionId: (m['ledgerTransactionId'] as num?)?.toInt(),
      reversalReason: m['reversalReason'] as String?,
      createdAtMs: (m['createdAt'] as Timestamp?)?.millisecondsSinceEpoch,
    );
  }

  PaymentAllocation _allocFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return PaymentAllocation(
      id: int.parse(d.id),
      paymentId: (m['paymentId'] as num).toInt(),
      chargeId: (m['chargeId'] as num).toInt(),
      amountMinor: (m['amountMinor'] as num).toInt(),
    );
  }

  ClientAdjustment _adjFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return ClientAdjustment(
      id: int.parse(d.id),
      clientId: (m['clientId'] as num).toInt(),
      kind: AdjustmentKindWire.parse(m['kind'] as String),
      amountMinor: (m['amountMinor'] as num).toInt(),
      effectiveAtMs: _tsMs(m['effectiveAt'] as Timestamp?),
      reason: m['reason'] as String?,
    );
  }

  ClientStatement _stmtFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return ClientStatement(
      id: int.parse(d.id),
      clientId: (m['clientId'] as num).toInt(),
      fromDateMs: _tsMs(m['fromDate'] as Timestamp?),
      toDateMs: _tsMs(m['toDate'] as Timestamp?),
      openingBalanceMinor: (m['openingBalanceMinor'] as num).toInt(),
      closingBalanceMinor: (m['closingBalanceMinor'] as num).toInt(),
      issuedAtMs: _tsMs(m['issuedAt'] as Timestamp?),
      statementNumber: (m['statementNumber'] as num).toInt(),
    );
  }

  ReceiptDocument _receiptDocumentFromMap(
    Map<String, dynamic> m,
    int paymentId,
  ) {
    final allocRaw = m['allocations'];
    final allocations = <({int chargeId, int amountMinor})>[];
    if (allocRaw is List) {
      for (final item in allocRaw) {
        if (item is Map) {
          final im = Map<String, dynamic>.from(item);
          allocations.add((
            chargeId: (im['chargeId'] as num).toInt(),
            amountMinor: (im['amountMinor'] as num).toInt(),
          ));
        }
      }
    }
    return ReceiptDocument(
      paymentId: paymentId,
      receiptNumber: (m['receiptNumber'] as num).toInt(),
      issuedAtMs: _tsMs(m['issuedAt'] as Timestamp?),
      clientId: (m['clientId'] as num).toInt(),
      clientDisplayName: m['clientDisplayName'] as String,
      clientCode: m['clientCode'] as String,
      amountMinor: (m['amountMinor'] as num).toInt(),
      method: PaymentMethodWire.parse(m['method'] as String),
      businessName: m['businessName'] as String?,
      reference: m['reference'] as String?,
      notes: m['notes'] as String?,
      allocations: allocations,
      paymentReversed: (m['paymentReversed'] as bool?) ?? false,
    );
  }

  Future<void> _persistReceiptDoc({
    required int paymentId,
    required Client client,
    required ClientPayment payment,
    required List<PaymentAllocation> allocations,
  }) async {
    final bn = await _ledger.getSetting('business_name');
    final rn = payment.receiptNumber ?? paymentId;
    await _receipts.doc('$paymentId').set({
      'paymentId': paymentId,
      'receiptNumber': rn,
      'issuedAt': Timestamp.fromDate(payment.receivedAt),
      'clientId': client.id,
      'clientDisplayName': client.displayName,
      'clientCode': client.clientCode,
      'amountMinor': payment.amountMinor,
      'method': payment.method.name,
      'businessName': bn,
      'reference': payment.reference,
      'notes': payment.notes,
      'paymentReversed': false,
      'allocations': [
        for (final a in allocations)
          {'chargeId': a.chargeId, 'amountMinor': a.amountMinor},
      ],
    });
  }

  @override
  Future<List<Client>> listClients({
    ClientStatus? status,
    String? query,
  }) async {
    await _ensureMeta();
    Query<Map<String, dynamic>> q = _clients;
    if (status != null) {
      q = q.where('status', isEqualTo: status.name);
    }
    final snap = await q.get();
    var list = snap.docs.map(_clientFromDoc).toList();
    list.sort(
      (Client a, Client b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    final qTrim = query?.trim().toLowerCase();
    if (qTrim != null && qTrim.isNotEmpty) {
      list = list.where((c) => c.matchesClientDirectoryQuery(qTrim)).toList();
    }
    return list;
  }

  @override
  Future<Client?> getClient(int id) async {
    await _ensureMeta();
    final d = await _clients.doc('$id').get();
    if (!d.exists) return null;
    return _clientFromDoc(d);
  }

  @override
  Future<int> createClient(CreateClientInput input) async {
    final id = await _allocate('nextClientId', 1);
    final now = FieldValue.serverTimestamp();
    await _clients.doc('$id').set({
      'clientCode': input.clientCode.trim(),
      'displayName': input.displayName.trim(),
      'legalName': input.legalName?.trim(),
      'status': ClientStatus.active.name,
      'primaryEmail': input.primaryEmail?.trim(),
      'primaryPhone': input.primaryPhone?.trim(),
      'notes': input.notes?.trim(),
      'openingBalanceMinor': input.openingBalanceMinor,
      'openingBalanceDate': input.openingBalanceDate != null
          ? Timestamp.fromDate(input.openingBalanceDate!)
          : null,
      'defaultCategoryId': input.defaultCategoryId,
      'defaultAccountId': input.defaultAccountId,
      'createdAt': now,
      'updatedAt': now,
    });
    return id;
  }

  @override
  Future<void> updateClient(UpdateClientInput input) async {
    final ref = _clients.doc('${input.id}');
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Client not found');
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (input.displayName != null) {
      data['displayName'] = input.displayName!.trim();
    }
    if (input.legalName != null) data['legalName'] = input.legalName!.trim();
    if (input.clientCode != null) {
      data['clientCode'] = input.clientCode!.trim();
    }
    if (input.status != null) data['status'] = input.status!.name;
    if (input.primaryEmail != null) {
      data['primaryEmail'] = input.primaryEmail!.trim();
    }
    if (input.primaryPhone != null) {
      data['primaryPhone'] = input.primaryPhone!.trim();
    }
    if (input.notes != null) data['notes'] = input.notes!.trim();
    if (input.openingBalanceMinor != null) {
      data['openingBalanceMinor'] = input.openingBalanceMinor;
    }
    if (input.openingBalanceDate != null) {
      data['openingBalanceDate'] = Timestamp.fromDate(input.openingBalanceDate!);
    }
    if (input.defaultCategoryId != null) {
      data['defaultCategoryId'] = input.defaultCategoryId;
    }
    if (input.defaultAccountId != null) {
      data['defaultAccountId'] = input.defaultAccountId;
    }
    await ref.set(data, SetOptions(merge: true));
  }

  @override
  Future<void> archiveClient(int id) async {
    await _clients.doc('$id').set({
      'status': ClientStatus.archived.name,
      'archivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<ClientCharge>> _chargesForClient(int clientId) async {
    final snap = await _charges.where('clientId', isEqualTo: clientId).get();
    return snap.docs.map(_chargeFromDoc).toList();
  }

  Future<List<ClientPayment>> _paymentsForClient(int clientId) async {
    final snap = await _payments.where('clientId', isEqualTo: clientId).get();
    return snap.docs.map(_paymentFromDoc).toList();
  }

  Future<List<ClientAdjustment>> _adjustmentsForClient(int clientId) async {
    final snap = await _adjustments.where('clientId', isEqualTo: clientId).get();
    return snap.docs.map(_adjFromDoc).toList();
  }

  Future<Map<int, int>> _allocationsByChargeForClient(int clientId) async {
    final snap = await _allocations.where('clientId', isEqualTo: clientId).get();
    final map = <int, int>{};
    for (final d in snap.docs) {
      final a = _allocFromDoc(d);
      map[a.chargeId] = (map[a.chargeId] ?? 0) + a.amountMinor;
    }
    return map;
  }

  int _openAmountForCharge(ClientCharge c, int allocated) {
    if (c.status == ChargeStatus.voided) return 0;
    final raw = c.amountMinor - allocated;
    return raw > 0 ? raw : 0;
  }

  @override
  Future<ClientAccountSummary> clientSummary(int clientId) async {
    final client = await getClient(clientId);
    if (client == null) throw StateError('Client not found');
    final charges = await _chargesForClient(clientId);
    final payments = await _paymentsForClient(clientId);
    final adjustments = await _adjustmentsForClient(clientId);
    final allocByCharge = await _allocationsByChargeForClient(clientId);

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
      final open = _openAmountForCharge(c, alloc);
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
        client.openingBalanceMinor +
        chargeTotal -
        paymentTotal +
        adjEffect;

    return ClientAccountSummary(
      client: client,
      balanceMinor: balance,
      outstandingChargesMinor: outstanding,
      openChargeCount: openCount,
      overdueOpenChargeCount: overdue,
    );
  }

  @override
  Future<List<ClientLedgerLine>> clientLedger(
    int clientId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final client = await getClient(clientId);
    if (client == null) throw StateError('Client not found');

    final charges = await _chargesForClient(clientId);
    final payments = await _paymentsForClient(clientId);
    final adjustments = await _adjustmentsForClient(clientId);

    final rows = <_LedgerSortRow>[];

    rows.add(
      _LedgerSortRow(
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
        _LedgerSortRow(
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
        _LedgerSortRow(
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
      final delta = a.kind == AdjustmentKind.increase
          ? a.amountMinor
          : -a.amountMinor;
      rows.add(
        _LedgerSortRow(
          a.effectiveAt,
          ClientLedgerEntryKind.adjustment,
          'Adjustment',
          a.reason,
          delta,
          refId: a.id,
        ),
      );
    }

    rows.sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.kind.index.compareTo(b.kind.index);
    });

    var balance = 0;
    final lines = <ClientLedgerLine>[];
    for (final r in rows) {
      balance += r.delta;
      final include = _inRange(r.at, from, to);
      if (!include) continue;
      lines.add(
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
    return lines;
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
  Future<List<ClientCharge>> listCharges({
    int? clientId,
    ChargeStatus? status,
  }) async {
    await _ensureMeta();
    Query<Map<String, dynamic>> q = _charges;
    if (clientId != null) q = q.where('clientId', isEqualTo: clientId);
    if (status != null) q = q.where('status', isEqualTo: status.name);
    final snap = await q.get();
    final list = snap.docs.map(_chargeFromDoc).toList()
      ..sort((ClientCharge a, ClientCharge b) {
        final c = b.issuedAt.compareTo(a.issuedAt);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    return list;
  }

  @override
  Future<ClientCharge?> getCharge(int id) async {
    final d = await _charges.doc('$id').get();
    if (!d.exists) return null;
    return _chargeFromDoc(d);
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
    final id = await _allocate('nextChargeId', 1);
    await _charges.doc('$id').set({
      'clientId': input.clientId,
      'amountMinor': input.amountMinor,
      'status': ChargeStatus.open.name,
      'issuedAt': Timestamp.fromDate(input.issuedAt),
      'dueDate': due != null ? Timestamp.fromDate(due) : null,
      'description': input.description?.trim(),
    });
    return id;
  }

  @override
  Future<void> voidCharge(int chargeId, String reason) async {
    await _charges.doc('$chargeId').update({
      'status': ChargeStatus.voided.name,
      'voidReason': reason.trim(),
    });
  }

  @override
  Future<int> createAdjustment(CreateClientAdjustmentInput input) async {
    await _ensureMeta();
    if (input.amountMinor <= 0) throw ArgumentError('amount');
    final client = await getClient(input.clientId);
    if (client == null) throw StateError('Client not found');
    final id = await _allocate('nextAdjustmentId', 1);
    await _adjustments.doc('$id').set({
      'clientId': input.clientId,
      'kind': input.kind.name,
      'amountMinor': input.amountMinor,
      'effectiveAt': Timestamp.fromDate(input.effectiveAt),
      'reason': input.reason?.trim(),
    });
    return id;
  }

  @override
  Future<List<ClientAdjustment>> listAdjustments(int clientId) async {
    await _ensureMeta();
    final list = await _adjustmentsForClient(clientId);
    list.sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));
    return list;
  }

  @override
  Future<List<({ClientCharge charge, int openMinor})>> listChargesWithOpenAmount(
    int clientId,
  ) async {
    await _ensureMeta();
    final charges = await _chargesForClient(clientId);
    final allocByCharge = await _allocationsByChargeForClient(clientId);
    final out = <({ClientCharge charge, int openMinor})>[];
    for (final c in charges) {
      if (c.status == ChargeStatus.voided) continue;
      final open = _openAmountForCharge(c, allocByCharge[c.id] ?? 0);
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
    await _ensureMeta();
    Query<Map<String, dynamic>> q = _payments;
    if (clientId != null) q = q.where('clientId', isEqualTo: clientId);
    if (status != null) q = q.where('status', isEqualTo: status.name);
    final snap = await q.get();
    final list = snap.docs.map(_paymentFromDoc).toList()
      ..sort((ClientPayment a, ClientPayment b) {
        final c = b.receivedAt.compareTo(a.receivedAt);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    return list;
  }

  @override
  Future<ClientPayment?> getPayment(int id) async {
    final d = await _payments.doc('$id').get();
    if (!d.exists) return null;
    return _paymentFromDoc(d);
  }

  @override
  Future<List<PaymentAllocation>> listAllocationsForPayment(
    int paymentId,
  ) async {
    final snap = await _allocations
        .where('paymentId', isEqualTo: paymentId)
        .get();
    return snap.docs.map(_allocFromDoc).toList();
  }

  @override
  Future<int> recordPayment(RecordPaymentInput input) async {
    await _ensureMeta();
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
      ledgerTxId = await _ledger.insertTransaction(
        bookId: _defaultBookId,
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

    var paymentId = 0;
    try {
      await _db.runTransaction((txn) async {
        final metaSnap = await txn.get(_metaClient);
        final data = metaSnap.data()!;
        paymentId = (data['nextPaymentId'] as num?)?.toInt() ?? 1;
        final receiptNumber =
            (data['nextReceiptNumber'] as num?)?.toInt() ?? 1;
        var nextAllocId = (data['nextAllocationId'] as num?)?.toInt() ?? 1;

        txn.set(_metaClient, {
          'nextPaymentId': paymentId + 1,
          'nextReceiptNumber': receiptNumber + 1,
          'nextAllocationId': nextAllocId + input.allocations.length,
        }, SetOptions(merge: true));

        txn.set(_payments.doc('$paymentId'), {
          'clientId': input.clientId,
          'amountMinor': input.amountMinor,
          'unallocatedMinor': unallocated,
          'status': PaymentStatus.posted.name,
          'method': input.method.name,
          'receivedAt': Timestamp.fromDate(input.receivedAt),
          'accountId': input.accountId,
          'categoryId': input.categoryId,
          'reference': input.reference?.trim(),
          'notes': input.notes?.trim(),
          'receiptNumber': receiptNumber,
          'ledgerTransactionId': ledgerTxId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        for (final a in input.allocations) {
          txn.set(_allocations.doc('$nextAllocId'), {
            'paymentId': paymentId,
            'chargeId': a.chargeId,
            'amountMinor': a.amountMinor,
            'clientId': input.clientId,
          });
          nextAllocId++;
        }
      });
    } catch (e) {
      if (ledgerTxId != null) {
        await _ledger.deleteTransaction(ledgerTxId);
      }
      rethrow;
    }

    final saved = await getPayment(paymentId);
    final allocsSaved = await listAllocationsForPayment(paymentId);
    if (saved != null) {
      await _persistReceiptDoc(
        paymentId: paymentId,
        client: client,
        payment: saved,
        allocations: allocsSaved,
      );
    }

    return paymentId;
  }

  @override
  Future<void> reversePayment(int paymentId, String reason) async {
    final p = await getPayment(paymentId);
    if (p == null) throw StateError('Payment not found');
    if (p.status == PaymentStatus.reversed) return;

    await _payments.doc('$paymentId').update({
      'status': PaymentStatus.reversed.name,
      'reversalReason': reason.trim(),
    });

    await _receipts.doc('$paymentId').set(
      {'paymentReversed': true},
      SetOptions(merge: true),
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
    final rsnap = await _receipts.doc('$paymentId').get();
    if (rsnap.exists && rsnap.data() != null) {
      return _receiptDocumentFromMap(rsnap.data()!, paymentId);
    }

    final p = await getPayment(paymentId);
    if (p == null) throw StateError('Payment not found');
    final client = await getClient(p.clientId);
    if (client == null) throw StateError('Client not found');
    final allocs = await listAllocationsForPayment(paymentId);
    final bn = await _ledger.getSetting('business_name');
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
        for (final a in allocs) (chargeId: a.chargeId, amountMinor: a.amountMinor),
      ],
      paymentReversed: p.status == PaymentStatus.reversed,
    );
  }

  Future<int> _balanceBeforeStartOfDay(int clientId, DateTime day) async {
    final client = await getClient(clientId);
    if (client == null) throw StateError('Client not found');
    final charges = await _chargesForClient(clientId);
    final payments = await _paymentsForClient(clientId);
    final adjustments = await _adjustmentsForClient(clientId);

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
    final client = await getClient(input.clientId);
    if (client == null) throw StateError('Client not found');
    if (!input.toDate.isBefore(input.fromDate)) {
      // ok
    } else {
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

    final opening = await _balanceBeforeStartOfDay(input.clientId, fromDay);

    final charges = await _chargesForClient(input.clientId);
    final payments = await _paymentsForClient(input.clientId);
    final adjustments = await _adjustmentsForClient(input.clientId);

    final events =
        <({DateTime at, String label, String? detail, int delta})>[];
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

    final closing = running;

    return StatementPreview(
      client: client,
      fromDateMs: fromMs,
      toDateMs: toMs,
      openingBalanceMinor: opening,
      lines: lines,
      closingBalanceMinor: closing,
    );
  }

  @override
  Future<int> saveStatement(BuildStatementInput input) async {
    final preview = await buildStatementPreview(input);
    final id = await _allocate('nextStatementId', 1);
    final statementNumber = await _allocate('nextStatementNumber', 1);
    await _statements.doc('$id').set({
      'clientId': input.clientId,
      'fromDate': Timestamp.fromDate(preview.fromDate),
      'toDate': Timestamp.fromDate(preview.toDate),
      'openingBalanceMinor': preview.openingBalanceMinor,
      'closingBalanceMinor': preview.closingBalanceMinor,
      'issuedAt': FieldValue.serverTimestamp(),
      'statementNumber': statementNumber,
    });
    return id;
  }

  @override
  Future<List<ClientStatement>> listStatements({int? clientId}) async {
    await _ensureMeta();
    Query<Map<String, dynamic>> q = _statements;
    if (clientId != null) q = q.where('clientId', isEqualTo: clientId);
    final snap = await q.get();
    final list = snap.docs.map(_stmtFromDoc).toList()
      ..sort((ClientStatement a, ClientStatement b) {
        final c = b.issuedAt.compareTo(a.issuedAt);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    return list;
  }

  @override
  Future<OverviewMetrics> overviewMetrics() async {
    await _ensureMeta();
    final clients = await listClients(status: ClientStatus.active);
    var totalBal = 0;
    var openCharges = 0;
    var overdue = 0;
    for (final c in clients) {
      final s = await clientSummary(c.id);
      totalBal += s.balanceMinor;
      openCharges += s.outstandingChargesMinor;
      overdue += s.overdueOpenChargeCount;
    }

    final pays = await listPayments(status: PaymentStatus.posted);
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    var last30 = 0;
    for (final p in pays) {
      if (!p.receivedAt.isBefore(cutoff)) last30 += p.amountMinor;
    }

    return OverviewMetrics(
      totalBalanceMinor: totalBal,
      openChargesTotalMinor: openCharges,
      overdueOpenChargeCount: overdue,
      postedPaymentsLast30DaysMinor: last30,
      activeClientCount: clients.length,
    );
  }
}

class _LedgerSortRow {
  _LedgerSortRow(
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
