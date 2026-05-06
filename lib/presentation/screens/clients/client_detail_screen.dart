import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/client_account_providers.dart';
import '../../../application/providers.dart';
import '../../../core/money.dart';
import '../../../domain/client_accounts.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/bennet_surface.dart';
import '../../widgets/metric_tile.dart';
import '../../widgets/page_header.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final int clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _voidCharge(BuildContext context, ClientCharge charge) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Void charge'),
          content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Reason'),
            maxLines: 2,
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
              child: const Text('Void'),
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
      await repo.voidCharge(charge.id, reason);
      if (!context.mounted) return;
      invalidateClientAccounts(ref, clientId: widget.clientId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Charge voided')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reversePayment(
    BuildContext context,
    ClientPayment payment,
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
            maxLines: 2,
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
      invalidateClientAccounts(ref, clientId: widget.clientId);
      invalidateLedger(ref);
      ref.invalidate(paymentDetailProvider(payment.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment reversed')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addAdjustment(BuildContext context, Client client) async {
    AdjustmentKind kind = AdjustmentKind.increase;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    DateTime effective = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Adjustment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kind',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                ),
                DropdownButton<AdjustmentKind>(
                  value: kind,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: AdjustmentKind.increase,
                      child: Text('Increase balance'),
                    ),
                    DropdownMenuItem(
                      value: AdjustmentKind.decrease,
                      child: Text('Decrease balance'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => kind = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Effective date'),
                  subtitle: Text(
                    effective.toLocal().toString().split(' ').first,
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: effective,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setLocal(() => effective = d);
                  },
                ),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final minor = parseMoneyInput(amountCtrl.text);
    if (minor == null || minor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }
    try {
      final repo = await ref.clientAccounts;
      await repo.createAdjustment(
        CreateClientAdjustmentInput(
          clientId: client.id,
          kind: kind,
          amountMinor: minor,
          effectiveAt: effective,
          reason: reasonCtrl.text.trim().isEmpty
              ? null
              : reasonCtrl.text.trim(),
        ),
      );
      if (!context.mounted) return;
      invalidateClientAccounts(ref, clientId: widget.clientId);
      ref.invalidate(statementPreviewProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Adjustment saved')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProvider(widget.clientId));
    final summaryAsync = ref.watch(clientSummaryProvider(widget.clientId));
    final cid = widget.clientId;

    return clientAsync.when(
      loading: () => const BennetScaffold(
        title: 'Client',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Client',
        body: Center(child: Text('$e')),
      ),
      data: (client) {
        if (client == null) {
          return const BennetScaffold(
            title: 'Client',
            body: Center(child: Text('Not found')),
          );
        }
        return BennetScaffold(
          title: client.displayName,
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Client actions',
              onSelected: (v) async {
                if (!context.mounted) return;
                final repo = await ref.clientAccounts;
                try {
                  if (v == 'archive') {
                    await repo.archiveClient(cid);
                  } else if (v == 'restore') {
                    await repo.updateClient(
                      UpdateClientInput(
                        id: cid,
                        status: ClientStatus.active,
                      ),
                    );
                  }
                  if (!context.mounted) return;
                  invalidateClientAccounts(ref, clientId: cid);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(v == 'archive'
                          ? 'Archived'
                          : 'Restored to active'),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              },
              itemBuilder: (ctx) => [
                if (client.status != ClientStatus.archived)
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive client'),
                  ),
                if (client.status == ClientStatus.archived)
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('Restore client'),
                  ),
              ],
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: () => context.go('/clients/$cid/edit'),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Add adjustment',
              onPressed: () => _addAdjustment(context, client),
              icon: const Icon(Icons.tune),
            ),
          ],
          fab: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'chg',
                tooltip: 'New charge',
                onPressed: () => context.go('/clients/$cid/charge/new'),
                child: const Icon(Icons.request_quote_outlined),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'pay',
                onPressed: () => context.go('/clients/$cid/payment/new'),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Payment'),
              ),
            ],
          ),
          body: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Summary'),
                  Tab(text: 'Timeline'),
                  Tab(text: 'Registers'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _SummaryTab(
                      client: client,
                      clientId: cid,
                      summaryAsync: summaryAsync,
                      statementsAsync: ref.watch(
                        statementsHistoryProvider(cid),
                      ),
                    ),
                    _TimelineTab(clientId: cid),
                    _RegistersTab(
                      clientId: cid,
                      onVoidCharge: (c) => _voidCharge(context, c),
                      onReversePayment: (p) => _reversePayment(context, p),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.client,
    required this.clientId,
    required this.summaryAsync,
    required this.statementsAsync,
  });

  final Client client;
  final int clientId;
  final AsyncValue<ClientAccountSummary> summaryAsync;
  final AsyncValue<List<ClientStatement>> statementsAsync;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: client.displayName,
          subtitle: '${client.clientCode} - ${client.status.name}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.go('/clients/$clientId/statement'),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Statement'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        summaryAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (s) => LayoutBuilder(
            builder: (context, c) {
              final cross = c.maxWidth >= 600 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cross,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2,
                children: [
                  MetricTile(
                    title: 'Balance',
                    value: formatMoney(s.balanceMinor),
                  ),
                  MetricTile(
                    title: 'Outstanding charges',
                    value: formatMoney(s.outstandingChargesMinor),
                    accent: AppSemanticColors.attention,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Recent statements',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        statementsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => Text('$e'),
          data: (list) {
            if (list.isEmpty) {
              return BennetSurface(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: ListTile(
                  title: Text(
                    'No statements yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            final recent = list.take(6).toList();
            return BennetSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text('Statement #${recent[i].statementNumber}'),
                      subtitle: Text(
                        '${recent[i].fromDate.toLocal().toString().split(' ').first} - ${recent[i].toDate.toLocal().toString().split(' ').first}',
                      ),
                      trailing: AmountText(recent[i].closingBalanceMinor),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  const _TimelineTab({required this.clientId});

  final int clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(
      clientLedgerProvider((clientId: clientId, from: null, to: null)),
    );

    return ledgerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (lines) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lines.length,
        itemBuilder: (context, i) {
          final line = lines[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BennetSurface(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(line.title),
                subtitle: line.subtitle != null ? Text(line.subtitle!) : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(line.deltaMinor),
                    Text(
                      formatMoney(line.balanceAfterMinor),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RegistersTab extends ConsumerWidget {
  const _RegistersTab({
    required this.clientId,
    required this.onVoidCharge,
    required this.onReversePayment,
  });

  final int clientId;
  final void Function(ClientCharge charge) onVoidCharge;
  final void Function(ClientPayment payment) onReversePayment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargesAsync = ref.watch(clientChargesProvider(clientId));
    final paymentsAsync = ref.watch(clientPaymentsProvider(clientId));
    final adjAsync = ref.watch(clientAdjustmentsProvider(clientId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Charges',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        chargesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) {
            if (list.isEmpty) {
              return BennetSurface(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    'No charges',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return BennetSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(list[i].description ?? 'Charge'),
                      subtitle: Text(
                        '${list[i].status.name} - ${list[i].issuedAt.toLocal().toString().split(' ').first}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AmountText(list[i].amountMinor),
                          if (list[i].status == ChargeStatus.open)
                            IconButton(
                              tooltip: 'Void charge',
                              icon: const Icon(Icons.block),
                              onPressed: () => onVoidCharge(list[i]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Payments',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        paymentsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) {
            if (list.isEmpty) {
              return BennetSurface(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    'No payments',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return BennetSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(
                        'Receipt #${list[i].receiptNumber ?? list[i].id} - ${list[i].method.name}',
                      ),
                      subtitle: Text(list[i].reference ?? '—'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AmountText(list[i].amountMinor),
                          if (list[i].status == PaymentStatus.posted)
                            IconButton(
                              tooltip: 'Reverse payment',
                              icon: const Icon(Icons.undo),
                              onPressed: () => onReversePayment(list[i]),
                            ),
                          IconButton(
                            tooltip: 'Details',
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () =>
                                context.go('/payments/${list[i].id}'),
                          ),
                        ],
                      ),
                      onTap: () => context.go('/payments/${list[i].id}'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Adjustments',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        adjAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) {
            if (list.isEmpty) {
              return BennetSurface(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    'None yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return BennetSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(list[i].kind.name),
                      subtitle: Text(list[i].reason ?? '—'),
                      trailing: AmountText(
                        list[i].kind == AdjustmentKind.increase
                            ? list[i].amountMinor
                            : -list[i].amountMinor,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
