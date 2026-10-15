// Android 16 (API 36) checks from brief/launch/03 section 5.
//
// Edge-to-edge can no longer be switched off, so the status and navigation
// bars always draw over the app. Each screen is laid out with system bars
// reported as insets; a fixed tap target under either bar is a failure.
// Content inside a scroll view may pass under the bars and is not checked.
//
// On screens 600dp and wider Android 16 ignores orientation locks, so the
// studio sheet (absent from layout_sweep_test.dart) is laid out in tablet
// portrait and landscape as well.
import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/screens/phone_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';
import 'fixtures/streamer_fixtures.dart';
import 'support/stub_video_player.dart';

class _CatalogLoader extends AssetLoader {
  const _CatalogLoader(this.data);
  final Map<String, dynamic> data;
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      data[locale.languageCode];
}

const _liveStreamId = 'stream_live_992';
const _statusBar = 32.0;
const _navigationBar = 48.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalogs = <String, dynamic>{};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final lang in ['en', 'ar']) {
      catalogs[lang] =
          jsonDecode(File('assets/i18n/$lang.json').readAsStringSync());
    }
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
  });

  AppProvider liveProvider({bool streamer = false}) {
    final provider = AppProvider();
    final base = mockStreamers
        .map((s) => s.copyWith(avatarUrl: '', bannerUrl: ''))
        .toList();
    for (final s in base) {
      provider.addStreamerForTests(s.streamerId == base.first.streamerId
          ? s.copyWith(
              isCurrentlyLive: true,
              broadcastType: BroadcastType.liveVideo,
              activeStreamId: _liveStreamId)
          : s);
    }
    if (streamer) {
      provider.debugSetSignedInForTests(
          email: 'streamer@example.test',
          ownedStreamerId: base.first.streamerId);
    }
    return provider;
  }

  final screens = <String, (Widget Function(), AppProvider Function())>{
    'feed': (() => const DiscoveryFeedScreen(), () => liveProvider()),
    'map': (() => const SpatialMapScreen(), () => liveProvider()),
    'settings': (
      () => const SettingsScreen(),
      () => liveProvider(streamer: true)
    ),
    'live room': (
      () => const LiveBroadcastScreen(streamId: _liveStreamId),
      () => liveProvider()
    ),
    'phone broadcast': (
      () => const PhoneBroadcastScreen(),
      () => liveProvider(streamer: true)
    ),
    'studio sheet': (
      () => const Scaffold(body: LiveBroadcasterStudioSheet()),
      () => liveProvider(streamer: true)
    ),
  };

  Future<void> pump(WidgetTester tester, String lang, Widget Function() home,
      AppProvider provider) async {
    await tester.pumpWidget(EasyLocalization(
      key: UniqueKey(),
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/i18n',
      assetLoader: _CatalogLoader(catalogs),
      startLocale: Locale(lang),
      saveLocale: false,
      child: Builder(
          builder: (context) => ChangeNotifierProvider.value(
                value: provider,
                child: MaterialApp(
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    theme: AppTheme.forLocale(Locale(lang)),
                    home: home()),
              )),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Tap targets that stay put while content scrolls.
  Iterable<Rect> fixedTapTargets(WidgetTester tester) => find
      .byWidgetPredicate((w) =>
          (w is InkResponse && (w.onTap != null || w.onLongPress != null)) ||
          (w is GestureDetector && w.onTap != null))
      .evaluate()
      .where((e) =>
          e.findAncestorWidgetOfExactType<Scrollable>() == null &&
          e.findAncestorWidgetOfExactType<PageView>() == null)
      .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)))
      .where((r) => !r.isEmpty);

  for (final entry in screens.entries) {
    for (final lang in ['en', 'ar']) {
      testWidgets(
          '${entry.key} keeps fixed controls clear of system bars ($lang)',
          (tester) async {
        StubVideoPlayer.install(
            state: StreamState.live, addTearDown: addTearDown);
        tester.view.devicePixelRatio = 1;
        tester.view.padding =
            const FakeViewPadding(top: _statusBar, bottom: _navigationBar);
        tester.view.viewPadding =
            const FakeViewPadding(top: _statusBar, bottom: _navigationBar);
        addTearDown(tester.view.reset);
        for (final size in const [
          Size(412, 915),
          Size(800, 1280),
          Size(1280, 800)
        ]) {
          tester.view.physicalSize = size;
          final provider = entry.value.$2();
          await pump(tester, lang, entry.value.$1, provider);
          final errors = <Object>[];
          Object? error;
          while ((error = tester.takeException()) != null) {
            errors.add(error!);
          }
          final covered = fixedTapTargets(tester)
              .where((r) =>
                  r.top < _statusBar - 1 ||
                  r.bottom > size.height - _navigationBar + 1)
              .toList();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          provider.dispose();
          expect(errors, isEmpty, reason: '${entry.key} $lang $size');
          expect(covered, isEmpty,
              reason:
                  '${entry.key} $lang $size: tap targets under a system bar');
        }
      });
    }
  }

  for (final lang in ['en', 'ar']) {
    testWidgets(
        'studio sheet lays out when a tablet ignores the portrait lock ($lang)',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final size in const [
        Size(360, 640),
        Size(600, 960),
        Size(800, 1280),
        Size(1280, 800),
        Size(960, 600),
      ]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = size;
          final provider = liveProvider(streamer: true);
          await pump(
              tester,
              lang,
              () => Builder(
                  builder: (context) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child:
                          const Scaffold(body: LiveBroadcasterStudioSheet()))),
              provider);
          final errors = <Object>[];
          Object? error;
          while ((error = tester.takeException()) != null) {
            errors.add(error!);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          provider.dispose();
          expect(errors, isEmpty, reason: 'studio $lang $size scale=$scale');
        }
      }
    });
  }

  test('the manifest has no orientation lock that tablets would ignore', () {
    // Android 16 ignores orientation locks on large screens, so screens must
    // lay out in both orientations instead (checked above and in
    // layout_sweep_test.dart).
    expect(
        File('android/app/src/main/AndroidManifest.xml')
            .readAsStringSync()
            .contains('android:screenOrientation'),
        isFalse);
  });
}
