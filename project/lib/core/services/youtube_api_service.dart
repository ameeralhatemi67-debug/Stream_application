import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/profile/models/vod_models.dart';


/// Service for communicating with YouTube Data API v3 REST endpoints.
class YouTubeApiService {
  /// Injected at build/run time via `--dart-define=YOUTUBE_API_KEY=...`
  /// (or --dart-define-from-file for local dev). Never hardcode a real key
  /// here -- see doc/Audit/01_Security_Data_Protection_Audit.md VULN-DATA-01.
  static const String _defaultApiKey =
      String.fromEnvironment('YOUTUBE_API_KEY');
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  final String apiKey;
  final http.Client _client;

  // In-memory caching to optimize API quota usage
  final Map<String, List<VodModel>> _cachedVods = {};
  final Map<String, List<PlaylistModel>> _cachedPlaylists = {};

  YouTubeApiService({
    String? apiKey,
    http.Client? client,
  })  : apiKey = apiKey ?? _defaultApiKey,
        _client = client ?? http.Client();

  /// Resolves channel handle or URL (e.g. '@ahmedamercaller' or 'https://www.youtube.com/@dalilk4english_podcast/videos') to channel ID and uploads playlist ID
  Future<Map<String, String>> fetchChannelDetails(String handleOrUrl) async {
    String cleanHandle = handleOrUrl.trim();
    cleanHandle = cleanHandle.replaceAll('https://www.youtube.com/', '');
    cleanHandle = cleanHandle.replaceAll('http://www.youtube.com/', '');
    cleanHandle = cleanHandle.replaceAll('https://youtube.com/', '');
    cleanHandle = cleanHandle.replaceAll('http://youtube.com/', '');
    cleanHandle = cleanHandle.replaceAll('www.youtube.com/', '');
    cleanHandle = cleanHandle.replaceAll('youtube.com/', '');
    cleanHandle = cleanHandle.replaceAll('/videos', '');
    cleanHandle = cleanHandle.replaceAll('/featured', '');
    cleanHandle = cleanHandle.replaceAll('/playlists', '');
    cleanHandle = cleanHandle.replaceAll('/streams', '');
    cleanHandle = cleanHandle.replaceAll('@', '');
    if (cleanHandle.contains('?')) {
      cleanHandle = cleanHandle.split('?').first;
    }
    cleanHandle = cleanHandle.replaceAll('/', '').trim();

    final url = Uri.parse(
      '$_baseUrl/channels?part=snippet,contentDetails&forHandle=$cleanHandle&key=$apiKey',
    );

    try {
      final response = await _client.get(url);
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

          return {
            'channelId': channelId,
            'uploadsPlaylistId': uploadsPlaylistId,
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching channel details for $handleOrUrl: $e');
    }

    // Default fallback mappings if YouTube API response fails
    final lower = cleanHandle.toLowerCase();
    if (lower == 'bidonwaraq') {
      return {
        'channelId': 'UC7mCgzz-LYRt-a3mCvUbccg',
        'uploadsPlaylistId': 'UU7mCgzz-LYRt-a3mCvUbccg',
      };
    } else if (lower == 'amiralhatime4831') {
      return {
        'channelId': 'UCdPq2Mayw6k-WuvBMKNj44A',
        'uploadsPlaylistId': 'UUdPq2Mayw6k-WuvBMKNj44A',
      };
    } else if (lower == 'dalilk4ielts') {
      return {
        'channelId': 'UCtH_J6a0r53rX7Zl2qGz_Qw',
        'uploadsPlaylistId': 'UUtH_J6a0r53rX7Zl2qGz_Qw',
      };
    } else if (lower == 'dalilk4english') {
      return {
        'channelId': 'UC4EnglishDalilkSampleId',
        'uploadsPlaylistId': 'UU4EnglishDalilkSampleId',
      };
    } else if (lower == 'dalilk4english_podcast') {
      return {
        'channelId': 'UCPodcastDalilkSampleId',
        'uploadsPlaylistId': 'UUPodcastDalilkSampleId',
      };
    } else if (lower == 'alquran4kofficial') {
      return {
        'channelId': 'UCQuran4KOfficialSampleId',
        'uploadsPlaylistId': 'UUQuran4KOfficialSampleId',
      };
    }

    return {
      'channelId': 'UCah56qawts736uNxZA3inLQ',
      'uploadsPlaylistId': 'UUah56qawts736uNxZA3inLQ',
    };
  }

  /// Fetches recent videos from a YouTube channel's uploads playlist
  Future<List<VodModel>> fetchChannelVideos({
    required String streamerId,
    String handle = 'ahmedamercaller',
    int maxResults = 25,
  }) async {
    if (_cachedVods.containsKey(streamerId)) {
      return _cachedVods[streamerId]!;
    }

    try {
      final channelDetails = await fetchChannelDetails(handle);
      final uploadsPlaylistId = channelDetails['uploadsPlaylistId']!;

      final url = Uri.parse(
        '$_baseUrl/playlistItems?part=snippet,contentDetails&playlistId=$uploadsPlaylistId&maxResults=$maxResults&key=$apiKey',
      );

      final response = await _client.get(url);
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
            final dateStr = publishedAt.length >= 10
                ? publishedAt.substring(0, 10)
                : '2026-08-01';

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
                durationSeconds: 2400,
                recordedDate: dateStr,
                thumbnailUrl: thumbUrl,
                viewCount: 0, // Will be hydrated below via statistics batch call
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

            _cachedVods[streamerId] = hydratedVods;
            return hydratedVods;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching channel videos for $streamerId ($handle): $e');
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

      final response = await _client.get(url);
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
            final dateStr = publishedAt.length >= 10
                ? publishedAt.substring(0, 10)
                : '2026-08-01';

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
                durationSeconds: 1800,
                recordedDate: dateStr,
                thumbnailUrl: thumbUrl,
                viewCount: 0, // Will be hydrated below via statistics batch call
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
      debugPrint('Error fetching playlist items for $playlistId: $e');
    }

    return [];
  }

  /// Looks up the currently-live broadcast video ID for a given channel,
  /// using the YouTube Data API's search endpoint (eventType=live).
  /// Returns null if the channel has no active live broadcast right now
  /// (e.g. OBS hasn't started streaming, or "Go Live" hasn't been clicked
  /// yet in YouTube Studio).
  Future<String?> fetchLiveVideoId(String channelId) async {
    final url = Uri.parse(
      '$_baseUrl/search?part=snippet&channelId=$channelId&eventType=live&type=video&key=$apiKey',
    );

    try {
      final response = await _client.get(url);
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
        debugPrint(
          'YouTube live lookup failed for channel $channelId: HTTP ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching live video for channel $channelId: $e');
    }

    return null;
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
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;

        if (items != null && items.isNotEmpty) {
          final liveDetails = (items.first as Map<String, dynamic>)['liveStreamingDetails']
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
        final response = await _client.get(url);
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
        debugPrint('Error fetching view counts for batch starting at $i: $e');
      }
    }

    return results;
  }

  /// Fetches public playlists from a YouTube channel
  Future<List<PlaylistModel>> fetchChannelPlaylists({
    required String streamerId,
    String channelId = 'UCah56qawts736uNxZA3inLQ',
    int maxResults = 10,
  }) async {
    if (_cachedPlaylists.containsKey(streamerId)) {
      return _cachedPlaylists[streamerId]!;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/playlists?part=snippet,contentDetails&channelId=$channelId&maxResults=$maxResults&key=$apiKey',
      );

      final response = await _client.get(url);
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
                'https://i.ytimg.com/vi/default/hqdefault.jpg';

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
            _cachedPlaylists[streamerId] = playlists;
            return playlists;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching playlists for channel $channelId: $e');
    }

    return [];
  }
}
