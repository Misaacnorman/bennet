import 'package:flutter/material.dart';

/// Design tokens for Bennet. Pair with explicit [ColorScheme] in [app_theme.dart].
abstract final class AppPalette {
  /// Light
  static const Color brandEmerald = Color(0xFF0F6B57);
  static const Color brandEmeraldDeep = Color(0xFF073B32);
  static const Color mint = Color(0xFFBFEBDD);
  static const Color mintSoft = Color(0xFFEAF8F2);
  static const Color pageWarm = Color(0xFFF8FAF6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceWarm = Color(0xFFFBFCF8);
  static const Color line = Color(0xFFDCE5DE);
  static const Color slate = Color(0xFF34443F);
  static const Color textStrong = Color(0xFF17211D);
  static const Color amber = Color(0xFFE29A19);
  static const Color amberSoft = Color(0xFFFFF4D8);
  static const Color coral = Color(0xFFE4572E);
  static const Color coralSoft = Color(0xFFFFE7DF);
  static const Color teal = Color(0xFF159A88);
  static const Color tealSoft = Color(0xFFE1F6F1);
  static const Color blue = Color(0xFF2E77D0);
  static const Color blueSoft = Color(0xFFE6F0FF);

  /// Dark
  static const Color darkPage = Color(0xFF081311);
  static const Color darkSurface = Color(0xFF101C19);
  static const Color darkSurfaceRaised = Color(0xFF162622);
  static const Color darkLine = Color(0xFF29413A);
  static const Color darkText = Color(0xFFEAF3EE);
  static const Color darkMuted = Color(0xFFB3C7BF);
  static const Color darkEmerald = Color(0xFF72D7BD);
  static const Color darkAmber = Color(0xFFFFCA63);
  static const Color darkCoral = Color(0xFFFF8A68);
  static const Color darkBlue = Color(0xFF8DBBFF);

  /// Text on tealSoft / similar tinted surfaces.
  static const Color tealOnSoft = Color(0xFF0A4A43);

  static const Color amberOnSoft = Color(0xFF5C4300);

  static const Color coralOnSoft = Color(0xFF781E0F);
}

abstract final class AppSemanticColors {
  static const Color attention = AppPalette.amber;
  static const Color attentionSoft = AppPalette.amberSoft;
  static const Color overdue = AppPalette.coral;
  static const Color overdueSoft = AppPalette.coralSoft;
  static const Color credits = AppPalette.teal;
  static const Color creditsSoft = AppPalette.tealSoft;
  static const Color info = AppPalette.blue;
  static const Color infoSoft = AppPalette.blueSoft;
  static const Color neutral = AppPalette.slate;
}

abstract final class AppRadii {
  static const double control = 8;
  static const double button = 10;
  static const double card = 14;
  static const double menu = 12;
  static const double authCard = 20;
}

abstract final class AppSpacing {
  /// Standard page inset (mobile baseline in AGENTS.md).
  static const double pagePad = 16;

  /// Wider layouts.
  static const double pagePadLoose = 24;

  static const double fieldGap = 12;
  static const double sectionGap = 24;

  /// List / table inset inside surfaces.
  static const double inset = 12;
}

abstract final class AppShadows {
  static List<BoxShadow> cardElevated(Brightness b) => [
    BoxShadow(
      color: Color.fromRGBO(15, 33, 29, b == Brightness.dark ? 0.35 : 0.07),
      blurRadius: 22,
      offset: const Offset(0, 6),
    ),
  ];

  /// FAB / compact floating controls.
  static List<BoxShadow> lifted(Brightness b) => [
    BoxShadow(
      color: Color.fromRGBO(15, 33, 29, b == Brightness.dark ? 0.45 : 0.12),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
  ];
}
