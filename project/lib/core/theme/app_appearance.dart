import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A device preference, independent of sign-in and server-owned settings.
class AppAppearance extends ChangeNotifier {
  AppAppearance({SharedPreferences? preferences}) : _preferences = preferences;

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
