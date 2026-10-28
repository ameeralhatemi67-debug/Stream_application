import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/notifications/notification_models.dart';
import 'package:streamer_app/features/organization/models/org_event.dart';
import 'support/fixture_application_db.dart';
import 'support/scripted_broadcasts.dart';

const _me = '84000000-0000-4000-8000-000000000001';
const _channel = '84000000-0000-4000-8000-000000000002';
const _schedule = '84000000-0000-4000-8000-000000000003';

AppProvider _signedIn(ScriptedBroadcasts broadcasts) {
  final provider = AppProvider.withServices(
      adminDbService: FixtureApplicationDb(),
      organizationBroadcastService: broadcasts);
  provider.debugSetSignedInForTests(
      email: 'viewer@example.invalid', isStreamer: false, userId: _me);
  return provider;
}

AppNotificationModel _item(String id, NotificationType type, DateTime at,
        {bool read = false}) =>
    AppNotificationModel(
        id: id,
        type: type,
        streamerId: '',
        streamerName: '',
        titleEn: 'Title',
        titleAr: 'عنوان',
        bodyEn: 'Body',
        bodyAr: 'نص',
        timestamp: at,
        isRead: read);

OrgEvent _event(String id, String kind, DateTime at) => OrgEvent(
    id: id,
    kind: kind,
    createdAt: at,
    payload: const {'title_en': 'Tafsir', 'presenter_id': _channel});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('one notification counts once on the badge', () {
    final provider = _signedIn(ScriptedBroadcasts());
    provider.addEnhancedNotification(
        _item('local-1', NotificationType.systemAlert, DateTime.now()));
    expect(provider.enhancedNotifications, hasLength(1));
    expect(provider.unreadNotificationsCount, 1);
    provider.markNotificationAsRead('local-1');
    expect(provider.unreadNotificationsCount, 0);
    provider.dispose();
  });

  test('a reminder that arrives while the app is open is in the centre', () {
    final provider = _signedIn(ScriptedBroadcasts());
    provider.handlePushWhileOpen({
      'type': 'upcoming_reminder',
      'viewer_id': _me,
      'streamer_id': _channel,
      'schedule_id': _schedule,
      'occurrence_at': '2026-10-30T18:00:00Z',
      'title_en': 'Weekly tafsir',
      'title_ar': 'تفسير أسبوعي',
      'body_en': 'Planned stream starts in 15 minutes',
      'body_ar': 'بث مخطط له بعد 15 دقيقة',
    });
    final reminder = provider.enhancedNotifications.single;
    expect(reminder.type, NotificationType.scheduleReminder);
    expect(reminder.titleAr, 'تفسير أسبوعي');
    expect(reminder.actionUrl, '/profile/$_channel?tab=upcoming');
    expect(reminder.category, NotificationCategory.live);
    expect(provider.unreadNotificationsCount, 1);
    provider.dispose();
  });

  test('a reminder for another account on this phone is ignored', () {
    final provider = _signedIn(ScriptedBroadcasts());
    provider.handlePushWhileOpen({
      'type': 'upcoming_reminder',
      'viewer_id': '84000000-0000-4000-8000-0000000000ff',
      'streamer_id': _channel,
      'schedule_id': _schedule,
    });
    expect(provider.enhancedNotifications, isEmpty);
    provider.dispose();
  });

  test('an unread server notice stays past 12 hours; an old live alert goes',
      () async {
    final old = DateTime.now().subtract(const Duration(days: 2));
    final broadcasts = ScriptedBroadcasts()
      ..eventRows = [
        _event('84000000-0000-4000-8000-0000000000a1', 'application_rejected', old),
        _event('84000000-0000-4000-8000-0000000000a2', 'show_live', old),
      ];
    final provider = _signedIn(broadcasts);
    await provider.refreshOrganizationEvents();
    final ids = provider.enhancedNotifications.map((n) => n.id).toList();
    expect(ids, contains('org:84000000-0000-4000-8000-0000000000a1'));
    expect(ids, isNot(contains('org:84000000-0000-4000-8000-0000000000a2')));
    expect(provider.unreadNotificationsCount, 1);
    // Once read it ages out like any other notification.
    provider.markNotificationAsRead('org:84000000-0000-4000-8000-0000000000a1');
    expect(provider.enhancedNotifications, isEmpty);
    provider.dispose();
  });

  test('server notices are never throttled away', () async {
    final now = DateTime.now();
    final broadcasts = ScriptedBroadcasts()
      ..eventRows = [
        for (var i = 0; i < 8; i++)
          _event('84000000-0000-4000-8000-00000000010$i', 'show_live',
              now.subtract(Duration(seconds: i))),
      ];
    final provider = _signedIn(broadcasts);
    expect(provider.notificationPreferences.maxPer10Min, lessThan(8));
    await provider.refreshOrganizationEvents();
    expect(provider.enhancedNotifications, hasLength(8));
    provider.dispose();
  });

  test('a decision shows even with admin notes switched off', () async {
    final broadcasts = ScriptedBroadcasts()
      ..eventRows = [
        _event('84000000-0000-4000-8000-0000000000b1', 'application_approved',
            DateTime.now()),
      ];
    final provider = _signedIn(broadcasts);
    provider.updateNotificationPreferences(provider.notificationPreferences
        .copyWith(adminNotesEnabled: false));
    await provider.refreshOrganizationEvents();
    expect(provider.enhancedNotifications.single.type,
        NotificationType.streamerApplicationApproved);
    provider.dispose();
  });

  test('a live push while the app is open loads the alert', () async {
    final broadcasts = ScriptedBroadcasts()
      ..eventRows = [
        _event('84000000-0000-4000-8000-0000000000c1', 'show_live', DateTime.now()),
      ];
    final provider = _signedIn(broadcasts);
    provider.handlePushWhileOpen({'type': 'org_event', 'viewer_id': _me});
    await Future<void>.delayed(Duration.zero);
    expect(provider.enhancedNotifications.single.id,
        'org:84000000-0000-4000-8000-0000000000c1');
    provider.dispose();
  });
}
