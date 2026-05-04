import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../../core/period_math.dart';
import '../../domain/entities.dart';
import '../widgets/app_scaffold.dart';

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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: _pickMonth,
                  ),
                ],
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Text(
                            DateFormat.yMMMM().format(_month),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Text(
                            'Opening: ${formatMoney(opening)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: sorted.isEmpty
                          ? const Center(child: Text('No entries this month.'))
                          : ListView.separated(
                              itemCount: sorted.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final t = sorted[i];
                                final bal = runs[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(t.categoryName ?? ''),
                                  subtitle: Text(
                                    '${DateFormat.yMMMd().format(t.occurredAt)} · ${t.type == TxType.income ? 'In' : 'Out'}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${t.type == TxType.income ? '+' : '-'}${formatMoney(t.amountMinor)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        formatMoney(bal),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
