import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/client_account_providers.dart';
import '../../domain/client_accounts.dart';
import '../../core/money.dart';
import '../layout/responsive_content.dart';
import '../widgets/amount_text.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/metric_tile.dart';
import '../widgets/page_header.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(overviewProvider);

    return metrics.when(
      loading: () => const BennetScaffold(
        title: 'Overview',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Overview',
        body: Center(child: Text('$e')),
      ),
      data: (m) => BennetScaffold(
        title: 'Overview',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageHeader(
              title: 'Overview',
              subtitle: 'Balances, collections, and open charges',
              actions: [
                FilledButton.icon(
                  onPressed: () => context.go('/clients/new'),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('New client'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/payments/new'),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Record payment'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.request_quote_outlined, size: 18),
                  label: const Text('Charges'),
                  onPressed: () => context.go('/charges'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Payments'),
                  onPressed: () => context.go('/payments'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Statements'),
                  onPressed: () => context.go('/statements'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.request_quote_outlined, size: 18),
                  label: const Text('New charge'),
                  onPressed: () => context.go('/charges/new'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cross =
                    w >= Breakpoints.expanded ? 3 : (w >= Breakpoints.compact ? 2 : 1);
                return GridView.count(
                  crossAxisCount: cross,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    MetricTile(
                      title: 'Total balance',
                      value: formatMoney(m.totalBalanceMinor),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    MetricTile(
                      title: 'Open charges',
                      value: formatMoney(m.openChargesTotalMinor),
                      icon: Icons.request_quote_outlined,
                      accent: Colors.amber.shade800,
                    ),
                    MetricTile(
                      title: 'Overdue items',
                      value: '${m.overdueOpenChargeCount}',
                      icon: Icons.schedule_outlined,
                      accent: Colors.deepOrange.shade700,
                    ),
                    MetricTile(
                      title: 'Payments (30 days)',
                      value: formatMoney(m.postedPaymentsLast30DaysMinor),
                      icon: Icons.trending_up,
                      accent: Colors.green.shade800,
                    ),
                    MetricTile(
                      title: 'Active clients',
                      value: '${m.activeClientCount}',
                      icon: Icons.groups_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            const _OverviewActivitySection(),
          ],
        ),
      ),
    );
  }
}

class _OverviewActivitySection extends ConsumerWidget {
  const _OverviewActivitySection();

  static final _df = DateFormat.yMMMd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsRegisterProvider);
    final clientsAsync = ref.watch(clientsProvider);
    final chargesAsync = ref.watch(chargesRegisterProvider);

    return paymentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('$e'),
      data: (payments) => clientsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (err, _) => const SizedBox.shrink(),
        data: (clients) => chargesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (err, _) => const SizedBox.shrink(),
          data: (charges) {
            final clientName = {for (final c in clients) c.id: c.displayName};

            final recent = payments.take(5).toList();
            final openCharges = charges
                .where((c) => c.status == ChargeStatus.open)
                .toList()
              ..sort((a, b) {
                final ad = a.dueDate;
                final bd = b.dueDate;
                if (ad == null && bd == null) return b.issuedAt.compareTo(a.issuedAt);
                if (ad == null) return 1;
                if (bd == null) return -1;
                final c = ad.compareTo(bd);
                return c != 0 ? c : b.issuedAt.compareTo(a.issuedAt);
              });
            final topOpen = openCharges.take(5).toList();

            final theme = Theme.of(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent payments',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'No payments recorded yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < recent.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            title: Text(
                              clientName[recent[i].clientId] ??
                                  'Client #${recent[i].clientId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_df.format(recent[i].receivedAt)} · '
                              '${recent[i].method.name} · '
                              '#${recent[i].receiptNumber ?? recent[i].id}',
                            ),
                            trailing: AmountText(recent[i].amountMinor),
                            onTap: () =>
                                context.go('/payments/${recent[i].id}'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/payments'),
                      child: const Text('See all payments'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Open charges',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (topOpen.isEmpty)
                  Text(
                    'No open charges.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < topOpen.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            title: Text(
                              topOpen[i].description ?? 'Charge',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${clientName[topOpen[i].clientId] ?? 'Client #${topOpen[i].clientId}'} · '
                              '${_df.format(topOpen[i].issuedAt)}'
                              '${topOpen[i].dueDate != null ? ' · Due ${_df.format(topOpen[i].dueDate!)}' : ''}',
                            ),
                            trailing: AmountText(topOpen[i].amountMinor),
                            onTap: () =>
                                context.go('/clients/${topOpen[i].clientId}'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/charges'),
                      child: const Text('See all charges'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
