import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class FloatingStreamMiniPlayer extends StatefulWidget {
  const FloatingStreamMiniPlayer({super.key});

  @override
  State<FloatingStreamMiniPlayer> createState() => _FloatingStreamMiniPlayerState();
}

class _FloatingStreamMiniPlayerState extends State<FloatingStreamMiniPlayer> {
  Offset _position = const Offset(16, 120);
  bool _controlsVisible = true;

  // Insets the card is kept inside: clear of status bar and bottom nav
  static const double _edgeInset = 12.0;
  static const double _topInset = 60.0;
  static const double _bottomInset = 90.0;

  /// Clamping to keep card inside the viewport during and after dragging.
  Offset _clampToScreen(
      Offset position, Size screen, double width, double height) {
    final maxDx = screen.width - width - _edgeInset;
    final maxDy = screen.height - height - _bottomInset;
    return Offset(
      maxDx <= _edgeInset ? _edgeInset : position.dx.clamp(_edgeInset, maxDx),
      maxDy <= _topInset ? _topInset : position.dy.clamp(_topInset, maxDy),
    );
  }

  void _expandToFullScreen(BuildContext context, AppProvider provider) {
    final streamId = provider.miniPlayerStreamId ?? 'stream_live_992';
    provider.closeMiniPlayer();
    context.push('/live/$streamId');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!provider.isMiniPlayerActive) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final playerWidth = isDesktop ? 220.0 : 175.0;
    final playerHeight = isDesktop ? 130.0 : 110.0;

    // Re-clamp on every build so rotation / window resize never strands card
    final position = _clampToScreen(_position, size, playerWidth, playerHeight);

    final isAudioOnly = provider.isMiniPlayerAudioOnly;
    final accentColor =
        isAudioOnly ? AppTheme.accent : AppTheme.danger;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = _clampToScreen(
                position + details.delta, size, playerWidth, playerHeight);
          });
        },
        onDoubleTap: () => _expandToFullScreen(context, provider),
        child: Material(
          elevation: 16,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            width: playerWidth,
            height: playerHeight,
            decoration: BoxDecoration(
              color: AppTheme.media,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.8),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.media.withValues(alpha: 0.7),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd - 1.4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Media Preview Area (Video Thumbnail or Audio Stage Avatar)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _controlsVisible = !_controlsVisible;
                      });
                    },
                    child: Container(
                      color: AppTheme.media,
                      child: isAudioOnly
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.2),
                                      border: Border.all(
                                        color: AppTheme.accent
                                            .withValues(alpha: 0.6),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.headphones_rounded,
                                      color: AppTheme.accent,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'live.audio_live_indicator'.tr(),
                                    style: const TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Image.network(
                              'https://images.unsplash.com/photo-1518770660439-4636190af475?w=400&auto=format&fit=crop&q=80',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: AppTheme.surface,
                                child: const Icon(
                                  Icons.videocam_rounded,
                                  color: AppTheme.textMuted,
                                  size: 28,
                                ),
                              ),
                            ),
                    ),
                  ),

                  // 2. Bottom Title & Live Pill Overlay (Tappable to expand)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _expandToFullScreen(context, provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: const BoxDecoration(color: AppTheme.media),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                provider.miniPlayerTitle,
                                style: const TextStyle(
                                  color: AppTheme.onMedia,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Floating Overlay Controls (Fade In / Out on Tap)
                  IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Semi-transparent backdrop when controls are visible (must not intercept button taps)
                          IgnorePointer(
                            child: Container(
                              color: AppTheme.media.withValues(alpha: 0.25),
                            ),
                          ),

                          // Top-Left: Mute / Unmute Button
                          Positioned(
                            top: 6,
                            left: 6,
                            child: IconButton(
                              key: const ValueKey('mini_player_mute_button'),
                              icon: Icon(
                                provider.isMiniPlayerMuted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                size: 16,
                                color: provider.isMiniPlayerMuted
                                    ? AppTheme.warning
                                    : AppTheme.onMedia,
                              ),
                              onPressed: provider.toggleMiniPlayerMute,
                              padding: const EdgeInsets.all(5),
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.media.withValues(alpha: 0.75),
                                shape: const CircleBorder(
                                  side: BorderSide(color: AppTheme.onMedia, width: 0.8),
                                ),
                              ),
                            ),
                          ),

                          // Top-Right: Close Button
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IconButton(
                              key: const ValueKey('mini_player_close_button'),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppTheme.onMedia,
                              ),
                              onPressed: provider.closeMiniPlayer,
                              padding: const EdgeInsets.all(5),
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.media.withValues(alpha: 0.75),
                                shape: const CircleBorder(
                                  side: BorderSide(color: AppTheme.onMedia, width: 0.8),
                                ),
                              ),
                            ),
                          ),

                          // Center Tap-to-Expand Indicator
                          Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    _expandToFullScreen(context, provider),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.media.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.open_in_full_rounded,
                                    size: 16,
                                    color: AppTheme.onMedia,
                                  ),
                                ),
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
          ),
        ),
      ),
    );
  }
}
