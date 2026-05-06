import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../../domain/entities.dart';
import '../../services/receipt_pdf_service.dart';
import '../layout/responsive_content.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/bennet_surface.dart';

class TransactionEditScreen extends ConsumerStatefulWidget {
  const TransactionEditScreen({super.key, this.transactionId});

  final int? transactionId;

  @override
  ConsumerState<TransactionEditScreen> createState() =>
      _TransactionEditScreenState();
}

class _TransactionEditScreenState extends ConsumerState<TransactionEditScreen> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _payCtrl = TextEditingController();
  final _methodCtrl = TextEditingController();

  TxType _type = TxType.expense;
  DateTime _date = DateTime.now();
  int? _categoryId;
  int? _accountId;
  bool _loading = true;

  bool get _isNew => widget.transactionId == null;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _payCtrl.dispose();
    _methodCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final repo = await ref.read(ledgerRepositoryProvider.future);
    final book = await ref.read(defaultBookProvider.future);
    final txFuture = widget.transactionId != null
        ? repo.getTransaction(widget.transactionId!)
        : Future<LedgerTransaction?>.value();
    final results = await Future.wait<Object?>([
      ref.read(accountsProvider(book.id).future),
      ref.read(categoriesProvider.future),
      txFuture,
    ]);
    final accounts = results[0] as List<Account>;
    final categories = results[1] as List<Category>;
    final tx = results[2] as LedgerTransaction?;
    if (!mounted) return;

    if (widget.transactionId != null) {
      if (tx != null) {
        _type = tx.type;
        _date = tx.occurredAt;
        _categoryId = tx.categoryId;
        _accountId = tx.accountId;
        _amountCtrl.text = (tx.amountMinor / 100).toStringAsFixed(2);
        _notesCtrl.text = tx.notes ?? '';
        _payCtrl.text = tx.counterparty ?? '';
        _methodCtrl.text = tx.paymentMethod ?? '';
      }
    } else {
      _accountId = accounts.isNotEmpty ? accounts.first.id : null;
      Category? expenseCat;
      for (final c in categories) {
        if (c.name.toLowerCase().contains('expense')) {
          expenseCat = c;
          break;
        }
      }
      _categoryId =
          expenseCat?.id ??
          (categories.isNotEmpty ? categories.first.id : null);
    }

    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final minor = parseMoneyInput(_amountCtrl.text);
    if (minor == null || minor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }
    if (_categoryId == null || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick category and account.')),
      );
      return;
    }

    final repo = await ref.read(ledgerRepositoryProvider.future);
    final book = await repo.defaultBook();

    if (_isNew) {
      await repo.insertTransaction(
        bookId: book.id,
        accountId: _accountId!,
        categoryId: _categoryId!,
        type: _type,
        amountMinor: minor,
        occurredAt: _date,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        paymentMethod: _methodCtrl.text.trim().isEmpty
            ? null
            : _methodCtrl.text.trim(),
        counterparty: _payCtrl.text.trim().isEmpty
            ? null
            : _payCtrl.text.trim(),
      );
    } else {
      final tx = await repo.getTransaction(widget.transactionId!);
      await repo.updateTransaction(
        id: widget.transactionId!,
        accountId: _accountId!,
        categoryId: _categoryId!,
        type: _type,
        amountMinor: minor,
        occurredAt: _date,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        paymentMethod: _methodCtrl.text.trim().isEmpty
            ? null
            : _methodCtrl.text.trim(),
        counterparty: _payCtrl.text.trim().isEmpty
            ? null
            : _payCtrl.text.trim(),
        clearedAt: tx?.clearedAt,
      );
    }

    invalidateLedger(ref);
    if (mounted) context.go('/transactions');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Delete transaction?'),
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    final repo = await ref.read(ledgerRepositoryProvider.future);
    await repo.deleteTransaction(widget.transactionId!);
    invalidateLedger(ref);
    if (mounted) context.go('/transactions');
  }

  Future<void> _shareReceipt() async {
    if (_isNew) return;
    final repo = await ref.read(ledgerRepositoryProvider.future);
    final tx = await repo.getTransaction(widget.transactionId!);
    if (tx == null || !mounted) return;
    final business = await repo.getSetting('business_name');
    final bytes = await buildTransactionReceiptPdf(
      transaction: tx,
      businessName: business,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bennet_receipt_${tx.id}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: 'Receipt ${tx.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BennetScaffold(
        title: 'Transaction',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final categoriesAsync = ref.watch(categoriesProvider);
    final bookAsync = ref.watch(defaultBookProvider);

    return bookAsync.when(
      loading: () => const BennetScaffold(
        title: 'Transaction',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Transaction',
        body: Center(child: Text('$e')),
      ),
      data: (book) {
        final accountsAsync = ref.watch(accountsProvider(book.id));

        return accountsAsync.when(
          loading: () => const BennetScaffold(
            title: 'Transaction',
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => BennetScaffold(
            title: 'Transaction',
            body: Center(child: Text('$e')),
          ),
          data: (accounts) => categoriesAsync.when(
            loading: () => const BennetScaffold(
              title: 'Transaction',
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => BennetScaffold(
              title: 'Transaction',
              body: Center(child: Text('$e')),
            ),
            data: (categories) => BennetScaffold(
              title: _isNew ? 'New transaction' : 'Edit transaction',
              contentWidth: ContentWidthMode.form,
              actions: [
                if (!_isNew)
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: _shareReceipt,
                    tooltip: 'Receipt PDF',
                  ),
                if (!_isNew)
                  IconButton(
                    style: IconButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _delete,
                    tooltip: 'Delete',
                  ),
              ],
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= Breakpoints.compact;
                  final categoryField = DropdownButtonFormField<int>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  );
                  final accountField = DropdownButtonFormField<int>(
                    initialValue: _accountId,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} (${a.kind.name})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _accountId = v),
                  );

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      BennetSurface(
                        clip: false,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<TxType>(
                              segments: const [
                                ButtonSegment(
                                  value: TxType.income,
                                  label: Text('Income'),
                                ),
                                ButtonSegment(
                                  value: TxType.expense,
                                  label: Text('Expense'),
                                ),
                              ],
                              selected: {_type},
                              onSelectionChanged: (s) =>
                                  setState(() => _type = s.first),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: wide ? 280 : double.infinity,
                                ),
                                child: TextField(
                                  controller: _amountCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: categoryField),
                                  const SizedBox(width: 16),
                                  Expanded(child: accountField),
                                ],
                              )
                            else ...[
                              categoryField,
                              const SizedBox(height: 16),
                              accountField,
                            ],
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Date'),
                              subtitle: Text(DateFormat.yMMMd().format(_date)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _pickDate,
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 560,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _payCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Payee / payer (optional)',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _methodCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Payment method (optional)',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _notesCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Notes (optional)',
                                      ),
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: FilledButton(
                            onPressed: _save,
                            child: const Text('Save'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
