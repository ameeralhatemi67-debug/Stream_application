import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_launcher_icon.dart';

/// A device preference, independent of sign-in and server-owned settings.
class AppAppearance extends ChangeNotifier {
  AppAppearance({
    SharedPreferences? preferences,
    Future<void> Function(bool)? updateLauncherIcon,
  })  : _preferences = preferences,
        _updateLauncherIcon = updateLauncherIcon ?? AppLauncherIcon.apply;

  final Future<void> Function(bool) _updateLauncherIcon;

  static const preferenceKey = 'hidayah_palette_enabled';
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async =>
      _preferences ??= await SharedPreferences.getInstance();

  bool _hidayah = false;
  bool _disposed = false;
  bool get hidayah => _hidayah;
  Future<void> _pendingWrite = Future<void>.value();

  Future<void> restore() async {
    try {
      final preferences = await _store;
      final restored = preferences.getBool(preferenceKey) ?? false;
      if (_hidayah != restored) {
        _hidayah = restored;
        if (!_disposed) notifyListeners();
      }
    } catch (error) {
      debugPrint('Appearance preference could not be loaded: $error');
    }
    try {
      await _updateLauncherIcon(_hidayah);
    } catch (error) {
      // A later startup or toggle retries; an icon failure must not lose the theme.
      debugPrint('Launcher icon could not be restored: $error');
    }
  }

  /// Serialize double-clicks so a slow write cannot restore an older choice.
  Future<void> toggle() {
    final operation = _pendingWrite.then((_) async {
      final next = !_hidayah;
      final preferences = await _store;
      if (!await preferences.setBool(preferenceKey, next)) {
        throw StateError('Appearance preference could not be saved');
      }
      _hidayah = next;
      if (!_disposed) notifyListeners();
      await _updateLauncherIcon(next);
    });
    _pendingWrite =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
