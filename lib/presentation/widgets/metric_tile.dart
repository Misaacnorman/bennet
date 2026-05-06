import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';
import 'bennet_surface.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.accent,
  });

  final String title;
  final String value;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ac = accent ?? scheme.primary;

    return BennetSurface(
      padding: const EdgeInsets.all(16),
      accent: ac,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ac.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.22 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    border: Border.all(color: ac.withValues(alpha: 0.22)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: ac),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: ac.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.2 : 0.1,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
