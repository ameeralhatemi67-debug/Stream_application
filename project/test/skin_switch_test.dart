import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';

/// Switching designs in Settings (ADR-016) through the app's own router and
/// theme. The buttons animated their labels from one design's text style to
/// the other's, the two disagreed on `inherit`, and TextStyle.lerp threw
/// mid-build: a red screen, then an endless Settings page, then a crash on
/// the way back to Discovery (owner report, 2026-10-29).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final lang in ['en', 'ar']) {
    testWidgets('switching designs back and forth keeps the app whole ($lang)',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = AppProvider()
        ..debugSetSignedInForTests(
            email: 'viewer@example.invalid', isStreamer: false);
      for (final s in mockStreamers) {
        provider.addStreamerForTests(s);
      }
      final lessons = LessonsController(DemoLessonsRepository());
      final router = AppRouter.build(provider);
      router.go('/feed');
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ar')],
          startLocale: Locale(lang),
          saveLocale: false,
          path: 'assets/i18n',
          assetLoader: const DirectJsonAssetLoader(),
          child: MultiProvider(
              providers: [
                ChangeNotifierProvider<AppProvider>.value(value: provider),
                ChangeNotifierProvider<LessonsController>.value(
                    value: lessons),
              ],
              child: Builder(builder: (context) {
                final skin =
                    context.select<AppProvider, AppSkin>((p) => p.appSkin);
                return MaterialApp.router(
                    routerConfig: router,
                    theme: AppTheme.forLocale(context.locale, skin: skin),
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates);
              }))));

      Future<void> frames(String after) async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          final error = tester.takeException();
          if (error != null) fail('after $after: $error');
        }
      }

      await frames('start');
      router.push('/settings');
      await frames('opening Settings');
      for (final skin in [
        AppSkin.hedayah,
        AppSkin.gold,
        AppSkin.hedayah,
        AppSkin.gold,
        AppSkin.hedayah,
      ]) {
        final tile = find.byKey(ValueKey('skin-option-${skin.id}'));
        await tester.scrollUntilVisible(tile, 200,
            scrollable: find
                .descendant(
                    of: find.byType(SettingsScreen),
                    matching: find.byType(Scrollable))
                .first);
        await tester.ensureVisible(tile);
        await frames('scrolling to ${skin.id}');
        await tester.tap(tile);
        await frames('choosing ${skin.id}');
        expect(provider.appSkin, skin);
      }
      router.pop();
      await frames('leaving Settings');
      for (final path in ['/map', '/lessons', '/feed']) {
        router.go(path);
        await frames(path);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      provider.dispose();
    });
  }
}
