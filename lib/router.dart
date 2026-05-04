import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'presentation/screens/balance_sheet_screen.dart';
import 'presentation/screens/cash_book_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/monthly_summary_screen.dart';
import 'presentation/screens/reconciliation_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/tax_export_screen.dart';
import 'presentation/screens/transaction_edit_screen.dart';
import 'presentation/screens/transaction_list_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/transactions', builder: (context, state) => const TransactionListScreen()),
      GoRoute(path: '/transactions/new', builder: (context, state) => const TransactionEditScreen()),
      GoRoute(
        path: '/transactions/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TransactionEditScreen(transactionId: id);
        },
      ),
      GoRoute(path: '/monthly', builder: (context, state) => const MonthlySummaryScreen()),
      GoRoute(path: '/cashbook', builder: (context, state) => const CashBookScreen()),
      GoRoute(path: '/reconciliation', builder: (context, state) => const ReconciliationScreen()),
      GoRoute(path: '/balance-sheet', builder: (context, state) => const BalanceSheetScreen()),
      GoRoute(path: '/reports', builder: (context, state) => const TaxExportScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});
