import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_icon.dart';
import 'package:streamer_app/core/widgets/streamer_identity_card.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/streamer_grid_card.dart';
import 'package:streamer_app/features/map/presentation/widgets/marker_summary_card.dart';
import 'package:streamer_app/features/profile/presentation/broadcaster_profile_screen.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';

import 'fixtures/streamer_fixtures.dart';

class DirectJsonAssetLoader extends AssetLoader {
  const DirectJsonAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync());
}

Widget app(AppProvider provider, Widget home, String lang, double scale,
        {GoRouter? router}) =>
    EasyLocalization(
      key: ValueKey('$lang-$scale'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: Builder(builder: (context) {
          Widget sized(BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: child!);
          return router == null
              ? MaterialApp(
                  locale: context.locale,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  theme: AppTheme.forLocale(context.locale),
                  builder: sized,
                  home: home,
                )
              : MaterialApp.router(
                  routerConfig: router,
                  locale: context.locale,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  theme: AppTheme.forLocale(context.locale),
                  builder: sized,
                );
        }),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final language in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Discovery row height $language ${width}px ${scale}x',
            (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final provider = AppProvider(AdminDatabaseService(null))
            ..addStreamerForTests(mockStreamers.first
                .copyWith(avatarUrl: '', bannerUrl: '', tags: const ['#One']))
            ..addStreamerForTests(mockStreamers[1].copyWith(
                avatarUrl: '',
                bannerUrl: '',
                tags: const ['#Two', '#Three', '#Four']));
          await tester.pumpWidget(
              app(provider, const DiscoveryFeedScreen(), language, scale));
          await tester.pumpAndSettle();
          final cards = find.byType(StreamerGridCard);
          expect(cards, findsNWidgets(2));
          expect(tester.getSize(cards.first).height,
              tester.getSize(cards.last).height);
          if (width == 1280) {
            tester.view.physicalSize = const Size(800, 900);
            await tester.pumpAndSettle();
            expect(tester.getSize(cards.first).height,
                tester.getSize(cards.last).height);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          provider.dispose();
        });
      }
    }
  }

  for (final lang in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final location in ['map', 'discovery', 'profile', 'settings']) {
          testWidgets('$location card $lang ${width}px ${scale}x text',
              (tester) async {
            SharedPreferences.setMockInitialValues({});
            final previousError = FlutterError.onError;
            FlutterError.onError = (details) {
              debugPrint(details.toString());
              previousError?.call(details);
            };
            addTearDown(() => FlutterError.onError = previousError);
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final streamer = mockStreamers.first.copyWith(
              avatarUrl: '',
              bannerUrl: '',
              youtubeHandle: '',
              tags: const ['#Physics', '#Research'],
              bioEn: 'A long academic description with practical lessons. ' * 8,
              bioAr: 'وصف أكاديمي طويل مع دروس عملية ومعلومات إضافية. ' * 8,
            );
            final provider = AppProvider(AdminDatabaseService(null))
              ..debugSetOnlineForTests(true)
              ..addStreamerForTests(streamer);
            if (location == 'settings') {
              provider.debugSetSignedInForTests(
                  email: 'lecturer@example.invalid',
                  name: 'Academic Lecturer',
                  isStreamer: true,
                  ownedStreamerId: streamer.streamerId);
            }
            final Widget home = switch (location) {
              'map' => Scaffold(
                  body: SingleChildScrollView(
                      child: MarkerSummaryCard(
                          streamer: streamer, onClose: () {}))),
              'discovery' => const DiscoveryFeedScreen(),
              'profile' =>
                BroadcasterProfileScreen(streamerId: streamer.streamerId),
              _ => const SettingsScreen(),
            };
            await tester.pumpWidget(app(provider, home, lang, scale));
            await tester.pumpAndSettle();
            final cards = switch (location) {
              'discovery' => find.byType(CaScholarCard),
              'settings' =>
                find.byKey(const ValueKey('settings-account-panel')),
              'profile' => find.ancestor(
                  of: find.text(streamer.getLocalizedName(lang)),
                  matching: find.byType(CaCard)),
              _ => find.byType(StreamerIdentityCard),
            };
            expect(cards, location == 'settings' ? findsOneWidget : findsWidgets);
            final surface = find
                .descendant(of: cards.first, matching: find.byType(Material))
                .first;
            final cardWidth = tester.getSize(surface).width;
            if (width >= 900 && location == 'profile') {
              expect(
                  cardWidth,
                  closeTo(
                      CanopySize.profilePaneLarge - 2 * AppTheme.spaceLg, 1));
            } else if (width >= 900 && location == 'settings') {
              expect(cardWidth, greaterThan(420));
            } else {
              expect(cardWidth, lessThanOrEqualTo(420));
            }
            expect(tester.takeException(), isNull);
            if (location == 'profile') {
              if (width >= 900) {
                expect(find.byType(AppBar), findsNothing);
                final back = find.byWidgetPredicate(
                    (w) => w is CaIconButton && w.icon == CaGlyph.back);
                expect(back, findsOneWidget);
                expect(
                    lang == 'en'
                        ? tester.getCenter(back).dx
                        : width - tester.getCenter(back).dx,
                    lessThan(tester.getSize(surface).width));
              }
              await tester
                  .ensureVisible(find.byTooltip('profile.show_more'.tr()));
              await tester.pumpAndSettle();
              await tester.tap(find.byTooltip('profile.show_more'.tr()));
              await tester.pumpAndSettle();
              expect(find.byTooltip('profile.show_less'.tr()), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester
                  .ensureVisible(find.byTooltip('profile.show_less'.tr()));
              await tester.pumpAndSettle();
              await tester.tap(find.byTooltip('profile.show_less'.tr()));
              await tester.pumpAndSettle();
              final follow = find.byWidgetPredicate(
                  (w) => w is CaButton && w.label == 'profile.follow_btn'.tr(),
                  skipOffstage: false);
              await Scrollable.ensureVisible(tester.element(follow),
                  alignment: .5);
              await tester.pumpAndSettle();
              await tester.tap(follow);
              await tester.pumpAndSettle();
              expect(provider.isFollowing(streamer.streamerId), isTrue);
              final reminder = find.byTooltip('profile.reminder_btn'.tr(),
                  skipOffstage: false);
              await Scrollable.ensureVisible(tester.element(reminder),
                  alignment: .5);
              await tester.pumpAndSettle();
              await tester.tap(reminder);
              await tester.pumpAndSettle();
              expect(provider.hasReminder(streamer.streamerId), isFalse);
              expect(find.text('upcoming.sign_in_title'.tr()), findsOneWidget);
            }
            if (location == 'settings') {
              expect(
                  find.descendant(
                      of: cards, matching: find.byIcon(Icons.edit_outlined)),
                  findsOneWidget);
              expect(find.text('settings.edit_profile'.tr()), findsOneWidget);
            }
            if (location == 'discovery') {
              if (width >= 900) {
                final rect = tester.getRect(surface);
                expect(lang == 'en' ? rect.left : width - rect.right,
                    closeTo(CanopyWindow.insetLarge, 1));
              }
              expect(find.text('profile.view_channel'.tr()), findsNothing);
              expect(find.text('#Physics'), findsOneWidget);
              expect(find.text('#Research'), findsOneWidget);
              expect(
                  find.descendant(
                      of: cards,
                      matching: find.byIcon(Icons.notifications_none_rounded)),
                  findsNothing);
              expect(
                  find.descendant(
                      of: cards,
                      matching: find.text('profile.follow_btn'.tr())),
                  findsNothing);
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            provider.dispose();
          });
        }
      }
    }
  }

  for (final lang in ['en', 'ar']) {
    testWidgets('desktop profile controls mirror within identity pane in $lang',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final streamer = mockStreamers.first
          .copyWith(avatarUrl: '', bannerUrl: '', isOrganization: false);
      final provider = AppProvider(AdminDatabaseService(null))
        ..addStreamerForTests(streamer);
      await tester.pumpWidget(app(provider,
          BroadcasterProfileScreen(streamerId: streamer.streamerId), lang, 1));
      await tester.pumpAndSettle();
      final back = find.byWidgetPredicate(
          (w) => w is CaIconButton && w.icon == CaGlyph.back);
      final share = find.byWidgetPredicate(
          (w) => w is CaIconButton && w.icon == CaGlyph.share);
      final chip = find.byType(CaLanguageChip);
      final status = find.byType(CaStatusChip).first;
      final paneEdge = lang == 'en' ? 0.0 : 1280.0;
      expect((tester.getCenter(back).dx - paneEdge).abs(), lessThan(100));
      expect((tester.getCenter(share).dx - paneEdge).abs(),
          lessThan(CanopySize.profilePaneLarge));
      expect((tester.getCenter(chip).dx - paneEdge).abs(),
          lessThan(CanopySize.profilePaneLarge));
      expect(
          (tester.getCenter(find.text('profile.follow_btn'.tr())).dx - paneEdge)
              .abs(),
          lessThan(CanopySize.profilePaneLarge));
      expect(tester.getRect(status).top,
          greaterThan(tester.getRect(share).bottom));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });

    for (final layout in [(420.0, 1), (800.0, 2), (1000.0, 3), (1280.0, 4)]) {
      testWidgets(
          'discovery uses ${layout.$2} columns at ${layout.$1}px in $lang',
          (tester) async {
        tester.view.physicalSize = Size(layout.$1, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = AppProvider(AdminDatabaseService(null));
        for (final streamer in mockStreamers.take(4)) {
          provider.addStreamerForTests(
              streamer.copyWith(avatarUrl: '', bannerUrl: ''));
        }
        await tester
            .pumpWidget(app(provider, const DiscoveryFeedScreen(), lang, 1));
        await tester.pumpAndSettle();
        final cards = find.byType(CaScholarCard);
        expect(cards, findsNWidgets(4));
        final firstTop = tester.getTopLeft(cards.first);
        expect(
            [
              for (var i = 0; i < 4; i++)
                if ((tester.getTopLeft(cards.at(i)).dy - firstTop.dy).abs() < 1)
                  i
            ].length,
            layout.$2);
        if (layout.$1 >= 900) {
          final rect = tester.getRect(cards.first);
          expect(
              lang == 'en' ? rect.left : layout.$1 - rect.right,
              closeTo(
                  layout.$1 >= CanopyWindow.large
                      ? CanopyWindow.insetLarge
                      : CanopyWindow.insetExpanded,
                  1));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      });
    }

    testWidgets('short profile has no expansion arrow $lang', (tester) async {
      final streamer = mockStreamers.first.copyWith(
          avatarUrl: '',
          bannerUrl: '',
          bioEn: 'Brief bio.',
          bioAr: 'نبذة قصيرة.',
          isOrganization: false);
      final provider = AppProvider(AdminDatabaseService(null))
        ..addStreamerForTests(streamer);
      await tester.pumpWidget(app(provider,
          BroadcasterProfileScreen(streamerId: streamer.streamerId), lang, 1));
      await tester.pumpAndSettle();
      expect(find.byTooltip('profile.show_more'.tr()), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  }

  testWidgets(
      'venue tap launches exact Google destination; live card opens its room',
      (tester) async {
    final streamer = mockStreamers.first.copyWith(
        avatarUrl: '',
        bannerUrl: '',
        isCurrentlyLive: true,
        liveSessionId: 'room-session',
        activeStreamId: 'abcdefghijk');
    final provider = AppProvider(AdminDatabaseService(null));
    final calls = <MethodCall>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: MarkerSummaryCard(streamer: streamer, onClose: () {}))),
      GoRoute(
          path: '/live/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Opened ${state.pathParameters['id']}'))),
    ]);
    await tester
        .pumpWidget(app(provider, const SizedBox(), 'en', 1, router: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-card-venue')));
    await tester.pumpAndSettle();
    final url = Uri.parse((calls.first.arguments as Map)['url'] as String);
    expect(url.host, 'www.google.com');
    expect(url.queryParameters['destination'],
        '${streamer.latitude},${streamer.longitude}');
    expect(find.byType(MarkerSummaryCard), findsOneWidget);
    await tester.tap(find.text(streamer.fullNameEn));
    await tester.pumpAndSettle();
    expect(find.text('Opened room-session'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    provider.dispose();
  });
}
