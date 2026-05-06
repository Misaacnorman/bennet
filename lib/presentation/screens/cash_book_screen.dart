import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../../core/period_math.dart';
import '../../domain/entities.dart';
import '../layout/responsive_content.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/bennet_surface.dart';

class CashBookScreen extends ConsumerStatefulWidget {
  const CashBookScreen({super.key});

  @override
  ConsumerState<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends ConsumerState<CashBookScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(defaultBookProvider);

    return bookAsync.when(
      loading: () => const BennetScaffold(
        title: 'Cash book',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Cash book',
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
        final openingAsync = ref.watch(
          openingBalanceProvider((
            bookId: book.id,
            year: _month.year,
            month: _month.month,
          )),
        );

        return openingAsync.when(
          loading: () => const BennetScaffold(
            title: 'Cash book',
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => BennetScaffold(
            title: 'Cash book',
            body: Center(child: Text('$e')),
          ),
          data: (opening) => txsAsync.when(
            loading: () => const BennetScaffold(
              title: 'Cash book',
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => BennetScaffold(
              title: 'Cash book',
              body: Center(child: Text('$e')),
            ),
            data: (txs) {
              final sorted = List<LedgerTransaction>.from(txs);
              final runs = runningBalances(
                openingMinor: opening,
                sortedAscending: sorted,
              );
              return BennetScaffold(
                title: 'Cash book',
                contentWidth: ContentWidthMode.wide,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: _pickMonth,
                  ),
                ],
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final useTable =
                        constraints.maxWidth >= Breakpoints.expanded;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            DateFormat.yMMMM().format(_month),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Opening: ${formatMoney(opening)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: sorted.isEmpty
                              ? const Center(
                                  child: Text('No entries this month.'),
                                )
                              : useTable
                              ? _cashTable(context, sorted, runs)
                              : Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    8,
                                    8,
                                    8,
                                  ),
                                  child: BennetSurface(
                                    padding: EdgeInsets.zero,
                                    child: _cashList(context, sorted, runs),
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _cashList(
    BuildContext context,
    List<LedgerTransaction> sorted,
    List<int> runs,
  ) {
    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final t = sorted[i];
        final bal = runs[i];
        return ListTile(
          dense: true,
          title: Text(t.categoryName ?? ''),
          subtitle: Text(
            '${DateFormat.yMMMd().format(t.occurredAt)} - ${t.type == TxType.income ? 'In' : 'Out'}',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${t.type == TxType.income ? '+' : '-'}${formatMoney(t.amountMinor)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                formatMoney(bal),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cashTable(
    BuildContext context,
    List<LedgerTransaction> sorted,
    List<int> runs,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: BennetDataSurface(
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Account')),
                  DataColumn(label: Text('Amount'), numeric: true),
                  DataColumn(label: Text('Balance'), numeric: true),
                ],
                rows: [
                  for (var i = 0; i < sorted.length; i++)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(DateFormat.yMMMd().format(sorted[i].occurredAt)),
                        ),
                        DataCell(
                          Text(sorted[i].type == TxType.income ? 'In' : 'Out'),
                        ),
                        DataCell(Text(sorted[i].categoryName ?? '')),
                        DataCell(Text(sorted[i].accountName ?? '')),
                        DataCell(
                          Text(
                            '${sorted[i].type == TxType.income ? '+' : '-'}${formatMoney(sorted[i].amountMinor)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(Text(formatMoney(runs[i]))),
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
}
