import 'package:flutter/material.dart';

import 'adapters/aws_ivs_player_adapter.dart';
import 'adapters/web_live_player_adapter.dart';
import 'adapters/youtube_player_adapter.dart';

export 'adapters/aws_ivs_player_adapter.dart';
export 'adapters/web_live_player_adapter.dart';
export 'adapters/youtube_player_adapter.dart';

/// Supported video streaming source engines in the application.
enum StreamSourceType {
  localRtmp,
  awsIvsHls,
  youtubeEmbed,
}

/// Lifecycle states of a video stream playback session.
///
/// Cluster 1 Task 4a added [startingSoon], [reconnecting] and [noAudioToken]
/// so `StreamStatePlaceholderOverlay` can distinguish "the broadcast hasn't
/// begun yet", "we lost the feed and are retrying" and "the audio token
/// couldn't be synced" from the generic [offline]/[fallbackError] pair the
/// player adapters used to collapse all three into.
enum StreamState {
  initializing,
  startingSoon,
  live,
  paused,
  buffering,
  reconnecting,
  ended,
  offline,
  noAudioToken,
  fallbackError,
}

/// Polymorphic abstract video player interface widget for educational broadcasts.
///
/// Implementations (`WebLivePlayerAdapter`, `AwsIvsPlayerAdapter`, `YouTubePlayerAdapter`)
/// standardize video playback, loading states, error handling, and lifecycle disposal.
abstract class AbstractVideoPlayer extends StatefulWidget {
  final String streamUrl;
  final bool autoPlay;
  final VoidCallback? onPlayerReady;
  final ValueChanged<StreamState>? onStateChanged;
  final ValueChanged<String>? onError;
  final double aspectRatio;

  /// The rendition the viewer pinned in the overlay's quality selector --
  /// `auto | 1080 | 720 | 480 | 360` (Cluster 1 Task 2). Adapters that can
  /// honour it do; the rest ignore it. `auto` means "let the engine's own
  /// adaptive logic decide", which is the default.
  final String preferredQuality;
  final List<String> fallbackUrls;

  const AbstractVideoPlayer({
    super.key,
    required this.streamUrl,
    this.autoPlay = true,
    this.onPlayerReady,
    this.onStateChanged,
    this.onError,
    this.aspectRatio = 16 / 9,
    this.preferredQuality = 'auto',
    this.fallbackUrls = const [],
  });

  /// Polymorphic factory constructor instantiating concrete player adapters based on [sourceType].
  factory AbstractVideoPlayer.fromSource({
    Key? key,
    required StreamSourceType sourceType,
    required String streamUrl,
    bool autoPlay = true,
    VoidCallback? onPlayerReady,
    ValueChanged<StreamState>? onStateChanged,
    ValueChanged<String>? onError,
    double aspectRatio = 16 / 9,
    String preferredQuality = 'auto',
    List<String> fallbackUrls = const [],
  }) {
    switch (sourceType) {
      case StreamSourceType.localRtmp:
        return WebLivePlayerAdapter(
          key: key,
          streamUrl: streamUrl,
          autoPlay: autoPlay,
          onPlayerReady: onPlayerReady,
          onStateChanged: onStateChanged,
          onError: onError,
          aspectRatio: aspectRatio,
          preferredQuality: preferredQuality,
        );
      case StreamSourceType.awsIvsHls:
        return AwsIvsPlayerAdapter(
          key: key,
          streamUrl: streamUrl,
          autoPlay: autoPlay,
          onPlayerReady: onPlayerReady,
          onStateChanged: onStateChanged,
          onError: onError,
          aspectRatio: aspectRatio,
          preferredQuality: preferredQuality,
        );
      case StreamSourceType.youtubeEmbed:
        return YouTubePlayerAdapter(
          key: key,
          streamUrl: streamUrl,
          fallbackUrls: fallbackUrls,
          autoPlay: autoPlay,
          onPlayerReady: onPlayerReady,
          onStateChanged: onStateChanged,
          onError: onError,
          aspectRatio: aspectRatio,
          preferredQuality: preferredQuality,
        );
    }
  }
}
