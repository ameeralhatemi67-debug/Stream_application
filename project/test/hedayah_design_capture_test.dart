import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/app_logo.dart';
import 'package:streamer_app/core/widgets/hedayah/hedayah_kit.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/profile/presentation/settings/appearance_settings_section.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';

/// Side-by-side review screenshots of the two designs (ADR-016), written to
/// SKIN_CAPTURE_DIR with the real fonts through the app's own router.
/// Skipped when the variable is unset.
final _dir = Platform.environment['SKIN_CAPTURE_DIR'];

AppProvider _provider(AppSkin skin) {
  final provider = AppProvider()..restoreAppSkin(skin);
  for (final (i, s) in mockStreamers.indexed) {
    provider.addStreamerForTests(i == 0
        ? s.copyWith(
            isCurrentlyLive: true,
            broadcastType: BroadcastType.liveVideo,
            activeStreamId: 'stream-skin-1')
        : s);
  }
  return provider;
}

Future<void> _shot(WidgetTester tester, String name,
    {required AppSkin skin,
    required Size size,
    String? location,
    Widget? screen,
    String lang = 'ar',
    int frames = 6}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final provider = _provider(skin);
  final lessons = LessonsController(DemoLessonsRepository());
  final router = AppRouter.build(provider);
  Widget frame(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: RepaintBoundary(key: const ValueKey('capture'), child: child!));
  await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: provider),
            ChangeNotifierProvider<LessonsController>.value(value: lessons),
          ],
          child: Builder(
              builder: (context) => screen != null
                  ? MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: AppTheme.forLocale(context.locale, skin: skin),
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: frame,
                      home: screen)
                  : MaterialApp.router(
                      debugShowCheckedModeBanner: false,
                      routerConfig: router,
                      theme: AppTheme.forLocale(context.locale, skin: skin),
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: frame)))));
  if (location != null) router.go(location);
  await tester.pump();
  final context = tester.element(find.byKey(const ValueKey('capture')));
  await tester.runAsync(() async {
    for (final s in mockStreamers) {
      for (final path in [s.avatarUrl, s.bannerUrl]) {
        if (path.startsWith('assets/')) {
          await precacheImage(AssetImage(path), context);
        }
      }
    }
    await precacheImage(const AssetImage(AppLogo.hidayahAsset), context);
    await precacheImage(const AssetImage(HedayahWordmark.asset), context);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  await tester.pumpWidget(const SizedBox.shrink());
  // Let the splash's timer and the router settle before the next capture.
  await tester.pump(const Duration(seconds: 3));
  provider.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    for (final pair in [
      ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-400.ttf'),
      ('IBM Plex Sans Arabic', 'assets/fonts/IBMPlexSansArabic-700.ttf'),
      ('IBM Plex Sans', 'assets/fonts/IBMPlexSans-Variable.ttf'),
      ('Reem Kufi', 'assets/fonts/ReemKufi-Variable.ttf'),
      ('Readex Pro', 'assets/fonts/ReadexPro-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(pair.$1)..addFont(rootBundle.load(pair.$2))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final skip = _dir == null;
  const phone = Size(390, 844), laptop = Size(1440, 900);

  for (final skin in AppSkin.values) {
    final tag = skin.id;
    testWidgets('capture $tag', skip: skip, (tester) async {
      await _shot(tester, '01-splash-$tag',
          skin: skin, size: phone, location: '/splash', frames: 3);
      await _shot(tester, '02-welcome-$tag',
          skin: skin, size: phone, location: '/welcome');
      await _shot(tester, '03-welcome-wide-$tag',
          skin: skin, size: laptop, location: '/welcome');
      await _shot(tester, '04-viewer-setup-$tag',
          skin: skin, size: phone, location: '/viewer-setup');
      await _shot(tester, '05-discover-$tag',
          skin: skin, size: phone, location: '/feed');
      await _shot(tester, '06-lessons-$tag',
          skin: skin, size: phone, location: '/lessons');
      await _shot(tester, '07-discover-web-$tag',
          skin: skin, size: const Size(1440, 1400), location: '/feed');
      await _shot(tester, '08-settings-design-$tag',
          skin: skin,
          size: const Size(390, 520),
          screen: const Scaffold(
              body: SafeArea(
                  child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: AppearanceSettingsSection()))));
      await _shot(tester, '09-settings-$tag',
          skin: skin, size: const Size(390, 1400), screen: const SettingsScreen());
      await _shot(tester, '10-role-select-$tag',
          skin: skin, size: phone, location: '/role-select');
      await _shot(tester, '11-map-$tag',
          skin: skin, size: phone, location: '/map');
    });
  }
}
