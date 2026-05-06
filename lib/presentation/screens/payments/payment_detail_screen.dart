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
import '../../../domain/entities.dart';
import '../../../services/receipt_pdf_service.dart';
import '../../layout/responsive_content.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/bennet_surface.dart';

class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});

  final int paymentId;

  Future<void> _shareReceipt(BuildContext context, WidgetRef ref) async {
    final repo = await ref.clientAccounts;
    final ledger = await ref.read(ledgerRepositoryProvider.future);
    final doc = await repo.receiptForPayment(paymentId);
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

  Future<void> _reversePayment(
    BuildContext context,
    WidgetRef ref,
    ClientPayment payment,
    int? clientId,
  ) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Reverse payment'),
          content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Reason'),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reverse'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reason is required.')));
      return;
    }
    try {
      final repo = await ref.clientAccounts;
      await repo.reversePayment(payment.id, reason);
      if (!context.mounted) return;
      invalidateClientAccounts(ref, clientId: clientId ?? payment.clientId);
      invalidateLedger(ref);
      ref.invalidate(paymentDetailProvider(payment.id));
      ref.invalidate(paymentAllocationChargeLookupProvider(payment.id));
      ref.invalidate(receiptDocumentProvider(payment.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment reversed')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String? _accountName(List<Account> accounts, int id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  String? _categoryName(List<Category> categories, int id) {
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(paymentDetailProvider(paymentId));
    final bookAsync = ref.watch(defaultBookProvider);

    return detailAsync.when(
      loading: () => const BennetScaffold(
        title: 'Payment',
        contentWidth: ContentWidthMode.narrow,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Payment',
        contentWidth: ContentWidthMode.narrow,
        body: Center(child: Text('$e')),
      ),
      data: (tuple) {
        final p = tuple.payment;
        final c = tuple.client;
        final baseAllocs = tuple.allocations;
        if (p == null) {
          return const BennetScaffold(
            title: 'Payment',
            contentWidth: ContentWidthMode.narrow,
            body: Center(child: Text('Not found')),
          );
        }

        final allocAsync = baseAllocs.isEmpty
            ? null
            : ref.watch(paymentAllocationChargeLookupProvider(paymentId));

        final scheme = Theme.of(context).colorScheme;
        final df = DateFormat.yMMMd();

        Widget allocationBlock() {
          if (baseAllocs.isEmpty) {
            return const ListTile(
              title: Text('Allocations'),
              subtitle:
                  Text('None — entire amount remained unapplied on the receipt.'),
            );
          }
          return allocAsync!.when(
            loading: () => const ListTile(
              title: Text('Allocations'),
              subtitle: Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            ),
            error: (e, _) => ListTile(
              title: const Text('Allocations'),
              subtitle: Text('$e'),
            ),
            data: (rows) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'Applied to balances',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final row in rows)
                      ListTile(
                        title: Text(
                          row.charge?.description?.trim().isNotEmpty == true
                              ? row.charge!.description!.trim()
                              : 'Charge #${row.allocation.chargeId}',
                        ),
                        subtitle: Text('Charge #${row.allocation.chargeId}'),
                        trailing: Text(
                          formatMoney(row.allocation.amountMinor),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        }

        return bookAsync.when(
          loading: () => const BennetScaffold(
            title: 'Payment',
            contentWidth: ContentWidthMode.standard,
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => BennetScaffold(
            title: 'Payment',
            contentWidth: ContentWidthMode.standard,
            body: Center(child: Text('$e')),
          ),
          data: (book) {
            final accountsAsync = ref.watch(accountsProvider(book.id));
            final categoriesAsync = ref.watch(categoriesProvider);

            return accountsAsync.when(
              loading: () => const BennetScaffold(
                title: 'Payment',
                contentWidth: ContentWidthMode.standard,
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => BennetScaffold(
                title: 'Payment',
                contentWidth: ContentWidthMode.standard,
                body: Center(child: Text('$e')),
              ),
              data: (accounts) {
                return categoriesAsync.when(
                  loading: () => const BennetScaffold(
                    title: 'Payment',
                    contentWidth: ContentWidthMode.standard,
                    body: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => BennetScaffold(
                    title: 'Payment',
                    contentWidth: ContentWidthMode.standard,
                    body: Center(child: Text('$e')),
                  ),
                  data: (categories) {
                    final accName =
                        _accountName(accounts, p.accountId) ??
                        'Account #${p.accountId}';
                    final catName =
                        _categoryName(categories, p.categoryId) ??
                        'Category #${p.categoryId}';

                    return BennetScaffold(
                      title: 'Payment',
                      contentWidth: ContentWidthMode.standard,
                      actions: [
                        if (p.status == PaymentStatus.posted)
                          IconButton(
                            style: IconButton.styleFrom(
                              foregroundColor: scheme.error,
                            ),
                            tooltip: 'Reverse payment',
                            onPressed: () =>
                                _reversePayment(context, ref, p, c?.id),
                            icon: const Icon(Icons.undo_outlined),
                          ),
                        TextButton.icon(
                          onPressed: () => context.go('/receipts/$paymentId'),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Receipt'),
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
                          BennetSurface(
                            clip: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  title: const Text('Amount'),
                                  trailing: Text(
                                    formatMoney(p.amountMinor),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Unapplied on receipt'),
                                  subtitle: Text(
                                    p.unallocatedMinor > 0
                                        ? formatMoney(p.unallocatedMinor)
                                        : '—',
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Method'),
                                  subtitle: Text(p.method.displayLabel),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Received'),
                                  subtitle: Text(df.format(p.receivedAt)),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Receipt #'),
                                  subtitle: Text(
                                    '${p.receiptNumber ?? paymentId}',
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: scheme.outline,
                                  ),
                                  onTap: () =>
                                      context.go('/receipts/$paymentId'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Status'),
                                  subtitle: Text(p.status.name),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Client'),
                                  subtitle: Text(c?.displayName ?? '—'),
                                  trailing: c != null
                                      ? Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: scheme.outline,
                                        )
                                      : null,
                                  onTap: c != null
                                      ? () => context.go('/clients/${c.id}')
                                      : null,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Deposit account'),
                                  subtitle: Text(accName),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  title: const Text('Category'),
                                  subtitle: Text(catName),
                                ),
                                if (p.reference != null &&
                                    p.reference!.trim().isNotEmpty) ...[
                                  const Divider(height: 1),
                                  ListTile(
                                    title: const Text('Reference'),
                                    subtitle: Text(p.reference!.trim()),
                                  ),
                                ],
                                if (p.notes != null &&
                                    p.notes!.trim().isNotEmpty) ...[
                                  const Divider(height: 1),
                                  ListTile(
                                    title: const Text('Notes'),
                                    subtitle: Text(p.notes!.trim()),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          BennetSurface(
                            clip: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                allocationBlock(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          BennetSurface(
                            clip: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    0,
                                  ),
                                  child: Text(
                                    'Ledger',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                if (p.ledgerTransactionId != null)
                                  ListTile(
                                    title: Text(
                                      'Income entry #${p.ledgerTransactionId}',
                                    ),
                                    subtitle: const Text(
                                      'Open the transaction to reconcile or '
                                      'edit counterparty.',
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: scheme.outline,
                                    ),
                                    onTap: () => context.go(
                                      '/transactions/${p.ledgerTransactionId}',
                                    ),
                                  )
                                else
                                  const ListTile(
                                    subtitle: Text(
                                      'No ledger posting for this '
                                      'payment.',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (p.status == PaymentStatus.reversed) ...[
                            const SizedBox(height: 16),
                            BennetSurface(
                              accent: scheme.errorContainer,
                              clip: false,
                              child: ListTile(
                                title: Text(
                                  'Reversed',
                                  style: TextStyle(color: scheme.onErrorContainer),
                                ),
                                subtitle: Text(
                                  p.reversalReason?.trim().isNotEmpty == true
                                      ? p.reversalReason!.trim()
                                      : 'No reason captured.',
                                  style: TextStyle(color: scheme.onErrorContainer),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
