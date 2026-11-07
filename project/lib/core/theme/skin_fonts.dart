import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_skin.dart';
import 'hedayah_skin.dart';

/// Fonts only one design uses, registered when that design is shown.
///
/// Every `fonts:` entry in pubspec.yaml is downloaded before the web app's
/// first frame, for every visitor. Readex Pro (the Hedayah skin's headings,
/// 151 KB) is an asset instead and loads here, the first time the skin is
/// chosen or restored (2026-11-07 web speed diagnosis). Until it arrives,
/// headings use the skin's fallback fonts; Flutter lays text out again once
/// the font is registered.
abstract final class SkinFonts {
  static const readexProAsset = 'assets/fonts/ReadexPro-Variable.ttf';

  static final Map<String, Future<void>> _loads = {};

  /// Registers the fonts [skin] needs. Safe to call repeatedly; a failed
  /// load is forgotten so a later call can try again.
  static Future<void> ensureLoaded(AppSkin skin, {AssetBundle? bundle}) {
    if (skin != AppSkin.hedayah) return Future.value();
    return _loads[HedayahSkin.display] ??= _load(
            HedayahSkin.display, readexProAsset, bundle ?? rootBundle)
        .catchError((Object error) {
      _loads.remove(HedayahSkin.display);
      debugPrint('Skin font not loaded: $error');
    });
  }

  static Future<void> _load(String family, String asset, AssetBundle bundle) =>
      (FontLoader(family)..addFont(bundle.load(asset))).load();

  @visibleForTesting
  static void debugReset() => _loads.clear();
}
