import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            _tile(context, loc, '/', Icons.dashboard_outlined, 'Dashboard'),
            _tile(context, loc, '/transactions', Icons.receipt_long, 'Transactions'),
            _tile(context, loc, '/monthly', Icons.calendar_month, 'Monthly summary'),
            _tile(context, loc, '/cashbook', Icons.menu_book_outlined, 'Cash book'),
            _tile(context, loc, '/reconciliation', Icons.account_balance, 'Reconciliation'),
            _tile(context, loc, '/balance-sheet', Icons.table_chart, 'Balance sheet'),
            _tile(context, loc, '/reports', Icons.description_outlined, 'Tax export'),
            _tile(context, loc, '/settings', Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    String current,
    String path,
    IconData icon,
    String label,
  ) {
    final selected = current == path || (path != '/' && current.startsWith(path));
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: () {
        Navigator.of(context).pop();
        context.go(path);
      },
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
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: const AppDrawer(),
      body: body,
      floatingActionButton: fab,
    );
  }
}
