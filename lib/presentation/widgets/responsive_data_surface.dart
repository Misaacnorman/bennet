import 'package:flutter/material.dart';

import '../layout/responsive_content.dart';

/// Desktop table vs compact card list based on width.
class ResponsiveDataSurface extends StatelessWidget {
  const ResponsiveDataSurface({
    super.key,
    required this.table,
    required this.cards,
  });

  final Widget table;
  final Widget cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= Breakpoints.medium) return table;
        return cards;
      },
    );
  }
}
