// One-time mechanical migration. Scheme A is the only token input.
import fs from 'node:fs';
import path from 'node:path';
const tokens = JSON.parse(fs.readFileSync('brief/assets/design_options/tokens_A.json', 'utf8'));
const renames = {
  darkBgBase:'bg', darkBackground:'bg', darkSurface1:'surface', darkSurface2:'surfaceAlt', darkSurface3:'surface',
  darkBorderSubtle:'border', darkBorderHighlight:'borderStrong',
  textPrimaryDark:'textPrimary',textSecondaryDark:'textSecondary',textMutedDark:'textMuted',
  lightBgBase:'bg',lightSurface1:'surface',lightSurfaceRecessed:'surfaceAlt',lightBorderSubtle:'border',lightBorderHighlight:'borderStrong',
  textPrimaryLight:'textPrimary',textSecondaryLight:'textSecondary',textMutedLight:'textMuted',
  accentRed:'danger',accentGreen:'success',accentBlue:'primary',accentPurple:'accent',accentAmber:'warning',accentPink:'live',primaryNavy:'primary',accentTeal:'accent',
  getDarkThemeForLocale:'forLocale',
};
function* walk(dir) { for(const e of fs.readdirSync(dir,{withFileTypes:true})) { const p=path.join(dir,e.name); if(e.isDirectory())yield* walk(p);else if(p.endsWith('.dart'))yield p; } }
for(const file of [...walk('project/lib'),...walk('project/test')]) {
  let s=fs.readFileSync(file,'utf8');
  for(const [a,b] of Object.entries(renames))s=s.replaceAll(`AppTheme.${a}`,`AppTheme.${b}`);
  fs.writeFileSync(file,s);
}
const colorLines=Object.entries(tokens.colors).map(([k,v])=>`  static const ${k==='background'?'bg':k} = Color(0xFF${v.slice(1)});`).join('\n');
fs.writeFileSync('project/lib/core/theme/app_theme.dart',`import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scheme A. Source: brief/assets/design_options/tokens_A.json.
abstract final class AppTheme {
${colorLines}
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
    dialogTheme: const DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent),
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
${Object.entries(tokens.gradients).map(([name,g])=>`  static const ${name} = LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [${g.stops.map(c=>`Color(0xFF${c.slice(1)})`).join(', ')}]);`).join('\n')}
}
`);
let main=fs.readFileSync('project/lib/main.dart','utf8').replace(/\s*darkTheme:.*\n/,'\n').replace('ThemeMode.dark','ThemeMode.light');
main=main.replace('routerConfig: _router,','routerConfig: _router,\n            builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child ?? const SizedBox.shrink()),');
fs.writeFileSync('project/lib/main.dart',main);
let pub=fs.readFileSync('project/pubspec.yaml','utf8').replace(/  google_fonts:.*\r?\n/,'');
pub=pub.replace('  assets:\n','  assets:\n    - assets/logo/colored.svg\n    - assets/logo/black.svg\n');
if(!pub.includes('assets/logo/colored.svg'))pub=pub.replace('  assets:\r\n','  assets:\r\n    - assets/logo/colored.svg\r\n    - assets/logo/black.svg\r\n');
pub+='\n  fonts:\n    - family: IBM Plex Sans\n      fonts:\n        - asset: assets/fonts/IBMPlexSans-Variable.ttf\n        - asset: assets/fonts/IBMPlexSans-Variable.ttf\n          weight: 700\n    - family: IBM Plex Sans Arabic\n      fonts:\n        - asset: assets/fonts/IBMPlexSansArabic-400.ttf\n        - asset: assets/fonts/IBMPlexSansArabic-700.ttf\n          weight: 700\n';
fs.writeFileSync('project/pubspec.yaml',pub);
let decisions=fs.readFileSync('brief/05_DECISIONS.md','utf8').replace(/^DESIGN_CHOICE=.*$/m,'DESIGN_CHOICE=A');
fs.writeFileSync('brief/05_DECISIONS.md',decisions);
fs.appendFileSync('brief/LEDGER.md','\n## Full design and release pass, 2026-09-21, Codex Astra\n- Owner authorizes SINGLE window 1, cap 90, continuing past soft 84. Entry used_5h=0, weekly=37, resets_in_min=300, cache_ttl=30m assumed. No subagents, plugins, pushes or production SQL. Roadmap and skill observations remain owner-owned. Both historical stashes preserved.\n- P4 starts with scheme A, selected explicitly by owner. Supplied colored.svg replaces the earlier concept; black.svg is monochrome. All nine source assets visually inspected, including rendered SVGs. Inkscape source sheet is not a runtime asset. Upstream IBM Plex fonts and OFL files downloaded for offline bundling.\n');
