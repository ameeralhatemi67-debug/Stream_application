import 'package:flutter/material.dart';

import '../app_skin.dart';

/// Lantern and Arch: the third design (ADR-026). Colours come in two sets
/// from the same roles, day (linen) and night (ink); a widget asks for a role
/// with `context.lt` and never names a hex value itself.
///
/// Values are the `--a-*` tokens of the approved identity ("Hedayah New
/// Identity", App identity tab). Contrast of each text pair is pinned by
/// test/lantern_contrast_test.dart.
@immutable
class LanternTokens extends ThemeExtension<LanternTokens> {
  const LanternTokens._({
    required this.night,
    required this.bg,
    required this.surface,
    required this.raised,
    required this.sunk,
    required this.line,
    required this.line2,
    required this.fg,
    required this.muted,
    required this.faint,
    required this.goldInk,
    required this.live,
    required this.liveDeep,
    required this.liveSoft,
    required this.liveText,
    required this.audio,
    required this.audioSoft,
    required this.ok,
    required this.okSoft,
    required this.warn,
    required this.warnSoft,
    required this.mod,
    required this.modSoft,
    required this.glow,
    required this.scrim,
    required this.shadow,
    required this.shadowHi,
    required this.shimmer,
  });

  final bool night;

  /// Page ground, cards on it, raised sheets, and wells sunk into a card.
  final Color bg, surface, raised, sunk;

  /// Hairlines: [line] around cards and fields, [line2] between rows.
  final Color line, line2;

  /// Text: main, secondary, and [faint] for captions that are not essential
  /// (below 4.5:1, so never for small text that matters).
  final Color fg, muted, faint;

  /// Gold as text and line: bronze by day, light gold by night.
  final Color goldInk;

  /// Live video (red), audio (teal), fine (green), caution (amber) and
  /// moderator (violet), each with a soft ground for chips and banners and,
  /// for live, a text tone that passes on that ground.
  final Color live, liveDeep, liveSoft, liveText;
  final Color audio, audioSoft, ok, okSoft, warn, warnSoft, mod, modSoft;

  /// Focus halo, the veil behind dialogs, and the skeleton's moving light.
  final Color glow, scrim, shimmer;

  final List<BoxShadow> shadow, shadowHi;

  // The same in both sets.
  static const gold = Color(0xFFBD933F),
      goldHi = Color(0xFFE2C389),
      goldLo = Color(0xFFA87726),
      goldTop = Color(0xFFD8AF63),
      ink = Color(0xFF151D24),
      nightGround = Color(0xFF0B1117),
      slate = Color(0xFF6B7981),
      onGold = ink,
      onNight = Color(0xFFF3EFE6),
      white = Color(0xFFFFFFFF);

  /// Solid grounds for small white text (a pin's label, a count badge), the
  /// same by day and by night: the night state colours are light, and white
  /// on them is below 4.5:1 (test/lantern_contrast_test.dart).
  static const liveFill = Color(0xFFC2343F),
      okFill = Color(0xFF2D7647),
      audioFill = Color(0xFF2D6F86);

  /// Linen by day.
  static const day = LanternTokens._(
    night: false,
    bg: Color(0xFFFAF6EC),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    sunk: Color(0xFFF3ECDC),
    line: Color(0xFFEADFCB),
    line2: Color(0xFFF2E9D8),
    fg: Color(0xFF151D24),
    muted: Color(0xFF515C66),
    faint: Color(0xFF8A959F),
    goldInk: Color(0xFF805B1B),
    live: Color(0xFFC2343F),
    liveDeep: Color(0xFF9A1C2E),
    liveSoft: Color(0xFFF8E4E5),
    liveText: Color(0xFFA3202D),
    audio: Color(0xFF2D6F86),
    audioSoft: Color(0xFFE3EFF3),
    ok: Color(0xFF2D7647),
    okSoft: Color(0xFFE5F1E8),
    warn: Color(0xFF9A5B0E),
    warnSoft: Color(0xFFFBEEDC),
    mod: Color(0xFF4B3F96),
    modSoft: Color(0xFFECE9F7),
    glow: Color(0x80BD933F),
    scrim: Color(0x750B1117),
    shimmer: Color(0x66FFFFFF),
    shadow: [
      BoxShadow(color: Color(0x0F151D24), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
          color: Color(0x29805B1B),
          blurRadius: 28,
          spreadRadius: -6,
          offset: Offset(0, 10)),
    ],
    shadowHi: [
      BoxShadow(color: Color(0x14151D24), blurRadius: 4, offset: Offset(0, 2)),
      BoxShadow(
          color: Color(0x4D805B1B),
          blurRadius: 38,
          spreadRadius: -8,
          offset: Offset(0, 20)),
    ],
  );

  /// Ink by night; also forced locally on the rooms, heroes and the footer.
  static const dark = LanternTokens._(
    night: true,
    bg: Color(0xFF0B1117),
    surface: Color(0xFF151D24),
    raised: Color(0xFF1B252E),
    sunk: Color(0xFF0F161C),
    line: Color(0xFF27323C),
    line2: Color(0xFF1F2A33),
    fg: Color(0xFFF3EFE6),
    muted: Color(0xFF9AA7B1),
    faint: Color(0xFF6B7981),
    goldInk: Color(0xFFE2C389),
    live: Color(0xFFE5535E),
    liveDeep: Color(0xFFB02A3A),
    liveSoft: Color(0xFF3A1B20),
    liveText: Color(0xFFF0868E),
    audio: Color(0xFF5BB7D0),
    audioSoft: Color(0xFF12303A),
    ok: Color(0xFF5CC08A),
    okSoft: Color(0xFF14291F),
    warn: Color(0xFFE3A857),
    warnSoft: Color(0xFF2E2314),
    mod: Color(0xFFA99BFF),
    modSoft: Color(0xFF251F47),
    glow: Color(0x73D2A95F),
    scrim: Color(0x99000000),
    shimmer: Color(0x12FFFFFF),
    shadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(
          color: Color(0x73000000),
          blurRadius: 30,
          spreadRadius: -6,
          offset: Offset(0, 12)),
    ],
    shadowHi: [
      BoxShadow(color: Color(0x80000000), blurRadius: 4, offset: Offset(0, 2)),
      BoxShadow(
          color: Color(0x99000000),
          blurRadius: 44,
          spreadRadius: -8,
          offset: Offset(0, 22)),
    ],
  );

  @override
  LanternTokens copyWith() => this;

  @override
  LanternTokens lerp(LanternTokens? other, double t) =>
      other == null || t < .5 ? this : other;
}

/// Shapes, gradients and timings that do not change between day and night.
abstract final class Lantern {
  static const radiusCard = 24.0,
      radiusDialog = 28.0,
      radiusRow = 18.0,
      radiusField = 16.0,
      radiusTile = 14.0,
      radiusPill = 999.0;

  /// Gutters: phone, and the website column (1200 wide, 32 at each side).
  static const gutter = 16.0, webGutter = 32.0, webContent = 1200.0;

  /// The website layout starts here; below it is the phone layout.
  static const webMinWidth = 1024.0;

  /// Side columns of the website layout (handoff, responsive rules).
  static const sideChat = 400.0,
      sideFilters = 300.0,
      sideStudio = 480.0,
      sideSettings = 260.0,
      sideAdmin = 270.0;

  static const headerHeight = 72.0, appBarHeight = 60.0, target = 44.0;

  static const goldFill = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [LanternTokens.goldTop, LanternTokens.gold]);
  static const dangerFill = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFD4414C), Color(0xFFA31F30)]);
  static const darkFill = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF27323C), LanternTokens.ink]);
  static const progressFill = LinearGradient(
      colors: [LanternTokens.goldHi, LanternTokens.gold]);

  /// The header's 2 px gilt underline.
  static const gilt = LinearGradient(colors: [
    Color(0x00BD933F),
    LanternTokens.gold,
    LanternTokens.goldHi,
    LanternTokens.gold,
    Color(0x00BD933F),
  ]);

  static const ease = Cubic(.23, 1, .32, 1);
  static const press = Duration(milliseconds: 160),
      state = Duration(milliseconds: 220),
      enter = Duration(milliseconds: 380),
      sweep = Duration(milliseconds: 700),
      hold = Duration(milliseconds: 1200),
      none = Duration.zero;

  static const display = 'Readex Pro';
  static const text = 'IBM Plex Sans Arabic';
  static const fallback = ['IBM Plex Sans Arabic'];

  /// Readex Pro headings. Its weight is a variable axis, so it is set there
  /// as well as on [FontWeight].
  static TextStyle displayStyle(double size,
          {required Color color,
          FontWeight weight = FontWeight.w600,
          double height = 1.3}) =>
      TextStyle(
          inherit: false,
          fontFamily: display,
          fontFamilyFallback: fallback,
          fontSize: size,
          fontWeight: weight,
          fontVariations: [FontVariation.weight(weight.value.toDouble())],
          height: height,
          letterSpacing: 0,
          textBaseline: TextBaseline.alphabetic,
          decoration: TextDecoration.none,
          color: color);

  /// IBM Plex Sans Arabic for body and controls. The app bundles 400 and
  /// 700; the design's 500 and 600 fall to the nearest of the two until those
  /// weights are added (an open question for the owner).
  static TextStyle textStyle(double size,
          {required Color color,
          FontWeight weight = FontWeight.w400,
          double height = 1.55}) =>
      TextStyle(
          inherit: false,
          fontFamily: text,
          fontFamilyFallback: fallback,
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: 0,
          textBaseline: TextBaseline.alphabetic,
          decoration: TextDecoration.none,
          color: color);

  /// Numbers that tick (viewers, countdowns) keep their width.
  static const tabular = [FontFeature.tabularFigures()];

  /// Non-essential motion is off when the device asks for less of it or the
  /// person chose calm motion in Settings.
  static bool calm(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

extension LanternContext on BuildContext {
  /// The Lantern tokens of the nearest theme; day when the theme has none.
  LanternTokens get lt =>
      Theme.of(this).extension<LanternTokens>() ?? LanternTokens.day;

  bool get isLanternSkin => skin == AppSkin.lantern;

  /// The website layout (1024 and wider).
  bool get lanternWide =>
      MediaQuery.sizeOf(this).width >= Lantern.webMinWidth;

  bool get lanternArabic => Localizations.localeOf(this).languageCode == 'ar';
}
