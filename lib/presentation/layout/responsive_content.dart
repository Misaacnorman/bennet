import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Layout breakpoints for web / desktop vs phone.
abstract final class Breakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 960;
}

/// Max width for centered page content inside [BennetScaffold].
enum ContentWidthMode {
  /// Forms and settings (~520).
  narrow,

  /// Lists and most screens (~960).
  standard,

  /// Split-pane modules (~1200).
  wide,
}

double maxWidthFor(ContentWidthMode mode) => switch (mode) {
      ContentWidthMode.narrow => 520,
      ContentWidthMode.standard => 960,
      ContentWidthMode.wide => 1200,
    };

/// Centers content and caps width for large viewports.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.mode,
    required this.child,
  });

  final ContentWidthMode mode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxW = maxWidthFor(mode);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }
}

/// Same breakpoints via [MediaQuery] (full window).
bool isMediumWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.medium;

bool isExpandedWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.expanded;

/// Half-width cell for 2-column responsive rows (gap between halves).
double halfCardWidth(double parentWidth, {double gap = 16}) =>
    math.max(0, (parentWidth - gap) / 2);
