import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scheme A. Source: brief/assets/design_options/tokens_A.json.
abstract final class AppTheme {
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFECF6EF);
  static const border = Color(0xFFD9DDDE);
  static const borderStrong = Color(0xFF737B7D);
  static const textPrimary = Color(0xFF202B2B);
  static const textSecondary = Color(0xFF485554);
  static const textMuted = Color(0xFF586563);
  static const primary = Color(0xFF17643F);
  static const onPrimary = Color(0xFFFFFFFF);
  static const accent = Color(0xFF17643F);
  static const success = Color(0xFF22613D);
  static const warning = Color(0xFF7C5012);
  static const danger = Color(0xFF9D3044);
  static const live = Color(0xFF17643F);
  static const onMedia = Color(0xFFFFFFFF);
  static const media = Color(0xFF243536);
  static const disabled = Color(0xFFE5E8E7);
  static const spaceXs = 4.0, spaceSm = 8.0, spaceMd = 12.0,
      spaceLg = 16.0, spaceXl = 24.0, space2Xl = 32.0, screenPadding = 18.0;
  static const radiusXs = 4.0, radiusSm = 8.0, radiusMd = 12.0,
      radiusLg = 12.0, radiusFull = 999.0;

  static TextTheme buildTextTheme(String languageCode) {
    final ar = languageCode == 'ar';
    TextStyle style(double size, double arabicHeight, {bool bold = false, Color color = textPrimary}) => TextStyle(
      fontFamily: ar ? 'IBM Plex Sans Arabic' : 'IBM Plex Sans',
      fontFamilyFallback: const ['IBM Plex Sans Arabic', 'IBM Plex Sans'],
      fontSize: size, height: ar ? arabicHeight : 1.4,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      letterSpacing: 0, color: color,
    );
    return TextTheme(
      displayLarge: style(30, 1.5, bold: true),
      displayMedium: style(30, 1.5, bold: true),
      displaySmall: style(30, 1.5, bold: true),
      headlineLarge: style(30, 1.5, bold: true),
      headlineMedium: style(21, 1.6, bold: true),
      headlineSmall: style(21, 1.6, bold: true),
      titleLarge: style(21, 1.6, bold: true),
      titleMedium: style(15, 1.8, bold: true),
      titleSmall: style(13, 1.6, bold: true),
      bodyLarge: style(15, 1.8),
      bodyMedium: style(15, 1.8, color: textSecondary),
      bodySmall: style(12, 1.7, color: textMuted),
      labelLarge: style(15, 1.8, bold: true),
      labelMedium: style(13, 1.6, bold: true),
      labelSmall: style(12, 1.7),
    );
  }

  static ThemeData forLocale(Locale locale) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: locale.languageCode == 'ar' ? 'IBM Plex Sans Arabic' : 'IBM Plex Sans',
    fontFamilyFallback: const ['IBM Plex Sans Arabic', 'IBM Plex Sans'],
    textTheme: buildTextTheme(locale.languageCode),
    scaffoldBackgroundColor: bg, canvasColor: bg, cardColor: surface,
    primaryColor: primary, dividerColor: border, disabledColor: textMuted,
    colorScheme: const ColorScheme.light(
      primary: primary, onPrimary: onPrimary, secondary: accent,
      onSecondary: onPrimary, tertiary: success, onTertiary: onPrimary,
      surface: surface, onSurface: textPrimary, error: danger, onError: onPrimary,
      outline: borderStrong, outlineVariant: border, surfaceContainerHighest: surfaceAlt,
      onSurfaceVariant: textSecondary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg, foregroundColor: textPrimary,
      elevation: 0, scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      iconTheme: IconThemeData(color: textPrimary, size: 22),
    ),
    cardTheme: CardThemeData(color: surface, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd), side: const BorderSide(color: border))),
    dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: surface, indicatorColor: surfaceAlt),
    navigationRailTheme: const NavigationRailThemeData(backgroundColor: surface, indicatorColor: surfaceAlt),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: surface, selectedItemColor: primary,
      unselectedItemColor: textMuted, type: BottomNavigationBarType.fixed, elevation: 0),
    snackBarTheme: const SnackBarThemeData(backgroundColor: media, contentTextStyle: TextStyle(color: onMedia)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      foregroundColor: onPrimary, backgroundColor: primary, disabledBackgroundColor: disabled,
      disabledForegroundColor: textMuted, elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: spaceLg, vertical: spaceMd),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)))),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface,
      hintStyle: const TextStyle(color: textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: spaceLg, vertical: spaceMd),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: const BorderSide(color: borderStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: const BorderSide(color: borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: const BorderSide(color: primary, width: 2))),
  );
}

/// Allowed on primary buttons, welcome hero, logo tiles and small accents only.
abstract final class AppGradients {
  static const brand = LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [Color(0xFF17643F), Color(0xFF327044)]);
  static const soft = LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [Color(0xFFD7EDDC), Color(0xFFB8DBB9)]);
}
