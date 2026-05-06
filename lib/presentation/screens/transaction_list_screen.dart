import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../../domain/entities.dart';
import '../layout/responsive_content.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/bennet_surface.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  Future<void> _pickMonth() async {
    final y = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Year'),
        children: [
          for (var i = -2; i <= 2; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, DateTime.now().year + i),
              child: Text('${DateTime.now().year + i}'),
            ),
        ],
      ),
    );
    if (y == null || !mounted) return;
    final m = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Month'),
        children: [
          for (var mo = 1; mo <= 12; mo++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, mo),
              child: Text(DateFormat.MMMM().format(DateTime(y, mo))),
            ),
        ],
      ),
    );
    if (m != null) setState(() => _month = DateTime(y, m));
  }

  Widget _listView(BuildContext context, List<LedgerTransaction> txs) {
    return ListView.separated(
      itemCount: txs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final t = txs[txs.length - 1 - i];
        return ListTile(
          leading: Icon(
            t.type == TxType.income ? Icons.south_west : Icons.north_east,
            color: t.type == TxType.income ? Colors.green : Colors.red,
          ),
          title: Text(t.categoryName ?? 'Category'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${DateFormat.MMMd().format(t.occurredAt)} - ${t.accountName ?? ''}',
              ),
              if (t.linksToPostedPayment && t.sourceId != null)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      context.go('/payments/${t.sourceId}'),
                  child: Text(
                    'Payment ${t.sourceNumber ?? '#${t.sourceId}'}',
                  ),
                ),
            ],
          ),
          trailing: Text(
            (t.type == TxType.income ? '+' : '-') + formatMoney(t.amountMinor),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => context.go('/transactions/${t.id}'),
        );
      },
    );
  }

  Widget _dataTable(BuildContext context, List<LedgerTransaction> txs) {
    final ordered = txs.reversed.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: BennetDataSurface(
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Account')),
                  DataColumn(label: Text('Source')),
                  DataColumn(label: Text('Amount'), numeric: true),
                ],
                rows: [
                  for (final t in ordered)
                    DataRow(
                      onSelectChanged: (_) =>
                          context.go('/transactions/${t.id}'),
                      cells: [
                        DataCell(Text(DateFormat.yMMMd().format(t.occurredAt))),
                        DataCell(
                          Text(t.type == TxType.income ? 'Income' : 'Expense'),
                        ),
                        DataCell(Text(t.categoryName ?? '')),
                        DataCell(Text(t.accountName ?? '')),
                        DataCell(
                          t.linksToPostedPayment && t.sourceId != null
                              ? TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () =>
                                      context.go('/payments/${t.sourceId}'),
                                  child: Text(
                                    t.sourceNumber ?? '#${t.sourceId}',
                                  ),
                                )
                              : const Text('—'),
                        ),
                        DataCell(
                          Text(
                            '${t.type == TxType.income ? '+' : '-'}${formatMoney(t.amountMinor)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: t.type == TxType.income
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(defaultBookProvider);

    return bookAsync.when(
      loading: () => const BennetScaffold(
        title: 'Transactions',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Transactions',
        body: Center(child: Text('$e')),
      ),
      data: (book) {
        final txsAsync = ref.watch(
          transactionsProvider((
            bookId: book.id,
            year: _month.year,
            month: _month.month,
          )),
        );
        return txsAsync.when(
          loading: () => const BennetScaffold(
            title: 'Transactions',
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => BennetScaffold(
            title: 'Transactions',
            body: Center(child: Text('$e')),
          ),
          data: (txs) => BennetScaffold(
            title: 'Transactions',
            contentWidth: ContentWidthMode.wide,
            fab: FloatingActionButton(
              onPressed: () => context.go('/transactions/new'),
              child: const Icon(Icons.add),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: _pickMonth,
                tooltip: 'Month',
              ),
            ],
            body: LayoutBuilder(
              builder: (context, constraints) {
                final useTable = constraints.maxWidth >= Breakpoints.expanded;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Text(
                            DateFormat.yMMMM().format(_month),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: txs.isEmpty
                          ? const Center(
                              child: Text('No transactions this month.'),
                            )
                          : useTable
                          ? _dataTable(context, txs)
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                              child: BennetSurface(
                                padding: EdgeInsets.zero,
                                child: _listView(context, txs),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
