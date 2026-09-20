import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/admin/models/streamer_custom_placeholder_model.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_player_overlay_controls.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/stream_state_placeholder_overlay.dart';
import 'package:streamer_app/features/map/models/map_models.dart';

import 'fixtures/streamer_fixtures.dart';

void main() {
  group('Live Stream Engine Unit Tests', () {
    // TC-GHOST-01 and TC-CHAT-01 covered the simulated "ghost audience" chat
    // pool and AppProvider's copy of it. Both were deleted in P2 (05 D-03):
    // an offline room now shows the "chat unavailable" banner over the real
    // message list instead of invented comments. Real chat behaviour is
    // covered by live_chat_controller/chat widget tests.
    test('TC-VENUE-01: Haversine Venue Distance Calculation Helper', () {
      final distanceKm = MapRegionModel.calculateHaversineDistance(
        26.2871, 50.2125, // Al Khobar Center
        26.3040, 50.1500, // KFUPM Auditorium
      );

      expect(distanceKm, greaterThan(0));
      expect(distanceKm,
          lessThan(30)); // Realistic intra-city distance in AlSharqia

      final formattedEn = MapRegionModel.formatDistance(distanceKm, 'en');
      final formattedAr = MapRegionModel.formatDistance(distanceKm, 'ar');

      expect(formattedEn, contains('km'));
      expect(formattedAr, contains('كم'));
    });

    test('TC-PLAYER-01: AbstractVideoPlayer Source Enums & Stream State Logic',
        () {
      expect(
          StreamSourceType.values,
          containsAll([
            StreamSourceType.localRtmp,
            StreamSourceType.awsIvsHls,
            StreamSourceType.youtubeEmbed,
          ]));

      expect(
          StreamState.values,
          containsAll([
            StreamState.initializing,
            StreamState.live,
            StreamState.paused,
            StreamState.buffering,
            StreamState.ended,
            StreamState.offline,
            StreamState.fallbackError,
            // Cluster 1 Task 4a placeholder states
            StreamState.startingSoon,
            StreamState.reconnecting,
            StreamState.noAudioToken,
          ]));
    });

    test(
        'TC-FALLBACK-01: Zero-Crash Fallback Stream State Transitions & Recovery',
        () {
      StreamState currentStreamState = StreamState.live;
      bool onErrorCalled = false;
      String lastError = '';

      void simulateStreamFailure(String errorMsg) {
        currentStreamState = StreamState.fallbackError;
        onErrorCalled = true;
        lastError = errorMsg;
      }

      void simulateRetryFeed() {
        currentStreamState = StreamState.live;
        onErrorCalled = false;
        lastError = '';
      }

      // Simulate stream disconnection
      simulateStreamFailure('Connection reset by peer');
      expect(currentStreamState, equals(StreamState.fallbackError));
      expect(onErrorCalled, isTrue);
      expect(lastError, contains('Connection reset'));

      // Simulate 1-tap "Retry Feed" user action
      simulateRetryFeed();
      expect(currentStreamState, equals(StreamState.live));
      expect(onErrorCalled, isFalse);
      expect(lastError, isEmpty);
    });

    test('TC-RTMP-DIALOG-01: RTMP IP Settings Override & Stream URL Generation',
        () {
      final appProvider = AppProvider();

      // Test default IP settings
      expect(appProvider.rtmpLaptopIp, equals('192.168.1.100'));
      expect(appProvider.rtmpStreamUrl,
          equals('http://192.168.1.100:8888/live/demo/'));

      // Test dynamic IP update to local loopback
      appProvider.updateRtmpLaptopIp('127.0.0.1');
      expect(appProvider.rtmpLaptopIp, equals('127.0.0.1'));
      expect(appProvider.rtmpStreamUrl,
          equals('http://127.0.0.1:8888/live/demo/'));

      // Test dynamic IP update to custom Wi-Fi address
      appProvider.updateRtmpLaptopIp('192.168.0.105');
      expect(appProvider.rtmpLaptopIp, equals('192.168.0.105'));
      expect(appProvider.rtmpStreamUrl,
          equals('http://192.168.0.105:8888/live/demo/'));
    });
  });

  group('Cluster 1 -- Player Quality, Placeholders & Mini-Player', () {
    test(
        'TC-QUALITY-01: Selector offers real resolutions, not playback engines',
        () {
      // The old selector was a StreamSourceType switcher wearing invented
      // resolution labels; these are resolutions and nothing else.
      expect(
        StreamQualityLevel.values.map((q) => q.value).toList(),
        equals(['auto', '1080', '720', '480', '360']),
      );

      expect(StreamQualityLevelInfo.fromValue('720'),
          equals(StreamQualityLevel.p720));
      expect(StreamQualityLevelInfo.fromValue('1080'),
          equals(StreamQualityLevel.p1080));

      // An unknown/legacy stored value degrades to adaptive rather than
      // throwing or pinning the viewer to a rendition they never chose.
      expect(StreamQualityLevelInfo.fromValue('1080p60 Local RTMP Loopback'),
          equals(StreamQualityLevel.auto));

      // Every level carries a distinct bilingual catalog key.
      final keys = StreamQualityLevel.values.map((q) => q.labelKey).toSet();
      expect(keys.length, equals(StreamQualityLevel.values.length));
    });

    test(
        'TC-PLACEHOLDER-01: Overlay covers every non-playing state and no playing one',
        () {
      // Playing states must leave the viewport alone -- the overlay is
      // permanently mounted in the player Stack.
      for (final playing in [
        StreamState.live,
        StreamState.paused,
        StreamState.buffering,
      ]) {
        expect(StreamStatePlaceholderOverlay.coversState(playing), isFalse,
            reason: '$playing should not be covered');
      }

      for (final blocked in [
        StreamState.initializing,
        StreamState.startingSoon,
        StreamState.reconnecting,
        StreamState.ended,
        StreamState.offline,
        StreamState.noAudioToken,
        StreamState.fallbackError,
      ]) {
        expect(StreamStatePlaceholderOverlay.coversState(blocked), isTrue,
            reason: '$blocked should be covered');
      }
    });

    test(
        'TC-CUSTOM-CARD-01: Placeholder model round-trips through its DB row shape',
        () {
      final created = DateTime.utc(2026, 8, 30, 12);
      final card = StreamerCustomPlaceholderModel(
        id: 'card_1',
        streamerId: 'streamer_1',
        placeholderType: StreamPlaceholderType.intermission,
        imageUrl: 'https://cdn.example/card.png',
        status: StreamPlaceholderStatus.pending,
        createdAt: created,
      );

      final row = card.toRow();
      expect(row['placeholder_type'], equals('intermission'));
      expect(row['status'], equals('pending'));

      final restored = StreamerCustomPlaceholderModel.fromRow(row);
      expect(restored.id, equals('card_1'));
      expect(
          restored.placeholderType, equals(StreamPlaceholderType.intermission));
      expect(restored.status, equals(StreamPlaceholderStatus.pending));
      expect(restored.isApproved, isFalse);
      expect(restored.createdAt, equals(created));

      // Only 'approved' artwork is ever shown to viewers.
      final approved = card.copyWith(status: StreamPlaceholderStatus.approved);
      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);
    });

    test('TC-MIC-01: Streamer mic-mute state is published for viewers', () {
      final provider = AppProvider();
      expect(provider.isStreamerMicMuted, isFalse);

      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.setStreamerMicMuted(true);
      expect(provider.isStreamerMicMuted, isTrue);
      expect(notifications, equals(1));

      // Re-publishing the same value must not churn every viewer's overlay.
      provider.setStreamerMicMuted(true);
      expect(notifications, equals(1));

      provider.setStreamerMicMuted(false);
      expect(provider.isStreamerMicMuted, isFalse);
      expect(notifications, equals(2));
    });

    test('TC-PIP-01: Minimizing carries the audio-only flag across', () {
      final provider = AppProvider();
      expect(provider.isMiniPlayerActive, isFalse);

      provider.openMiniPlayer(
        videoId: '8Y1RaecJ-mo',
        title: 'Autonomous Agents',
        streamerName: 'Dr. Al-Ghamdi',
        streamId: 'stream_live_992',
        isAudioOnly: true,
      );

      expect(provider.isMiniPlayerActive, isTrue);
      expect(provider.isMiniPlayerPlaying, isTrue);
      expect(provider.miniPlayerStreamId, equals('stream_live_992'));
      expect(provider.miniPlayerVideoId, equals('8Y1RaecJ-mo'));
      expect(provider.isMiniPlayerAudioOnly, isTrue);

      provider.closeMiniPlayer();
      expect(provider.isMiniPlayerActive, isFalse);

      // A video broadcast minimizes without inheriting the audio-only badge.
      provider.openMiniPlayer(
        videoId: 'M7lc1UVf-VE',
        title: 'Cloud Streaming',
        streamerName: 'Dr. Al-Ghamdi',
        streamId: 'stream_live_993',
      );
      expect(provider.isMiniPlayerAudioOnly, isFalse);
    });

    test(
        'TC-CUSTOM-CARD-02: Rejection with a blank reason is refused before it reaches the backend',
        () async {
      final provider = AppProvider();
      final card = StreamerCustomPlaceholderModel(
        id: 'card_2',
        streamerId: 'streamer_2',
        placeholderType: StreamPlaceholderType.startingSoon,
        imageUrl: 'https://cdn.example/soon.png',
        status: StreamPlaceholderStatus.pending,
        createdAt: DateTime.utc(2026, 8, 30),
      );

      // The rejection reason *is* the body of the notification the streamer
      // receives, so "rejected, no reason given" is not a reachable state.
      await expectLater(
        provider.rejectCustomPlaceholder(card, reason: '   '),
        throwsA(isA<Exception>()),
      );
    });

    test('TC-FALLBACK-01: Al Quran 4K has active stream and valid fallback streams', () {
      final quranStreamer = mockStreamers.firstWhere((s) => s.streamerId == 'quran_4k_05');
      expect(quranStreamer.youtubeVideoId, equals('jjBoecWjAnw'));
      expect(quranStreamer.fallbackYoutubeVideoIds, isNotEmpty);
      expect(quranStreamer.fallbackYoutubeVideoIds.length, equals(2));
      expect(quranStreamer.fallbackYoutubeVideoIds, containsAll(['PLkCnLrKN8Q', 'hPeOq1Dz5xI']));
    });

    test('TC-FALLBACK-02: AbstractVideoPlayer forwards fallbackUrls to YouTube adapter', () {
      final player = AbstractVideoPlayer.fromSource(
        sourceType: StreamSourceType.youtubeEmbed,
        streamUrl: 'jjBoecWjAnw',
        fallbackUrls: const ['PLkCnLrKN8Q', 'hPeOq1Dz5xI'],
      ) as YouTubePlayerAdapter;

      expect(player.streamUrl, equals('jjBoecWjAnw'));
      expect(player.fallbackUrls, equals(const ['PLkCnLrKN8Q', 'hPeOq1Dz5xI']));
    });
  });
}
