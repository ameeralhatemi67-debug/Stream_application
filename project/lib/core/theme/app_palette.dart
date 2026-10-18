import 'package:flutter/material.dart';

/// The original tokens remain constant; themed consumers resolve them here.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({this.hidayah = false});

  final bool hidayah;

  static const gold = Color(0xFFC1923B);
  static const goldLight = Color(0xFFCFA55D);
  static const goldInk = Color(0xFF73521D);
  static const ivory = Color(0xFFF9F7EF);
  static const paper = Color(0xFFFFFEFA);
  static const ink = Color(0xFF253239);
  static const slate = Color(0xFF26363E);

  // Standalone labels use dark gold; filled gradient controls use logo gold
  // with the ink foreground returned by paletteOnAccent.
  static const _colors = <int, Color>{
    0xFFFFFF: paper,
    0xECF6EF: Color(0xFFF0EDE4),
    0xD9DDDE: Color(0xFFDEDFD9),
    0x737B7D: Color(0xFF707878),
    0x202B2B: ink,
    0x485554: Color(0xFF58666B),
    0x586563: Color(0xFF58666B),
    0x17643F: goldInk,
    0x327044: Color(0xFF8D672B),
    0x9D3044: Color(0xFFA43D42),
    0x243536: slate,
    0xE5E8E7: Color(0xFFEDEAE2),
    0xD7EDDC: Color(0xFFEFE4CD),
    0xB8DBB9: Color(0xFFE3D3B2),
    0x0A2C1B: slate,
    0x0E3A24: Color(0xFF33454E),
    0x145030: goldInk,
    0x22804D: Color(0xFF8D672B),
    0x2F9A55: goldLight,
    0x31A05A: Color(0xFFD7B47B),
    0xBFE6CD: Color(0xFFECE3D2),
    0xE3F6EA: Color(0xFFF0EDE4),
    0xF4FFF7: ivory,
    0x12251C: ink,
    0x3C5247: Color(0xFF58666B),
    0x5D7266: Color(0xFF58666B),
    0xD3E5DA: Color(0xFFDEDFD9),
    0x7A9585: Color(0xFF707878),
    0xB3263E: Color(0xFFA43D42),
    0xC9A24B: gold,
    0x1B7A6E: goldInk,
    0x123E26: slate,
    0x256B3F: goldInk,
    0x123E24: gold,
    0x23773F: goldLight,
  };

  Color color(Color original) {
    if (!hidayah) return original;
    final replacement = _colors[original.toARGB32() & 0x00FFFFFF];
    return replacement?.withValues(alpha: original.a) ?? original;
  }

  T gradient<T extends Gradient>(T original) {
    if (!hidayah) return original;
    final rgb = original.colors.map((c) => c.toARGB32() & 0x00FFFFFF).toList();
    final accent = rgb.length == 2 &&
        ((rgb[0] == 0x145030 && rgb[1] == 0x22804D) ||
            (rgb[0] == 0x17643F && rgb[1] == 0x327044));
    final colors = accent
        ? [
            gold.withValues(alpha: original.colors[0].a),
            goldLight.withValues(alpha: original.colors[1].a),
          ]
        : original.colors.map(color).toList(growable: false);
    if (original is LinearGradient) {
      return LinearGradient(
        begin: original.begin,
        end: original.end,
        colors: colors,
        stops: original.stops,
        tileMode: original.tileMode,
        transform: original.transform,
      ) as T;
    }
    if (original is RadialGradient) {
      return RadialGradient(
        center: original.center,
        radius: original.radius,
        colors: colors,
        stops: original.stops,
        tileMode: original.tileMode,
        focal: original.focal,
        focalRadius: original.focalRadius,
        transform: original.transform,
      ) as T;
    }
    if (original is SweepGradient) {
      return SweepGradient(
        center: original.center,
        startAngle: original.startAngle,
        endAngle: original.endAngle,
        colors: colors,
        stops: original.stops,
        tileMode: original.tileMode,
        transform: original.transform,
      ) as T;
    }
    return original;
  }

  @override
  AppPalette copyWith({bool? hidayah}) =>
      AppPalette(hidayah: hidayah ?? this.hidayah);

  @override
  AppPalette lerp(covariant AppPalette? other, double t) =>
      other == null || t < .5 ? this : other;
}

AppPalette paletteOf(BuildContext context) =>
    Theme.of(context).extension<AppPalette>() ?? const AppPalette();

Color paletteColor(BuildContext context, Color original) =>
    paletteOf(context).color(original);

/// Foreground for the bright primary gradient, independent of media whites.
Color paletteOnAccent(BuildContext context, Color original) =>
    paletteOf(context).hidayah
        ? AppPalette.ink.withValues(alpha: original.a)
        : original;

T paletteGradient<T extends Gradient>(BuildContext context, T original) =>
    paletteOf(context).gradient(original);

List<BoxShadow> paletteShadows(BuildContext context, List<BoxShadow> original) {
  final palette = paletteOf(context);
  if (!palette.hidayah) return original;
  return original
      .map((shadow) => shadow.copyWith(color: palette.color(shadow.color)))
      .toList(growable: false);
}
