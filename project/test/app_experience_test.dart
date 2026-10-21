import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_experience.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/profile/presentation/settings/about_settings_section.dart';

import 'support/localized_app.dart';

class _FailingStore extends Fake implements SharedPreferences {
  @override
  String? getString(String key) => null;
  @override
  bool containsKey(String key) => false;
  @override
  Future<bool> setString(String key, String value) async => false;
}

/// Settings' About card inside a router, so the logo can navigate.
Widget _settings(AppExperience experience, List<String> visited) {
  final router = GoRouter(initialLocation: '/settings', routes: [
    GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: AboutSettingsSection())),
    for (final e in Experience.values)
      GoRoute(
          path: e.home,
          builder: (_, __) {
            visited.add(e.home);
            return Text('home ${e.name}');
          }),
  ]);
  return ChangeNotifierProvider<AppExperience>.value(
    value: experience,
    child: EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: Builder(
          builder: (context) => MaterialApp.router(
                theme: AppTheme.forLocale(context.locale),
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                routerConfig: router,
              )),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('starts on Hadayah Live and keeps each choice across restarts',
      () async {
    final first = AppExperience();
    await first.restore();
    expect(first.current, Experience.hadayah);
    expect(await first.toggle(), Experience.taysir);

    final restarted = AppExperience();
    await restarted.restore();
    expect(restarted.taysir, isTrue);
    expect(await restarted.toggle(), Experience.hadayah);

    final again = AppExperience();
    await again.restore();
    expect(again.current, Experience.hadayah);
  });

  test('the retired palette preference is removed and does not switch apps',
      () async {
    SharedPreferences.setMockInitialValues(
        {AppExperience.legacyPaletteKey: true});
    final experience = AppExperience();
    await experience.restore();
    expect(experience.current, Experience.hadayah);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(AppExperience.legacyPaletteKey), isFalse);
  });

  test('a failed save keeps the current application', () async {
    final experience = AppExperience(preferences: _FailingStore());
    await experience.restore();
    await expectLater(experience.toggle(), throwsStateError);
    expect(experience.current, Experience.hadayah);
  });

  test('gold is the only theme: ivory pages, bronze primary, Plex Arabic', () {
    for (final lang in ['en', 'ar']) {
      final theme = AppTheme.forLocale(Locale(lang));
      expect(theme.scaffoldBackgroundColor, HidayahGold.g50);
      expect(theme.colorScheme.primary, HidayahGold.g700);
      expect(theme.textTheme.bodyLarge!.fontFamily, HidayahType.text);
    }
    expect(Canopy.brandGreen, HidayahGold.g700);
    expect(CanopyGradients.pill, HidayahGradients.minted);
  });

  testWidgets('tapping the Settings logo opens Taysir, and again returns',
      (tester) async {
    final experience = AppExperience();
    await experience.restore();
    final visited = <String>[];
    await tester.pumpWidget(_settings(experience, visited));
    await tester.pumpAndSettle();

    expect(find.text('Tap the logo to open Taysir, the mosque lessons programme.'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-experience-toggle')));
    await tester.pumpAndSettle();
    expect(experience.taysir, isTrue);
    expect(visited.last, '/taysir');

    // Back on Settings, the hint now offers the way home.
    await tester.pumpWidget(_settings(experience, visited));
    await tester.pumpAndSettle();
    expect(find.text('Tap the logo to return to Hadayah Live.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-experience-toggle')));
    await tester.pumpAndSettle();
    expect(experience.current, Experience.hadayah);
    expect(visited.last, '/feed');
  });
}
