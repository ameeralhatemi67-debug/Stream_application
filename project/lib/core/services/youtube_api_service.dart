import 'youtube_channel_reference.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/profile/models/vod_models.dart';

/// What YouTube's public Data API says about one watch ID. This is a
/// snapshot read with the app's API key, not channel authorization: it can
/// tell a live broadcast from a finished one, a regular video or a mistyped
/// ID, and which channel owns it. It cannot see the stream key, the encoder
/// or whether a particular viewer hears sound.
enum YouTubeWatchState {
  live,
  upcoming,
  ended,
  notLive,
  notFound,

  /// No answer (no API key, quota, network): nothing is known.
  unavailable,
}

class YouTubeWatchStatus {
  const YouTubeWatchStatus(this.state,
      {this.channelId, this.title, this.scheduledStart});
  final YouTubeWatchState state;
  final String? channelId;
  final String? title;

  /// liveStreamingDetails.scheduledStartTime, for an upcoming broadcast.
  final DateTime? scheduledStart;
}

/// YouTube could not be asked (quota, key, network, timeout). Distinct from
/// "asked, and the answer is no".
class YouTubeLookupUnavailable implements Exception {
  const YouTubeLookupUnavailable();
}

/// Service for communicating with YouTube Data API v3 REST endpoints.
class YouTubeApiService {
  /// Native-only build setting. Web uses the same-origin server endpoint,
  /// whose key is never compiled into the browser bundle. Never hardcode a key
  /// here -- see doc/Audit/01_Security_Data_Protection_Audit.md VULN-DATA-01.
  static const String _defaultApiKey =
      kIsWeb ? '' : String.fromEnvironment('YOUTUBE_API_KEY');
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  /// Studio lookups wait at most this long; after that the studio treats
  /// YouTube as unreachable instead of spinning.
  static const Duration defaultLookupTimeout = Duration(seconds: 8);
  final Duration lookupTimeout;

  final String apiKey;
  final http.Client _client;
  final bool _useWebProxy;
  bool get _canRead => _useWebProxy || apiKey.isNotEmpty;

  // In-memory caching to optimize API quota usage
  final Map<String, List<VodModel>> _cachedVods = {};
  final Map<String, List<PlaylistModel>> _cachedPlaylists = {};

  /// A channel's id and uploads playlist never change, so a successful lookup
  /// is remembered for the session. The profile screen, channel validation and
  /// watch-link verification each used to re-query the same handle (1 quota
  /// unit and a round-trip each; audit CA-04). Failures are not cached.
  final Map<String, Map<String, String>> _cachedChannelDetails = {};

  YouTubeApiService({
    String? apiKey,
    http.Client? client,
    bool? useWebProxy,
    this.lookupTimeout = defaultLookupTimeout,
  })  : apiKey = apiKey ?? _defaultApiKey,
        _useWebProxy = useWebProxy ?? (kIsWeb && apiKey == null),
        _client = client ?? http.Client();

  Future<http.Response> _get(Uri url) {
    if (_useWebProxy) {
      final parameters = Map<String, String>.of(url.queryParameters)
        ..remove('key')
        ..['resource'] = url.pathSegments.last;
      url =
          Uri.base.resolve('/api/youtube').replace(queryParameters: parameters);
    }
    return _client.get(url).timeout(lookupTimeout);
  }

  /// Resolves old ID-only saves without visiting a channel or its latest page.
  /// Missing/deleted videos are omitted; an unavailable API remains an error.
  Future<Map<String, VodModel>> fetchSavedVideos(List<String> ids) async {
    if (!_canRead) throw const YouTubeLookupUnavailable();
    final valid = ids
        .toSet()
        .where((id) => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id))
        .toList();
    final result = <String, VodModel>{};
    for (var offset = 0; offset < valid.length; offset += 50) {
      final batch = valid.skip(offset).take(50).join(',');
      final response = await _get(Uri.parse('$_baseUrl/videos').replace(
          queryParameters: {
            'part': 'snippet,statistics',
            'id': batch,
            'key': apiKey
          }));
      if (response.statusCode != 200) throw const YouTubeLookupUnavailable();
      final items =
          (jsonDecode(response.body) as Map<String, dynamic>)['items'] as List;
      for (final item in items) {
        final id = item['id'] as String;
        final snippet = item['snippet'] as Map<String, dynamic>;
        final title = snippet['title'] as String? ?? '';
        final description = snippet['description'] as String? ?? '';
        final published = snippet['publishedAt'] as String? ?? '';
        result[id] = VodModel(
            vodId: id,
            streamerId: '',
            titleEn: title,
            titleAr: title,
            descriptionEn: description,
            descriptionAr: description,
            youtubeVideoId: id,
            durationSeconds: 0,
            recordedDate:
                published.length >= 10 ? published.substring(0, 10) : '',
            thumbnailUrl: snippet['thumbnails']?['high']?['url'] as String? ??
                'https://img.youtube.com/vi/$id/hqdefault.jpg',
            viewCount: int.tryParse(
                    item['statistics']?['viewCount']?.toString() ?? '') ??
                0);
      }
    }
    return result;
  }

  /// Resolves channel handle or URL (e.g. '@ahmedamercaller'or 'https://www.youtube.com/@dalilk4english_podcast/videos') to channel ID and uploads playlist ID
  Future<Map<String, String>> fetchChannelDetails(String handleOrUrl) async {
    if (handleOrUrl.trim().isEmpty || !_canRead) return {};
    final channel = YouTubeChannelReference.parse(handleOrUrl);
    if (channel == null || channel.parameter == 'custom') return {};
    final cacheKey = '${channel.parameter}:${channel.value.toLowerCase()}';
    final cached = _cachedChannelDetails[cacheKey];
    if (cached != null) return Map.of(cached);
    final url = Uri.parse('$_baseUrl/channels').replace(queryParameters: {
      'part': 'snippet,contentDetails',
      channel.parameter: channel.value,
      'key': apiKey,
    });

    try {
      final response = await _get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;

        if (items != null && items.isNotEmpty) {
          final firstItem = items.first as Map<String, dynamic>;
          final channelId = firstItem['id'] as String;
          final contentDetails =
              firstItem['contentDetails'] as Map<String, dynamic>?;
          final relatedPlaylists =
              contentDetails?['relatedPlaylists'] as Map<String, dynamic>?;
          final uploadsPlaylistId = relatedPlaylists?['uploads'] as String? ??
              'UU${channelId.substring(2)}';

          final details = {
            'channelId': channelId,
            'uploadsPlaylistId': uploadsPlaylistId,
          };
          _cachedChannelDetails[cacheKey] = details;
          return Map.of(details);
        }
      }
    } catch (e) {
      // The error text can contain the request URL, which carries the key.
      debugPrint('Error fetching channel details: ${e.runtimeType}');
    }

    return {};
  }

  /// Fetches recent videos from a YouTube channel's uploads playlist
  Future<List<VodModel>> fetchChannelVideos({
    required String streamerId,
    String handle = '',
    int maxResults = 25,
  }) async {
    if (_cachedVods.containsKey('$streamerId:$handle')) {
      return _cachedVods['$streamerId:$handle']!;
    }

    try {
      final channelDetails = await fetchChannelDetails(handle);
      final uploadsPlaylistId = channelDetails['uploadsPlaylistId'] ?? '';
      if (uploadsPlaylistId.isEmpty) return [];

      final url = Uri.parse(
        '$_baseUrl/playlistItems?part=snippet,contentDetails&playlistId=$uploadsPlaylistId&maxResults=$maxResults&key=$apiKey',
      );

      final response = await _get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;

        if (items != null && items.isNotEmpty) {
          final vods = <VodModel>[];
          for (final item in items) {
            final snippet = item['snippet'] as Map<String, dynamic>?;
            final contentDetails =
                item['contentDetails'] as Map<String, dynamic>?;

            final videoId = contentDetails?['videoId'] as String? ??
                snippet?['resourceId']?['videoId'] as String? ??
                '';

            if (videoId.isEmpty) continue;

            final title = snippet?['title'] as String? ?? 'YouTube Lecture';
            final description = snippet?['description'] as String? ?? '';
            final liveBroadcastContent =
                snippet?['liveBroadcastContent'] as String? ?? 'none';

            // Drop upcoming/scheduled premiere videos ("Live in N days")
            if (liveBroadcastContent == 'upcoming' ||
                title.toLowerCase().contains('live in ') ||
                title.toLowerCase().contains('premieres in ')) {
              continue;
            }

            final publishedAt = snippet?['publishedAt'] as String? ?? '';
            final dateStr =
                publishedAt.length >= 10 ? publishedAt.substring(0, 10) : '';

            final thumbnails = snippet?['thumbnails'] as Map<String, dynamic>?;
            final thumbUrl = thumbnails?['high']?['url'] as String? ??
                thumbnails?['medium']?['url'] as String? ??
                'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

            vods.add(
              VodModel(
                vodId: 'vod_yt_$videoId',
                streamerId: streamerId,
                titleEn: title,
                titleAr: title,
                descriptionEn: description,
                descriptionAr: description,
                youtubeVideoId: videoId,
                durationSeconds: 0,
                recordedDate: dateStr,
                thumbnailUrl: thumbUrl,
                viewCount:
                    0, // Will be hydrated below via statistics batch call
              ),
            );
          }

          if (vods.isNotEmpty) {
            // Hydrate real view counts via a single batch statistics call
            final videoIdList = vods.map((v) => v.youtubeVideoId).toList();
            final viewCounts = await fetchVideoViewCounts(videoIdList);
            final hydratedVods = vods.map((v) {
              final realCount = viewCounts[v.youtubeVideoId];
              return realCount != null ? v.copyWith(viewCount: realCount) : v;
            }).toList();

            _cachedVods['$streamerId:$handle'] = hydratedVods;
            return hydratedVods;
          }
        }
      }
    } catch (e) {
      debugPrint(
          'Error fetching channel videos for $streamerId ($handle): ${e.runtimeType}');
    }

    return [];
  }

  /// Fetches videos inside a specific YouTube playlist
  Future<List<VodModel>> fetchPlaylistItems({
    required String streamerId,
    required String playlistId,
    int maxResults = 25,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/playlistItems?part=snippet,contentDetails&playlistId=$playlistId&maxResults=$maxResults&key=$apiKey',
      );

      final response = await _get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;

        if (items != null && items.isNotEmpty) {
          final vods = <VodModel>[];
          for (final item in items) {
            final snippet = item['snippet'] as Map<String, dynamic>?;
            final contentDetails =
                item['contentDetails'] as Map<String, dynamic>?;

            final videoId = contentDetails?['videoId'] as String? ??
                snippet?['resourceId']?['videoId'] as String? ??
                '';

            if (videoId.isEmpty) continue;

            final title = snippet?['title'] as String? ?? 'Playlist Video';
            final description = snippet?['description'] as String? ?? '';
            final publishedAt = snippet?['publishedAt'] as String? ?? '';
            final dateStr =
                publishedAt.length >= 10 ? publishedAt.substring(0, 10) : '';

            final thumbnails = snippet?['thumbnails'] as Map<String, dynamic>?;
            final thumbUrl = thumbnails?['high']?['url'] as String? ??
                thumbnails?['medium']?['url'] as String? ??
                'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

            vods.add(
              VodModel(
                vodId: 'vod_pl_$videoId',
                streamerId: streamerId,
                titleEn: title,
                titleAr: title,
                descriptionEn: description,
                descriptionAr: description,
                youtubeVideoId: videoId,
                durationSeconds: 0,
                recordedDate: dateStr,
                thumbnailUrl: thumbUrl,
                viewCount:
                    0, // Will be hydrated below via statistics batch call
              ),
            );
          }

          // Hydrate real view counts via a single batch statistics call
          if (vods.isNotEmpty) {
            final videoIdList = vods.map((v) => v.youtubeVideoId).toList();
            final viewCounts = await fetchVideoViewCounts(videoIdList);
            return vods.map((v) {
              final realCount = viewCounts[v.youtubeVideoId];
              return realCount != null ? v.copyWith(viewCount: realCount) : v;
            }).toList();
          }
          return vods;
        }
      }
    } catch (e) {
      debugPrint(
          'Error fetching playlist items for $playlistId: ${e.runtimeType}');
    }

    return [];
  }

  /// Looks up the currently-live broadcast video ID for a given channel,
  /// using the YouTube Data API's search endpoint (eventType=live).
  /// Returns null if the channel has no active live broadcast right now
  /// (e.g. OBS hasn't started streaming, or "Go Live"hasn't been clicked
  /// yet in YouTube Studio).
  ///
  /// Throws [YouTubeLookupUnavailable] when YouTube could not be asked, so a
  /// quota or network failure is never reported as "no live broadcast".
  Future<String?> fetchLiveVideoId(String channelId) async {
    if (!_canRead) throw const YouTubeLookupUnavailable();
    final url = Uri.parse(
      '$_baseUrl/search?part=snippet&channelId=$channelId&eventType=live&type=video&key=$apiKey',
    );

    try {
      final response = await _get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;

        if (items != null && items.isNotEmpty) {
          final firstItem = items.first as Map<String, dynamic>;
          final id = firstItem['id'] as Map<String, dynamic>?;
          final videoId = id?['videoId'] as String?;
          if (videoId != null && videoId.isNotEmpty) {
            return videoId;
          }
        }
      } else {
        debugPrint('YouTube live lookup failed: HTTP ${response.statusCode}');
        throw const YouTubeLookupUnavailable();
      }
    } on YouTubeLookupUnavailable {
      rethrow;
    } catch (e) {
      debugPrint('YouTube live lookup failed: ${e.runtimeType}');
      throw const YouTubeLookupUnavailable();
    }

    return null;
  }

  /// Reads the public status of [videoId] (videos.list, 1 quota unit):
  /// snippet.liveBroadcastContent is `live`, `upcoming` or `none`, and a
  /// finished broadcast keeps liveStreamingDetails.actualEndTime. Request
  /// URLs carry the API key, so they are never logged.
  Future<YouTubeWatchStatus> fetchWatchStatus(String videoId) async {
    // A malformed ID cannot exist on YouTube; no request is needed.
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
      return const YouTubeWatchStatus(YouTubeWatchState.notFound);
    }
    if (!_canRead) {
      return const YouTubeWatchStatus(YouTubeWatchState.unavailable);
    }
    final url = Uri.parse(
      '$_baseUrl/videos?part=snippet,liveStreamingDetails&id=$videoId&key=$apiKey',
    );
    try {
      final response = await _get(url);
      if (response.statusCode != 200) {
        debugPrint('YouTube watch check failed: HTTP ${response.statusCode}');
        return const YouTubeWatchStatus(YouTubeWatchState.unavailable);
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? const [];
      if (items.isEmpty) {
        return const YouTubeWatchStatus(YouTubeWatchState.notFound);
      }
      final item = items.first as Map<String, dynamic>;
      final snippet = item['snippet'] as Map<String, dynamic>? ?? const {};
      final details = item['liveStreamingDetails'] as Map<String, dynamic>?;
      final content = snippet['liveBroadcastContent'] as String? ?? 'none';
      final state = switch (content) {
        'live' => YouTubeWatchState.live,
        'upcoming' => YouTubeWatchState.upcoming,
        _ => details?['actualEndTime'] != null
            ? YouTubeWatchState.ended
            : YouTubeWatchState.notLive,
      };
      return YouTubeWatchStatus(state,
          channelId: snippet['channelId'] as String?,
          title: snippet['title'] as String?,
          scheduledStart: DateTime.tryParse(
              details?['scheduledStartTime'] as String? ?? ''));
    } catch (e) {
      debugPrint('YouTube watch check failed: ${e.runtimeType}');
      return const YouTubeWatchStatus(YouTubeWatchState.unavailable);
    }
  }

  /// Fetches real-time concurrent viewers for an active live YouTube broadcast.
  ///
  /// Uses the `liveStreamingDetails` part on the Videos endpoint — the only
  /// YouTube Data API field that reports live concurrent viewers in real time.
  /// Returns `null` if the video is not currently live or the value is unavailable.
  Future<int?> fetchLiveConcurrentViewers(String videoId) async {
    if (videoId.isEmpty) return null;

    final url = Uri.parse(
      '$_baseUrl/videos?part=liveStreamingDetails&id=$videoId&key=$apiKey',
    );

    try {
      final response = await _get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;

        if (items != null && items.isNotEmpty) {
          final liveDetails =
              (items.first as Map<String, dynamic>)['liveStreamingDetails']
                  as Map<String, dynamic>?;
          final raw = liveDetails?['concurrentViewers'] as String?;
          if (raw != null) {
            return int.tryParse(raw);
          }
        }
      } else {
        debugPrint(
          'YouTube concurrentViewers lookup failed for $videoId: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching concurrent viewers for $videoId: $e');
    }

    return null;
  }

  /// Fetches real YouTube view counts for a batch of video IDs (max 50 per call).
  ///
  /// Uses `videos?part=statistics` — a single quota unit for up to 50 IDs at once.
  /// Returns a map of `{ videoId: viewCount }`. Any video not found is omitted.
  Future<Map<String, int>> fetchVideoViewCounts(List<String> videoIds) async {
    if (videoIds.isEmpty) return {};

    // YouTube API allows up to 50 IDs per request. Chunk if needed.
    final results = <String, int>{};
    const int batchSize = 50;

    for (int i = 0; i < videoIds.length; i += batchSize) {
      final chunk = videoIds.skip(i).take(batchSize).toList();
      final idParam = chunk.join(',');

      final url = Uri.parse(
        '$_baseUrl/videos?part=statistics&id=$idParam&key=$apiKey',
      );

      try {
        final response = await _get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>?;

          if (items != null) {
            for (final item in items) {
              final itemMap = item as Map<String, dynamic>;
              final id = itemMap['id'] as String? ?? '';
              final stats = itemMap['statistics'] as Map<String, dynamic>?;
              final rawCount = stats?['viewCount'] as String?;
              if (id.isNotEmpty && rawCount != null) {
                results[id] = int.tryParse(rawCount) ?? 0;
              }
            }
          }
        } else {
          debugPrint(
            'YouTube statistics batch failed for chunk starting at $i: HTTP ${response.statusCode}',
          );
        }
      } catch (e) {
        debugPrint(
            'Error fetching view counts for batch starting at $i: ${e.runtimeType}');
      }
    }

    return results;
  }

  /// Fetches public playlists from a YouTube channel
  Future<List<PlaylistModel>> fetchChannelPlaylists({
    required String streamerId,
    String channelId = '',
    int maxResults = 10,
  }) async {
    if (channelId.isEmpty || !_canRead) return [];
    final cacheKey = '$streamerId:$channelId';
    if (_cachedPlaylists.containsKey(cacheKey)) {
      return _cachedPlaylists[cacheKey]!;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/playlists?part=snippet,contentDetails&channelId=$channelId&maxResults=$maxResults&key=$apiKey',
      );

      final response = await _get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;

        if (items != null && items.isNotEmpty) {
          final playlists = <PlaylistModel>[];
          for (final item in items) {
            final playlistId = item['id'] as String;
            final snippet = item['snippet'] as Map<String, dynamic>?;
            final contentDetails =
                item['contentDetails'] as Map<String, dynamic>?;

            final title = snippet?['title'] as String? ?? 'YouTube Playlist';
            final description = snippet?['description'] as String? ?? '';
            final videoCount = contentDetails?['itemCount'] as int? ?? 5;

            final thumbnails = snippet?['thumbnails'] as Map<String, dynamic>?;
            final thumbUrl = thumbnails?['high']?['url'] as String? ??
                thumbnails?['medium']?['url'] as String? ??
                '';

            playlists.add(
              PlaylistModel(
                playlistId: playlistId,
                streamerId: streamerId,
                titleEn: title,
                titleAr: title,
                descriptionEn: description.isNotEmpty
                    ? description
                    : 'Official playlist from @ahmedamercaller YouTube channel.',
                descriptionAr: description.isNotEmpty
                    ? description
                    : 'قائمة تشغيل رسمية من قناة الداعية أحمد عامر.',
                youtubePlaylistUrl:
                    'https://www.youtube.com/playlist?list=$playlistId',
                thumbnailUrl: thumbUrl,
                videoCount: videoCount,
                videos: const [],
              ),
            );
          }

          if (playlists.isNotEmpty) {
            _cachedPlaylists[cacheKey] = playlists;
            return playlists;
          }
        }
      }
    } catch (e) {
      debugPrint(
          'Error fetching playlists for channel $channelId: ${e.runtimeType}');
    }

    return [];
  }
}
