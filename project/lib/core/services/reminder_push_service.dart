import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/reminder_firebase_config.dart';
import 'upcoming_schedule_service.dart';

enum ReminderPushStatus { unavailable, notGranted, granted }

class ReminderPushService {
  ReminderPushService(this._schedules);
  final UpcomingScheduleService _schedules;
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _token;
  String _language = 'en';

  static Future<void> initializeIfConfigured() async {
    if (!ReminderFirebaseConfig.configured) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: ReminderFirebaseConfig.options);
      }
    } catch (e) {
      debugPrint('Reminder push initialization failed: $e');
    }
  }

  bool get ready =>
      ReminderFirebaseConfig.configured && Firebase.apps.isNotEmpty;

  void attach(
      {required void Function(Map<String, dynamic>) onMessage,
      required void Function(Map<String, dynamic>) onOpen}) {
    if (!ready) return;
    _messageSubscription ??= FirebaseMessaging.onMessage
        .listen((message) => onMessage(message.data));
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp
        .listen((message) => onOpen(message.data));
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) onOpen(message.data);
    });
    _refreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final oldToken = _token;
      if (oldToken != null && oldToken != token) {
        try {
          await _schedules.removeDevice(oldToken);
        } catch (_) {}
      }
      _token = token;
      try {
        await _schedules.upsertDevice(
            token, kIsWeb ? 'web' : 'android', _language);
      } catch (e) {
        debugPrint('Push token save failed: $e');
      }
    });
  }

  Future<ReminderPushStatus> sync(
      {required bool requestPermission, required String language}) async {
    _language = language == 'ar' ? 'ar' : 'en';
    if (!ready) return ReminderPushStatus.unavailable;
    final accountId = _schedules.client.auth.currentUser?.id;
    if (accountId == null) return ReminderPushStatus.unavailable;
    final messaging = FirebaseMessaging.instance;
    final settings = requestPermission
        ? await messaging.requestPermission()
        : await messaging.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return ReminderPushStatus.notGranted;
    }
    final token = await messaging.getToken(
        vapidKey: kIsWeb ? ReminderFirebaseConfig.vapidKey : null);
    if (token == null || token.isEmpty) return ReminderPushStatus.unavailable;
    if (_schedules.client.auth.currentUser?.id != accountId) {
      return ReminderPushStatus.unavailable;
    }
    _token = token;
    await _schedules.upsertDevice(token, kIsWeb ? 'web' : 'android', _language);
    return ReminderPushStatus.granted;
  }

  Future<void> signOut() async {
    if (!ready) return;
    final token = _token;
    if (token != null) {
      try {
        await _schedules.removeDevice(token);
      } catch (_) {/* Token is invalidated below. */}
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Push token invalidation failed: $e');
    }
    _token = null;
  }

  void dispose() {
    _refreshSubscription?.cancel();
    _messageSubscription?.cancel();
    _openedSubscription?.cancel();
  }
}
