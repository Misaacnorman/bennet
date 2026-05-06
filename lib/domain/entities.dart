enum TxType { income, expense }

extension TxTypeSerialized on TxType {
  String get wire => name;

  static TxType parse(String s) {
    return TxType.values.firstWhere((e) => e.name == s);
  }
}

enum AccountKind { cash, bank }

extension AccountKindSerialized on AccountKind {
  String get wire => name;

  static AccountKind parse(String s) {
    return AccountKind.values.firstWhere((e) => e.name == s);
  }
}

enum BalanceSection { asset, liability, equity }

extension BalanceSectionSerialized on BalanceSection {
  String get wire => name;

  static BalanceSection parse(String s) {
    return BalanceSection.values.firstWhere((e) => e.name == s);
  }
}

class Book {
  const Book({required this.id, required this.name});

  final int id;
  final String name;
}

class Category {
  const Category({required this.id, required this.name});

  final int id;
  final String name;
}

class Account {
  const Account({
    required this.id,
    required this.bookId,
    required this.name,
    required this.kind,
  });

  final int id;
  final int bookId;
  final String name;
  final AccountKind kind;
}

class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.bookId,
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.amountMinor,
    required this.occurredAt,
    this.notes,
    this.paymentMethod,
    this.counterparty,
    this.clearedAt,
    this.categoryName,
    this.accountName,
    this.clientId,
    this.sourceType,
    this.sourceId,
    this.sourceNumber,
  });

  final int id;
  final int bookId;
  final int accountId;
  final int categoryId;
  final TxType type;
  final int amountMinor;
  final DateTime occurredAt;
  final String? notes;
  final String? paymentMethod;
  final String? counterparty;
  final DateTime? clearedAt;
  final String? categoryName;
  final String? accountName;

  /// When set with [sourceType]/[sourceId], links cash-book activity to client payments.
  final int? clientId;
  final String? sourceType;
  final int? sourceId;
  final String? sourceNumber;

  bool get linksToPostedPayment =>
      sourceType == LedgerSourceType.clientPayment && sourceId != null;
}

/// Values for [LedgerTransaction.sourceType] on payment-related ledger writes.
abstract final class LedgerSourceType {
  static const clientPayment = 'client_payment';
  static const paymentReversal = 'payment_reversal';
}

class PeriodOpening {
  const PeriodOpening({
    required this.id,
    required this.bookId,
    required this.year,
    required this.month,
    required this.openingBalanceMinor,
  });

  final int id;
  final int bookId;
  final int year;
  final int month;
  final int openingBalanceMinor;
}

class BankStatementLine {
  const BankStatementLine({
    required this.id,
    required this.accountId,
    required this.postedAt,
    required this.amountMinor,
    required this.description,
    this.matchedTransactionId,
  });

  final int id;
  final int accountId;
  final DateTime postedAt;
  final int amountMinor;
  final String description;
  final int? matchedTransactionId;
}

class BalanceSheetItem {
  const BalanceSheetItem({
    required this.id,
    required this.bookId,
    required this.section,
    required this.label,
    required this.amountMinor,
    required this.sortOrder,
  });

  final int id;
  final int bookId;
  final BalanceSection section;
  final String label;
  final int amountMinor;
  final int sortOrder;
}

class CategoryRollup {
  const CategoryRollup({
    required this.categoryId,
    required this.categoryName,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final int categoryId;
  final String categoryName;
  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;
}
