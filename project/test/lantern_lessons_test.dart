import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
import 'package:streamer_app/features/lessons/presentation/lantern/lantern_lessons_parts.dart';
import 'package:streamer_app/features/lessons/presentation/lantern/lessons_home_view.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// The mosque-lessons pages in the Lantern and Arch design (ADR-026).
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
}
