import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/client_account_providers.dart';
import '../../../domain/client_accounts.dart';
import '../../layout/responsive_content.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/responsive_data_surface.dart';
import '../../widgets/search_and_filters_bar.dart';
import '../../widgets/status_pill.dart';

class ChargeListScreen extends ConsumerStatefulWidget {
  const ChargeListScreen({super.key});

  @override
  ConsumerState<ChargeListScreen> createState() => _ChargeListScreenState();
}

class _ChargeListScreenState extends ConsumerState<ChargeListScreen> {
  final _search = TextEditingController();
  String _filter = '';
  ChargeStatus? _statusFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Color _statusColor(ChargeStatus s, ThemeData theme) => switch (s) {
        ChargeStatus.open => Colors.blue.shade800,
        ChargeStatus.paid => Colors.green.shade800,
        ChargeStatus.voided => theme.colorScheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(chargesRegisterProvider);
    final clientsAsync = ref.watch(clientsProvider);

    return BennetScaffold(
      title: 'Charges',
      contentWidth: ContentWidthMode.wide,
      fab: FloatingActionButton.extended(
        onPressed: () => context.go('/charges/new'),
        icon: const Icon(Icons.add),
        label: const Text('Charge'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (charges) => clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('$err')),
          data: (clients) {
            final clientName = {for (final c in clients) c.id: c.displayName};
            final filtered = _filteredCharges(charges, clientName)
              ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
            final df = DateFormat.yMMMd();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PageHeader(
                  title: 'Charges',
                  subtitle:
                      '${filtered.length} shown · ${charges.length} total',
                ),
                const SizedBox(height: 12),
                SearchAndFiltersBar(
                  controller: _search,
                  hintText: 'Search description or client',
                  onChanged: (v) => setState(() => _filter = v),
                  filterChips: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _statusFilter == null,
                      onSelected: (_) =>
                          setState(() => _statusFilter = null),
                    ),
                    FilterChip(
                      label: const Text('Open'),
                      selected: _statusFilter == ChargeStatus.open,
                      onSelected: (_) =>
                          setState(() => _statusFilter = ChargeStatus.open),
                    ),
                    FilterChip(
                      label: const Text('Paid'),
                      selected: _statusFilter == ChargeStatus.paid,
                      onSelected: (_) =>
                          setState(() => _statusFilter == ChargeStatus.paid),
                    ),
                    FilterChip(
                      label: const Text('Voided'),
                      selected: _statusFilter == ChargeStatus.voided,
                      onSelected: (_) =>
                          setState(() => _statusFilter = ChargeStatus.voided),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (charges.isEmpty)
                  EmptyState(
                    icon: Icons.request_quote_outlined,
                    title: 'No charges yet',
                    subtitle:
                        'Issue charges from a client record to track amounts billed.',
                    action: OutlinedButton.icon(
                      onPressed: () => context.go('/clients'),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Go to clients'),
                    ),
                  )
                else if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No matching charges',
                    subtitle:
                        'Try clearing search or changing the status filter.',
                    action: OutlinedButton(
                      onPressed: () => setState(() {
                        _filter = '';
                        _search.clear();
                        _statusFilter = null;
                      }),
                      child: const Text('Clear filters'),
                    ),
                  )
                else
                  ResponsiveDataSurface(
                    table:
                        _chargeTable(context, filtered, clientName, df, theme),
                    cards: _chargeCards(
                      context,
                      filtered,
                      clientName,
                      df,
                      theme,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<ClientCharge> _filteredCharges(
    List<ClientCharge> charges,
    Map<int, String> clientName,
  ) {
    var list = charges;
    if (_statusFilter != null) {
      list = list.where((c) => c.status == _statusFilter).toList();
    }
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      final name = clientName[c.clientId]?.toLowerCase() ?? '';
      final desc = (c.description ?? '').toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  Widget _chargeTable(
    BuildContext context,
    List<ClientCharge> rows,
    Map<int, String> clientName,
    DateFormat df,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Issued')),
            DataColumn(label: Text('Client')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Due')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Amount'), numeric: true),
          ],
          rows: [
            for (final ch in rows)
              DataRow(
                onSelectChanged: (_) => context.go('/clients/${ch.clientId}'),
                cells: [
                  DataCell(Text(df.format(ch.issuedAt))),
                  DataCell(
                    Text(
                      clientName[ch.clientId] ?? '#${ch.clientId}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(
                    Text(
                      ch.description ?? 'Charge',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(
                    Text(
                      ch.dueDate != null ? df.format(ch.dueDate!) : '—',
                    ),
                  ),
                  DataCell(
                    StatusPill(
                      label: ch.status.name,
                      color: _statusColor(ch.status, theme),
                    ),
                  ),
                  DataCell(AmountText(ch.amountMinor)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chargeCards(
    BuildContext context,
    List<ClientCharge> rows,
    Map<int, String> clientName,
    DateFormat df,
    ThemeData theme,
  ) {
    return Column(
      children: [
        for (final ch in rows)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(ch.description ?? 'Charge'),
              subtitle: Text(
                '${clientName[ch.clientId] ?? 'Client #${ch.clientId}'} · '
                '${df.format(ch.issuedAt)}'
                '${ch.dueDate != null ? ' · Due ${df.format(ch.dueDate!)}' : ''}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(ch.amountMinor),
                  StatusPill(
                    label: ch.status.name,
                    color: _statusColor(ch.status, theme),
                  ),
                ],
              ),
              onTap: () => context.go('/clients/${ch.clientId}'),
            ),
          ),
      ],
    );
  }
}
