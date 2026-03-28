import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Herzog brand color palette
class HerzogColors {
  // Brand
  static const gold = Color(0xFFFFD100);
  static const brightYellow = Color(0xFFFFDD00);
  static const darkYellow = Color(0xFFF1B80E);
  static const richBlack = Color(0xFF000000);
  static const darkGray = Color(0xFF58595B);
  static const midGray = Color(0xFF6D6E71);
  static const smoke = Color(0xFFA7A9AC);
  static const accentGray = Color(0xFFD1D3D4);

  // Action (Navy)
  static const navyBlue = Color(0xFF1E3A5F);
  static const navyLight = Color(0xFF2E5A8F);
  static const navyDark = Color(0xFF0F1F33);

  // Semantic
  static const successGreen = Color(0xFF1E6B38);
  static const successLight = Color(0xFFD4EDDA);
  static const errorRed = Color(0xFFAB2D24);
  static const errorLight = Color(0xFFF8D7DA);
  static const warningAmber = Color(0xFF8A5700);
  static const warningLight = Color(0xFFFFF3CD);
  static const infoTeal = Color(0xFF086670);
  static const infoLight = Color(0xFFD1ECF1);

  // Neutrals
  static const white = Color(0xFFFFFFFF);
  static const offWhite = Color(0xFFFAFAFA);
  static const lightGray = Color(0xFFF5F5F5);
  static const borderGray = Color(0xFFE5E5E5);
  static const inputBorder = Color(0xFF8E8E8E);

  // Data Visualization Palette
  static const chartPurple = Color(0xFF6B4C9A);
  static const chartSlate = Color(0xFF4A6274);
  static const chartColors = [
    navyBlue,
    infoTeal,
    gold,
    successGreen,
    errorRed,
    chartPurple,
    warningAmber,
    chartSlate,
  ];
}

// ---------------------------------------------------------------------------
// Dark-mode color overrides
// ---------------------------------------------------------------------------

/// Dark-mode surface / background colors for Herzog dark theme.
///
/// All foreground / background pairs are tested at WCAG AA (4.5:1 for normal
/// text, 3:1 for large text and UI components).
class HerzogDarkColors {
  /// Page scaffold background — deep navy (#0D1B2A).
  static const background = Color(0xFF0D1B2A);

  /// Card / surface background — dark gray-blue (#1B2838).
  static const surface = Color(0xFF1B2838);

  /// Elevated surface (dialogs, drawers, drop-downs).
  static const surfaceVariant = Color(0xFF243347);

  /// Primary text on dark backgrounds — near-white (contrast ~12:1 on surface).
  static const textPrimary = Color(0xFFE8EDF2);

  /// Secondary / body text on dark backgrounds (~7:1 on surface).
  static const textSecondary = Color(0xFFB0BEC5);

  /// Muted / hint text (~4.70:1 on surface — meets WCAG AA).
  static const textMuted = Color(0xFF819AAA);

  /// Border color for cards and dividers.
  static const border = Color(0xFF2E4460);

  /// Input border in its resting state.
  static const inputBorder = Color(0xFF4A6274);

  // Status badge colors — dark backgrounds with accessible foregrounds (WCAG AA)
  /// Success badge background.
  static const successBg = Color(0xFF0E3320);

  /// Success badge foreground (~5:1 on successBg).
  static const successFg = Color(0xFF4CAF7D);

  /// Error badge background.
  static const errorBg = Color(0xFF3B1010);

  /// Error badge foreground (~5:1 on errorBg).
  static const errorFg = Color(0xFFEF9A9A);

  /// Warning badge background.
  static const warningBg = Color(0xFF3B2800);

  /// Warning badge foreground (~5:1 on warningBg).
  static const warningFg = Color(0xFFFFCC80);

  /// Info badge background.
  static const infoBg = Color(0xFF0A2A30);

  /// Info badge foreground (~5:1 on infoBg).
  static const infoFg = Color(0xFF4DD0E1);

  // Chart colors — brightened variants for visibility on dark backgrounds
  static const List<Color> chartColors = [
    Color(0xFF4A90D9), // brightened navy
    Color(0xFF26C6DA), // brightened teal
    Color(0xFFFFD100), // gold (unchanged — pops on dark)
    Color(0xFF4CAF7D), // brightened green
    Color(0xFFEF5350), // brightened red
    Color(0xFFAB7FD4), // brightened purple
    Color(0xFFFFB74D), // brightened amber
    Color(0xFF78909C), // brightened slate
  ];
}

/// Herzog text styles using Oswald (headings) and Roboto (body)
class HerzogText {
  static TextStyle heading({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w600,
    Color color = HerzogColors.richBlack,
  }) {
    return GoogleFonts.oswald(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.04 * fontSize,
    );
  }

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = HerzogColors.darkGray,
  }) {
    return GoogleFonts.roboto(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle label({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w700,
    Color color = HerzogColors.midGray,
  }) {
    return GoogleFonts.roboto(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.5,
    );
  }
}

/// Build the full Herzog ThemeData (light mode).
ThemeData herzogTheme() {
  return ThemeData(
    fontFamily: GoogleFonts.roboto().fontFamily,
    scaffoldBackgroundColor: HerzogColors.offWhite,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HerzogColors.navyBlue,
      surface: HerzogColors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: HerzogColors.richBlack,
      foregroundColor: HerzogColors.gold,
      elevation: 0,
      titleTextStyle: GoogleFonts.oswald(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: HerzogColors.gold,
        letterSpacing: 1.2,
      ),
      shape: const Border(
        bottom: BorderSide(color: HerzogColors.gold, width: 3),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HerzogColors.navyBlue,
        foregroundColor: HerzogColors.white,
        textStyle: GoogleFonts.roboto(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    cardTheme: CardThemeData(
      color: HerzogColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: HerzogColors.borderGray),
      ),
      margin: const EdgeInsets.only(bottom: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: HerzogColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: HerzogColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: HerzogColors.navyBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: GoogleFonts.roboto(color: HerzogColors.smoke),
    ),
    dividerColor: HerzogColors.borderGray,
    // ADA: Focus indicators (WCAG 2.4.7)
    focusColor: HerzogColors.navyBlue.withValues(alpha: 0.3),
    // ADA: Ensure text scales properly
    textTheme: TextTheme(
      bodyLarge: GoogleFonts.roboto(fontSize: 16, color: HerzogColors.darkGray),
      bodyMedium: GoogleFonts.roboto(
        fontSize: 14,
        color: HerzogColors.darkGray,
      ),
      bodySmall: GoogleFonts.roboto(fontSize: 12, color: HerzogColors.midGray),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: HerzogColors.richBlack,
      selectedIconTheme: const IconThemeData(color: HerzogColors.gold),
      unselectedIconTheme: const IconThemeData(color: HerzogColors.smoke),
      selectedLabelTextStyle: GoogleFonts.oswald(color: HerzogColors.gold),
      unselectedLabelTextStyle: GoogleFonts.roboto(color: HerzogColors.smoke),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: HerzogColors.gold,
      unselectedLabelColor: HerzogColors.smoke,
      indicatorColor: HerzogColors.gold,
      labelStyle: GoogleFonts.oswald(fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w400),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(HerzogColors.offWhite),
      headingTextStyle: GoogleFonts.roboto(
        fontWeight: FontWeight.w600,
        color: HerzogColors.midGray,
        fontSize: 12,
        letterSpacing: 1.0,
      ),
      dataTextStyle: GoogleFonts.roboto(
        fontWeight: FontWeight.w400,
        color: HerzogColors.darkGray,
        fontSize: 14,
      ),
      dividerThickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: HerzogColors.successLight,
      labelStyle: GoogleFonts.roboto(color: HerzogColors.successGreen),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: HerzogColors.navyDark,
      contentTextStyle: GoogleFonts.roboto(color: HerzogColors.white),
    ),
  );
}

/// Build the full Herzog ThemeData — dark mode.
///
/// Design decisions:
/// - Sidebar / AppBar: dark navy (#0D1B2A) to match scaffold background;
///   gold text and gold bottom border retained for brand consistency.
/// - Gold accent (#FFD100) is kept unchanged — it provides ~8:1 contrast on
///   the dark navy background (exceeds WCAG AAA).
/// - Navy action color (#1E3A5F) is kept for buttons; white foreground gives
///   ~10:1 contrast (WCAG AAA).
/// - All text colours are drawn from [HerzogDarkColors] (WCAG AA verified).
/// - Chart colours are brightened variants from [HerzogDarkColors.chartColors].
ThemeData herzogDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.roboto().fontFamily,
    scaffoldBackgroundColor: HerzogDarkColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HerzogColors.navyBlue,
      brightness: Brightness.dark,
      surface: HerzogDarkColors.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: HerzogDarkColors.background,
      foregroundColor: HerzogColors.gold,
      elevation: 0,
      titleTextStyle: GoogleFonts.oswald(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: HerzogColors.gold,
        letterSpacing: 1.2,
      ),
      shape: const Border(
        bottom: BorderSide(color: HerzogColors.gold, width: 3),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HerzogColors.navyBlue,
        foregroundColor: HerzogColors.white,
        textStyle: GoogleFonts.roboto(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    cardTheme: CardThemeData(
      color: HerzogDarkColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: HerzogDarkColors.border),
      ),
      margin: const EdgeInsets.only(bottom: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: HerzogDarkColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: const BorderSide(color: HerzogDarkColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        // Gold focus ring on dark — ~8:1 contrast (WCAG AAA)
        borderSide: const BorderSide(color: HerzogColors.gold, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: GoogleFonts.roboto(color: HerzogDarkColors.textMuted),
      labelStyle: GoogleFonts.roboto(color: HerzogDarkColors.textSecondary),
      floatingLabelStyle: GoogleFonts.roboto(color: HerzogColors.gold),
    ),
    dividerColor: HerzogDarkColors.border,
    // ADA: Gold focus ring is highly visible on dark backgrounds (WCAG 2.4.7)
    focusColor: HerzogColors.gold.withValues(alpha: 0.3),
    // ADA: Text colours meet WCAG AA on dark surfaces
    textTheme: TextTheme(
      bodyLarge: GoogleFonts.roboto(
        fontSize: 16,
        color: HerzogDarkColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.roboto(
        fontSize: 14,
        color: HerzogDarkColors.textSecondary,
      ),
      bodySmall: GoogleFonts.roboto(
        fontSize: 12,
        color: HerzogDarkColors.textMuted,
      ),
      titleLarge: GoogleFonts.oswald(
        fontSize: 22,
        color: HerzogDarkColors.textPrimary,
      ),
      titleMedium: GoogleFonts.oswald(
        fontSize: 18,
        color: HerzogDarkColors.textPrimary,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: HerzogDarkColors.background,
      selectedIconTheme: const IconThemeData(color: HerzogColors.gold),
      unselectedIconTheme: IconThemeData(color: HerzogDarkColors.textMuted),
      selectedLabelTextStyle: GoogleFonts.oswald(color: HerzogColors.gold),
      unselectedLabelTextStyle: GoogleFonts.roboto(
        color: HerzogDarkColors.textMuted,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: HerzogColors.gold,
      unselectedLabelColor: HerzogDarkColors.textMuted,
      indicatorColor: HerzogColors.gold,
      labelStyle: GoogleFonts.oswald(fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.roboto(fontWeight: FontWeight.w400),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(HerzogDarkColors.surfaceVariant),
      headingTextStyle: GoogleFonts.roboto(
        fontWeight: FontWeight.w600,
        color: HerzogDarkColors.textMuted,
        fontSize: 12,
        letterSpacing: 1.0,
      ),
      dataTextStyle: GoogleFonts.roboto(
        fontWeight: FontWeight.w400,
        color: HerzogDarkColors.textSecondary,
        fontSize: 14,
      ),
      dividerThickness: 1,
    ),
    // Neutral chip defaults — status-specific colors are applied per-chip
    // at the widget level to avoid coloring filter chips and non-status chips.
    chipTheme: ChipThemeData(
      backgroundColor: HerzogDarkColors.surfaceVariant,
      labelStyle: GoogleFonts.roboto(color: HerzogDarkColors.textSecondary),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: HerzogDarkColors.surfaceVariant,
      contentTextStyle: GoogleFonts.roboto(color: HerzogDarkColors.textPrimary),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: HerzogDarkColors.surfaceVariant,
      titleTextStyle: GoogleFonts.oswald(
        fontSize: 20,
        color: HerzogDarkColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: GoogleFonts.roboto(
        fontSize: 14,
        color: HerzogDarkColors.textSecondary,
      ),
    ),
  );
}
