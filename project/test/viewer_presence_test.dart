import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_player_overlay_controls.dart';
import 'package:streamer_app/features/live_stream/services/viewer_presence_service.dart';

/// P3 / 05 D-08. The runtime behaviour that needs a database (the heartbeat
/// RPC, the 45-second window, guest/user keying, broadcaster exclusion) is
/// covered by supabase/tests/viewer_presence.test.sql and stays
/// UNVERIFIED-STATIC until that runs on a local stack. What is checked here is
/// the client contract: an unknown count is never rendered as a number, and no
/// count is invented when there is no backend.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget overlay({required int? viewerCount}) => MaterialApp(
        home: Scaffold(
          // Wide surface: with EasyLocalization uninitialized, `.tr()` renders
          // the raw key ('feed.watching'), which is longer than the real
          // label and overflows a phone-width control row.
          body: SizedBox(
            width: 900,
            height: 500,
            child: LivePlayerOverlayControls(
              streamState: StreamState.live,
              viewerCount: viewerCount,
              isPlaying: true,
              isMuted: false,
              isFullscreen: false,
              onTogglePlayPause: () {},
              onToggleMute: () {},
              onToggleFullscreen: () {},
              onRetryConnection: () {},
              selectedQuality: StreamQualityLevel.auto,
              onSelectQuality: (_) {},
            ),
          ),
        ),
      );

  group('P3 viewer presence: client contract', () {
    test('TC-PRESENCE-01: a count nobody has fetched yet is null, not zero',
        () {
      final provider = AppProvider();

      expect(provider.platformViewerCount('abcdefghijk'), isNull);
      expect(provider.platformViewerCount(''), isNull);
      // YouTube's own figure is a separate, separately-unknown number and is
      // never merged into platform presence.
      expect(provider.youTubeConcurrentViewers('any-streamer'), isNull);
    });

    test(
        'TC-PRESENCE-02: refreshing counts without a backend leaves them '
        'unknown rather than inventing zeros', () async {
      final provider = AppProvider();

      await provider.refreshViewerCountsFor(['abcdefghijk', 'lmnopqrstuv']);

      expect(provider.platformViewerCount('abcdefghijk'), isNull);
      expect(provider.platformViewerCount('lmnopqrstuv'), isNull);
    });

    test('TC-PRESENCE-03: the service starts idle and disposes cleanly', () {
      final service = ViewerPresenceService(streamId: 'abcdefghijk');

      expect(service.count, isNull);
      expect(service.isRunning, isFalse);
      expect(ViewerPresenceService.heartbeatInterval,
          equals(const Duration(seconds: 20)));
      expect(ViewerPresenceService.countPollInterval,
          equals(const Duration(seconds: 15)));

      // Disposing a service that was never started must not throw: the live
      // room creates one per stream and disposes it with the screen.
      service.dispose();
    });

    testWidgets(
        'TC-PRESENCE-04: the player overlay shows an em dash while the count '
        'is unknown, and the real number once it is known', (tester) async {
      await tester.pumpWidget(overlay(viewerCount: null));
      await tester.pump();

      expect(find.textContaining('—'), findsWidgets);

      await tester.pumpWidget(overlay(viewerCount: 7));
      await tester.pump();

      expect(find.textContaining('7'), findsWidgets);
      expect(find.textContaining('—'), findsNothing);
    });
  });
}
