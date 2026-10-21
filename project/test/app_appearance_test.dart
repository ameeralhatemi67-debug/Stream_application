import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/theme/app_appearance.dart';
import 'package:streamer_app/core/theme/app_launcher_icon.dart';
import 'package:streamer_app/core/widgets/app_logo.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/features/profile/presentation/settings/about_settings_section.dart';
import 'package:streamer_app/main.dart' as entry;

import 'support/localized_app.dart';

class _FailingStore extends Fake implements SharedPreferences {
  bool fail = true;
  bool? saved;

  @override
  bool? getBool(String key) => saved;

  @override
  Future<bool> setBool(String key, bool value) async {
    if (fail) return false;
    saved = value;
    return true;
  }
}

Widget _harness(AppAppearance appearance) =>
    ChangeNotifierProvider<AppAppearance>.value(
      value: appearance,
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('ar'),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.forLocale(context.locale,
                hidayah: context.select<AppAppearance, bool>((p) => p.hidayah)),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const _Fixture(),
          ),
        ),
      ),
    );

class _Fixture extends StatelessWidget {
  const _Fixture();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        key: const ValueKey('palette-capture'),
        child: Scaffold(
          backgroundColor: paletteColor(context, Canopy.dawn),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const AboutSettingsSection(),
                  const SizedBox(height: 24),
                  CaButton(label: 'ابدأ البث', onPressed: () {}),
                  const SizedBox(height: 24),
                  const TextField(key: ValueKey('preserved-input')),
                ],
              ),
            ),
          ),
        ),
      );
}

Future<void> _doubleTap(WidgetTester tester) async {
  final logo = find.byKey(const ValueKey('settings-palette-toggle'));
  await tester.tap(logo);
  await tester.pump(const Duration(milliseconds: 80));
  await tester.tap(logo);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['PALETTE_SCREENSHOT_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('palette-capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final pair in [
      ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-400.ttf'),
      ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-700.ttf'),
      ('IBM Plex Sans', 'assets/fonts/IBMPlexSans-Variable.ttf'),
    ]) {
      await (FontLoader(pair.$1)..addFont(rootBundle.load(pair.$2))).load();
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLauncherIcon.channel, (_) async => null);
    await EasyLocalization.ensureInitialized();
  });

  test('each palette choice survives a new appearance instance', () async {
    final appearance = AppAppearance();
    await appearance.restore();
    expect(appearance.hidayah, isFalse);
    await appearance.toggle();
    final restarted = AppAppearance();
    await restarted.restore();
    expect(restarted.hidayah, isTrue);
    await restarted.toggle();
    final restartedAgain = AppAppearance();
    await restartedAgain.restore();
    expect(restartedAgain.hidayah, isFalse);
    appearance.dispose();
    restarted.dispose();
    restartedAgain.dispose();
  });

  test('rapid toggles persist in order and preserve other preferences',
      () async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final appearance = AppAppearance();
    await appearance.restore();
    await Future.wait([appearance.toggle(), appearance.toggle()]);
    final store = await SharedPreferences.getInstance();
    expect(appearance.hidayah, isFalse);
    expect(store.getBool(AppAppearance.preferenceKey), isFalse);
    expect(store.getString('locale'), 'en');
    appearance.dispose();
  });

  test('a failed save keeps the current palette and the next save can work',
      () async {
    final store = _FailingStore();
    final appearance = AppAppearance(preferences: store);
    await appearance.restore();
    await expectLater(appearance.toggle(), throwsStateError);
    expect(appearance.hidayah, isFalse);
    expect(store.saved, isNull);
    store.fail = false;
    await appearance.toggle();
    expect(appearance.hidayah, isTrue);
    expect(store.saved, isTrue);
    appearance.dispose();
  });

  test('disposing during a save still persists without notifying a dead widget',
      () async {
    final appearance = AppAppearance();
    final save = appearance.toggle();
    appearance.dispose();
    await save;
    final restarted = AppAppearance();
    await restarted.restore();
    expect(restarted.hidayah, isTrue);
    restarted.dispose();
  });

  test('launcher receives the saved choice on restore and both toggles',
      () async {
    final choices = <bool>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLauncherIcon.channel, (call) async {
      expect(call.method, 'setHidayahIcon');
      final enabled = (call.arguments as Map)['enabled'] as bool;
      final store = await SharedPreferences.getInstance();
      expect(store.getBool(AppAppearance.preferenceKey) ?? false, enabled);
      choices.add(enabled);
      return null;
    });
    final first = AppAppearance();
    await first.restore();
    await first.toggle();
    final restarted = AppAppearance();
    await restarted.restore();
    await restarted.toggle();
    expect(choices, [false, true, true, false]);
    first.dispose();
    restarted.dispose();
  });

  test('launcher failure preserves the saved palette and allows another toggle',
      () async {
    var fail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLauncherIcon.channel, (_) async {
      if (fail) throw PlatformException(code: 'launcher_icon_failed');
      return null;
    });
    final appearance = AppAppearance();
    await expectLater(
        appearance.toggle(), throwsA(isA<LauncherIconException>()));
    expect(appearance.hidayah, isTrue);
    expect(
        (await SharedPreferences.getInstance())
            .getBool(AppAppearance.preferenceKey),
        isTrue);
    fail = false;
    await appearance.toggle();
    expect(appearance.hidayah, isFalse);
    appearance.dispose();
  });

  test('gold palette preserves opacity, gradient geometry, contrast and fonts',
      () {
    const gold = AppPalette(hidayah: true);
    final normal = AppTheme.forLocale(const Locale('en'));
    final themed = AppTheme.forLocale(const Locale('en'), hidayah: true);
    expect(normal.colorScheme.primary, AppTheme.primary);
    expect(themed.colorScheme.primary, AppPalette.goldInk);
    expect(themed.textTheme.bodyLarge!.fontFamily, 'IBM Plex Sans Arabic');
    expect(normal.textTheme.bodyLarge!.fontFamily, 'IBM Plex Sans');
    expect(gold.color(AppTheme.shadowSoft).a, AppTheme.shadowSoft.a);
    // The green panel becomes the night slate panel (a designed gradient,
    // not a hue swap), and accent pills become the minted gold lit from the
    // top, so they read the same in Arabic and English.
    expect(gold.gradient(AppGradients.panel), HidayahGradients.night);
    expect(gold.gradient(CanopyGradients.canopy), HidayahGradients.night);
    expect(gold.gradient(AppGradients.pill), HidayahGradients.minted);
    expect(HidayahGradients.minted.begin, Alignment.topCenter);
    expect(HidayahGradients.minted.end, Alignment.bottomCenter);
    for (final background in [AppPalette.ivory, AppPalette.paper]) {
      for (final foreground in [
        AppTheme.textPrimary,
        AppTheme.textSecondary,
        AppTheme.textMuted,
        AppTheme.primary
      ]) {
        final a = gold.color(foreground).computeLuminance();
        final b = background.computeLuminance();
        expect((b + .05) / (a + .05), greaterThanOrEqualTo(4.5));
      }
    }
    expect(gold.gradient(AppGradients.pill).colors.last, AppPalette.gold);
    const translucent = LinearGradient(colors: [
      Color(0x4417643F), Color(0x88327044),
    ]);
    // A translucent accent stays translucent once redesigned.
    expect(gold.gradient(translucent).colors.every((c) => c.a < .3), isTrue);
    // Gold never carries small text on ivory; bronze does.
    expect(
        (AppPalette.ivory.computeLuminance() + .05) /
            (AppPalette.gold.computeLuminance() + .05),
        lessThan(3));
    expect(
        (AppPalette.ivory.computeLuminance() + .05) /
            (AppPalette.goldInk.computeLuminance() + .05),
        greaterThanOrEqualTo(4.5));
    // Selected chips and tabs use ink with pale gold, well above 4.5:1.
    expect(
        (HidayahGold.g200.computeLuminance() + .05) /
            (HidayahGold.s800.computeLuminance() + .05),
        greaterThanOrEqualTo(7));
    for (final background in gold.gradient(AppGradients.pill).colors) {
      expect(
          (background.computeLuminance() + .05) /
              (AppPalette.ink.computeLuminance() + .05),
          greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('the existing Settings logo needs two clicks and preserves state',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appearance = AppAppearance();
    await appearance.restore();
    await tester.pumpWidget(_harness(appearance));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('preserved-input'));
    await tester.runAsync(() => precacheImage(
        const AssetImage(AppLogo.hidayahAsset), tester.element(input)));
    await tester.pumpAndSettle();
    await tester.enterText(input, 'تبقى هذه الكتابة');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final before = tester.state(input);
    final normalColor = Theme.of(tester.element(input)).colorScheme.primary;
    await tester.tap(find.byKey(const ValueKey('settings-palette-toggle')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(appearance.hidayah, isFalse);
    await _capture(tester, 'normal-palette');
    await _doubleTap(tester);
    expect(appearance.hidayah, isTrue);
    final logoImage = tester.widget<Image>(find.descendant(
        of: find.byType(AppLogo), matching: find.byType(Image)));
    expect((logoImage.image as AssetImage).assetName,
        'assets/logo/hidayah_mark.png');
    expect(
        tester
            .widget<RawImage>(find.descendant(
                of: find.byType(AppLogo), matching: find.byType(RawImage)))
            .image,
        isNotNull);
    expect(Theme.of(tester.element(input)).colorScheme.primary,
        AppPalette.goldInk);
    expect(identical(before, tester.state(input)), isTrue);
    expect(find.text('تبقى هذه الكتابة'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance())
            .getBool(AppAppearance.preferenceKey),
        isTrue);
    await _capture(tester, 'hidayah-palette');
    final context = tester.element(input);
    await context.setLocale(const Locale('en'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(input)).textTheme.bodyLarge!.fontFamily,
        'IBM Plex Sans Arabic');
    await _doubleTap(tester);
    expect(appearance.hidayah, isFalse);
    expect(Theme.of(tester.element(input)).colorScheme.primary, normalColor);
    expect(context.locale.languageCode, 'en');
    await tester.pumpWidget(const SizedBox.shrink());
    appearance.dispose();
  });

  testWidgets('fresh startup defaults to Arabic and restores the palette',
      (tester) async {
    SharedPreferences.setMockInitialValues({AppAppearance.preferenceKey: true});
    await entry.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final localization =
        tester.widget<EasyLocalization>(find.byType(EasyLocalization));
    expect(localization.startLocale, const Locale('ar'));
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.locale, const Locale('ar'));
    expect(material.theme!.extension<AppPalette>()!.hidayah, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('startup retains a saved English language choice',
      (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    await entry.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.locale, const Locale('en'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
