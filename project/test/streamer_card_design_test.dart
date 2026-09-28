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
import 'package:streamer_app/core/widgets/language_switcher.dart';
import 'package:streamer_app/core/widgets/streamer_identity_card.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
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
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
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
            final cards = find.byType(StreamerIdentityCard);
            expect(cards, findsWidgets);
            final surface = find
                .descendant(of: cards.first, matching: find.byType(Material))
                .first;
            final cardWidth = tester.getSize(surface).width;
            if (width >= 900 && location == 'profile') {
              expect(cardWidth, greaterThan(900));
            } else if (width >= 900 && location == 'settings') {
              expect(cardWidth, greaterThan(420));
            } else {
              expect(cardWidth, lessThanOrEqualTo(420));
            }
            expect(tester.takeException(), isNull);
            if (location == 'profile') {
              if (width >= 900) {
                expect(find.byType(AppBar), findsNothing);
                final back = find.byIcon(Icons.arrow_back_rounded);
                expect(back, findsOneWidget);
                expect(tester.getTopLeft(back).dx,
                    lessThan(tester.getCenter(surface).dx));
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
              final follow =
                  find.text('profile.follow_btn'.tr(), skipOffstage: false);
              await tester.ensureVisible(follow);
              await tester.pumpAndSettle();
              await tester.tap(follow);
              await tester.pumpAndSettle();
              expect(provider.isFollowing(streamer.streamerId), isTrue);
              final reminder = find.byTooltip('profile.reminder_btn'.tr(),
                  skipOffstage: false);
              await tester.ensureVisible(reminder);
              await tester.tap(reminder);
              await tester.pumpAndSettle();
              expect(provider.hasReminder(streamer.streamerId), isTrue);
            }
            if (location == 'settings') {
              expect(
                  find.descendant(
                      of: cards, matching: find.byIcon(Icons.edit_outlined)),
                  findsNothing);
              expect(find.text('settings.edit_profile'.tr()), findsOneWidget);
            }
            if (location == 'discovery') {
              if (width >= 900) {
                expect(tester.getTopLeft(surface).dx, closeTo(16, 1));
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
    testWidgets('desktop profile controls keep physical corners in $lang',
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
      expect(tester.getCenter(find.byIcon(Icons.arrow_back_rounded)).dx,
          lessThan(100));
      expect(tester.getCenter(find.byType(LanguageSwitcher)).dx,
          greaterThan(1100));
      expect(tester.getCenter(find.byIcon(Icons.share_outlined)).dx,
          greaterThan(1100));
      expect(tester.getCenter(find.byIcon(Icons.person_add_rounded)).dx,
          lessThan(400));
      expect(
          tester.getRect(find.byType(StreamerCardStatus)).top,
          greaterThan(
              tester.getRect(find.byIcon(Icons.share_outlined)).bottom));
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
        final cards = find.byType(StreamerIdentityCard);
        expect(cards, findsNWidgets(4));
        final firstTop = tester.getTopLeft(cards.first);
        expect(
            [
              for (var i = 0; i < 4; i++)
                if ((tester.getTopLeft(cards.at(i)).dy - firstTop.dy).abs() < 1)
                  i
            ].length,
            layout.$2);
        if (layout.$1 >= 900) expect(firstTop.dx, closeTo(16, 1));
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
      'venue tap launches exact Google destination; card tap opens profile',
      (tester) async {
    final streamer = mockStreamers.first.copyWith(
        avatarUrl: '',
        bannerUrl: '',
        isCurrentlyLive: true,
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
          path: '/profile/:id',
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
    expect(find.text('Opened ${streamer.streamerId}'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    provider.dispose();
  });
}
