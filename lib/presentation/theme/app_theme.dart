import 'package:flutter/material.dart';

import 'app_design_tokens.dart';

ColorScheme _lightColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: AppPalette.brandEmerald,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppPalette.brandEmerald,
    onPrimary: Colors.white,
    primaryContainer: AppPalette.mintSoft,
    onPrimaryContainer: AppPalette.brandEmeraldDeep,
    surface: AppPalette.surface,
    onSurface: AppPalette.textStrong,
    onSurfaceVariant: AppPalette.slate.withValues(alpha: 0.88),
    surfaceContainerLowest: AppPalette.pageWarm,
    surfaceContainerLow: AppPalette.mintSoft,
    surfaceContainer: AppPalette.surfaceWarm,
    surfaceContainerHigh: const Color(0xFFF3F6F4),
    surfaceContainerHighest: const Color(0xFFECEFEA),
    secondary: AppPalette.teal,
    onSecondary: Colors.white,
    secondaryContainer: AppPalette.tealSoft,
    onSecondaryContainer: AppPalette.tealOnSoft,
    tertiary: AppPalette.amber,
    onTertiary: const Color(0xFF1C1400),
    tertiaryContainer: AppPalette.amberSoft,
    onTertiaryContainer: AppPalette.amberOnSoft,
    error: AppPalette.coral,
    onError: Colors.white,
    errorContainer: AppPalette.coralSoft,
    onErrorContainer: AppPalette.coralOnSoft,
    outline: AppPalette.line,
    outlineVariant: AppPalette.line.withValues(alpha: 0.55),
    surfaceTint: Colors.transparent,
  );
}

ColorScheme _darkColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: AppPalette.darkEmerald,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppPalette.darkEmerald,
    onPrimary: const Color(0xFF031510),
    primaryContainer: AppPalette.brandEmerald,
    onPrimaryContainer: AppPalette.mintSoft,
    surface: AppPalette.darkSurface,
    onSurface: AppPalette.darkText,
    onSurfaceVariant: AppPalette.darkMuted,
    surfaceContainerLowest: AppPalette.darkPage,
    surfaceContainerLow: const Color(0xFF0A1412),
    surfaceContainer: AppPalette.darkSurface,
    surfaceContainerHigh: const Color(0xFF13201D),
    surfaceContainerHighest: AppPalette.darkSurfaceRaised,
    secondary: const Color(0xFF4ECDB8),
    onSecondary: const Color(0xFF002E29),
    secondaryContainer: const Color(0xFF163530),
    onSecondaryContainer: AppPalette.tealSoft,
    tertiary: AppPalette.darkAmber,
    onTertiary: const Color(0xFF261800),
    tertiaryContainer: const Color(0xFF4A3912),
    onTertiaryContainer: AppPalette.amberSoft,
    error: AppPalette.darkCoral,
    onError: const Color(0xFF370D00),
    errorContainer: const Color(0xFF5E2315),
    onErrorContainer: AppPalette.coralSoft,
    outline: AppPalette.darkLine,
    outlineVariant: AppPalette.darkLine.withValues(alpha: 0.45),
    surfaceTint: Colors.transparent,
  );
}

TextTheme _refinedTextTheme(TextTheme base, ColorScheme cs) {
  return base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
    ),
  );
}

ThemeData bennetTheme(Brightness brightness) {
  final cs = brightness == Brightness.dark
      ? _darkColorScheme()
      : _lightColorScheme();
  final scaffoldBg = brightness == Brightness.dark
      ? AppPalette.darkPage
      : AppPalette.pageWarm;
  final appBarBg = brightness == Brightness.dark
      ? AppPalette.darkPage
      : AppPalette.pageWarm;

  final baseTheme = ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: scaffoldBg,
  );

  final textTheme = _refinedTextTheme(baseTheme.textTheme, cs);

  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.card),
    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.85)),
  );

  return baseTheme.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: appBarBg,
      foregroundColor: cs.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      shape: Border(
        bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: cs.surface,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: cardShape,
      margin: EdgeInsets.zero,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: cs.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.9)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      focusElevation: 4,
      hoverElevation: 4,
      highlightElevation: 3,
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.dark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.55)
          : AppPalette.surfaceWarm,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.65)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.55)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide(color: cs.error, width: 2),
      ),
      labelStyle: TextStyle(color: cs.onSurfaceVariant),
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.75)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cs.surface,
      deleteIconColor: cs.onSurfaceVariant,
      disabledColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      selectedColor: cs.secondaryContainer,
      secondarySelectedColor: cs.tertiaryContainer,
      labelStyle: textTheme.labelLarge?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: cs.onSecondaryContainer,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.55)),
      ),
      side: BorderSide(color: cs.outline.withValues(alpha: 0.55)),
      elevation: 0,
      pressElevation: 0,
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
      headingTextStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      dataTextStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
      dividerThickness: 1,
      horizontalMargin: 16,
      columnSpacing: 16,
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(AppRadii.menu),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: cs.onSurfaceVariant,
      textColor: cs.onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant.withValues(alpha: 0.65),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cs.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: cs.onInverseSurface,
      ),
      actionTextColor: cs.inversePrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.menu),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: cs.inverseSurface,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: cs.onInverseSurface),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: cs.primary,
      linearTrackColor: cs.surfaceContainerHighest,
      circularTrackColor: cs.surfaceContainerHighest,
    ),
  );
}
