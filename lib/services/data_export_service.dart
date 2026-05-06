import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../application/client_account_providers.dart';
import '../domain/client_accounts.dart';

/// Share simple CSV extracts for clients, charges, and payments.
class BennetCsvExports {
  BennetCsvExports._();

  static Future<void> shareClients(WidgetRef ref) async {
    final repo = await ref.read(clientAccountRepositoryProvider.future);
    final rows = await repo.listClients();

    final csv = const ListToCsvConverter().convert(<List<String>>[
      ['id', 'displayName', 'clientCode', 'status', 'primaryEmail'],
      ...rows.map(
        (c) => [
          '${c.id}',
          c.displayName,
          c.clientCode,
          c.status.name,
          c.primaryEmail ?? '',
        ],
      ),
    ]);

    await _shareString(csv, 'bennet_clients.csv', 'Clients');
  }

  static Future<void> shareChargesRegister(WidgetRef ref) async {
    final repo = await ref.read(clientAccountRepositoryProvider.future);
    final rows = await repo.listChargeRegister();
    final csv = const ListToCsvConverter().convert(<List<String>>[
      [
        'chargeId',
        'clientDisplayName',
        'clientCode',
        'originalMinor',
        'openMinor',
        'ledgerStatus',
        'storedChargeStatus',
      ],
      ...rows.map(
        (ChargeRegisterRow r) => [
          '${r.charge.id}',
          r.clientDisplayName,
          r.clientCode,
          '${r.charge.amountMinor}',
          '${r.openMinor}',
          r.ledgerStatus.name,
          r.charge.status.name,
        ],
      ),
    ]);
    await _shareString(csv, 'bennet_charges.csv', 'Charges');
  }

  static Future<void> sharePaymentsRegister(WidgetRef ref) async {
    final repo = await ref.read(clientAccountRepositoryProvider.future);
    final rows = await repo.listPayments();
    final df = DateFormat.yMMMd();

    final csv = const ListToCsvConverter().convert(<List<String>>[
      [
        'id',
        'clientId',
        'receivedOn',
        'amountMinor',
        'unallocatedMinor',
        'status',
        'method',
        'receiptNumber',
      ],
      ...rows.map(
        (ClientPayment p) => [
          '${p.id}',
          '${p.clientId}',
          df.format(p.receivedAt),
          '${p.amountMinor}',
          '${p.unallocatedMinor}',
          p.status.name,
          p.method.name,
          '${p.receiptNumber ?? ''}',
        ],
      ),
    ]);
    await _shareString(csv, 'bennet_payments.csv', 'Payments');
  }

  static Future<void> shareStatementsIndex(WidgetRef ref) async {
    final repo = await ref.read(clientAccountRepositoryProvider.future);
    final rows = await repo.listStatements();
    final df = DateFormat.yMMMd();

    final csv = const ListToCsvConverter().convert(<List<String>>[
      [
        'id',
        'clientId',
        'number',
        'from',
        'to',
        'closingMinor',
        'issuedOn',
      ],
      ...rows.map(
        (ClientStatement s) => [
          '${s.id}',
          '${s.clientId}',
          '${s.statementNumber}',
          df.format(s.fromDate),
          df.format(s.toDate),
          '${s.closingBalanceMinor}',
          df.format(s.issuedAt),
        ],
      ),
    ]);
    await _shareString(csv, 'bennet_statements.csv', 'Statements');
  }

  static Future<void> _shareString(
    String content,
    String filename,
    String subject,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], subject: subject);
  }
}
