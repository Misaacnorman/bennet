import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_design_tokens.dart';

/// Shared centered layout for login / signup (narrow column on wide web viewports).
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.headline,
    required this.subtitle,
    required this.formCard,
    this.footerText,
    this.footerLink,
  });

  final String headline;
  final String subtitle;
  final Widget formCard;
  final String? footerText;
  final Widget? footerLink;

  static const double maxFormWidth = 400;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = math.min(
              maxFormWidth,
              constraints.maxWidth - 48,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(0, contentWidth),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.22),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'B',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bennet',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                            letterSpacing: -0.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          headline,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        formCard,
                        if (footerLink != null) ...[
                          const SizedBox(height: 20),
                          footerLink!,
                        ],
                        if (footerText != null) ...[
                          const SizedBox(height: 24),
                          Text(
                            footerText!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Card wrapper matching Bennet auth styling.
  static Widget card(BuildContext context, {required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.authCard),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.82),
        ),
        boxShadow: AppShadows.cardElevated(theme.brightness),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
