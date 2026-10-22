import 'package:flutter/material.dart';

/// The two designs a device can show (ADR-016). Gold & black is the app's own
/// design and the default; the Hedayah skin follows the association's
/// identity (hedayh.org.sa): white and mist grounds, flat gold bands with the
/// owner's lattice pattern, slate, pill buttons and Readex Pro headings.
///
/// The skin rides on the theme ([AppSkinTheme]), so any widget can ask for it
/// with [AppSkinContext.isHedayahSkin] and rebuilds when it changes.
enum AppSkin {
  gold('gold-black'),
  hedayah('hedayah-skin');

  const AppSkin(this.id);

  /// The stored and linked name ("?skin=hedayah-skin" on the web).
  final String id;

  static const preferenceKey = 'app_skin';

  /// Reads a stored value or a link parameter; "hedayah" and "gold" work too.
  static AppSkin? tryParse(String? value) => switch (value?.trim()) {
        'hedayah-skin' || 'hedayah' => AppSkin.hedayah,
        'gold-black' || 'gold' => AppSkin.gold,
        _ => null,
      };
}

@immutable
class AppSkinTheme extends ThemeExtension<AppSkinTheme> {
  const AppSkinTheme(this.skin);

  final AppSkin skin;

  @override
  AppSkinTheme copyWith({AppSkin? skin}) => AppSkinTheme(skin ?? this.skin);

  @override
  AppSkinTheme lerp(AppSkinTheme? other, double t) =>
      other == null || t < .5 ? this : other;
}

/// The skin of the theme built last, for the few text-style helpers that
/// take no context (the website's and Lessons' display face). Widgets ask
/// [AppSkinContext.isHedayahSkin] instead, which rebuilds them on a change.
abstract final class ActiveSkin {
  static AppSkin current = AppSkin.gold;
  static bool get hedayah => current == AppSkin.hedayah;
}

extension AppSkinContext on BuildContext {
  /// Gold when the theme carries no skin (tests that build their own theme).
  AppSkin get skin =>
      Theme.of(this).extension<AppSkinTheme>()?.skin ?? AppSkin.gold;

  bool get isHedayahSkin => skin == AppSkin.hedayah;
}
