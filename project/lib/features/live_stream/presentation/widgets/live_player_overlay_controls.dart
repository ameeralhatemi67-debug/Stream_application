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

  /// Whether the server says this room's broadcast is live. The LIVE badge
  /// follows that, not the player: a playing video is not proof of a live
  /// broadcast.
  final bool showLiveBadge;

  /// Live viewers counted by the server, or null while unknown (P3 /
  /// 05 D-08). Null renders as "—": the app never shows a number it does not
  /// have.
  final int? viewerCount;
  final bool isPlaying;
  final bool isMuted;
  final bool isFullscreen;

  /// Audio-only broadcasts have no video track to pick a rendition for, so
  /// the quality selector is hidden outright rather than shown inert.
  final bool isAudioOnly;

  /// False where the app cannot command the player (the web iframe): the
  /// play/pause and mute buttons are hidden instead of shown inert, and the
  /// player's own controls are used.
  final bool showTransportControls;
  final bool showQualitySelector;

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
    this.showLiveBadge = true,
    required this.viewerCount,
    required this.isPlaying,
    required this.isMuted,
    required this.isFullscreen,
    required this.onTogglePlayPause,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onRetryConnection,
    this.isAudioOnly = false,
    this.showTransportControls = true,
    this.showQualitySelector = true,
    this.isStreamerMicMuted = false,
    this.selectedQuality = StreamQualityLevel.auto,
    required this.onSelectQuality,
  });

  @override
  State<LivePlayerOverlayControls> createState() =>
      LivePlayerOverlayControlsState();
}

class LivePlayerOverlayControlsState extends State<LivePlayerOverlayControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showControls = true;
  final FocusNode _controlsFocus = FocusNode(debugLabel: 'viewer-controls');

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
    _controlsFocus.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void toggleControlsVisibility() {
    if (_showControls &&
        (_controlsFocus.hasFocus ||
            MediaQuery.of(context).accessibleNavigation)) {
      return;
    }
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

    return Focus(
      focusNode: _controlsFocus,
      child: Stack(
        children: [
          if (!isPlaceholderVisible)
            PositionedDirectional(
                top: 8,
                start: 12,
                child: IconButton(
                  tooltip: 'live.toggle_player_controls'.tr(),
                  onPressed: () {
                    if (_showControls && _controlsFocus.hasFocus) {
                      // An explicit Hide button may release its own focus; a media
                      // tap never removes focused controls.
                      _controlsFocus.unfocus();
                    }
                    if (!MediaQuery.of(context).accessibleNavigation) {
                      setState(() => _showControls = !_showControls);
                    }
                  },
                  icon: Icon(
                      _showControls
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.onMedia),
                )),
          // Top Header Overlay: Live Badge, Viewer count pill, Quality Selector (Video only)
          if (controlsVisible && !widget.isAudioOnly)
            PositionedDirectional(
              top: 8,
              start: 72,
              end: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulsing Red Live Badge
                        if (widget.showLiveBadge)
                          FadeTransition(
                            opacity: _pulseAnimation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.danger,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'live.live_indicator'.tr(),
                                style: const TextStyle(
                                  color: AppTheme.onMedia,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),

                        // Viewer Counter Pill. It gives way before the LIVE
                        // badge does: on a 320 px phone at text scale 2.0 the
                        // badge and the pill together overran the header row,
                        // and the count matters less than the fact that the
                        // room is live.
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.media.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.remove_red_eye_outlined,
                                    size: 12, color: AppTheme.onMedia),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '${widget.viewerCount ?? '—'} ${'feed.watching'.tr()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.onMedia,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quality Selector -- video renditions only
                  if (widget.showQualitySelector) _buildQualitySelector(),
                ],
              ),
            ),

          // Streamer Silence / Mic Muted Badge (Task 1). Deliberately shown
          // even while the controls are hidden: it explains why the viewer
          // is hearing nothing, which is exactly when they stop tapping.
          if (widget.isStreamerMicMuted && !isPlaceholderVisible)
            PositionedDirectional(
              top: 44,
              end: 12,
              child: _buildMicMutedPill(),
            ),

          // Bottom Action Controls Overlay (Play/Pause, Mute/Unmute, Fullscreen)
          if (controlsVisible)
            PositionedDirectional(
              bottom: 8,
              start: 12,
              end: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!widget.isAudioOnly && widget.showTransportControls)
                    Row(
                      children: [
                        _mediaButton(
                          key: const Key('room-play-pause'),
                          icon: widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          tooltip: (widget.isPlaying
                                  ? 'live.tooltip_pause'
                                  : 'live.tooltip_play')
                              .tr(),
                          onPressed: widget.onTogglePlayPause,
                        ),
                        const SizedBox(width: 4),
                        _mediaButton(
                          key: const Key('room-mute'),
                          icon: widget.isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          tooltip: (widget.isMuted
                                  ? 'live.tooltip_unmute'
                                  : 'live.tooltip_mute')
                              .tr(),
                          onPressed: widget.onToggleMute,
                        ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),

                  // Fullscreen Toggle Button -- rotates the device into
                  // landscape immersive mode (available on all streams).
                  _mediaButton(
                    key: const Key('room-fullscreen'),
                    icon: widget.isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    tooltip: (widget.isFullscreen
                            ? 'live.tooltip_exit_fullscreen'
                            : 'live.tooltip_fullscreen')
                        .tr(),
                    onPressed: widget.onToggleFullscreen,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// A 48 dp media control with a tooltip (also its screen-reader label).
  Widget _mediaButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: () {
        FocusScope.of(context).unfocus();
        onPressed();
      },
      icon: Icon(icon, color: AppTheme.onMedia, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.media.withValues(alpha: 0.6),
        minimumSize: const Size(48, 48),
        shape: const CircleBorder(),
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
      color: AppTheme.surfaceAlt,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.media.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.6), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hd_outlined, size: 14, color: AppTheme.primary),
            const SizedBox(width: 4),
            Text(
              widget.selectedQuality.shortLabel,
              style: const TextStyle(
                color: AppTheme.onMedia,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(Icons.arrow_drop_down,
                size: 14, color: AppTheme.onMedia.withValues(alpha: 0.7)),
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
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                quality.labelKey.tr(),
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.onMedia,
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
          color: AppTheme.media.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: AppTheme.warning, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_off_rounded,
                size: 13, color: AppTheme.warning),
            const SizedBox(width: 6),
            Text(
              '${'live.mic_muted_badge'.tr()} · ${'live.mic_silent_badge'.tr()}',
              style: const TextStyle(
                color: AppTheme.warning,
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
