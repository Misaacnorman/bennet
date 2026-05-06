import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/client_account_providers.dart';
import '../../core/money.dart';
import '../layout/responsive_content.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/amount_text.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/bennet_surface.dart';
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
          padding: const EdgeInsets.all(AppSpacing.pagePad),
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _OverviewQuickLink(
                  icon: Icons.request_quote_outlined,
                  label: 'Charges',
                  onPressed: () => context.go('/charges'),
                ),
                _OverviewQuickLink(
                  icon: Icons.payments_outlined,
                  label: 'Payments',
                  onPressed: () => context.go('/payments'),
                ),
                _OverviewQuickLink(
                  icon: Icons.description_outlined,
                  label: 'Statements',
                  onPressed: () => context.go('/statements'),
                ),
                _OverviewQuickLink(
                  icon: Icons.add_circle_outline,
                  label: 'New charge',
                  onPressed: () => context.go('/charges/new'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cross = w >= Breakpoints.expanded
                    ? 3
                    : (w >= Breakpoints.compact ? 2 : 1);
                final aspectRatio = switch (cross) {
                  1 => 1.22,
                  2 => 1.36,
                  _ => 1.4,
                };
                return GridView.count(
                  crossAxisCount: cross,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: aspectRatio,
                  children: [
                    MetricTile(
                      title: 'Total balance',
                      value: formatMoney(m.totalBalanceMinor),
                      icon: Icons.account_balance_wallet_outlined,
                      accent: AppSemanticColors.credits,
                    ),
                    MetricTile(
                      title: 'Open charges',
                      value: formatMoney(m.openChargesTotalMinor),
                      icon: Icons.request_quote_outlined,
                      accent: AppSemanticColors.attention,
                    ),
                    MetricTile(
                      title: 'Overdue items',
                      value: '${m.overdueOpenChargeCount}',
                      icon: Icons.schedule_outlined,
                      accent: AppSemanticColors.overdue,
                    ),
                    MetricTile(
                      title: 'Payments (30 days)',
                      value: formatMoney(m.postedPaymentsLast30DaysMinor),
                      icon: Icons.trending_up,
                      accent: AppSemanticColors.credits,
                    ),
                    MetricTile(
                      title: 'Active clients',
                      value: '${m.activeClientCount}',
                      icon: Icons.groups_outlined,
                      accent: AppSemanticColors.info,
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

/// Compact Overview shortcut aligned with refreshed [ChipTheme].
class _OverviewQuickLink extends StatelessWidget {
  const _OverviewQuickLink({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icon, size: 17, color: scheme.primary),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: onPressed,
    );
  }
}

class _ActivityLeading extends StatelessWidget {
  const _ActivityLeading({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.14,
        ),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: accent),
    );
  }
}

class _OverviewActivitySection extends ConsumerWidget {
  const _OverviewActivitySection();

  static final _df = DateFormat.yMMMd();

  /// ASCII separators avoid Windows / encoding quirks in middot-heavy strings.
  static String sep(String a, String b) => '$a - $b';

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
          data: (regRows) {
            final clientName = {for (final c in clients) c.id: c.displayName};

            final recent = payments.take(5).toList();
            final openCharges = regRows.where((r) => r.openMinor > 0).toList()
              ..sort((a, b) {
                final ad = a.charge.dueDate;
                final bd = b.charge.dueDate;
                if (ad == null && bd == null) {
                  return b.charge.issuedAt.compareTo(a.charge.issuedAt);
                }
                if (ad == null) return 1;
                if (bd == null) return -1;
                final c0 = ad.compareTo(bd);
                return c0 != 0 ? c0 : b.charge.issuedAt.compareTo(a.charge.issuedAt);
              });
            final topOpen = openCharges.take(5).toList();

            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            final sectionStyle = theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text('Recent payments', style: sectionStyle),
                    ),
                    if (recent.isNotEmpty)
                      TextButton(
                        onPressed: () => context.go('/payments'),
                        child: const Text('See all'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'No payments recorded yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  BennetSurface(
                    padding: EdgeInsets.zero,
                    accent: AppSemanticColors.credits,
                    child: Column(
                      children: [
                        for (var i = 0; i < recent.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            leading: const _ActivityLeading(
                              icon: Icons.payments_outlined,
                              accent: AppSemanticColors.credits,
                            ),
                            title: Text(
                              clientName[recent[i].clientId] ??
                                  'Client #${recent[i].clientId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              sep(
                                sep(
                                  _df.format(recent[i].receivedAt),
                                  recent[i].method.name,
                                ),
                                '#${recent[i].receiptNumber ?? recent[i].id}',
                              ),
                            ),
                            trailing: AmountText(recent[i].amountMinor),
                            onTap: () =>
                                context.go('/payments/${recent[i].id}'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Text('Open charges', style: sectionStyle)),
                    if (topOpen.isNotEmpty)
                      TextButton(
                        onPressed: () => context.go('/charges'),
                        child: const Text('See all'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (topOpen.isEmpty)
                  Text(
                    'No open charges.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  BennetSurface(
                    padding: EdgeInsets.zero,
                    accent: AppSemanticColors.attention,
                    child: Column(
                      children: [
                        for (var i = 0; i < topOpen.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            leading: const _ActivityLeading(
                              icon: Icons.request_quote_outlined,
                              accent: AppSemanticColors.attention,
                            ),
                            title: Text(
                              topOpen[i].charge.description ?? 'Charge',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(() {
                              final clientLine = topOpen[i].clientDisplayName;
                              final issue =
                                  _df.format(topOpen[i].charge.issuedAt);
                              final due = topOpen[i].charge.dueDate != null
                                  ? 'Due ${_df.format(topOpen[i].charge.dueDate!)}'
                                  : null;
                              if (due == null) {
                                return sep(clientLine, issue);
                              }
                              return sep(sep(clientLine, issue), due);
                            }()),
                            trailing: AmountText(topOpen[i].openMinor),
                            onTap: () =>
                                context.go('/charges/${topOpen[i].charge.id}'),
                          ),
                        ],
                      ],
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
