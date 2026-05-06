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
  ChargeLedgerStatus? _statusFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Color _ledgerStatusColor(ChargeLedgerStatus s) => switch (s) {
    ChargeLedgerStatus.open => AppSemanticColors.attention,
    ChargeLedgerStatus.paid => AppSemanticColors.credits,
    ChargeLedgerStatus.overdue => AppSemanticColors.overdue,
    ChargeLedgerStatus.voided => AppSemanticColors.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chargesRegisterProvider);

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
        data: (charges) {
          final filtered = _filteredCharges(charges)
            ..sort((a, b) => b.charge.issuedAt.compareTo(a.charge.issuedAt));
          final df = DateFormat.yMMMd();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageHeader(
                title: 'Charges',
                subtitle:
                    '${filtered.length} shown - ${charges.length} total',
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
                    onSelected: (_) => setState(() => _statusFilter = null),
                  ),
                  FilterChip(
                    label: const Text('Open'),
                    selected: _statusFilter == ChargeLedgerStatus.open,
                    onSelected: (_) => setState(
                      () => _statusFilter = ChargeLedgerStatus.open,
                    ),
                  ),
                  FilterChip(
                    label: const Text('Paid'),
                    selected: _statusFilter == ChargeLedgerStatus.paid,
                    onSelected: (_) => setState(
                      () => _statusFilter = ChargeLedgerStatus.paid,
                    ),
                  ),
                  FilterChip(
                    label: const Text('Overdue'),
                    selected: _statusFilter == ChargeLedgerStatus.overdue,
                    onSelected: (_) => setState(
                      () => _statusFilter = ChargeLedgerStatus.overdue,
                    ),
                  ),
                  FilterChip(
                    label: const Text('Voided'),
                    selected: _statusFilter == ChargeLedgerStatus.voided,
                    onSelected: (_) => setState(
                      () => _statusFilter = ChargeLedgerStatus.voided,
                    ),
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
                  table: _chargeTable(context, filtered, df),
                  cards: _chargeCards(context, filtered, df),
                ),
            ],
          );
        },
      ),
    );
  }

  List<ChargeRegisterRow> _filteredCharges(List<ChargeRegisterRow> charges) {
    var list = charges;
    if (_statusFilter != null) {
      list = list
          .where((r) => r.ledgerStatus == _statusFilter)
          .toList();
    }
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((r) {
      final name = r.clientDisplayName.toLowerCase();
      final code = r.clientCode.toLowerCase();
      final desc = (r.charge.description ?? '').toLowerCase();
      return name.contains(q) ||
          code.contains(q) ||
          desc.contains(q) ||
          'charge #${r.charge.id}'.contains(q);
    }).toList();
  }

  Widget _chargeTable(
    BuildContext context,
    List<ChargeRegisterRow> rows,
    DateFormat df,
  ) {
    return BennetDataSurface(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Issued')),
            DataColumn(label: Text('Client')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Due')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Original'), numeric: true),
            DataColumn(label: Text('Open'), numeric: true),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                onSelectChanged: (_) =>
                    context.go('/charges/${r.charge.id}'),
                cells: [
                  DataCell(Text(df.format(r.charge.issuedAt))),
                  DataCell(
                    Text(
                      r.clientDisplayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(
                    Text(
                      r.charge.description ?? 'Charge',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(
                    Text(
                      r.charge.dueDate != null
                          ? df.format(r.charge.dueDate!)
                          : '—',
                    ),
                  ),
                  DataCell(
                    StatusPill(
                      label: r.ledgerStatus.name,
                      color: _ledgerStatusColor(r.ledgerStatus),
                    ),
                  ),
                  DataCell(AmountText(r.originalAmountMinor)),
                  DataCell(AmountText(r.openMinor)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chargeCards(
    BuildContext context,
    List<ChargeRegisterRow> rows,
    DateFormat df,
  ) {
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BennetSurface(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(r.charge.description ?? 'Charge'),
                subtitle: Text(
                  '${r.clientDisplayName} - ${df.format(r.charge.issuedAt)}'
                  '${r.charge.dueDate != null ? ' - Due ${df.format(r.charge.dueDate!)}' : ''}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(r.openMinor),
                    StatusPill(
                      label: r.ledgerStatus.name,
                      color: _ledgerStatusColor(r.ledgerStatus),
                    ),
                  ],
                ),
                onTap: () => context.go('/charges/${r.charge.id}'),
              ),
            ),
          ),
      ],
    );
  }
}
