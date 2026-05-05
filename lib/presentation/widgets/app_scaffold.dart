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

/// Single source for sidebar destinations.
abstract final class BennetNav {
  static const List<BennetNavDestination> destinations = [
    BennetNavDestination(
      path: '/',
      icon: Icons.insights_outlined,
      label: 'Overview',
    ),
    BennetNavDestination(
      path: '/clients',
      icon: Icons.people_outline,
      label: 'Clients',
    ),
    BennetNavDestination(
      path: '/payments',
      icon: Icons.payments_outlined,
      label: 'Payments',
    ),
    BennetNavDestination(
      path: '/charges',
      icon: Icons.request_quote_outlined,
      label: 'Charges',
    ),
    BennetNavDestination(
      path: '/statements',
      icon: Icons.description_outlined,
      label: 'Statements',
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
      icon: Icons.analytics_outlined,
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
    var bestIdx = 0;
    var bestLen = -1;
    for (var i = 1; i < destinations.length; i++) {
      final p = destinations[i].path;
      if (uriPath.startsWith(p) && p.length > bestLen) {
        bestLen = p.length;
        bestIdx = i;
      }
    }
    return bestLen >= 0 ? bestIdx : 0;
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

class _ResponsiveSidebar extends StatelessWidget {
  const _ResponsiveSidebar({required this.collapsed, required this.onToggle});

  static const double _collapsedWidth = 56;
  static const double _expandedWidth = 216;
  static const double _notchWidth = 28;

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final scheme = Theme.of(context).colorScheme;
    final panelWidth = collapsed ? _collapsedWidth : _expandedWidth;
    final notchOverlap = _notchWidth / 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: panelWidth + notchOverlap,
      child: Stack(
        children: [
          Positioned.fill(
            right: notchOverlap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(right: BorderSide(color: scheme.outlineVariant)),
              ),
              child: SafeArea(
                right: false,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        collapsed ? 8 : 14,
                        12,
                        8,
                        8,
                      ),
                      child: SizedBox(
                        height: 34,
                        child: Row(
                          mainAxisAlignment: collapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            if (collapsed)
                              Text(
                                'B',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              )
                            else
                              Expanded(
                                child: Text(
                                  'Bennet',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(7, 4, 7, 12),
                        itemCount: BennetNav.destinations.length,
                        itemBuilder: (context, i) {
                          final d = BennetNav.destinations[i];
                          final selected = BennetNav._selected(loc, d.path);
                          final item = Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => context.go(d.path),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOut,
                                height: 38,
                                padding: EdgeInsets.symmetric(
                                  horizontal: collapsed ? 0 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? scheme.primaryContainer.withValues(
                                          alpha: 0.75,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: collapsed
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      d.icon,
                                      size: 17,
                                      color: selected
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurfaceVariant,
                                    ),
                                    if (!collapsed) ...[
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          d.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: selected
                                                    ? scheme.onPrimaryContainer
                                                    : scheme.onSurface,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );

                          if (!collapsed) return item;
                          return Tooltip(
                            message: d.label,
                            waitDuration: const Duration(milliseconds: 450),
                            child: item,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 54,
            child: Material(
              color: scheme.surface,
              elevation: 2,
              shape: StadiumBorder(
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onToggle,
                child: SizedBox(
                  width: _notchWidth,
                  height: 44,
                  child: Icon(
                    collapsed ? Icons.chevron_right : Icons.chevron_left,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BennetScaffold extends StatefulWidget {
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
  State<BennetScaffold> createState() => _BennetScaffoldState();
}

class _BennetScaffoldState extends State<BennetScaffold> {
  bool? _sidebarCollapsedOverride;

  @override
  Widget build(BuildContext context) {
    final wrappedBody = ResponsiveContent(
      mode: widget.contentWidth,
      child: widget.body,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsed =
            _sidebarCollapsedOverride ??
            constraints.maxWidth < Breakpoints.expanded;

        return Scaffold(
          appBar: AppBar(title: Text(widget.title), actions: widget.actions),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ResponsiveSidebar(
                collapsed: collapsed,
                onToggle: () =>
                    setState(() => _sidebarCollapsedOverride = !collapsed),
              ),
              Expanded(child: wrappedBody),
            ],
          ),
          floatingActionButton: widget.fab,
        );
      },
    );
  }
}
