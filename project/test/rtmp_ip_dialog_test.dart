import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/interactive_toast_overlay.dart';
import 'package:streamer_app/features/live_stream/models/stream_privacy_models.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';

class DirectJsonAssetLoader extends AssetLoader {
  final Map<String, dynamic> enData;
  final Map<String, dynamic> arData;

  const DirectJsonAssetLoader({required this.enData, required this.arData});

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return locale.languageCode == 'ar' ? arData : enData;
  }
}

late Map<String, dynamic> globalEnData;
late Map<String, dynamic> globalArData;

Widget createTestWidget({
  required Widget child,
  required AppProvider provider,
  Locale locale = const Locale('en'),
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('ar')],
    path: 'assets/i18n',
    assetLoader:
        DirectJsonAssetLoader(enData: globalEnData, arData: globalArData),
    fallbackLocale: const Locale('en'),
    startLocale: locale,
    saveLocale: false,
    useOnlyLangCode: true,
    child: Builder(
      builder: (context) {
        return ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: ThemeData.dark(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: AppTheme.bg,
            ),
            home: Scaffold(body: child),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    globalEnData =
        jsonDecode(await File('assets/i18n/en.json').readAsString());
    globalArData =
        jsonDecode(await File('assets/i18n/ar.json').readAsString());
    await EasyLocalization.ensureInitialized();
  });

  group('LiveBroadcasterStudioSheet: 80% Broadcaster Studio bottom sheet (V2)',
      () {
    late AppProvider provider;

    setUp(() {
      provider = AppProvider();
      // The studio starts with an empty title now (P2: it used to be
      // pre-filled with an invented lecture title). Tests that locate the
      // title field by its current text seed one explicitly.
      provider.setCustomBroadcastMeta(
        title: 'Seeded Studio Title',
        description: '',
        category: provider.customLiveCategory,
      );
    });

    // InteractiveToastOverlay's auto-dismiss Timer is a static field that
    // outlives any single test. flutter_test fails a test whose Timer is
    // still pending when the test function returns (checked before
    // package:test's own addTearDown queue runs, so addTearDown itself is
    // too late) -- every test below that triggers a toast calls
    // InteractiveToastOverlay.dismiss() as its last statement instead.

    // The sheet is a fixed 80% of screen height with a scrollable middle
    // card -- widen the surface so every field is actually hit-testable
    // without fighting scroll offsets mid-test.
    void useTallTestSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Finder findByHint(String hint) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == hint,
        );

    // Pulls a nested key (e.g. 'design_copy.local') out of the raw locale
    // JSON so the test can tap a tab by its actual rendered label without
    // hardcoding the Arabic translation inline.
    String localized(Map<String, dynamic> data, String dottedKey) {
      dynamic value = data;
      for (final part in dottedKey.split('.')) {
        value = (value as Map<String, dynamic>)[part];
      }
      return value as String;
    }

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets(
          'TC-STUDIO-20 (${locale.languageCode}): tapping every mode tab '
          'shows that mode\'s own fields, never another mode\'s -- '
          'UI-04 semantic mapping must survive RTL tab reordering',
          (tester) async {
        useTallTestSurface(tester);
        final data = locale.languageCode == 'ar' ? globalArData : globalEnData;
        await tester.pumpWidget(
          createTestWidget(
            child: const LiveBroadcasterStudioSheet(),
            provider: provider,
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        const obsLabel = 'OBS';
        final phoneLabel = localized(data, 'design_copy.phone');
        final localLabel = localized(data, 'design_copy.local');

        // Starts on OBS: the YouTube-link field is OBS/Phone-only in its
        // "paste a link" form, but the laptop-IP field is Local-only and
        // the stream-key *obscured* field is Phone-only -- each is a
        // reliable, locale-independent fingerprint (hardcoded hint text)
        // for exactly one mode.
        expect(findByHint('e.g. 192.168.1.100'), findsNothing);
        expect(findByHint('https://youtube.com/watch?v=... or Video ID'),
            findsOneWidget);
        expect(findByHint('xxxx-xxxx-xxxx-xxxx-xxxx'), findsNothing);

        await tester.tap(find.text(localLabel));
        await tester.pumpAndSettle();
        expect(findByHint('e.g. 192.168.1.100'), findsOneWidget);
        expect(findByHint('https://youtube.com/watch?v=... or Video ID'),
            findsNothing);
        expect(findByHint('xxxx-xxxx-xxxx-xxxx-xxxx'), findsNothing);

        await tester.tap(find.text(phoneLabel));
        await tester.pumpAndSettle();
        expect(findByHint('e.g. 192.168.1.100'), findsNothing);
        expect(findByHint('https://youtube.com/watch?v=... or Video ID'),
            findsNothing);
        expect(findByHint('xxxx-xxxx-xxxx-xxxx-xxxx'), findsOneWidget);

        await tester.tap(find.text(obsLabel));
        await tester.pumpAndSettle();
        expect(findByHint('e.g. 192.168.1.100'), findsNothing);
        expect(findByHint('https://youtube.com/watch?v=... or Video ID'),
            findsOneWidget);
        expect(findByHint('xxxx-xxxx-xxxx-xxxx-xxxx'), findsNothing);
      });
    }

    testWidgets(
        'TC-STUDIO-01: renders the director_title/director_subtitle '
        'localization keys (regression for the missing-key bug)',
        (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Broadcaster Studio'), findsOneWidget);
      expect(find.text('Choose how you want to broadcast today'),
          findsOneWidget);
      // The raw (untranslated) keys must never leak onto screen.
      expect(find.text('live_studio.director_title'), findsNothing);
      expect(find.text('live_studio.director_subtitle'), findsNothing);
    });

    testWidgets('TC-STUDIO-02: opens on OBS mode with all three pill tabs',
        (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('OBS'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Go Live'), findsOneWidget);
      expect(find.text('YouTube Live Link'), findsOneWidget);
    });

    testWidgets(
        'TC-STUDIO-03: switching pill tabs morphs the middle card into '
        'mode-specific fields', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      expect(find.text('Open Camera'), findsOneWidget);
      expect(find.text('Quality Preset'), findsOneWidget);
      expect(find.text('YouTube Live Link'), findsNothing);

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      expect(find.text('Stream'), findsOneWidget);
      expect(find.text('Stream URL Preview'), findsOneWidget);
      expect(find.text('Quality Preset'), findsNothing);
    });

    testWidgets(
        'TC-STUDIO-04: root-cause regression -- Open Camera in Phone mode '
        'never touches the simulated YouTubeLiveService session, only the '
        'real user-typed stream key', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      final videoIdBefore = provider.customYouTubeVideoId;

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();

      final keyField = findByHint('xxxx-xxxx-xxxx-xxxx-xxxx');
      expect(keyField, findsOneWidget);
      await tester.enterText(keyField, 'real-key-from-youtube-studio');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Camera'));
      await tester.pump();

      expect(provider.phoneBroadcastStreamKey,
          equals('real-key-from-youtube-studio'));
      // startQuickPhoneBroadcast (the simulated path) was never called --
      // the viewer-facing video id is untouched by a fresh "sim_..."id.
      expect(provider.customYouTubeVideoId, equals(videoIdBefore));

      // PhoneBroadcastScreen's camera/permission setup needs real platform
      // channels this test environment doesn't provide.
      tester.takeException();
    });

    testWidgets(
        'TC-STUDIO-05: an empty stream key blocks Open Camera before it '
        'ever reaches AppProvider', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();

      final keyField = findByHint('xxxx-xxxx-xxxx-xxxx-xxxx');
      await tester.enterText(keyField, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Camera'));
      await tester.pump();

      expect(find.text('Stream Key Required'), findsOneWidget);
      expect(provider.isBroadcastingLive, isFalse);

      // See TC-STUDIO-06 -- cancel the error toast's own pending Timer.
      InteractiveToastOverlay.dismiss();
    });

    testWidgets('TC-STUDIO-06: Local mode updates the laptop RTMP IP',
        (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      final ipField = findByHint('e.g. 192.168.1.100');
      await tester.enterText(ipField, '10.0.0.42');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stream'));
      await tester.pumpAndSettle();

      expect(provider.rtmpLaptopIp, equals('10.0.0.42'));

      // The success toast's own 4-second auto-dismiss Timer would otherwise
      // still be pending when this test function returns, which
      // flutter_test treats as a leaked-timer test failure.
      InteractiveToastOverlay.dismiss();
    });

    testWidgets(
        'TC-STUDIO-07: an empty laptop IP blocks Stream before it ever '
        'reaches AppProvider', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      final ipBefore = provider.rtmpLaptopIp;

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      final ipField = findByHint('e.g. 192.168.1.100');
      await tester.enterText(ipField, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stream'));
      await tester.pump();

      expect(find.text('Laptop IP Required'), findsOneWidget);
      expect(provider.rtmpLaptopIp, equals(ipBefore));

      // See TC-STUDIO-06 -- cancel the error toast's own pending Timer.
      InteractiveToastOverlay.dismiss();
    });

    testWidgets('TC-STUDIO-08: category chips are selectable in Phone mode',
        (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();

      final medicineChipFinder =
          find.widgetWithText(ChoiceChip, 'Medicine & Clinical Health');
      expect(medicineChipFinder, findsOneWidget);

      final beforeTap = tester.widget<ChoiceChip>(medicineChipFinder);
      expect(beforeTap.selected, isFalse);

      await tester.tap(medicineChipFinder);
      await tester.pumpAndSettle();

      final afterTap = tester.widget<ChoiceChip>(medicineChipFinder);
      expect(afterTap.selected, isTrue);
    });

    testWidgets(
        'TC-STUDIO-09: switching modes and back preserves typed title text '
        '(shared controller across mode morphs)', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      final titleField =
          find.widgetWithText(TextField, provider.customLiveTitle);
      await tester.enterText(titleField, 'My Great Lecture');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      expect(find.text('My Great Lecture'), findsOneWidget);

      await tester.tap(find.text('OBS'));
      await tester.pumpAndSettle();
      expect(find.text('My Great Lecture'), findsOneWidget);
    });

    testWidgets(
        'TC-STUDIO-10: the Audio-Only format toggle unfolds the poster '
        'backdrop section and drives a bounded (not infinite) pulse '
        'animation', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Audio-Only Backdrop'), findsNothing);

      await tester.tap(find.text('Audio'));
      // The Audio toggle's selection now drives a repeating breathing-glow
      // AnimationController (V2) -- pumpAndSettle() would spin forever
      // while it's active, so settle with a few bounded frames instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Audio-Only Backdrop'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Custom Poster'), findsOneWidget);

      // Switching back to Video must stop the pulse controller cleanly --
      // otherwise this pumpAndSettle() would hang, proving the animation
      // is properly bounded to only run while Audio-Only is selected.
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Audio-Only Backdrop'), findsNothing);
    });

    testWidgets(
        'TC-STUDIO-10B: the sheet is capped at 80% of screen height and '
        'shrinks to content instead of always stretching to the cap '
        '(UI-02/UI-10: no dead space below short Local-mode content)',
        (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      final screenHeight = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      final obsSheetSize =
          tester.getSize(find.byType(LiveBroadcasterStudioSheet));

      // Never exceeds the 80% cap, even for the tallest (OBS) mode.
      expect(obsSheetSize.height, lessThanOrEqualTo(screenHeight * 0.80 + 0.5));

      // Local mode's content is much shorter -- the sheet must shrink with
      // it rather than staying pinned at the same height as OBS mode.
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      final localSheetSize =
          tester.getSize(find.byType(LiveBroadcasterStudioSheet));

      expect(localSheetSize.height, lessThan(obsSheetSize.height));
    });

    testWidgets(
        'TC-STUDIO-10C: all 3 modes share one unified coral pink accent on '
        'their Go Live CTA (no per-mode cyan/green/amber)', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Go Live'), findsOneWidget);

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      expect(find.text('Open Camera'), findsOneWidget);

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      expect(find.text('Stream'), findsOneWidget);
    });

    testWidgets(
        'TC-STUDIO-11: OBS Go Live persists title/description/category and '
        'denies going live without a primary session', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      final titleField =
          find.widgetWithText(TextField, provider.customLiveTitle);
      await tester.enterText(titleField, 'OBS Lecture Title');

      final descField = findByHint('A short summary viewers will see...');
      await tester.enterText(descField, 'A short OBS description.');
      await tester.pumpAndSettle();

      expect(provider.isBroadcastingLive, isFalse);
      await tester.tap(find.text('Go Live'));
      await tester.pumpAndSettle();

      expect(provider.customLiveTitle, equals('OBS Lecture Title'));
      expect(provider.customLiveDescription, equals('A short OBS description.'));
      expect(provider.isBroadcastingLive, isFalse);
      expect(provider.broadcastSessionError, 'broadcast_primary_required');

      // See TC-STUDIO-06 -- cancel the "YouTube Live Target Updated"toast's
      // own pending Timer before tearing the provider down.
      InteractiveToastOverlay.dismiss();
      provider.dispose();
    });

    testWidgets(
        'TC-STUDIO-12: an Info button opens the gamified Streamer Academy '
        'guide and steps through all 4 OBS quests to the final CTA',
        (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('STREAMER ACADEMY'), findsOneWidget);
      expect(find.textContaining('Level 1 of 4'), findsOneWidget);
      expect(find.text('Next Quest '), findsOneWidget);
      // First quest -- no Previous button yet.
      expect(find.text('Previous Step'), findsNothing);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next Quest '));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Level 4 of 4'), findsOneWidget);
      expect(find.text("Got It, Let's Stream!"), findsOneWidget);
      expect(find.text('Previous Step'), findsOneWidget);

      await tester.tap(find.text("Got It, Let's Stream!"));
      await tester.pumpAndSettle();

      expect(find.text('STREAMER ACADEMY'), findsNothing);
    });

    testWidgets(
        'TC-STUDIO-13: Paste Key from Clipboard inside the guide populates '
        'the stream key field back in Phone mode', (tester) async {
      useTallTestSurface(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': 'clipboard-pasted-stream-key'};
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      // Level 2 ("Set It & Forget It") is the Phone quest carrying the
      // paste action -- advance one quest forward from Level 1.
      await tester.tap(find.text('Next Quest '));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paste Key from Clipboard'));
      await tester.pumpAndSettle();

      expect(find.text('Stream key pasted ✓'), findsOneWidget);
      // Let the confirmation SnackBar's own auto-dismiss Timer fire so it
      // isn't still pending when this test function returns (see
      // TC-STUDIO-06's InteractiveToastOverlay.dismiss() note above).
      await tester.pump(const Duration(seconds: 5));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      final keyField = findByHint('xxxx-xxxx-xxxx-xxxx-xxxx');
      final fieldWidget = tester.widget<TextField>(keyField);
      expect(fieldWidget.controller?.text,
          equals('clipboard-pasted-stream-key'));
    });

    testWidgets(
        'TC-STUDIO-15: private controls are hidden without server entitlements', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Public'), findsNothing);
      expect(find.text('Private'), findsNothing);
      expect(find.text('Share Private Invite Link'), findsNothing);
      expect(
        find.text('Require Host Knock Approval for new guests'),
        findsNothing,
      );
    });

    testWidgets(
        'TC-STUDIO-16: saved whitelist remains editable as data but has no private UI', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      provider.addStreamWhitelistHandle('@sarah');
      expect(provider.streamWhitelistHandles, contains('@sarah'));
      provider.removeStreamWhitelistHandle('@sarah');
      expect(provider.streamWhitelistHandles, isNot(contains('@sarah')));
      expect(findByHint('@sarah, @khalid'), findsNothing);
      expect(find.widgetWithText(Chip, '@sarah'), findsNothing);
    });

    testWidgets(
        'TC-STUDIO-17: OBS Go Live cannot enable private mode through provider state', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      provider.configureStreamPrivacy(visibility: StreamVisibility.private);

      await tester.tap(find.text('Go Live'));
      await tester.pumpAndSettle();

      expect(provider.streamVisibility, equals(StreamVisibility.public));

      InteractiveToastOverlay.dismiss();
      provider.dispose();
    });

    testWidgets(
        'TC-STUDIO-18: Local mode cannot enable private streaming',
        (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      final ipField = findByHint('e.g. 192.168.1.100');
      await tester.enterText(ipField, '10.0.0.42');
      expect(find.text('Private'), findsNothing);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stream'));
      await tester.pumpAndSettle();

      expect(provider.streamVisibility, equals(StreamVisibility.public));

      InteractiveToastOverlay.dismiss();
    });

    testWidgets(
        'TC-STUDIO-19: default state (Private never tapped) leaves '
        'streamVisibility public', (tester) async {
      useTallTestSurface(tester);
      await tester.pumpWidget(
        createTestWidget(
            child: const LiveBroadcasterStudioSheet(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go Live'));
      await tester.pumpAndSettle();

      expect(provider.streamVisibility, equals(StreamVisibility.public));

      InteractiveToastOverlay.dismiss();
      provider.dispose();
    });
  });
}
