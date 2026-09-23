import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/connectivity_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/connectivity_banner.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/streamer_grid_card.dart';
import 'package:streamer_app/features/auth/presentation/streamer_apply_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_room_connection_view.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';

Widget harness(AppProvider provider, String language, Widget home) =>
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(language),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: AppTheme.forLocale(context.locale),
            home: Scaffold(body: home),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['en', 'ar']) {
    testWidgets(
        '$language offline banner gives a local retry in the right layout',
        (tester) async {
      final service = ConnectivityService(
        endpoint: Uri.parse('http://127.0.0.1:1/rest/v1/'),
        checkConnectivity: () async => [ConnectivityResult.none],
        connectivityChanges: const Stream.empty(),
        probe: (_) async => throw StateError('Probe must not run offline'),
      );
      final provider = AppProvider.withServices(connectivityService: service);
      provider.debugSetOnlineForTests(false);
      await tester.pumpWidget(harness(
          provider, language, const Column(children: [ConnectivityBanner()])));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connectivity_banner')), findsOneWidget);
      expect(find.text(language == 'ar' ? 'إعادة المحاولة' : 'Retry'),
          findsOneWidget);
      final bannerContext = tester.element(find.byType(ConnectivityBanner));
      expect(Directionality.of(bannerContext),
          language == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr);
      await tester
          .tap(find.text(language == 'ar' ? 'إعادة المحاولة' : 'Retry'));
      await tester.pumpAndSettle();
      expect(provider.networkStatus, NetworkStatus.offline);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  }

  testWidgets('retry clears the degraded banner when the backend recovers',
      (tester) async {
    var reachable = false;
    final service = ConnectivityService(
      endpoint: Uri.parse('http://127.0.0.1:1/rest/v1/'),
      checkConnectivity: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
      probe: (_) async => reachable,
    );
    final provider = AppProvider.withServices(connectivityService: service);
    await provider.refreshConnectivityNow();
    await tester.pumpWidget(harness(provider, 'en',
        const Column(children: [ConnectivityBanner()])));
    await tester.pumpAndSettle();
    expect(find.text('The service is hard to reach'), findsOneWidget);
    reachable = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(provider.networkStatus, NetworkStatus.online);
    expect(find.byKey(const ValueKey('connectivity_banner')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('lost connection hides stale LIVE badge and viewer claim',
      (tester) async {
    final provider = AppProvider();
    final staleLive = mockStreamers.first.copyWith(
        isCurrentlyLive: true,
        activeStreamId: 'stale-room',
        activeViewerCount: 88);
    provider.addStreamer(staleLive);
    provider.debugSetOnlineForTests(false);
    expect(provider.streamers.single.activeStreamId, isNull);
    expect(provider.streamers.single.activeViewerCount, 0);
    await tester.pumpWidget(harness(
        provider,
        'en',
        SizedBox(
            width: 220,
            height: 300,
            child: StreamerGridCard(streamer: staleLive, langCode: 'en'))));
    await tester.pumpAndSettle();
    expect(find.text('Live status unavailable'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('degraded room gives a reason and retry without a player',
      (tester) async {
    final service = ConnectivityService(
      endpoint: Uri.parse('http://127.0.0.1:1/rest/v1/'),
      checkConnectivity: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
      probe: (_) async => false,
    );
    final provider = AppProvider.withServices(connectivityService: service);
    await tester.pumpWidget(harness(provider, 'ar',
        const LiveRoomConnectionView(status: NetworkStatus.degraded)));
    await tester.pumpAndSettle();
    expect(find.text('غرفة البث غير متاحة'), findsOneWidget);
    expect(find.text('تعذّر الوصول إلى الخدمة'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(provider.networkStatus, NetworkStatus.degraded);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('wizard input survives a recoverable connection loss',
      (tester) async {
    final provider = AppProvider();
    await tester.pumpWidget(harness(provider, 'en',
        const StreamerApplyScreen()));
    await tester.pumpAndSettle();
    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Unsent applicant name');
    provider.debugSetOnlineForTests(false);
    await tester.pump();
    expect(find.text('Unsent applicant name'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
}
