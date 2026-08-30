import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../abstract_video_player.dart';
import 'stream_state_placeholder_overlay.dart';

/// The playback resolutions a viewer can pin the player to.
///
/// Cluster 1 Task 2 replaced the old selector, which was really a
/// [StreamSourceType] switcher mislabelled with invented resolutions
/// ("1080p60 Local RTMP Loopback", "480p YouTube Embed") -- picking "1080p"
/// swapped the whole playback engine rather than the rendition. These are
/// resolutions, and nothing else.
enum StreamQualityLevel { auto, p1080, p720, p480, p360 }

extension StreamQualityLevelInfo on StreamQualityLevel {
  /// The value handed to the player engine (and stored/compared): the plan's
  /// `auto | 1080 | 720 | 480 | 360`.
  String get value {
    switch (this) {
      case StreamQualityLevel.auto:
        return 'auto';
      case StreamQualityLevel.p1080:
        return '1080';
      case StreamQualityLevel.p720:
        return '720';
      case StreamQualityLevel.p480:
        return '480';
      case StreamQualityLevel.p360:
        return '360';
    }
  }

  /// Full bilingual menu-row label.
  String get labelKey {
    switch (this) {
      case StreamQualityLevel.auto:
        return 'live.quality_auto';
      case StreamQualityLevel.p1080:
        return 'live.quality_1080';
      case StreamQualityLevel.p720:
        return 'live.quality_720';
      case StreamQualityLevel.p480:
        return 'live.quality_480';
      case StreamQualityLevel.p360:
        return 'live.quality_360';
    }
  }

  /// Compact label for the collapsed pill ("720p", "Auto").
  String get shortLabel {
    switch (this) {
      case StreamQualityLevel.auto:
        return 'live.quality_auto_short'.tr();
      default:
        return '${value}p';
    }
  }

  static StreamQualityLevel fromValue(String value) {
    return StreamQualityLevel.values.firstWhere(
      (q) => q.value == value,
      orElse: () => StreamQualityLevel.auto,
    );
  }
}

/// Interactive player overlay controls for live broadcast screens.
///
/// Non-playing states ([StreamState.offline], [StreamState.fallbackError],
/// ...) are no longer drawn here: `StreamStatePlaceholderOverlay` owns every
/// placeholder surface as of Cluster 1 Task 4a. This widget only hides its
/// own controls while one of those states is on screen.
class LivePlayerOverlayControls extends StatefulWidget {
  final StreamState streamState;
  final int viewerCount;
  final bool isPlaying;
  final bool isMuted;
  final bool isFullscreen;

  /// Audio-only broadcasts have no video track to pick a rendition for, so
  /// the quality selector is hidden outright rather than shown inert.
  final bool isAudioOnly;

  /// True while the broadcaster's own microphone is muted or has been silent
  /// long enough to count as intentional silence -- viewers get an explicit
  /// badge instead of wondering whether their own audio broke.
  final bool isStreamerMicMuted;

  final StreamQualityLevel selectedQuality;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFullscreen;
  final ValueChanged<StreamQualityLevel> onSelectQuality;
  final VoidCallback onRetryConnection;

  const LivePlayerOverlayControls({
    super.key,
    required this.streamState,
    required this.viewerCount,
    required this.isPlaying,
    required this.isMuted,
    required this.isFullscreen,
    required this.onTogglePlayPause,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onRetryConnection,
    this.isAudioOnly = false,
    this.isStreamerMicMuted = false,
    this.selectedQuality = StreamQualityLevel.auto,
    required this.onSelectQuality,
  });

  @override
  State<LivePlayerOverlayControls> createState() => _LivePlayerOverlayControlsState();
}

class _LivePlayerOverlayControlsState extends State<LivePlayerOverlayControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleControlsVisibility() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    // A placeholder state (offline, error, ended, starting soon, ...) means
    // StreamStatePlaceholderOverlay is painting the whole viewport; the
    // transport controls would only sit uselessly on top of it.
    final isPlaceholderVisible =
        StreamStatePlaceholderOverlay.coversState(widget.streamState);
    final controlsVisible = _showControls && !isPlaceholderVisible;

    return GestureDetector(
      onTap: _toggleControlsVisibility,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Top Header Overlay: Live Badge, Viewer count pill, Quality Selector
          if (controlsVisible)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulsing Red Live Badge
                        FadeTransition(
                          opacity: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'live.live_indicator'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Viewer Counter Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.remove_red_eye_outlined, size: 12, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                '${widget.viewerCount} ${'feed.watching'.tr()}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quality Selector -- video renditions only, so it is
                  // absent entirely on audio-only broadcasts (Task 2).
                  if (!widget.isAudioOnly) _buildQualitySelector(),
                ],
              ),
            ),

          // Streamer Silence / Mic Muted Badge (Task 1). Deliberately shown
          // even while the controls are hidden: it explains why the viewer
          // is hearing nothing, which is exactly when they stop tapping.
          if (widget.isStreamerMicMuted && !isPlaceholderVisible)
            Positioned(
              top: 44,
              right: 12,
              child: _buildMicMutedPill(),
            ),

          // Bottom Action Controls Overlay (Play/Pause, Mute/Unmute, Fullscreen)
          if (controlsVisible)
            Positioned(
              bottom: 8,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Play / Pause Button
                      InkWell(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          widget.onTogglePlayPause();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Mute / Unmute Button
                      InkWell(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          widget.onToggleMute();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Fullscreen Toggle Button -- rotates the device into
                  // landscape immersive mode (Task 3).
                  InkWell(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      widget.onToggleFullscreen();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQualitySelector() {
    return PopupMenuButton<StreamQualityLevel>(
      initialValue: widget.selectedQuality,
      tooltip: 'live.quality'.tr(),
      onOpened: () => FocusScope.of(context).unfocus(),
      onSelected: (quality) {
        FocusScope.of(context).unfocus();
        widget.onSelectQuality(quality);
      },
      color: AppTheme.darkSurface2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.6), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hd_outlined, size: 14, color: AppTheme.accentBlue),
            const SizedBox(width: 4),
            Text(
              widget.selectedQuality.shortLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white70),
          ],
        ),
      ),
      itemBuilder: (context) => StreamQualityLevel.values.map((quality) {
        final isSelected = quality == widget.selectedQuality;
        return PopupMenuItem<StreamQualityLevel>(
          value: quality,
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_rounded : Icons.hd_outlined,
                color: isSelected ? AppTheme.accentBlue : AppTheme.textMutedDark,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                quality.labelKey.tr(),
                style: TextStyle(
                  color: isSelected ? AppTheme.accentBlue : Colors.white,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMicMutedPill() {
    return FadeTransition(
      opacity: _pulseAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: AppTheme.accentAmber, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_off_rounded, size: 13, color: AppTheme.accentAmber),
            const SizedBox(width: 6),
            Text(
              '${'live.mic_muted_badge'.tr()} · ${'live.mic_silent_badge'.tr()}',
              style: const TextStyle(
                color: AppTheme.accentAmber,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
