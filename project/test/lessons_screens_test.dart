import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_navigation.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/map/services/map_pack_controller.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/domain/lessons_dates.dart';
import 'package:streamer_app/features/lessons/domain/lessons_models.dart';
import 'package:streamer_app/features/lessons/domain/lessons_rules.dart';
import 'package:streamer_app/features/lessons/presentation/screens/discover_screen.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_in_app.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_kit.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_map.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_widgets.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'package:streamer_app/features/web/presentation/hidayah_web_header.dart';

import 'support/localized_app.dart';

const _phone = Size(390, 844);
const _smallPhone = Size(360, 740);
const _web = Size(1280, 800);

/// No map files: the shared map settles on "unavailable" and draws its pins
/// without tiles (tiles are covered on devices and in Chrome).
class _NoPackBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('no $key');
}

/// The real app router with Lessons's sample data, viewed as [persona].
class _App {
  _App(this.tester, this.router, this.lessons, this.repo, this.provider,
      this.lang);
  final WidgetTester tester;
  final GoRouter router;
  final LessonsController lessons;
  final DemoLessonsRepository repo;
  final AppProvider provider;
  final String lang;

  String get at => router.routeInformationProvider.value.uri.toString();

  Future<void> go(String location) async {
    router.go(location);
    await _settle(tester);
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    lessons.dispose();
    provider.dispose();
  }
}

Future<_App> _open(
  WidgetTester tester,
  String location, {
  LessonsDemoPersona persona = LessonsDemoPersona.guest,
  Size size = _phone,
  String lang = 'en',
  double scale = 1,
  void Function(DemoLessonsRepository repo)? setup,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = AppProvider();
  final repo = DemoLessonsRepository(persona: persona);
  setup?.call(repo);
  final lessons = LessonsController(repo);
  final router = AppRouter.build(provider);
  router.go(location);
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
          routerConfig: router,
          theme: AppTheme.forLocale(context.locale),
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    ),
  ));
  await _settle(tester);
  return _App(tester, router, lessons, repo, provider, lang);
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10));

/// Scrolls [finder] into view, then taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  final target = finder.first;
  await tester.ensureVisible(target);
  await _settle(tester);
  await tester.tap(target);
  await _settle(tester);
}

/// Inside the open sheet (phones) or dialog (website).
Finder _inModal(Finder finder) => find.descendant(
    of: find.byWidgetPredicate((w) => w is BottomSheet || w is Dialog),
    matching: finder);

String _plural(String key, int n) => 'lessons.n.$key'.plural(n);

Lesson _lesson(DemoLessonsRepository repo, bool Function(Lesson) test) =>
    repo.lessons.values.where(test).toList().first;

/// The next session of "Explaining Kitab al-Tawhid" (the viewer has a
/// reminder on it).
Lesson _nextTawhid(DemoLessonsRepository repo) {
  final today = lessonsToday();
  return (repo.lessons.values
          .where((l) => l.seriesId == 's1' && !l.date.isBefore(today))
          .toList()
        ..sort(compareLessons))
      .first;
}

int _upcomingMatching(LessonsController c, LessonFilter f) => c.publicLessons
    .where((l) => !l.date.isBefore(c.today) && f.matches(l, c.catalog))
    .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;

  setUpAll(() async {
    await initializeTestLocalization();
    for (final font in {
      'IBM Plex Sans': ['assets/fonts/IBMPlexSans-Variable.ttf'],
      'IBM Plex Sans Arabic': [
        'assets/fonts/IBMPlexSansArabic-400.ttf',
        'assets/fonts/IBMPlexSansArabic-700.ttf'
      ],
      'Reem Kufi': ['assets/fonts/ReemKufi-Variable.ttf'],
    }.entries) {
      final loader = FontLoader(font.key);
      for (final file in font.value) {
        loader.addFont(rootBundle.load(file));
      }
      await loader.load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LessonsMap.debugPlaceholder = true;
    MapPackController.debugShared =
        MapPackController(bundle: _NoPackBundle(), useWebStore: false);
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  tearDown(() {
    LessonsMap.debugPlaceholder = false;
    MapPackController.debugShared = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // Lessons is part of Hadayah Live (ADR-014): a Lessons tab beside Discover
  // and Map, mosques on the one map, a lessons row on Discover, and a
  // person's programme pages in Settings. Nothing switches the app.
  group('inside Hadayah Live', () {
    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
    ]) {
      testWidgets('phone: Lessons is the third tab, after Discover and Map ($lang x$scale)',
          (tester) async {
        final app =
            await _open(tester, '/feed', lang: lang, size: size, scale: scale);
        expect(find.byType(DiscoveryFeedScreen), findsOneWidget);
        expect(find.byType(CaNavBar), findsOneWidget);

        await _tap(tester, find.byTooltip('nav.lessons'.tr()));
        expect(app.at, '/lessons');
        expect(find.byType(LessonsDiscoverScreen), findsOneWidget);
        expect(find.byType(CaNavBar), findsOneWidget);

        await _tap(tester, find.byTooltip('nav.map'.tr()));
        expect(app.at, '/map');
        expect(find.byType(SpatialMapScreen), findsOneWidget);

        await _tap(tester, find.byTooltip('nav.feed'.tr()));
        expect(app.at, '/feed');
        await app.close();
      });
    }

    testWidgets('website: Lessons is in the site header, between Map and Organizations',
        (tester) async {
      final app = await _open(tester, '/lessons', size: _web);
      expect(find.byType(HidayahWebHeader), findsOneWidget);
      expect(find.byType(HidayahWebFooter), findsOneWidget);
      final header = find.byType(HidayahWebHeader);
      double x(String key) => tester
          .getCenter(find.descendant(of: header, matching: find.text(key.tr())))
          .dx;
      expect(x('web.nav_map'), lessThan(x('web.nav_lessons')));
      expect(x('web.nav_lessons'), lessThan(x('web.nav_orgs')));

      await _tap(tester,
          find.descendant(of: header, matching: find.text('web.nav_discover'.tr())));
      expect(app.at, '/feed');
      await _tap(tester,
          find.descendant(of: header, matching: find.text('web.nav_lessons'.tr())));
      expect(app.at, '/lessons');
      await app.close();
    });

    testWidgets('a lesson page above the tabs keeps the site header on the website',
        (tester) async {
      final app = await _open(tester, '/lessons', size: _web);
      final l = _nextTawhid(app.repo);
      await app.go('/lessons/lesson/${l.id}');
      expect(find.byType(HidayahWebHeader), findsOneWidget);
      await app.close();
    });

    for (final size in [_phone, _web]) {
      testWidgets('Discover shows this week\'s mosque lessons (${size.width})',
          (tester) async {
        final app = await _open(tester, '/feed', size: size);
        final rail = find.byKey(const ValueKey('feed-lessons-rail'));
        await tester.scrollUntilVisible(rail, 300,
            scrollable: find.byType(Scrollable).first);
        expect(find.descendant(of: rail, matching: find.byType(LessonCard)),
            findsWidgets);
        final seeAll = find.descendant(
            of: rail, matching: find.text('lessons.see_all'.tr()));
        await _tap(tester, seeAll);
        expect(app.at, '/lessons');
        await app.close();
      });
    }

    testWidgets('Discover shows no lessons row when there are none',
        (tester) async {
      final app = await _open(tester, '/feed',
          setup: (repo) => repo.lessons.clear());
      expect(find.byKey(const ValueKey('feed-lessons-rail')), findsNothing);
      await app.close();
    });
  });

  group('the shared map', () {
    for (final size in [_phone, _web]) {
      testWidgets('mosques with lessons are pinned beside broadcasters (${size.width})',
          (tester) async {
        final app = await _open(tester, '/map', size: size);
        final pins = mapMosques(app.lessons, 'en');
        expect(pins, isNotEmpty);
        // The marker layer draws the pins inside the visible map.
        final shown = find.byType(MosqueCoin).evaluate().length;
        expect(shown, inInclusiveRange(1, pins.length));

        // Broadcasters only, then lessons back.
        await _tap(tester, find.byKey(const ValueKey('map-layer-streamers')));
        expect(find.byType(MosqueCoin), findsNothing);
        await _tap(tester, find.byKey(const ValueKey('map-layer-lessons')));
        expect(find.byType(MosqueCoin), findsNWidgets(shown));

        // A coin opens the mosque's card, and its page from there. (Called
        // directly: without map files the pack notice covers the centre.)
        final m1 = pins.firstWhere((m) => m.id == 'm1');
        tester
            .widget<MosqueCoin>(find.byWidgetPredicate(
                (w) => w is MosqueCoin && w.pin.id == m1.id))
            .onTap!();
        await _settle(tester);
        expect(find.byKey(const ValueKey('map-mosque-card')), findsOneWidget);
        expect(find.text(m1.label), findsWidgets);
        await _tap(tester, find.text('lessons.map.mosque_page'.tr()));
        expect(app.at, '/lessons/mosques/m1');
        await app.close();
      });
    }

    testWidgets('a lessons map link opens the shared map on that mosque',
        (tester) async {
      final app = await _open(tester, '/lessons/map?mosque=m1');
      expect(app.at, '/map?mosque=m1');
      expect(find.byKey(const ValueKey('map-mosque-card')), findsOneWidget);
      expect(find.text(app.repo.mosques['m1']!.name('en')), findsWidgets);
      await app.close();
    });

    testWidgets('links from before the rename (/taysir) still open',
        (tester) async {
      final app = await _open(tester, '/taysir');
      expect(app.at, '/lessons');
      final l = _nextTawhid(app.repo);
      for (final (old, now) in [
        ('/taysir/lessons?topic=seerah', '/lessons/calendar?topic=seerah'),
        ('/taysir/lessons/${l.id}', '/lessons/lesson/${l.id}'),
        ('/taysir/mosques/m1', '/lessons/mosques/m1'),
        ('/taysir/map?mosque=m1', '/map?mosque=m1'),
      ]) {
        await app.go(old);
        expect(app.at, now, reason: old);
      }
      await app.close();
    });

    testWidgets('a mosque page opens the shared map on its lessons',
        (tester) async {
      final app = await _open(tester, '/lessons/mosques/m1');
      await _tap(tester, find.text('lessons.calendar.on_map'.tr()));
      expect(app.at, '/map?mosque=m1');
      expect(find.byKey(const ValueKey('map-mosque-card')), findsOneWidget);
      await app.close();
    });

    testWidgets('without lessons the map has no layer switch', (tester) async {
      final app = await _open(tester, '/map',
          setup: (repo) => repo.lessons.clear());
      expect(find.byType(MapLayerSwitch), findsNothing);
      expect(find.byType(MosqueCoin), findsNothing);
      await app.close();
    });
  });

  group('discover', () {
    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
    ]) {
      testWidgets('phone: Hadayah tabs, sample banner and lessons ($lang x$scale)',
          (tester) async {
        final app =
            await _open(tester, '/lessons', lang: lang, size: size, scale: scale);
        expect(find.text('lessons.sample_banner'.tr()), findsOneWidget);
        for (final tab in ['feed', 'map', 'lessons']) {
          expect(find.byTooltip('nav.$tab'.tr()), findsOneWidget);
        }
        // No website header on phones.
        expect(find.byType(HidayahWebHeader), findsNothing);

        final row = find.byType(LessonRow).first;
        final id = tester.widget<LessonRow>(row).lesson.id;
        await _tap(tester, row);
        expect(app.at, '/lessons/lesson/$id');
        expect(find.text(app.lessons.lesson(id)!.title(lang)), findsWidgets);
        await app.close();
      });
    }

    for (final lang in ['en', 'ar']) {
      testWidgets('website: site header and hero at 1280 ($lang)', (tester) async {
        final app = await _open(tester, '/lessons', lang: lang, size: _web);
        expect(find.byType(HidayahWebHeader), findsOneWidget);
        expect(find.text('lessons.discover.hero_title'.tr()), findsOneWidget);
        expect(find.text('web.sign_in'.tr()), findsOneWidget);
        expect(find.byType(LessonCard), findsWidgets);
        await _tap(tester, find.text('lessons.see_all'.tr()));
        expect(app.at, '/lessons/calendar');
        expect(find.text('lessons.calendar.title'.tr()), findsOneWidget);
        await app.close();
      });
    }

    testWidgets('phone: all lessons opens inside the tab and goes back',
        (tester) async {
      final app = await _open(tester, '/lessons');
      await _tap(tester, find.text('lessons.see_all'.tr()));
      expect(app.at, '/lessons/calendar');
      expect(find.byType(CaNavBar), findsOneWidget);
      await _tap(tester, find.byTooltip('lessons.back'.tr()));
      expect(app.at, '/lessons');
      await app.close();
    });

    for (final size in [_phone, _web]) {
      testWidgets('the language button switches every label (${size.width})',
          (tester) async {
        final app = await _open(tester, '/lessons', size: size);
        final keys = [
          size == _web ? 'web.nav_lessons' : 'lessons.app_name',
          'lessons.discover.upcoming',
          'lessons.sample_banner',
        ];
        final english = [for (final key in keys) key.tr()];
        await _tap(
            tester,
            find.byTooltip(
                size == _web ? 'language.switch_lang'.tr() : 'العربية'));
        expect(app.tester.element(find.byType(LessonsDiscoverScreen)).locale,
            const Locale('ar'));
        for (final (key, en) in [
          for (var i = 0; i < keys.length; i++) (keys[i], english[i])
        ]) {
          expect(find.text(en), findsNothing, reason: key);
          expect(find.text(key.tr()), findsWidgets, reason: key);
        }
        expect(
            Directionality.of(
                tester.element(find.byType(LessonsDiscoverScreen))),
            TextDirection.rtl);
        await app.close();
      });
    }

    testWidgets('a preacher sees the submit band and button', (tester) async {
      final app =
          await _open(tester, '/lessons', persona: LessonsDemoPersona.preacher);
      final name = app.repo.preachers['p1']!.name('en');
      expect(find.text('lessons.discover.welcome'.tr(args: [name])),
          findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await _tap(tester, find.byType(FloatingActionButton));
      expect(app.at, '/lessons/submit');
      await app.close();
    });
  });

  group('lessons filters', () {
    testWidgets('phone: the filter sheet narrows the list by language',
        (tester) async {
      final app = await _open(tester, '/lessons/calendar');
      final c = app.lessons;
      final all = _upcomingMatching(c, LessonFilter.none);
      expect(find.text(_plural('results', all)), findsOneWidget);

      await _tap(tester, find.byTooltip('lessons.calendar.filter'.tr()));
      expect(find.text('lessons.calendar.filter_title'.tr()), findsOneWidget);
      await _tap(tester, _inModal(find.text('اردو')));
      await _tap(tester, find.text('lessons.calendar.show_results'.tr()));

      final urdu = _upcomingMatching(c, const LessonFilter(language: 'ur'));
      expect(urdu, inExclusiveRange(0, all));
      expect(find.text(_plural('results', urdu)), findsOneWidget);
      for (final row in tester.widgetList<LessonRow>(find.byType(LessonRow))) {
        final l = row.lesson;
        expect(l.language == 'ur' || l.interpretation == 'ur', isTrue,
            reason: l.titleEn);
      }
      await app.close();
    });

    testWidgets('phone: a shared filter link opens filtered', (tester) async {
      final app = await _open(tester, '/lessons/calendar?topic=seerah');
      final n =
          _upcomingMatching(app.lessons, const LessonFilter(topic: 'seerah'));
      expect(find.text(_plural('results', n)), findsOneWidget);
      await app.close();
    });

    for (final lang in ['en', 'ar']) {
      testWidgets('website: city chips, week grid and clearing ($lang)',
          (tester) async {
        final app =
            await _open(tester, '/lessons/calendar', lang: lang, size: _web);
        final c = app.lessons;
        await _tap(tester, find.text('lessons.city.dammam'.tr()));
        final dammam =
            _upcomingMatching(c, const LessonFilter(city: 'dammam'));
        expect(find.text(_plural('results', dammam)), findsOneWidget);

        await _tap(tester, find.text('lessons.calendar.week'.tr()));
        expect(find.byType(Table), findsOneWidget);

        await _tap(tester,
            find.text('lessons.calendar.clear_n'.tr(args: ['1'])));
        expect(
            find.text(_plural('results', _upcomingMatching(c, LessonFilter.none))),
            findsOneWidget);
        await app.close();
      });
    }
  });

  group('lesson detail', () {
    testWidgets('a guest asked to remind is asked to sign in, and can share',
        (tester) async {
      final app = await _open(tester, '/lessons');
      final l = _nextTawhid(app.repo);
      await app.go('/lessons/lesson/${l.id}');
      await _tap(tester, find.text('lessons.lesson.remind'.tr()));
      expect(find.text('lessons.sign_in_title'.tr()), findsOneWidget);
      await _tap(tester, find.byTooltip('lessons.close'.tr()));

      await _tap(tester, find.text('lessons.lesson.share'.tr()));
      expect(find.text('lessons.share.title'.tr()), findsOneWidget);
      await _tap(tester, _inModal(find.text('lessons.share.copy'.tr())));
      expect(clipboard, contains('/lessons/lesson/${l.id}'));
      expect(clipboard, contains(l.title('en')));
      expect(find.text('lessons.copied'.tr()), findsOneWidget);
      await app.close();
    });

    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('en', _web, 1.0),
    ]) {
      testWidgets('a viewer sets and removes a reminder ($lang ${size.width} x$scale)',
          (tester) async {
        final app = await _open(tester, '/lessons',
            persona: LessonsDemoPersona.viewer,
            lang: lang,
            size: size,
            scale: scale);
        final l = _lesson(app.repo, (l) => l.titleEn == 'Repentance, an open door');
        await app.go('/lessons/lesson/${l.id}');
        expect(app.lessons.hasReminder(l.id), isFalse);

        await _tap(tester, find.text('lessons.lesson.remind'.tr()));
        expect(find.text('lessons.remind.title'.tr()), findsOneWidget);
        await _tap(tester, _inModal(find.text('lessons.lead.30'.tr())));
        expect(app.lessons.reminderLead(l.id), '30');
        expect(find.text('lessons.remind.saved'.tr()), findsOneWidget);
        expect(find.text('lessons.lesson.reminder_on'.tr()), findsOneWidget);

        await _tap(tester, find.text('lessons.lesson.reminder_on'.tr()));
        await _tap(tester, _inModal(find.text('lessons.remind.remove'.tr())));
        expect(app.lessons.hasReminder(l.id), isFalse);
        await app.close();
      });
    }

    for (final (lang, size) in [('en', _phone), ('ar', _web)]) {
      testWidgets('a coordinator cancels a session and reminded viewers are told ($lang ${size.width})',
          (tester) async {
        final app = await _open(tester, '/lessons',
            persona: LessonsDemoPersona.coordinator, lang: lang, size: size);
        final l = _nextTawhid(app.repo);
        await app.go('/lessons/lesson/${l.id}');
        await _tap(tester, find.text('lessons.lesson.cancel'.tr()));
        expect(find.text('lessons.cxl.title'.tr()), findsOneWidget);
        await _tap(tester, _inModal(find.text('lessons.cxl.confirm'.tr())));

        expect(app.repo.lessons[l.id]!.status, 'cancelled');
        // The viewer had a reminder on this session.
        expect(find.text('lessons.cxl.done'.tr(args: [_plural('people', 1)])),
            findsOneWidget);
        expect(find.textContaining('lessons.lesson.cancelled'.tr()),
            findsOneWidget);
        expect(find.text('lessons.lesson.cancel'.tr()), findsNothing);
        await app.close();
      });
    }
  });

  group('submit wizard', () {
    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('ar', _web, 1.0),
    ]) {
      testWidgets('a preacher sends a lesson for review ($lang ${size.width} x$scale)',
          (tester) async {
        final app = await _open(tester, '/lessons/submit',
            persona: LessonsDemoPersona.preacher,
            lang: lang,
            size: size,
            scale: scale);
        const title = 'درس تجريبي في فقه الصيام';
        final next = find.text('lessons.next'.tr());

        await tester.enterText(find.byType(TextField).first, title);
        await _settle(tester);
        await _tap(tester, next);

        await _tap(tester, find.text(app.repo.mosques['m1']!.name(lang)));
        await _tap(tester, next);
        await _tap(tester, next);

        expect(find.text('lessons.submit.summary'.tr()), findsOneWidget);
        await _tap(tester, find.text('lessons.submit.send'.tr()));

        final sent = app.repo.lessons.values.where((l) => l.titleAr == title);
        expect(sent, hasLength(1));
        expect(sent.single.status, 'pending');
        expect(sent.single.mosqueId, 'm1');
        expect(sent.single.date, addDays(lessonsToday(), 2));
        expect(app.at, '/lessons/me/lessons');
        expect(find.text(title), findsOneWidget);
        await app.close();
      });
    }

    testWidgets('the wizard holds Next until a title is written',
        (tester) async {
      final app = await _open(tester, '/lessons/submit',
          persona: LessonsDemoPersona.preacher);
      await _tap(tester, find.text('lessons.next'.tr()));
      // Still on the first step.
      expect(find.text('lessons.submit.title_ar_hint'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('a guest or viewer cannot submit', (tester) async {
      final app = await _open(tester, '/lessons/submit',
          persona: LessonsDemoPersona.viewer);
      expect(find.text('lessons.submit.not_allowed'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('a coordinator publishes directly for a chosen preacher (1280)',
        (tester) async {
      final app = await _open(tester, '/lessons/submit',
          persona: LessonsDemoPersona.coordinator, size: _web);
      const title = 'محاضرة منشورة مباشرة';
      await _tap(tester, find.byType(DropdownButtonFormField<String>).first);
      await tester.tap(find.text(app.repo.preachers['p3']!.name('en')).last);
      await _settle(tester);
      await tester.enterText(find.byType(TextField).first, title);
      await _settle(tester);
      await _tap(tester, find.text('lessons.next'.tr()));
      await _tap(tester, find.text('lessons.city.dhahran'.tr()));
      await _tap(tester, find.text(app.repo.mosques['m5']!.name('en')));
      await _tap(tester, find.text('lessons.next'.tr()));
      await _tap(tester, find.text('lessons.next'.tr()));
      await _tap(tester, find.text('lessons.submit.direct'.tr()));
      await _tap(tester, find.text('lessons.submit.publish'.tr()));

      final sent = app.repo.lessons.values.where((l) => l.titleAr == title);
      expect(sent.single.status, 'approved');
      expect(sent.single.preacherId, 'p3');
      expect(app.at, '/lessons/console/review');
      await app.close();
    });
  });

  group('console', () {
    testWidgets('guests and viewers see the locked console', (tester) async {
      final app = await _open(tester, '/lessons/console',
          persona: LessonsDemoPersona.viewer);
      expect(find.text('lessons.console.locked'.tr()), findsOneWidget);
      await app.close();
    });

    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('en', _web, 1.0),
      ('ar', _web, 1.0),
    ]) {
      testWidgets('review: approve, reject with a reason, undo ($lang ${size.width} x$scale)',
          (tester) async {
        final app = await _open(tester, '/lessons/console/review',
            persona: LessonsDemoPersona.coordinator,
            lang: lang,
            size: size,
            scale: scale);
        final c = app.lessons;
        expect(c.pendingRequests, hasLength(5));
        final first = c.pendingRequests.first;
        expect(first.isSeries, isTrue);

        await _tap(tester, find.text('lessons.review.approve'.tr()));
        expect(c.pendingRequests, hasLength(4));
        expect(
            app.repo.lessons.values
                .where((l) => l.requestId == first.id)
                .every((l) => l.status == 'approved'),
            isTrue);
        expect(
            find.text('lessons.review.approved'
                .tr(args: [_plural('requests', 1)])),
            findsOneWidget);

        final second = c.pendingRequests.first;
        await _tap(tester, find.text('lessons.review.reject'.tr()));
        expect(find.text('lessons.review.reject_title'.tr()), findsOneWidget);
        await _tap(tester, _inModal(find.text('lessons.review.reject_sel'.tr())));
        final rejected = app.repo.lessons.values
            .firstWhere((l) => l.requestId == second.id);
        expect(rejected.status, 'rejected');
        expect(rejected.rejectionReason,
            startsWith('lessons.reject_reason.clash'.tr()));
        expect(c.pendingRequests, hasLength(3));

        await _tap(tester, find.text('lessons.review.undo'.tr()));
        expect(
            app.repo.lessons.values
                .firstWhere((l) => l.requestId == second.id)
                .status,
            'pending');
        expect(c.pendingRequests, hasLength(4));
        await app.close();
      });
    }

    testWidgets('review: select all and approve together', (tester) async {
      final app = await _open(tester, '/lessons/console/review',
          persona: LessonsDemoPersona.coordinator, size: _web);
      await _tap(tester, find.text('lessons.review.select_all'.tr()));
      await _tap(tester,
          find.text('lessons.review.approve_sel'.tr(args: ['5'])));
      expect(app.lessons.pendingRequests, isEmpty);
      expect(find.text('lessons.review.empty'.tr()), findsOneWidget);
      await app.close();
    });

    for (final (lang, size) in [('en', _phone), ('ar', _web)]) {
      testWidgets('roster: a phone is revealed on request and logged ($lang ${size.width})',
          (tester) async {
        final app = await _open(tester, '/lessons/console/preachers',
            persona: LessonsDemoPersona.coordinator, lang: lang, size: size);
        final masked = maskPhone('0500000101');
        expect(find.text(masked), findsOneWidget);
        expect(find.text('0500000101'), findsNothing);

        await _tap(tester, find.text(masked));
        expect(find.text('0500000101'), findsOneWidget);
        expect(find.text('lessons.roster.logged'.tr()), findsOneWidget);
        expect(app.repo.audit.first.action, 'phone');

        await _tap(tester, find.text('0500000101'));
        expect(find.text(masked), findsOneWidget);
        await app.close();
      });
    }

    testWidgets('roster: an invitation link is created for an unlinked preacher',
        (tester) async {
      final app = await _open(tester, '/lessons/console/preachers',
          persona: LessonsDemoPersona.coordinator, size: _web);
      final before = app.repo.invites.length;
      await _tap(tester, find.text('lessons.roster.invite'.tr()));
      expect(find.text('lessons.roster.invite_title'.tr()), findsOneWidget);
      expect(app.repo.invites.length, before + 1);
      await _tap(tester, _inModal(find.text('lessons.roster.copy_msg'.tr())));
      expect(clipboard, contains('/lessons/claim/'));
      await app.close();
    });
  });

  group('admins manage coordinators', () {
    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('en', _web, 1.0),
      ('ar', _web, 1.0),
    ]) {
      testWidgets('add, edit and remove a coordinator ($lang ${size.width} x$scale)',
          (tester) async {
        final app = await _open(tester, '/lessons/console/team',
            persona: LessonsDemoPersona.admin,
            lang: lang,
            size: size,
            scale: scale);
        const org = DemoLessonsRepository.org, org2 = DemoLessonsRepository.org2;
        final repo = app.repo;
        final reem = DemoLessonsRepository.accounts
            .firstWhere((a) => a.id == 'demo-account-reem');
        expect(find.text('lessons.coord.title'.tr()), findsOneWidget);
        expect(app.lessons.coordinators, hasLength(1));

        // Add: search an account, choose an organization, save.
        await _tap(tester, find.text('lessons.coord.add'.tr()));
        await tester.enterText(_inModal(find.byType(TextField)), lang == 'ar' ? 'ريم' : 'Reem');
        await _tap(tester, _inModal(find.text('lessons.coord.search'.tr())));
        await _tap(tester, _inModal(find.text(reem.name(lang))));
        await _tap(tester, _inModal(find.text(repo.organizations[org]!.name(lang))));
        await _tap(tester, _inModal(find.text('lessons.save'.tr())));
        expect(repo.coordinatorGrants[reem.id], {org});
        expect(find.text('lessons.coord.saved'.tr()), findsOneWidget);
        expect(app.lessons.coordinators, hasLength(2));

        // Edit: move them to the other organization.
        await _tap(tester, find.text('lessons.coord.edit'.tr()).at(1));
        expect(find.text('lessons.coord.edit_title'.tr()), findsOneWidget);
        await _tap(tester, _inModal(find.text(repo.organizations[org2]!.name(lang))));
        await _tap(tester, _inModal(find.text(repo.organizations[org]!.name(lang))));
        await _tap(tester, _inModal(find.text('lessons.save'.tr())));
        expect(repo.coordinatorGrants[reem.id], {org2});

        // Remove, after confirming.
        await _tap(tester, find.text('lessons.coord.remove'.tr()).at(1));
        expect(
            find.text('lessons.coord.remove_title'.tr(args: [reem.name(lang)])),
            findsOneWidget);
        await _tap(tester, _inModal(find.text('lessons.coord.remove'.tr())));
        expect(repo.coordinatorGrants.containsKey(reem.id), isFalse);
        expect(find.text('lessons.coord.removed'.tr()), findsOneWidget);
        expect(app.lessons.coordinators, hasLength(1));
        // Every change is in the action log.
        expect(
            repo.audit.where((a) => a.targetEn == '${reem.nameEn} → coordinator'),
            hasLength(4));
        await app.close();
      });
    }

    testWidgets('saving needs at least one organization', (tester) async {
      final app = await _open(tester, '/lessons/console/team',
          persona: LessonsDemoPersona.admin);
      await _tap(tester, find.text('lessons.coord.add'.tr()));
      await tester.enterText(_inModal(find.byType(TextField)), 'Badr');
      await _tap(tester, _inModal(find.text('lessons.coord.search'.tr())));
      await _tap(tester, _inModal(find.text('Badr Al-Shammari')));
      await _tap(tester, _inModal(find.text('lessons.save'.tr())));
      expect(find.text('lessons.coord.pick_org'.tr()), findsOneWidget);
      expect(app.repo.coordinatorGrants.containsKey('demo-member-u3'), isFalse);
      await app.close();
    });

    testWidgets('a coordinator does not get the admins\' coordinator tools',
        (tester) async {
      final app = await _open(tester, '/lessons/console/team',
          persona: LessonsDemoPersona.coordinator);
      expect(find.text('lessons.coord.title'.tr()), findsNothing);
      expect(find.text('lessons.team.view_only'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('with no organizations yet, admins are told to create one first',
        (tester) async {
      final app = await _open(tester, '/lessons/console',
          persona: LessonsDemoPersona.admin,
          setup: (repo) => repo.organizations.clear());
      expect(find.text('lessons.coord.no_orgs'.tr()), findsOneWidget);
      expect(
          tester
              .widget<TButton>(find.ancestor(
                  of: find.text('lessons.coord.add'.tr()),
                  matching: find.byType(TButton)))
              .onPressed,
          isNull);
      await app.close();
    });
  });

  group('invitation claim', () {
    testWidgets('a guest is asked to sign in first', (tester) async {
      final app = await _open(tester, '/lessons/claim/invite-p5');
      final name = app.repo.preachers['p5']!.name('en');
      expect(find.text('lessons.claim.welcome'.tr(args: [name])), findsOneWidget);
      expect(find.text('lessons.claim.sign_in'.tr()), findsOneWidget);
      await app.close();
    });

    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('en', _web, 1.0),
    ]) {
      testWidgets('a signed-in preacher links the card ($lang ${size.width} x$scale)',
          (tester) async {
        final app = await _open(tester, '/lessons/claim/invite-p5',
            persona: LessonsDemoPersona.viewer,
            lang: lang,
            size: size,
            scale: scale);
        final link = find.text('lessons.claim.link'.tr());
        await _tap(tester, link);
        // Nothing happens until the terms are accepted.
        expect(app.repo.preachers['p5']!.linkedProfileId, isNull);

        await _tap(tester, find.text('lessons.claim.agree'.tr()));
        await _tap(tester, link);
        expect(app.repo.preachers['p5']!.linkedProfileId, 'demo-viewer');
        expect(find.text('lessons.claim.done'.tr()), findsOneWidget);
        expect(app.repo.invites.containsKey('invite-p5'), isFalse);
        await app.close();
      });
    }

    testWidgets('a used or unknown link says so', (tester) async {
      final app = await _open(tester, '/lessons/claim/not-a-token',
          persona: LessonsDemoPersona.viewer);
      expect(find.text('lessons.claim.invalid'.tr()), findsOneWidget);
      await app.close();
    });
  });

  group('settings', () {
    /// Settings needs a signed-in account; the card is checked on its own,
    /// with the programme's routes stubbed.
    Future<(LessonsController, List<String>)> pumpCard(
        WidgetTester tester, LessonsDemoPersona persona) async {
      final lessons = LessonsController(DemoLessonsRepository(persona: persona));
      addTearDown(lessons.dispose);
      final opened = <String>[];
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
                body: SingleChildScrollView(child: LessonsSettingsCard()))),
        GoRoute(
            path: '/lessons/:rest(.*)',
            builder: (_, state) {
              opened.add(state.uri.toString());
              return const Scaffold(body: Text('page'));
            }),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(EasyLocalization(
        key: UniqueKey(),
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: ChangeNotifierProvider<LessonsController>.value(
          value: lessons,
          child: Builder(
            builder: (context) => MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.forLocale(context.locale),
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
            ),
          ),
        ),
      ));
      await _settle(tester);
      return (lessons, opened);
    }

    testWidgets('a viewer reaches the programme page, reminders and alerts',
        (tester) async {
      final (lessons, opened) =
          await pumpCard(tester, LessonsDemoPersona.viewer);
      expect(find.text('lessons.programme'.tr()), findsOneWidget);
      expect(find.text('lessons.me.console'.tr()), findsNothing);
      expect(find.text('lessons.me.my_lessons'.tr()), findsNothing);
      expect(find.text('${lessons.mine.unread}'), findsOneWidget);
      await _tap(tester, find.text('lessons.me.reminders'.tr()));
      expect(opened.last, '/lessons/me/saved?tab=reminders');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a coordinator also gets the console, with pending requests',
        (tester) async {
      final (lessons, opened) =
          await pumpCard(tester, LessonsDemoPersona.coordinator);
      expect(find.text('${lessons.pendingRequests.length}'), findsOneWidget);
      await _tap(tester, find.text('lessons.me.console'.tr()));
      expect(opened.last, '/lessons/console');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a preacher also gets their lessons', (tester) async {
      final (_, opened) = await pumpCard(tester, LessonsDemoPersona.preacher);
      await _tap(tester, find.text('lessons.me.my_lessons'.tr()));
      expect(opened.last, '/lessons/me/lessons');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('me', () {
    testWidgets('the sample persona switcher changes the view', (tester) async {
      final app = await _open(tester, '/lessons/me');
      expect(find.text('lessons.me.guest_title'.tr()), findsOneWidget);
      await _tap(tester, find.text('lessons.me.p_coordinator'.tr()));
      expect(app.lessons.canCoordinate, isTrue);
      expect(find.text('lessons.me.console'.tr()), findsOneWidget);
      // Counted before the console was ever opened: 5 requests, 1 report.
      expect(
          find.text('lessons.me.console_body'.tr(
              args: [_plural('requests', 5), _plural('reports', 1)])),
          findsOneWidget);
      await _tap(tester, find.text('lessons.me.open'.tr()));
      expect(app.at, '/lessons/console');
      await app.close();
    });

    testWidgets('notifications are marked read when opened', (tester) async {
      final app = await _open(tester, '/lessons/me/notifications',
          persona: LessonsDemoPersona.viewer);
      expect(app.lessons.mine.unread, 2);
      await _tap(tester, find.text('lessons.notifications.mark_all'.tr()));
      expect(app.lessons.mine.unread, 0);
      await app.close();
    });
  });

  // Every Lessons page, for the roles that reach it, at phone and website
  // widths, in both languages and at large text: no overflow, no exception.
  group('layout sweep', () {
    List<(LessonsDemoPersona, String)> pages(DemoLessonsRepository repo) {
      final today = lessonsToday();
      final next = _nextTawhid(repo);
      final past = _lesson(repo, (l) =>
          l.preacherId == 'p1' &&
          l.status == 'approved' &&
          l.date.isBefore(today) &&
          !repo.reports.containsKey(l.id));
      const g = LessonsDemoPersona.guest,
          v = LessonsDemoPersona.viewer,
          p = LessonsDemoPersona.preacher,
          a = LessonsDemoPersona.admin;
      return [
        (g, '/lessons'),
        (g, '/lessons/calendar'),
        (g, '/feed'),
        (g, '/map'),
        (g, '/map?mosque=m1'),
        (g, '/lessons/me'),
        (g, '/lessons/lesson/${next.id}'),
        (g, '/lessons/series/s1'),
        (g, '/lessons/preachers/p1'),
        (g, '/lessons/mosques/m1'),
        (g, '/lessons/permissions'),
        (g, '/lessons/claim/invite-p5'),
        (g, '/lessons/console'),
        (g, '/lessons/me/saved'),
        (v, '/lessons/me'),
        (v, '/lessons/me/saved'),
        (v, '/lessons/me/saved?tab=log'),
        (v, '/lessons/me/saved?tab=mosques'),
        (v, '/lessons/me/notifications'),
        (v, '/lessons/lesson/${past.id}'),
        (v, '/lessons/claim/invite-p8'),
        (p, '/lessons'),
        (p, '/lessons/me'),
        (p, '/lessons/me/lessons'),
        (p, '/lessons/me/lessons?tab=rejected'),
        (p, '/lessons/me/lessons?tab=past'),
        (p, '/lessons/submit'),
        (p, '/lessons/report/${past.id}'),
        (p, '/lessons/lesson/${next.id}'),
        (a, '/lessons/console'),
        (a, '/lessons/console/review'),
        (a, '/lessons/console/review?filter=reports'),
        (a, '/lessons/console/preachers'),
        (a, '/lessons/console/mosques'),
        (a, '/lessons/console/reports'),
        (a, '/lessons/console/audit'),
        (a, '/lessons/console/team'),
        (a, '/lessons/lesson/${next.id}'),
      ];
    }

    for (final (size, scales) in [
      (_smallPhone, [1.0, 2.0]),
      (_web, [1.0, 2.0]),
    ]) {
      for (final lang in ['en', 'ar']) {
        for (final scale in scales) {
          testWidgets('${size.width.toInt()} $lang text x$scale',
              (tester) async {
            for (final persona in LessonsDemoPersona.values) {
              final probe = DemoLessonsRepository();
              final routes = [
                for (final (who, route) in pages(probe))
                  if (who == persona) route
              ];
              if (routes.isEmpty) continue;
              final app = await _open(tester, routes.first,
                  persona: persona, lang: lang, size: size, scale: scale);
              for (final route in routes) {
                await app.go(route);
                expect(tester.takeException(), isNull,
                    reason: '${persona.name} $route');
                expect(app.at, route, reason: 'stayed on $route');
              }
              await app.close();
            }
          });
        }
      }
    }
  });
}
