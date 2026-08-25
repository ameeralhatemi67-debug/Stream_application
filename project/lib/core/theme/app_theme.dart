import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Master Design Contract Token System: Refined Minimalist Academic
/// Enforces depth through surface elevation, mathematical spacing, and high-contrast bilingual typography.
class AppTheme {
  // Refined Minimalist Academic Dark Palette (Levels of Graphite)
  static const Color darkBgBase = Color(0xFF121214); // Canvas backdrop
  static const Color darkSurface1 = Color(0xFF1A1A1E); // Card surface
  static const Color darkSurface2 = Color(0xFF24242A); // Elevated tabs/search
  static const Color darkSurface3 = Color(0xFF2D2D35); // Floating sheets/modals

  static const Color darkBorderSubtle = Color(0xFF27272F);
  static const Color darkBorderHighlight = Color(0xFF3F3F4C);

  // Minimalist Light Palette
  static const Color lightBgBase = Color(0xFFFAFAFA);
  static const Color lightSurface1 = Color(0xFFFFFFFF);
  static const Color lightSurfaceRecessed = Color(0xFFF4F4F5);
  static const Color lightBorderSubtle = Color(0xFFE4E4E7);
  static const Color lightBorderHighlight = Color(0xFFD4D4D8);

  // Text Contrast Levels
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // 98% Lightness
  static const Color textSecondaryDark = Color(0xFFA1A1AA); // 70% Lightness
  static const Color textMutedDark = Color(0xFF71717A); // 50% Lightness

  static const Color textPrimaryLight = Color(0xFF09090B);
  static const Color textSecondaryLight = Color(0xFF52525B);
  static const Color textMutedLight = Color(0xFFA1A1AA);

  // Semantic Functional Accents
  static const Color accentRed = Color(0xFFFF8080); // Live status pulse
  static const Color accentGreen = Color(0xFF34D399); // Physical venue attendance & open seats
  static const Color accentBlue = Color(0xFF38BDF8); // Verified scholar badge & map vectors
  static const Color accentPurple = Color(0xFFA78BFA); // VOD archive catalog & lecture slides
  static const Color accentAmber = Color(0xFFFBBF24); // Q&A featured upvotes & notifications
  static const Color accentPink = Color(0xFFFF2D55); // Broadcaster Studio signature accent (Go Live CTAs)

  // Compatibility Aliases
  static const Color darkBackground = darkBgBase;
  static const Color primaryNavy = accentBlue;
  static const Color accentTeal = accentBlue;

  // Spacing System (4px increments)
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 24.0;
  static const double space2Xl = 32.0;

  // Border Radii Scale
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusFull = 999.0;

  /// Builds a TextTheme tailored to Arabic (Tajawal) or English (Inter).
  static TextTheme buildTextTheme(String languageCode, {bool isDark = true}) {
    final primaryColor = isDark ? textPrimaryDark : textPrimaryLight;
    final secondaryColor = isDark ? textSecondaryDark : textSecondaryLight;
    final mutedColor = isDark ? textMutedDark : textMutedLight;
    final isArabic = languageCode == 'ar';

    TextTheme baseTheme;
    if (isArabic) {
      baseTheme = GoogleFonts.tajawalTextTheme();
    } else {
      baseTheme = GoogleFonts.interTextTheme();
    }

    // In Arabic typography, letter spacing must be 0.0 to prevent broken cursive glyph ligatures.
    // Line height of 1.38 provides clean vertical breathability for Arabic diacritics and ascenders/descenders.
    final double letterSpacingHeadline = isArabic ? 0.0 : -0.5;
    final double letterSpacingMedium = isArabic ? 0.0 : -0.3;
    final double standardHeight = isArabic ? 1.38 : 1.25;

    return baseTheme.copyWith(
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primaryColor,
        letterSpacing: letterSpacingHeadline,
        height: standardHeight,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: primaryColor,
        letterSpacing: letterSpacingMedium,
        height: standardHeight,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0.0,
        height: standardHeight,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: primaryColor,
        letterSpacing: 0.0,
        height: standardHeight,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.normal,
        color: primaryColor,
        letterSpacing: 0.0,
        height: standardHeight,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
        letterSpacing: 0.0,
        height: standardHeight,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: mutedColor,
        letterSpacing: 0.0,
        height: standardHeight,
      ),
    );
  }

  /// Refined Dark Theme definition adhering to Impeccable contracts.
  static ThemeData getDarkThemeForLocale(Locale locale) {
    final textTheme = buildTextTheme(locale.languageCode, isDark: true);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBgBase,
      primaryColor: accentBlue,
      canvasColor: darkBgBase,
      cardColor: darkSurface1,
      dividerColor: darkBorderSubtle,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentRed,
        tertiary: accentGreen,
        surface: darkSurface1,
        error: accentRed,
        onPrimary: darkBgBase,
        onSecondary: Colors.white,
        onSurface: textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimaryDark, size: 22),
      ),
      cardTheme: CardThemeData(
        color: darkSurface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: darkBorderSubtle, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface1,
        selectedItemColor: accentRed,
        unselectedItemColor: textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkBorderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkBorderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
        ),
      ),
    );
  }
}
