import 'package:flutter/material.dart';

import '../../core/money.dart';

/// Right-aligned amount with optional semantic color.
class AmountText extends StatelessWidget {
  const AmountText(
    this.minor, {
    super.key,
    this.style,
    this.positiveIsCredit = false,
  });

  final int minor;
  final TextStyle? style;

  /// When true, negative amounts render as informational (credit).
  final bool positiveIsCredit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? color;
    if (minor < 0 && positiveIsCredit) {
      color = theme.colorScheme.primary;
    } else if (minor > 0 && !positiveIsCredit) {
      color = theme.colorScheme.error;
    }
    final base = style ?? theme.textTheme.titleMedium;
    return Text(
      formatMoney(minor),
      textAlign: TextAlign.right,
      style: base?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? base.color,
      ),
    );
  }
}
