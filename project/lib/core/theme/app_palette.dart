import 'hidayah_gold.dart';
export 'hidayah_gold.dart';

/// Role names for the Hidayah Gold values the app reaches for most (see
/// [HidayahGold] for the full ramps). Hidayah Gold is the only design.
abstract final class AppPalette {
  static const gold = HidayahGold.g500;
  static const goldLight = HidayahGold.g400;

  /// Bronze: the primary/brand colour as text or as a fill under white text.
  static const goldInk = HidayahGold.g700;
  static const ivory = HidayahGold.g50;
  static const paper = HidayahGold.card;
  static const ink = HidayahGold.s900;

  /// Media and dark app-bar surfaces.
  static const slate = HidayahGold.s900;
}
