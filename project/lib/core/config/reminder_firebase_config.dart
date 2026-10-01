import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// These Firebase client identifiers are public build configuration, not
/// service-account credentials. A build without them keeps the app usable.
abstract final class ReminderFirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const vapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  static bool get supported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  static bool get configured =>
      supported &&
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      senderId.isNotEmpty &&
      projectId.isNotEmpty &&
      (!kIsWeb || vapidKey.isNotEmpty);

  static FirebaseOptions get options => const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
      );
}
