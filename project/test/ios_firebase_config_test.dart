import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/config/reminder_firebase_config.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS reminder Firebase is unsupported and unconfigured', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(ReminderFirebaseConfig.supported, isFalse);
    expect(ReminderFirebaseConfig.configured, isFalse);
  });

  test('Android retains Firebase reminder support', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(ReminderFirebaseConfig.supported, isTrue);
  });
}
