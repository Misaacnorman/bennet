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

class PaymentListScreen extends ConsumerStatefulWidget {
  const PaymentListScreen({super.key});

  @override
  ConsumerState<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends ConsumerState<PaymentListScreen> {
  final _search = TextEditingController();
  String _filter = '';
  PaymentStatus? _statusFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(paymentsRegisterProvider);
    final clientsAsync = ref.watch(clientsProvider);

    return BennetScaffold(
      title: 'Payments',
      contentWidth: ContentWidthMode.wide,
      fab: FloatingActionButton.extended(
        onPressed: () => context.go('/payments/new'),
        icon: const Icon(Icons.add),
        label: const Text('Payment'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (payments) => clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('$err')),
          data: (clients) {
            final clientName = {for (final c in clients) c.id: c.displayName};
            final filtered = _filteredPayments(payments, clientName);
            final df = DateFormat.yMMMd();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PageHeader(
                  title: 'Payments',
                  subtitle:
                      '${filtered.length} shown - ${payments.length} total',
                ),
                const SizedBox(height: 12),
                SearchAndFiltersBar(
                  controller: _search,
                  hintText: 'Search client, receipt #, reference, method',
                  onChanged: (v) => setState(() => _filter = v),
                  filterChips: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _statusFilter == null,
                      onSelected: (_) => setState(() => _statusFilter = null),
                    ),
                    FilterChip(
                      label: const Text('Posted'),
                      selected: _statusFilter == PaymentStatus.posted,
                      onSelected: (_) =>
                          setState(() => _statusFilter = PaymentStatus.posted),
                    ),
                    FilterChip(
                      label: const Text('Reversed'),
                      selected: _statusFilter == PaymentStatus.reversed,
                      onSelected: (_) => setState(
                        () => _statusFilter = PaymentStatus.reversed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (payments.isEmpty)
                  EmptyState(
                    icon: Icons.payments_outlined,
                    title: 'No payments yet',
                    subtitle:
                        'Record a payment from a client or use Quick Actions on Overview.',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/payments/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Record payment'),
                    ),
                  )
                else if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No matching payments',
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
                    table: _paymentTable(context, filtered, clientName, df),
                    cards: _paymentCards(context, filtered, clientName, df),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<ClientPayment> _filteredPayments(
    List<ClientPayment> payments,
    Map<int, String> clientName,
  ) {
    var list = payments;
    if (_statusFilter != null) {
      list = list.where((p) => p.status == _statusFilter).toList();
    }
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((p) {
      final name = clientName[p.clientId]?.toLowerCase() ?? '';
      final ref = (p.reference ?? '').toLowerCase();
      final notes = (p.notes ?? '').toLowerCase();
      final receipt = '${p.receiptNumber ?? p.id}';
      return name.contains(q) ||
          ref.contains(q) ||
          notes.contains(q) ||
          receipt.contains(q) ||
          p.method.name.toLowerCase().contains(q);
    }).toList();
  }

  Widget _paymentTable(
    BuildContext context,
    List<ClientPayment> rows,
    Map<int, String> clientName,
    DateFormat df,
  ) {
    return BennetDataSurface(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Client')),
            DataColumn(label: Text('Receipt')),
            DataColumn(label: Text('Method')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Amount'), numeric: true),
          ],
          rows: [
            for (final p in rows)
              DataRow(
                onSelectChanged: (_) => context.go('/payments/${p.id}'),
                cells: [
                  DataCell(Text(df.format(p.receivedAt))),
                  DataCell(
                    Text(
                      clientName[p.clientId] ?? '#${p.clientId}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(Text('#${p.receiptNumber ?? p.id}')),
                  DataCell(Text(p.method.name)),
                  DataCell(
                    StatusPill(
                      label: p.status.name,
                      color: switch (p.status) {
                        PaymentStatus.posted => AppSemanticColors.credits,
                        PaymentStatus.reversed => AppSemanticColors.overdue,
                      },
                    ),
                  ),
                  DataCell(AmountText(p.amountMinor)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _paymentCards(
    BuildContext context,
    List<ClientPayment> rows,
    Map<int, String> clientName,
    DateFormat df,
  ) {
    return Column(
      children: [
        for (final p in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BennetSurface(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(clientName[p.clientId] ?? 'Client #${p.clientId}'),
                subtitle: Text(
                  '${df.format(p.receivedAt)} - ${p.method.name} - '
                  '#${p.receiptNumber ?? p.id}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(p.amountMinor),
                    StatusPill(
                      label: p.status.name,
                      color: switch (p.status) {
                        PaymentStatus.posted => AppSemanticColors.credits,
                        PaymentStatus.reversed => AppSemanticColors.overdue,
                      },
                    ),
                  ],
                ),
                onTap: () => context.go('/payments/${p.id}'),
              ),
            ),
          ),
      ],
    );
  }
}
