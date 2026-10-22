import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/services/retired_preferences.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/profile/presentation/settings/about_settings_section.dart';

import 'support/localized_app.dart';

/// The palette toggle (ADR-013) and the Hadayah Live / Taysir app switch
/// are gone: gold is the only design and Taysir is part of the app
/// (ADR-014). Devices that used either lose the old setting on start.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);

  test('a device that had chosen Taysir or a palette forgets it', () async {
    SharedPreferences.setMockInitialValues({
      'app_experience': 'taysir',
      'hidayah_palette_enabled': true,
      'unrelated': 'kept',
    });
    await forgetRetiredPreferences();
    final preferences = await SharedPreferences.getInstance();
    for (final key in retiredPreferenceKeys) {
      expect(preferences.containsKey(key), isFalse, reason: key);
    }
    expect(preferences.getString('unrelated'), 'kept');
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

  testWidgets('the Settings logo is only the logo now', (tester) async {
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: Builder(
          builder: (context) => MaterialApp(
                theme: AppTheme.forLocale(context.locale),
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: const Scaffold(body: AboutSettingsSection()),
              )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-experience-toggle')),
        findsNothing);
    expect(find.textContaining('Taysir'), findsNothing);
    expect(find.text('Hadayah Live'), findsOneWidget);
  });
}
