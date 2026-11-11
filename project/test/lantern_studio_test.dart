import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/core/widgets/ds/ca_fields.dart';
import 'package:streamer_app/core/widgets/interactive_toast_overlay.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/live_stream/presentation/lantern/lantern_studio_view.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';

import 'support/empty_broadcasts.dart';
import 'support/lantern_harness.dart' show loadAppFonts;
import 'support/localized_app.dart';
import 'support/studio_fixture.dart';

/// The broadcast studio in Lantern and Arch (ADR-026): one night page with
/// the status, the three steps and the controls. Going live from a laptop
/// and ending a broadcast are press-and-hold. The studio's state and actions
/// are the ones the older designs use.
const _second = ChannelConnection(
    id: 'connection-2',
    ownerId: 'c',
    organizationId: null,
    channelId: 'UC_two',
    title: 'Second channel',
    status: 'connected',
    revision: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  (AppProvider, StudioDb)? opened;

  Future<void> settle(WidgetTester tester, [int frames = 5]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// The studio for a signed-in broadcaster on the device that holds the
  /// broadcast. Without [broadcasts] no channel is connected.
  Future<AppProvider> pumpStudio(WidgetTester tester,
      {StudioBroadcasts? broadcasts,
      String lang = 'en',
      Size size = const Size(390, 844),
      StudioMode mode = StudioMode.phone,
      double textScale = 1}) async {
    final db = StudioDb();
    final provider = (await tester.runAsync(() => studioBroadcaster(db,
        broadcasts: broadcasts ?? (StudioBroadcasts()..channels = const []))))!
      ..restoreAppSkin(AppSkin.lantern);
    opened = (provider, db);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
        child: EasyLocalization(
            key: UniqueKey(),
            supportedLocales: const [Locale('en'), Locale('ar')],
            startLocale: Locale(lang),
            saveLocale: false,
            path: 'assets/i18n',
            assetLoader: const DirectJsonAssetLoader(),
            child: ChangeNotifierProvider<AppProvider>.value(
                value: provider,
                child: Builder(
                    builder: (context) => MaterialApp(
                        debugShowCheckedModeBanner: false,
                        theme: LanternSkin.theme(context.locale),
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                                disableAnimations: true,
                                textScaler: TextScaler.linear(textScale)),
                            child: child!),
                        home: Scaffold(
                            body: LiveBroadcasterStudioSheet(
                                initialMode: mode))))))));
    await settle(tester);
    return provider;
  }

  /// Takes the studio down the way the app does, so the grace timer of a
  /// prepared broadcast ends with the provider.
  Future<void> close(WidgetTester tester) async {
    InteractiveToastOverlay.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    final (provider, db) = opened!;
    opened = null;
    provider.dispose();
    await db.devices.close();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> hold(WidgetTester tester, Finder button) async {
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 100));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(Lantern.hold + const Duration(milliseconds: 100));
    await gesture.up();
    await settle(tester);
  }

  for (final lang in ['en', 'ar']) {
    for (final (label, size, scale) in [
      ('phone', const Size(390, 844), 1.0),
      ('small phone, large text', const Size(360, 720), 1.5),
      ('laptop', const Size(1440, 900), 1.0),
    ]) {
      testWidgets('no channel yet: the studio offers Connect ($lang, $label)',
          (tester) async {
        await pumpStudio(tester, lang: lang, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.byType(LanternStudioView), findsOneWidget);
        expect(find.byType(CaButton), findsNothing);
        expect(find.byType(CaSegmentedTabs), findsNothing);
        expect(find.byKey(const ValueKey('lantern-studio-status')),
            findsOneWidget);
        expect(
            find.byKey(const ValueKey('lantern-studio-steps')), findsOneWidget);
        final connect = tester.widget<LButton>(
            find.byKey(const ValueKey('lantern-studio-connect')));
        expect(connect.onPressed, isNotNull);
        // Nothing can be prepared, started or ended yet.
        expect(find.byType(LHoldButton), findsNothing);
        expect(
            find.byKey(const ValueKey('lantern-studio-prepare')), findsNothing);
        await close(tester);
      });
    }
  }

  testWidgets('the website layout puts the controls in a 480 px column',
      (tester) async {
    await pumpStudio(tester,
        broadcasts: StudioBroadcasts(), size: const Size(1440, 900));
    expect(tester.takeException(), isNull);
    expect(
        tester
            .getSize(find.byKey(const ValueKey('lantern-studio-column')))
            .width,
        Lantern.sideStudio);
    expect(find.text('Streaming from a laptop'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
      'one personal channel: it is chosen, and the next step is Prepare',
      (tester) async {
    await pumpStudio(tester, broadcasts: StudioBroadcasts());
    expect(tester.takeException(), isNull);
    expect(find.text('Not live yet'), findsOneWidget);
    expect(find.text('YouTube channel: Confirmed channel'), findsOneWidget);
    // The status card names the destination too.
    expect(find.text('Confirmed channel'), findsOneWidget);
    // Step one is done; step two is the one next step.
    expect(find.text('Next'), findsOneWidget);
    expect(find.bySemanticsLabel('1. Choose where to go live, done'),
        findsOneWidget);
    expect(find.bySemanticsLabel('2. Prepare the broadcast, Next'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-studio-confirm')), findsNothing);
    final prepare = find.byKey(const ValueKey('lantern-studio-prepare'));
    // The title is optional: the next step is open before anything is typed.
    expect(tester.widget<LButton>(prepare).onPressed, isNotNull);
    expect(find.byKey(const Key('studio-hide-replay')), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-studio-title')), findsOneWidget);
    // No stream key or server is shown before the broadcast is prepared.
    expect(find.textContaining('rtmp'), findsNothing);
    await close(tester);
  });

  testWidgets('two channels: the destination is chosen and must be confirmed',
      (tester) async {
    await pumpStudio(tester,
        broadcasts: StudioBroadcasts()
          ..channels = const [StudioBroadcasts.destination, _second]);
    expect(tester.takeException(), isNull);
    final prepare = find.byKey(const ValueKey('lantern-studio-prepare'));
    final confirm = find.byKey(const ValueKey('lantern-studio-confirm'));
    final choice = find.byKey(const ValueKey('lantern-studio-destination'));
    expect(confirm, findsOneWidget);
    expect(tester.widget<LButton>(prepare).onPressed, isNull);

    await tester.ensureVisible(choice);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lantern-studio-choice-list')),
        findsOneWidget);
    await tester.tap(find.text('Second channel').last);
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('lantern-studio-choice-list')), findsNothing);
    expect(find.text('I confirm this destination: Second channel'),
        findsOneWidget);
    expect(tester.widget<LButton>(prepare).onPressed, isNull);

    await tester.tap(confirm);
    await settle(tester, 2);
    expect(tester.widget<LanternStudioConfirm>(confirm).value, isTrue);
    expect(tester.widget<LButton>(prepare).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'from a laptop: prepare, hold to go live, hold to end; a tap does neither',
      (tester) async {
    final broadcasts = StudioBroadcasts();
    final provider = await pumpStudio(tester, broadcasts: broadcasts);
    // Send from OBS rather than this phone.
    await tester.tap(find.text('OBS'));
    await settle(tester, 2);
    final prepare = find.byKey(const ValueKey('lantern-studio-prepare'));
    expect(find.widgetWithText(LButton, 'Prepare or recover session'),
        findsOneWidget);
    await tester.tap(prepare);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
    expect(tester.takeException(), isNull);
    // Before it, the phone's own background preparation came and went.
    expect(broadcasts.actions.last, 'prepare');
    expect(broadcasts.actions, isNot(contains('start')));
    final prepared = broadcasts.actions.length;
    expect(find.text('Ready to stream'), findsOneWidget);
    expect(find.bySemanticsLabel('3. Start streaming, Next'), findsOneWidget);
    // The server shows; the key stays hidden until asked for.
    expect(find.text('rtmps://a.rtmps.youtube.com/live2'), findsOneWidget);
    expect(find.text('test-only-key'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Show or hide stream key'));
    await tester.tap(find.byTooltip('Show or hide stream key'));
    await settle(tester, 2);
    expect(find.text('test-only-key'), findsOneWidget);

    final start = find.byKey(const ValueKey('lantern-studio-start'));
    final end = find.byKey(const ValueKey('lantern-studio-end'));
    expect(start, findsOneWidget);
    expect(find.text('Hold to cancel the show'), findsOneWidget);
    // A tap is not enough.
    await tester.ensureVisible(start);
    await tester.tap(start);
    await settle(tester);
    expect(broadcasts.actions, hasLength(prepared));
    expect(provider.isBroadcastingLive, isFalse);

    await hold(tester, start);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(broadcasts.actions.sublist(prepared), ['start']);
    expect(provider.isBroadcastingLive, isTrue);
    expect(find.text('You are live'), findsOneWidget);
    expect(start, findsNothing);
    expect(find.text('Hold to end the broadcast'), findsOneWidget);

    await tester.ensureVisible(end);
    await tester.tap(end);
    await settle(tester);
    expect(provider.isBroadcastingLive, isTrue, reason: 'a tap does not end');
    await hold(tester, end);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(broadcasts.actions.sublist(prepared), ['start', 'end']);
    expect(provider.isBroadcastingLive, isFalse);
    await close(tester);
  });

  testWidgets('the format and the connection show in the status card',
      (tester) async {
    final provider = await pumpStudio(tester, broadcasts: StudioBroadcasts());
    expect(
        find.byKey(const ValueKey('lantern-studio-network')), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Audio only'), findsOneWidget);
    await tester.tap(find.text('Audio only'));
    await settle(tester, 3);
    // Once in the control and once in the status card.
    expect(find.text('Audio only'), findsNWidgets(2));
    provider.debugSetOnlineForTests(false);
    await settle(tester, 3);
    expect(find.text('Offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('a device that cannot send says so and offers Close',
      (tester) async {
    await pumpStudio(tester, mode: StudioMode.local);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('local-unavailable')), findsOneWidget);
    expect(find.byType(LanternStudioNotice), findsOneWidget);
    expect(find.widgetWithText(LButton, 'Close'), findsOneWidget);
    await close(tester);
  });

  // Pictures for review, written only when LANTERN_CAPTURE_DIR is set.
  final dir = Platform.environment['LANTERN_CAPTURE_DIR'];
  for (final (name, lang, size, prepared) in [
    ('studio-phone-ar-setup', 'ar', const Size(390, 844), false),
    ('studio-phone-en-ready', 'en', const Size(390, 844), true),
    ('studio-laptop-ar-ready', 'ar', const Size(1440, 900), true),
    ('studio-laptop-en-setup', 'en', const Size(1440, 900), false),
  ]) {
    testWidgets('capture $name', skip: dir == null, (tester) async {
      await pumpStudio(tester,
          broadcasts: StudioBroadcasts(), lang: lang, size: size);
      if (prepared) {
        await tester.tap(find
            .byWidgetPredicate(
                (w) => w is Text && (w.data == 'OBS' || w.data == 'أو بي إس'))
            .first);
        await settle(tester, 2);
        await tester.tap(find.byKey(const ValueKey('lantern-studio-prepare')));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await settle(tester);
      }
      final error = tester.takeException();
      if (error != null) debugPrint('CAPTURE $name: $error');
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(dir!).createSync(recursive: true);
        await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await close(tester);
    });
  }

  testWidgets('the older designs build none of it', (tester) async {
    for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
      final provider = AppProvider.withServices(
          organizationBroadcastService: EmptyBroadcasts())
        ..restoreAppSkin(skin);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(EasyLocalization(
          key: UniqueKey(),
          supportedLocales: const [Locale('en'), Locale('ar')],
          startLocale: const Locale('en'),
          saveLocale: false,
          path: 'assets/i18n',
          assetLoader: const DirectJsonAssetLoader(),
          child: ChangeNotifierProvider.value(
              value: provider,
              child: Builder(
                  builder: (context) => MaterialApp(
                      theme: AppTheme.forLocale(context.locale, skin: skin),
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      home: const Scaffold(
                          body: LiveBroadcasterStudioSheet()))))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LanternStudioView), findsNothing, reason: skin.name);
      expect(
          find.byWidgetPredicate((w) => w is LanternSkinWidget), findsNothing,
          reason: skin.name);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    }
  });
}
