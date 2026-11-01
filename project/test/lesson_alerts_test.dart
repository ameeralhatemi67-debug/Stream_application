import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/reminder_push_service.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/domain/lessons_dates.dart';
import 'package:streamer_app/features/lessons/domain/lessons_models.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_widgets.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'package:streamer_app/features/profile/presentation/settings/notification_settings_section.dart';

import 'support/fixture_application_db.dart';
import 'support/localized_app.dart';
import 'support/scripted_broadcasts.dart';

const _me = '88000000-0000-4000-8000-000000000001';

/// Records the requests for notification permission.
class _RecordingProvider extends AppProvider {
  _RecordingProvider({required super.adminDbService, required super.organizationBroadcastService})
      : super.withServices();
  final asked = <bool>[];
  ReminderPushStatus status = ReminderPushStatus.granted;
  @override
  ReminderPushStatus get reminderPushStatus => status;
  @override
  Future<void> syncReminderPush({required bool requestPermission, required String language}) async {
    asked.add(requestPermission);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sample programme, as the server does it', () {
    late DemoLessonsRepository repo;

    /// The viewer follows only [follows]; no reminders.
    Future<void> viewerFollowsOnly(Set<String> follows) async {
      repo.persona = LessonsDemoPersona.viewer;
      final mine = await repo.loadMine();
      for (final f in mine.follows) {
        final at = f.indexOf(':');
        await repo.setFollow(f.substring(0, at), f.substring(at + 1), false);
      }
      for (final id in mine.reminders.keys) {
        await repo.removeReminder(id);
      }
      for (final f in follows) {
        final at = f.indexOf(':');
        await repo.setFollow(f.substring(0, at), f.substring(at + 1), true);
      }
      repo.persona = LessonsDemoPersona.admin;
    }

    Future<List<String>> viewerInbox() async {
      repo.persona = LessonsDemoPersona.viewer;
      final mine = await repo.loadMine();
      repo.persona = LessonsDemoPersona.admin;
      return [for (final n in mine.notifications) n.titleEn];
    }

    setUp(() => repo = DemoLessonsRepository(persona: LessonsDemoPersona.admin));

    Future<Lesson> upcomingLesson(bool Function(Lesson) test) async {
      final catalog = await repo.loadCatalog();
      return catalog.lessons.values
          .firstWhere((l) => l.status == 'approved' && !l.date.isBefore(lessonsToday()) && test(l));
    }

    test('a preacher\'s follower hears a cancellation without having set a reminder', () async {
      final l = await upcomingLesson((_) => true);
      await viewerFollowsOnly({'preacher:${l.preacherId}'});
      expect(await repo.cancelLesson(l.id, 'Travel'), 1);
      expect(await viewerInbox(), contains('Cancelled: ${l.title('en')}'));
    });

    test('so does a mosque\'s and a series\' follower', () async {
      final l = await upcomingLesson((l) => l.seriesId != null);
      await viewerFollowsOnly({'mosque:${l.mosqueId}'});
      await repo.cancelLesson(l.id, 'Travel');
      expect(await viewerInbox(), contains('Cancelled: ${l.title('en')}'));

      final next = await upcomingLesson((o) => o.seriesId == l.seriesId);
      await viewerFollowsOnly({'series:${l.seriesId}'});
      await repo.cancelLesson(next.id, 'Travel');
      expect(await viewerInbox(), contains('Cancelled: ${next.title('en')}'));
    });

    test('a stranger to the lesson hears nothing', () async {
      final l = await upcomingLesson((_) => true);
      await viewerFollowsOnly(const {});
      expect(await repo.cancelLesson(l.id, 'Travel'), 0);
      expect(await viewerInbox(), isNot(contains('Cancelled: ${l.title('en')}')));
    });

    test('a follower hears a new time, with the new date', () async {
      final l = await upcomingLesson((_) => true);
      await viewerFollowsOnly({'preacher:${l.preacherId}'});
      final moved = addDays(l.date, 2);
      await repo.editLesson(l.id, {'lesson_date': isoDate(moved)});
      repo.persona = LessonsDemoPersona.viewer;
      final notice = (await repo.loadMine()).notifications.first;
      expect(notice.titleEn, 'A lesson time or place changed');
      expect(notice.bodyEn, endsWith(isoDate(moved)));
    });

    test('a new title alone tells nobody', () async {
      final l = await upcomingLesson((_) => true);
      await viewerFollowsOnly({'preacher:${l.preacherId}'});
      await repo.editLesson(l.id, {'title_en': 'Another title'});
      expect(await viewerInbox(), isNot(contains('A lesson time or place changed')));
    });

    test('a new lesson says whether the follow was the preacher or the mosque', () async {
      final catalog = await repo.loadCatalog();
      final preacher = catalog.preachers.keys.first;
      final mosque = catalog.mosques.keys.first;
      LessonDraft draft() => LessonDraft(
          preacherId: preacher,
          type: 'lesson',
          topic: 'fiqh',
          titleAr: 'درس',
          slot: 'isha',
          dates: [addDays(lessonsToday(), 3)],
          mosqueId: mosque);

      await viewerFollowsOnly({'mosque:$mosque'});
      await repo.addLessons(draft());
      expect(await viewerInbox(), contains('New lesson at a mosque you follow'));

      await viewerFollowsOnly({'preacher:$preacher', 'mosque:$mosque'});
      final before = (await viewerInbox()).where((t) => t.startsWith('New lesson')).length;
      await repo.addLessons(draft());
      final after = (await viewerInbox()).where((t) => t.startsWith('New lesson')).toList();
      expect(after.length, before + 1, reason: 'one alert when both are followed');
      expect(after.first, 'New lesson from a preacher you follow');
    });
  });

  group('asking for notifications', () {
    setUpAll(initializeTestLocalization);

    _RecordingProvider provider() {
      final p = _RecordingProvider(
          adminDbService: FixtureApplicationDb(), organizationBroadcastService: ScriptedBroadcasts());
      p.debugSetSignedInForTests(email: 'viewer@example.invalid', isStreamer: false, userId: _me);
      p.debugRemindersAvailable = true;
      return p;
    }

    testWidgets('following a preacher asks, so the alerts can reach the phone', (tester) async {
      final app = provider();
      final repo = DemoLessonsRepository(persona: LessonsDemoPersona.viewer);
      final lessons = LessonsController(repo);
      await lessons.refresh();
      await tester.pumpWidget(localizedApp(
          home: MultiProvider(providers: [
        ChangeNotifierProvider<AppProvider>.value(value: app),
        ChangeNotifierProvider<LessonsController>.value(value: lessons),
      ], child: const Scaffold(body: Center(child: FollowButton(kind: 'preacher', id: 'p2'))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FollowButton));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(app.asked, [true]);

      // Unfollowing has nothing to ask for.
      await tester.tap(find.byType(FollowButton));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(app.asked, [true]);
      await tester.pumpWidget(const SizedBox());
      lessons.dispose();
      app.dispose();
    });

    testWidgets('Settings has a lesson alerts switch', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = provider();
      await tester.pumpWidget(localizedApp(
          home: ChangeNotifierProvider<AppProvider>.value(
              value: app, child: const Scaffold(body: SingleChildScrollView(child: NotificationSettingsSection())))));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(NotificationSettingsSection));
      expect(find.text('design_copy.lesson_alerts'.tr()), findsOneWidget);
      expect('design_copy.lesson_alerts'.tr(context: context), 'Lesson reminders, changes and cancellations');
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a phone that said no gets a way to turn notifications on', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = provider()..status = ReminderPushStatus.notGranted;
      await tester.pumpWidget(localizedApp(
          home: ChangeNotifierProvider<AppProvider>.value(
              value: app, child: const Scaffold(body: SingleChildScrollView(child: NotificationSettingsSection())))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('turn-on-notifications')));
      await tester.pump();
      expect(app.asked, [true]);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  });
}
