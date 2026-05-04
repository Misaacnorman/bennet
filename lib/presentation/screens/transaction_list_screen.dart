import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../../domain/entities.dart';
import '../widgets/app_scaffold.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
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

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(defaultBookProvider);

    return bookAsync.when(
      loading: () => const BennetScaffold(title: 'Transactions', body: Center(child: CircularProgressIndicator())),
      error: (e, _) => BennetScaffold(title: 'Transactions', body: Center(child: Text('$e'))),
      data: (book) {
        final txsAsync = ref.watch(
          transactionsProvider((bookId: book.id, year: _month.year, month: _month.month)),
        );
        return txsAsync.when(
          loading: () => const BennetScaffold(title: 'Transactions', body: Center(child: CircularProgressIndicator())),
          error: (e, _) => BennetScaffold(title: 'Transactions', body: Center(child: Text('$e'))),
          data: (txs) => BennetScaffold(
            title: 'Transactions',
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
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    DateFormat.yMMMM().format(_month),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: txs.isEmpty
                      ? const Center(child: Text('No transactions this month.'))
                      : ListView.separated(
                          itemCount: txs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final t = txs[txs.length - 1 - i];
                            return ListTile(
                              leading: Icon(
                                t.type == TxType.income ? Icons.south_west : Icons.north_east,
                                color: t.type == TxType.income ? Colors.green : Colors.red,
                              ),
                              title: Text(t.categoryName ?? 'Category'),
                              subtitle: Text(
                                '${DateFormat.MMMd().format(t.occurredAt)} · ${t.accountName ?? ''}',
                              ),
                              trailing: Text(
                                (t.type == TxType.income ? '+' : '-') + formatMoney(t.amountMinor),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              onTap: () => context.go('/transactions/${t.id}'),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
