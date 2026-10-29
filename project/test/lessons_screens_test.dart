import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
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
import 'package:streamer_app/features/lessons/presentation/admin/lessons_admin_shell.dart';
import 'package:streamer_app/features/lessons/presentation/screens/discover_screen.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_in_app.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_map.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_widgets.dart';
import 'package:streamer_app/features/lessons/presentation/preacher_form_kit.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'package:streamer_app/features/lessons/state/preacher_link_controller.dart';
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
  bool platformAdmin = false,
  bool? signIn,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = AppProvider(AdminDatabaseService(null));
  // The admin page checks the account's role; the sample admin is a lessons
  // admin, and also a platform admin when [platformAdmin].
  if (signIn ?? persona == LessonsDemoPersona.admin) {
    provider.debugSetSignedInForTests(
        email: 'admin@example.invalid', isLessonsAdmin: true, isAdmin: platformAdmin);
  }
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

/// Chooses, in an approval card's city-then-mosque picker, the first mosque
/// of the city shown other than the one already chosen; returns its id.
Future<String> _pickMosque(WidgetTester tester, _App app, String requestId) async {
  final c = app.lessons, lang = app.lang;
  final r = c.pendingRequests.firstWhere((r) => r.id == requestId);
  final p = c.preacher(r.first.preacherId);
  final current = r.first.hasMosque ? r.first.mosqueId : (c.mosque(p?.homeMosqueId) == null ? null : p!.homeMosqueId);
  final city = cityOr(c, current, p?.city ?? 'khobar');
  final m = c.mosquesIn(city, lang, hidden: true).firstWhere((m) => m.id != current);
  return _chooseMosque(tester, app, find.byKey(ValueKey('approval-mosque-$requestId')), m.id);
}

/// Opens the mosque list of the picker inside [picker] and chooses [mosqueId].
Future<String> _chooseMosque(WidgetTester tester, _App app, Finder picker, String mosqueId) async {
  final c = app.lessons, lang = app.lang;
  final m = c.mosque(mosqueId)!;
  await _tap(tester, find.descendant(of: picker, matching: find.byType(DropdownButtonFormField<String>)).last);
  await tester.tap(find.textContaining('${m.name(lang)} · ${c.district(m.districtId)?.name(lang) ?? ''}').last);
  await _settle(tester);
  return m.id;
}

/// Chooses [city] in the picker inside [picker].
Future<void> _chooseCity(WidgetTester tester, Finder picker, String city) async {
  await _tap(tester, find.descendant(of: picker, matching: find.byType(DropdownButtonFormField<String>)).first);
  await tester.tap(find.text(cityLabel(city)).last);
  await _settle(tester);
}

/// [p] without an initial mosque (a card from before 20261029120000).
Preacher _withoutHome(Preacher p) => Preacher(
    id: p.id, nameAr: p.nameAr, nameEn: p.nameEn, titleAr: p.titleAr, titleEn: p.titleEn, city: p.city,
    affiliation: p.affiliation, languages: p.languages);

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

    testWidgets('an admin sees the Preachers & lessons band', (tester) async {
      final app =
          await _open(tester, '/lessons', persona: LessonsDemoPersona.admin);
      expect(find.text('lessons.admin.title'.tr()), findsWidgets);
      expect(find.byType(FloatingActionButton), findsNothing);
      await _tap(tester, find.text('lessons.discover.open_review'.tr()));
      expect(app.at, '/admin/lessons/approvals');
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
      testWidgets('an admin cancels a session and reminded viewers are told ($lang ${size.width})',
          (tester) async {
        final app = await _open(tester, '/lessons',
            persona: LessonsDemoPersona.admin, lang: lang, size: size);
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

    testWidgets('viewers get no admin tools on a lesson', (tester) async {
      final app = await _open(tester, '/lessons', persona: LessonsDemoPersona.viewer);
      await app.go('/lessons/lesson/${_nextTawhid(app.repo).id}');
      expect(find.text('lessons.lesson.cancel'.tr()), findsNothing);
      expect(find.text('lessons.admin.manage_preacher'.tr()), findsNothing);
      await app.close();
    });
  });

  // The admin page's Preachers & lessons area (owner decisions 2026-10-22).
  group('admin area', () {
    testWidgets('a platform admin opens the platform area from the switch (1280)',
        (tester) async {
      final app = await _open(tester, '/admin/lessons',
          persona: LessonsDemoPersona.admin, platformAdmin: true, size: _web);
      expect(find.byKey(const ValueKey('lessons-admin-navigation')), findsOneWidget);
      // The platform area (a deferred library) is checked in admin_roles_test.
      await tester.tap(find.byKey(const ValueKey('admin-area-platform')));
      await tester.pump();
      expect(app.at, '/admin');
      await app.close();
    });

    testWidgets('a lessons-only admin goes straight to Preachers & lessons',
        (tester) async {
      final app = await _open(tester, '/admin',
          persona: LessonsDemoPersona.admin, size: _web);
      expect(app.at, '/admin/lessons');
      expect(find.byKey(const ValueKey('admin-area-platform')), findsNothing);
      await app.close();
    });

    testWidgets('phone: the tabs are in the drawer', (tester) async {
      final app = await _open(tester, '/admin/lessons', persona: LessonsDemoPersona.admin);
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await _settle(tester);
      await _tap(tester, find.byKey(const ValueKey('lessons-admin-tab-mosques')));
      expect(app.at, '/admin/lessons/mosques');
      expect(find.text('lessons.mosques.body'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('guests and viewers are kept out', (tester) async {
      final app = await _open(tester, '/admin/lessons', persona: LessonsDemoPersona.viewer);
      expect(app.at, '/welcome');
      await app.close();
    });

    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('en', _web, 1.0),
      ('ar', _web, 1.0),
    ]) {
      testWidgets('approvals: choose a mosque, approve, decline with a reason, undo ($lang ${size.width} x$scale)',
          (tester) async {
        // A preacher with no initial mosque: the admin must choose one.
        final app = await _open(tester, '/admin/lessons/approvals',
            persona: LessonsDemoPersona.admin, lang: lang, size: size, scale: scale,
            setup: (repo) {
              repo.preachers['p4'] = _withoutHome(repo.preachers['p4']!);
              // Only requests here: the application card has its own Approve.
              repo.applications.clear();
            });
        final c = app.lessons;
        expect(c.pendingRequests, hasLength(5));
        final first = c.pendingRequests.first;
        expect(first.isSeries, isTrue);
        expect(first.first.hasMosque, isFalse);

        // Nothing is approved without a mosque.
        await _tap(tester, find.text('lessons.review.approve'.tr()));
        expect(find.text('lessons.approvals.choose_mosque'.tr()), findsOneWidget);
        expect(c.pendingRequests, hasLength(5));

        final mosque = await _pickMosque(tester, app, first.id);
        await _tap(tester, find.text('lessons.review.approve'.tr()));
        expect(c.pendingRequests, hasLength(4));
        final approved = app.repo.lessons.values.where((l) => l.requestId == first.id);
        expect(approved.every((l) => l.status == 'approved' && l.mosqueId == mosque), isTrue);
        expect(find.text('lessons.review.approved'.tr(args: [_plural('requests', 1)])),
            findsOneWidget);

        final second = c.pendingRequests.first;
        await _tap(tester, find.text('lessons.review.reject'.tr()));
        expect(find.text('lessons.review.reject_title'.tr()), findsOneWidget);
        await _tap(tester, _inModal(find.text('lessons.review.reject_sel'.tr())));
        final rejected = app.repo.lessons.values.firstWhere((l) => l.requestId == second.id);
        expect(rejected.status, 'rejected');
        expect(rejected.rejectionReason, startsWith('lessons.reject_reason.clash'.tr()));
        expect(c.pendingRequests, hasLength(3));

        await _tap(tester, find.text('lessons.review.undo'.tr()));
        expect(app.repo.lessons.values.firstWhere((l) => l.requestId == second.id).status, 'pending');
        expect(c.pendingRequests, hasLength(4));
        await app.close();
      });
    }

    testWidgets("approvals: a request starts at the preacher's first mosque", (tester) async {
      final app = await _open(tester, '/admin/lessons/approvals',
          persona: LessonsDemoPersona.admin, size: _web, setup: (repo) => repo.applications.clear());
      final first = app.lessons.pendingRequests.first;
      final home = app.repo.preachers[first.first.preacherId]!.homeMosqueId!;
      await _tap(tester, find.text('lessons.review.approve'.tr()));
      expect(app.repo.lessons.values.where((l) => l.requestId == first.id).every((l) => l.mosqueId == home), isTrue);
      await app.close();
    });

    testWidgets('approvals: approve several together, each with its mosque', (tester) async {
      final app = await _open(tester, '/admin/lessons/approvals',
          persona: LessonsDemoPersona.admin, size: _web);
      final reqs = app.lessons.pendingRequests.take(2).toList();
      for (final r in reqs) {
        await _pickMosque(tester, app, r.id);
      }
      await _tap(tester, find.byType(Checkbox).at(0));
      await _tap(tester, find.byType(Checkbox).at(1));
      await _tap(tester, find.text('lessons.review.approve_sel'.tr(args: ['2'])));
      expect(app.lessons.pendingRequests, hasLength(3));
      for (final r in reqs) {
        expect(app.repo.lessons.values.where((l) => l.requestId == r.id).every((l) => l.status == 'approved'), isTrue);
      }
      await app.close();
    });

    testWidgets("approvals: a preacher's card change is applied", (tester) async {
      final app = await _open(tester, '/admin/lessons/approvals',
          persona: LessonsDemoPersona.admin, size: _web);
      final edit = app.repo.edits.single;
      await _tap(tester, find.text('lessons.approvals.apply'.tr()));
      expect(app.repo.preachers['p4']!.titleAr, edit.changes['title_ar']);
      expect(app.lessons.pendingEdits, isEmpty);
      expect(find.text('lessons.approvals.no_edits'.tr()), findsOneWidget);
      await app.close();
    });

    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('ar', _web, 1.0),
    ]) {
      testWidgets('add a lesson for a preacher: published at once ($lang ${size.width} x$scale)',
          (tester) async {
        final app = await _open(tester, '/admin/lessons/add?preacher=p3',
            persona: LessonsDemoPersona.admin, lang: lang, size: size, scale: scale);
        const title = 'درس تجريبي في فقه الصيام';
        final next = find.text('lessons.next'.tr());

        await tester.enterText(find.byKey(const ValueKey('add-title-ar')), title);
        await _settle(tester);
        await _tap(tester, next);
        await _tap(tester, find.text(app.repo.mosques['m1']!.name(lang)));
        await _tap(tester, next);
        await _tap(tester, next);
        expect(find.text('lessons.submit.summary'.tr()), findsOneWidget);
        await _tap(tester, find.text('lessons.add.publish'.tr()));

        final added = app.repo.lessons.values.where((l) => l.titleAr == title);
        expect(added, hasLength(1));
        expect(added.single.status, 'approved');
        expect(added.single.preacherId, 'p3');
        expect(added.single.mosqueId, 'm1');
        expect(added.single.date, addDays(lessonsToday(), 2));
        expect(app.at, '/admin/lessons/preachers/p3');
        await app.close();
      });
    }

    testWidgets('the add wizard holds Next until a preacher and a title are chosen',
        (tester) async {
      final app = await _open(tester, '/admin/lessons/add', persona: LessonsDemoPersona.admin);
      await tester.enterText(find.byKey(const ValueKey('add-title-ar')), 'عنوان كافٍ');
      await _settle(tester);
      await _tap(tester, find.text('lessons.next'.tr()));
      // No preacher yet: still on the first step.
      expect(find.text('lessons.submit.title_ar_hint'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('preachers: add one with no account', (tester) async {
      final app = await _open(tester, '/admin/lessons/preachers',
          persona: LessonsDemoPersona.admin, size: _web);
      final before = app.repo.preachers.length;
      await _tap(tester, find.text('lessons.roster.add'.tr()));
      await tester.enterText(find.byKey(const ValueKey('preacher-name-ar')), 'الشيخ سعيد بن عمر');
      // His initial mosque is required.
      await _tap(tester, find.byKey(const ValueKey('preacher-save')));
      expect(find.text('lessons.preacher_admin.mosque_needed'.tr()), findsOneWidget);
      expect(app.repo.preachers.length, before);
      await _chooseMosque(tester, app, find.byKey(const ValueKey('preacher-home-mosque')), 'm1');
      await _tap(tester, find.byKey(const ValueKey('preacher-save')));
      expect(app.repo.preachers.length, before + 1);
      final p = app.repo.preachers.values.firstWhere((p) => p.nameAr == 'الشيخ سعيد بن عمر');
      expect(p.linkedProfileId, isNull);
      expect(p.homeMosqueId, 'm1');
      expect(find.text('lessons.roster.added'.tr()), findsOneWidget);
      await app.close();
    });

    for (final (lang, size) in [('en', _phone), ('ar', _web)]) {
      testWidgets("a preacher's phone is shown on request and logged ($lang ${size.width})",
          (tester) async {
        final app = await _open(tester, '/admin/lessons/preachers/p1',
            persona: LessonsDemoPersona.admin, lang: lang, size: size);
        final masked = maskPhone('0500000101');
        expect(find.text(masked), findsOneWidget);
        expect(find.text('0500000101'), findsNothing);
        await _tap(tester, find.text('lessons.roster.show_number'.tr()));
        expect(find.text('0500000101'), findsOneWidget);
        expect(find.text('lessons.roster.logged'.tr()), findsOneWidget);
        expect(app.repo.audit.first.action, 'phone');
        await app.close();
      });
    }

    for (final (lang, size, scale) in [
      ('en', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('en', _web, 1.0),
    ]) {
      testWidgets('links: a one-time link, a timed link, and revoking ($lang ${size.width} x$scale)',
          (tester) async {
        final app = await _open(tester, '/admin/lessons/preachers/p2',
            persona: LessonsDemoPersona.admin, lang: lang, size: size, scale: scale);
        expect(find.text('lessons.links.none_yet'.tr()), findsOneWidget);

        await _tap(tester, find.text('lessons.links.send'.tr()));
        expect(find.text('lessons.links.new_title'.tr()), findsOneWidget);
        await _tap(tester, _inModal(find.text('lessons.links.create'.tr())));
        expect(find.text('lessons.links.ready_title'.tr()), findsOneWidget);
        await _tap(tester, _inModal(find.text('lessons.roster.copy_msg'.tr())));
        final token = RegExp(r'/preacher/([a-z0-9]+)').firstMatch(clipboard ?? '')?.group(1);
        expect(token, isNotNull);
        expect(app.repo.links[token]!.kind, 'once');
        await _tap(tester, find.byTooltip('lessons.close'.tr()));
        expect(find.text('lessons.links.state_waiting'.tr()), findsOneWidget);

        await _tap(tester, find.text('lessons.links.send'.tr()));
        await _tap(tester, _inModal(find.text('lessons.links.window'.tr())));
        await _tap(tester, _inModal(find.text('lessons.links.create'.tr())));
        await _tap(tester, find.byTooltip('lessons.close'.tr()));
        expect(app.repo.links.values.where((k) => k.preacherId == 'p2' && k.kind == 'window'), hasLength(1));
        // It starts in an hour.
        expect(find.text('lessons.links.state_scheduled'.tr()), findsOneWidget);

        await _tap(tester, find.text('lessons.links.revoke'.tr()));
        expect(find.text('lessons.links.state_revoked'.tr()), findsOneWidget);
        expect(find.text('lessons.links.revoke'.tr()), findsOneWidget);
        await app.close();
      });
    }

    testWidgets('a preacher is removed with his lessons', (tester) async {
      final app = await _open(tester, '/admin/lessons/preachers/p11',
          persona: LessonsDemoPersona.admin, size: _web);
      await _tap(tester, find.text('lessons.preacher_admin.remove'.tr()));
      expect(find.text('lessons.preacher_admin.remove_title'.tr()), findsOneWidget);
      await _tap(tester, _inModal(find.text('lessons.preacher_admin.remove'.tr())));
      expect(app.repo.preachers.containsKey('p11'), isFalse);
      expect(app.repo.lessons.values.where((l) => l.preacherId == 'p11'), isEmpty);
      expect(app.at, '/admin/lessons/preachers');
      await app.close();
    });
  });

  // A preacher's page from his link: no account, no sign-in.
  group('preacher link', () {
    for (final (lang, size, scale) in [
      ('ar', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('en', _web, 1.0),
    ]) {
      testWidgets('he asks for a lesson and it waits for the admins ($lang ${size.width} x$scale)',
          (tester) async {
        final app = await _open(tester, '/preacher/${DemoLessonsRepository.fahdLink}',
            lang: lang, size: size, scale: scale);
        final p = app.repo.preachers['p1']!;
        expect(find.text('lessons.link.hello'.tr(args: [p.name(lang)])), findsOneWidget);
        expect(app.repo.links[DemoLessonsRepository.fahdLink]!.device, isNotNull);

        await _tap(tester, find.text('lessons.link.request'.tr()));
        const title = 'فضل العلم وأهله';
        await tester.enterText(find.byKey(const ValueKey('link-request-title')), title);
        await _tap(tester, find.byKey(const ValueKey('link-request-send')));
        expect(find.text('lessons.link.sent'.tr()), findsOneWidget);
        final sent = app.repo.lessons.values.where((l) => l.titleAr == title).single;
        expect(sent.status, 'pending');
        expect(sent.fromPreacher, isTrue);
        // Suggested at his first mosque unless he chooses another or none.
        expect(sent.mosqueId, p.homeMosqueId);
        expect(find.text(title), findsOneWidget);
        expect(find.text('lessons.link.mosque_later'.tr()), findsWidgets);
        await app.close();
      });
    }

    testWidgets('he suggests a card change; it waits for the admins', (tester) async {
      final app = await _open(tester, '/preacher/${DemoLessonsRepository.fahdLink}', lang: 'ar');
      await _tap(tester, find.text('lessons.link.edit_card'.tr()));
      await tester.enterText(_inModal(find.byType(TextField)).at(1), 'إمام وخطيب جامع الهدى');
      await _tap(tester, _inModal(find.text('lessons.link.send_edit'.tr())));
      expect(find.text('lessons.link.edit_sent'.tr()), findsOneWidget);
      expect(app.repo.edits.where((e) => e.preacherId == 'p1' && e.pending).single.changes['title_ar'], 'إمام وخطيب جامع الهدى');
      expect(app.repo.preachers['p1']!.titleAr, isNot('إمام وخطيب جامع الهدى'));
      expect(find.text('lessons.link.edit_waiting'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('he withdraws a request he sent', (tester) async {
      final app = await _open(tester, '/preacher/${DemoLessonsRepository.fahdLink}');
      final pending = app.repo.lessons.values.firstWhere((l) => l.preacherId == 'p1' && l.status == 'pending');
      await _tap(tester, find.text('lessons.link.withdraw'.tr()));
      expect(app.repo.lessons[pending.id]!.status, 'withdrawn');
      expect(find.text('lessons.link.withdrawn'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets('a one-time link does not open on a second phone', (tester) async {
      final app = await _open(tester, '/preacher/${DemoLessonsRepository.fahdLink}');
      expect(find.text('lessons.link.request'.tr()), findsOneWidget);
      await (await SharedPreferences.getInstance())
          .setString(PreacherLinkController.deviceKey, 'another-phone-0123456789abcdef');
      await app.go('/lessons');
      await app.go('/preacher/${DemoLessonsRepository.fahdLink}');
      expect(find.text('lessons.link.closed_used'.tr()), findsOneWidget);
      expect(find.text('lessons.link.request'.tr()), findsNothing);
      await app.close();
    });

    testWidgets('opening another link shows that link, not the last one', (tester) async {
      final app = await _open(tester, '/preacher/${DemoLessonsRepository.fahdLink}');
      expect(find.text('lessons.link.hello'.tr(args: [app.repo.preachers['p1']!.name('en')])), findsOneWidget);
      await app.go('/preacher/${DemoLessonsRepository.iqbalLink}');
      expect(find.text('lessons.link.hello'.tr(args: [app.repo.preachers['p4']!.name('en')])), findsOneWidget);
      await app.go('/preacher/not-a-link');
      expect(find.text('lessons.link.closed_revoked'.tr()), findsOneWidget);
      await app.close();
    });

    for (final token in ['demo-old', 'not-a-link']) {
      testWidgets('a revoked or unknown link says so ($token)', (tester) async {
        final app = await _open(tester, '/preacher/$token');
        expect(find.text('lessons.link.closed_revoked'.tr()), findsOneWidget);
        await app.close();
      });
    }
  });

  group('settings', () {
    /// Settings needs a signed-in account; the card is checked on its own,
    /// with the programme's routes stubbed.
    Future<(LessonsController, List<String>)> pumpCard(
        WidgetTester tester, LessonsDemoPersona persona, {void Function(DemoLessonsRepository repo)? setup}) async {
      final repo = DemoLessonsRepository(persona: persona);
      setup?.call(repo);
      final lessons = LessonsController(repo);
      addTearDown(lessons.dispose);
      final opened = <String>[];
      Widget page(GoRouterState state) {
        opened.add(state.uri.toString());
        return const Scaffold(body: Text('page'));
      }

      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
                body: SingleChildScrollView(child: LessonsSettingsCard()))),
        GoRoute(path: '/lessons/:rest(.*)', builder: (_, state) => page(state)),
        GoRoute(path: '/admin/lessons', builder: (_, state) => page(state)),
        GoRoute(path: '/preacher/:token', builder: (_, state) => page(state)),
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
      expect(find.text('lessons.admin.title'.tr()), findsNothing);
      expect(find.text('lessons.link.my_page'.tr()), findsNothing);
      expect(find.text('${lessons.mine.unread}'), findsOneWidget);
      await _tap(tester, find.text('lessons.me.reminders'.tr()));
      expect(opened.last, '/lessons/me/saved?tab=reminders');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a signed-in person can apply to give lessons, then sees it waiting', (tester) async {
      var (lessons, opened) = await pumpCard(tester, LessonsDemoPersona.viewer);
      expect(find.text('lessons.apply.settings_row'.tr()), findsOneWidget);
      expect(find.text('lessons.me.preacher_page'.tr()), findsNothing);
      await _tap(tester, find.text('lessons.apply.settings_row'.tr()));
      expect(opened.last, '/lessons/apply');
      await tester.pumpWidget(const SizedBox());

      (lessons, opened) = await pumpCard(tester, LessonsDemoPersona.viewer,
          setup: (repo) => repo.applications.add(PreacherApplication(
              id: 'mine', profileId: 'demo-viewer', nameAr: 'عبدالله السالم', city: 'khobar', mosqueId: 'm1',
              phone: '0500000300', email: 'abdullah@example.invalid', createdAt: DateTime.now())));
      expect(find.text('lessons.apply.settings_waiting'.tr()), findsOneWidget);
      expect(find.text('lessons.apply.settings_waiting_hint'.tr()), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets("a preacher with an account opens his page from Settings", (tester) async {
      final (_, opened) = await pumpCard(tester, LessonsDemoPersona.viewer,
          setup: (repo) => repo.preachers['p3'] = repo.preachers['p3']!.copyWith(linkedProfileId: 'demo-viewer'));
      expect(find.text('lessons.apply.settings_row'.tr()), findsNothing);
      await _tap(tester, find.text('lessons.me.preacher_page'.tr()));
      expect(opened.last, '/lessons/me/preacher');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an admin also gets Preachers & lessons, with what is waiting',
        (tester) async {
      final (lessons, opened) = await pumpCard(tester, LessonsDemoPersona.admin);
      expect(find.text('${lessons.waitingCount}'), findsOneWidget);
      await _tap(tester, find.text('lessons.admin.title'.tr()));
      expect(opened.last, '/admin/lessons');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a preacher whose link opened here gets his page back',
        (tester) async {
      SharedPreferences.setMockInitialValues({PreacherLinkController.lastLinkKey: DemoLessonsRepository.fahdLink});
      final (_, opened) = await pumpCard(tester, LessonsDemoPersona.guest);
      await _tap(tester, find.text('lessons.link.my_page'.tr()));
      expect(opened.last, '/preacher/${DemoLessonsRepository.fahdLink}');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('me', () {
    testWidgets('the sample persona switcher changes the view', (tester) async {
      final app = await _open(tester, '/lessons/me', signIn: true);
      expect(find.text('lessons.me.guest_title'.tr()), findsOneWidget);
      await _tap(tester, find.text('lessons.me.p_admin'.tr()));
      expect(app.lessons.canManage, isTrue);
      expect(find.text('lessons.me.console'.tr()), findsOneWidget);
      // Five requests and one card change waiting, one report from a user.
      expect(
          find.text('lessons.me.console_body'.tr(
              args: [_plural('requests', 6), _plural('reports', 1)])),
          findsOneWidget);
      await _tap(tester, find.text('lessons.me.open'.tr()));
      expect(app.at, '/admin/lessons');
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
  // Preachers invited by an admin or accepted after applying (ADR-020).
  group('preacher onboarding', () {
    Future<void> type(WidgetTester tester, Finder field, String text) async {
      await tester.ensureVisible(field);
      await _settle(tester);
      await tester.enterText(field, text);
      await _settle(tester);
    }

    testWidgets('the welcome page offers applying as a preacher', (tester) async {
      final app = await _open(tester, '/role-select', persona: LessonsDemoPersona.viewer, signIn: true, size: _web);
      expect(find.text('role_select.preacher_title'.tr()), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('role-select-preacher')));
      expect(app.at, '/lessons/apply');
      await app.close();
    });

    for (final (lang, size, scale) in [
      ('ar', _phone, 1.0),
      ('ar', _smallPhone, 2.0),
      ('en', _web, 1.0),
    ]) {
      testWidgets('a signed-in person applies with his city and mosque, then waits ($lang ${size.width} x$scale)',
          (tester) async {
        final app = await _open(tester, '/lessons/apply',
            persona: LessonsDemoPersona.viewer, signIn: true, lang: lang, size: size, scale: scale);
        expect(find.byKey(const ValueKey('apply-form')), findsOneWidget);
        await type(tester, find.byKey(const ValueKey('apply-name')), 'الشيخ عبدالله السالم');
        final picker = find.byKey(const ValueKey('apply-mosque'));
        await _chooseCity(tester, picker, 'dammam');
        await _chooseMosque(tester, app, picker, 'm7');
        await type(tester, find.byKey(const ValueKey('apply-phone')), '0500000300');
        await _tap(tester, find.byKey(const ValueKey('apply-send')));
        expect(find.text('lessons.apply.agree_needed'.tr()), findsOneWidget);
        expect(app.repo.applications.where((a) => a.profileId == 'demo-viewer'), isEmpty);
        // The warning floats over the button on a small phone; it goes first.
        tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first).hideCurrentSnackBar();
        await _settle(tester);

        await _tap(tester, find.byKey(const ValueKey('apply-agree')));
        await _tap(tester, find.byKey(const ValueKey('apply-send')));
        final mine = app.repo.applications.singleWhere((a) => a.profileId == 'demo-viewer');
        expect((mine.status, mine.city, mine.mosqueId, mine.email), ('pending', 'dammam', 'm7', 'admin@example.invalid'));
        expect(find.byKey(const ValueKey('apply-pending')), findsOneWidget);
        expect(app.repo.outbox.first.kind, 'application_received');

        await _tap(tester, find.text('lessons.apply.withdraw'.tr()));
        expect(app.repo.applications.singleWhere((a) => a.profileId == 'demo-viewer').status, 'withdrawn');
        expect(find.byKey(const ValueKey('apply-form')), findsOneWidget);
        await app.close();
      });
    }

    testWidgets('an applicant can name a mosque that is not listed, with its area', (tester) async {
      final app = await _open(tester, '/lessons/apply', persona: LessonsDemoPersona.viewer, signIn: true, size: _web);
      await type(tester, find.byKey(const ValueKey('apply-name')), 'الشيخ عبدالله السالم');
      await _tap(tester, find.byKey(const ValueKey('picker-not-listed')));
      await type(tester, find.byKey(const ValueKey('picker-new-mosque')), 'مسجد الرحمة');
      await _tap(tester, find.byKey(const ValueKey('picker-new-area-khobar')));
      await tester.tap(find.text(app.repo.districts['thuqbah']!.name('en')).last);
      await _settle(tester);
      await type(tester, find.byKey(const ValueKey('apply-phone')), '0500000300');
      await _tap(tester, find.byKey(const ValueKey('apply-agree')));
      await _tap(tester, find.byKey(const ValueKey('apply-send')));
      final mine = app.repo.applications.singleWhere((a) => a.profileId == 'demo-viewer');
      expect((mine.mosqueId, mine.newMosqueName, mine.newMosqueDistrict), (null, 'مسجد الرحمة', 'thuqbah'));
      await app.close();
    });

    testWidgets("the city picker offers only that city's mosques", (tester) async {
      final app = await _open(tester, '/admin/lessons/preachers', persona: LessonsDemoPersona.admin, size: _web);
      await _tap(tester, find.text('lessons.roster.add'.tr()));
      final picker = find.byKey(const ValueKey('preacher-home-mosque'));
      await _chooseCity(tester, picker, 'dammam');
      await _tap(tester, find.descendant(of: picker, matching: find.byType(DropdownButtonFormField<String>)).last);
      expect(find.textContaining(app.repo.mosques['m7']!.name('en')), findsWidgets);
      expect(find.textContaining(app.repo.mosques['m1']!.name('en')), findsNothing);
      await app.close();
    });

    testWidgets('an admin approves an application, then undoes it', (tester) async {
      final app = await _open(tester, '/admin/lessons/approvals', persona: LessonsDemoPersona.admin, size: _web);
      const id = DemoLessonsRepository.sampleApplication;
      expect(find.byKey(const ValueKey('application-$id')), findsOneWidget);
      expect(app.lessons.waitingCount, greaterThanOrEqualTo(1));
      await _tap(tester, find.byKey(const ValueKey('approve-application-$id')));
      await _tap(tester, find.byKey(const ValueKey('approve-application-confirm')));
      final p = app.repo.preachers.values.singleWhere((p) => p.linkedProfileId == 'demo-applicant');
      expect((p.homeMosqueId, p.joinedVia, p.city), ('m9', 'application', 'dammam'));
      expect(app.repo.emails[p.id], 'saad@example.invalid');
      expect(app.repo.outbox.first.kind, 'application_approved');
      expect(app.repo.outbox.first.status, 'queued');
      expect(app.repo.audit.first.action, 'applicationApproved');
      expect(find.byKey(const ValueKey('application-$id')), findsNothing);

      await _tap(tester, find.text('lessons.review.undo'.tr()));
      expect(app.repo.preachers.values.where((p) => p.linkedProfileId == 'demo-applicant'), isEmpty);
      expect(app.repo.applications.single.pending, isTrue);
      expect(app.repo.outbox.firstWhere((e) => e.kind == 'application_approved').status, 'cancelled');
      await app.close();
    });

    testWidgets('an admin declines an application with a reason, kept in the log', (tester) async {
      final app = await _open(tester, '/admin/lessons/approvals', persona: LessonsDemoPersona.admin, size: _phone);
      const id = DemoLessonsRepository.sampleApplication;
      await _tap(tester, find.byKey(const ValueKey('decline-application-$id')));
      await _tap(tester, find.byKey(const ValueKey('decline-application-confirm')));
      expect(find.text('lessons.applications.reason_needed'.tr()), findsOneWidget);
      await type(tester, find.byKey(const ValueKey('decline-application-reason')), 'نحتاج تزكية من المكتب');
      await _tap(tester, find.byKey(const ValueKey('decline-application-confirm')));
      final a = app.repo.applications.single;
      expect((a.status, a.reason), ('rejected', 'نحتاج تزكية من المكتب'));
      expect(app.repo.audit.first.note, 'نحتاج تزكية من المكتب');
      expect(app.repo.outbox.first.kind, 'application_rejected');
      await app.close();
    });

    testWidgets('approving adds the mosque an applicant named', (tester) async {
      final app = await _open(tester, '/admin/lessons/approvals', persona: LessonsDemoPersona.admin, size: _web,
          setup: (repo) => repo.applications
            ..clear()
            ..add(PreacherApplication(
                id: 'app-new', profileId: 'demo-applicant', nameAr: 'الشيخ سعد الغامدي', city: 'khobar',
                newMosqueName: 'مسجد الرحمة', newMosqueDistrict: 'thuqbah', phone: '0500000177',
                email: 'saad@example.invalid', createdAt: DateTime.now())));
      await _tap(tester, find.byKey(const ValueKey('approve-application-app-new')));
      expect(find.text('lessons.applications.use_named'.tr(args: ['مسجد الرحمة'])), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('approve-application-confirm')));
      final m = app.repo.mosques.values.singleWhere((m) => m.nameAr == 'مسجد الرحمة');
      expect(m.districtId, 'thuqbah');
      expect(app.repo.preachers.values.singleWhere((p) => p.linkedProfileId == 'demo-applicant').homeMosqueId, m.id);
      await app.close();
    });

    testWidgets('an admin adds a preacher with his email and invites him at once', (tester) async {
      final app = await _open(tester, '/admin/lessons/preachers', persona: LessonsDemoPersona.admin, size: _web);
      await _tap(tester, find.text('lessons.roster.add'.tr()));
      await type(tester, find.byKey(const ValueKey('preacher-name-ar')), 'الشيخ سعيد بن عمر');
      await type(tester, find.byKey(const ValueKey('preacher-email')), 'Saeed@Example.Invalid');
      await _chooseMosque(tester, app, find.byKey(const ValueKey('preacher-home-mosque')), 'm3');
      await _tap(tester, find.byKey(const ValueKey('preacher-invite')));
      await _tap(tester, find.byKey(const ValueKey('preacher-save')));
      final p = app.repo.preachers.values.singleWhere((p) => p.nameAr == 'الشيخ سعيد بن عمر');
      expect(app.repo.emails[p.id], 'saeed@example.invalid');
      expect(app.repo.links.values.where((k) => k.preacherId == p.id && k.kind == 'once'), hasLength(1));
      expect((app.repo.outbox.first.kind, app.repo.outbox.first.preacherId), ('invite', p.id));
      expect(app.repo.audit.first.action, 'invite');
      expect(find.text('lessons.roster.added_invited'.tr()), findsOneWidget);
      await app.close();
    });

    testWidgets("a preacher's page: masked email shown on request and logged, emails sent, history", (tester) async {
      final app = await _open(tester, '/admin/lessons/preachers/p1', persona: LessonsDemoPersona.admin, size: _web);
      expect(find.text(maskEmail('fahd@example.invalid')), findsOneWidget);
      await _tap(tester, find.text('lessons.roster.show_email'.tr()));
      expect(find.text('fahd@example.invalid'), findsOneWidget);
      expect((app.repo.audit.first.action, app.repo.audit.first.actorName, app.repo.audit.first.actorEmail),
          ('email', 'Khalid Al-Dosari', 'khalid@example.invalid'));
      expect(find.descendant(of: find.byKey(const ValueKey('preacher-emails')), matching: find.text('lessons.email_kind.invite'.tr())),
          findsOneWidget);
      expect(find.text('lessons.preacher_admin.history'.tr()), findsOneWidget);

      // A new link can go to his email too.
      await _tap(tester, find.text('lessons.links.send'.tr()));
      await _tap(tester, _inModal(find.text('lessons.links.create'.tr())));
      expect(find.text('lessons.links.emailed'.tr()), findsOneWidget);
      expect(app.repo.outbox.where((e) => e.kind == 'invite' && e.preacherId == 'p1'), hasLength(2));
      await app.close();
    });

    testWidgets('the log names who did what, with reasons; filters, search and emails', (tester) async {
      final app = await _open(tester, '/admin/lessons/log', persona: LessonsDemoPersona.admin, size: _web,
          setup: (repo) => repo.outbox.add(PreacherEmailEntry(
              id: 'em-stuck', kind: 'lesson_assigned', status: 'queued', preacherId: 'p4', to: maskEmail('iqbal@example.invalid'),
              createdAt: DateTime.now().subtract(const Duration(hours: 1)),
              sendAfter: DateTime.now().subtract(const Duration(hours: 1)))));
      expect(find.textContaining('Khalid Al-Dosari'), findsWidgets);
      expect(find.textContaining('khalid@example.invalid'), findsWidgets);
      expect(find.textContaining('تتعارض مع محاضرة الجمعية الكبرى'), findsOneWidget);

      await _tap(tester, find.text('lessons.auditlog.g_applications'.tr()));
      expect(find.byKey(const ValueKey('log-a0')), findsOneWidget);
      expect(find.byKey(const ValueKey('log-a1')), findsNothing);
      await _tap(tester, find.text('lessons.all'.tr()));
      await type(tester, find.descendant(of: find.byKey(const ValueKey('log-search')), matching: find.byType(TextField)), 'Youth');
      expect(find.byKey(const ValueKey('log-a2')), findsOneWidget);
      expect(find.byKey(const ValueKey('log-a1')), findsNothing);

      await _tap(tester, find.text('lessons.auditlog.emails'.tr()));
      expect(find.byKey(const ValueKey('email-em1')), findsOneWidget);
      expect(find.byKey(const ValueKey('emails-stuck')), findsOneWidget);
      await app.close();
    });

    testWidgets('a preacher with an account opens his page and asks for a lesson at another mosque', (tester) async {
      final app = await _open(tester, '/lessons/me/preacher', persona: LessonsDemoPersona.viewer, signIn: true, size: _phone,
          setup: (repo) => repo.preachers['p3'] = repo.preachers['p3']!.copyWith(linkedProfileId: 'demo-viewer'));
      final p = app.repo.preachers['p3']!;
      expect(find.text('lessons.link.hello'.tr(args: [p.name('en')])), findsOneWidget);
      expect(find.text('lessons.link.via_account'.tr()), findsOneWidget);
      await _tap(tester, find.text('lessons.link.request'.tr()));
      const title = 'شرح الأربعين النووية';
      await type(tester, find.byKey(const ValueKey('link-request-title')), title);
      final picker = find.byKey(const ValueKey('link-request-mosque'));
      await _chooseCity(tester, picker, 'dammam');
      await _chooseMosque(tester, app, picker, 'm7');
      await _tap(tester, find.byKey(const ValueKey('link-request-send')));
      final sent = app.repo.lessons.values.singleWhere((l) => l.titleAr == title);
      expect((sent.preacherId, sent.mosqueId, sent.status), ('p3', 'm7', 'pending'));
      expect((app.repo.audit.first.action, app.repo.audit.first.actorName), ('request', 'Abdullah Al-Salem'));
      await app.close();
    });

    testWidgets('an account without a card is shown how to apply', (tester) async {
      final app = await _open(tester, '/lessons/me/preacher', persona: LessonsDemoPersona.viewer, signIn: true);
      expect(find.text('lessons.link.closed_not_preacher'.tr()), findsOneWidget);
      await _tap(tester, find.text('lessons.apply.title'.tr()));
      expect(app.at, '/lessons/apply');
      await app.close();
    });

    testWidgets('a preacher may leave the mosque to the admins', (tester) async {
      final app = await _open(tester, '/preacher/${DemoLessonsRepository.fahdLink}');
      await _tap(tester, find.text('lessons.link.request'.tr()));
      const title = 'فضل العلم وأهله';
      await type(tester, find.byKey(const ValueKey('link-request-title')), title);
      final picker = find.byKey(const ValueKey('link-request-mosque'));
      await _tap(tester, find.descendant(of: picker, matching: find.byType(DropdownButtonFormField<String>)).last);
      await tester.tap(find.text('lessons.place.any'.tr()).last);
      await _settle(tester);
      await _tap(tester, find.byKey(const ValueKey('link-request-send')));
      expect(app.repo.lessons.values.singleWhere((l) => l.titleAr == title).hasMosque, isFalse);
      await app.close();
    });

    for (final (lang, size, scale) in [
      ('ar', _smallPhone, 2.0),
      ('en', _smallPhone, 1.0),
      ('ar', _web, 1.0),
    ]) {
      testWidgets('new pages fit ($lang ${size.width} x$scale)', (tester) async {
        final app = await _open(tester, '/lessons/apply',
            persona: LessonsDemoPersona.viewer, signIn: true, lang: lang, size: size, scale: scale,
            setup: (repo) => repo.preachers['p3'] = repo.preachers['p3']!.copyWith(linkedProfileId: 'demo-viewer'));
        expect(tester.takeException(), isNull);
        await app.go('/lessons/me/preacher');
        expect(tester.takeException(), isNull);
        await _tap(tester, find.text('lessons.link.request'.tr()));
        expect(tester.takeException(), isNull);
        await app.close();

        final admin = await _open(tester, '/admin/lessons/approvals',
            persona: LessonsDemoPersona.admin, lang: lang, size: size, scale: scale);
        expect(find.byKey(const ValueKey('application-${DemoLessonsRepository.sampleApplication}')), findsOneWidget);
        await _tap(tester, find.byKey(const ValueKey('approve-application-${DemoLessonsRepository.sampleApplication}')));
        expect(tester.takeException(), isNull);
        await admin.close();

        final log = await _open(tester, '/admin/lessons/log',
            persona: LessonsDemoPersona.admin, lang: lang, size: size, scale: scale);
        await _tap(tester, find.text('lessons.auditlog.emails'.tr()));
        expect(tester.takeException(), isNull);
        await log.close();

        final roster = await _open(tester, '/admin/lessons/preachers',
            persona: LessonsDemoPersona.admin, lang: lang, size: size, scale: scale);
        await _tap(tester, find.text('lessons.roster.add'.tr()));
        await _tap(tester, find.byKey(const ValueKey('picker-add-mosque')));
        expect(tester.takeException(), isNull);
        await roster.close();
      });
    }
  });

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
        (g, '/lessons/me/saved'),
        (g, '/preacher/${DemoLessonsRepository.fahdLink}'),
        (g, '/preacher/${DemoLessonsRepository.iqbalLink}'),
        (g, '/preacher/not-a-link'),
        (v, '/lessons/me'),
        (v, '/lessons/me/saved'),
        (v, '/lessons/me/saved?tab=log'),
        (v, '/lessons/me/saved?tab=mosques'),
        (v, '/lessons/me/notifications'),
        (v, '/lessons/lesson/${past.id}'),
        (a, '/lessons'),
        (a, '/lessons/me'),
        for (final t in lessonsAdminTabs) (a, '/admin/lessons/$t'),
        (a, '/admin/lessons/preachers/p1'),
        (a, '/admin/lessons/preachers/p4'),
        (a, '/admin/lessons/add'),
        (a, '/admin/lessons/add?from=${next.id}'),
        (a, '/admin/lessons/report/${past.id}'),
        (a, '/lessons/apply'),
        (a, '/lessons/me/preacher'),
        (a, '/lessons/lesson/${next.id}'),
        (a, '/lessons/preachers/p1'),
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
                  persona: persona, platformAdmin: true, lang: lang, size: size, scale: scale);
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
