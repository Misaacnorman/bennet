import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../../domain/entities.dart';
import '../widgets/app_scaffold.dart';

class ReconciliationScreen extends ConsumerStatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  ConsumerState<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends ConsumerState<ReconciliationScreen> {
  int? _bankAccountId;

  Future<void> _addBankAccount() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New bank account'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Account name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final repo = await ref.read(ledgerRepositoryProvider.future);
    final book = await repo.defaultBook();
    await repo.addBankAccount(bookId: book.id, name: name);
    ref.invalidate(accountsProvider(book.id));
    final accounts = await ref.read(accountsProvider(book.id).future);
    final banks = accounts.where((a) => a.kind == AccountKind.bank).toList();
    setState(() => _bankAccountId = banks.isNotEmpty ? banks.last.id : null);
  }

  Future<void> _addLine(int bankAccountId) async {
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime posted = DateTime.now();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Statement line'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(DateFormat.yMMMd().format(posted)),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: posted,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setSt(() => posted = d);
                  },
                ),
                TextField(
                  controller: amtCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount (+ deposit, − withdrawal)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}'))],
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final minor = parseMoneyInput(amtCtrl.text);
                if (minor == null || descCtrl.text.trim().isEmpty) return;
                final repo = await ref.read(ledgerRepositoryProvider.future);
                await repo.insertStatementLine(
                  accountId: bankAccountId,
                  postedAt: posted,
                  amountMinor: minor,
                  description: descCtrl.text.trim(),
                );
                ref.invalidate(reconciliationBundleProvider(bankAccountId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _matchLine(int bankAccountId, int lineId) async {
    final repo = await ref.read(ledgerRepositoryProvider.future);
    final book = await repo.defaultBook();
    final txs = await repo.listTransactions(bookId: book.id, accountId: bankAccountId);
    final uncleared = txs.where((t) => t.clearedAt == null).toList();
    if (!mounted) return;
    final picked = await showDialog<LedgerTransaction>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Match to transaction'),
        children: uncleared.isEmpty
            ? [const Padding(padding: EdgeInsets.all(24), child: Text('No uncleared book entries.'))]
            : uncleared
                .map(
                  (t) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, t),
                    child: Text(
                      '${DateFormat.MMMd().format(t.occurredAt)} ${formatMoney(t.amountMinor)} · ${t.categoryName}',
                    ),
                  ),
                )
                .toList(),
      ),
    );
    if (picked == null) return;
    await repo.matchStatementLine(statementLineId: lineId, transactionId: picked.id);
    invalidateLedger(ref);
    ref.invalidate(reconciliationBundleProvider(bankAccountId));
  }

  Future<void> _unmatchLine(int bankAccountId, int lineId) async {
    final repo = await ref.read(ledgerRepositoryProvider.future);
    await repo.unmatchStatementLine(lineId);
    invalidateLedger(ref);
    ref.invalidate(reconciliationBundleProvider(bankAccountId));
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(defaultBookProvider);

    return bookAsync.when(
      loading: () =>
          const BennetScaffold(title: 'Reconciliation', body: Center(child: CircularProgressIndicator())),
      error: (e, _) => BennetScaffold(title: 'Reconciliation', body: Center(child: Text('$e'))),
      data: (book) {
        final accountsAsync = ref.watch(accountsProvider(book.id));

        return accountsAsync.when(
          loading: () =>
              const BennetScaffold(title: 'Reconciliation', body: Center(child: CircularProgressIndicator())),
          error: (e, _) => BennetScaffold(title: 'Reconciliation', body: Center(child: Text('$e'))),
          data: (accounts) {
            final banks = accounts.where((a) => a.kind == AccountKind.bank).toList();

            final selectedBankId =
                (_bankAccountId != null && banks.any((a) => a.id == _bankAccountId))
                    ? _bankAccountId!
                    : banks.first.id;

            if (banks.isEmpty) {
              return BennetScaffold(
                title: 'Reconciliation',
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Add a bank account to reconcile.'),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _addBankAccount, child: const Text('Add bank account')),
                      ],
                    ),
                  ),
                ),
              );
            }

            final bankId = selectedBankId;
            final bundleAsync = ref.watch(reconciliationBundleProvider(bankId));

            return bundleAsync.when(
              loading: () =>
                  const BennetScaffold(title: 'Reconciliation', body: Center(child: CircularProgressIndicator())),
              error: (e, _) => BennetScaffold(title: 'Reconciliation', body: Center(child: Text('$e'))),
              data: (bundle) {
                final lines = bundle.lines;
                final summary = bundle.summary;
                return BennetScaffold(
                  title: 'Reconciliation',
                  fab: FloatingActionButton(
                    onPressed: () => _addLine(bankId),
                    child: const Icon(Icons.add),
                  ),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: selectedBankId,
                                decoration: const InputDecoration(labelText: 'Bank account'),
                                items: banks
                                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                                    .toList(),
                                onChanged: (v) => setState(() => _bankAccountId = v),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_business_outlined),
                              onPressed: _addBankAccount,
                              tooltip: 'Add bank',
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Statement net: ${formatMoney(summary.statementNetMinor)}'),
                            Text('Matched book net: ${formatMoney(summary.matchedBookNetMinor)}'),
                            Text('Unmatched on statement: ${formatMoney(summary.unmatchedStatementMinor)}'),
                            Text('Uncleared in book: ${formatMoney(summary.unclearedBookMinor)}'),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: lines.isEmpty
                            ? const Center(child: Text('No statement lines.'))
                            : ListView.separated(
                                itemCount: lines.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final line = lines[i];
                                  final matched = line.matchedTransactionId;
                                  return ListTile(
                                    title: Text(line.description),
                                    subtitle: Text(DateFormat.yMMMd().format(line.postedAt)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          formatMoney(line.amountMinor),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        if (matched == null)
                                          TextButton(
                                            onPressed: () => _matchLine(bankId, line.id),
                                            child: const Text('Match'),
                                          )
                                        else
                                          TextButton(
                                            onPressed: () => _unmatchLine(bankId, line.id),
                                            child: const Text('Unmatch'),
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
            );
          },
        );
      },
    );
  }
}
