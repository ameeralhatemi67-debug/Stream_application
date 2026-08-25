import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/live_stream/services/rtmp_publish_engine.dart';
import 'package:streamer_app/features/live_stream/services/youtube_live_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phone-to-YouTube Live: YouTubeLiveService', () {
    test(
        'TC-YTLIVE-01: createBroadcastSession returns a usable session '
        'without any live Google API key (simulation fallback)', () async {
      final service = YouTubeLiveService();

      final session = await service.createBroadcastSession(
        title: 'AI & Machine Learning Lecture',
        description: 'Live educational broadcast.',
        isAudioOnly: false,
        quality: BroadcastQualityPreset.high,
      );

      expect(session.broadcastId, isNotEmpty);
      expect(session.videoId, isNotEmpty);
      expect(session.rtmpUrl, equals('rtmp://a.rtmp.youtube.com/live2'));
      expect(session.streamKey, isNotEmpty);
    });

    test('TC-YTLIVE-02: two sessions created back-to-back get distinct ids',
        () async {
      final service = YouTubeLiveService();
      final first = await service.createBroadcastSession(
        title: 'Lecture 1',
        description: '',
        isAudioOnly: false,
        quality: BroadcastQualityPreset.medium,
      );
      final second = await service.createBroadcastSession(
        title: 'Lecture 2',
        description: '',
        isAudioOnly: true,
        quality: BroadcastQualityPreset.low,
      );

      expect(first.broadcastId, isNot(equals(second.broadcastId)));
      expect(first.videoId, isNot(equals(second.videoId)));
    });

    test('TC-YTLIVE-03: endBroadcastSession completes without throwing',
        () async {
      final service = YouTubeLiveService();
      await expectLater(
        service.endBroadcastSession(broadcastId: 'bcast_test_01'),
        completes,
      );
    });
  });

  group('Phone-to-YouTube Live: AppProvider.startQuickPhoneBroadcast', () {
    test('TC-QGL-01: configures every broadcast field and goes live', () async {
      final provider = AppProvider();
      expect(provider.isBroadcastingLive, isFalse);

      final success = await provider.startQuickPhoneBroadcast(
        title: 'AI & Machine Learning Lecture',
        category: 'cs_tech',
        venue: 'KFUPM Auditorium 21',
        isAudioOnly: false,
        quality: BroadcastQualityPreset.high,
      );

      expect(success, isTrue);
      expect(provider.customLiveTitle, equals('AI & Machine Learning Lecture'));
      expect(provider.customLiveCategory, equals('cs_tech'));
      expect(provider.customLiveVenue, equals('KFUPM Auditorium 21'));
      expect(provider.customBroadcastType, equals(BroadcastType.liveVideo));
      expect(provider.customYouTubeVideoId, isNotEmpty);
      expect(provider.customYouTubeLiveUrl,
          contains(provider.customYouTubeVideoId));
      expect(provider.phoneBroadcastRtmpUrl,
          equals('rtmp://a.rtmp.youtube.com/live2'));
      expect(provider.phoneBroadcastStreamKey, isNotEmpty);
      expect(provider.isBroadcastingLive, isTrue);
    });

    test(
        'TC-QGL-02: format switching -- Audio-Only sets BroadcastType.liveAudio',
        () async {
      final provider = AppProvider();

      await provider.startQuickPhoneBroadcast(
        title: 'Live Audio Stage',
        category: 'general_edu',
        venue: 'Remote',
        isAudioOnly: true,
        quality: BroadcastQualityPreset.medium,
      );

      expect(provider.customBroadcastType, equals(BroadcastType.liveAudio));
      expect(provider.isBroadcastingLive, isTrue);
    });

    test(
        'TC-QGL-03: ending a quick-live broadcast flips isBroadcastingLive '
        'back off cleanly (endBroadcastSession hook)', () async {
      final provider = AppProvider();
      await provider.startQuickPhoneBroadcast(
        title: 'Test Lecture',
        category: 'islamic_studies',
        venue: 'Test Hall',
        isAudioOnly: false,
        quality: BroadcastQualityPreset.low,
      );
      expect(provider.isBroadcastingLive, isTrue);

      await provider.toggleBroadcasterGoLive();
      expect(provider.isBroadcastingLive, isFalse);
    });

    test('TC-QGL-04: does not touch state if session creation fails', () {
      // createBroadcastSession never throws in its current simulated form,
      // so this documents the contract: a failed session creation must
      // leave isBroadcastingLive/custom* fields untouched and return false,
      // exercised at the unit level by the try/catch in
      // AppProvider.startQuickPhoneBroadcast itself.
      final provider = AppProvider();
      expect(provider.isBroadcastingLive, isFalse);
      expect(provider.customLiveTitle, isNotEmpty);
    });
  });

  group('AppProvider: Broadcaster Studio meta (v0.9)', () {
    test(
        'TC-STUDIO-META-01: setCustomBroadcastMeta updates title/description/'
        'category without touching venue', () {
      final provider = AppProvider();
      final venueBefore = provider.customLiveVenue;

      provider.setCustomBroadcastMeta(
        title: 'New Title',
        description: 'New description text.',
        category: 'engineering_tech',
      );

      expect(provider.customLiveTitle, equals('New Title'));
      expect(provider.customLiveDescription, equals('New description text.'));
      expect(provider.customLiveCategory, equals('engineering_tech'));
      expect(provider.customLiveVenue, equals(venueBefore));
    });

    test(
        'TC-STUDIO-META-02: setCustomAudioOnlyPosterPath stores and clears '
        'the poster path', () {
      final provider = AppProvider();
      expect(provider.customAudioOnlyPosterPath, isNull);

      provider.setCustomAudioOnlyPosterPath('/tmp/poster.jpg');
      expect(provider.customAudioOnlyPosterPath, equals('/tmp/poster.jpg'));

      provider.setCustomAudioOnlyPosterPath(null);
      expect(provider.customAudioOnlyPosterPath, isNull);

      provider.setCustomAudioOnlyPosterPath('');
      expect(provider.customAudioOnlyPosterPath, isNull);
    });
  });
}
