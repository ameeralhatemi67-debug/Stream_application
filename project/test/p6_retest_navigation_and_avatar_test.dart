import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/widgets/streamer_avatar.dart';
import 'package:streamer_app/features/auth/presentation/application_pending_screen.dart';
import 'package:streamer_app/features/auth/presentation/streamer_apply_screen.dart';

import 'support/localized_app.dart';

Widget _app({required Widget child, Locale locale = const Locale('en')}) =>
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: locale,
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('S02 avatar fallback', () {
    testWidgets('a picture that fails to load shows the initial, not a blank '
        'circle', (tester) async {
      // flutter_test answers every network image request with HTTP 400,
      // the same shape as a Google photo returning 429 or a deleted upload.
      await tester.pumpWidget(_app(
          child: const StreamerAvatar(
              avatarUrl: 'https://example.invalid/avatar.png',
              name: 'amir',
              radius: 30)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('no picture and no name shows a person icon', (tester) async {
      await tester.pumpWidget(_app(child: const StreamerAvatar(avatarUrl: '')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });

    testWidgets('Arabic names use their first letter in RTL', (tester) async {
      await tester.pumpWidget(_app(
          locale: const Locale('ar'),
          child: const StreamerAvatar(avatarUrl: null, name: 'أمير', square: true)));
      await tester.pump();
      expect(find.text('أ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('R09 application wizard exit', () {
    Future<AppProvider> pumpWizard(WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = AppProvider();
      await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: _app(
          child: Builder(
            builder: (c) => TextButton(
              onPressed: () => Navigator.of(c).push(MaterialPageRoute(
                  builder: (_) => const StreamerApplyScreen())),
              child: const Text('settings page'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('settings page'));
      await tester.pumpAndSettle();
      expect(find.byType(StreamerApplyScreen), findsOneWidget);
      return provider;
    }

    testWidgets('close leaves directly from the first step', (tester) async {
      final provider = await pumpWizard(tester);
      await tester.tap(find.byKey(const Key('wizard-exit')));
      await tester.pumpAndSettle();
      expect(find.byType(StreamerApplyScreen), findsNothing);
      expect(find.text('settings page'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('close from a later step asks, then leaves in one action',
        (tester) async {
      final provider = await pumpWizard(tester);
      tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard-exit')));
      await tester.pumpAndSettle();
      expect(find.text('wizard_steps.exit_title'.tr()), findsOneWidget);

      await tester.tap(find.text('wizard_steps.exit_stay'.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(StreamerApplyScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('wizard-exit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('wizard_steps.exit_leave'.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(StreamerApplyScreen), findsNothing);
      expect(find.text('settings page'), findsOneWidget);
      provider.dispose();
    });
  });

  testWidgets(
      'R09: the application status screen has a way back even after go()',
      (tester) async {
    final router = GoRouter(initialLocation: '/application-pending', routes: [
      GoRoute(
          path: '/settings',
          builder: (_, __) => const Scaffold(body: Text('settings page'))),
      GoRoute(
          path: '/application-pending',
          builder: (_, __) => const ApplicationPendingScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: Builder(
        builder: (context) => MaterialApp.router(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          routerConfig: router,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);
  });
}
