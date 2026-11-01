import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/notifications/notification_models.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/domain/lessons_rules.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'support/fixture_application_db.dart';
import 'support/scripted_broadcasts.dart';

const _me = '86000000-0000-4000-8000-000000000001';
const _notice = '86000000-0000-4000-8000-0000000000c1';

/// The sample programme, recording reminder writes.
class _RecordingLessons extends DemoLessonsRepository {
  _RecordingLessons() : super(persona: LessonsDemoPersona.viewer);
  final writes = <(String, String, DateTime)>[];
  @override
  Future<void> setReminder(String lessonId, String lead, DateTime remindAt) async {
    writes.add((lessonId, lead, remindAt));
    await super.setReminder(lessonId, lead, remindAt);
  }
}

/// ...behaving like the server (not a demo).
class _ServerLikeLessons extends _RecordingLessons {
  @override
  bool get isDemo => false;
}

Map<String, dynamic> _push({String viewer = _me, String id = _notice, String route = '/lessons/lesson/abc'}) => {
      'type': 'lesson_notice',
      'viewer_id': viewer,
      'notification_id': id,
      'route': route,
      'title_ar': 'أُلغي موعد: تفسير',
      'title_en': 'Cancelled: Tafsir',
      'body_ar': '2026-11-03 — سفر الشيخ',
      'body_en': '2026-11-03: Travel',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ScriptedBroadcasts? broadcasts;
  AppProvider signedIn() {
    broadcasts = ScriptedBroadcasts();
    final provider = AppProvider.withServices(
        adminDbService: FixtureApplicationDb(),
        organizationBroadcastService: broadcasts!);
    provider.debugSetSignedInForTests(
        email: 'viewer@example.invalid', isStreamer: false, userId: _me);
    return provider;
  }

  test('a lesson alert that arrives while the app is open is in the bell, shown, and refreshes the inbox',
      () {
    final provider = signedIn();
    final shown = <PushWhileOpen>[];
    var refreshed = 0;
    provider.attachReminderPush(
        onOpen: (_) async {},
        onLessonNotice: () => refreshed++,
        onPushWhileOpen: shown.add);
    provider.handlePushWhileOpen(_push());
    final item = provider.enhancedNotifications.single;
    expect(item.type, NotificationType.scheduleReminder);
    expect(item.titleAr, 'أُلغي موعد: تفسير');
    expect(item.actionUrl, '/lessons/lesson/abc');
    expect(shown.single.titleEn, 'Cancelled: Tafsir');
    expect(shown.single.route, '/lessons/lesson/abc');
    expect(refreshed, 1);
    provider.dispose();
  });

  test('a lesson alert for another account, or without a valid id, is ignored',
      () {
    final provider = signedIn();
    final shown = <PushWhileOpen>[];
    provider.attachReminderPush(onOpen: (_) async {}, onPushWhileOpen: shown.add);
    provider.handlePushWhileOpen(_push(viewer: '86000000-0000-4000-8000-0000000000ff'));
    provider.handlePushWhileOpen(_push(id: '../admin'));
    expect(provider.enhancedNotifications, isEmpty);
    expect(shown, isEmpty);
    provider.dispose();
  });

  test('a burst of lesson alerts is not throttled away', () {
    final provider = signedIn();
    provider.updateNotificationPreferences(
        provider.notificationPreferences.copyWith(maxPer10Min: 1));
    for (var i = 0; i < 4; i++) {
      provider.handlePushWhileOpen(_push(id: '86000000-0000-4000-8000-00000000000$i'));
    }
    expect(provider.enhancedNotifications, hasLength(4));
    provider.dispose();
  });

  test('tapping a lesson alert opens its page and marks it read', () async {
    final provider = signedIn();
    final opened = <String>[], read = <String>[];
    provider.attachReminderPush(
        onOpen: (_) async {},
        onOpenRoute: (route) async => opened.add(route),
        onLessonNoticeRead: read.add);
    provider.handlePushOpened(_push(route: '/admin/lessons/approvals'));
    expect(opened, ['/admin/lessons/approvals']);
    expect(read, [_notice]);
    provider.dispose();
  });

  test('a lesson alert only ever opens a Lessons page', () {
    for (final bad in ['https://evil.example', '/admin', '/lessons/../admin', '//x', '', null]) {
      expect(AppProvider.lessonNoticeRoute(bad), '/lessons', reason: '$bad');
    }
    expect(AppProvider.lessonNoticeRoute('/lessons/requests/abc-1'), '/lessons/requests/abc-1');
    expect(AppProvider.lessonNoticeRoute('/lessons/me/preacher'), '/lessons/me/preacher');
  });

  test('reading a lesson alert in the bell marks it read in the inbox', () {
    final provider = signedIn();
    final read = <String>[];
    provider.attachReminderPush(onOpen: (_) async {}, onLessonNoticeRead: read.add);
    provider.handlePushWhileOpen(_push());
    provider.markNotificationAsRead('lesson:$_notice');
    expect(read, [_notice]);
    read.clear();
    provider.handlePushWhileOpen(_push(id: '86000000-0000-4000-8000-0000000000c2'));
    provider.markAllNotificationsAsRead();
    expect(read, ['86000000-0000-4000-8000-0000000000c2']);
    provider.dispose();
  });

  test('a live alert or reminder while the app is open is shown too', () {
    final provider = signedIn();
    final shown = <PushWhileOpen>[];
    provider.attachReminderPush(onOpen: (_) async {}, onPushWhileOpen: shown.add);
    provider.handlePushWhileOpen({
      'type': 'org_event',
      'viewer_id': _me,
      'event_id': _notice,
      'kind': 'show_live',
      'session_id': '86000000-0000-4000-8000-0000000000d1',
      'title_en': 'Live now - Fahd',
      'title_ar': 'مباشر الآن - فهد',
    });
    expect(shown.single.titleEn, 'Live now - Fahd');
    expect(shown.single.route, '/live/86000000-0000-4000-8000-0000000000d1');
    provider.dispose();
  });

  test('lesson alerts have their own switch, saved to the server', () async {
    final provider = signedIn();
    expect(provider.notificationPreferences.lessonsEnabled, isTrue);
    provider.updateNotificationPreferences(
        provider.notificationPreferences.copyWith(lessonsEnabled: false));
    await Future<void>.delayed(Duration.zero);
    expect(broadcasts!.calls, contains('push-preferences:true:true:false'));
    provider.dispose();
  });

  group('asking for notifications at sign-in', () {
    test('someone who already follows channels is asked, once', () async {
      final provider = signedIn()..debugRemindersAvailable = true;
      await provider.toggleFollow('86000000-0000-4000-8000-0000000000e1');
      expect(await provider.shouldAskForPush(_me), isTrue);
      expect(await provider.shouldAskForPush(_me), isFalse);
      provider.dispose();
    });

    test('someone who follows nobody is not', () async {
      final provider = signedIn()..debugRemindersAvailable = true;
      expect(await provider.shouldAskForPush(_me), isFalse);
      provider.dispose();
    });

    test('a build without push configured never asks', () async {
      final provider = signedIn()..debugRemindersAvailable = false;
      await provider.toggleFollow('86000000-0000-4000-8000-0000000000e1');
      expect(await provider.shouldAskForPush(_me), isFalse);
      provider.dispose();
    });
  });

  test('a reminder left on a moved lesson\'s old time is put on the new time',
      () async {
    final repository = _ServerLikeLessons();
    final catalog = await repository.loadCatalog();
    final today = DateTime.now();
    final later = catalog.lessons.values.firstWhere((l) =>
        l.status == 'approved' &&
        l.date.isAfter(DateTime(today.year, today.month, today.day + 2)));
    // As if the reminder was set before an admin moved the lesson.
    final stale = reminderInstant(later, '30', catalog)
        .subtract(const Duration(hours: 5));
    await repository.setReminder(later.id, '30', stale);
    repository.writes.clear();

    final controller = LessonsController(repository);
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    final moved = repository.writes.where((w) => w.$1 == later.id).toList();
    expect(moved, hasLength(1));
    expect(moved.single.$2, '30');
    expect(moved.single.$3, reminderInstant(later, '30', catalog));

    // Once aligned, the next load writes nothing for it.
    repository.writes.clear();
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(repository.writes.where((w) => w.$1 == later.id), isEmpty);
    controller.dispose();
  });

  test('sample data is never written back', () async {
    final repository = _RecordingLessons();
    final controller = LessonsController(repository);
    await controller.refresh();
    await Future<void>.delayed(Duration.zero);
    // The demo's seeded reminder keeps its sample time.
    expect(controller.mine.reminders, isNotEmpty);
    expect(repository.writes, isEmpty);
    controller.dispose();
  });
}
