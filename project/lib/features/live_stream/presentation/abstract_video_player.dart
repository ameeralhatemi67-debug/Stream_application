import 'package:flutter/material.dart';

import 'adapters/aws_ivs_player_adapter.dart';
import 'adapters/web_live_player_adapter.dart';
import 'adapters/youtube_player_adapter.dart';

export 'adapters/aws_ivs_player_adapter.dart';
export 'adapters/vlc_player_adapter.dart';
export 'adapters/web_live_player_adapter.dart';
export 'adapters/youtube_player_adapter.dart';

/// Supported video streaming source engines in the application.
enum StreamSourceType {
  localRtmp,
  awsIvsHls,
  youtubeEmbed,
}

/// Lifecycle states of a video stream playback session.
enum StreamState {
  initializing,
  live,
  paused,
  buffering,
  ended,
  offline,
  fallbackError,
}

/// Polymorphic abstract video player interface widget for educational broadcasts.
///
/// Implementations (`WebLivePlayerAdapter`, `VlcPlayerAdapter`, `AwsIvsPlayerAdapter`, `YouTubePlayerAdapter`)
/// standardize video playback, loading states, error handling, and lifecycle disposal.
abstract class AbstractVideoPlayer extends StatefulWidget {
  final String streamUrl;
  final bool autoPlay;
  final VoidCallback? onPlayerReady;
  final ValueChanged<StreamState>? onStateChanged;
  final ValueChanged<String>? onError;
  final double aspectRatio;

  const AbstractVideoPlayer({
    super.key,
    required this.streamUrl,
    this.autoPlay = true,
    this.onPlayerReady,
    this.onStateChanged,
    this.onError,
    this.aspectRatio = 16 / 9,
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
        );
      case StreamSourceType.youtubeEmbed:
        return YouTubePlayerAdapter(
          key: key,
          streamUrl: streamUrl,
          autoPlay: autoPlay,
          onPlayerReady: onPlayerReady,
          onStateChanged: onStateChanged,
          onError: onError,
          aspectRatio: aspectRatio,
        );
    }
  }
}
