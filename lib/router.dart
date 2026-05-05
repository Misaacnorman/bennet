import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'application/backend_config.dart';
import 'presentation/screens/balance_sheet_screen.dart';
import 'presentation/screens/cash_book_screen.dart';
import 'presentation/screens/charges/charge_edit_screen.dart';
import 'presentation/screens/charges/charge_list_screen.dart';
import 'presentation/screens/charges/charge_pick_client_screen.dart';
import 'presentation/screens/clients/client_detail_screen.dart';
import 'presentation/screens/clients/client_edit_screen.dart';
import 'presentation/screens/clients/client_list_screen.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/monthly_summary_screen.dart';
import 'presentation/screens/overview_screen.dart';
import 'presentation/screens/payments/payment_detail_screen.dart';
import 'presentation/screens/payments/payment_edit_screen.dart';
import 'presentation/screens/payments/payment_list_screen.dart';
import 'presentation/screens/reconciliation_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/statements/statement_builder_screen.dart';
import 'presentation/screens/statements/statement_history_screen.dart';
import 'presentation/screens/signup_screen.dart';
import 'presentation/screens/tax_export_screen.dart';
import 'presentation/screens/transaction_edit_screen.dart';
import 'presentation/screens/transaction_list_screen.dart';
import 'router_refresh.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final _goRouterRefreshProvider = Provider<GoRouterRefreshStream>((ref) {
  final notifier = kUseSqliteBackend
      ? GoRouterRefreshStream(const Stream<void>.empty())
      : GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges());
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
      if (kUseSqliteBackend) return null;
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
      GoRoute(path: '/', builder: (context, state) => const OverviewScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/clients',
        builder: (context, state) => const ClientListScreen(),
      ),
      GoRoute(
        path: '/clients/new',
        builder: (context, state) => const ClientEditScreen(),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ClientDetailScreen(clientId: id);
        },
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ClientEditScreen(clientId: id);
        },
      ),
      GoRoute(
        path: '/clients/:id/payment/new',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PaymentEditScreen(clientId: id);
        },
      ),
      GoRoute(
        path: '/clients/:id/charge/new',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ChargeEditScreen(clientId: id);
        },
      ),
      GoRoute(
        path: '/clients/:id/statement',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return StatementBuilderScreen(clientId: id);
        },
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentListScreen(),
      ),
      GoRoute(
        path: '/payments/new',
        builder: (context, state) => const PaymentEditScreen(),
      ),
      GoRoute(
        path: '/payments/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PaymentDetailScreen(paymentId: id);
        },
      ),
      GoRoute(
        path: '/charges',
        builder: (context, state) => const ChargeListScreen(),
      ),
      GoRoute(
        path: '/charges/new',
        builder: (context, state) => const ChargePickClientScreen(),
      ),
      GoRoute(
        path: '/statements',
        builder: (context, state) => const StatementHistoryScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionListScreen(),
      ),
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) => const TransactionEditScreen(),
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TransactionEditScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/monthly',
        builder: (context, state) => const MonthlySummaryScreen(),
      ),
      GoRoute(
        path: '/cashbook',
        builder: (context, state) => const CashBookScreen(),
      ),
      GoRoute(
        path: '/reconciliation',
        builder: (context, state) => const ReconciliationScreen(),
      ),
      GoRoute(
        path: '/balance-sheet',
        builder: (context, state) => const BalanceSheetScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const TaxExportScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
