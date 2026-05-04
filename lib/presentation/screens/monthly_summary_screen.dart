import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../widgets/app_scaffold.dart';

class MonthlySummaryScreen extends ConsumerStatefulWidget {
  const MonthlySummaryScreen({super.key});

  @override
  ConsumerState<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends ConsumerState<MonthlySummaryScreen> {
  late DateTime _month;
  final _openingCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOpeningField());
  }

  @override
  void dispose() {
    _openingCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshOpeningField() async {
    final repo = await ref.read(ledgerRepositoryProvider.future);
    final book = await repo.defaultBook();
    final explicit = await repo.getOpeningMinor(book.id, _month.year, _month.month);
    final resolved = await repo.resolveOpeningMinor(book.id, _month.year, _month.month);
    if (!mounted) return;
    if (explicit != null) {
      _openingCtrl.text = (explicit / 100).toStringAsFixed(2);
    } else {
      _openingCtrl.text = (resolved / 100).toStringAsFixed(2);
    }
    setState(() {});
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
      await _refreshOpeningField();
      ref.invalidate(monthlySummaryProvider);
    }
  }

  Future<void> _saveOpening() async {
    final minor = parseMoneyInput(_openingCtrl.text);
    if (minor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid opening balance.')));
      return;
    }
    final repo = await ref.read(ledgerRepositoryProvider.future);
    final book = await repo.defaultBook();
    await repo.setOpeningMinor(book.id, _month.year, _month.month, minor);
    invalidateLedger(ref);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening balance saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(defaultBookProvider);

    return bookAsync.when(
      loading: () => const BennetScaffold(title: 'Monthly summary', body: Center(child: CircularProgressIndicator())),
      error: (e, _) => BennetScaffold(title: 'Monthly summary', body: Center(child: Text('$e'))),
      data: (book) {
        final summaryAsync = ref.watch(
          monthlySummaryProvider((bookId: book.id, year: _month.year, month: _month.month)),
        );
        return summaryAsync.when(
          loading: () =>
              const BennetScaffold(title: 'Monthly summary', body: Center(child: CircularProgressIndicator())),
          error: (e, _) => BennetScaffold(title: 'Monthly summary', body: Center(child: Text('$e'))),
          data: (s) => BennetScaffold(
            title: 'Monthly summary',
            actions: [
              IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickMonth),
            ],
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(DateFormat.yMMMM().format(_month), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: _openingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opening balance (edit & save)',
                    helperText: 'Stored opening for this month; affects closing.',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}'))],
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _saveOpening, child: const Text('Save opening balance')),
                const Divider(height: 32),
                _row('Opening balance', formatMoney(s.openingMinor)),
                _row('Total income', formatMoney(s.totalIncomeMinor)),
                _row('Total expenses', formatMoney(s.totalExpenseMinor)),
                _row('Profit / loss', formatMoney(s.netMinor)),
                _row('Closing balance', formatMoney(s.closingMinor), emphasize: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: emphasize ? FontWeight.bold : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
