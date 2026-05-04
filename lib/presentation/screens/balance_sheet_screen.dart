import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../../domain/entities.dart';
import '../layout/responsive_content.dart';
import '../widgets/app_scaffold.dart';

class BalanceSheetScreen extends ConsumerWidget {
  const BalanceSheetScreen({super.key});

  Future<void> _addItem(BuildContext context, WidgetRef ref, int bookId) async {
    BalanceSection section = BalanceSection.asset;
    final labelCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Balance sheet line'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<BalanceSection>(
                    initialValue: section,
                    items: BalanceSection.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) =>
                        setSt(() => section = v ?? BalanceSection.asset),
                  ),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(labelText: 'Label'),
                  ),
                  TextField(
                    controller: amtCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d{0,2}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final minor = parseMoneyInput(amtCtrl.text);
                if (minor == null || labelCtrl.text.trim().isEmpty) return;
                final repo = await ref.read(ledgerRepositoryProvider.future);
                await repo.insertBalanceSheetItem(
                  bookId: bookId,
                  section: section,
                  label: labelCtrl.text.trim(),
                  amountMinor: minor,
                );
                ref.invalidate(balanceSheetItemsProvider(bookId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(defaultBookProvider);
    final now = DateTime.now();

    return bookAsync.when(
      loading: () => const BennetScaffold(
        title: 'Balance sheet',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Balance sheet',
        body: Center(child: Text('$e')),
      ),
      data: (book) {
        final itemsAsync = ref.watch(balanceSheetItemsProvider(book.id));
        final summaryAsync = ref.watch(
          monthlySummaryProvider((
            bookId: book.id,
            year: now.year,
            month: now.month,
          )),
        );

        return itemsAsync.when(
          loading: () => const BennetScaffold(
            title: 'Balance sheet',
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => BennetScaffold(
            title: 'Balance sheet',
            body: Center(child: Text('$e')),
          ),
          data: (items) => summaryAsync.when(
            loading: () => const BennetScaffold(
              title: 'Balance sheet',
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => BennetScaffold(
              title: 'Balance sheet',
              body: Center(child: Text('$e')),
            ),
            data: (summary) {
              final assets = items
                  .where((i) => i.section == BalanceSection.asset)
                  .toList();
              final lia = items
                  .where((i) => i.section == BalanceSection.liability)
                  .toList();
              final eq = items
                  .where((i) => i.section == BalanceSection.equity)
                  .toList();

              int sumOf(List<BalanceSheetItem> xs) =>
                  xs.fold(0, (a, b) => a + b.amountMinor);

              return BennetScaffold(
                title: 'Balance sheet',
                fab: FloatingActionButton(
                  onPressed: () => _addItem(context, ref, book.id),
                  child: const Icon(Icons.add),
                ),
                body: LayoutBuilder(
                  builder: (context, c) {
                    final twoCol = c.maxWidth >= Breakpoints.medium;
                    final intro = Text(
                      'Cash-centric view',
                      style: Theme.of(context).textTheme.titleMedium,
                    );
                    final bookCard = Card(
                      child: ListTile(
                        title: const Text(
                          'Book balance (month closing, all accounts)',
                        ),
                        subtitle: Text(
                          '${now.year}-${now.month.toString().padLeft(2, '0')}',
                        ),
                        trailing: Text(
                          formatMoney(summary.closingMinor),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                    final footer = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Totals include manual lines only; compare book balance above to cash activity.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Assets subtotal: ${formatMoney(sumOf(assets))}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text('Liabilities subtotal: ${formatMoney(sumOf(lia))}'),
                        Text('Equity subtotal: ${formatMoney(sumOf(eq))}'),
                      ],
                    );

                    if (!twoCol) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          intro,
                          const SizedBox(height: 8),
                          bookCard,
                          const SizedBox(height: 24),
                          _section(context, 'Manual assets', assets, ref, book.id),
                          _section(context, 'Manual liabilities', lia, ref, book.id),
                          _section(context, 'Manual equity', eq, ref, book.id),
                          footer,
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          intro,
                          const SizedBox(height: 8),
                          bookCard,
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _section(
                                      context,
                                      'Manual assets',
                                      assets,
                                      ref,
                                      book.id,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _section(
                                      context,
                                      'Manual liabilities',
                                      lia,
                                      ref,
                                      book.id,
                                    ),
                                    _section(
                                      context,
                                      'Manual equity',
                                      eq,
                                      ref,
                                      book.id,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          footer,
                        ],
                      ),
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

  Widget _section(
    BuildContext context,
    String title,
    List<BalanceSheetItem> rows,
    WidgetRef ref,
    int bookId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        ...rows.map(
          (r) => ListTile(
            title: Text(r.label),
            trailing: Text(formatMoney(r.amountMinor)),
            onLongPress: () async {
              final repo = await ref.read(ledgerRepositoryProvider.future);
              await repo.deleteBalanceSheetItem(r.id);
              ref.invalidate(balanceSheetItemsProvider(bookId));
            },
          ),
        ),
        if (rows.isEmpty) const Text('—'),
        const SizedBox(height: 12),
      ],
    );
  }
}
