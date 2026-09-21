import 'package:flutter/material.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';

/// A player that renders the media box without a platform engine.
///
/// The real adapters build a `WebViewController`, which asserts under the
/// widget tester because no `WebViewPlatform` is registered. This stub stands
/// in for them through [AbstractVideoPlayer.debugPlayerFactory] so the live
/// room can be laid out at every size, scale and locale the sweep covers.
///
/// It reports [reportedState] once after the first frame, which is what drives
/// the room's placeholder overlays: that makes "starting soon", "reconnecting",
/// "offline" and "playback failed" reachable as *layouts* without a network.
class StubVideoPlayer extends AbstractVideoPlayer {
  /// State handed to `onStateChanged` after the first frame.
  final StreamState reportedState;

  /// Error string handed to `onError`, for the failure-path layouts.
  final String? reportedError;

  const StubVideoPlayer({
    super.key,
    required super.streamUrl,
    super.autoPlay,
    super.onPlayerReady,
    super.onStateChanged,
    super.onError,
    super.aspectRatio,
    super.preferredQuality,
    super.fallbackUrls,
    this.reportedState = StreamState.live,
    this.reportedError,
  });

  /// Installs this stub as the player for the rest of the test, and removes it
  /// again on tear-down so one test never leaks its player state into the next.
  static void install({
    StreamState state = StreamState.live,
    String? error,
    required void Function(void Function()) addTearDown,
  }) {
    AbstractVideoPlayer.debugPlayerFactory = ({
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
    }) =>
        StubVideoPlayer(
          key: key,
          streamUrl: streamUrl,
          autoPlay: autoPlay,
          onPlayerReady: onPlayerReady,
          onStateChanged: onStateChanged,
          onError: onError,
          aspectRatio: aspectRatio,
          preferredQuality: preferredQuality,
          fallbackUrls: fallbackUrls,
          reportedState: state,
          reportedError: error,
        );
    addTearDown(() => AbstractVideoPlayer.debugPlayerFactory = null);
  }

  @override
  State<StubVideoPlayer> createState() => _StubVideoPlayerState();
}

class _StubVideoPlayerState extends State<StubVideoPlayer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onPlayerReady?.call();
      widget.onStateChanged?.call(widget.reportedState);
      final error = widget.reportedError;
      if (error != null) widget.onError?.call(error);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Same shape and surface the real adapters occupy, so the room's
    // constraints are exercised as they are in production.
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: const ColoredBox(color: AppTheme.media),
    );
  }
}
