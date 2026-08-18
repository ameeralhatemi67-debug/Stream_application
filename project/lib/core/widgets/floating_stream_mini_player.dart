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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!provider.isMiniPlayerActive) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final playerWidth = isDesktop ? 340.0 : 280.0;
    final playerHeight = isDesktop ? 96.0 : 84.0;

    return Positioned(
      left: _position.dx.clamp(12.0, size.width - playerWidth - 12.0),
      top: _position.dy.clamp(60.0, size.height - playerHeight - 90.0),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
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
                          color: AppTheme.accentRed,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'live.live_indicator'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
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
