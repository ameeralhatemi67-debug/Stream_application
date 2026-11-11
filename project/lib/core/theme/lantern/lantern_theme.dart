import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_skin.dart';
import 'lantern_tokens.dart';

/// The Material theme of Lantern and Arch (ADR-026), day or night.
///
/// Lantern screens draw with their own kit (lib/core/widgets/lantern) and
/// read [LanternTokens]; this theme dresses the Material pieces underneath
/// (dialogs, sheets, menus, text fields, pickers) and the screens that have
/// no Lantern layout yet, which always get the day set.
abstract final class LanternSkin {
  static final Map<String, ThemeData> _themes = {};

  static ThemeData theme(Locale locale, {bool night = false}) =>
      _themes.putIfAbsent(
          '${locale.languageCode}/$night', () => _build(locale, night));

  // Which styles inherit matters when the design changes: MaterialApp
  // animates from one theme to the next, and TextStyle.lerp throws when the
  // two sides disagree on `inherit` (the red screen of 2026-10-29). The text
  // theme's styles inherit, as the other designs' do after Material merges
  // them; styles that stand in for a component default do not, as Material's
  // own defaults do not.
  static TextStyle _inherits(TextStyle style) => style.copyWith(inherit: true);

  static TextTheme textTheme(String languageCode, LanternTokens t) {
    final ar = languageCode == 'ar';
    TextStyle head(double size, {FontWeight weight = FontWeight.w600}) =>
        _inherits(Lantern.displayStyle(size,
            color: t.fg, weight: weight, height: ar ? 1.45 : 1.25));
    TextStyle body(double size,
            {FontWeight weight = FontWeight.w400,
            Color? color,
            double? arabic}) =>
        _inherits(Lantern.textStyle(size,
            color: color ?? t.fg,
            weight: weight,
            height: ar ? (arabic ?? 1.8) : 1.5));
    return TextTheme(
      displayLarge: head(34),
      displayMedium: head(30),
      displaySmall: head(28),
      headlineLarge: head(28),
      headlineMedium: head(23),
      headlineSmall: head(21),
      titleLarge: head(20),
      titleMedium: head(16),
      titleSmall: body(13.5, weight: FontWeight.w700, arabic: 1.6),
      bodyLarge: body(15),
      bodyMedium: body(15, color: t.muted),
      bodySmall: body(12.5, color: t.muted, arabic: 1.7),
      labelLarge: body(15, weight: FontWeight.w600, arabic: 1.6),
      labelMedium: body(13, weight: FontWeight.w600, arabic: 1.6),
      labelSmall: body(12, arabic: 1.7),
    );
  }

  static ThemeData _build(Locale locale, bool night) {
    final t = night ? LanternTokens.dark : LanternTokens.day;
    final text = textTheme(locale.languageCode, t);
    const pill = StadiumBorder();
    final field = OutlineInputBorder(
        borderRadius: BorderRadius.circular(Lantern.radiusField),
        borderSide: BorderSide(color: t.line, width: 1.5));
    final scheme = (night ? const ColorScheme.dark() : const ColorScheme.light())
        .copyWith(
      primary: t.goldInk,
      onPrimary: night ? LanternTokens.ink : LanternTokens.white,
      secondary: LanternTokens.gold,
      onSecondary: LanternTokens.onGold,
      tertiary: t.audio,
      onTertiary: LanternTokens.white,
      surface: t.surface,
      onSurface: t.fg,
      error: t.live,
      onError: LanternTokens.white,
      outline: t.muted,
      outlineVariant: t.line,
      surfaceContainerHighest: t.sunk,
      surfaceContainerHigh: t.sunk,
      surfaceContainer: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainerLowest: t.surface,
      onSurfaceVariant: t.muted,
      shadow: const Color(0xFF000000),
      scrim: t.scrim,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: night ? Brightness.dark : Brightness.light,
      fontFamily: Lantern.text,
      fontFamilyFallback: Lantern.fallback,
      textTheme: text,
      extensions: [const AppSkinTheme(AppSkin.lantern), t],
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.surface,
      cardColor: t.surface,
      primaryColor: t.goldInk,
      dividerColor: t.line,
      disabledColor: t.faint,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: scheme,
      iconTheme: IconThemeData(color: t.fg, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            night ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: Lantern.displayStyle(18, color: t.fg),
        iconTheme: IconThemeData(color: t.fg, size: 22),
      ),
      cardTheme: CardThemeData(
          color: t.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Lantern.radiusCard),
              side: BorderSide(color: t.line))),
      dialogTheme: DialogThemeData(
          backgroundColor: t.raised,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: Lantern.displayStyle(19, color: t.fg),
          contentTextStyle: Lantern.textStyle(15, color: t.muted),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Lantern.radiusDialog))),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: t.raised,
          surfaceTintColor: Colors.transparent,
          modalBarrierColor: t.scrim,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Lantern.radiusDialog)))),
      popupMenuTheme: PopupMenuThemeData(
          color: t.raised,
          surfaceTintColor: Colors.transparent,
          textStyle: Lantern.textStyle(14.5, color: t.fg),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Lantern.radiusRow),
              side: BorderSide(color: t.line))),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: t.surface, indicatorColor: LanternTokens.gold),
      navigationRailTheme: NavigationRailThemeData(
          backgroundColor: t.surface, indicatorColor: LanternTokens.gold),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: t.surface,
          selectedItemColor: t.goldInk,
          unselectedItemColor: t.muted,
          type: BottomNavigationBarType.fixed,
          elevation: 0),
      tabBarTheme: TabBarThemeData(
          labelColor: t.fg,
          unselectedLabelColor: t.muted,
          indicatorColor: LanternTokens.gold,
          dividerColor: t.line,
          labelStyle: Lantern.displayStyle(14.5, color: t.fg),
          unselectedLabelStyle: Lantern.textStyle(14.5, color: t.muted)),
      chipTheme: ChipThemeData(
          backgroundColor: t.surface,
          selectedColor: LanternTokens.gold,
          labelStyle: Lantern.textStyle(13.5,
              color: t.fg, weight: FontWeight.w500, height: 1.2),
          side: BorderSide(color: t.line),
          shape: pill),
      switchTheme: SwitchThemeData(
          thumbColor: const WidgetStatePropertyAll(LanternTokens.white),
          trackColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? LanternTokens.gold
                  : t.line),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent)),
      checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? LanternTokens.gold
                  : Colors.transparent),
          checkColor: const WidgetStatePropertyAll(LanternTokens.ink),
          side: BorderSide(color: t.muted, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? t.goldInk : t.muted)),
      progressIndicatorTheme: ProgressIndicatorThemeData(
          color: LanternTokens.gold, linearTrackColor: t.sunk),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1),
      tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
              color: LanternTokens.nightGround,
              borderRadius: BorderRadius.circular(10)),
          textStyle: Lantern.textStyle(12,
              color: LanternTokens.onNight, weight: FontWeight.w500)),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: LanternTokens.nightGround,
          behavior: SnackBarBehavior.floating,
          shape: const StadiumBorder(),
          actionTextColor: LanternTokens.goldHi,
          contentTextStyle: _inherits(Lantern.textStyle(14,
              color: LanternTokens.onNight,
              weight: FontWeight.w500,
              height: 1.4))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              foregroundColor: LanternTokens.onGold,
              backgroundColor: LanternTokens.gold,
              disabledBackgroundColor: t.sunk,
              disabledForegroundColor: t.faint,
              elevation: 0,
              textStyle: Lantern.textStyle(15,
                  color: LanternTokens.onGold,
                  weight: FontWeight.w600,
                  height: 1.2),
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: pill)),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              foregroundColor: LanternTokens.onGold,
              backgroundColor: LanternTokens.gold,
              disabledBackgroundColor: t.sunk,
              disabledForegroundColor: t.faint,
              textStyle: Lantern.textStyle(15,
                  color: LanternTokens.onGold,
                  weight: FontWeight.w600,
                  height: 1.2),
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: pill)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: t.fg,
              side: BorderSide(color: t.fg, width: 1.5),
              textStyle: Lantern.textStyle(15,
                  color: t.fg, weight: FontWeight.w600, height: 1.2),
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: pill)),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: t.goldInk,
              textStyle: Lantern.textStyle(14.5,
                  color: t.goldInk, weight: FontWeight.w600, height: 1.2),
              shape: pill)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: t.surface,
          hintStyle:
              _inherits(Lantern.textStyle(15, color: t.faint, height: 1.3)),
          labelStyle:
              _inherits(Lantern.textStyle(14, color: t.muted, height: 1.3)),
          errorStyle: _inherits(Lantern.textStyle(12.5,
              color: t.liveText, weight: FontWeight.w500, height: 1.3)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: field,
          enabledBorder: field,
          focusedBorder: field.copyWith(
              borderSide:
                  const BorderSide(color: LanternTokens.gold, width: 1.5)),
          errorBorder: field.copyWith(
              borderSide: BorderSide(color: t.live, width: 1.5)),
          focusedErrorBorder: field.copyWith(
              borderSide: BorderSide(color: t.live, width: 1.5))),
    );
  }
}
