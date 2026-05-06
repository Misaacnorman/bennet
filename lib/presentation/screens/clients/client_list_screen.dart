import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/client_account_providers.dart';
import '../../../domain/client_accounts.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/bennet_surface.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/responsive_data_surface.dart';
import '../../widgets/search_and_filters_bar.dart';
import '../../widgets/status_pill.dart';

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  final _search = TextEditingController();
  String _filter = '';
  bool _includeArchived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSummaries = ref.watch(clientSummariesProvider);

    return BennetScaffold(
      title: 'Clients',
      fab: FloatingActionButton.extended(
        onPressed: () => context.go('/clients/new'),
        icon: const Icon(Icons.add),
        label: const Text('New client'),
      ),
      body: asyncSummaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (summaries) {
          final all = [for (final s in summaries) s.client];
          final summaryByClientId = {for (final s in summaries) s.client.id: s};
          final visibilityFiltered = _includeArchived
              ? all
              : all.where((c) => c.status != ClientStatus.archived).toList();

          final q = _filter.trim().toLowerCase();
          final clients = q.isEmpty
              ? visibilityFiltered
              : visibilityFiltered
                    .where((c) => c.matchesClientDirectoryQuery(q))
                    .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageHeader(
                title: 'Clients',
                subtitle:
                    '${clients.length} shown${_includeArchived ? '' : ' - archived hidden'}',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/payments/new'),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Payment'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/charges/new'),
                    icon: const Icon(Icons.request_quote_outlined),
                    label: const Text('Charge'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SearchAndFiltersBar(
                controller: _search,
                hintText: 'Search name, code, email, phone, notes',
                onChanged: (v) => setState(() => _filter = v),
                filterChips: [
                  FilterChip(
                    label: const Text('Include archived'),
                    selected: _includeArchived,
                    onSelected: (v) => setState(() => _includeArchived = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (clients.isEmpty)
                EmptyState(
                  icon: Icons.people_outline,
                  title: () {
                    if (visibilityFiltered.isEmpty) {
                      return !_includeArchived
                          ? 'No active clients'
                          : 'No clients yet';
                    }
                    return 'No matches';
                  }(),
                  subtitle: () {
                    if (visibilityFiltered.isEmpty) {
                      return !_includeArchived
                          ? 'Archived clients are hidden. Include archived, or create a client.'
                          : 'Create a client to start tracking charges and payments.';
                    }
                    return 'Nothing matches this search.';
                  }(),
                  action: () {
                    if (visibilityFiltered.isEmpty) {
                      return !_includeArchived
                          ? TextButton.icon(
                              onPressed: () =>
                                  setState(() => _includeArchived = true),
                              icon: const Icon(Icons.archive_outlined),
                              label: const Text('Include archived'),
                            )
                          : FilledButton.icon(
                              onPressed: () => context.go('/clients/new'),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: const Text('New client'),
                            );
                    }
                    return TextButton.icon(
                      onPressed: () {
                        _search.clear();
                        setState(() => _filter = '');
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear search'),
                    );
                  }(),
                )
              else
                ResponsiveDataSurface(
                  table: _table(context, clients, summaryByClientId),
                  cards: _cards(context, clients, summaryByClientId),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _table(
    BuildContext context,
    List<Client> clients,
    Map<int, ClientAccountSummary> summaryByClientId,
  ) {
    return BennetDataSurface(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Balance'), numeric: true),
            DataColumn(label: Text('Outstanding'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final c in clients)
              DataRow(
                onSelectChanged: (_) => context.go('/clients/${c.id}'),
                cells: [
                  DataCell(Text(c.clientCode)),
                  DataCell(Text(c.displayName)),
                  DataCell(
                    AmountText(summaryByClientId[c.id]?.balanceMinor ?? 0),
                  ),
                  DataCell(
                    AmountText(
                      summaryByClientId[c.id]?.outstandingChargesMinor ?? 0,
                    ),
                  ),
                  DataCell(_status(c.status)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Record payment',
                          icon: const Icon(Icons.payments_outlined, size: 20),
                          onPressed: () =>
                              context.go('/clients/${c.id}/payment/new'),
                        ),
                        IconButton(
                          tooltip: 'New charge',
                          icon: const Icon(
                            Icons.request_quote_outlined,
                            size: 20,
                          ),
                          onPressed: () =>
                              context.go('/clients/${c.id}/charge/new'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cards(
    BuildContext context,
    List<Client> clients,
    Map<int, ClientAccountSummary> summaryByClientId,
  ) {
    return Column(
      children: [
        for (final c in clients)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BennetSurface(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(c.displayName),
                subtitle: Text(c.clientCode),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _status(c.status),
                    AmountText(summaryByClientId[c.id]?.balanceMinor ?? 0),
                  ],
                ),
                onTap: () => context.go('/clients/${c.id}'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _status(ClientStatus s) {
    final (label, color) = switch (s) {
      ClientStatus.active => ('Active', AppPalette.brandEmerald),
      ClientStatus.paused => ('Paused', AppSemanticColors.attention),
      ClientStatus.archived => ('Archived', AppSemanticColors.neutral),
    };
    return StatusPill(label: label, color: color);
  }
}
