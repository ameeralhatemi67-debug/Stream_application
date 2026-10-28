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
const _lesson = '86000000-0000-4000-8000-0000000000c1';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AppProvider signedIn() {
    final provider = AppProvider.withServices(
        adminDbService: FixtureApplicationDb(),
        organizationBroadcastService: ScriptedBroadcasts());
    provider.debugSetSignedInForTests(
        email: 'viewer@example.invalid', isStreamer: false, userId: _me);
    return provider;
  }

  test('a lesson reminder that arrives while the app is open is in the bell',
      () {
    final provider = signedIn();
    provider.handlePushWhileOpen({
      'type': 'lesson_reminder',
      'viewer_id': _me,
      'lesson_id': _lesson,
      'title_ar': 'تذكير بدرس: تفسير',
      'title_en': 'Lesson reminder: Tafsir',
      'body_ar': 'اليوم بعد صلاة العشاء.',
      'body_en': 'Today after Isha.',
    });
    final item = provider.enhancedNotifications.single;
    expect(item.type, NotificationType.scheduleReminder);
    expect(item.titleAr, 'تذكير بدرس: تفسير');
    expect(item.actionUrl, '/lessons/lesson/$_lesson');
    provider.dispose();
  });

  test('a lesson reminder for another account, or without a lesson, is ignored',
      () {
    final provider = signedIn();
    provider.handlePushWhileOpen({
      'type': 'lesson_reminder',
      'viewer_id': '86000000-0000-4000-8000-0000000000ff',
      'lesson_id': _lesson,
    });
    provider.handlePushWhileOpen(
        {'type': 'lesson_reminder', 'viewer_id': _me, 'lesson_id': '../admin'});
    expect(provider.enhancedNotifications, isEmpty);
    provider.dispose();
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
