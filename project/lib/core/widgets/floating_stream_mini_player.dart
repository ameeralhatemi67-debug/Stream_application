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
  Offset _position = const Offset(12, 100);

  // Insets the card is kept inside: clear of the status bar at the top and
  // of the bottom navigation bar / gesture area at the bottom.
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
    final playerWidth =
        isDesktop ? 360.0 : (size.width - 24.0).clamp(280.0, 420.0);
    const playerHeight = 64.0;

    // Re-clamp on every build so a rotation or window resize can never
    // strand the card outside the new viewport.
    final position = _clampToScreen(_position, size, playerWidth, playerHeight);

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
        child: Material(
          elevation: 14,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            width: playerWidth,
            height: playerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF18181C),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: provider.isMiniPlayerAudioOnly
                    ? AppTheme.accentPurple.withValues(alpha: 0.7)
                    : AppTheme.accentRed.withValues(alpha: 0.7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: provider.isMiniPlayerAudioOnly
                      ? AppTheme.accentPurple.withValues(alpha: 0.20)
                      : AppTheme.accentRed.withValues(alpha: 0.20),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. YouTube-Style 16:9 Thumbnail Preview with Badge
                GestureDetector(
                  onTap: () => _expandToFullScreen(context, provider),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 82,
                      height: 48,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: Colors.black,
                            child: Image.network(
                              'https://images.unsplash.com/photo-1518770660439-4636190af475?w=400&auto=format&fit=crop&q=80',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: AppTheme.darkSurface1,
                                child: const Icon(
                                  Icons.play_circle_outline_rounded,
                                  color: AppTheme.textMutedDark,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          // Live Indicator Tag
                          Positioned(
                            top: 3,
                            left: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: provider.isMiniPlayerAudioOnly
                                    ? AppTheme.accentPurple
                                    : AppTheme.accentRed,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (provider.isMiniPlayerAudioOnly) ...[
                                    const Icon(Icons.headphones_rounded,
                                        size: 8, color: Colors.white),
                                    const SizedBox(width: 2.5),
                                  ],
                                  Text(
                                    provider.isMiniPlayerAudioOnly
                                        ? 'live.audio_live_indicator'.tr()
                                        : 'live.live_indicator'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
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
                const SizedBox(width: 10),

                // 2. Lecture Title & Streamer Name (Flexible, never overflows)
                Expanded(
                  child: InkWell(
                    onTap: () => _expandToFullScreen(context, provider),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.miniPlayerTitle,
                            style: const TextStyle(
                              color: AppTheme.textPrimaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            provider.miniPlayerStreamerName,
                            style: const TextStyle(
                              color: AppTheme.textSecondaryDark,
                              fontSize: 11,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // 3. YouTube-Style Action Buttons: Play/Pause and Close
                IconButton(
                  icon: Icon(
                    provider.isMiniPlayerPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                  onPressed: provider.toggleMiniPlayerPlayPause,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: provider.isMiniPlayerPlaying ? 'Pause' : 'Play',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.textMutedDark,
                  ),
                  onPressed: provider.closeMiniPlayer,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 32),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
