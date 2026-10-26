import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/config/app_distribution.dart';
import 'package:streamer_app/core/config/app_identity.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/providers/app_update_controller.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/services/app_release_service.dart';
import 'package:streamer_app/core/widgets/app_update_gate.dart';
import 'package:streamer_app/core/widgets/app_update_presenter.dart';
import 'package:streamer_app/features/profile/presentation/settings/about_settings_section.dart';

import 'support/localized_app.dart';

const _listing =
    'https://play.google.com/store/apps/details?id=sa.hadayah.streamer_app';

AppRelease _release(
        {int code = 3,
        int min = 0,
        String name = '1.0.2',
        String? url,
        String notesEn = 'Faster maps',
        String notesAr = 'خرائط أسرع'}) =>
    AppRelease(
        versionCode: code,
        versionName: name,
        minSupportedCode: min,
        downloadUrl:
            Uri.parse(url ?? '${AppIdentity.websiteUrl}/download/$code.apk'),
        notesEn: notesEn,
        notesAr: notesAr);

/// The backend, the installed app and the browser, as the controller sees
/// them.
class _World {
  AppRelease? next;
  Object? error;
  int fetches = 0;
  String? channel;
  Uri? opened;
  bool openResult = true;
  DateTime now = DateTime.utc(2026, 10, 26, 9);

  AppUpdateController controller(
          {AppDistribution distribution = AppDistribution.apk,
          int? build = 2}) =>
      AppUpdateController(
        distribution: distribution,
        fetchLatest: (channel) async {
          fetches++;
          this.channel = channel;
          if (error != null) throw error!;
          return next;
        },
        readInstalled: () async => (version: '1.0.1', build: build),
        openUrl: (url) async {
          opened = url;
          return openResult;
        },
        clock: () => now,
      );
}

Widget _withUpdates(AppUpdateController updates, Widget child,
        {AppProvider? app}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppUpdateController>.value(value: updates),
        if (app != null) ChangeNotifierProvider<AppProvider>.value(value: app),
      ],
      child: localizedApp(home: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('distribution', () {
    test('only apk and play are release channels', () {
      expect(AppDistribution.parse('apk').channel, 'apk');
      expect(AppDistribution.parse('play').channel, 'play');
      expect(AppDistribution.parse('').channel, isNull);
      expect(AppDistribution.parse('APK').channel, isNull);
      expect(AppDistribution.current, AppDistribution.none,
          reason: 'tests are built without DISTRIBUTION');
    });
  });

  group('release links', () {
    test(
        'the APK opens HTTPS links on the website (no backend here) or its Play listing',
        () {
      expect(_release().linkAllowedFor(AppDistribution.apk), isTrue);
      expect(
          _release(url: 'http://stream-application-ten.vercel.app/a.apk')
              .linkAllowedFor(AppDistribution.apk),
          isFalse);
      expect(
          _release(url: 'https://evil.example/a.apk')
              .linkAllowedFor(AppDistribution.apk),
          isFalse);
      expect(
          _release(url: '${AppIdentity.websiteUrl}:8443/a.apk')
              .linkAllowedFor(AppDistribution.apk),
          isFalse);
      expect(
          _release(url: _listing).linkAllowedFor(AppDistribution.apk), isTrue,
          reason: 'the last APK release may send people to Google Play');
      expect(
          _release(url: 'https://play.google.com/store/search?q=hadayah')
              .linkAllowedFor(AppDistribution.apk),
          isFalse);
    });

    test('the Play build opens only its own Play listing', () {
      expect(
          _release(url: _listing).linkAllowedFor(AppDistribution.play), isTrue);
      expect(_release().linkAllowedFor(AppDistribution.play), isFalse);
      expect(
          _release(
                  url:
                      'https://play.google.com/store/apps/details?id=com.other.app')
              .linkAllowedFor(AppDistribution.play),
          isFalse);
      expect(_release().linkAllowedFor(AppDistribution.none), isFalse);
    });

    test('notes fall back to the other language when one is empty', () {
      expect(_release().notes('ar'), 'خرائط أسرع');
      expect(_release(notesAr: '').notes('ar'), 'Faster maps');
      expect(_release(notesEn: ' ').notes('en'), 'خرائط أسرع');
    });

    test('a database row becomes a release', () {
      final release = AppRelease.fromRow({
        'version_code': 7,
        'version_name': '1.1.0',
        'min_supported_code': 5,
        'download_url': '${AppIdentity.websiteUrl}/x.apk',
        'notes_en': 'New',
        'notes_ar': null,
      });
      expect(release.versionCode, 7);
      expect(release.minSupportedCode, 5);
      expect(release.notesAr, '');
    });
  });

  group('AppUpdateController', () {
    test('a build without a distribution never asks, but knows its version',
        () async {
      final world = _World()..next = _release();
      final updates = world.controller(distribution: AppDistribution.none);
      await updates.loadInstalled();
      await updates.check(force: true);
      expect(world.fetches, 0);
      expect(updates.status, AppUpdateStatus.unknown);
      expect(updates.installedVersion, '1.0.1');
      expect(updates.installedBuild, 2);
    });

    test('newer is offered, below the minimum is required, same is current',
        () async {
      final world = _World();
      final updates = world.controller();

      world.next = _release(code: 3, min: 1);
      await updates.check(force: true);
      expect(world.channel, 'apk');
      expect(updates.status, AppUpdateStatus.available);
      expect(updates.promptPending, isTrue);

      world.next = _release(code: 3, min: 3);
      await updates.check(force: true);
      expect(updates.status, AppUpdateStatus.required);
      expect(updates.promptPending, isFalse,
          reason: 'a required update is a page, not a prompt');

      world.next = _release(code: 2, min: 2);
      await updates.check(force: true);
      expect(updates.status, AppUpdateStatus.upToDate);
      expect(updates.release, isNull);

      world.next = null;
      await updates.check(force: true);
      expect(updates.status, AppUpdateStatus.upToDate,
          reason: 'no published release yet');
    });

    test('a failed check keeps what was known, so offline never blocks',
        () async {
      final world = _World()..next = _release();
      final updates = world.controller();
      await updates.check();
      world.error = Exception('offline');
      await updates.check(force: true);
      expect(updates.status, AppUpdateStatus.available);

      final fresh = _World()..error = Exception('offline');
      final first = fresh.controller();
      await first.check();
      expect(first.status, AppUpdateStatus.unknown);
    });

    test('checks at most every six hours unless forced', () async {
      final world = _World()..next = _release();
      final updates = world.controller();
      await updates.check();
      world.now = world.now.add(const Duration(hours: 5));
      await updates.check();
      expect(world.fetches, 1);
      await updates.check(force: true);
      expect(world.fetches, 2);
      world.now = world.now.add(const Duration(hours: 6));
      await updates.check();
      expect(world.fetches, 3);
    });

    test('an install whose version cannot be read never asks', () async {
      final world = _World()..next = _release(min: 3);
      final updates = world.controller(build: null);
      await updates.check(force: true);
      expect(world.fetches, 0);
      expect(updates.status, AppUpdateStatus.unknown);
    });

    test('Later is remembered for that release on this device', () async {
      final world = _World()..next = _release(code: 3);
      final updates = world.controller();
      await updates.check();
      await updates.dismiss();
      expect(updates.promptPending, isFalse);
      expect(updates.status, AppUpdateStatus.available,
          reason: 'Settings still offers it');

      final restarted = world.controller();
      await restarted.check();
      expect(restarted.promptPending, isFalse);

      world.next = _release(code: 4, name: '1.0.3');
      await restarted.check(force: true);
      expect(restarted.promptPending, isTrue, reason: 'a newer release asks');
    });

    test('a link outside the website or storage is ignored', () async {
      final world = _World()
        ..next = _release(min: 3, url: 'https://evil.example/hadayah.apk');
      final updates = world.controller();
      await updates.check();
      expect(updates.status, AppUpdateStatus.upToDate);
      expect(await updates.openDownload(), isFalse);
      expect(world.opened, isNull);
    });

    test('the Play build reads its channel and opens only its listing',
        () async {
      final world = _World()..next = _release();
      final updates = world.controller(distribution: AppDistribution.play);
      await updates.check();
      expect(world.channel, 'play');
      expect(updates.status, AppUpdateStatus.upToDate,
          reason: 'an APK link is never offered on Play');

      world.next = _release(url: _listing);
      await updates.check(force: true);
      expect(updates.status, AppUpdateStatus.available);
      expect(await updates.openDownload(), isTrue);
      expect(world.opened.toString(), _listing);
    });
  });

  group('update required page', () {
    testWidgets('covers the app and opens the download', (tester) async {
      final world = _World()..next = _release(min: 3);
      final updates = world.controller();
      var behind = 0;
      await tester.pumpWidget(_withUpdates(
          updates,
          AppUpdateGate(
              child: Scaffold(
                  body: Center(
                      child: TextButton(
                          onPressed: () => behind++,
                          child: const Text('Behind')))))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-required-page')), findsNothing);

      await updates.check();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-required-page')), findsOneWidget);
      expect(find.text('update.required_title'.tr()), findsOneWidget);
      expect(
          find.text('update.versions'
              .tr(namedArgs: {'current': '1.0.1', 'latest': '1.0.2'})),
          findsOneWidget);
      expect(find.text('Faster maps'), findsOneWidget);

      await tester.tap(find.text('Behind'), warnIfMissed: false);
      expect(behind, 0, reason: 'the app below cannot be used');

      await tester.tap(find.byKey(const Key('update-required-download')));
      await tester.pumpAndSettle();
      expect(world.opened, _release().downloadUrl);
      expect(find.text('update.open_failed'.tr()), findsNothing);

      world.next = _release(min: 1);
      await tester.tap(find.byKey(const Key('update-required-check')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-required-page')), findsNothing,
          reason: 'the minimum was lowered again');
      await tester.tap(find.text('Behind'));
      expect(behind, 1);
    });

    testWidgets('says so when the link cannot be opened, in Arabic too',
        (tester) async {
      final world = _World()
        ..next = _release(min: 3)
        ..openResult = false;
      final updates = world.controller();
      await updates.check();
      await tester.pumpWidget(
          _withUpdates(updates, const AppUpdateGate(child: SizedBox.expand())));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(UpdateRequiredPage));
      await context.setLocale(const Locale('ar'));
      await tester.pumpAndSettle();
      expect(find.text('خرائط أسرع'), findsOneWidget);
      await tester.tap(find.byKey(const Key('update-required-download')));
      await tester.pumpAndSettle();
      expect(find.text('update.open_failed'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('waits until a phone broadcast has ended', (tester) async {
      final world = _World()..next = _release(min: 3);
      final updates = world.controller();
      final app = AppProvider()..setPitchDirectorMode(true);
      await updates.check();
      await tester.pumpWidget(_withUpdates(
          updates, const AppUpdateGate(child: SizedBox.expand()),
          app: app));
      await tester.pumpAndSettle();
      expect(app.isBroadcastingLive, isTrue);
      expect(find.byKey(const Key('update-required-page')), findsNothing);

      app.setPitchDirectorMode(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('update-required-page')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    testWidgets('fits a small phone with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final world = _World()
        ..next = _release(min: 3, notesEn: List.filled(30, 'Fixes.').join(' '));
      final updates = world.controller();
      await updates.check();
      await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 568), textScaler: TextScaler.linear(2)),
          child: _withUpdates(
              updates, const AppUpdateGate(child: SizedBox.expand()))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('update-required-page')), findsOneWidget);
    });
  });

  group('Settings', () {
    testWidgets('shows the installed version and a published update',
        (tester) async {
      final world = _World()..next = _release();
      final updates = world.controller();
      await updates.check();
      await tester.pumpWidget(_withUpdates(
          updates,
          const Scaffold(
              body: SingleChildScrollView(child: AboutSettingsSection()))));
      await tester.pumpAndSettle();
      expect(
          find.text('settings.build_version'
              .tr(namedArgs: {'version': '1.0.1', 'build': '2'})),
          findsOneWidget);
      expect(
          find.text(
              'update.settings_available'.tr(namedArgs: {'version': '1.0.2'})),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-update-download')));
      await tester.pumpAndSettle();
      expect(world.opened, _release().downloadUrl);

      world.next = null;
      await updates.check(force: true);
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('settings-update-latest')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('settings-update-download')), findsNothing);
    });

    testWidgets('a build that never checks shows no update row',
        (tester) async {
      final updates = _World().controller(distribution: AppDistribution.none);
      await updates.loadInstalled();
      await tester.pumpWidget(_withUpdates(
          updates,
          const Scaffold(
              body: SingleChildScrollView(child: AboutSettingsSection()))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-installed-version')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('settings-update-latest')), findsNothing);
      expect(
          find.byKey(const ValueKey('settings-update-download')), findsNothing);
    });
  });

  group('update prompt', () {
    Future<(AppProvider, AppUpdatePresenter)> launch(
        WidgetTester tester, AppUpdateController updates) async {
      final provider = AppProvider();
      final router = AppRouter.build(provider);
      final presenter = AppUpdatePresenter(
          updates: updates, provider: provider, router: router)
        ..attach();
      addTearDown(() async {
        presenter.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        provider.dispose();
      });
      await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: Builder(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider<AppProvider>.value(value: provider),
              ChangeNotifierProvider<AppUpdateController>.value(value: updates),
            ],
            child: MaterialApp.router(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            ),
          ),
        ),
      ));
      router.go('/feed');
      await settle(tester);
      return (provider, presenter);
    }

    testWidgets('offers a release once on a main tab and remembers Later',
        (tester) async {
      final world = _World()..next = _release();
      final updates = world.controller();
      await launch(tester, updates);
      expect(find.byKey(const Key('update-available-dialog')), findsNothing);

      await updates.check();
      await settle(tester);
      expect(find.byKey(const Key('update-available-dialog')), findsOneWidget);
      expect(
          find.text(
              'update.available_body'.tr(namedArgs: {'version': '1.0.2'})),
          findsOneWidget);
      expect(find.text('Faster maps'), findsOneWidget);

      await tester.tap(find.byKey(const Key('update-available-later')));
      await settle(tester);
      expect(find.byKey(const Key('update-available-dialog')), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt(AppUpdateController.dismissedKey), 3);

      await updates.check(force: true);
      await settle(tester);
      expect(find.byKey(const Key('update-available-dialog')), findsNothing,
          reason: 'Later is not asked again for the same release');
      expect(world.opened, isNull);
    });

    testWidgets('closing it with Back also counts as Later', (tester) async {
      final world = _World()..next = _release();
      final updates = world.controller();
      await launch(tester, updates);
      await updates.check();
      await settle(tester);
      expect(find.byKey(const Key('update-available-dialog')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.byKey(const Key('update-available-dialog')), findsNothing);
      expect(updates.promptPending, isFalse);
    });

    testWidgets('Download opens the link; the prompt waits for a broadcast',
        (tester) async {
      final world = _World()..next = _release();
      final updates = world.controller();
      final (provider, _) = await launch(tester, updates);
      provider.setPitchDirectorMode(true);
      await updates.check();
      await settle(tester);
      expect(find.byKey(const Key('update-available-dialog')), findsNothing);

      provider.setPitchDirectorMode(false);
      await settle(tester);
      expect(find.byKey(const Key('update-available-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('update-available-download')));
      await settle(tester);
      expect(world.opened, _release().downloadUrl);
      expect(updates.promptPending, isFalse);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
