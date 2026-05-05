// Domain-neutral client account entities (charges, payments, statements).

enum ClientStatus {
  active,
  paused,
  archived,
}

extension ClientStatusWire on ClientStatus {
  String get wire => name;

  static ClientStatus parse(String s) =>
      ClientStatus.values.firstWhere((e) => e.name == s);
}

enum ChargeStatus {
  open,
  paid,
  voided,
}

extension ChargeStatusWire on ChargeStatus {
  String get wire => name;

  static ChargeStatus parse(String s) =>
      ChargeStatus.values.firstWhere((e) => e.name == s);
}

enum PaymentStatus {
  posted,
  reversed,
}

extension PaymentStatusWire on PaymentStatus {
  String get wire => name;

  static PaymentStatus parse(String s) =>
      PaymentStatus.values.firstWhere((e) => e.name == s);
}

enum PaymentMethod {
  cash,
  bankTransfer,
  card,
  check,
  other,
}

extension PaymentMethodWire on PaymentMethod {
  String get wire => name;

  static PaymentMethod parse(String s) =>
      PaymentMethod.values.firstWhere((e) => e.name == s);
}

enum AdjustmentKind {
  increase,
  decrease,
}

extension AdjustmentKindWire on AdjustmentKind {
  String get wire => name;

  static AdjustmentKind parse(String s) =>
      AdjustmentKind.values.firstWhere((e) => e.name == s);
}

enum ClientLedgerEntryKind {
  opening,
  charge,
  payment,
  adjustment,
}

class Client {
  const Client({
    required this.id,
    required this.bookId,
    required this.clientCode,
    required this.displayName,
    this.legalName,
    required this.status,
    this.primaryEmail,
    this.primaryPhone,
    this.notes,
    this.openingBalanceMinor = 0,
    this.openingBalanceDate,
    this.defaultCategoryId,
    this.defaultAccountId,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.archivedAtMs,
  });

  final int id;
  final int bookId;
  final String clientCode;
  final String displayName;
  final String? legalName;
  final ClientStatus status;
  final String? primaryEmail;
  final String? primaryPhone;
  final String? notes;
  final int openingBalanceMinor;
  final DateTime? openingBalanceDate;
  final int? defaultCategoryId;
  final int? defaultAccountId;
  final int createdAtMs;
  final int updatedAtMs;
  final int? archivedAtMs;

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true);

  DateTime get updatedAt =>
      DateTime.fromMillisecondsSinceEpoch(updatedAtMs, isUtc: true);

  DateTime? get archivedAt => archivedAtMs != null
      ? DateTime.fromMillisecondsSinceEpoch(archivedAtMs!, isUtc: true)
      : null;
}

/// Normalized query from [String.trim] and [String.toLowerCase]. Empty matches all.
extension ClientDirectoryQuery on Client {
  bool matchesClientDirectoryQuery(String queryLower) {
    if (queryLower.isEmpty) return true;
    return displayName.toLowerCase().contains(queryLower) ||
        clientCode.toLowerCase().contains(queryLower) ||
        (legalName?.toLowerCase().contains(queryLower) ?? false) ||
        (primaryEmail?.toLowerCase().contains(queryLower) ?? false) ||
        (primaryPhone?.toLowerCase().contains(queryLower) ?? false) ||
        (notes?.toLowerCase().contains(queryLower) ?? false);
  }
}

class ClientCharge {
  const ClientCharge({
    required this.id,
    required this.clientId,
    required this.amountMinor,
    required this.status,
    required this.issuedAtMs,
    this.dueDateMs,
    this.description,
    this.voidReason,
  });

  final int id;
  final int clientId;
  final int amountMinor;
  final ChargeStatus status;
  final int issuedAtMs;
  final int? dueDateMs;
  final String? description;
  final String? voidReason;

  DateTime get issuedAt =>
      DateTime.fromMillisecondsSinceEpoch(issuedAtMs, isUtc: true);

  DateTime? get dueDate => dueDateMs != null
      ? DateTime.fromMillisecondsSinceEpoch(dueDateMs!, isUtc: true)
      : null;
}

class ClientPayment {
  const ClientPayment({
    required this.id,
    required this.clientId,
    required this.amountMinor,
    required this.unallocatedMinor,
    required this.status,
    required this.method,
    required this.receivedAtMs,
    required this.accountId,
    required this.categoryId,
    this.reference,
    this.notes,
    this.receiptNumber,
    this.ledgerTransactionId,
    this.reversalReason,
    this.createdAtMs,
  });

  final int id;
  final int clientId;
  final int amountMinor;
  final int unallocatedMinor;
  final PaymentStatus status;
  final PaymentMethod method;
  final int receivedAtMs;
  final int accountId;
  final int categoryId;
  final String? reference;
  final String? notes;
  final int? receiptNumber;
  final int? ledgerTransactionId;
  final String? reversalReason;
  final int? createdAtMs;

  DateTime get receivedAt =>
      DateTime.fromMillisecondsSinceEpoch(receivedAtMs, isUtc: true);
}

class PaymentAllocation {
  const PaymentAllocation({
    required this.id,
    required this.paymentId,
    required this.chargeId,
    required this.amountMinor,
  });

  final int id;
  final int paymentId;
  final int chargeId;
  final int amountMinor;
}

class ClientAdjustment {
  const ClientAdjustment({
    required this.id,
    required this.clientId,
    required this.kind,
    required this.amountMinor,
    required this.effectiveAtMs,
    this.reason,
  });

  final int id;
  final int clientId;
  final AdjustmentKind kind;
  final int amountMinor;
  final int effectiveAtMs;
  final String? reason;

  DateTime get effectiveAt =>
      DateTime.fromMillisecondsSinceEpoch(effectiveAtMs, isUtc: true);
}

/// Snapshot fields suitable for PDF regeneration.
class ReceiptDocument {
  const ReceiptDocument({
    required this.paymentId,
    required this.receiptNumber,
    required this.issuedAtMs,
    required this.clientId,
    required this.clientDisplayName,
    required this.clientCode,
    required this.amountMinor,
    required this.method,
    this.businessName,
    this.reference,
    this.notes,
    required this.allocations,
    this.paymentReversed = false,
  });

  final int paymentId;
  final int receiptNumber;
  final int issuedAtMs;
  final int clientId;
  final String clientDisplayName;
  final String clientCode;
  final int amountMinor;
  final PaymentMethod method;
  final String? businessName;
  final String? reference;
  final String? notes;
  final List<({int chargeId, int amountMinor})> allocations;
  /// True after reversal; snapshot reflects issued receipt that was later reversed.
  final bool paymentReversed;

  DateTime get issuedAt =>
      DateTime.fromMillisecondsSinceEpoch(issuedAtMs, isUtc: true);
}

class ClientStatement {
  const ClientStatement({
    required this.id,
    required this.clientId,
    required this.fromDateMs,
    required this.toDateMs,
    required this.openingBalanceMinor,
    required this.closingBalanceMinor,
    required this.issuedAtMs,
    required this.statementNumber,
  });

  final int id;
  final int clientId;
  final int fromDateMs;
  final int toDateMs;
  final int openingBalanceMinor;
  final int closingBalanceMinor;
  final int issuedAtMs;
  final int statementNumber;

  DateTime get fromDate =>
      DateTime.fromMillisecondsSinceEpoch(fromDateMs, isUtc: true);

  DateTime get toDate =>
      DateTime.fromMillisecondsSinceEpoch(toDateMs, isUtc: true);

  DateTime get issuedAt =>
      DateTime.fromMillisecondsSinceEpoch(issuedAtMs, isUtc: true);
}

class ClientLedgerLine {
  const ClientLedgerLine({
    required this.sortAtMs,
    required this.kind,
    required this.title,
    this.subtitle,
    required this.deltaMinor,
    required this.balanceAfterMinor,
    this.refId,
  });

  final int sortAtMs;
  final ClientLedgerEntryKind kind;
  final String title;
  final String? subtitle;
  /// Effect on running balance (charges increase AR; payments decrease).
  final int deltaMinor;
  final int balanceAfterMinor;
  final int? refId;

  DateTime get sortAt =>
      DateTime.fromMillisecondsSinceEpoch(sortAtMs, isUtc: true);
}

class ClientAccountSummary {
  const ClientAccountSummary({
    required this.client,
    required this.balanceMinor,
    required this.outstandingChargesMinor,
    required this.openChargeCount,
    required this.overdueOpenChargeCount,
  });

  final Client client;
  /// Positive means client owes; negative means credit.
  final int balanceMinor;
  final int outstandingChargesMinor;
  final int openChargeCount;
  final int overdueOpenChargeCount;
}

class StatementPreviewLine {
  const StatementPreviewLine({
    required this.occurredAtMs,
    required this.label,
    this.detail,
    required this.deltaMinor,
    required int runningBalanceMinor,
  }) : _runningBalanceMinor = runningBalanceMinor;

  final int occurredAtMs;
  final String label;
  final String? detail;
  final int deltaMinor;
  final int _runningBalanceMinor;

  int get runningBalanceMinor => _runningBalanceMinor;

  DateTime get occurredAt =>
      DateTime.fromMillisecondsSinceEpoch(occurredAtMs, isUtc: true);
}

class StatementPreview {
  const StatementPreview({
    required this.client,
    required this.fromDateMs,
    required this.toDateMs,
    required this.openingBalanceMinor,
    required this.lines,
    required this.closingBalanceMinor,
  });

  final Client client;
  final int fromDateMs;
  final int toDateMs;
  final int openingBalanceMinor;
  final List<StatementPreviewLine> lines;
  final int closingBalanceMinor;

  DateTime get fromDate =>
      DateTime.fromMillisecondsSinceEpoch(fromDateMs, isUtc: true);

  DateTime get toDate =>
      DateTime.fromMillisecondsSinceEpoch(toDateMs, isUtc: true);
}

// --- Inputs ---

class CreateClientInput {
  const CreateClientInput({
    required this.displayName,
    this.legalName,
    required this.clientCode,
    this.primaryEmail,
    this.primaryPhone,
    this.notes,
    this.openingBalanceMinor = 0,
    this.openingBalanceDate,
    this.defaultCategoryId,
    this.defaultAccountId,
  });

  final String displayName;
  final String? legalName;
  final String clientCode;
  final String? primaryEmail;
  final String? primaryPhone;
  final String? notes;
  final int openingBalanceMinor;
  final DateTime? openingBalanceDate;
  final int? defaultCategoryId;
  final int? defaultAccountId;
}

class UpdateClientInput {
  const UpdateClientInput({
    required this.id,
    this.displayName,
    this.legalName,
    this.clientCode,
    this.status,
    this.primaryEmail,
    this.primaryPhone,
    this.notes,
    this.openingBalanceMinor,
    this.openingBalanceDate,
    this.defaultCategoryId,
    this.defaultAccountId,
  });

  final int id;
  final String? displayName;
  final String? legalName;
  final String? clientCode;
  final ClientStatus? status;
  final String? primaryEmail;
  final String? primaryPhone;
  final String? notes;
  final int? openingBalanceMinor;
  final DateTime? openingBalanceDate;
  final int? defaultCategoryId;
  final int? defaultAccountId;
}

class CreateChargeInput {
  const CreateChargeInput({
    required this.clientId,
    required this.amountMinor,
    required this.issuedAt,
    this.dueDate,
    this.description,
  });

  final int clientId;
  final int amountMinor;
  final DateTime issuedAt;
  final DateTime? dueDate;
  final String? description;
}

class PaymentAllocationInput {
  const PaymentAllocationInput({
    required this.chargeId,
    required this.amountMinor,
  });

  final int chargeId;
  final int amountMinor;
}

class RecordPaymentInput {
  const RecordPaymentInput({
    required this.clientId,
    required this.amountMinor,
    required this.receivedAt,
    required this.method,
    required this.accountId,
    required this.categoryId,
    this.allocations = const [],
    this.reference,
    this.notes,
    this.syncLedgerIncome = true,
  });

  final int clientId;
  final int amountMinor;
  final DateTime receivedAt;
  final PaymentMethod method;
  final int accountId;
  final int categoryId;
  final List<PaymentAllocationInput> allocations;
  final String? reference;
  final String? notes;
  final bool syncLedgerIncome;
}

class BuildStatementInput {
  const BuildStatementInput({
    required this.clientId,
    required this.fromDate,
    required this.toDate,
  });

  final int clientId;
  final DateTime fromDate;
  final DateTime toDate;
}

class CreateClientAdjustmentInput {
  const CreateClientAdjustmentInput({
    required this.clientId,
    required this.kind,
    required this.amountMinor,
    required this.effectiveAt,
    this.reason,
  });

  final int clientId;
  final AdjustmentKind kind;
  final int amountMinor;
  final DateTime effectiveAt;
  final String? reason;
}
