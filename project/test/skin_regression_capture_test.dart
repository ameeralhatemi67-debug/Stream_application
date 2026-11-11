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
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/app_logo.dart';
import 'package:streamer_app/core/widgets/hedayah/hedayah_kit.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

/// Pictures of the two existing designs, gold & black and Hedayah, for a
/// before and after comparison: run once on `master` and once on a branch
/// with the same SKIN_REGRESSION_DIR sub-folders, then compare the files
/// (brief/tools/compare_skin_captures.py). The two designs must not change
/// when a third one is added.
///
/// Rendered by the test engine with the real fonts, through the app's own
/// router where a route exists. Skipped when SKIN_REGRESSION_DIR is unset.
final _dir = Platform.environment['SKIN_REGRESSION_DIR'];

const _liveId = 'stream-regression-1';

enum _Who { guest, viewer, streamer, admin }

AppProvider _provider(AppSkin skin, _Who who, {bool audio = false}) {
  final provider = AppProvider()..restoreAppSkin(skin);
  for (final (i, s) in mockStreamers.indexed) {
    provider.addStreamerForTests(i == 0
        ? s.copyWith(
            isCurrentlyLive: true,
            broadcastType:
                audio ? BroadcastType.liveAudio : BroadcastType.liveVideo,
            activeStreamId: _liveId)
        : s);
  }
  switch (who) {
    case _Who.guest:
      break;
    case _Who.viewer:
      provider.debugSetSignedInForTests(
          email: 'viewer@example.invalid', name: 'Viewer', isStreamer: false);
    case _Who.streamer:
      provider.debugSetSignedInForTests(
          email: 'streamer@example.invalid',
          name: 'Streamer',
          ownedStreamerId: mockStreamers.first.streamerId);
    case _Who.admin:
      provider.debugSetSignedInForTests(
          email: 'admin@example.invalid',
          name: 'Admin',
          isMasterAdmin: true,
          isLessonsAdmin: true,
          isStreamer: false);
  }
  return provider;
}

Future<void> _shot(WidgetTester tester, String name,
    {required AppSkin skin,
    required Size size,
    String? location,
    Widget? screen,
    String lang = 'ar',
    _Who who = _Who.guest,
    bool audio = false,
    int frames = 8}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final provider = _provider(skin, who, audio: audio);
  final lessons = LessonsController(DemoLessonsRepository(
      persona: who == _Who.admin
          ? LessonsDemoPersona.admin
          : LessonsDemoPersona.guest));
  final router = AppRouter.build(provider);
  if (location != null) router.go(location);
  Widget frame(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: RepaintBoundary(key: const ValueKey('capture'), child: child!));
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
              builder: (context) => screen != null
                  ? MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: AppTheme.forLocale(context.locale, skin: skin),
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: frame,
                      home: screen)
                  : MaterialApp.router(
                      debugShowCheckedModeBanner: false,
                      routerConfig: router,
                      theme: AppTheme.forLocale(context.locale, skin: skin),
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: frame)))));
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
    await precacheImage(const AssetImage(HedayahWordmark.asset), context);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  // A layout error is part of the picture, not a reason to stop the run.
  tester.takeException();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  await tester.pumpWidget(const SizedBox.shrink());
  // Let the splash's timer and the router settle before the next capture.
  await tester.pump(const Duration(seconds: 3));
  tester.takeException();
  provider.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    for (final pair in [
      ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-400.ttf'),
      ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-700.ttf'),
      ('Reem Kufi', 'assets/fonts/ReemKufi-Variable.ttf'),
      ('Readex Pro', 'assets/fonts/ReadexPro-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(pair.$1)..addFont(rootBundle.load(pair.$2))).load();
    }
    if (_dir != null) Directory(_dir!).createSync(recursive: true);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final skip = _dir == null;
  const phone = Size(390, 844), laptop = Size(1440, 900);
  const tallPhone = Size(390, 1600), tallLaptop = Size(1440, 1600);

  // The two existing designs, named one by one: a design added later must
  // not join this list.
  for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
    final tag = skin.id;
    testWidgets('capture $tag: entry and Discover', skip: skip, (tester) async {
      await _shot(tester, '01-splash-$tag',
          skin: skin, size: phone, location: '/splash', frames: 3);
      await _shot(tester, '02-welcome-$tag',
          skin: skin, size: phone, location: '/welcome');
      await _shot(tester, '03-discover-phone-ar-$tag',
          skin: skin, size: tallPhone, location: '/feed');
      await _shot(tester, '04-discover-phone-en-$tag',
          skin: skin, size: tallPhone, location: '/feed', lang: 'en');
      await _shot(tester, '05-discover-laptop-ar-$tag',
          skin: skin, size: tallLaptop, location: '/feed');
    });

    testWidgets('capture $tag: live and audio rooms', skip: skip,
        (tester) async {
      StubVideoPlayer.install(state: StreamState.live, addTearDown: addTearDown);
      await _shot(tester, '06-live-room-phone-ar-$tag',
          skin: skin,
          size: phone,
          screen: const LiveBroadcastScreen(streamId: _liveId));
      await _shot(tester, '07-live-room-laptop-ar-$tag',
          skin: skin,
          size: laptop,
          screen: const LiveBroadcastScreen(streamId: _liveId));
      await _shot(tester, '08-audio-room-phone-ar-$tag',
          skin: skin,
          size: phone,
          audio: true,
          screen: const LiveBroadcastScreen(streamId: _liveId));
    });

    testWidgets('capture $tag: map and lessons', skip: skip, (tester) async {
      await _shot(tester, '09-map-phone-ar-$tag',
          skin: skin, size: phone, location: '/map');
      await _shot(tester, '10-map-laptop-ar-$tag',
          skin: skin, size: laptop, location: '/map');
      await _shot(tester, '11-lessons-phone-ar-$tag',
          skin: skin, size: tallPhone, location: '/lessons');
      await _shot(tester, '12-lessons-laptop-ar-$tag',
          skin: skin, size: tallLaptop, location: '/lessons');
      await _shot(tester, '13-lessons-calendar-phone-ar-$tag',
          skin: skin, size: tallPhone, location: '/lessons/calendar');
    });

    testWidgets('capture $tag: settings, channel and admin', skip: skip,
        (tester) async {
      await _shot(tester, '14-settings-phone-ar-$tag',
          skin: skin,
          size: const Size(390, 2400),
          who: _Who.viewer,
          screen: const SettingsScreen());
      await _shot(tester, '15-settings-laptop-ar-$tag',
          skin: skin,
          size: laptop,
          who: _Who.viewer,
          screen: const SettingsScreen());
      await _shot(tester, '16-channel-phone-ar-$tag',
          skin: skin,
          size: tallPhone,
          location: '/profile/${mockStreamers.first.streamerId}');
      await _shot(tester, '17-admin-phone-ar-$tag',
          skin: skin, size: tallPhone, who: _Who.admin, location: '/admin');
      await _shot(tester, '18-admin-laptop-ar-$tag',
          skin: skin, size: laptop, who: _Who.admin, location: '/admin');
      await _shot(tester, '19-admin-lessons-laptop-ar-$tag',
          skin: skin,
          size: laptop,
          who: _Who.admin,
          location: '/admin/lessons');
    });
  }
}
