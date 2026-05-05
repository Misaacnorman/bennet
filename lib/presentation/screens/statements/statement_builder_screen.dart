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
import '../../../services/statement_pdf_service.dart';
import '../../layout/responsive_content.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/responsive_data_surface.dart';

class StatementBuilderScreen extends ConsumerStatefulWidget {
  const StatementBuilderScreen({super.key, required this.clientId});

  final int clientId;

  @override
  ConsumerState<StatementBuilderScreen> createState() =>
      _StatementBuilderScreenState();
}

class _StatementBuilderScreenState
    extends ConsumerState<StatementBuilderScreen> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _from = DateTime(n.year, n.month, 1);
    _to = DateTime(n.year, n.month + 1, 0);
  }

  BuildStatementInput get _input => BuildStatementInput(
    clientId: widget.clientId,
    fromDate: _from,
    toDate: _to,
  );

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _from = d;
        if (_from.isAfter(_to)) _to = _from;
      });
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _to = d;
        if (_to.isBefore(_from)) _from = _to;
      });
    }
  }

  Future<void> _saveAndShare() async {
    if (_to.isBefore(_from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be on or after start date.'),
        ),
      );
      return;
    }
    try {
      final repo = await ref.clientAccounts;
      final preview = await ref.read(
        statementPreviewProvider((
          clientId: widget.clientId,
          from: _from,
          to: _to,
        )).future,
      );
      final results = await Future.wait<Object?>([
        repo.saveStatement(_input),
        ref.read(businessNameProvider.future),
      ]);
      final savedId = results[0] as int;
      final businessName = results[1] as String?;
      ClientStatement? savedStmt;
      final stmts = await repo.listStatements(clientId: widget.clientId);
      for (final s in stmts) {
        if (s.id == savedId) {
          savedStmt = s;
          break;
        }
      }
      if (!mounted) return;
      invalidateClientAccounts(ref, clientId: widget.clientId);
      ref.invalidate(statementPreviewProvider);
      ref.invalidate(statementsHistoryProvider(null));
      ref.invalidate(statementsHistoryProvider(widget.clientId));
      final bytes = await buildStatementPdf(
        preview: preview,
        businessName: businessName,
        statementNumber: savedStmt?.statementNumber,
        issuedAt: savedStmt?.issuedAt,
      );
      if (!mounted) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/statement_${preview.client.clientCode}_${preview.fromDateMs}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat.yMMMd();
    final clientAsync = ref.watch(clientProvider(widget.clientId));
    final previewAsync = ref.watch(
      statementPreviewProvider((
        clientId: widget.clientId,
        from: _from,
        to: _to,
      )),
    );

    return BennetScaffold(
      title: 'Statement',
      contentWidth: ContentWidthMode.wide,
      actions: [
        IconButton(
          tooltip: 'Statement history',
          onPressed: () => context.go('/statements'),
          icon: const Icon(Icons.history_edu_outlined),
        ),
        FilledButton.icon(
          onPressed: _saveAndShare,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Save & share'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          clientAsync.when(
            loading: () => PageHeader(
              title: 'Statement',
              subtitle: 'Client #${widget.clientId}',
            ),
            error: (_, _) => PageHeader(
              title: 'Statement',
              subtitle: 'Client #${widget.clientId}',
            ),
            data: (client) => PageHeader(
              title: 'Statement',
              subtitle: client == null
                  ? 'Client not found'
                  : '${client.displayName} · ${client.clientCode}',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/clients/${widget.clientId}'),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Client'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a period that includes all charges and payments you want on this statement.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('From'),
                      subtitle: Text(df.format(_from)),
                      trailing: IconButton(
                        tooltip: 'Pick start date',
                        onPressed: _pickFrom,
                        icon: const Icon(Icons.calendar_today_outlined),
                      ),
                      onTap: _pickFrom,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('To'),
                      subtitle: Text(df.format(_to)),
                      trailing: IconButton(
                        tooltip: 'Pick end date',
                        onPressed: _pickTo,
                        icon: const Icon(Icons.calendar_today_outlined),
                      ),
                      onTap: _pickTo,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          previewAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SelectableText('$e'),
            data: (p) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Preview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${p.lines.length} line${p.lines.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Opening',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                formatMoney(p.openingBalanceMinor),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Closing',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                formatMoney(p.closingBalanceMinor),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (p.lines.isEmpty)
                  EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No activity this period',
                    subtitle:
                        'Nothing falls between these dates for this client. '
                        'Try a wider range or add charges and payments first.',
                  )
                else
                  ResponsiveDataSurface(
                    table: _statementTable(context, p, df),
                    cards: _statementCards(context, p, df),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statementTable(
    BuildContext context,
    StatementPreview p,
    DateFormat df,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Activity')),
            DataColumn(label: Text('Amount'), numeric: true),
            DataColumn(label: Text('Balance'), numeric: true),
          ],
          rows: [
            for (final line in p.lines)
              DataRow(
                cells: [
                  DataCell(Text(df.format(line.occurredAt))),
                  DataCell(
                    SizedBox(
                      width: 280,
                      child: Text(
                        line.detail != null && line.detail!.trim().isNotEmpty
                            ? '${line.label} — ${line.detail}'
                            : line.label,
                        softWrap: true,
                      ),
                    ),
                  ),
                  DataCell(AmountText(line.deltaMinor)),
                  DataCell(Text(formatMoney(line.runningBalanceMinor))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statementCards(
    BuildContext context,
    StatementPreview p,
    DateFormat df,
  ) {
    return Column(
      children: [
        for (final line in p.lines)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(line.label),
              subtitle: Text(
                '${df.format(line.occurredAt)}'
                '${line.detail != null && line.detail!.trim().isNotEmpty ? '\n${line.detail}' : ''}',
              ),
              isThreeLine:
                  line.detail != null && line.detail!.trim().isNotEmpty,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(line.deltaMinor),
                  Text(
                    formatMoney(line.runningBalanceMinor),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
