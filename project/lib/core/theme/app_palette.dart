import 'package:flutter/material.dart';
import 'hidayah_gold.dart';
export 'hidayah_gold.dart';

/// The original tokens remain constant; themed consumers resolve them here.
/// With [hidayah] on, each green-system value resolves to the Hidayah Gold
/// value for the role it plays (see [HidayahGold]).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({this.hidayah = false});

  final bool hidayah;

  static const gold = HidayahGold.g500;
  static const goldLight = HidayahGold.g400;

  /// Bronze: the primary/brand colour as text or as a fill under white text.
  static const goldInk = HidayahGold.g700;
  static const ivory = HidayahGold.g50;
  static const paper = HidayahGold.card;
  static const ink = HidayahGold.s900;

  /// Media and dark app-bar surfaces.
  static const slate = HidayahGold.s900;

  // Keyed by the green system's RGB. Dark greens that carried white text or
  // acted as text resolve to bronze (still a dark colour, so white text and
  // ivory backgrounds keep their contrast); surfaces resolve to ivory/white;
  // the forest darks resolve to night slate.
  static const _colors = <int, Color>{
    // AppTheme (scheme A)
    0xFFFFFF: paper,
    0xECF6EF: HidayahGold.g100,
    0xD9DDDE: HidayahGold.hairline,
    0x737B7D: HidayahGold.s500,
    0x202B2B: ink,
    0x485554: HidayahGold.s700,
    0x586563: HidayahGold.s600,
    0x17643F: goldInk,
    0x327044: goldInk,
    0x22613D: HidayahGold.success,
    0x7C5012: HidayahGold.warning,
    0x9D3044: HidayahGold.live,
    0x243536: slate,
    0xE5E8E7: Color(0xFFEDE8DE),
    0xD7EDDC: HidayahGold.g100,
    0xB8DBB9: HidayahGold.g200,
    // Canopy
    0x0A2C1B: HidayahGold.s950,
    0x0E3A24: HidayahGold.s800,
    0x145030: HidayahGold.g800,
    0x22804D: goldInk,
    0x2F9A55: HidayahGold.g400,
    0x31A05A: HidayahGold.g300,
    0xBFE6CD: HidayahGold.g200,
    0xE3F6EA: HidayahGold.g100,
    0xF4FFF7: ivory,
    0x12251C: ink,
    0x3C5247: HidayahGold.s700,
    0x5D7266: HidayahGold.s600,
    0xD3E5DA: HidayahGold.hairline,
    0x7A9585: HidayahGold.s500,
    0xB3263E: HidayahGold.live,
    0xC9A24B: gold,
    0x1B7A6E: HidayahGold.info,
    0x123E26: HidayahGold.g900,
    0x123E24: HidayahGold.s800,
    0x23773F: HidayahGold.s900,
    0x256B3F: HidayahGold.g600,
    0xA3203A: Color(0xFF9A1C2E),
    0xC8344C: Color(0xFFC2343F),
  };

  // Whole gradients that change design rather than hue, keyed by their
  // stop colours.
  static final _gradients = <String, Gradient>{
    _key(const [0x145030, 0x22804D]): HidayahGradients.minted, // pill
    _key(const [0x17643F, 0x327044]): HidayahGradients.minted, // brand
    _key(const [0x256B3F, 0x31A05A]): HidayahGradients.meter, // pillWide
    _key(const [0x123E24, 0x23773F, 0x31A05A]): HidayahGradients.night, // panel
    _key(const [0x0E3A24, 0x17643F, 0x2F9A55]): HidayahGradients.night, // canopy
    _key(const [0xF4FFF7, 0xE3F6EA]): HidayahGradients.ivory, // dawn
    _key(const [0xD7EDDC, 0xB8DBB9]):
        const LinearGradient(colors: [HidayahGold.g100, HidayahGold.g200]),
    _key(const [0xBFE6CD, 0xE3F6EA]): const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [HidayahGold.g200, HidayahGold.g100]),
    _key(const [0x145030, 0x31A05A, 0xBFE6CD, 0x145030]): HidayahGradients.ring,
    _key(const [0xA3203A, 0xC8344C]): HidayahGradients.live,
  };

  static String _key(List<int> rgb) => rgb.join(',');

  Color color(Color original) {
    if (!hidayah) return original;
    final replacement = _colors[original.toARGB32() & 0x00FFFFFF];
    return replacement?.withValues(alpha: original.a) ?? original;
  }

  T gradient<T extends Gradient>(T original) {
    if (!hidayah) return original;
    final rgb = original.colors.map((c) => c.toARGB32() & 0x00FFFFFF).toList();
    final designed = _gradients[_key(rgb)];
    if (designed is T) return _carryAlpha(designed, original) as T;
    final colors = original.colors.map(color).toList(growable: false);
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

  /// A translucent green gradient stays as translucent in gold: the overall
  /// opacity of the original carries over to the designed replacement.
  static Gradient _carryAlpha(Gradient designed, Gradient original) {
    final alpha = original.colors.map((c) => c.a).reduce((a, b) => a < b ? a : b);
    if (alpha >= 1) return designed;
    return designed.withOpacity(alpha);
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

/// Selected chips, tabs and navigation items on light surfaces. Normally the
/// accent pill; in Hidayah an ink fill, so gold stays on the primary action.
Gradient paletteSelectedFill(BuildContext context, Gradient original) =>
    paletteOf(context).hidayah ? HidayahGradients.selected : original;

/// Foreground on [paletteSelectedFill].
Color paletteOnSelected(BuildContext context, Color original) =>
    paletteOf(context).hidayah
        ? HidayahGold.g200.withValues(alpha: original.a)
        : original;

List<BoxShadow> paletteShadows(BuildContext context, List<BoxShadow> original) {
  final palette = paletteOf(context);
  if (!palette.hidayah) return original;
  return original
      .map((shadow) => shadow.copyWith(color: palette.color(shadow.color)))
      .toList(growable: false);
}
