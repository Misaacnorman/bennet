import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/responsive_content.dart';

class BennetNavDestination {
  const BennetNavDestination({
    required this.path,
    required this.icon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final String label;
}

/// Single source for drawer + [NavigationRail] destinations.
abstract final class BennetNav {
  static const List<BennetNavDestination> destinations = [
    BennetNavDestination(
      path: '/',
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
    ),
    BennetNavDestination(
      path: '/transactions',
      icon: Icons.receipt_long,
      label: 'Transactions',
    ),
    BennetNavDestination(
      path: '/monthly',
      icon: Icons.calendar_month,
      label: 'Monthly summary',
    ),
    BennetNavDestination(
      path: '/cashbook',
      icon: Icons.menu_book_outlined,
      label: 'Cash book',
    ),
    BennetNavDestination(
      path: '/reconciliation',
      icon: Icons.account_balance,
      label: 'Reconciliation',
    ),
    BennetNavDestination(
      path: '/balance-sheet',
      icon: Icons.table_chart,
      label: 'Balance sheet',
    ),
    BennetNavDestination(
      path: '/reports',
      icon: Icons.description_outlined,
      label: 'Tax export',
    ),
    BennetNavDestination(
      path: '/settings',
      icon: Icons.settings_outlined,
      label: 'Settings',
    ),
  ];

  static int selectedIndex(String uriPath) {
    if (uriPath == '/') return 0;
    for (var i = 1; i < destinations.length; i++) {
      final p = destinations[i].path;
      if (uriPath.startsWith(p)) return i;
    }
    return 0;
  }

  static bool _selected(String current, String path) =>
      current == path || (path != '/' && current.startsWith(path));
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8),
          children: [
            const DrawerHeader(
              margin: EdgeInsets.zero,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Bennet',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final d in BennetNav.destinations)
              ListTile(
                leading: Icon(d.icon),
                title: Text(d.label),
                selected: BennetNav._selected(loc, d.path),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(d.path);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class BennetScaffold extends StatelessWidget {
  const BennetScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.fab,
    this.contentWidth = ContentWidthMode.standard,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? fab;

  /// Caps horizontal width on large screens (web/desktop).
  final ContentWidthMode contentWidth;

  @override
  Widget build(BuildContext context) {
    final wrappedBody = ResponsiveContent(mode: contentWidth, child: body);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = constraints.maxWidth >= Breakpoints.medium;
        if (!showRail) {
          return Scaffold(
            appBar: AppBar(title: Text(title), actions: actions),
            drawer: const AppDrawer(),
            body: wrappedBody,
            floatingActionButton: fab,
          );
        }

        final loc = GoRouterState.of(context).uri.path;
        final idx = BennetNav.selectedIndex(loc);

        return Scaffold(
          appBar: AppBar(title: Text(title), actions: actions),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavigationRail(
                selectedIndex: idx,
                onDestinationSelected: (i) =>
                    context.go(BennetNav.destinations[i].path),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Bennet',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                destinations: [
                  for (final d in BennetNav.destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: wrappedBody),
            ],
          ),
          floatingActionButton: fab,
        );
      },
    );
  }
}
