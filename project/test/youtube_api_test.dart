import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:streamer_app/core/services/youtube_api_service.dart';
import 'package:streamer_app/core/providers/app_provider.dart';

void main() {
  group('YouTube Data API v3 Unit & Integration Tests', () {
    const testApiKey = 'AIzaSyADRzIa7p3RlPlik-8C1r0bZjUipQTpOis';

    test('TC-YT-01: YouTubeApiService Handle Resolution to Channel ID',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('forHandle=ahmedamercaller')) {
          return http.Response(
            json.encode({
              'kind': 'youtube#channelListResponse',
              'items': [
                {
                  'id': 'UCah56qawts736uNxZA3inLQ',
                  'contentDetails': {
                    'relatedPlaylists': {
                      'uploads': 'UUah56qawts736uNxZA3inLQ',
                    }
                  }
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = YouTubeApiService(apiKey: testApiKey, client: mockClient);
      final details = await service.fetchChannelDetails('ahmedamercaller');

      expect(details['channelId'], equals('UCah56qawts736uNxZA3inLQ'));
      expect(details['uploadsPlaylistId'], equals('UUah56qawts736uNxZA3inLQ'));
    });

    test('TC-YT-02: YouTubeApiService Fetch Channel Uploads Parsing', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('playlistItems')) {
          return http.Response(
            json.encode({
              'items': [
                {
                  'snippet': {
                    'title': 'Test Lecture Title',
                    'description': 'Test Lecture Description',
                    'publishedAt': '2026-08-01T15:00:00Z',
                    'liveBroadcastContent': 'none',
                    'thumbnails': {
                      'high': {
                        'url':
                            'https://i.ytimg.com/vi/bl60n6uuvWE/hqdefault.jpg'
                      }
                    }
                  },
                  'contentDetails': {'videoId': 'bl60n6uuvWE'}
                }
              ]
            }),
            200,
          );
        }
        return http.Response(
          json.encode({
            'items': [
              {
                'id': 'UCah56qawts736uNxZA3inLQ',
                'contentDetails': {
                  'relatedPlaylists': {'uploads': 'UUah56qawts736uNxZA3inLQ'}
                }
              }
            ]
          }),
          200,
        );
      });

      final service = YouTubeApiService(apiKey: testApiKey, client: mockClient);
      final vods = await service.fetchChannelVideos(
        streamerId: 'prof_otaibi_02',
        handle: 'ahmedamercaller',
      );

      expect(vods.length, equals(1));
      expect(vods.first.youtubeVideoId, equals('bl60n6uuvWE'));
      expect(vods.first.titleEn, equals('Test Lecture Title'));
      expect(vods.first.recordedDate, equals('2026-08-01'));
    });

    test('TC-YT-03: AppProvider Integration with YouTube Service', () async {
      final provider = AppProvider();

      expect(provider.isYouTubeLiveSynced('prof_otaibi_02'), isFalse);
      final initialVods = provider.getVodsForStreamer('prof_otaibi_02');
      expect(initialVods.isNotEmpty, isTrue);

      await provider.loadYouTubeChannelData(
        streamerId: 'prof_otaibi_02',
        handle: 'ahmedamercaller',
      );

      expect(provider.isYouTubeLiveSynced('prof_otaibi_02'), isTrue);
      final liveVods = provider.getVodsForStreamer('prof_otaibi_02');
      expect(liveVods.isNotEmpty, isTrue);
    });

    test('TC-YT-04: Filter Upcoming Premieres ("Live in N days")', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('playlistItems')) {
          return http.Response(
            json.encode({
              'items': [
                {
                  'snippet': {
                    'title': 'Live in 3 days - Upcoming Session',
                    'description': 'Scheduled premiere',
                    'publishedAt': '2026-08-10T15:00:00Z',
                    'liveBroadcastContent': 'upcoming',
                  },
                  'contentDetails': {'videoId': 'upcoming_video_id_123'}
                },
                {
                  'snippet': {
                    'title': 'Completed Past Lecture',
                    'description': 'Watchable video',
                    'publishedAt': '2026-08-01T15:00:00Z',
                    'liveBroadcastContent': 'none',
                  },
                  'contentDetails': {'videoId': 'available_video_id_456'}
                }
              ]
            }),
            200,
          );
        }
        return http.Response(
          json.encode({
            'items': [
              {
                'id': 'UCah56qawts736uNxZA3inLQ',
                'contentDetails': {
                  'relatedPlaylists': {'uploads': 'UUah56qawts736uNxZA3inLQ'}
                }
              }
            ]
          }),
          200,
        );
      });

      final service = YouTubeApiService(apiKey: testApiKey, client: mockClient);
      final vods = await service.fetchChannelVideos(
        streamerId: 'prof_otaibi_02',
        handle: 'ahmedamercaller',
      );

      expect(vods.length, equals(1));
      expect(vods.first.youtubeVideoId, equals('available_video_id_456'));
      expect(vods.first.titleEn, equals('Completed Past Lecture'));
    });

    test('TC-YT-05: Fetch Playlist Items for Modal Display', () async {
      final mockClient = MockClient((request) async {
        if (request.url
            .toString()
            .contains('playlistId=PLSSxr3Rf2_X09k084XozCL-GIIil-lC4V')) {
          return http.Response(
            json.encode({
              'items': [
                {
                  'snippet': {
                    'title': 'Riyadh Al-Salihin Lesson 1',
                    'description': 'Lesson 1 description',
                    'publishedAt': '2026-07-25T15:00:00Z',
                  },
                  'contentDetails': {'videoId': 'riyadh_lesson_01'}
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = YouTubeApiService(apiKey: testApiKey, client: mockClient);
      final playlistVods = await service.fetchPlaylistItems(
        streamerId: 'prof_otaibi_02',
        playlistId: 'PLSSxr3Rf2_X09k084XozCL-GIIil-lC4V',
      );

      expect(playlistVods.length, equals(1));
      expect(playlistVods.first.youtubeVideoId, equals('riyadh_lesson_01'));
      expect(playlistVods.first.titleEn, equals('Riyadh Al-Salihin Lesson 1'));
    });
  });
}
