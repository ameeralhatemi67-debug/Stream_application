import 'package:flutter/material.dart';

/// The designs a device can show (ADR-016, ADR-026, ADR-027). Lantern and
/// Arch is the default. Gold & black was removed as a choice on 2026-11-12
/// (ADR-027): [gold] stays only as the base the Hedayah skin's shared screens
/// are drawn on and for tests; a device or link that names it gets Lantern
/// ([readAppSkin]). The Hedayah skin follows the
/// association's identity (hedayh.org.sa): white and mist grounds, flat gold
/// bands with the owner's lattice pattern, slate, pill buttons and Readex Pro
/// headings. Lantern and Arch is the third: linen by day and ink by night,
/// the arch frame and the eight-point star, with screens of its own.
///
/// The skin rides on the theme ([AppSkinTheme]), so any widget can ask for it
/// with [AppSkinContext.isHedayahSkin] and rebuilds when it changes.
enum AppSkin {
  gold('gold-black'),
  hedayah('hedayah-skin'),
  lantern('lantern-arch');

  const AppSkin(this.id);

  /// The stored and linked name ("?skin=hedayah-skin" on the web).
  final String id;

  static const preferenceKey = 'app_skin';

  /// The designs offered in Settings, the default first. Gold & black is no
  /// longer one of them (ADR-027).
  static const choices = [AppSkin.lantern, AppSkin.hedayah];

  /// The design a device opens in when nothing (or a retired one) is saved.
  static const fallback = AppSkin.lantern;

  /// Reads a stored value or a link parameter; "hedayah", "gold" and
  /// "lantern" work too.
  static AppSkin? tryParse(String? value) => switch (value?.trim()) {
        'hedayah-skin' || 'hedayah' => AppSkin.hedayah,
        'gold-black' || 'gold' => AppSkin.gold,
        'lantern-arch' || 'lantern' => AppSkin.lantern,
        _ => null,
      };
}

/// Day or night for the Lantern and Arch design (the other two designs have
/// one look). Per device, chosen in Settings; [day] until the owner decides
/// otherwise (an open question in the identity handoff).
enum LanternAppearance {
  day,
  night,
  system;

  static const preferenceKey = 'lantern_appearance';

  /// Calm motion for the Lantern design, beside the device's own setting.
  static const calmMotionKey = 'lantern_calm_motion';

  static const fallback = LanternAppearance.day;

  static LanternAppearance parse(String? value) => LanternAppearance.values
      .firstWhere((a) => a.name == value?.trim(), orElse: () => fallback);

  /// Whether night colours apply, given the device's own brightness.
  bool isNight(Brightness platform) => switch (this) {
        LanternAppearance.day => false,
        LanternAppearance.night => true,
        LanternAppearance.system => platform == Brightness.dark,
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

  /// Gold & black or Hedayah: the two designs that share their screens.
  /// Lantern and Arch has screens of its own.
  bool get isClassicSkin => skin != AppSkin.lantern;
}
