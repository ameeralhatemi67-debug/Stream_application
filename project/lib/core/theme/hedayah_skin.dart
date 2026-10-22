import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_skin.dart';

/// The Hedayah skin (ADR-016), taken from the association's identity book
/// ("Hedayah Brand Identity", scanned from hedayh.org.sa on 2026-10-22).
///
/// Rules the tokens encode, all from that book:
/// * Gold is a fill. Text on gold is [ink] (6.0:1); white on gold fails.
/// * Gold-coloured text on white is [bronze] (6.1:1); icons use [gold600].
/// * Slate draws the rosette and quiet icons, never small text.
/// * One shape: every button, tab track and chip is a pill.
/// * Grounds are white and [mist]; gold returns in bands carrying the lattice.
abstract final class HedayahSkin {
  // Brand constants.
  static const gold = Color(0xFFBD933F), // signature, browser theme colour
      slate = Color(0xFF6B7981), // the rosette
      ink = Color(0xFF151D24), // text on gold
      bronze = Color(0xFF805B1B), // gold text on white, fills under white text
      gold600 = Color(0xFFA87726), // icons on white (3.9:1)
      goldLight = Color(0xFFE2C389), // gold on ink
      mist = Color(0xFFF8F8F8), // section ground
      paper = Color(0xFFFFFFFF),
      bodyGrey = Color(0xFF69727D), // captions (4.9:1 on white)
      track = Color(0xFFE4E4E4); // ring tracks

  // Interface tones built around them.
  static const surface = Color(0xFFF3F6F8),
      line = Color(0xFFDCE2E7),
      lineSoft = Color(0xFFEDF0F3),
      muted = Color(0xFF515C66),
      chip = Color(0xFFF6ECD9),
      chipInk = Color(0xFF6E4A14),
      goldTint = Color(0x35BD933F), // the website header's 21% gold
      success = Color(0xFF2D7647),
      warning = Color(0xFF9A5B0E),
      danger = Color(0xFFAF2934),
      disabled = Color(0xFFE9ECEF);

  static const page = mist;

  /// The lattice over gold bands, as the website lays it (white, about a
  /// fifth).
  static const patternOnGold = Color(0x40FFFFFF);

  /// The lattice on mist and white grounds.
  static const patternOnMist = Color(0x0F151D24);

  static const display = 'Readex Pro';
  static const text = 'IBM Plex Sans Arabic';
  static const fallback = ['IBM Plex Sans Arabic', 'IBM Plex Sans'];

  static const radiusPill = 25.0, radiusCard = 15.0, radiusSheet = 20.0;
  static const radiusField = 12.0;

  /// The service cards' soft ambient shadow.
  static const ambient = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 20),
  ];

  /// Raised surfaces that float over content (sheets, the tab bar).
  static const lifted = [
    BoxShadow(color: Color(0x14151D24), blurRadius: 24, offset: Offset(0, 6)),
  ];

  /// Readex Pro headings. Its weight is a variable axis, so it is set there
  /// as well as on [FontWeight].
  static TextStyle displayStyle(double size,
          {Color color = ink,
          FontWeight weight = FontWeight.w600,
          double height = 1.35}) =>
      TextStyle(
          fontFamily: display,
          fontFamilyFallback: fallback,
          fontSize: size,
          fontWeight: weight,
          fontVariations: [FontVariation.weight(weight.value.toDouble())],
          height: height,
          letterSpacing: 0,
          color: color);

  static TextStyle textStyle(double size,
          {Color color = muted,
          FontWeight weight = FontWeight.w400,
          double height = 1.7}) =>
      TextStyle(
          fontFamily: text,
          fontFamilyFallback: fallback,
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: 0,
          color: color);

  static TextTheme textTheme(String languageCode) {
    final ar = languageCode == 'ar';
    TextStyle head(double size, {FontWeight weight = FontWeight.w600}) =>
        displayStyle(size, weight: weight, height: ar ? 1.5 : 1.3);
    TextStyle body(double size,
            {bool bold = false, Color color = ink, double? arabic}) =>
        textStyle(size,
            color: color,
            weight: bold ? FontWeight.w700 : FontWeight.w400,
            height: ar ? (arabic ?? 1.8) : 1.45);
    return TextTheme(
      displayLarge: head(32),
      displayMedium: head(30),
      displaySmall: head(28),
      headlineLarge: head(28),
      headlineMedium: head(22),
      headlineSmall: head(21),
      titleLarge: head(20),
      titleMedium: head(16, weight: FontWeight.w500),
      titleSmall: body(13, bold: true, arabic: 1.6),
      bodyLarge: body(15),
      bodyMedium: body(15, color: muted),
      bodySmall: body(12, color: bodyGrey, arabic: 1.7),
      labelLarge: head(15, weight: FontWeight.w500),
      labelMedium: body(13, bold: true, arabic: 1.6),
      labelSmall: body(12, arabic: 1.7),
    );
  }

  static ThemeData theme(Locale locale) {
    final text = textTheme(locale.languageCode);
    const pill = StadiumBorder();
    final field = OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: const BorderSide(color: line));
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: HedayahSkin.text,
      fontFamilyFallback: fallback,
      textTheme: text,
      extensions: const [AppSkinTheme(AppSkin.hedayah)],
      scaffoldBackgroundColor: page,
      canvasColor: paper,
      cardColor: paper,
      primaryColor: bronze,
      dividerColor: line,
      disabledColor: bodyGrey,
      colorScheme: const ColorScheme.light(
        primary: bronze,
        onPrimary: paper,
        secondary: gold,
        onSecondary: ink,
        tertiary: slate,
        onTertiary: paper,
        surface: paper,
        onSurface: ink,
        error: danger,
        onError: paper,
        outline: slate,
        outlineVariant: line,
        surfaceContainerHighest: surface,
        onSurfaceVariant: muted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: displayStyle(18),
        iconTheme: const IconThemeData(color: ink, size: 22),
      ),
      cardTheme: CardThemeData(
          color: paper,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusCard),
              side: const BorderSide(color: lineSoft))),
      dialogTheme: DialogThemeData(
          backgroundColor: paper,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: displayStyle(19),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSheet))),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: paper,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(radiusSheet)))),
      navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: paper, indicatorColor: gold),
      navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: paper, indicatorColor: gold),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: paper,
          selectedItemColor: bronze,
          unselectedItemColor: bodyGrey,
          type: BottomNavigationBarType.fixed,
          elevation: 0),
      tabBarTheme: TabBarThemeData(
          labelColor: ink,
          unselectedLabelColor: bodyGrey,
          indicatorColor: gold,
          dividerColor: line,
          labelStyle: displayStyle(14, weight: FontWeight.w500),
          unselectedLabelStyle: textStyle(14)),
      chipTheme: ChipThemeData(
          backgroundColor: chip,
          selectedColor: gold,
          labelStyle: textStyle(13, color: chipInk, weight: FontWeight.w700),
          side: BorderSide.none,
          shape: pill),
      switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(paper),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? gold600 : track),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent)),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: gold, linearTrackColor: track),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusField)),
          contentTextStyle: textStyle(14, color: paper, height: 1.5)),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              foregroundColor: ink,
              backgroundColor: gold,
              disabledBackgroundColor: disabled,
              disabledForegroundColor: bodyGrey,
              elevation: 0,
              textStyle: displayStyle(15, weight: FontWeight.w500),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              shape: pill)),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              foregroundColor: paper,
              backgroundColor: bronze,
              textStyle: displayStyle(15, weight: FontWeight.w500),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              shape: pill)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              side: const BorderSide(color: ink, width: 1.5),
              textStyle: displayStyle(15, weight: FontWeight.w500),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: pill)),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: bronze,
              textStyle: displayStyle(14, weight: FontWeight.w500),
              shape: pill)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: paper,
          hintStyle: textStyle(14, color: bodyGrey),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          border: field,
          enabledBorder: field,
          focusedBorder: field.copyWith(
              borderSide: const BorderSide(color: bronze, width: 2))),
    );
  }
}
