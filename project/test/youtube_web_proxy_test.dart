import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streamer_app/core/config/app_identity.dart';
import 'package:streamer_app/core/services/youtube_api_service.dart';

void main() {
  test(
      'web loads channel archives, playlists and playlist videos without a client key',
      () async {
    final resources = <String>[];
    final client = MockClient((request) async {
      expect(request.url.path, '/api/youtube');
      expect(request.url.queryParameters.containsKey('key'), isFalse);
      final resource = request.url.queryParameters['resource'];
      resources.add(resource!);
      final items = switch (resource) {
        'channels' => [
            {
              'id': 'UCah56qawts736uNxZA3inLQ',
              'contentDetails': {
                'relatedPlaylists': {'uploads': 'UUah56qawts736uNxZA3inLQ'}
              }
            }
          ],
        'playlistItems' => [
            {
              'contentDetails': {'videoId': 'bl60n6uuvWE'},
              'snippet': {
                'title': 'Actual channel lecture',
                'publishedAt': '2026-10-01T00:00:00Z'
              }
            }
          ],
        'playlists' => [
            {
              'id': 'PLabcdefghijk',
              'snippet': {'title': 'Actual channel playlist'},
              'contentDetails': {'itemCount': 1}
            }
          ],
        'videos' => [
            {
              'id': 'bl60n6uuvWE',
              'statistics': {'viewCount': '42'}
            }
          ],
        _ => throw StateError('Unexpected resource'),
      };
      return http.Response(jsonEncode({'items': items}), 200);
    });
    final service =
        YouTubeApiService(apiKey: '', client: client, useProxy: true);
    final vods = await service.fetchChannelVideos(
        streamerId: 'streamer', handle: '@ahmedamercaller');
    expect(vods.single.youtubeVideoId, 'bl60n6uuvWE');
    expect(vods.single.viewCount, 42);
    final playlists = await service.fetchChannelPlaylists(
        streamerId: 'streamer', channelId: 'UCah56qawts736uNxZA3inLQ');
    expect(playlists.single.titleEn, 'Actual channel playlist');
    final videos = await service.fetchPlaylistItems(
        streamerId: 'streamer', playlistId: playlists.single.playlistId);
    expect(videos.single.titleEn, 'Actual channel lecture');
    expect(resources,
        containsAll(['channels', 'playlistItems', 'playlists', 'videos']));
  });

  test('proxy never forwards even an accidentally supplied client key',
      () async {
    final service = YouTubeApiService(
        apiKey: 'must-not-leave-browser',
        useProxy: true,
        client: MockClient((request) async {
          expect(request.url.toString(),
              isNot(contains('must-not-leave-browser')));
          return http.Response('{"items":[]}', 200);
        }));
    await service.fetchChannelDetails('@somehandle');
  });

  test('phones read through the public site, with no key in the request',
      () async {
    final requests = <Uri>[];
    final service = YouTubeApiService(client: MockClient((request) async {
      requests.add(request.url);
      return http.Response('{"items":[]}', 200);
    }));
    await service.fetchChannelDetails('@somehandle');
    await service.fetchWatchStatus('abcdefghijk');
    expect(requests, hasLength(2));
    for (final url in requests) {
      expect(
          '${url.origin}${url.path}', '${AppIdentity.websiteUrl}/api/youtube');
      expect(url.queryParameters.containsKey('key'), isFalse);
    }
    expect(requests.map((u) => u.queryParameters['resource']),
        ['channels', 'videos']);
  });

  test('a key passed in explicitly still calls Google directly', () async {
    final service = YouTubeApiService(
        apiKey: 'tool-test-key',
        client: MockClient((request) async {
          expect(request.url.host, 'www.googleapis.com');
          expect(request.url.queryParameters['key'], 'tool-test-key');
          return http.Response('{"items":[]}', 200);
        }));
    await service.fetchChannelDetails('@somehandle');
  });
}
