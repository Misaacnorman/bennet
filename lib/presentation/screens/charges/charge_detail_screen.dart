import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/client_account_providers.dart';
import '../../../domain/client_accounts.dart';
import '../../layout/responsive_content.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/bennet_surface.dart';
import '../../widgets/status_pill.dart';

class ChargeDetailScreen extends ConsumerWidget {
  const ChargeDetailScreen({super.key, required this.chargeId});

  final int chargeId;

  static Color _ledgerColor(ChargeLedgerStatus s) => switch (s) {
    ChargeLedgerStatus.open => AppSemanticColors.attention,
    ChargeLedgerStatus.paid => AppSemanticColors.credits,
    ChargeLedgerStatus.overdue => AppSemanticColors.overdue,
    ChargeLedgerStatus.voided => AppSemanticColors.neutral,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regAsync = ref.watch(chargesRegisterProvider);
    final df = DateFormat.yMMMd();

    return regAsync.when(
      loading: () => const BennetScaffold(
        title: 'Charge',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Charge',
        body: Center(child: Text('$e')),
      ),
      data: (rows) {
        ChargeRegisterRow? row;
        for (final r in rows) {
          if (r.charge.id == chargeId) {
            row = r;
            break;
          }
        }
        if (row == null) {
          return BennetScaffold(
            title: 'Charge',
            body: const Center(child: Text('Not found')),
          );
        }
        final ch = row.charge;
        return BennetScaffold(
          title: 'Charge #${ch.id}',
          contentWidth: ContentWidthMode.narrow,
          actions: [
            IconButton(
              tooltip: 'Client',
              onPressed: () => context.go('/clients/${ch.clientId}'),
              icon: const Icon(Icons.person_outline),
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
                      title: const Text('Client'),
                      subtitle: Text(
                        '${row.clientDisplayName} (${row.clientCode})',
                      ),
                      onTap: () => context.go('/clients/${ch.clientId}'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Description'),
                      subtitle: Text(ch.description ?? '—'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Issued'),
                      subtitle: Text(df.format(ch.issuedAt)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Due'),
                      subtitle: Text(
                        ch.dueDate != null ? df.format(ch.dueDate!) : '—',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Status'),
                      subtitle: StatusPill(
                        label: row.ledgerStatus.name,
                        color: _ledgerColor(row.ledgerStatus),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Original amount'),
                      trailing: AmountText(row.originalAmountMinor),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Open amount'),
                      trailing: AmountText(row.openMinor),
                    ),
                    if (ch.voidReason != null && ch.voidReason!.isNotEmpty) ...[
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Void reason'),
                        subtitle: Text(ch.voidReason!),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment applications',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _AllocationsSection(chargeId: chargeId),
            ],
          ),
        );
      },
    );
  }
}

class _AllocationsSection extends ConsumerWidget {
  const _AllocationsSection({required this.chargeId});

  final int chargeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(clientAccountRepositoryProvider.future).then(
            (repo) => repo.listAllocationsForCharge(chargeId),
          ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ));
        }
        if (snap.hasError) {
          return Text('${snap.error}');
        }
        final allocs = snap.data ?? const <PaymentAllocation>[];
        if (allocs.isEmpty) {
          return Text(
            'No line-level applications recorded.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          );
        }
        return BennetSurface(
          clip: false,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < allocs.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  title: Text('Payment #${allocs[i].paymentId}'),
                  trailing: AmountText(allocs[i].amountMinor),
                  onTap: () =>
                      context.push('/payments/${allocs[i].paymentId}'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
