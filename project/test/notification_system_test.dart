import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/notifications/notification_models.dart';
import 'package:streamer_app/core/services/notifications/watch_session_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TC-NOTIF-01: 10-Minute Rolling Rate Limiter & Throttling Tests', () {
    late AppProvider provider;

    setUp(() {
      provider = AppProvider();
      WatchSessionTracker.reset();
    });

    test('Enforces default 5 notifications per 10-minute cap', () {
      expect(provider.notificationPreferences.maxPer10Min, equals(5));

      // Dispatch 5 notifications (should all succeed)
      for (int i = 1; i <= 5; i++) {
        final success = provider.addEnhancedNotification(
          AppNotificationModel(
            id: 'notif_test_$i',
            type: NotificationType.streamerLiveVideo,
            titleEn: 'Live Stream $i',
            titleAr: 'بث مباشر $i',
            bodyEn: 'Body $i',
            bodyAr: 'محتوى $i',
            timestamp: DateTime.now(),
          ),
        );
        expect(success, isTrue);
      }

      expect(provider.enhancedNotifications.length, equals(5));

      // 6th notification within the same 10 minutes MUST be throttled
      final throttledSuccess = provider.addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_test_6',
          type: NotificationType.streamerLiveVideo,
          titleEn: 'Live Stream 6',
          titleAr: 'بث مباشر 6',
          bodyEn: 'Body 6',
          bodyAr: 'محتوى 6',
          timestamp: DateTime.now(),
        ),
      );

      expect(throttledSuccess, isFalse);
      expect(provider.enhancedNotifications.length, equals(5));
    });

    test('Respects user custom rate limit changes via settings slider', () {
      provider.setNotificationRateLimit(8);
      expect(provider.notificationPreferences.maxPer10Min, equals(8));

      for (int i = 1; i <= 8; i++) {
        final success = provider.addEnhancedNotification(
          AppNotificationModel(
            id: 'notif_custom_$i',
            type: NotificationType.newVodUpload,
            titleEn: 'VOD $i',
            titleAr: 'محاضرة $i',
            bodyEn: 'Body $i',
            bodyAr: 'محتوى $i',
            timestamp: DateTime.now(),
          ),
        );
        expect(success, isTrue);
      }

      expect(provider.enhancedNotifications.length, equals(8));

      // 9th should be throttled
      final throttled = provider.addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_custom_9',
          type: NotificationType.newVodUpload,
          titleEn: 'VOD 9',
          titleAr: 'محاضرة 9',
          bodyEn: 'Body 9',
          bodyAr: 'محتوى 9',
          timestamp: DateTime.now(),
        ),
      );
      expect(throttled, isFalse);
    });
  });

  group('TC-NOTIF-02: Quick Mute & Channel Silence Controls', () {
    late AppProvider provider;

    setUp(() {
      provider = AppProvider();
    });

    test('Muting an entity prevents all notifications from that streamer/org', () {
      const streamerId = 'prof_alghamdi_01';

      // 1. Initially unmuted
      expect(provider.isEntityMuted(streamerId), isFalse);

      final ok = provider.addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_live_1',
          type: NotificationType.streamerLiveVideo,
          streamerId: streamerId,
          titleEn: 'Live Now',
          titleAr: 'مباشر الآن',
          bodyEn: 'Body',
          bodyAr: 'محتوى',
          timestamp: DateTime.now(),
        ),
      );
      expect(ok, isTrue);

      // 2. Mute the entity
      provider.toggleMuteEntity(streamerId);
      expect(provider.isEntityMuted(streamerId), isTrue);

      // 3. New notification from muted streamer should be blocked
      final blocked = provider.addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_live_2',
          type: NotificationType.streamerLiveVideo,
          streamerId: streamerId,
          titleEn: 'Live Again',
          titleAr: 'مباشر مجدداً',
          bodyEn: 'Body',
          bodyAr: 'محتوى',
          timestamp: DateTime.now(),
        ),
      );
      expect(blocked, isFalse);

      // 4. Unmute the entity
      provider.toggleMuteEntity(streamerId);
      expect(provider.isEntityMuted(streamerId), isFalse);
    });
  });

  group('TC-NOTIF-03: 1-Hour Watch Milestone Tracker Tests', () {
    test('Does not trigger thank-you notification if watched < 60 minutes', () {
      WatchSessionTracker.reset();
      WatchSessionTracker.simulateWatchedSeconds('stream_live_992', 'amir_01', 'Amir Al-Hatemi', 1800); // 30 mins

      bool milestoneFired = false;
      final result = WatchSessionTracker.onStreamEnded(
        'stream_live_992',
        onMilestoneReached: (_, __, ___) => milestoneFired = true,
      );

      expect(result, isFalse);
      expect(milestoneFired, isFalse);
    });

    test('Triggers humanized thank-you notification when watched >= 60 minutes upon stream end', () {
      WatchSessionTracker.reset();
      WatchSessionTracker.simulateWatchedSeconds('stream_live_992', 'amir_01', 'Amir Al-Hatemi', 3650); // > 1 hr

      bool milestoneFired = false;
      String reachedStreamer = '';

      final result = WatchSessionTracker.onStreamEnded(
        'stream_live_992',
        onMilestoneReached: (spkId, spkName, duration) {
          milestoneFired = true;
          reachedStreamer = spkName;
        },
      );

      expect(result, isTrue);
      expect(milestoneFired, isTrue);
      expect(reachedStreamer, equals('Amir Al-Hatemi'));
    });
  });

  group('TC-NOTIF-04: 14 Humanized Saudi Arabic Event Template Verification', () {
    late AppProvider provider;

    setUp(() {
      provider = AppProvider();
    });

    test('Correctly dispatches humanized guest speaker invite', () {
      final success = provider.notifyOrgGuestInvite(
        orgNameEn: 'Dalilk 4 IELTS',
        orgNameAr: 'أكاديمية دليلك',
        streamTitle: 'Mastering Academic IELTS Speaking',
      );

      expect(success, isTrue);
      final notif = provider.enhancedNotifications.first;
      expect(notif.type, equals(NotificationType.orgLiveGuestInvite));
      expect(notif.category, equals(NotificationCategory.invitesAndAdmin));
      expect(notif.titleAr, contains('دعوة للمشاركة كمتحدث ضيف'));
      expect(notif.bodyAr, contains('تدعوك أكاديمية دليلك للمشاركة كمتحدث ضيف'));
    });

    test('Correctly dispatches humanized application approval & rejection', () {
      // Approved
      provider.addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_app_appr',
          type: NotificationType.streamerApplicationApproved,
          titleEn: '🎉 Broadcaster Application Approved!',
          titleAr: '🎉 أهلاً بك في نخبة المذيعين!',
          bodyEn: 'Congratulations Amir!',
          bodyAr: 'تهانينا أمير! تم اعتماد طلبك بنجاح.',
          timestamp: DateTime.now(),
        ),
      );

      final appr = provider.enhancedNotifications.first;
      expect(appr.type, equals(NotificationType.streamerApplicationApproved));
      expect(appr.category, equals(NotificationCategory.invitesAndAdmin));

      // Rejected
      provider.addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_app_rej',
          type: NotificationType.streamerApplicationRejected,
          titleEn: '📋 Broadcaster Application Status Update',
          titleAr: '📋 تحديث بخصوص طلب التوثيق الأكاديمي',
          bodyEn: 'Thank you for applying.',
          bodyAr: 'نشكر اهتمامك بالانضمام لمنصتنا.',
          timestamp: DateTime.now(),
        ),
      );

      final rej = provider.enhancedNotifications.first;
      expect(rej.type, equals(NotificationType.streamerApplicationRejected));
    });

    test('Category filtering and read states work accurately', () {
      provider.addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_vod_1',
          type: NotificationType.newVodUpload,
          titleEn: 'New Lecture',
          titleAr: 'محاضرة جديدة',
          bodyEn: 'Body',
          bodyAr: 'محتوى',
          timestamp: DateTime.now(),
        ),
      );

      final vodNotifs = provider.enhancedNotifications
          .where((n) => n.category == NotificationCategory.vods)
          .toList();
      expect(vodNotifs.length, equals(1));

      expect(provider.unreadNotificationsCount, greaterThan(0));
      provider.markAllNotificationsAsRead();
      expect(provider.unreadNotificationsCount, equals(0));
    });
  });
}
