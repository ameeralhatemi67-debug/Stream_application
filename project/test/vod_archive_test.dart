import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/profile/models/vod_models.dart';

void main() {
  group('VOD Archive & RTMP Configuration Unit Tests', () {
    test('TC-VOD-01 & TC-VOD-02: Localized Title & Description Selection', () {
      const sampleVod = VodModel(
        vodId: 'vod_test_01',
        streamerId: 'prof_alghamdi_01',
        titleEn: 'Cloud Computing 101',
        titleAr: 'الحوسبة السحابية ١٠١',
        descriptionEn: 'Introductory cloud lecture.',
        descriptionAr: 'محاضرة سحابية تمهيدية.',
        youtubeVideoId: '9bZkp7q19f0',
        durationSeconds: 3240,
        recordedDate: '2026-07-20',
        thumbnailUrl: 'assets/test.jpg',
        viewCount: 1200,
      );

      expect(sampleVod.getLocalizedTitle('en'), equals('Cloud Computing 101'));
      expect(sampleVod.getLocalizedTitle('ar'), equals('الحوسبة السحابية ١٠١'));
      expect(sampleVod.getLocalizedDescription('en'),
          equals('Introductory cloud lecture.'));
      expect(sampleVod.getLocalizedDescription('ar'),
          equals('محاضرة سحابية تمهيدية.'));
    });

    test('TC-VOD-03: Duration Formatting Helper', () {
      const vodShort = VodModel(
        vodId: 'vod_short',
        streamerId: 'prof_alghamdi_01',
        titleEn: 'Short',
        titleAr: 'قصيرة',
        descriptionEn: 'Short',
        descriptionAr: 'قصيرة',
        youtubeVideoId: '9bZkp7q19f0',
        durationSeconds: 3240, // 54 minutes
        recordedDate: '2026-07-20',
        thumbnailUrl: 'assets/test.jpg',
        viewCount: 100,
      );
      expect(vodShort.formattedDuration, equals('54:00'));

      const vodLong = VodModel(
        vodId: 'vod_long',
        streamerId: 'prof_alghamdi_01',
        titleEn: 'Long',
        titleAr: 'طويلة',
        descriptionEn: 'Long',
        descriptionAr: 'طويلة',
        youtubeVideoId: '9bZkp7q19f0',
        durationSeconds: 4050, // 1h 7m
        recordedDate: '2026-07-20',
        thumbnailUrl: 'assets/test.jpg',
        viewCount: 100,
      );
      expect(vodLong.formattedDuration, equals('1h 7m'));
    });

    test('TC-VOD-04: JSON Serialization Round-Trip', () {
      final sample = MockVodArchivePool.sampleVods.first;
      final jsonMap = sample.toJson();

      expect(jsonMap['vod_id'], equals(sample.vodId));
      expect(jsonMap['youtube_video_id'], equals(sample.youtubeVideoId));
      expect(jsonMap['duration_seconds'], equals(sample.durationSeconds));

      final restoredVod = VodModel.fromJson(jsonMap);
      expect(restoredVod.vodId, equals(sample.vodId));
      expect(restoredVod.youtubeVideoId, equals(sample.youtubeVideoId));
      expect(restoredVod.titleEn, equals(sample.titleEn));
    });

    test('TC-RTMP-01: AppProvider RTMP Laptop IP Override State', () {
      final provider = AppProvider();

      expect(provider.rtmpLaptopIp, equals('192.168.1.100'));
      expect(provider.rtmpStreamUrl,
          equals('http://192.168.1.100:8888/live/demo/'));

      provider.updateRtmpLaptopIp('10.0.0.5');
      expect(provider.rtmpLaptopIp, equals('10.0.0.5'));
      expect(provider.rtmpStreamUrl,
          equals('http://10.0.0.5:8888/live/demo/'));
    });

    test(
      'TC-RTMP-02: AppProvider Phone-to-YouTube Broadcast Target State (v0.7 CP2 Phase 2)',
      () {
        final provider = AppProvider();

        expect(
          provider.phoneBroadcastRtmpUrl,
          equals('rtmp://a.rtmp.youtube.com/live2'),
        );
        expect(provider.phoneBroadcastStreamKey, equals(''));
        // No stream key yet -- full URL degrades to just the ingest URL
        // rather than appending a trailing "/".
        expect(
          provider.phoneBroadcastFullUrl,
          equals('rtmp://a.rtmp.youtube.com/live2'),
        );

        provider.updatePhoneBroadcastTarget(
          rtmpUrl: 'rtmp://a.rtmp.youtube.com/live2',
          streamKey: 'abcd-efgh-ijkl-mnop',
        );

        expect(provider.phoneBroadcastStreamKey, equals('abcd-efgh-ijkl-mnop'));
        expect(
          provider.phoneBroadcastFullUrl,
          equals('rtmp://a.rtmp.youtube.com/live2/abcd-efgh-ijkl-mnop'),
        );
      },
    );

    test('TC-FOLLOW-01: AppProvider Follow & Reminder State Management', () {
      final provider = AppProvider();
      const testStreamerId = 'prof_alghamdi_01';

      expect(provider.isFollowing(testStreamerId), isFalse);
      expect(provider.hasReminder(testStreamerId), isFalse);

      provider.toggleFollow(testStreamerId);
      expect(provider.isFollowing(testStreamerId), isTrue);

      provider.toggleReminder(testStreamerId);
      expect(provider.hasReminder(testStreamerId), isTrue);

      provider.toggleFollow(testStreamerId);
      expect(provider.isFollowing(testStreamerId), isFalse);
    });

    test('TC-POOL-01: MockVodArchivePool Data Integrity', () {
      expect(MockVodArchivePool.sampleVods, isNotEmpty);
      expect(MockVodArchivePool.sampleVods.length, greaterThanOrEqualTo(4));
      for (final vod in MockVodArchivePool.sampleVods) {
        expect(vod.youtubeVideoId, isNotEmpty);
        expect(vod.durationSeconds, greaterThan(0));
        expect(vod.titleEn, isNotEmpty);
        expect(vod.titleAr, isNotEmpty);
      }
    });
  });
}
