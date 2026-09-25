import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamer_app/core/services/youtube_api_service.dart';

/// The real videos.list / search.list parsing, against canned responses.
void main() {
  YouTubeApiService service(
      FutureOr<http.Response> Function(http.Request) handler,
      {List<Uri>? seen}) {
    return YouTubeApiService(
      apiKey: 'test-only',
      client: MockClient((request) async {
        seen?.add(request.url);
        return handler(request);
      }),
    );
  }

  http.Response video(Map<String, dynamic> snippet,
          [Map<String, dynamic>? details]) =>
      http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'abcdefghijk',
                'snippet': snippet,
                if (details != null) 'liveStreamingDetails': details,
              }
            ]
          }),
          200);

  group('fetchWatchStatus', () {
    test('live, with its channel', () async {
      final seen = <Uri>[];
      final s = await service(
              (_) =>
                  video({'liveBroadcastContent': 'live', 'channelId': 'UC1'}),
              seen: seen)
          .fetchWatchStatus('abcdefghijk');
      expect(s.state, YouTubeWatchState.live);
      expect(s.channelId, 'UC1');
      expect(seen.single.path, endsWith('/videos'));
      expect(
          seen.single.queryParameters['part'], 'snippet,liveStreamingDetails');
    });

    test('upcoming keeps its scheduled start', () async {
      final s = await service((_) => video({
            'liveBroadcastContent': 'upcoming'
          }, {
            'scheduledStartTime': '2026-09-25T18:00:00Z'
          })).fetchWatchStatus('abcdefghijk');
      expect(s.state, YouTubeWatchState.upcoming);
      expect(s.scheduledStart, DateTime.utc(2026, 9, 25, 18));
    });

    test('a finished broadcast is ended, a plain upload is not live', () async {
      final ended = await service((_) => video({
            'liveBroadcastContent': 'none'
          }, {
            'actualEndTime': '2026-09-25T10:00:00Z'
          })).fetchWatchStatus('abcdefghijk');
      expect(ended.state, YouTubeWatchState.ended);
      final upload =
          await service((_) => video({'liveBroadcastContent': 'none'}))
              .fetchWatchStatus('abcdefghijk');
      expect(upload.state, YouTubeWatchState.notLive);
    });

    test('no items is not found; a malformed ID sends nothing', () async {
      final seen = <Uri>[];
      final svc =
          service((_) => http.Response('{"items":[]}', 200), seen: seen);
      expect((await svc.fetchWatchStatus('abcdefghijk')).state,
          YouTubeWatchState.notFound);
      expect((await svc.fetchWatchStatus('not an id')).state,
          YouTubeWatchState.notFound);
      expect(seen, hasLength(1));
    });

    test('quota errors, bad JSON and no key are unavailable, not refusals',
        () async {
      expect(
          (await service((_) => http.Response('quota', 403))
                  .fetchWatchStatus('abcdefghijk'))
              .state,
          YouTubeWatchState.unavailable);
      expect(
          (await service((_) => http.Response('<html>', 200))
                  .fetchWatchStatus('abcdefghijk'))
              .state,
          YouTubeWatchState.unavailable);
      expect(
          (await YouTubeApiService(apiKey: '').fetchWatchStatus('abcdefghijk'))
              .state,
          YouTubeWatchState.unavailable);
    });
  });

  test('a lookup that hangs times out as unavailable', () async {
    final slow = YouTubeApiService(
      apiKey: 'test-only',
      lookupTimeout: const Duration(milliseconds: 50),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        return http.Response('{"items":[]}', 200);
      }),
    );
    expect((await slow.fetchWatchStatus('abcdefghijk')).state,
        YouTubeWatchState.unavailable);
    expect(
        slow.fetchLiveVideoId('UC1'), throwsA(isA<YouTubeLookupUnavailable>()));
  });

  group('fetchLiveVideoId', () {
    test('returns the live video, or null when there is none', () async {
      final found = await service((_) => http.Response(
          jsonEncode({
            'items': [
              {
                'id': {'videoId': 'zyxwvutsrqp'}
              }
            ]
          }),
          200)).fetchLiveVideoId('UC1');
      expect(found, 'zyxwvutsrqp');
      final none = await service((_) => http.Response('{"items":[]}', 200))
          .fetchLiveVideoId('UC1');
      expect(none, isNull);
    });

    test('a quota or network failure throws instead of saying "none"',
        () async {
      expect(
          service((_) => http.Response('quota', 403)).fetchLiveVideoId('UC1'),
          throwsA(isA<YouTubeLookupUnavailable>()));
      expect(
          service((_) => throw http.ClientException('offline'))
              .fetchLiveVideoId('UC1'),
          throwsA(isA<YouTubeLookupUnavailable>()));
    });
  });
}
