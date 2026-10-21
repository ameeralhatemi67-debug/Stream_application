import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/config/app_identity.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/utils/text_direction.dart';
import 'package:streamer_app/core/widgets/app_logo.dart';
import 'package:streamer_app/core/widgets/ds/ca_feedback.dart';
import 'package:streamer_app/features/auth/presentation/role_select_screen.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/profile/models/vod_models.dart';
import 'package:streamer_app/features/profile/presentation/broadcaster_profile_screen.dart';
import 'package:streamer_app/features/profile/presentation/web/profile_web_parts.dart';
import 'package:streamer_app/features/splash/presentation/app_splash_screen.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

/// Engineering quick wins from the Hidayah Gold user-flow audit
/// (brief/audit/2026-10-21_USER_FLOW_AND_ATTENTION_AUDIT_HIDAYAH_GOLD.md).

/// The app's localization, with CLDR plural rules on as in main.dart.
Widget _localized(Widget child, {String lang = 'en', bool gold = false}) =>
    EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: Locale(lang),
        saveLocale: false,
        ignorePluralRules: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: Builder(
            builder: (context) => MaterialApp(
                theme: AppTheme.forLocale(context.locale, hidayah: gold),
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: true),
                    child: child!),
                home: child)));

Widget _localizedRouter(AppProvider provider, GoRouter router) =>
    EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: Builder(
                builder: (context) => MaterialApp.router(
                    routerConfig: router,
                    theme: AppTheme.forLocale(context.locale),
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    builder: (context, child) => TickerMode(
                        enabled: false,
                        child: MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(disableAnimations: true),
                            child: child!))))));

Future<void> _restored(AppProvider provider) async {
  for (var i = 0; i < 100 && !provider.localStateRestored; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(provider.localStateRestored, isTrue);
}

VodModel _vod(int i) => VodModel(
    vodId: 'vod-$i',
    streamerId: mockStreamers.first.streamerId,
    titleEn: 'Lesson $i',
    titleAr: 'درس $i',
    descriptionEn: '',
    descriptionAr: '',
    youtubeVideoId: 'video$i',
    durationSeconds: 600,
    recordedDate: '2026-10-0$i',
    thumbnailUrl: '',
    viewCount: 10);

class _GuestChat extends LiveChatController {
  _GuestChat() : super(streamId: 'stream_live_992');

  @override
  Future<void> start() async => debugSetStateForTests(
      currentUserId: null,
      chatEnabled: true,
      connectionState: ChatConnectionState.live);

  @override
  Future<void> sendMessage(String body) async {}

  @override
  Future<void> sendReaction(String type) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('first load weight', () {
    test('the bundled gold mark is display-sized, the master is not bundled',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('- assets/logo/clearlogo2.png')));
      expect(pubspec, contains('- ${AppLogo.hidayahAsset}'));
      for (final path in [
        AppLogo.hidayahAsset,
        'assets/logo/3.0x/hidayah_mark.png'
      ]) {
        final size = File(path).lengthSync();
        expect(size, lessThan(64 * 1024), reason: path);
        expect(size, greaterThan(16 * 1024), reason: '$path lost its detail');
      }
      // The master stays for the launcher-icon script.
      expect(File('assets/logo/clearlogo2.png').existsSync(), isTrue);
    });

    test('each font file is listed once (every entry is a download on web)',
        () {
      final assets = RegExp(r'^\s+- asset: (assets/fonts/\S+)$', multiLine: true)
          .allMatches(File('pubspec.yaml').readAsStringSync())
          .map((m) => m.group(1))
          .toList();
      expect(assets, isNotEmpty);
      expect(assets.toSet().length, assets.length);
    });
  });

  group('returning guest', () {
    test('consent, name, avatar and follows survive a new visit', () async {
      final first = AppProvider();
      await _restored(first);
      expect(first.isReturningGuest, isFalse);
      await first.recordConsent();
      await first.setupGuestViewer(
          name: ' Noura ', avatarUrl: 'assets/images/avatars/neutral_2.png');
      await first.toggleFollow('channel-1');
      first.dispose();

      final next = AppProvider();
      await _restored(next);
      expect(next.hasAcceptedCurrentConsent, isTrue);
      expect(next.isGuestViewer, isTrue);
      expect(next.isReturningGuest, isTrue);
      expect(next.guestViewerName, 'Noura');
      expect(next.guestViewerAvatar, 'assets/images/avatars/neutral_2.png');
      expect(next.isFollowing('channel-1'), isTrue);

      await next.toggleFollow('channel-1');
      next.dispose();
      final third = AppProvider();
      await _restored(third);
      expect(third.isFollowing('channel-1'), isFalse);
      third.dispose();
    });

    test('consent given before choosing is remembered on its own', () async {
      final first = AppProvider();
      await first.recordConsent();
      first.dispose();
      final next = AppProvider();
      await _restored(next);
      expect(next.hasAcceptedCurrentConsent, isTrue);
      // Consent alone is not a viewer profile: the gate still asks the rest.
      expect(next.isReturningGuest, isFalse);
      next.dispose();
    });

    test('signing out forgets the guest on this device', () async {
      final first = AppProvider();
      await first.setupGuestViewer(name: 'Noura');
      await first.logout();
      first.dispose();
      final next = AppProvider();
      await _restored(next);
      expect(next.isGuestViewer, isFalse);
      next.dispose();
    });

    testWidgets('the splash opens Discovery for a returning guest',
        (tester) async {
      Future<String> landing() async {
        final provider = AppProvider();
        final router = GoRouter(initialLocation: '/splash', routes: [
          GoRoute(
              path: '/splash',
              builder: (context, state) => const AppSplashScreen()),
          GoRoute(
              path: '/feed',
              builder: (context, state) => const Text('feed-page')),
          GoRoute(
              path: '/welcome',
              builder: (context, state) => const Text('welcome-page')),
        ]);
        await tester.pumpWidget(_localizedRouter(provider, router));
        await tester.runAsync(() => _restored(provider));
        for (var i = 0;
            i < 20 &&
                router.routeInformationProvider.value.uri.path == '/splash';
            i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        final at = router.routeInformationProvider.value.uri.path;
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        provider.dispose();
        return at;
      }

      expect(await landing(), '/welcome');
      final guest = AppProvider();
      await tester.runAsync(() async {
        await guest.recordConsent();
        await guest.setupGuestViewer(name: 'Noura');
      });
      guest.dispose();
      expect(await landing(), '/feed');
    });

    testWidgets('a returning guest on the welcome screen is not asked again',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = AppProvider();
      await tester.runAsync(() async {
        await provider.recordConsent();
        await provider.setupGuestViewer(name: 'Noura');
      });
      // Reached from a login-only link, e.g. Organizations in the header.
      final router = GoRouter(initialLocation: '/welcome', routes: [
        GoRoute(
            path: '/welcome',
            builder: (context, state) => const WelcomeScreen()),
        GoRoute(
            path: '/feed', builder: (context, state) => const Text('feed-page')),
        GoRoute(
            path: '/viewer-setup',
            builder: (context, state) => const Text('name-form')),
      ]);
      await tester.pumpWidget(_localizedRouter(provider, router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('auth_welcome.btn_guest'.tr()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(router.routeInformationProvider.value.uri.path, '/feed');
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      provider.dispose();
    });
  });

  group('sign-in returns to where it was asked for', () {
    test('only in-app pages outside the sign-in flow are kept, once',
        () async {
      final provider = AppProvider();
      await provider.rememberSignInReturn('/live/abc');
      expect(provider.takeSignInReturn(), '/live/abc');
      expect(provider.takeSignInReturn(), isNull);
      for (final unsafe in [
        '/welcome',
        '/login-callback?code=1',
        '//evil.example/live',
        'https://evil.example/live',
        'live/abc',
      ]) {
        await provider.rememberSignInReturn(unsafe);
        expect(provider.takeSignInReturn(), isNull, reason: unsafe);
      }
      provider.dispose();
    });

    test('the return survives the web sign-in reload', () async {
      final first = AppProvider();
      await first.rememberSignInReturn('/profile/abc?tab=upcoming');
      first.dispose();
      final next = AppProvider();
      await _restored(next);
      expect(next.takeSignInReturn(), '/profile/abc?tab=upcoming');
      next.dispose();
    });

    testWidgets('finishing sign-in opens the page that asked, not Discovery',
        (tester) async {
      final provider = AppProvider();
      provider.debugSetSignedInForTests(
          email: 'viewer@example.invalid', isStreamer: false);
      await tester.runAsync(() => provider.rememberSignInReturn('/profile/abc'));
      final router = AppRouter.build(provider);
      router.go('/welcome');
      await tester.pumpWidget(_localizedRouter(provider, router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(router.routeInformationProvider.value.uri.toString(),
          '/profile/abc');
      expect(find.byType(BroadcasterProfileScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      provider.dispose();
    });

    testWidgets('the native OAuth callback also returns to the page',
        (tester) async {
      final provider = AppProvider();
      provider.debugSetSignedInForTests(
          email: 'viewer@example.invalid', isStreamer: false);
      await tester.runAsync(() => provider.rememberSignInReturn('/profile/abc'));
      final router = AppRouter.build(provider);
      router.go('/login-callback?code=abc');
      await tester.pumpWidget(_localizedRouter(provider, router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(router.routeInformationProvider.value.uri.toString(),
          '/profile/abc');
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      provider.dispose();
    });

    testWidgets('a new account picks a role, then lands on the page that asked',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = AppProvider();
      await tester.runAsync(
          () => provider.rememberSignInReturn('/live/stream_live_992'));
      final router = GoRouter(initialLocation: '/role-select', routes: [
        GoRoute(
            path: '/role-select',
            builder: (context, state) => const RoleSelectScreen()),
        GoRoute(
            path: '/feed', builder: (context, state) => const Text('feed-page')),
        GoRoute(
            path: '/live/:id',
            builder: (context, state) => const Text('live-page')),
      ]);
      await tester.pumpWidget(_localizedRouter(provider, router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('role_select.viewer_btn'.tr()).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(router.routeInformationProvider.value.uri.path,
          '/live/stream_live_992');
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      provider.dispose();
    });

    testWidgets('a shared channel link opens for a guest without the gate',
        (tester) async {
      final provider = AppProvider();
      final router = AppRouter.build(provider);
      router.go('/profile/abc?tab=upcoming');
      await tester.pumpWidget(_localizedRouter(provider, router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(router.routeInformationProvider.value.uri.toString(),
          '/profile/abc?tab=upcoming');
      expect(find.byType(BroadcasterProfileScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      provider.dispose();
    });

    testWidgets(
        'live chat Sign in keeps the live page, shows its address and '
        'remembers it', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      StubVideoPlayer.install(addTearDown: addTearDown);
      LiveBroadcastScreen.debugChatFactory = (id, provider) => _GuestChat();
      addTearDown(() => LiveBroadcastScreen.debugChatFactory = null);
      final provider = AppProvider();
      provider.addStreamerForTests(mockStreamers.first.copyWith(
          avatarUrl: '',
          bannerUrl: '',
          isCurrentlyLive: true,
          broadcastType: BroadcastType.liveVideo,
          activeStreamId: 'stream_live_992'));
      AppRouter.build(provider).dispose();
      expect(GoRouter.optionURLReflectsImperativeAPIs, isTrue);
      // Opened straight from a shared live link.
      final router =
          GoRouter(initialLocation: '/live/stream_live_992', routes: [
        GoRoute(
            path: '/live/:id',
            builder: (context, state) =>
                LiveBroadcastScreen(streamId: state.pathParameters['id']!)),
        GoRoute(
            path: '/welcome',
            builder: (context, state) =>
                const Scaffold(body: Text('welcome-page'))),
      ]);
      await tester.pumpWidget(_localizedRouter(provider, router));
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));

      await tester.tap(find.text('live.chat_composer_guest_action'.tr()));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(find.text('welcome-page', skipOffstage: false), findsOneWidget);
      // Pushed, so the address is the sign-in page's own (it used to keep the
      // page below) and Back returns to the live page, which stays mounted.
      expect(router.routeInformationProvider.value.uri.path, '/welcome');
      expect(router.canPop(), isTrue);
      expect(find.byType(LiveBroadcastScreen, skipOffstage: false),
          findsOneWidget);
      expect(provider.takeSignInReturn(), '/live/stream_live_992');

      router.pop();
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path,
          '/live/stream_live_992');
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      provider.dispose();
    });
  });

  group('channel page counts', () {
    for (final lang in ['en', 'ar']) {
      testWidgets('a dash, never 0, until the archive has loaded ($lang)',
          (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = AppProvider();
        for (final s in mockStreamers) {
          provider.addStreamerForTests(
              s.copyWith(avatarUrl: '', bannerUrl: '', youtubeHandle: '@x'));
        }
        final id = mockStreamers.first.streamerId;
        await tester.pumpWidget(_localized(
            ChangeNotifierProvider<AppProvider>.value(
                value: provider, child: BroadcasterProfileScreen(streamerId: id)),
            lang: lang,
            gold: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final hero = find.byType(ProfileWebHero);
        expect(hero, findsOneWidget);
        expect(provider.isChannelArchiveKnown(id), isFalse);
        expect(find.descendant(of: hero, matching: find.text('\u2014')),
            findsNWidgets(2));
        expect(find.descendant(of: hero, matching: find.text('0')),
            findsNothing);

        provider.setStreamerMediaForTests(id,
            vods: [_vod(1), _vod(2), _vod(3)], playlists: const []);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.descendant(of: hero, matching: find.text('\u2014')),
            findsNothing);
        expect(find.descendant(of: hero, matching: find.text('3')),
            findsOneWidget);
        expect(
            find.descendant(
                of: hero,
                matching: find.text(lang == 'ar' ? 'تسجيلات' : 'recordings')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      });
    }

    test('a channel without a YouTube handle has a known, empty archive',
        () async {
      final provider = AppProvider();
      await provider.loadYouTubeChannelData(streamerId: 'none', handle: ' ');
      expect(provider.isChannelArchiveKnown('none'), isTrue);
      provider.dispose();
    });
  });

  group('Arabic plural forms', () {
    Map<String, dynamic> catalog(String lang) =>
        jsonDecode(File('assets/i18n/$lang.json').readAsStringSync());

    test('every plural entry has all six forms in both languages', () {
      const forms = {'zero', 'one', 'two', 'few', 'many', 'other'};
      var found = 0;
      void walk(Map<String, dynamic> en, Map<String, dynamic> ar, String at) {
        for (final key in en.keys) {
          final e = en[key], a = ar[key];
          if (e is Map<String, dynamic> && e.keys.toSet().containsAll(forms)) {
            found++;
            expect(e.keys.toSet(), forms, reason: '$at$key (en)');
            expect((a as Map).keys.toSet(), forms, reason: '$at$key (ar)');
          } else if (e is Map<String, dynamic>) {
            walk(e, a as Map<String, dynamic>, '$at$key.');
          }
        }
      }

      walk(catalog('en'), catalog('ar'), '');
      expect(found, greaterThanOrEqualTo(14));
    });

    test('the app turns on CLDR plural rules', () {
      // easy_localization's default maps every count above 2 to "other",
      // which never reaches Arabic's few (3-10) and many (11-99) forms.
      expect(File('lib/main.dart').readAsStringSync(),
          contains('ignorePluralRules: false'));
    });

    testWidgets('counts agree with their noun in Arabic and English',
        (tester) async {
      late Map<String, String> ar, en;
      Map<String, String> read() => {
            'map0': 'web.map_count'.plural(0),
            'map1': 'web.map_count'.plural(1),
            'map2': 'web.map_count'.plural(2),
            'map5': 'web.map_count'.plural(5),
            'map11': 'web.map_count'.plural(11),
            'map100': 'web.map_count'.plural(100),
            'rec3': 'web.stat_recordings'.plural(3),
            'rec25': 'web.stat_recordings'.plural(25),
            'channels5': 'web.stat_channels'.plural(5),
            'venues4': 'map.cluster_list_title'.plural(4, name: 'count'),
            'files': 'map.web_offline_preparing'
                .plural(12, name: 'total', namedArgs: {'done': '3'}),
            'wait5': 'live.chat_composer_slow_mode'.plural(5),
            'lectures7': 'profile.lectures_count'.plural(7),
          };
      for (final lang in ['ar', 'en']) {
        await tester.pumpWidget(_localized(
            Builder(builder: (context) {
              if (lang == 'ar') {
                ar = read();
              } else {
                en = read();
              }
              return const SizedBox();
            }),
            lang: lang));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
      expect(ar['map0'], 'لا قنوات على الخريطة');
      expect(ar['map1'], 'قناة واحدة على الخريطة');
      expect(ar['map2'], 'قناتان على الخريطة');
      expect(ar['map5'], '5 قنوات على الخريطة');
      expect(ar['map11'], '11 قناة على الخريطة');
      expect(ar['map100'], '100 قناة على الخريطة');
      expect(ar['rec3'], 'تسجيلات');
      expect(ar['rec25'], 'تسجيلًا');
      expect(ar['channels5'], 'محاضرين وقنوات');
      expect(ar['venues4'], '4 أماكن هنا');
      expect(ar['files'], 'جارٍ الحفظ… 3 من 12 ملفًا');
      expect(ar['wait5'], 'الوضع البطيء: انتظر 5 ثوانٍ');
      expect(ar['lectures7'], '7 محاضرات');
      expect(en['map1'], '1 channel on the map');
      expect(en['map5'], '5 channels on the map');
      expect(en['rec3'], 'recordings');
      expect(en['files'], 'Saving… 3 of 12 files');
      expect(en['wait5'], 'Slow mode: wait 5s');
    });
  });

  test('snackbars name their font so Arabic never waits for a download', () {
    for (final (lang, gold, family) in [
      ('ar', false, 'IBM Plex Sans Arabic'),
      ('en', true, 'IBM Plex Sans Arabic'),
      ('en', false, 'IBM Plex Sans'),
    ]) {
      final style =
          AppTheme.forLocale(Locale(lang), hidayah: gold).snackBarTheme
              .contentTextStyle!;
      expect(style.fontFamily, family, reason: '$lang gold=$gold');
      expect(style.fontFamilyFallback,
          containsAll(['IBM Plex Sans Arabic', 'IBM Plex Sans']));
      expect(style.color, isNotNull);
    }
  });

  group('web entry page', () {
    final html = File('web/index.html').readAsStringSync();
    String meta(String attribute, String name) =>
        RegExp('<meta $attribute="${RegExp.escape(name)}" content="([^"]*)">')
                .firstMatch(html)
                ?.group(1) ??
            '';
    final arabic = RegExp(r'[\u0600-\u06FF]');

    test('link previews and the description carry Arabic and English', () {
      for (final tag in ['og:title', 'og:description', 'og:site_name']) {
        expect(meta('property', tag), contains(arabic), reason: tag);
        expect(meta('property', tag), contains(RegExp('[A-Za-z]')),
            reason: tag);
      }
      expect(meta('name', 'description'), contains(arabic));
      expect(meta('property', 'og:locale'), 'ar_SA');
      // og:image must be absolute and on the app's own origin.
      expect(meta('property', 'og:image'),
          startsWith('${AppIdentity.websiteUrl}/'));
      expect(
          File('web/${meta('property', 'og:image').substring(AppIdentity.websiteUrl.length + 1)}')
              .existsSync(),
          isTrue);
    });

    test('the boot splash is neutral, not the green brand colour', () {
      final style = RegExp(r'<style>([\s\S]*?)</style>').firstMatch(html)!.group(1)!;
      expect(style.toUpperCase(), isNot(contains('#17643F')));
    });
  });

  group('chat message direction', () {
    test('follows the first strong letter', () {
      expect(firstStrongTextDirection('Could you repeat that?'),
          TextDirection.ltr);
      expect(firstStrongTextDirection('هل يمكنك الإعادة؟'), TextDirection.rtl);
      expect(firstStrongTextDirection('12 - Allah أكبر'), TextDirection.ltr);
      expect(firstStrongTextDirection('؟ 12 شكراً'), TextDirection.rtl);
      expect(firstStrongTextDirection('123 🙂'), isNull);
      // Emoji are not letters: a smiley first must not flip Arabic text.
      expect(firstStrongTextDirection('🙂 شكراً'), TextDirection.rtl);
      expect(firstStrongTextDirection('🙂 thanks'), TextDirection.ltr);
    });

    testWidgets('an English message reads left to right in the Arabic app',
        (tester) async {
      Future<RichText> bubble(String message) async {
        await tester.pumpWidget(_localized(
            Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                    body: CaChatBubble(
                        name: 'نورة', message: message, time: '10:00'))),
            lang: 'ar'));
        await tester.pump();
        return tester.widget<RichText>(find.byWidgetPredicate((w) =>
            w is RichText && w.text.toPlainText().contains(message)));
      }

      final english = await bubble('Could you repeat that?');
      expect(english.textDirection, TextDirection.ltr);
      // The Arabic name is isolated so it cannot pull the "?" around.
      expect(english.text.toPlainText(), contains('\u2068نورة\u2069'));

      final arabic = await bubble('هل يمكنك الإعادة؟');
      expect(arabic.textDirection, TextDirection.rtl);
      expect(arabic.text.toPlainText(), isNot(contains('\u2068')));
      expect(tester.takeException(), isNull);
    });
  });
}
