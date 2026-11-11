import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/data/lessons_repository.dart';
import 'package:streamer_app/features/lessons/domain/lessons_models.dart';
import 'package:streamer_app/features/lessons/domain/lessons_names.dart';
import 'package:streamer_app/features/lessons/presentation/lantern/calendar_view.dart';
import 'package:streamer_app/features/lessons/presentation/lantern/lantern_lessons_parts.dart';
import 'package:streamer_app/features/lessons/presentation/lantern/lesson_view.dart';
import 'package:streamer_app/features/lessons/presentation/lantern/mosque_view.dart';
import 'package:streamer_app/features/lessons/presentation/lantern/preacher_view.dart';
import 'package:streamer_app/features/lessons/presentation/lantern/series_view.dart';
import 'package:streamer_app/features/lessons/presentation/lantern/lessons_home_view.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// The mosque-lessons pages in the Lantern and Arch design (ADR-026).
bool sameDayAs(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const _phone = Size(390, 844), _laptop = Size(1440, 900);

/// Never answers: the programme stays loading.
class _SlowRepo extends DemoLessonsRepository {
  _SlowRepo() : super();
  final _never = Completer<LessonsCatalog>();
  @override
  Future<LessonsCatalog> loadCatalog() => _never.future;
}

/// The server cannot be reached.
class _DownRepo extends DemoLessonsRepository {
  _DownRepo() : super();
  bool down = true;
  @override
  Future<LessonsCatalog> loadCatalog() async {
    if (down) throw const LessonsException(LessonsFailure.unavailable);
    return super.loadCatalog();
  }
}

/// The whole app through its router, in the Lantern design, with [repo].
class _App {
  _App(this.tester, this.provider, this.lessons, this.router);
  final WidgetTester tester;
  final AppProvider provider;
  final LessonsController lessons;
  final GoRouter router;

  Future<void> settle([int frames = 10]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> go(String location) async {
    router.go(location);
    await settle();
  }

  Future<void> push(String location) async {
    router.push(location);
    await settle();
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    lessons.dispose();
    provider.dispose();
    tester.view.reset();
  }
}

Future<_App> _start(WidgetTester tester,
    {required String location,
    String lang = 'en',
    Size size = _phone,
    bool night = false,
    AppSkin skin = AppSkin.lantern,
    LessonsDemoPersona persona = LessonsDemoPersona.guest,
    DemoLessonsRepository? repo}) async {
  LessonsNames.reset();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final provider = lanternProvider(
      skin: skin,
      appearance: night ? LanternAppearance.night : LanternAppearance.day);
  if (persona == LessonsDemoPersona.admin) {
    provider.debugSetSignedInForTests(
        email: 'admin@example.invalid',
        name: 'Admin',
        isMasterAdmin: true,
        isLessonsAdmin: true,
        isStreamer: false);
  } else if (persona == LessonsDemoPersona.viewer) {
    provider.debugSetSignedInForTests(
        email: 'viewer@example.invalid', name: 'Viewer', isStreamer: false);
  }
  final lessons =
      LessonsController(repo ?? DemoLessonsRepository(persona: persona));
  final router = AppRouter.build(provider)..go(location);
  await tester.pumpWidget(EasyLocalization(
      key: UniqueKey(),
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: provider),
            ChangeNotifierProvider<LessonsController>.value(value: lessons),
          ],
          child: Builder(
              builder: (context) => MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                  theme: AppTheme.forLocale(context.locale, skin: skin),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: true),
                      child: child!))))));
  final app = _App(tester, provider, lessons, router);
  await app.settle();
  return app;
}

/// Scrolls [finder] into view and taps it.
Future<void> _tap(_App app, Finder finder) async {
  await app.tester.ensureVisible(finder.first);
  await app.tester.pump();
  await app.tester.tap(finder.first);
  await app.settle();
}

/// Lays [route] out in both languages, both layouts, day and night, and
/// fails on any exception (an overflow is one).
Future<void> _layoutEverywhere(WidgetTester tester, String Function(LessonsController c) route,
    {LessonsDemoPersona persona = LessonsDemoPersona.admin,
    required Type view}) async {
  for (final lang in ['ar', 'en']) {
    for (final size in [_phone, _laptop]) {
      for (final night in [false, true]) {
        final probe = LessonsController(DemoLessonsRepository(persona: persona));
        await probe.ensureLoaded();
        final location = route(probe);
        probe.dispose();
        final app = await _start(tester,
            location: location,
            lang: lang,
            size: size,
            night: night,
            persona: persona);
        final where = '$location $lang $size ${night ? 'night' : 'day'}';
        expect(tester.takeException(), isNull, reason: where);
        expect(find.byType(view), findsOneWidget, reason: where);
        // Scroll to the end: everything below the fold lays out too.
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await tester.drag(scrollables.first, const Offset(0, -6000));
          await app.settle(4);
          expect(tester.takeException(), isNull, reason: '$where (end)');
        }
        await app.close();
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Lessons home', () {
    testWidgets('lays out in both languages, layouts and appearances',
        (tester) async {
      await _layoutEverywhere(tester, (_) => '/lessons',
          view: LanternLessonsHome);
    });

    testWidgets('shows tonight, the sections and the map card',
        (tester) async {
      final app = await _start(tester, location: '/lessons', size: _laptop);
      expect(find.byKey(const ValueKey('lantern-lessons-tonight')),
          findsOneWidget);
      expect(find.byType(LPrayerStrip), findsOneWidget);
      expect(find.text('lessons.discover.upcoming'.tr()), findsOneWidget);
      expect(find.byType(LLessonCard), findsWidgets);
      expect(find.byType(LMapTeaser), findsOneWidget);
      expect(find.byType(LanternWebFooter), findsOneWidget);
      // Guests see no admin band.
      expect(find.byKey(const ValueKey('lantern-lessons-admin')), findsNothing);
      await app.close();
    });

    testWidgets('admins see their band, which opens the review',
        (tester) async {
      final app = await _start(tester,
          location: '/lessons', persona: LessonsDemoPersona.admin);
      expect(find.byKey(const ValueKey('lantern-lessons-admin')),
          findsOneWidget);
      await _tap(app, find.text('lessons.discover.open_review'.tr()));
      expect(app.router.routeInformationProvider.value.uri.path,
          '/admin/lessons/approvals');
      await app.close();
    });

    testWidgets('loading shows skeletons', (tester) async {
      final app =
          await _start(tester, location: '/lessons', repo: _SlowRepo());
      expect(find.byType(LSkeleton), findsWidgets);
      expect(find.byType(LLessonCard), findsNothing);
      expect(tester.takeException(), isNull);
      await app.close();
    });

    testWidgets('a failure offers Try again, which reloads', (tester) async {
      final repo = _DownRepo();
      final app = await _start(tester, location: '/lessons', repo: repo);
      expect(find.byKey(const ValueKey('lantern-lessons-error')),
          findsOneWidget);
      expect(find.text('lessons.unavailable_title'.tr()), findsOneWidget);
      repo.down = false;
      await _tap(app, find.text('lessons.retry'.tr()));
      expect(app.lessons.loaded, isTrue);
      expect(find.byType(LLessonCard), findsWidgets);
      await app.close();
    });

    testWidgets('with nothing published it says so', (tester) async {
      final repo = DemoLessonsRepository()..lessons.clear();
      final app = await _start(tester, location: '/lessons', repo: repo);
      expect(find.byKey(const ValueKey('lantern-lessons-empty')),
          findsOneWidget);
      expect(find.text('lessons.discover.empty'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('the bell asks a guest to sign in', (tester) async {
      final app = await _start(tester, location: '/lessons');
      final l = app.lessons.upcoming.first;
      await _tap(app, find.byKey(ValueKey('lantern-remind-${l.id}')));
      expect(find.text('lessons.sign_in_title'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('the bell sets a reminder through the controller',
        (tester) async {
      final app = await _start(tester,
          location: '/lessons', persona: LessonsDemoPersona.viewer);
      final l = app.lessons.upcoming.first;
      expect(app.lessons.hasReminder(l.id), isFalse);
      await _tap(app, find.byKey(ValueKey('lantern-remind-${l.id}')));
      await _tap(app, find.byKey(const ValueKey('lantern-remind-adhan')));
      expect(app.lessons.hasReminder(l.id), isTrue);
      expect(app.lessons.reminderLead(l.id), 'adhan');
      await app.close();
    });

    testWidgets('the search and the week link open the calendar',
        (tester) async {
      final app = await _start(tester, location: '/lessons');
      await _tap(app, find.byKey(const ValueKey('lantern-lessons-search')));
      expect(app.router.routeInformationProvider.value.uri.path,
          '/lessons/calendar');
      await app.close();
    });

    testWidgets('the older designs build no Lantern widget here',
        (tester) async {
      for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
        final app = await _start(tester,
            location: '/lessons', skin: skin, lang: 'ar');
        tester.takeException();
        expect(tester.allWidgets.whereType<LanternSkinWidget>(), isEmpty,
            reason: skin.id);
        await app.close();
      }
    });
  });

  group('Lessons calendar', () {
    int count(WidgetTester tester) {
      final text = tester
          .widget<Text>(find.byKey(const ValueKey('lantern-calendar-count')))
          .data!;
      return int.parse(RegExp(r'\d+').firstMatch(text)!.group(0)!);
    }

    testWidgets('lays out in both languages, layouts and appearances',
        (tester) async {
      await _layoutEverywhere(tester, (_) => '/lessons/calendar',
          view: LanternLessonsCalendar);
    });

    testWidgets('the strip picks a day, All and 2 weeks', (tester) async {
      final app = await _start(tester, location: '/lessons/calendar');
      final all = count(tester);
      expect(all, app.lessons.upcoming.length);
      final today = app.lessons.today;
      await _tap(app,
          find.byKey(ValueKey('lantern-day-${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}')));
      final todays = app.lessons.upcoming
          .where((l) =>
              l.date.year == today.year &&
              l.date.month == today.month &&
              l.date.day == today.day)
          .length;
      expect(count(tester), todays);
      await _tap(app, find.byKey(const ValueKey('lantern-day-two-weeks')));
      expect(count(tester), lessThanOrEqualTo(all));
      await _tap(app, find.byKey(const ValueKey('lantern-day-all')));
      expect(count(tester), all);
      await app.close();
    });

    testWidgets('the website panel filters live and clears', (tester) async {
      final app =
          await _start(tester, location: '/lessons/calendar', size: _laptop);
      expect(find.byKey(const ValueKey('lantern-calendar-filter-panel')),
          findsOneWidget);
      final all = count(tester);
      await _tap(app, find.byKey(const ValueKey('lantern-filter-live')));
      final streamed = app.lessons.upcoming.where((l) => l.streamed).length;
      expect(count(tester), streamed);
      expect(find.text('lessons.calendar.clear_n'.tr(args: ['1'])),
          findsOneWidget);
      await _tap(app, find.byKey(const ValueKey('lantern-filter-clear')));
      expect(count(tester), all);
      await app.close();
    });

    testWidgets('phones filter in a sheet; Show results applies',
        (tester) async {
      final app = await _start(tester, location: '/lessons/calendar');
      expect(find.byKey(const ValueKey('lantern-calendar-filter-panel')),
          findsNothing);
      await _tap(app, find.byKey(const ValueKey('lantern-calendar-filters')));
      await _tap(app, find.byKey(const ValueKey('lantern-filter-series')));
      await _tap(app, find.byKey(const ValueKey('lantern-calendar-show')));
      final series =
          app.lessons.upcoming.where((l) => l.seriesId != null).length;
      expect(count(tester), series);
      await app.close();
    });

    testWidgets('honours the route filter, and the empty state clears it',
        (tester) async {
      final app = await _start(tester,
          location: '/lessons/calendar?mosque=no-such-mosque', size: _laptop);
      expect(find.byKey(const ValueKey('lantern-calendar-empty')),
          findsOneWidget);
      await _tap(app, find.text('lessons.calendar.clear'.tr()));
      expect(count(tester), app.lessons.upcoming.length);
      await app.close();

      final urdu = await _start(tester, location: '/lessons/calendar?lang=ur');
      final ur = urdu.lessons.upcoming
          .where((l) => l.language == 'ur' || l.interpretation == 'ur')
          .length;
      expect(count(tester), ur);
      await urdu.close();
    });

    testWidgets('the week grid lays lessons out by prayer', (tester) async {
      final app = await _start(tester, location: '/lessons/calendar');
      await _tap(app, find.text('lessons.calendar.week'.tr()));
      expect(find.byKey(const ValueKey('lantern-calendar-grid')),
          findsOneWidget);
      final first = app.lessons.upcoming.first;
      expect(find.byKey(ValueKey('lantern-grid-${first.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await app.close();
    });

    testWidgets('past lessons take Did you attend? through the controller',
        (tester) async {
      final app = await _start(tester,
          location: '/lessons/calendar', persona: LessonsDemoPersona.viewer);
      await _tap(app, find.text('lessons.calendar.past'.tr()));
      final past = app.lessons.pastWhere((_) => true);
      expect(past, isNotEmpty);
      final l = past.first;
      final was = app.lessons.attended(l.id);
      await _tap(app, find.byKey(ValueKey('lantern-attend-${l.id}')));
      expect(app.lessons.attended(l.id), !was);
      await app.close();
    });

    testWidgets('calendar loading and failure states', (tester) async {
      final slow = await _start(tester,
          location: '/lessons/calendar', repo: _SlowRepo());
      expect(find.byKey(const ValueKey('lantern-lessons-loading')),
          findsOneWidget);
      await slow.close();
      final down = await _start(tester,
          location: '/lessons/calendar', repo: _DownRepo());
      expect(find.byKey(const ValueKey('lantern-lessons-error')),
          findsOneWidget);
      await down.close();
    });
  });

  group('Lesson page', () {
    String seriesLesson(LessonsController c) =>
        '/lessons/lesson/${c.upcoming.firstWhere((l) => l.seriesId != null && !sameDayAs(l.date, c.today)).id}';

    testWidgets('lays out in both languages, layouts and appearances',
        (tester) async {
      await _layoutEverywhere(tester, seriesLesson, view: LanternLessonView);
    });

    testWidgets('shows facts, actions, series, preacher, mosque and prayers',
        (tester) async {
      final app = await _start(tester,
          location: '/lessons', size: _laptop, persona: LessonsDemoPersona.viewer);
      await app.push(seriesLesson(app.lessons));
      expect(find.byType(LFactTile), findsNWidgets(3));
      expect(find.byType(LPrayerStrip), findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-lesson-remind')), findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-lesson-share')), findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-lesson-upcoming')), findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-lesson-flag')), findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-lesson-admin')), findsNothing);
      expect(find.byType(LanternWebHeader), findsOneWidget);
      expect(find.byType(LanternWebFooter), findsOneWidget);
      await app.close();
    });

    testWidgets('Remind me, Follow and Report call the controller',
        (tester) async {
      final app = await _start(tester,
          location: '/lessons', persona: LessonsDemoPersona.viewer);
      final route = seriesLesson(app.lessons);
      final l = app.lessons.lesson(route.split('/').last)!;
      await app.push(route);
      expect(find.byType(LanternPageBar), findsOneWidget);
      await _tap(app, find.byKey(const ValueKey('lantern-lesson-remind')));
      await _tap(app, find.byKey(const ValueKey('lantern-remind-30')));
      expect(app.lessons.reminderLead(l.id), '30');
      await _tap(app, find.byKey(ValueKey('lantern-follow-preacher-${l.preacherId}')));
      expect(app.lessons.isFollowing('preacher', l.preacherId), isTrue);
      await _tap(app, find.byKey(const ValueKey('lantern-lesson-share')));
      expect(find.text('lessons.share.copy'.tr()), findsOneWidget);
      await _tap(app, find.byTooltip('Close'));
      expect(find.text('lessons.share.copy'.tr()), findsNothing);
      final repo = app.lessons.repository as DemoLessonsRepository;
      final before = repo.flags.length;
      // Let the toasts go: they float over the end of the page.
      await tester.pump(const Duration(seconds: 6));
      await app.settle();
      await _tap(app, find.byKey(const ValueKey('lantern-lesson-flag')));
      await _tap(app, find.text('lessons.flag.send'.tr()));
      expect(repo.flags.length, before + 1);
      await app.close();
    });

    testWidgets('a cancelled session is struck through and says so',
        (tester) async {
      final app = await _start(tester,
          location: '/lessons', persona: LessonsDemoPersona.admin);
      final route = seriesLesson(app.lessons);
      await tester.runAsync(
          () => app.lessons.cancelLesson(route.split('/').last, 'Travel'));
      await app.push(route);
      expect(find.byKey(const ValueKey('lantern-lesson-cancelled')), findsOneWidget);
      final title =
          tester.widget<Text>(find.byKey(const ValueKey('lantern-lesson-title')));
      expect(title.style?.decoration, TextDecoration.lineThrough);
      expect(find.byKey(const ValueKey('lantern-lesson-admin')), findsOneWidget);
      expect(find.text('lessons.restore.title'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('an unknown lesson is not found', (tester) async {
      final app = await _start(tester, location: '/lessons/lesson/no-such-lesson');
      expect(find.byKey(const ValueKey('lantern-lesson-missing')), findsOneWidget);
      await _tap(app, find.text('lessons.see_all'.tr()));
      expect(app.router.routeInformationProvider.value.uri.path, '/lessons/calendar');
      await app.close();
    });
  });

  group('Preacher page', () {
    String withLessons(LessonsController c) =>
        '/lessons/preachers/${c.listedPreachers.firstWhere((p) => c.upcoming.any((l) => l.preacherId == p.id && l.seriesId != null)).id}';

    testWidgets('lays out in both languages, layouts and appearances',
        (tester) async {
      await _layoutEverywhere(tester, withLessons, view: LanternPreacherView);
    });

    testWidgets('header, counts and tabs', (tester) async {
      final app = await _start(tester, location: '/lessons', size: _laptop);
      await app.push(withLessons(app.lessons));
      expect(find.byKey(const ValueKey('lantern-preacher-avatar')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-preacher-tab-upcoming')),
          findsOneWidget);
      expect(find.byType(LLessonCard), findsWidgets);
      await _tap(app, find.text('lessons.preacher.series'.tr()));
      expect(find.byKey(const ValueKey('lantern-preacher-tab-series')),
          findsOneWidget);
      expect(find.byType(LSeriesCard), findsWidgets);
      await _tap(app, find.text('lessons.preacher.about'.tr()));
      expect(find.text('lessons.preacher.languages'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('his mosques open their pages', (tester) async {
      final app = await _start(tester, location: '/lessons');
      final route = withLessons(app.lessons);
      final id = route.split('/').last;
      final mosque =
          app.lessons.upcoming.firstWhere((l) => l.preacherId == id).mosqueId;
      await app.push(route);
      expect(find.byKey(const ValueKey('lantern-preacher-mosques')),
          findsOneWidget);
      await _tap(app, find.byKey(ValueKey('lantern-preacher-mosque-$mosque')));
      expect(app.router.routeInformationProvider.value.uri.path,
          '/lessons/mosques/$mosque');
      expect(find.byType(LanternMosqueView), findsOneWidget);
      await app.close();
    });

    testWidgets('Follow and Copy link', (tester) async {
      final app = await _start(tester,
          location: '/lessons', persona: LessonsDemoPersona.viewer);
      final route = withLessons(app.lessons);
      final id = route.split('/').last;
      await app.push(route);
      final was = app.lessons.isFollowing('preacher', id);
      await _tap(app, find.byKey(ValueKey('lantern-follow-preacher-$id')));
      expect(app.lessons.isFollowing('preacher', id), !was);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async => null);
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await _tap(app, find.byKey(const ValueKey('lantern-preacher-copy')));
      expect(find.text('lessons.copied'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('a guest who follows is asked to sign in', (tester) async {
      final app = await _start(tester, location: '/lessons');
      final route = withLessons(app.lessons);
      await app.push(route);
      await _tap(
          app,
          find.byKey(
              ValueKey('lantern-follow-preacher-${route.split('/').last}')));
      expect(find.text('lessons.sign_in_title'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('no upcoming lessons, and not found', (tester) async {
      final app = await _start(tester, location: '/lessons');
      final idle = app.lessons.listedPreachers
          .where((p) => !app.lessons.upcoming.any((l) => l.preacherId == p.id))
          .toList();
      if (idle.isNotEmpty) {
        await app.push('/lessons/preachers/${idle.first.id}');
        expect(find.byKey(const ValueKey('lantern-preacher-no-upcoming')),
            findsOneWidget);
      }
      await app.go('/lessons/preachers/no-such-preacher');
      expect(find.byKey(const ValueKey('lantern-preacher-missing')),
          findsOneWidget);
      await app.close();
    });
  });

  group('Mosque page', () {
    String busy(LessonsController c) =>
        '/lessons/mosques/${c.upcoming.firstWhere((l) => c.mosque(l.mosqueId)!.verified).mosqueId}';

    testWidgets('lays out in both languages, layouts and appearances',
        (tester) async {
      await _layoutEverywhere(tester, busy, view: LanternMosqueView);
    });

    testWidgets('the week timetable opens a lesson', (tester) async {
      final app = await _start(tester, location: '/lessons', size: _laptop);
      final route = busy(app.lessons);
      final id = route.split('/').last;
      await app.push(route);
      expect(find.byKey(const ValueKey('lantern-mosque-week')), findsOneWidget);
      expect(find.byType(LPrayerStrip), findsOneWidget);
      final week = app.lessons.upcoming
          .where((l) =>
              l.mosqueId == id &&
              l.date.difference(app.lessons.today).inDays < 7)
          .toList();
      if (week.isNotEmpty) {
        await _tap(
            app, find.byKey(ValueKey('lantern-mosque-row-${week.first.id}')));
        expect(app.router.routeInformationProvider.value.uri.path,
            '/lessons/lesson/${week.first.id}');
      }
      await app.close();
    });

    testWidgets('Follow calls the controller', (tester) async {
      final app = await _start(tester,
          location: '/lessons', persona: LessonsDemoPersona.viewer);
      final route = busy(app.lessons);
      final id = route.split('/').last;
      await app.push(route);
      final was = app.lessons.isFollowing('mosque', id);
      await _tap(app, find.byKey(ValueKey('lantern-follow-mosque-$id')));
      expect(app.lessons.isFollowing('mosque', id), !was);
      await app.close();
    });

    testWidgets('an unverified mosque says so; an unknown one is not found',
        (tester) async {
      // The sample's suggested mosque, which only admins see.
      final app = await _start(tester,
          location: '/lessons/mosques/m13', persona: LessonsDemoPersona.admin);
      expect(find.byKey(const ValueKey('lantern-mosque-unverified')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-mosque-on-map')), findsNothing);
      await app.go('/lessons/mosques/no-such-mosque');
      expect(
          find.byKey(const ValueKey('lantern-mosque-missing')), findsOneWidget);
      await app.close();
    });
  });

  group('Series page', () {
    String withSessions(LessonsController c) =>
        '/lessons/series/${c.upcoming.firstWhere((l) => l.seriesId != null).seriesId}';

    testWidgets('lays out in both languages, layouts and appearances',
        (tester) async {
      await _layoutEverywhere(tester, withSessions, view: LanternSeriesView);
    });

    testWidgets('shows its progress and every session; Next opens a lesson',
        (tester) async {
      final app = await _start(tester, location: '/lessons', size: _laptop);
      final route = withSessions(app.lessons);
      final id = route.split('/').last;
      final sessions = app.lessons.sessionsOf(id);
      await app.push(route);
      expect(find.byKey(const ValueKey('lantern-series-head')), findsOneWidget);
      expect(find.byType(LFillBar), findsOneWidget);
      expect(find.byType(LLessonRow), findsNWidgets(sessions.length));
      final next = sessions
          .where((x) => !x.date.isBefore(app.lessons.today) && x.isPublic)
          .first;
      await _tap(app, find.byKey(const ValueKey('lantern-series-next')));
      expect(app.router.routeInformationProvider.value.uri.path,
          '/lessons/lesson/${next.id}');
      await app.close();
    });

    testWidgets('Follow calls the controller; a guest is asked to sign in',
        (tester) async {
      final app = await _start(tester,
          location: '/lessons', persona: LessonsDemoPersona.viewer);
      final route = withSessions(app.lessons);
      final id = route.split('/').last;
      await app.push(route);
      final was = app.lessons.isFollowing('series', id);
      await _tap(app, find.byKey(ValueKey('lantern-follow-series-$id')));
      expect(app.lessons.isFollowing('series', id), !was);
      await app.close();

      final guest = await _start(tester, location: '/lessons');
      await guest.push(route);
      await _tap(guest, find.byKey(ValueKey('lantern-follow-series-$id')));
      expect(find.text('lessons.sign_in_title'.tr()), findsOneWidget);
      await guest.close();
    });

    testWidgets('an unknown series is not found', (tester) async {
      final app =
          await _start(tester, location: '/lessons/series/no-such-series');
      expect(find.byKey(const ValueKey('lantern-series-missing')),
          findsOneWidget);
      await _tap(app, find.text('lessons.see_all'.tr()));
      expect(app.router.routeInformationProvider.value.uri.path,
          '/lessons/calendar');
      await app.close();
    });

    testWidgets('waits for the programme, and offers Try again',
        (tester) async {
      final slow =
          await _start(tester, location: '/lessons/series/s1', repo: _SlowRepo());
      expect(find.byType(LSkeleton), findsWidgets);
      expect(find.byKey(const ValueKey('lantern-series-missing')), findsNothing);
      expect(tester.takeException(), isNull);
      await slow.close();
      final repo = _DownRepo();
      final down =
          await _start(tester, location: '/lessons/series/s1', repo: repo);
      expect(find.byKey(const ValueKey('lantern-lessons-error')),
          findsOneWidget);
      repo.down = false;
      await _tap(down, find.text('lessons.retry'.tr()));
      expect(down.lessons.loaded, isTrue);
      expect(find.byKey(const ValueKey('lantern-lessons-error')), findsNothing);
      await down.close();
    });
  });

  testWidgets(
      'older designs build no Lantern widget on the preacher, mosque and series pages',
      (tester) async {
    for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
      for (final size in [_phone, _laptop]) {
        final app = await _start(tester,
            location: '/lessons', skin: skin, size: size, lang: 'ar');
        final l = app.lessons.upcoming.first;
        final s = app.lessons.upcoming.firstWhere((x) => x.seriesId != null);
        for (final route in [
          '/lessons/preachers/${l.preacherId}',
          '/lessons/mosques/${l.mosqueId}',
          '/lessons/series/${s.seriesId}',
          '/lessons/preachers/no-such-preacher',
          '/lessons/mosques/no-such-mosque',
          '/lessons/series/no-such-series',
        ]) {
          await app.go(route);
          tester.takeException();
          expect(tester.allWidgets.whereType<LanternSkinWidget>(), isEmpty,
              reason: '${skin.id} $route');
        }
        await app.close();
      }
    }
  });
}
