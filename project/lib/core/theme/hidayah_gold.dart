import 'package:flutter/material.dart';

/// Hidayah Gold, the palette behind the Settings logo toggle (owner review
/// 2026-10-19). The gold ramp is anchored on the logo gold ([g500]) and the
/// slate ramp on the logo's star grey ([s500]); both were built in OKLCH, so
/// each step moves lightness evenly and the gold warms in its dark steps.
///
/// Rules the tokens encode:
/// * Gold is a fill, never small text on a light surface: [g500] is 2.6:1 on
///   [g50]. Text uses slate; links and gold labels use bronze [g700] (5.7:1).
/// * Gold is kept for the primary action. Selected chips, tabs and nav items
///   use an ink fill with [g200] text.
/// * Every gradient is lit from the top, so it reads the same in RTL and LTR.
abstract final class HidayahGold {
  static const g50 = Color(0xFFFBF7ED), // page ivory
      g100 = Color(0xFFF6ECD9), // tags, tint surfaces
      g200 = Color(0xFFEDDAB4), // text on ink selections
      g300 = Color(0xFFE2C389), // gold text on night (10:1)
      g400 = Color(0xFFD2A95F),
      g500 = Color(0xFFC1923B), // logo gold
      g600 = Color(0xFFA87726), // icons and badges on white (3:1+)
      g700 = Color(0xFF805B1B), // bronze: links and gold labels
      g800 = Color(0xFF6E4A14), // text on g100
      g900 = Color(0xFF4B320E),
      shine = Color(0xFFF7E6AD); // the highlight in gilded ornament

  static const s50 = Color(0xFFF3F6F8),
      s100 = Color(0xFFE5EBEF),
      s200 = Color(0xFFCED5DB),
      s300 = Color(0xFFACB6BE),
      s400 = Color(0xFF8A959F),
      s500 = Color(0xFF6D7881), // logo star grey: not for small text on ivory
      s600 = Color(0xFF515C66), // muted text
      s700 = Color(0xFF39444D), // secondary text
      s800 = Color(0xFF242E37),
      s900 = Color(0xFF151D24), // ink
      s950 = Color(0xFF0B1117);

  static const card = Color(0xFFFFFFFF),
      hairline = Color(0xFFEADFCB),
      live = Color(0xFFAF2934),
      success = Color(0xFF2D7647), // 4.7:1 on g100 (2F7A4A missed AA there)
      warning = Color(0xFF9A5B0E),
      info = Color(0xFF2D6F86);
}

abstract final class HidayahGradients {
  /// Primary buttons, the play button and dark-surface selections. The only
  /// gradient that carries text: ink stays above 6:1 at the darkest stop.
  static const minted = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0, .5, 1],
      colors: [HidayahGold.g300, HidayahGold.g400, HidayahGold.g500]);

  /// Ornament only: underlines, rings and dividers. Never put text on it.
  static const gilded = LinearGradient(
      begin: Alignment(-1, -.45),
      end: Alignment(1, .45),
      stops: [0, .18, .34, .48, .60, .78, 1],
      colors: [
        HidayahGold.g800,
        HidayahGold.g600,
        HidayahGold.g400,
        HidayahGold.shine,
        HidayahGold.g400,
        HidayahGold.g500,
        HidayahGold.g700
      ]);

  static const ring = SweepGradient(colors: [
    HidayahGold.g700,
    HidayahGold.g500,
    HidayahGold.shine,
    HidayahGold.g400,
    HidayahGold.g700
  ]);

  /// Hero bands, panels, the footer: replaces the green panel.
  static const night = LinearGradient(
      begin: Alignment(-.5, -1),
      end: Alignment(.5, 1),
      stops: [0, .55, 1],
      colors: [HidayahGold.s800, HidayahGold.s900, HidayahGold.s950]);

  /// Selected chips, tabs and navigation items on light surfaces.
  static const selected = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [HidayahGold.s800, HidayahGold.s900]);

  static const ivory = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [HidayahGold.g50, HidayahGold.g100]);

  /// LIVE badge: white text passes 5.4:1 at the lighter stop.
  static const live = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFC2343F), Color(0xFF9A1C2E)]);

  /// Meters and progress bars (decorative, no text).
  static const meter = LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: [HidayahGold.g600, HidayahGold.g300]);

  /// The warm glow in the top corner of night bands.
  static const nightGlow = RadialGradient(
      center: AlignmentDirectional(.85, -1.1),
      radius: 1.1,
      colors: [Color(0x3DC1923B), Color(0x00C1923B)]);
}

abstract final class HidayahShadow {
  /// Minted buttons: a soft bronze drop under the coin.
  static const minted = [
    BoxShadow(color: Color(0x294B320E), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
        color: Color(0x8C86601E),
        blurRadius: 18,
        spreadRadius: -10,
        offset: Offset(0, 8)),
  ];

  /// White cards on ivory.
  static const card = [
    BoxShadow(
        color: Color(0x3D6E4A14),
        blurRadius: 30,
        spreadRadius: -22,
        offset: Offset(0, 14)),
  ];
}

abstract final class HidayahType {
  /// Geometric Kufi display face for website titles and big numbers only.
  static const display = 'Reem Kufi';
  static const text = 'IBM Plex Sans Arabic';
}
