import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../layout/responsive_content.dart';
import '../theme/app_design_tokens.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/metric_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(defaultBookProvider);
    final now = DateTime.now();

    return bookAsync.when(
      loading: () => const BennetScaffold(
        title: 'Dashboard',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Dashboard',
        body: Center(child: Text('$e')),
      ),
      data: (book) {
        final summaryAsync = ref.watch(
          monthlySummaryProvider((
            bookId: book.id,
            year: now.year,
            month: now.month,
          )),
        );
        return summaryAsync.when(
          loading: () => const BennetScaffold(
            title: 'Dashboard',
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => BennetScaffold(
            title: 'Dashboard',
            body: Center(child: Text('$e')),
          ),
          data: (s) => BennetScaffold(
            title: 'Dashboard',
            body: LayoutBuilder(
              builder: (context, constraints) {
                final cards = <Widget>[
                  MetricTile(
                    title: 'Opening balance',
                    value: formatMoney(s.openingMinor),
                    icon: Icons.account_balance_wallet_outlined,
                    accent: AppSemanticColors.info,
                  ),
                  MetricTile(
                    title: 'Total income',
                    value: formatMoney(s.totalIncomeMinor),
                    icon: Icons.south_west,
                    accent: AppSemanticColors.credits,
                  ),
                  MetricTile(
                    title: 'Total expenses',
                    value: formatMoney(s.totalExpenseMinor),
                    icon: Icons.north_east,
                    accent: AppSemanticColors.overdue,
                  ),
                  MetricTile(
                    title: 'Net (P&L)',
                    value: formatMoney(s.netMinor),
                    icon: Icons.balance_outlined,
                    accent: AppSemanticColors.neutral,
                  ),
                  MetricTile(
                    title: 'Closing balance',
                    value: formatMoney(s.closingMinor),
                    icon: Icons.account_balance_outlined,
                    accent: AppSemanticColors.credits,
                  ),
                ];
                final twoCol = constraints.maxWidth >= Breakpoints.compact;
                final cellW = halfCardWidth(constraints.maxWidth);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '${now.year}-${now.month.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (!twoCol)
                      ...cards.map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: w,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: cards
                            .map((w) => SizedBox(width: cellW, child: w))
                            .toList(),
                      ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/transactions/new'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add transaction'),
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
