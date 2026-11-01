import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/domain/lessons_dates.dart';
import 'package:streamer_app/features/lessons/domain/lessons_models.dart';
import 'package:streamer_app/features/lessons/domain/lessons_rules.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_in_app.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_map.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_widgets.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'package:streamer_app/features/map/models/map_models.dart';
import 'package:streamer_app/features/map/presentation/map_cluster_layout.dart';
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/map/presentation/widgets/map_cluster_badge.dart';
import 'package:streamer_app/features/map/presentation/widgets/map_discovery_channel_card_marker.dart';
import 'package:streamer_app/features/map/presentation/widgets/spatial_streamer_marker.dart';
import 'package:streamer_app/features/map/presentation/widgets/topic_selector_dropdown.dart';
import 'package:streamer_app/features/map/services/map_pack_controller.dart';
import 'package:streamer_app/features/profile/models/upcoming_schedule.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';

class _NoPackBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw StateError('no map pack in tests');
}

/// The map's lesson states: what is on now, what comes next, what truly is
/// live, and how pins group (2026-11-01).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const mosque = Mosque(id: 'm', nameAr: 'مسجد', nameEn: 'Mosque', districtId: 'd', latitude: 26.3, longitude: 50.2);
  const preacher = Preacher(id: 'p', nameAr: 'داعية', nameEn: 'Preacher', linkedProfileId: 'channel');
  final date = DateTime(2026, 11, 1, 12);
  const catalog = LessonsCatalog(
    mosques: {'m': mosque},
    preachers: {'p': preacher},
    districts: {'d': District(id: 'd', city: 'khobar', nameAr: 'حي', nameEn: 'Area')},
  );

  /// A lesson at a fixed clock time, so the tests don't depend on prayer times.
  Lesson lesson(String id, String time,
          {String type = 'lesson', int? minutes, bool streamed = false, DateTime? on, String status = 'approved'}) =>
      Lesson(
          id: id,
          requestId: 'r-$id',
          type: type,
          topic: 'fiqh',
          titleAr: 'درس $id',
          titleEn: 'Lesson $id',
          preacherId: 'p',
          mosqueId: 'm',
          date: on ?? date,
          slot: 'isha',
          exactTime: time,
          durationMinutes: minutes,
          streamed: streamed,
          status: status);

  /// Saudi clock time on 1 November 2026, as an instant.
  DateTime at(int hour, int minute, {int day = 1}) =>
      DateTime.utc(2026, 11, day, hour, minute).subtract(const Duration(hours: 3));

  group('how long a lesson runs', () {
    test('a set length wins, otherwise the default for its type', () {
      expect(lessonMinutes(lesson('a', '20:00')), 60);
      expect(lessonMinutes(lesson('a', '20:00', type: 'lecture')), 75);
      expect(lessonMinutes(lesson('a', '20:00', type: 'talk')), 15);
      expect(lessonMinutes(lesson('a', '20:00', type: 'talk', minutes: 40)), 40);
    });

    test('a short talk ends when it should, not after 1 h 15 m', () {
      final talk = lesson('a', '20:00', type: 'talk');
      expect(lessonTiming(talk, catalog, at(20, 10)).phase, LessonPhase.running);
      expect(lessonTiming(talk, catalog, at(20, 16)).phase, LessonPhase.ended);
    });

    test('timing counts to the start, to the end and since the end', () {
      final l = lesson('a', '20:00');
      expect(lessonTiming(l, catalog, at(19, 18)), (phase: LessonPhase.upcoming, minutes: 42, progress: 0.0));
      final running = lessonTiming(l, catalog, at(20, 15));
      expect((running.phase, running.minutes), (LessonPhase.running, 45));
      expect(running.progress, closeTo(.25, .001));
      expect(lessonTiming(l, catalog, at(21, 10)).minutes, 10);
    });

    test('the length reaches the server, and only when one was chosen', () {
      LessonDraft draft(int? minutes) => LessonDraft(
          preacherId: 'p', type: 'lesson', topic: 'fiqh', titleAr: 'درس', slot: 'isha',
          dates: [date], mosqueId: 'm', durationMinutes: minutes);
      expect(draft(45).toJson()['duration_minutes'], 45);
      expect(draft(null).toJson().containsKey('duration_minutes'), isFalse);
      expect(Lesson.fromJson({'lesson_date': '2026-11-01', 'duration_minutes': 30}).durationMinutes, 30);
    });
  });

  group('what a mosque shows', () {
    MosqueNow state(List<Lesson> lessons, DateTime now) => mosqueNow(lessons, catalog, now);

    test('now, with the minutes left', () {
      final s = state([lesson('a', '20:00')], at(20, 30));
      expect((s.status, s.minutes, s.count, s.lesson?.id), (MosqueStatus.now, 30, 1, 'a'));
    });

    test('soon within the hour, today later on, week after that', () {
      final l = lesson('a', '20:00');
      expect(state([l], at(19, 20)).status, MosqueStatus.soon);
      expect(state([l], at(19, 20)).minutes, 40);
      expect(state([l], at(15, 0)).status, MosqueStatus.today);
      final later = lesson('b', '20:00', on: addDays(date, 3));
      expect(state([later], at(10, 0)).status, MosqueStatus.week);
    });

    test('quiet when nothing is left in the next seven days', () {
      expect(state([], at(10, 0)).status, MosqueStatus.quiet);
      expect(state([lesson('a', '20:00')], at(22, 0)).status, MosqueStatus.quiet);
      expect(state([lesson('b', '20:00', on: addDays(date, 8))], at(10, 0)).status, MosqueStatus.quiet);
      expect(state([lesson('a', '20:00', status: 'cancelled')], at(20, 10)).status, MosqueStatus.quiet);
    });

    test('the count covers what is on and what is coming', () {
      final s = state([lesson('a', '20:00'), lesson('b', '21:30'), lesson('c', '20:00', on: addDays(date, 2))], at(20, 30));
      expect((s.status, s.count), (MosqueStatus.now, 3));
    });
  });

  test('time left reads in English and Arabic', () {
    expect(durationLabel(42, 'en'), '42m');
    expect(durationLabel(135, 'en'), '2h 15m');
    expect(durationLabel(120, 'en'), '2h');
    expect(durationLabel(1500, 'en'), '1d 1h');
    expect(durationLabel(2880, 'en'), '2d');
    expect(durationLabel(135, 'ar'), '2 س 15 د');
    expect(durationLabel(-5, 'en'), '0m');
  });

  group('live means really live', () {
    LessonsController controller(Lesson l) {
      final c = LessonsController(DemoLessonsRepository());
      c.catalog = catalog.copyWith(lessons: {l.id: l});
      return c;
    }

    final streamed = lesson('a', '20:00', streamed: true);

    test('a streamed lesson in its time, with nobody broadcasting, is not live', () {
      final c = controller(streamed);
      expect(c.isLiveNow(streamed, now: at(20, 10)), isFalse);
      c.dispose();
    });

    test('it is live once the preacher\'s linked channel is', () async {
      final c = controller(streamed);
      c.setLiveChannels({'channel'});
      expect(c.isLiveNow(streamed, now: at(20, 10)), isTrue);
      expect(c.isLiveNow(streamed, now: at(19, 50)), isFalse, reason: 'before it starts');
      expect(c.isLiveNow(streamed, now: at(21, 10)), isFalse, reason: 'after it ends');
      await Future<void>.delayed(Duration.zero);
      c.dispose();
    });

    test('someone else being live changes nothing, nor does a lesson not streamed', () async {
      final plain = lesson('b', '20:00');
      final c = controller(plain);
      c.setLiveChannels({'someone-else'});
      expect(c.isLiveNow(streamed, now: at(20, 10)), isFalse);
      c.setLiveChannels({'channel'});
      expect(c.isLiveNow(plain, now: at(20, 10)), isFalse);
      await Future<void>.delayed(Duration.zero);
      c.dispose();
    });
  });

  group('grouping pins', () {
    Offset project(LatLng p) => Offset(p.longitude, p.latitude);
    MapClusterPoint point(String id, double x, double y, {int priority = 0}) =>
        MapClusterPoint(id, LatLng(y, x), priority: priority);

    test('mosques and streamers share one bubble', () {
      final groups = clusterMapPoints([point('m:a', 10, 10), point('s:b', 30, 10)], project: project);
      expect(groups.single.memberIds, ['m:a', 's:b']);
    });

    test('two pins beside a line of the old grid still group', () {
      // 71.9 and 72.1 fell in different cells of the 72 px grid.
      final groups = clusterMapPoints([point('a', 71.9, 10), point('b', 72.1, 10)], project: project);
      expect(groups, hasLength(1));
    });

    test('no two markers end up closer than the radius', () {
      final pins = [
        for (var i = 0; i < 300; i++) point('p$i', (i * 37 % 900).toDouble(), (i * 53 % 700).toDouble(), priority: i % 4)
      ];
      final groups = clusterMapPoints(pins, project: project);
      for (final a in groups) {
        for (final b in groups) {
          if (a == b) continue;
          final d = (project(a.center) - project(b.center)).distance;
          expect(d, greaterThanOrEqualTo(kMapClusterRadius - .001));
        }
      }
      expect(groups.expand((g) => g.memberIds).toSet(), hasLength(300), reason: 'nothing is lost');
    });

    test('what is happening now anchors its bubble where it really is', () {
      final groups = clusterMapPoints(
          [point('m:quiet', 10, 10), point('s:live', 40, 10, priority: 6), point('s:off', 60, 10, priority: 1)],
          project: project);
      expect(groups.single.center, const LatLng(10, 40));
    });

    test('the same pins group the same way in any order', () {
      final pins = [for (var i = 0; i < 40; i++) point('p$i', i * 20.0, 10)];
      expect(clusterMapPoints(pins.reversed, project: project).map((g) => g.id),
          clusterMapPoints(pins, project: project).map((g) => g.id));
    });
  });

  test('each channel\'s next live is its soonest', () {
    UpcomingSchedule once(String id, String channel, DateTime start) => UpcomingSchedule(
        id: id, streamerId: channel, kind: 'once', localTime: '00:00', weekdays: const [], oneTimeStartUtc: start,
        titleEn: id, titleAr: id, descriptionEn: '', descriptionAr: '', tags: const [], colorKey: 'green');
    final now = at(10, 0);
    final next = nextLiveByChannel([
      once('later', 'a', at(20, 0)),
      once('sooner', 'a', at(12, 0)),
      once('past', 'b', at(9, 0)),
    ], now);
    expect(next['a']!.schedule.id, 'sooner');
    expect(next.containsKey('b'), isFalse);
  });

  group('the mosques on the map', () {
    LessonsController loaded(DemoLessonsRepository repo) => LessonsController(repo);

    test('every approved mosque is on it, including ones with nothing coming', () async {
      final repo = DemoLessonsRepository(today: lessonsToday());
      final c = loaded(repo);
      await c.ensureLoaded();
      final pins = mapMosques(c, 'en');
      expect(pins.map((m) => m.id), contains('m6'), reason: 'Al-Salam has no lessons in the sample data');
      expect(pins.firstWhere((m) => m.id == 'm6').status, MosqueStatus.quiet);
      expect(pins.map((m) => m.id), isNot(contains('m13')), reason: 'not approved yet');
      c.dispose();
    });

    test('offline, nothing claims to be happening now', () async {
      final repo = DemoLessonsRepository();
      final c = loaded(repo);
      await c.ensureLoaded();
      final pins = mapMosques(c, 'en', online: false);
      expect(pins.where((m) => m.status == MosqueStatus.now || m.status == MosqueStatus.soon), isEmpty);
      expect(pins.every((m) => !m.live && m.chip.isEmpty), isTrue);
      expect(pins.any((m) => m.count > 0), isTrue, reason: 'the lessons we hold still count');
      c.dispose();
    });

    test('a topic keeps only the mosques with a coming lesson on it', () async {
      final c = loaded(DemoLessonsRepository());
      await c.ensureLoaded();
      final seerah = mapMosques(c, 'en', topic: 'seerah');
      expect(seerah, isNotEmpty);
      final allowed = {for (final l in c.upcoming) if (l.topic == 'seerah') l.mosqueId};
      expect(seerah.every((m) => allowed.contains(m.id)), isTrue);
      c.dispose();
    });

    test('search finds mosques, areas, lessons and preachers', () async {
      final c = loaded(DemoLessonsRepository());
      await c.ensureLoaded();
      expect(searchMapLessons(c, 'furqan', 'en').first.mosqueId, 'm2');
      expect(searchMapLessons(c, 'thuqbah', 'en').first.mosqueId, 'm2');
      final byPreacher = searchMapLessons(c, 'Fahd', 'en');
      expect(byPreacher, isNotEmpty);
      expect(searchMapLessons(c, '', 'en'), isEmpty);
      expect(searchMapLessons(c, 'nothing-like-this', 'en'), isEmpty);
      c.dispose();
    });

    test('today\'s list puts what is on first, then the soonest', () {
      MapMosque m(String id, MosqueStatus status, int minutes) => (
            id: id, point: const LatLng(26.3, 50.2), label: id, count: 1, live: false,
            status: status, minutes: minutes, chip: '');
      final list = activeMapMosques([
        m('week', MosqueStatus.week, 3000),
        m('today', MosqueStatus.today, 200),
        m('soon', MosqueStatus.soon, 20),
        m('now', MosqueStatus.now, 50),
        m('quiet', MosqueStatus.quiet, 0),
      ]);
      expect(list.map((x) => x.id), ['now', 'soon', 'today']);
    });
  });

  Widget harness(Widget child, {Size size = const Size(400, 500), LessonsController? lessons}) => EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: Builder(
            builder: (context) => MaterialApp(
                  theme: AppTheme.forLocale(context.locale),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: Scaffold(
                      body: lessons == null
                          ? Center(child: child)
                          : ChangeNotifierProvider<LessonsController>.value(value: lessons, child: child)),
                )),
      );

  group('markers', () {
    Widget arch(MosquePin pin) => SizedBox(width: 52, height: 52, child: MosqueArch(pin: pin));
    const base = MosquePin(id: 'm', lat: 26.3, lng: 50.2, label: 'Al-Huda', count: 3);

    testWidgets('an arch shows its count and its line', (tester) async {
      LessonsMap.debugPlaceholder = true;
      addTearDown(() => LessonsMap.debugPlaceholder = false);
      await tester.pumpWidget(harness(arch(const MosquePin(
          id: 'm', lat: 26.3, lng: 50.2, label: 'Al-Huda', count: 3, onSite: true,
          chip: 'Now · 23m', chipTone: MosqueChipTone.onSite))));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Now · 23m'), findsOneWidget);
      expect(find.text('lessons.lesson.live'.tr()), findsNothing, reason: 'green never says LIVE');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('red and LIVE only when it is live', (tester) async {
      LessonsMap.debugPlaceholder = true;
      addTearDown(() => LessonsMap.debugPlaceholder = false);
      await tester.pumpWidget(harness(arch(const MosquePin(
          id: 'm', lat: 26.3, lng: 50.2, label: 'Al-Huda', count: 2, live: true))));
      await tester.pumpAndSettle();
      expect(find.text('lessons.lesson.live'.tr()), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a quiet mosque is hollow, with no number', (tester) async {
      await tester.pumpWidget(harness(arch(const MosquePin(
          id: 'm', lat: 26.3, lng: 50.2, label: 'Al-Salam', quiet: true))));
      await tester.pumpAndSettle();
      expect(find.byType(Text), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a mosque with a lesson on pulses, and stops when told to', (tester) async {
      await tester.pumpWidget(harness(arch(const MosquePin(
          id: 'm', lat: 26.3, lng: 50.2, label: 'Al-Huda', count: 1, onSite: true))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(harness(arch(base)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a bubble counts its pins and what is on inside', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(harness(SizedBox(
          width: 80,
          height: 80,
          child: MapClusterBadge(
              count: 7, mosques: 4, live: 1, onSite: 2, semanticLabel: '7 venues', onTap: () => tapped++))));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byType(MapClusterBadge));
      expect(tapped, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the pill says what is on now', (tester) async {
      await tester.pumpWidget(harness(const MapNowPill(onSite: 2, live: 1)));
      await tester.pumpAndSettle();
      expect(find.text('lessons.map.now_mosques'.tr(args: ['2'])), findsOneWidget);
      expect(find.text('lessons.map.now_live'.tr(args: ['1'])), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a streamer can say how soon it goes live', (tester) async {
      const marker = MapMarkerModel(
          markerId: 'pin', streamerId: 's', displayNameEn: 'S', displayNameAr: 'S', venueNameEn: 'V', venueNameAr: 'V',
          latitude: 26.3, longitude: 50.2, cityId: 'khobar', categoryId: 'all', status: MarkerStatus.offline,
          viewerCount: 0, avatarUrl: '');
      await tester.pumpWidget(harness(SpatialStreamerMarker(marker: marker, chip: 'in 35m', onTap: () {}, onDoubleTap: () {})));
      await tester.pumpAndSettle();
      expect(find.text('in 35m'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the lesson status card', () {
    Future<LessonsController> open(WidgetTester tester, Lesson l, {Set<String> live = const {}, bool runningOnly = false}) async {
      final c = LessonsController(DemoLessonsRepository());
      c.catalog = catalog.copyWith(lessons: {l.id: l});
      c.setLiveChannels(live);
      await tester.pumpWidget(harness(LessonStatusCard(l, runningOnly: runningOnly), lessons: c));
      await tester.pump();
      return c;
    }

    /// A lesson running now, whatever time the test runs.
    Lesson running({bool streamed = false}) {
      final saudi = DateTime.now().toUtc().add(const Duration(hours: 3)).subtract(const Duration(minutes: 10));
      String two(int n) => n.toString().padLeft(2, '0');
      return lesson('a', '${two(saudi.hour)}:${two(saudi.minute)}',
          streamed: streamed, on: DateTime(saudi.year, saudi.month, saudi.day, 12));
    }

    Lesson later() {
      final saudi = DateTime.now().toUtc().add(const Duration(hours: 3));
      return lesson('a', '10:00', on: DateTime(saudi.year, saudi.month, saudi.day + 3, 12));
    }

    Future<void> finish(WidgetTester tester, LessonsController c) async {
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }

    testWidgets('on at the mosque, and says it comes from the schedule', (tester) async {
      final c = await open(tester, running());
      expect(find.byKey(const ValueKey('lesson-status-on-site')), findsOneWidget);
      expect(find.textContaining('lessons.map.not_streamed'.tr()), findsOneWidget);
      expect(find.textContaining('lessons.map.from_schedule'.tr()), findsOneWidget);
      await finish(tester, c);
    });

    testWidgets('streamed and truly live', (tester) async {
      final c = await open(tester, running(streamed: true), live: {'channel'});
      expect(find.byKey(const ValueKey('lesson-status-live')), findsOneWidget);
      await finish(tester, c);
    });

    testWidgets('marked streamed but nobody is live stays green', (tester) async {
      final c = await open(tester, running(streamed: true));
      expect(find.byKey(const ValueKey('lesson-status-on-site')), findsOneWidget);
      await finish(tester, c);
    });

    testWidgets('a countdown before it starts', (tester) async {
      final c = await open(tester, later());
      expect(find.byKey(const ValueKey('lesson-status-upcoming')), findsOneWidget);
      expect(find.text('lessons.map.starts_in'.tr()), findsOneWidget);
      await finish(tester, c);
    });

    testWidgets('the lesson page shows it only while it runs', (tester) async {
      final c = await open(tester, later(), runningOnly: true);
      expect(find.byKey(const ValueKey('lesson-status-upcoming')), findsNothing);
      await finish(tester, c);
    });
  });

  group('the map with both on it', () {
    /// Sample lessons, one of them on right now at Al-Huda, beside a streamer
    /// a few streets away.
    Future<({AppProvider app, LessonsController lessons, MapPackController pack})> mapped(
        WidgetTester tester, {bool streamed = false, String lang = 'en', double height = 800}) async {
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DemoLessonsRepository();
      final saudi = DateTime.now().toUtc().add(const Duration(hours: 3)).subtract(const Duration(minutes: 10));
      String two(int n) => n.toString().padLeft(2, '0');
      repo.lessons['now'] = Lesson(
          id: 'now', requestId: 'r-now', type: 'lesson', topic: 'fiqh', titleAr: 'درس الآن', titleEn: 'A lesson on now',
          preacherId: 'p1', mosqueId: 'm1', date: DateTime(saudi.year, saudi.month, saudi.day, 12), slot: 'isha',
          exactTime: '${two(saudi.hour)}:${two(saudi.minute)}', streamed: streamed);
      repo.preachers['p1'] = repo.preachers['p1']!.copyWith(linkedProfileId: 'channel');
      final lessons = LessonsController(repo);
      await tester.runAsync(lessons.ensureLoaded);
      if (streamed) lessons.setLiveChannels({'channel'});
      final app = AppProvider(AdminDatabaseService(null))
        ..debugSetOnlineForTests(true)
        ..addStreamerForTests(mockStreamers.first.copyWith(
            streamerId: 'near', isVerified: true, isTemporarilyHiddenFromMap: false, latitude: 26.2972, longitude: 50.1915));
      final pack = MapPackController(bundle: _NoPackBundle(), useWebStore: false);
      await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: Locale(lang),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: app),
            ChangeNotifierProvider<LessonsController>.value(value: lessons),
          ],
          child: Builder(
              builder: (context) => MaterialApp(
                    theme: AppTheme.forLocale(context.locale),
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
                    home: SpatialMapScreen(packController: pack),
                  )),
        ),
      ));
      // The first frames measure the controls and frame the overview.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      return (app: app, lessons: lessons, pack: pack);
    }

    Future<void> zoomTo(WidgetTester tester, double zoom) async {
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      map.mapController!.move(const LatLng(26.2935, 50.1955), zoom);
      await tester.pump();
      await tester.pump();
    }

    Future<void> finish(WidgetTester tester, ({AppProvider app, LessonsController lessons, MapPackController pack}) m) async {
      await tester.pumpWidget(const SizedBox());
      m.pack.dispose();
      m.lessons.dispose();
      m.app.dispose();
    }

    testWidgets('close pins share a bubble that counts both kinds', (tester) async {
      final m = await mapped(tester);
      await zoomTo(tester, 11);
      final bubbles = tester.widgetList<MapClusterBadge>(find.byType(MapClusterBadge)).toList();
      expect(bubbles, isNotEmpty);
      final mixed = bubbles.where((b) => b.mosques > 0 && b.mosques < b.count);
      expect(mixed, isNotEmpty, reason: 'the streamer groups with the mosques around it');
      expect(mixed.first.onSite, 1, reason: 'the lesson on now is counted on the bubble');
      await finish(tester, m);
    });

    testWidgets('zoomed in, the bubble is gone and each pin stands alone', (tester) async {
      final m = await mapped(tester);
      await zoomTo(tester, 14);
      expect(find.byType(MapClusterBadge), findsNothing);
      expect(find.byType(SpatialStreamerMarker), findsOneWidget);
      final huda = tester.widgetList<MosqueArch>(find.byType(MosqueArch)).firstWhere((a) => a.pin.id == 'm1');
      expect(huda.pin.onSite, isTrue);
      expect(huda.pin.live, isFalse);
      expect(huda.pin.chip, startsWith('lessons.map.now_left'.tr(args: ['']).trim().split(' ').first));
      expect(find.byKey(const ValueKey('map-now-pill')), findsOneWidget);
      await finish(tester, m);
    });

    testWidgets('right up close a streamer becomes its channel card', (tester) async {
      final m = await mapped(tester);
      await zoomTo(tester, kMapChannelCardZoom + .4);
      expect(find.byType(MapDiscoveryChannelCardMarker), findsOneWidget);
      expect(find.byType(SpatialStreamerMarker), findsNothing);
      expect(tester.takeException(), isNull);
      await finish(tester, m);
    });

    testWidgets('a mosque with nothing coming shows only when zoomed in', (tester) async {
      final m = await mapped(tester);
      bool quietShown() => tester.widgetList<MosqueArch>(find.byType(MosqueArch)).any((a) => a.pin.quiet);
      await zoomTo(tester, 11);
      expect(quietShown(), isFalse);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      map.mapController!.move(const LatLng(26.286, 50.122), kMapQuietMosqueZoom + 1);
      await tester.pump();
      await tester.pump();
      expect(quietShown(), isTrue);
      await finish(tester, m);
    });

    testWidgets('a streamed lesson with the channel live turns red', (tester) async {
      final m = await mapped(tester, streamed: true);
      await zoomTo(tester, 14);
      final huda = tester.widgetList<MosqueArch>(find.byType(MosqueArch)).firstWhere((a) => a.pin.id == 'm1');
      expect((huda.pin.live, huda.pin.onSite), (true, false));
      await finish(tester, m);
    });

    for (final lang in ['en', 'ar']) {
      testWidgets('a mosque card reads without scrolling on a phone ($lang)', (tester) async {
        // A 800 px phone less its bottom bar.
        final m = await mapped(tester, lang: lang, height: 730);
        await zoomTo(tester, 14);
        tester.widgetList<MosqueArch>(find.byType(MosqueArch)).firstWhere((a) => a.pin.id == 'm1').onTap!();
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump();
        final card = find.byKey(const ValueKey('map-mosque-card'));
        expect(card, findsOneWidget);
        final scroll = tester.state<ScrollableState>(find.ancestor(of: card, matching: find.byType(Scrollable)).first);
        expect(scroll.position.maxScrollExtent, 0);
        expect(tester.takeException(), isNull);
        await finish(tester, m);
      });
    }

    testWidgets('topics follow the layer', (tester) async {
      final m = await mapped(tester);
      TopicSelectorDropdown topics() => tester.widget(find.byType(TopicSelectorDropdown));
      expect(topics().categories.any((c) => c.id == 'seerah'), isFalse);
      tester.widget<MapLayerSwitch>(find.byType(MapLayerSwitch)).onChanged(MapLayers.lessons);
      await tester.pump(const Duration(milliseconds: 300));
      expect(topics().categories.any((c) => c.id == 'seerah'), isTrue);
      await finish(tester, m);
    });
  });

  test('live channels come from the catalog of streamers', () {
    final provider = AppProvider(AdminDatabaseService(null));
    expect(provider.liveChannelIds, isEmpty);
    provider.dispose();
  });
}
