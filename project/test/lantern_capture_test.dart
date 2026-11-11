import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/app_logo.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/splash/presentation/lantern/lantern_opening_view.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/lantern_harness.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

/// Pictures of the Lantern and Arch screens for review and for the report:
/// phone, tablet and laptop, Arabic and English, day and night. Rendered by
/// the test engine with the real fonts through the app's own router.
///
/// Skipped unless LANTERN_CAPTURE_DIR is set. LANTERN_CAPTURE_ONLY keeps the
/// shots whose name contains one of its comma-separated parts.
final _dir = Platform.environment['LANTERN_CAPTURE_DIR'];
final _only = (Platform.environment['LANTERN_CAPTURE_ONLY'] ?? '')
    .split(',')
    .where((p) => p.isNotEmpty)
    .toList();

const phone = Size(390, 844), tablet = Size(820, 1180), laptop = Size(1440, 900);

typedef LanternShot = ({
  String name,
  String route,
  Size size,
  String lang,
  bool night,
  String who,
  bool audio,
  bool live
});

LanternShot lanternShot(String name, String route,
        {Size size = phone,
        String lang = 'ar',
        bool night = false,
        String who = 'guest',
        bool audio = false,
        bool live = true}) =>
    (
      name: name,
      route: route,
      size: size,
      lang: lang,
      night: night,
      who: who,
      audio: audio,
      live: live
    );

final shots = <LanternShot>[
  lanternShot('discover-phone-ar-day', '/feed', size: const Size(390, 5200)),
  lanternShot('discover-phone-en-night', '/feed',
      size: const Size(390, 5200), lang: 'en', night: true),
  lanternShot('discover-phone-ar-quiet', '/feed', live: false),
  lanternShot('discover-tablet-ar-day', '/feed', size: const Size(820, 3600)),
  lanternShot('discover-laptop-ar-day', '/feed', size: const Size(1440, 3200)),
  lanternShot('discover-laptop-en-night', '/feed',
      size: const Size(1440, 3200), lang: 'en', night: true),
  lanternShot('discover-phone-ar-fold', '/feed'),
  lanternShot('discover-laptop-ar-fold', '/feed', size: laptop),
  lanternShot('room-live-phone-ar', '/live/lanternLive'),
  lanternShot('room-live-phone-en', '/live/lanternLive', lang: 'en'),
  lanternShot('room-live-tablet-ar', '/live/lanternLive', size: tablet),
  lanternShot('room-live-laptop-ar', '/live/lanternLive', size: laptop),
  lanternShot('room-audio-phone-ar', '/live/lanternLive', audio: true),
  lanternShot('room-audio-laptop-en', '/live/lanternLive',
      size: laptop, lang: 'en', audio: true),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
    if (_dir != null) Directory(_dir!).createSync(recursive: true);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final s in shots) {
    final wanted = _only.isEmpty || _only.any(s.name.contains);
    testWidgets('capture ${s.name}', skip: _dir == null || !wanted,
        (tester) async {
      StubVideoPlayer.install(state: StreamState.live, addTearDown: addTearDown);
      final provider = lanternProvider(
          appearance:
              s.night ? LanternAppearance.night : LanternAppearance.day,
          audio: s.audio,
          live: s.live);
      switch (s.who) {
        case 'viewer':
          provider.debugSetSignedInForTests(
              email: 'viewer@example.invalid', name: 'Viewer', isStreamer: false);
        case 'streamer':
          provider.debugSetSignedInForTests(
              email: 'streamer@example.invalid',
              name: 'Streamer',
              ownedStreamerId: mockStreamers.first.streamerId);
        case 'admin':
          provider.debugSetSignedInForTests(
              email: 'admin@example.invalid',
              name: 'Admin',
              isMasterAdmin: true,
              isLessonsAdmin: true,
              isStreamer: false);
      }
      final app = await LanternApp.start(tester,
          provider: provider,
          size: s.size,
          lang: s.lang,
          location: s.route,
          persona: s.who == 'admin'
              ? LessonsDemoPersona.admin
              : LessonsDemoPersona.guest);
      final context = tester.element(find.byType(Navigator).first);
      await tester.runAsync(() async {
        for (final m in mockStreamers) {
          for (final path in [m.avatarUrl, m.bannerUrl]) {
            if (path.startsWith('assets/')) {
              await precacheImage(AssetImage(path), context);
            }
          }
        }
        await precacheImage(const AssetImage(AppLogo.hidayahAsset), context);
        await precacheImage(const AssetImage(LLogo.wordmark), context);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await app.settle(10);
      // A build or layout error shows in the picture; say what it was.
      final error = tester.takeException();
      if (error != null) debugPrint('CAPTURE ${s.name}: $error');
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$_dir/${s.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await app.close();
    });
  }

  // Screens that are easier to show on their own than through the router.
  final pieces = <(String, Size, String, Widget)>[
    ('opening-phone-ar', phone, 'ar', const LanternOpeningView()),
    ('opening-laptop-en', laptop, 'en', const LanternOpeningView()),
    (
      'opening-phone-ar-slow',
      phone,
      'ar',
      LanternOpeningView(
          state: LanternOpeningState.slow, onContinue: () {}, onSkip: () {})
    ),
    (
      'opening-phone-en-offline',
      phone,
      'en',
      LanternOpeningView(state: LanternOpeningState.offline, onRetry: () {})
    ),
  ];
  for (final (name, size, lang, widget) in pieces) {
    final wanted = _only.isEmpty || _only.any(name.contains);
    testWidgets('capture $name', skip: _dir == null || !wanted, (tester) async {
      await pumpLanternWidget(tester, RepaintBoundary(child: widget),
          size: size, lang: lang);
      final context = tester.element(find.byType(RepaintBoundary).first);
      await tester.runAsync(() async {
        await precacheImage(const AssetImage(LLogo.wordmark), context);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 200));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$_dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
