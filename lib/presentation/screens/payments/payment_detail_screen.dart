import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../application/client_account_providers.dart';
import '../../../application/providers.dart';
import '../../../core/money.dart';
import '../../../domain/client_accounts.dart';
import '../../../services/receipt_pdf_service.dart';
import '../../widgets/app_scaffold.dart';

class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});

  final int paymentId;

  Future<void> _shareReceipt(BuildContext context, WidgetRef ref) async {
    final repo = await ref.clientAccounts;
    final doc = await repo.receiptForPayment(paymentId);
    final bytes = await buildClientPaymentReceiptPdf(receipt: doc);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_${doc.receiptNumber}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _reversePayment(
    BuildContext context,
    WidgetRef ref,
    ClientPayment payment,
    int? clientId,
  ) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse payment'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reason is required.')),
      );
      return;
    }
    try {
      final repo = await ref.clientAccounts;
      await repo.reversePayment(payment.id, reason);
      if (!context.mounted) return;
      invalidateClientAccounts(ref, clientId: clientId ?? payment.clientId);
      invalidateLedger(ref);
      ref.invalidate(paymentDetailProvider(payment.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment reversed')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentDetailProvider(paymentId));

    return async.when(
      loading: () => const BennetScaffold(
        title: 'Payment',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Payment',
        body: Center(child: Text('$e')),
      ),
      data: (tuple) {
        final p = tuple.payment;
        final c = tuple.client;
        if (p == null) {
          return const BennetScaffold(
            title: 'Payment',
            body: Center(child: Text('Not found')),
          );
        }
        return BennetScaffold(
          title: 'Payment',
          actions: [
            if (p.status == PaymentStatus.posted)
              IconButton(
                tooltip: 'Reverse payment',
                onPressed: () => _reversePayment(context, ref, p, c?.id),
                icon: const Icon(Icons.undo_outlined),
              ),
            IconButton(
              tooltip: 'Share receipt PDF',
              onPressed: () => _shareReceipt(context, ref),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: const Text('Amount'),
                trailing: Text(formatMoney(p.amountMinor)),
              ),
              ListTile(
                title: const Text('Client'),
                subtitle: Text(c?.displayName ?? '—'),
                onTap: c != null
                    ? () => context.go('/clients/${c.id}')
                    : null,
              ),
              ListTile(
                title: const Text('Status'),
                subtitle: Text(p.status.name),
              ),
              ListTile(
                title: const Text('Receipt #'),
                subtitle: Text('${p.receiptNumber ?? paymentId}'),
              ),
            ],
          ),
        );
      },
    );
  }
}
