import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_skin.dart';

/// The design this device shows (ADR-016), read before the first frame so the
/// app never opens in one skin and flips to the other.
///
/// On the web a link can carry the skin ("?skin=hedayah-skin" before the
/// "#/"), so the team can share either design without signing in to reach
/// Settings. A linked skin is remembered like one chosen in Settings.
///
/// Gold & black is no longer offered (ADR-027): a device that saved it, or a
/// link that names it, opens in Lantern and Arch, the default.
Future<AppSkin> readAppSkin({SharedPreferences? store, Uri? link}) async {
  try {
    final preferences = store ?? await SharedPreferences.getInstance();
    final linked = _offered(AppSkin.tryParse(
        (link ?? (kIsWeb ? Uri.base : null))?.queryParameters['skin']));
    if (linked != null) {
      await preferences.setString(AppSkin.preferenceKey, linked.id);
      return linked;
    }
    final saved = AppSkin.tryParse(preferences.getString(AppSkin.preferenceKey));
    final offered = _offered(saved) ?? AppSkin.fallback;
    if (saved != null && saved != offered) {
      await preferences.setString(AppSkin.preferenceKey, offered.id);
    }
    return offered;
  } catch (error) {
    debugPrint('App skin not read: $error');
    return AppSkin.fallback;
  }
}

/// A retired design becomes the default one.
AppSkin? _offered(AppSkin? skin) => skin == null
    ? null
    : AppSkin.choices.contains(skin)
        ? skin
        : AppSkin.fallback;

Future<void> saveAppSkin(AppSkin skin, {SharedPreferences? store}) async {
  try {
    final preferences = store ?? await SharedPreferences.getInstance();
    await preferences.setString(AppSkin.preferenceKey, skin.id);
  } catch (error) {
    debugPrint('App skin not saved: $error');
  }
}

/// Day or night for the Lantern and Arch design, read with the skin before
/// the first frame so the opening screen does not flip.
Future<LanternAppearance> readLanternAppearance(
    {SharedPreferences? store}) async {
  try {
    final preferences = store ?? await SharedPreferences.getInstance();
    return LanternAppearance.parse(
        preferences.getString(LanternAppearance.preferenceKey));
  } catch (error) {
    debugPrint('Lantern appearance not read: $error');
    return LanternAppearance.fallback;
  }
}

Future<void> saveLanternAppearance(LanternAppearance appearance,
    {SharedPreferences? store}) async {
  try {
    final preferences = store ?? await SharedPreferences.getInstance();
    await preferences.setString(
        LanternAppearance.preferenceKey, appearance.name);
  } catch (error) {
    debugPrint('Lantern appearance not saved: $error');
  }
}

Future<bool> readLanternCalmMotion({SharedPreferences? store}) async {
  try {
    final preferences = store ?? await SharedPreferences.getInstance();
    return preferences.getBool(LanternAppearance.calmMotionKey) ?? false;
  } catch (error) {
    debugPrint('Lantern calm motion not read: $error');
    return false;
  }
}

Future<void> saveLanternCalmMotion(bool calm,
    {SharedPreferences? store}) async {
  try {
    final preferences = store ?? await SharedPreferences.getInstance();
    await preferences.setBool(LanternAppearance.calmMotionKey, calm);
  } catch (error) {
    debugPrint('Lantern calm motion not saved: $error');
  }
}
