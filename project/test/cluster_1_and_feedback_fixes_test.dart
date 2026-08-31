import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/widgets/floating_stream_mini_player.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_player_overlay_controls.dart';
import 'package:streamer_app/features/discovery/models/academic_category_model.dart';
import 'package:streamer_app/features/admin/presentation/widgets/academic_categories_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Quick Fix QF-01: Fullscreen Button on Audio-Only Streams', () {
    testWidgets('LivePlayerOverlayControls renders fullscreen toggle button on audio-only streams',
        (WidgetTester tester) async {
      bool fullscreenToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: LivePlayerOverlayControls(
                streamState: StreamState.live,
                viewerCount: 1250,
                isAudioOnly: true,
                isPlaying: true,
                isMuted: false,
                isFullscreen: false,
                isStreamerMicMuted: false,
                onTogglePlayPause: () {},
                onToggleMute: () {},
                onToggleFullscreen: () {
                  fullscreenToggled = true;
                },
                onRetryConnection: () {},
                selectedQuality: StreamQualityLevel.auto,
                onSelectQuality: (_) {},
              ),
            ),
          ),
        ),
      );

      // Play/Pause button should NOT be rendered for audio-only streams
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      // Fullscreen button MUST be rendered even on audio-only streams
      final fullscreenButton = find.byIcon(Icons.fullscreen_rounded);
      expect(fullscreenButton, findsOneWidget);

      await tester.tap(fullscreenButton);
      await tester.pump();
      expect(fullscreenToggled, isTrue);
    });

    testWidgets('Fullscreen toggle displays exit icon when isFullscreen is true on audio streams',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: LivePlayerOverlayControls(
                streamState: StreamState.live,
                viewerCount: 1250,
                isAudioOnly: true,
                isPlaying: true,
                isMuted: false,
                isFullscreen: true,
                isStreamerMicMuted: false,
                onTogglePlayPause: () {},
                onToggleMute: () {},
                onToggleFullscreen: () {},
                onRetryConnection: () {},
                selectedQuality: StreamQualityLevel.auto,
                onSelectQuality: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
    });
  });

  group('Quick Fix QF-02: Compact Picture-in-Picture Mini-Player Redesign', () {
    test('AppProvider mini-player mute state toggles cleanly', () {
      final provider = AppProvider();
      expect(provider.isMiniPlayerMuted, isFalse);

      provider.toggleMiniPlayerMute();
      expect(provider.isMiniPlayerMuted, isTrue);

      provider.toggleMiniPlayerMute();
      expect(provider.isMiniPlayerMuted, isFalse);
    });

    testWidgets('FloatingStreamMiniPlayer renders compact card with Mute and Close overlay buttons',
        (WidgetTester tester) async {
      final provider = AppProvider();
      provider.launchMiniPlayer(
        videoId: 'test_vid_123',
        title: 'Al Quran 4K Live Broadcast',
        streamerName: 'Holy Quran Channel',
        streamId: 'quran_live_01',
        isAudioOnly: true,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  FloatingStreamMiniPlayer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify mini-player is visible
      expect(find.byType(FloatingStreamMiniPlayer), findsOneWidget);

      // Verify Mute button and Close button are present
      expect(find.byKey(const ValueKey('mini_player_mute_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('mini_player_close_button')), findsOneWidget);

      // Verify Pause button is removed per live stream ergonomics
      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      // Toggle Mute
      provider.toggleMiniPlayerMute();
      await tester.pumpAndSettle();
      expect(provider.isMiniPlayerMuted, isTrue);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

      // Close Mini-Player
      provider.closeMiniPlayer();
      await tester.pumpAndSettle();
      expect(provider.isMiniPlayerActive, isFalse);
      expect(find.byKey(const ValueKey('mini_player_mute_button')), findsNothing);
      expect(find.byKey(const ValueKey('mini_player_close_button')), findsNothing);
    });
  });

  group('Quick Fix QF-04: Database Error Resilience & Offline Fallbacks', () {
    test('AdminDatabaseService methods degrade gracefully without Supabase', () async {
      final service = await AdminDatabaseService.create();

      final categories = await service.loadAcademicCategories();
      expect(categories, isEmpty);

      final tags = await service.loadAllTags();
      expect(tags, isEmpty);

      final approvedTags = await service.loadApprovedTagNames();
      expect(approvedTags, isEmpty);

      final moderators = await service.loadStreamModerators();
      expect(moderators, isEmpty);

      final bannedUsers = await service.loadBannedUsers();
      expect(bannedUsers, isEmpty);
    });

    test('AcademicCategoryModel.defaultPool provides full fallback taxonomy', () {
      expect(AcademicCategoryModel.defaultPool.length, greaterThanOrEqualTo(8));
      for (final cat in AcademicCategoryModel.defaultPool) {
        expect(cat.id, isNotEmpty);
        expect(cat.nameEn, isNotEmpty);
        expect(cat.nameAr, isNotEmpty);
        expect(cat.iconName, isNotEmpty);
      }
    });
  });

  group('Quick Fix QF-05: Category Bilingual Script Validation & Icon Picker', () {
    test('Arabic regex detects Arabic script in English name field', () {
      final arabicRegex = RegExp(r'[\u0600-\u06FF]');

      expect(arabicRegex.hasMatch('Computer Science'), isFalse);
      expect(arabicRegex.hasMatch('هندسة البرمجيات'), isTrue);
      expect(arabicRegex.hasMatch('Engineering هندسة'), isTrue);
    });

    test('Latin regex detects English script in Arabic name field', () {
      final latinRegex = RegExp(r'[a-zA-Z]');

      expect(latinRegex.hasMatch('علوم الحاسب'), isFalse);
      expect(latinRegex.hasMatch('Computer Science'), isTrue);
      expect(latinRegex.hasMatch('هندسة Software'), isTrue);
    });

    test('kAvailableCategoryIcons contains valid Material icons list', () {
      expect(kAvailableCategoryIcons, isNotEmpty);
      for (final item in kAvailableCategoryIcons) {
        expect(item['name'], isA<String>());
        expect(item['icon'], isA<IconData>());
        expect(item['label'], isA<String>());
      }
    });
  });
}
