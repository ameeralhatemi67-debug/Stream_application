import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../abstract_video_player.dart';

/// Interactive player overlay controls for live broadcast screens.
class LivePlayerOverlayControls extends StatefulWidget {
  final StreamSourceType currentSource;
  final StreamState streamState;
  final int viewerCount;
  final bool isPlaying;
  final bool isMuted;
  final bool isFullscreen;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFullscreen;
  final ValueChanged<StreamSourceType> onSelectSource;
  final VoidCallback onRetryConnection;

  const LivePlayerOverlayControls({
    super.key,
    required this.currentSource,
    required this.streamState,
    required this.viewerCount,
    required this.isPlaying,
    required this.isMuted,
    required this.isFullscreen,
    required this.onTogglePlayPause,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onSelectSource,
    required this.onRetryConnection,
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

  String _getSourceLabel(StreamSourceType type) {
    switch (type) {
      case StreamSourceType.localRtmp:
        return '1080p (RTMP)';
      case StreamSourceType.awsIvsHls:
        return '720p (AWS IVS)';
      case StreamSourceType.youtubeEmbed:
        return '480p (YouTube)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = widget.streamState == StreamState.offline ||
        widget.streamState == StreamState.fallbackError;

    return GestureDetector(
      onTap: _toggleControlsVisibility,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Offline / Disconnection Reconnection Banner Overlay
          if (isOffline)
            Container(
              color: Colors.black.withValues(alpha: 0.88),
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: AppTheme.accentRed, size: 48),
                    const SizedBox(height: AppTheme.spaceMd),
                    Text(
                      'live.offline_title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'live.offline_sub'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text('live.retry_feed'.tr()),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        widget.onRetryConnection();
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Top Header Overlay: Live Badge, Viewer count pill, Quality Selector
          if (_showControls && !isOffline)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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

                  // Quality Selector Popup Menu Button (Unfocuses keyboard on tap)
                  PopupMenuButton<StreamSourceType>(
                    initialValue: widget.currentSource,
                    onOpened: () => FocusScope.of(context).unfocus(),
                    onSelected: (source) {
                      FocusScope.of(context).unfocus();
                      widget.onSelectSource(source);
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
                            _getSourceLabel(widget.currentSource),
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
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: StreamSourceType.localRtmp,
                        child: Row(
                          children: [
                            Icon(Icons.flash_on, color: AppTheme.accentRed, size: 16),
                            SizedBox(width: 8),
                            Text('1080p60 (Local RTMP Loopback)', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: StreamSourceType.awsIvsHls,
                        child: Row(
                          children: [
                            Icon(Icons.cloud_outlined, color: AppTheme.accentBlue, size: 16),
                            SizedBox(width: 8),
                            Text('720p60 (AWS IVS Low-Latency)', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: StreamSourceType.youtubeEmbed,
                        child: Row(
                          children: [
                            Icon(Icons.play_circle_fill, color: Colors.red, size: 16),
                            SizedBox(width: 8),
                            Text('480p (YouTube Embed)', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Bottom Action Controls Overlay (Play/Pause, Mute/Unmute, Fullscreen)
          if (_showControls && !isOffline)
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

                  // Fullscreen Toggle Button
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
}
