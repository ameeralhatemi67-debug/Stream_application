import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_skin.dart';
import 'canopy_tokens.dart';
import 'hedayah_skin.dart';
export 'app_palette.dart';
export 'app_skin.dart';
export 'hedayah_skin.dart';
export 'skin_colors.dart';
// Canopy tokens back the redesigned streaming screens; the app-wide values
// below are unchanged.
export 'canopy_tokens.dart';

/// Scheme A. Source: brief/assets/design_options/tokens_A.json.
abstract final class AppTheme {
  static const captionFont = 12.0;
  static const disabledText = Canopy.slate;
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = HidayahGold.g100;
  static const border = HidayahGold.hairline;
  static const borderStrong = HidayahGold.s500;
  static const textPrimary = HidayahGold.s900;
  static const textSecondary = HidayahGold.s700;
  static const textMuted = HidayahGold.s600;
  static const primary = HidayahGold.g700;
  static const onPrimary = Color(0xFFFFFFFF);
  static const accent = HidayahGold.g700;
  static const success = HidayahGold.success;
  static const warning = HidayahGold.warning;
  static const danger = HidayahGold.live;
  static const live = HidayahGold.g700;
  static const onMedia = Color(0xFFFFFFFF);
  static const media = HidayahGold.s900;
  static const disabled = Color(0xFFEDE8DE);

  /// Elevation shadows.
  ///
  /// Tinted from [media] rather than pure black, so every raised surface in
  /// the scheme sits on the same neutral. They replace the ad-hoc
  /// ad-hoc black shades the screens had accumulated, which varied by author
  /// rather than by elevation.
  static const shadowSoft = Color(0x1F151D24);
  static const shadow = Color(0x33151D24);
  static const shadowStrong = Color(0x4D151D24);

  static const entrySurfaceShadow = [
    BoxShadow(color: shadowSoft, blurRadius: 24, offset: Offset(0, 6)),
  ];
  static const spaceXs = 4.0, spaceSm = 8.0, spaceMd = 12.0,
      spaceLg = 16.0, spaceXl = 24.0, space2Xl = 32.0, screenPadding = 18.0;
  static const radiusXs = 4.0, radiusSm = 8.0, radiusMd = 12.0,
      radiusLg = 12.0, radiusFull = 999.0;

  /// Shared search-field surface contract (UI-01): the feed search bar and
  /// the spatial-map search bar must use one radius, one border width and
  /// one height rather than each hand-rolling its own Container decoration,
  /// which is how they drifted (or were reported to drift) apart in the
  /// first place. Fill colour/opacity and elevation are intentionally left
  /// to each call site -- the map bar floats over a variable-colour tile
  /// layer and needs a translucent fill plus a shadow to stay legible,
  /// while the feed bar sits inline on a plain white list and needs neither.
  static const searchBarRadius = 14.0;
  static const searchBarBorderWidth = 1.2;
  static const searchBarHeight = 46.0;

  /// Shared floating map-overlay contract (UI-11): the search bar, city/topic
  /// dropdowns and the floating action buttons that sit over the spatial map
  /// share one radius, fill opacity and drop-shadow mechanism so they read as
  /// one system of controls rather than each picking its own elevation
  /// style. Accent colour (e.g. the map tab's red on an active/selected
  /// control) is left to the call site -- that is deliberate per-control
  /// state, not surface inconsistency.
  static const mapOverlayRadius = searchBarRadius;
  static const mapOverlayFillAlpha = 0.80;
  static const mapOverlayShadow = [
    BoxShadow(color: shadowSoft, blurRadius: 10, offset: Offset(0, 3)),
  ];

  static TextTheme buildTextTheme(String languageCode) {
    final ar = languageCode == 'ar';
    TextStyle style(double size, double arabicHeight, {bool bold = false, Color color = textPrimary}) => TextStyle(
      fontFamily: HidayahType.text,
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

  static final Map<String, ThemeData> _themeByLanguage = {};

  /// One ThemeData per language and skin: MaterialApp rebuilds used to build a
  /// fresh one (and its text theme) every time (audit ST-01).
  static ThemeData forLocale(Locale locale, {AppSkin skin = AppSkin.gold}) {
    ActiveSkin.current = skin;
    return _themeByLanguage.putIfAbsent(
        '${skin.id}/${locale.languageCode}',
        () => skin == AppSkin.hedayah
            ? HedayahSkin.theme(locale)
            : _buildTheme(locale));
  }

  static ThemeData _buildTheme(Locale locale) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: HidayahType.text,
    fontFamilyFallback: const ['IBM Plex Sans Arabic', 'IBM Plex Sans'],
    textTheme: buildTextTheme(locale.languageCode),
    extensions: const [AppSkinTheme(AppSkin.gold)],
    scaffoldBackgroundColor: AppPalette.ivory, canvasColor: bg, cardColor: surface,
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
    // The snackbar draws its text with this style alone (not the text theme), so
    // it names the family: without one, web fell back to a downloaded font and
    // Arabic showed as boxes until it arrived (audit 2026-10-21, section 6).
    snackBarTheme: const SnackBarThemeData(backgroundColor: media, contentTextStyle: TextStyle(
      fontFamily: HidayahType.text,
      fontFamilyFallback: ['IBM Plex Sans Arabic', 'IBM Plex Sans'],
      color: onMedia)),
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
  static const ring = CanopyGradients.ring;
  static const panel = CanopyGradients.panel;
  static const pill = CanopyGradients.pill;
  static const liveSignal = CanopyGradients.liveSignal;
  static const canopy = CanopyGradients.canopy;
  static const brand = HidayahGradients.minted;
  static const soft = LinearGradient(colors: [HidayahGold.g100, HidayahGold.g200]);

  /// Bottom scrim for thumbnails and viewports that carry [AppTheme.onMedia]
  /// text over an arbitrary video frame.
  ///
  /// Both stops are the scheme's own [AppTheme.media]; only the alpha changes,
  /// so the scrim introduces no colour the tokens do not already define. The
  /// 0xCC bottom stop is what `theme_contrast_test` pins: against the worst
  /// case, a pure white frame underneath, white text still clears 4.5:1, which
  /// a lighter scrim does not.
  ///
  /// It exists because the scheme A migration turned two such scrims into a
  /// *solid* media fill, which hid the feed card banner and the VOD thumbnail
  /// underneath them completely.
  static const mediaScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00151D24), Color(0xCC151D24)],
  );
}
