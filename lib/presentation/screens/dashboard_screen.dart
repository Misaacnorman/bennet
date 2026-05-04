import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../widgets/app_scaffold.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(defaultBookProvider);
    final now = DateTime.now();

    return bookAsync.when(
      loading: () => const BennetScaffold(title: 'Dashboard', body: Center(child: CircularProgressIndicator())),
      error: (e, _) => BennetScaffold(title: 'Dashboard', body: Center(child: Text('$e'))),
      data: (book) {
        final summaryAsync = ref.watch(
          monthlySummaryProvider((bookId: book.id, year: now.year, month: now.month)),
        );
        return summaryAsync.when(
          loading: () => const BennetScaffold(
            title: 'Dashboard',
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => BennetScaffold(title: 'Dashboard', body: Center(child: Text('$e'))),
          data: (s) => BennetScaffold(
            title: 'Dashboard',
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${now.year}-${now.month.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _card(context, 'Opening balance', formatMoney(s.openingMinor)),
                _card(context, 'Total income', formatMoney(s.totalIncomeMinor), color: Colors.green.shade700),
                _card(context, 'Total expenses', formatMoney(s.totalExpenseMinor), color: Colors.red.shade700),
                _card(context, 'Net (P&L)', formatMoney(s.netMinor)),
                _card(context, 'Closing balance', formatMoney(s.closingMinor)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/transactions/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add transaction'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, String label, String value, {Color? color}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: color,
          ),
        ),
      ),
    );
  }
}
