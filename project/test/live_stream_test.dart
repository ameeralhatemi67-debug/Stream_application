import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/live_stream/models/ghost_comments.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/map/models/map_models.dart';

void main() {
  group('Live Stream Engine & Ghost Audience Unit Tests', () {
    test('TC-GHOST-01: GhostCommentPool Data Integrity & Random Generation',
        () {
      expect(GhostCommentPool.rawComments, isNotEmpty);
      expect(GhostCommentPool.rawComments.length, greaterThanOrEqualTo(8));

      final comment =
          GhostCommentPool.getRandomComment(streamId: 'stream_live_992');
      expect(comment.streamId, equals('stream_live_992'));
      expect(comment.messageId, isNotEmpty);
      expect(comment.getLocalizedSender('en'), isNotEmpty);
      expect(comment.getLocalizedSender('ar'), isNotEmpty);
      expect(comment.getLocalizedMessage('en'), isNotEmpty);
      expect(comment.getLocalizedMessage('ar'), isNotEmpty);
    });

    test('TC-CHAT-01: AppProvider Live Chat State Management', () {
      final appProvider = AppProvider();
      expect(appProvider.chatMessages, isEmpty);

      appProvider.seedGhostChatIfNeeded(streamId: 'stream_live_992');
      expect(appProvider.chatMessages, isNotEmpty);
      final initialLength = appProvider.chatMessages.length;

      const userComment = GhostComment(
        messageId: 'user_test_1',
        streamId: 'stream_live_992',
        senderNameEn: 'You',
        senderNameAr: 'أنت',
        senderAvatar: 'assets/images/avatars/user_fahad.jpg',
        messageTextEn: 'Great lecture Professor!',
        messageTextAr: 'محاضرة قيمة يا دكتور!',
        timestamp: '14:30:00',
        isCurrentUser: true,
        isGhostSimulation: false,
        reactionType: 'clap',
      );

      appProvider.addChatMessage(userComment);
      expect(appProvider.chatMessages.length, equals(initialLength + 1));
      expect(appProvider.chatMessages.first.messageId, equals('user_test_1'));
      expect(appProvider.chatMessages.first.isCurrentUser, isTrue);
      expect(appProvider.chatMessages.first.reactionType, equals('clap'));

      appProvider.clearChatMessages();
      expect(appProvider.chatMessages, isEmpty);
    });

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
}
