import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'presentation/screens/balance_sheet_screen.dart';
import 'presentation/screens/cash_book_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/signup_screen.dart';
import 'presentation/screens/monthly_summary_screen.dart';
import 'presentation/screens/reconciliation_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/tax_export_screen.dart';
import 'presentation/screens/transaction_edit_screen.dart';
import 'presentation/screens/transaction_list_screen.dart';
import 'router_refresh.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final _goRouterRefreshProvider = Provider<GoRouterRefreshStream>((ref) {
  final notifier = GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_goRouterRefreshProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final onAuthPage =
          state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
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
