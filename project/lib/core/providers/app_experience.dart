import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which application the shell shows: the live-streaming app or Taysir, the
/// mosque lessons programme. A device preference, switched by the logo in
/// Settings, independent of sign-in and server-owned settings.
enum Experience {
  hadayah('/feed'),
  taysir('/taysir');

  const Experience(this.home);

  /// Where the shell lands when this experience is chosen.
  final String home;
}

class AppExperience extends ChangeNotifier {
  AppExperience({SharedPreferences? preferences}) : _preferences = preferences;

  static const preferenceKey = 'app_experience';

  /// The retired palette switch (green or gold). Gold is the only design now;
  /// the key is removed on the first start after the update.
  static const legacyPaletteKey = 'hidayah_palette_enabled';

  SharedPreferences? _preferences;
  Future<SharedPreferences> get _store async =>
      _preferences ??= await SharedPreferences.getInstance();

  Experience _current = Experience.hadayah;
  bool _disposed = false;
  Future<void> _pendingWrite = Future<void>.value();

  Experience get current => _current;
  bool get taysir => _current == Experience.taysir;

  Future<void> restore() async {
    try {
      final preferences = await _store;
      final saved = preferences.getString(preferenceKey);
      final restored = Experience.values
          .firstWhere((e) => e.name == saved, orElse: () => Experience.hadayah);
      if (preferences.containsKey(legacyPaletteKey)) {
        await preferences.remove(legacyPaletteKey);
      }
      if (restored != _current) {
        _current = restored;
        if (!_disposed) notifyListeners();
      }
    } catch (error) {
      debugPrint('Experience preference could not be loaded: $error');
    }
  }

  /// Serialize double taps so a slow write cannot restore an older choice.
  Future<Experience> toggle() => set(
      _current == Experience.hadayah ? Experience.taysir : Experience.hadayah);

  Future<Experience> set(Experience next) {
    final operation = _pendingWrite.then((_) async {
      final preferences = await _store;
      if (!await preferences.setString(preferenceKey, next.name)) {
        throw StateError('Experience preference could not be saved');
      }
      _current = next;
      if (!_disposed) notifyListeners();
      return next;
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
