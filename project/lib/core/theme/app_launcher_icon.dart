import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LauncherIconException implements Exception {
  const LauncherIconException();
}

/// Android launcher state follows the persisted appearance, including on startup.
abstract final class AppLauncherIcon {
  static const channel = MethodChannel('streamer_app/appearance');

  static Future<void> apply(bool hidayah) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await channel.invokeMethod<void>('setHidayahIcon', {'enabled': hidayah});
    } on PlatformException {
      throw const LauncherIconException();
    } on MissingPluginException {
      throw const LauncherIconException();
    }
  }
}
