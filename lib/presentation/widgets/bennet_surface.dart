import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

/// Polished bordered surface with optional KPI-style accent stripe.
class BennetSurface extends StatelessWidget {
  const BennetSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.clip = true,
    this.onTap,
    this.minHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final bool clip;
  final VoidCallback? onTap;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppRadii.card);

    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (accent != null)
          Container(
            height: 3,
            width: double.infinity,
            color: accent!.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.55 : 0.5,
            ),
          ),
        Padding(
          padding: padding,
          child: minHeight != null
              ? ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight!),
                  child: child,
                )
              : child,
        ),
      ],
    );

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: radius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.78),
        ),
        boxShadow: AppShadows.cardElevated(theme.brightness),
      ),
      child: clip ? ClipRRect(borderRadius: radius, child: inner) : inner,
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Section heading + optional framed body (no nested cards).
class BennetSection extends StatelessWidget {
  const BennetSection({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.child,
    this.framed = true,
    this.surfacePadding = const EdgeInsets.all(0),
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget child;

  /// When true, [child] is wrapped in [BennetSurface].
  final bool framed;

  /// Padding inside [BennetSurface] when [framed] is true.
  final EdgeInsetsGeometry surfacePadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.end,
                children: actions!,
              ),
          ],
        ),
        const SizedBox(height: 12),
        framed ? BennetSurface(padding: surfacePadding, child: child) : child,
      ],
    );
  }
}

/// Wrapper for [DataTable] / horizontal scroll: single frame, no stacked cards.
class BennetDataSurface extends StatelessWidget {
  const BennetDataSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadii.menu);

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.72),
          ),
          boxShadow: AppShadows.cardElevated(theme.brightness),
        ),
        child: child,
      ),
    );
  }
}
