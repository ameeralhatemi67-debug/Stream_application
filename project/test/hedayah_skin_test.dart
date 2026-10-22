import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/app_skin_preference.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_icon.dart';
import 'package:streamer_app/core/widgets/ds/ca_navigation.dart';
import 'package:streamer_app/core/widgets/hedayah/hedayah_kit.dart';
import 'package:streamer_app/core/widgets/hedayah/hedayah_motif_data.dart';
import 'package:streamer_app/features/auth/presentation/hedayah_welcome_view.dart';
import 'package:streamer_app/features/auth/presentation/role_select_screen.dart';
import 'package:streamer_app/features/auth/presentation/viewer_setup_screen.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/profile/presentation/settings/appearance_settings_section.dart';
import 'package:streamer_app/features/splash/presentation/app_splash_screen.dart';

import 'support/localized_app.dart';

/// The Hedayah skin (ADR-016): a second design beside gold & black, chosen
/// per device in Settings or by a web link.

/// The app as main.dart builds it: the theme follows the provider's skin.
Widget _app(AppProvider provider, Widget home, {String lang = 'en'}) =>
    EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: Locale(lang),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: Builder(builder: (context) {
              final skin =
                  context.select<AppProvider, AppSkin>((p) => p.appSkin);
              return MaterialApp(
                  theme: AppTheme.forLocale(context.locale, skin: skin),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: true),
                      child: child!),
                  home: home);
            })));

String _assetOf(WidgetTester tester, Finder svg) =>
    (tester.widget<SvgPicture>(svg).bytesLoader as SvgAssetLoader).assetName;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('choosing the skin', () {
    test('stored names, link names and short names all parse', () {
      expect(AppSkin.tryParse('hedayah-skin'), AppSkin.hedayah);
      expect(AppSkin.tryParse('hedayah'), AppSkin.hedayah);
      expect(AppSkin.tryParse('gold-black'), AppSkin.gold);
      expect(AppSkin.tryParse('gold'), AppSkin.gold);
      expect(AppSkin.tryParse('green'), isNull);
      expect(AppSkin.tryParse(null), isNull);
    });

    test('a device starts on gold & black', () async {
      expect(await readAppSkin(link: Uri.parse('https://x.test/')),
          AppSkin.gold);
    });

    test('a saved skin is read back; a web link wins and is remembered',
        () async {
      SharedPreferences.setMockInitialValues(
          {AppSkin.preferenceKey: 'hedayah-skin'});
      expect(await readAppSkin(link: Uri.parse('https://x.test/')),
          AppSkin.hedayah);
      expect(
          await readAppSkin(
              link: Uri.parse('https://x.test/?skin=gold-black#/welcome')),
          AppSkin.gold);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(AppSkin.preferenceKey), 'gold-black');
    });

    test('the provider switches, notifies and saves', () async {
      final provider = AppProvider();
      addTearDown(provider.dispose);
      provider.restoreAppSkin(AppSkin.hedayah);
      expect(provider.appSkin, AppSkin.hedayah);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey(AppSkin.preferenceKey), isFalse,
          reason: 'restoring the start-up skin saves nothing');
      var notified = false;
      provider.addListener(() => notified = true);
      await provider.setAppSkin(AppSkin.gold);
      expect(notified, isTrue);
      expect(provider.appSkin, AppSkin.gold);
      expect(preferences.getString(AppSkin.preferenceKey), 'gold-black');
      await provider.setAppSkin(AppSkin.hedayah);
      expect(preferences.getString(AppSkin.preferenceKey), 'hedayah-skin');
    });
  });

  group('the Hedayah theme', () {
    test('mist pages, Readex Pro headings, gold pills with ink', () {
      for (final lang in ['en', 'ar']) {
        final theme =
            AppTheme.forLocale(Locale(lang), skin: AppSkin.hedayah);
        expect(theme.extension<AppSkinTheme>()!.skin, AppSkin.hedayah);
        expect(theme.scaffoldBackgroundColor, HedayahSkin.mist);
        expect(theme.colorScheme.primary, HedayahSkin.bronze);
        expect(theme.textTheme.titleLarge!.fontFamily, HedayahSkin.display);
        expect(theme.textTheme.bodyLarge!.fontFamily, HedayahSkin.text);
        final button = theme.elevatedButtonTheme.style!;
        expect(button.backgroundColor!.resolve({}), HedayahSkin.gold);
        expect(button.foregroundColor!.resolve({}), HedayahSkin.ink);
        expect(button.shape!.resolve({}), isA<StadiumBorder>());
      }
    });

    test('gold & black is unchanged and says so', () {
      final theme = AppTheme.forLocale(const Locale('en'));
      expect(theme.extension<AppSkinTheme>()!.skin, AppSkin.gold);
      expect(theme.scaffoldBackgroundColor, HidayahGold.g50);
      expect(theme.colorScheme.primary, HidayahGold.g700);
    });

    test('every glyph has a Hedayah drawing of the same name', () {
      for (final glyph in CaGlyph.values) {
        final file = File('assets/hedayah/icons/${glyph.name}.svg');
        expect(file.existsSync(), isTrue, reason: glyph.name);
        expect(file.readAsStringSync(), startsWith('<svg'));
      }
    });

    test('the pattern motif decodes inside its 19.66 mm square', () {
      expect(hedayahMotifPaths, isNotEmpty);
      for (final entry in hedayahMotifPaths) {
        expect(entry.d.first, 0, reason: 'each path starts with a move');
      }
      final xs = [
        for (final entry in hedayahMotifPaths)
          for (var i = 0; i < entry.d.length; i++)
            if (entry.d[i] != 3) entry.d[i]
      ];
      expect(xs.reduce((a, b) => a > b ? a : b),
          lessThanOrEqualTo(hedayahMotifSize + .5));
    });

    test('the new labels exist in both languages', () {
      final en = jsonDecode(File('assets/i18n/en.json').readAsStringSync());
      final ar = jsonDecode(File('assets/i18n/ar.json').readAsStringSync());
      expect((en['skin'] as Map).keys.toSet(), (ar['skin'] as Map).keys.toSet());
      expect(ar['skin']['hedayah'], 'هداية');
    });
  });

  group('the lattice stays light to draw', () {
    testWidgets('a whole band is one repeating image, not motif by motif',
        (tester) async {
      await tester.pumpWidget(const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 1440, height: 900, child: HedayahPattern())));
      final paint = find.descendant(
          of: find.byType(HedayahPattern), matching: find.byType(CustomPaint));
      // Replaying every motif drew ~1,000 pictures (67 paths each) a frame on
      // a laptop-sized band; scrolling lagged on the web.
      expect(paint, paintsExactlyCountTimes(#drawPicture, 0));
      expect(paint, paintsExactlyCountTimes(#drawPath, 0));
      expect(paint, paintsExactlyCountTimes(#drawRect, 1));
    });
  });

  group('screens', () {
    testWidgets('icons come from the skin\'s set', (tester) async {
      final provider = AppProvider();
      addTearDown(provider.dispose);
      await tester.pumpWidget(
          _app(provider, const Scaffold(body: CaIcon(CaGlyph.gear))));
      await tester.pumpAndSettle();
      expect(_assetOf(tester, find.byType(SvgPicture)),
          'assets/canopy/icons/gear.svg');
      await provider.setAppSkin(AppSkin.hedayah);
      await tester.pumpAndSettle();
      expect(_assetOf(tester, find.byType(SvgPicture)),
          'assets/hedayah/icons/gear.svg');
    });

    testWidgets('the Hedayah sign-in page: lockup, tagline and pill actions',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = AppProvider()..restoreAppSkin(AppSkin.hedayah);
      addTearDown(provider.dispose);
      final router = GoRouter(initialLocation: '/welcome', routes: [
        GoRoute(
            path: '/welcome', builder: (context, state) => const WelcomeScreen()),
        GoRoute(path: '/feed', builder: (context, state) => const Text('feed')),
        GoRoute(
            path: '/viewer-setup',
            builder: (context, state) => const Text('name-form')),
      ]);
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ar')],
          startLocale: const Locale('ar'),
          saveLocale: false,
          path: 'assets/i18n',
          assetLoader: const DirectJsonAssetLoader(),
          child: ChangeNotifierProvider<AppProvider>.value(
              value: provider,
              child: Builder(
                  builder: (context) => MaterialApp.router(
                      routerConfig: router,
                      theme: AppTheme.forLocale(context.locale,
                          skin: AppSkin.hedayah),
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(disableAnimations: true),
                          child: child!))))));
      await tester.pumpAndSettle();
      expect(find.byType(HedayahWelcomeView), findsOneWidget);
      expect(find.byType(HedayahWordmark), findsOneWidget);
      expect(find.byType(HedayahRosette), findsWidgets);
      expect(find.text('skin.tagline'.tr()), findsOneWidget);
      expect(find.byKey(const Key('welcome-signup')), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gold & black keeps its own sign-in page', (tester) async {
      final provider = AppProvider();
      addTearDown(provider.dispose);
      await tester.pumpWidget(_app(provider, const WelcomeScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(HedayahWelcomeView), findsNothing);
      expect(find.byKey(const Key('welcome-signup')), findsOneWidget);
    });

    testWidgets('Settings → Design switches the whole app and remembers it',
        (tester) async {
      final provider = AppProvider();
      addTearDown(provider.dispose);
      await tester.pumpWidget(_app(
          provider,
          const Scaffold(
              body: SingleChildScrollView(
                  child: AppearanceSettingsSection()))));
      await tester.pumpAndSettle();
      expect(find.text('skin.title'.tr()), findsOneWidget);
      final hedayahTile =
          find.byKey(const ValueKey('skin-option-hedayah-skin'));
      expect(tester.getSemantics(hedayahTile),
          isSemantics(isSelected: false));
      await tester.tap(hedayahTile);
      await tester.pumpAndSettle();
      expect(provider.appSkin, AppSkin.hedayah);
      expect(
          tester
              .element(find.byType(AppearanceSettingsSection))
              .isHedayahSkin,
          isTrue);
      expect(tester.getSemantics(hedayahTile),
          isSemantics(isSelected: true));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(AppSkin.preferenceKey), 'hedayah-skin');
      await tester.tap(find.byKey(const ValueKey('skin-option-gold-black')));
      await tester.pumpAndSettle();
      expect(provider.appSkin, AppSkin.gold);
    });

    testWidgets('the Hedayah tab bar marks the chosen tab', (tester) async {
      final provider = AppProvider()..restoreAppSkin(AppSkin.hedayah);
      addTearDown(provider.dispose);
      var chosen = -1;
      await tester.pumpWidget(_app(
          provider,
          Scaffold(
              bottomNavigationBar:
                  CaNavBar(index: 1, onChanged: (i) => chosen = i))));
      await tester.pumpAndSettle();
      expect(
          find.byWidgetPredicate((w) =>
              w is Semantics && w.properties.selected == true &&
              w.properties.label == 'nav.map'.tr()),
          findsOneWidget);
      await tester.tap(find.text('nav.lessons'.tr()));
      expect(chosen, 2);
    });
  });

  group('entry screens fit', () {
    // A small phone, a phone on its side, and a laptop window; both languages.
    const sizes = [Size(320, 568), Size(740, 360), Size(1280, 800)];

    Future<void> pumpRoute(WidgetTester tester, String location, Size size,
        String lang) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = AppProvider()..restoreAppSkin(AppSkin.hedayah);
      addTearDown(provider.dispose);
      final router = GoRouter(initialLocation: location, routes: [
        GoRoute(
            path: '/splash',
            builder: (context, state) => const AppSplashScreen()),
        GoRoute(
            path: '/welcome', builder: (context, state) => const WelcomeScreen()),
        GoRoute(
            path: '/viewer-setup',
            builder: (context, state) => const ViewerSetupScreen()),
        GoRoute(
            path: '/role-select',
            builder: (context, state) => const RoleSelectScreen()),
        GoRoute(path: '/feed', builder: (context, state) => const Text('feed')),
      ]);
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ar')],
          startLocale: Locale(lang),
          saveLocale: false,
          path: 'assets/i18n',
          assetLoader: const DirectJsonAssetLoader(),
          child: ChangeNotifierProvider<AppProvider>.value(
              value: provider,
              child: Builder(
                  builder: (context) => MaterialApp.router(
                      routerConfig: router,
                      theme: AppTheme.forLocale(context.locale,
                          skin: AppSkin.hedayah),
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(disableAnimations: true),
                          child: child!))))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    for (final location in ['/splash', '/welcome', '/viewer-setup', '/role-select']) {
      for (final size in sizes) {
        for (final lang in ['ar', 'en']) {
          testWidgets('$location at ${size.width.toInt()}x${size.height.toInt()} '
              '($lang)', (tester) async {
            await pumpRoute(tester, location, size, lang);
            expect(tester.takeException(), isNull);
            // Let the splash's timer move on, so no timer is left pending.
            await tester.pump(const Duration(seconds: 3));
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
