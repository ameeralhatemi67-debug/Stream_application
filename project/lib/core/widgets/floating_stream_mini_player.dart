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
  Offset _position = const Offset(20, 100);

  // Insets the card is kept inside: clear of the status bar at the top and
  // of the bottom navigation bar / gesture area at the bottom.
  static const double _edgeInset = 12.0;
  static const double _topInset = 60.0;
  static const double _bottomInset = 90.0;

  /// Cluster 1 Task 6 -- clamping has to happen when the drag is *recorded*,
  /// not only when it is rendered. Accumulating the raw delta and clamping
  /// at paint time let `_position` drift arbitrarily far off-screen while
  /// the card sat pinned at the edge, so the viewer then had to drag all the
  /// way back through that dead travel before it moved again.
  Offset _clampToScreen(Offset position, Size screen, double width, double height) {
    // On a viewport too small to hold the card within its insets the clamp
    // bounds invert; falling back to the inset keeps `clamp` from throwing.
    final maxDx = screen.width - width - _edgeInset;
    final maxDy = screen.height - height - _bottomInset;
    return Offset(
      maxDx <= _edgeInset ? _edgeInset : position.dx.clamp(_edgeInset, maxDx),
      maxDy <= _topInset ? _topInset : position.dy.clamp(_topInset, maxDy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!provider.isMiniPlayerActive) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final playerWidth = isDesktop ? 340.0 : 280.0;
    final playerHeight = isDesktop ? 96.0 : 84.0;

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
          elevation: 12,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            width: playerWidth,
            height: playerHeight,
            padding: const EdgeInsets.all(AppTheme.spaceSm),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface3,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppTheme.accentRed.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                // Video / Thumbnail Preview with Live badge
                Stack(
                  children: [
                    Container(
                      width: playerHeight * 1.3,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        image: const DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1518770660439-4636190af475?w=400&auto=format&fit=crop&q=80',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
                                  size: 9, color: Colors.white),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              provider.isMiniPlayerAudioOnly
                                  ? 'live.audio_live_indicator'.tr()
                                  : 'live.live_indicator'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppTheme.spaceSm),

                // Lecture Title & Streamer Name
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final streamId = provider.miniPlayerStreamId ?? 'stream_live_992';
                      provider.closeMiniPlayer();
                      context.push('/live/$streamId');
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.miniPlayerTitle,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.miniPlayerStreamerName,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryDark,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                // Controls: Play/Pause, Expand, Close
                IconButton(
                  icon: Icon(
                    provider.isMiniPlayerPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                    color: AppTheme.accentRed,
                  ),
                  onPressed: provider.toggleMiniPlayerPlayPause,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    size: 18,
                    color: AppTheme.textPrimaryDark,
                  ),
                  onPressed: () {
                    final streamId = provider.miniPlayerStreamId ?? 'stream_live_992';
                    provider.closeMiniPlayer();
                    context.push('/live/$streamId');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.textMutedDark,
                  ),
                  onPressed: provider.closeMiniPlayer,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
