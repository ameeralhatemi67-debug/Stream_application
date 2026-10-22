import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_skin.dart';

/// The design this device shows (ADR-016), read before the first frame so the
/// app never opens in one skin and flips to the other.
///
/// On the web a link can carry the skin ("?skin=hedayah-skin" before the
/// "#/"), so the team can share either design without signing in to reach
/// Settings. A linked skin is remembered like one chosen in Settings.
Future<AppSkin> readAppSkin({SharedPreferences? store, Uri? link}) async {
  try {
    final preferences = store ?? await SharedPreferences.getInstance();
    final linked = AppSkin.tryParse(
        (link ?? (kIsWeb ? Uri.base : null))?.queryParameters['skin']);
    if (linked != null) {
      await preferences.setString(AppSkin.preferenceKey, linked.id);
      return linked;
    }
    return AppSkin.tryParse(preferences.getString(AppSkin.preferenceKey)) ??
        AppSkin.gold;
  } catch (error) {
    debugPrint('App skin not read: $error');
    return AppSkin.gold;
  }
}

Future<void> saveAppSkin(AppSkin skin, {SharedPreferences? store}) async {
  try {
    final preferences = store ?? await SharedPreferences.getInstance();
    await preferences.setString(AppSkin.preferenceKey, skin.id);
  } catch (error) {
    debugPrint('App skin not saved: $error');
  }
}
