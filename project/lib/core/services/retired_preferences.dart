import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device settings left behind by switches that no longer exist: the green
/// or gold palette (ADR-013) and the Hadayah Live / Lessons app switch. Lessons
/// is part of Hadayah Live now (ADR-014), so a device that had chosen Lessons
/// opens on the Discovery feed like every other.
const retiredPreferenceKeys = ['hidayah_palette_enabled', 'app_experience'];

Future<void> forgetRetiredPreferences([SharedPreferences? store]) async {
  try {
    final preferences = store ?? await SharedPreferences.getInstance();
    for (final key in retiredPreferenceKeys) {
      if (preferences.containsKey(key)) await preferences.remove(key);
    }
  } catch (error) {
    debugPrint('Retired preferences could not be removed: $error');
  }
}
