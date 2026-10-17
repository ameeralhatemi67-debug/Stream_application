import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/organization_broadcast_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';

import 'support/localized_app.dart';

Widget _app(AppProvider provider, Widget home, String language) =>
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
            home: home,
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS refuses channel authorization before accessing the backend',
      () async {
    final service = OrganizationBroadcastService();

    await expectLater(
        service.connectChannel(), throwsA(isA<UnsupportedError>()));
    await expectLater(
        service.connectChannel(organizationId: 'test-organization'),
        throwsA(isA<UnsupportedError>()));
  });

  for (final language in ['en', 'ar']) {
    testWidgets('iOS studio entry shows a dismissible notice ($language)',
        (tester) async {
      final provider = AppProvider();
      try {
        await tester.pumpWidget(_app(
          provider,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => LiveBroadcasterStudioSheet.show(context),
                child: const Text('Open studio'),
              ),
            ),
          ),
          language,
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open studio'));
        await tester.pumpAndSettle();

        expect(find.byType(FeatureInProgressModal), findsOneWidget);
        expect(find.text('live_studio.btn_local_unavailable'.tr()),
            findsOneWidget);
        expect(find.byType(LiveBroadcasterStudioSheet), findsNothing);

        await tester.tap(find.text('organization_v1.close'.tr()));
        await tester.pumpAndSettle();
        expect(find.byType(FeatureInProgressModal), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
