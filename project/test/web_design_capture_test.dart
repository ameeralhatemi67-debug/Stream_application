import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/app_logo.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/presentation/web/live_web_parts.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_audio_stage_multi_speaker.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/profile/presentation/broadcaster_profile_screen.dart';
import 'package:streamer_app/features/web/presentation/hidayah_web_header.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';

/// Design review screenshots of the Hidayah Gold website layouts, written to
/// WEB_CAPTURE_DIR with the real fonts. Skipped when the variable is unset.
final _dir = Platform.environment['WEB_CAPTURE_DIR'];

AppProvider _provider() {
  final provider = AppProvider();
  for (final (i, s) in mockStreamers.indexed) {
    provider.addStreamerForTests(i == 0
        ? s.copyWith(
            isCurrentlyLive: true,
            broadcastType: BroadcastType.liveVideo,
            activeStreamId: 'stream-web-1')
        : i == 2
            ? s.copyWith(
                isCurrentlyLive: true,
                broadcastType: BroadcastType.liveAudio,
                activeStreamId: 'stream-web-2')
            : s);
  }
  return provider;
}

Future<void> _shot(WidgetTester tester, String name, Widget screen,
    {required Size size,
    bool gold = true,
    String lang = 'en',
    AppProvider? provider}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final p = provider ?? _provider();
  await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: Builder(
          builder: (context) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.forLocale(context.locale, hidayah: gold),
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: child!),
              home: ChangeNotifierProvider<AppProvider>.value(
                  value: p,
                  child: RepaintBoundary(
                      key: const ValueKey('capture'), child: screen))))));
  await tester.pump();
  final context = tester.element(find.byKey(const ValueKey('capture')));
  await tester.runAsync(() async {
    for (final s in mockStreamers) {
      for (final path in [s.avatarUrl, s.bannerUrl]) {
        if (path.startsWith('assets/')) {
          await precacheImage(AssetImage(path), context);
        }
      }
    }
    await precacheImage(const AssetImage(AppLogo.hidayahAsset), context);
  });
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

Widget _shell(HidayahWebSection section, Widget child) => Scaffold(
    body: Column(children: [
  HidayahWebHeader(active: section),
  Expanded(child: child),
]));

/// Stand-in for the video player and chat, which need a live backend.
Widget _fakePlayer(String asset) => Stack(fit: StackFit.expand, children: [
      Image.asset(asset, fit: BoxFit.cover),
      const ColoredBox(color: Color(0x33000000)),
    ]);

Widget _fakeChat() => ColoredBox(
    color: HidayahGold.s950,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      for (final (who, text) in [
        ('Faisal', 'السلام عليكم، جزاكم الله خيراً'),
        ('Noura', 'Could you repeat the second condition?'),
        ('Majed', 'ما شاء الله، درس نافع'),
        ('Reem', 'Is there a recording afterwards?'),
      ])
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                  radius: 14,
                  backgroundColor: HidayahGold.s800,
                  child: Text(who[0],
                      style: const TextStyle(color: HidayahGold.g200))),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('$who  $text',
                      style: const TextStyle(color: HidayahGold.s100))),
            ])),
    ]));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    for (final pair in [
      ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-400.ttf'),
      ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-700.ttf'),
      ('IBM Plex Sans', 'assets/fonts/IBMPlexSans-Variable.ttf'),
      ('Reem Kufi', 'assets/fonts/ReemKufi-Variable.ttf'),
    ]) {
      await (FontLoader(pair.$1)..addFont(rootBundle.load(pair.$2))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final skip = _dir == null;

  for (final lang in ['en', 'ar']) {
    testWidgets('capture discovery $lang', skip: skip, (tester) async {
      await _shot(tester, 'web-discovery-$lang',
          _shell(HidayahWebSection.discover, const DiscoveryFeedScreen()),
          size: const Size(1440, 2300), lang: lang);
    });
    testWidgets('capture profile $lang', skip: skip, (tester) async {
      await _shot(
          tester,
          'web-profile-$lang',
          BroadcasterProfileScreen(streamerId: mockStreamers[1].streamerId),
          size: const Size(1440, 1000),
          lang: lang);
    });
  }
  testWidgets('capture map', skip: skip, (tester) async {
    await _shot(tester, 'web-map-en',
        _shell(HidayahWebSection.map, const SpatialMapScreen()),
        size: const Size(1440, 900));
  });
  testWidgets('capture live video', skip: skip, (tester) async {
    final s = _provider().streamers.first;
    await _shot(
        tester,
        'web-live-video-en',
        HidayahWebPage(
            dark: true,
            body: LiveWebLayout(
                streamer: s,
                viewport: _fakePlayer(s.bannerUrl),
                panel: _fakeChat(),
                viewerCount: 214,
                following: false,
                onFollow: () {},
                onMinimize: () {})),
        size: const Size(1440, 900));
  });
  testWidgets('capture live audio', skip: skip, (tester) async {
    final s = _provider().streamers[2];
    await _shot(
        tester,
        'web-live-audio-ar',
        HidayahWebPage(
            dark: true,
            body: Builder(
                builder: (context) => LiveWebLayout(
                    streamer: s,
                    viewport: LiveAudioStageMultiSpeaker(
                        streamer: s,
                        langCode: context.locale.languageCode,
                        viewerCount: 41,
                        isPlaying: true,
                        streamState: StreamState.live),
                    panel: _fakeChat(),
                    viewerCount: 41,
                    following: true,
                    onFollow: () {},
                    onMinimize: () {}))),
        size: const Size(1440, 900),
        lang: 'ar');
  });
  testWidgets('capture studio', skip: skip, (tester) async {
    await _shot(tester, 'web-studio-en',
        const LiveBroadcasterStudioSheet(initialMode: StudioMode.obs),
        size: const Size(1440, 900));
  });
  testWidgets('capture green discovery for comparison', skip: skip,
      (tester) async {
    await _shot(tester, 'green-discovery-en', const DiscoveryFeedScreen(),
        size: const Size(1440, 900), gold: false);
  });
  for (final lang in ['en', 'ar']) {
    testWidgets('capture phone gold $lang', skip: skip, (tester) async {
      await _shot(tester, 'phone-discovery-$lang', const DiscoveryFeedScreen(),
          size: const Size(390, 844), lang: lang);
      await _shot(
          tester,
          'phone-profile-$lang',
          BroadcasterProfileScreen(streamerId: mockStreamers[1].streamerId),
          size: const Size(390, 844),
          lang: lang);
    });
  }
}
