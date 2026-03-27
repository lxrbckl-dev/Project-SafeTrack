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

/// Build the full Herzog ThemeData
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
