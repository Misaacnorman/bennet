import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/responsive_content.dart';
import '../theme/app_design_tokens.dart';

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

BoxDecoration _sidebarGradientDecoration(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? const [Color(0xFF05221C), AppPalette.brandEmeraldDeep]
          : const [AppPalette.brandEmeraldDeep, AppPalette.brandEmerald],
    ),
    border: Border(
      right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
  );
}

class _BennetBrandHeader extends StatelessWidget {
  const _BennetBrandHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pad = compact
        ? const EdgeInsets.fromLTRB(16, 20, 16, 12)
        : const EdgeInsets.fromLTRB(14, 12, 8, 10);
    return Padding(
      padding: pad,
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 32,
            height: compact ? 36 : 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            alignment: Alignment.center,
            child: Text(
              'B',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.96),
                fontWeight: FontWeight.w800,
                fontSize: compact ? 16 : 15,
                height: 1,
              ),
            ),
          ),
          SizedBox(width: compact ? 12 : 10),
          Expanded(
            child: Text(
              'Bennet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.98),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BennetShellNavList extends StatelessWidget {
  const _BennetShellNavList({
    required this.currentPath,
    required this.onNavigate,
  });

  final String currentPath;
  final void Function(BennetNavDestination destination) onNavigate;

  static final Color _inactiveFg = Colors.white.withValues(alpha: 0.78);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      itemCount: BennetNav.destinations.length,
      itemBuilder: (context, i) {
        final d = BennetNav.destinations[i];
        final selected = BennetNav._selected(currentPath, d.path);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.control),
              onTap: () => onNavigate(d),
              splashColor: Colors.white.withValues(alpha: 0.08),
              highlightColor: Colors.white.withValues(alpha: 0.06),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.92)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Row(
                  children: [
                    if (selected) ...[
                      Container(
                        width: 3,
                        height: 22,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppPalette.mint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                    Icon(
                      d.icon,
                      size: 17,
                      color: selected
                          ? AppPalette.brandEmeraldDeep
                          : _inactiveFg,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        d.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected
                              ? AppPalette.brandEmeraldDeep
                              : _inactiveFg,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.chevron_left,
                        size: 16,
                        color: AppPalette.brandEmerald.withValues(alpha: 0.45),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;

    return Drawer(
      width: 286,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        child: DecoratedBox(
          decoration: _sidebarGradientDecoration(context),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BennetBrandHeader(compact: true),
                Expanded(
                  child: _BennetShellNavList(
                    currentPath: loc,
                    onNavigate: (d) {
                      Navigator.of(context).pop();
                      context.go(d.path);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponsiveSidebar extends StatelessWidget {
  const _ResponsiveSidebar({required this.collapsed, required this.onToggle});

  static const double _expandedWidth = 216;
  static const double _notchWidth = 28;

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final loc = GoRouterState.of(context).uri.path;
    final notchOverlap = _notchWidth / 2;
    final sidebarWidth = collapsed
        ? _notchWidth
        : _expandedWidth + notchOverlap;
    final topInset = MediaQuery.paddingOf(context).top;
    final notchTop = topInset + 10.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: sidebarWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!collapsed)
            Positioned.fill(
              right: notchOverlap,
              child: DecoratedBox(
                decoration: _sidebarGradientDecoration(context),
                child: SafeArea(
                  right: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BennetBrandHeader(),
                      Expanded(
                        child: _BennetShellNavList(
                          currentPath: loc,
                          onNavigate: (d) => context.go(d.path),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            top: notchTop,
            child: _CollapseNotch(
              onToggle: onToggle,
              collapsed: collapsed,
              brightness: brightness,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapseNotch extends StatelessWidget {
  const _CollapseNotch({
    required this.onToggle,
    required this.collapsed,
    required this.brightness,
  });

  final VoidCallback onToggle;
  final bool collapsed;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        customBorder: const StadiumBorder(),
        child: Ink(
          width: _ResponsiveSidebar._notchWidth + 2,
          height: 44,
          decoration: ShapeDecoration(
            color: brightness == Brightness.dark
                ? AppPalette.darkSurfaceRaised
                : AppPalette.surface,
            shape: StadiumBorder(
              side: BorderSide(color: AppPalette.line.withValues(alpha: 0.85)),
            ),
            shadows: AppShadows.lifted(brightness),
          ),
          child: Icon(
            collapsed ? Icons.chevron_right : Icons.chevron_left,
            size: 18,
            color: AppPalette.brandEmerald,
          ),
        ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsed =
            _sidebarCollapsedOverride ??
            constraints.maxWidth < Breakpoints.expanded;
        final useQuietAppBar = constraints.maxWidth >= Breakpoints.expanded;

        final appBarDivider = Divider(
          height: 1,
          thickness: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.title,
              style: useQuietAppBar
                  ? theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    )
                  : theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
            ),
            actions: widget.actions,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            foregroundColor: scheme.onSurface,
            bottom: useQuietAppBar
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: appBarDivider,
                  )
                : null,
          ),
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
