import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../application/client_account_providers.dart';
import '../../../application/providers.dart';
import '../../../core/money.dart';
import '../../../domain/client_accounts.dart';
import '../../../services/receipt_pdf_service.dart';
import '../../layout/responsive_content.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/bennet_surface.dart';

class ReceiptPreviewScreen extends ConsumerWidget {
  const ReceiptPreviewScreen({super.key, required this.paymentId});

  final int paymentId;

  Future<void> _sharePdf(BuildContext context, WidgetRef ref, ReceiptDocument doc) async {
    final ledger = await ref.read(ledgerRepositoryProvider.future);
    final footer = await ledger.getSetting('document_secondary_footer');
    final bytes = await buildClientPaymentReceiptPdf(
      receipt: doc,
      footerSecondary: footer,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_${doc.receiptNumber}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptDocumentProvider(paymentId));

    return async.when(
      loading: () => const BennetScaffold(
        title: 'Receipt',
        contentWidth: ContentWidthMode.narrow,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Receipt',
        contentWidth: ContentWidthMode.narrow,
        body: Center(child: Text('$e')),
      ),
      data: (doc) {
        if (doc == null) {
          return BennetScaffold(
            title: 'Receipt',
            contentWidth: ContentWidthMode.narrow,
            body: const Center(child: Text('Receipt not found')),
          );
        }
        final df = DateFormat.yMMMd();
        return BennetScaffold(
          title: 'Receipt #${doc.receiptNumber}',
          contentWidth: ContentWidthMode.standard,
          actions: [
            IconButton(
              tooltip: 'Payment record',
              icon: const Icon(Icons.payment_outlined),
              onPressed: () => context.go('/payments/$paymentId'),
            ),
            IconButton(
              tooltip: 'Share PDF',
              onPressed: () => _sharePdf(context, ref, doc),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (doc.paymentReversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MaterialBanner(
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    leading: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    content: Text(
                      'This receipt was issued before the payment was reversed.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    actions: const [SizedBox.shrink()],
                  ),
                ),
              BennetSurface(
                clip: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      title: const Text('Amount'),
                      trailing: Text(formatMoney(doc.amountMinor)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Client'),
                      subtitle: Text('${doc.clientDisplayName} · ${doc.clientCode}'),
                      onTap: () => context.go('/clients/${doc.clientId}'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Method'),
                      subtitle: Text(doc.method.displayLabel),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Issued'),
                      subtitle: Text(df.format(doc.issuedAt)),
                    ),
                    if (doc.reference != null &&
                        doc.reference!.trim().isNotEmpty) ...[
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Reference'),
                        subtitle: Text(doc.reference!),
                      ),
                    ],
                    if (doc.notes != null && doc.notes!.trim().isNotEmpty) ...[
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Notes'),
                        subtitle: Text(doc.notes!),
                      ),
                    ],
                  ],
                ),
              ),
              if (doc.allocations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Applied to balances',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                BennetSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final a in doc.allocations)
                        ListTile(
                          title: Text('Charge #${a.chargeId}'),
                          trailing: Text(formatMoney(a.amountMinor)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
