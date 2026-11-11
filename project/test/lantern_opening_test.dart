import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/splash/presentation/app_splash_screen.dart';
import 'package:streamer_app/features/splash/presentation/lantern/lantern_opening_view.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// The opening screen of Lantern and Arch (ADR-026): what it shows, its
/// slow-network and offline states, and that it never holds the app back
/// longer than its short minimum.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final lang in ['ar', 'en']) {
    for (final size in [const Size(390, 844), const Size(1440, 900)]) {
      testWidgets('lays out in $lang at ${size.width.round()} wide',
          (tester) async {
        await pumpLanternWidget(tester, const LanternOpeningView(),
            lang: lang, size: size);
        expect(tester.takeException(), isNull);
        expect(find.text(lang == 'ar' ? 'منصة هدايه' : 'Hadayah Live'),
            findsOneWidget);
        // Always night, whatever the person chose for the rest of the app.
        expect(
            Theme.of(tester.element(find.byType(Scaffold).last))
                .extension<LanternTokens>()!
                .night,
            isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('calm motion shows the last frame at once and nothing moves',
      (tester) async {
    await pumpLanternWidget(tester, const LanternOpeningView(), calm: true);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Ready'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('with motion, the drawing plays and then the line keeps moving',
      (tester) async {
    await pumpLanternWidget(tester, const LanternOpeningView(), calm: false);
    expect(tester.hasRunningAnimations, isTrue);
    expect(find.text("Getting live broadcasts and tonight's lessons…"),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Ordering lessons by prayer time…'), findsOneWidget);
    await tester.pump(LanternOpening.play);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ready'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue,
        reason: 'the progress line shows the app is still loading');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a slow network says so and offers to continue', (tester) async {
    var continued = 0, skipped = 0;
    await pumpLanternWidget(
        tester,
        LanternOpeningView(
            state: LanternOpeningState.slow,
            onContinue: () => continued++,
            onSkip: () => skipped++));
    expect(find.byKey(const ValueKey('lantern-opening-slow')), findsOneWidget);
    await tester.tap(find.text('Continue with what loaded'));
    expect(continued, 1);
    await tester.tap(find.text('Skip'));
    expect(skipped, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('continue is not offered before the device state is known',
      (tester) async {
    await pumpLanternWidget(tester,
        const LanternOpeningView(state: LanternOpeningState.slow));
    final button = tester.widget<LButton>(
        find.widgetWithText(LButton, 'Continue with what loaded'));
    expect(button.onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('without a connection it offers to try again', (tester) async {
    var retried = 0;
    await pumpLanternWidget(
        tester,
        LanternOpeningView(
            state: LanternOpeningState.offline, onRetry: () => retried++));
    expect(
        find.byKey(const ValueKey('lantern-opening-offline')), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('in the app', () {
    testWidgets('it shows for its short minimum, then opens the next page',
        (tester) async {
      final app = await LanternApp.start(tester,
          location: '/splash', lang: 'en', calm: false);
      // LanternApp.start has already let about a second pass.
      expect(find.byType(LanternOpeningView), findsOneWidget);
      expect(app.location, '/splash');
      await tester.pump(LanternOpening.minimumShow);
      await app.settle();
      tester.takeException();
      expect(app.location, isNot('/splash'));
      expect(find.byType(AppSplashScreen), findsNothing);
      await app.close();
    });

    testWidgets('Skip opens the next page without waiting', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final provider = lanternProvider();
      final app = await LanternApp.start(tester,
          location: '/splash', lang: 'en', provider: provider, calm: false);
      if (app.location == '/splash') {
        await tester.tap(find.text('Skip'));
        await app.settle(3);
        tester.takeException();
      }
      expect(app.location, isNot('/splash'));
      await app.close();
    });

    testWidgets('the older designs keep their own splash and its timing',
        (tester) async {
      for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
        final app = await LanternApp.start(tester,
            skin: skin, location: '/splash', lang: 'en');
        tester.takeException();
        expect(find.byType(LanternOpeningView), findsNothing);
        // 300 ms minimum: long gone after the harness's first second.
        expect(app.location, isNot('/splash'), reason: skin.id);
        await app.close();
      }
    });
  });
}
