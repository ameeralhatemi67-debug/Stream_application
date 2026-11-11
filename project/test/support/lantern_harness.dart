import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import '../fixtures/streamer_fixtures.dart';
import 'localized_app.dart';

/// Shared set-up for tests of the Lantern and Arch design (ADR-026).
///
/// [pumpLanternWidget] shows one widget under the Lantern theme;
/// [LanternApp] runs the whole app through its own router in any skin.

/// Loads the real fonts, so text is measured as on a device. Call once in
/// `setUpAll` for tests that check sizes or take pictures.
Future<void> loadAppFonts() async {
  for (final pair in [
    ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-400.ttf'),
    ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-700.ttf'),
    ('Reem Kufi', 'assets/fonts/ReemKufi-Variable.ttf'),
    ('Readex Pro', 'assets/fonts/ReadexPro-Variable.ttf'),
    ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
  ]) {
    await (FontLoader(pair.$1)..addFont(rootBundle.load(pair.$2))).load();
  }
}

/// A provider with the sample channels; the first one is live.
AppProvider lanternProvider(
    {AppSkin skin = AppSkin.lantern,
    LanternAppearance appearance = LanternAppearance.day,
    bool audio = false,
    bool live = true,
    String liveId = 'stream-lantern-1'}) {
  final provider = AppProvider()..restoreAppSkin(skin, appearance: appearance);
  for (final (i, s) in mockStreamers.indexed) {
    provider.addStreamerForTests(!live
        // Nothing is live: the sample channels that are live by default
        // are switched off too.
        ? s.copyWith(isCurrentlyLive: false)
        : i == 0
            ? s.copyWith(
                isCurrentlyLive: true,
                broadcastType:
                    audio ? BroadcastType.liveAudio : BroadcastType.liveVideo,
                activeStreamId: liveId)
            : s);
  }
  return provider;
}

/// One widget under the Lantern theme, with localization and a provider.
Future<AppProvider> pumpLanternWidget(WidgetTester tester, Widget child,
    {String lang = 'en',
    bool night = false,
    Size size = const Size(390, 844),
    AppProvider? provider,
    bool calm = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = provider ??
      lanternProvider(
          appearance: night ? LanternAppearance.night : LanternAppearance.day);
  addTearDown(app.dispose);
  await tester.pumpWidget(EasyLocalization(
      key: UniqueKey(),
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: Builder(
              builder: (context) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: LanternSkin.theme(context.locale, night: night),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: calm),
                      child: child!),
                  home: Scaffold(body: child))))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return app;
}

/// The whole app through its own router, in any of the three designs.
class LanternApp {
  LanternApp._(this.tester, this.provider, this.lessons, this.router);

  final WidgetTester tester;
  final AppProvider provider;
  final LessonsController lessons;
  final GoRouter router;

  static Future<LanternApp> start(WidgetTester tester,
      {AppSkin skin = AppSkin.lantern,
      String lang = 'en',
      Size size = const Size(390, 844),
      String location = '/feed',
      AppProvider? provider,
      LessonsDemoPersona persona = LessonsDemoPersona.guest,
      bool calm = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final app = provider ?? lanternProvider(skin: skin);
    final lessons = LessonsController(DemoLessonsRepository(persona: persona));
    final router = AppRouter.build(app)..go(location);
    await tester.pumpWidget(EasyLocalization(
        key: UniqueKey(),
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
            child: Builder(builder: (context) {
              final skin =
                  context.select<AppProvider, AppSkin>((p) => p.appSkin);
              return MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                  theme: AppTheme.forLocale(context.locale, skin: skin),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: calm),
                      child: child!));
            }))));
    final it = LanternApp._(tester, app, lessons, router);
    await it.settle();
    return it;
  }

  /// The page on top, whether it was reached with go or push.
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  /// A few frames, without waiting for endless animations to finish.
  Future<void> settle([int frames = 8]) async {
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

  /// Takes the app down and lets its timers end.
  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    provider.dispose();
    tester.view.reset();
  }
}
