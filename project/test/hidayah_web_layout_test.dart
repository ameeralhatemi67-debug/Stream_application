import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_discovery.dart';
import 'package:streamer_app/core/widgets/ds/ca_icon.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/discovery/presentation/web/discovery_web_view.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/streamer_grid_card.dart';
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/map/presentation/web/map_web_panel.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/profile/presentation/broadcaster_profile_screen.dart';
import 'package:streamer_app/features/profile/presentation/web/profile_web_parts.dart';
import 'package:streamer_app/features/web/presentation/hidayah_web_header.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';

/// The gold palette's website layouts replace the app layout on wide
/// windows only; the green palette and phones keep today's layouts.
AppProvider _provider() {
  final provider = AppProvider();
  final base =
      mockStreamers.map((s) => s.copyWith(avatarUrl: '', bannerUrl: '')).toList();
  for (final s in base) {
    provider.addStreamerForTests(s.streamerId == base.first.streamerId
        ? s.copyWith(
            isCurrentlyLive: true,
            broadcastType: BroadcastType.liveVideo,
            activeStreamId: 'stream-web-1')
        : s);
  }
  return provider;
}

Future<void> _pump(WidgetTester tester, Widget screen,
    {required Size size, String lang = 'en'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = _provider();
  await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: Builder(
          builder: (context) => MaterialApp(
              theme: AppTheme.forLocale(context.locale),
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: child!),
              home: ChangeNotifierProvider<AppProvider>.value(
                  value: provider, child: screen)))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final lang in ['en', 'ar']) {
    for (final width in [1024.0, 1440.0]) {
      testWidgets('gold discovery is a website at $width ($lang)',
          (tester) async {
        await _pump(tester, const DiscoveryFeedScreen(),
            size: Size(width, 900), lang: lang);
        expect(find.byType(DiscoveryWebView), findsOneWidget);
        expect(find.byType(StreamerGridCard), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.byType(HidayahWebFooter), 600,
            scrollable: find
                .descendant(
                    of: find.byType(DiscoveryWebView),
                    matching: find.byType(Scrollable))
                .first);
        expect(find.byType(HidayahWebFooter), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('gold channel page is a website at $width ($lang)',
          (tester) async {
        await _pump(
            tester,
            BroadcasterProfileScreen(
                streamerId: mockStreamers.first.streamerId),
            size: Size(width, 900),
            lang: lang);
        expect(find.byType(HidayahWebHeader), findsOneWidget);
        expect(find.byType(ProfileWebHero), findsOneWidget);
        // About lives in the identity block; a non-organization channel has no
        // sidebar, so its tab content takes the full width.
        expect(
            find.descendant(
                of: find.byType(ProfileWebHero),
                matching: find.byType(ProfileWebAbout)),
            findsOneWidget);
        expect(find.byType(ProfileWebSidebar), findsNothing);
        await tester.tap(find.text('profile.archive_tab'.tr()));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });

      testWidgets('gold map has the website panel at $width ($lang)',
          (tester) async {
        await _pump(tester, const SpatialMapScreen(),
            size: Size(width, 900), lang: lang);
        expect(find.byType(MapWebPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'website discovery: three wider channel cards per row, verified on the '
      'avatar, and the map preview', (tester) async {
    await _pump(tester, const DiscoveryFeedScreen(),
        size: const Size(1440, 900));
    final scroll = find
        .descendant(
            of: find.byType(DiscoveryWebView), matching: find.byType(Scrollable))
        .first;
    final ids = [for (final s in mockStreamers.take(4)) s.streamerId];
    Finder card(String id) => find.byKey(ValueKey('channel-card-$id'));
    await tester.scrollUntilVisible(card(ids[0]), 300, scrollable: scroll);
    final rects = [for (final id in ids.take(3)) tester.getRect(card(id))];
    // One row of three, each wider than the old four-up cards (about 285 px).
    expect(rects.map((r) => r.top).toSet(), hasLength(1));
    for (final r in rects) {
      expect(r.width, greaterThan(360));
    }
    await tester.scrollUntilVisible(card(ids[3]), 300, scrollable: scroll);
    expect(tester.getRect(card(ids[3])).top,
        greaterThan(tester.getRect(card(ids[0])).top));

    // The verified mark is on the picture, not beside the name.
    final first = card(ids[0]);
    expect(mockStreamers.first.isVerified, isTrue);
    expect(find.descendant(of: first, matching: find.byType(CaVerifiedBadge)),
        findsOneWidget);
    expect(
        find.descendant(
            of: first,
            matching: find.byWidgetPredicate(
                (w) => w is CaIcon && w.glyph == CaGlyph.verified)),
        findsNothing);

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('map-preview')), 400,
        scrollable: scroll);
    expect(find.text('web.map_title'.tr()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('website channel page: verified on the avatar, not the name',
      (tester) async {
    await _pump(
        tester,
        BroadcasterProfileScreen(streamerId: mockStreamers.first.streamerId),
        size: const Size(1440, 900));
    final hero = find.byType(ProfileWebHero);
    expect(find.descendant(of: hero, matching: find.byType(CaVerifiedBadge)),
        findsOneWidget);
    expect(
        find.descendant(
            of: hero,
            matching: find.byWidgetPredicate(
                (w) => w is CaIcon && w.glyph == CaGlyph.verified)),
        findsNothing);
  });

  testWidgets('gold palette keeps the app layout on a phone', (tester) async {
    await _pump(tester, const DiscoveryFeedScreen(),
        size: const Size(390, 844));
    expect(find.byType(DiscoveryWebView), findsNothing);
    expect(find.byType(CaChipRow), findsOneWidget);
  });
}
