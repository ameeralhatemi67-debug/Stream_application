// P6S wave 3, group 4: Local (same Wi-Fi) streaming stays visibly
// unavailable, and nothing in the app suggests it can be configured.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/admin/presentation/admin_hub_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';

import 'support/localized_app.dart';

Widget _app(AppProvider p, Widget home, String lang) => EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider.value(
        value: p,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            theme: AppTheme.forLocale(context.locale),
            home: home,
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final lang in ['en', 'ar']) {
    testWidgets('studio Local tab explains it is unavailable ($lang)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = AppProvider();
      await tester.pumpWidget(_app(
          p,
          const Scaffold(
              body: LiveBroadcasterStudioSheet(initialMode: StudioMode.local)),
          lang));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('local-unavailable')), findsOneWidget);
      expect(find.byType(TextField), findsNothing,
          reason: 'no address, key or link is asked for');
      // The rendered card names the tabs the viewer actually sees.
      final body = find.descendant(
          of: find.byKey(const ValueKey('local-unavailable')),
          matching: find.text('live_studio.local_unavailable_body'.tr()));
      expect(body, findsOneWidget);
      final text = tester.widget<Text>(body).data!;
      expect(text, contains('live_studio.mode_encoder'.tr()));
      expect(text, contains('design_copy.phone'.tr()));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the admin testing tools no longer offer a Local RTMP address',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = AppProvider(AdminDatabaseService(null));
    p.debugSetSignedInForTests(
        email: 'master@example.invalid', isMasterAdmin: true);
    await tester.pumpWidget(_app(p, const AdminHubScreen(), 'en'));
    await tester.pumpAndSettle();
    final testing = find.byKey(const ValueKey('admin.tab_testing'));
    await tester.scrollUntilVisible(testing, 200,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('admin-navigation')),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(testing);
    await tester.pumpAndSettle();
    expect(find.text('settings.pitch_mode'.tr()), findsOneWidget);
    expect(find.textContaining('RTMP'), findsNothing);
    expect(find.byIcon(Icons.wifi_tethering_rounded), findsNothing);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets('the studio entry is not described as IP or RTMP settings',
      (tester) async {
    for (final lang in ['en', 'ar']) {
      await tester.pumpWidget(_app(AppProvider(), const SizedBox(), lang));
      await tester.pumpAndSettle();
      final label = 'live.rtmp_ip_tooltip'.tr();
      expect(label, isNot(contains('IP')));
      expect(label, isNot(contains('RTMP')));
    }
  });
}
