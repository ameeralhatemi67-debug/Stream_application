import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../profile/models/streamer_models.dart';

class StreamerGridCard extends StatelessWidget {
  final StreamerModel streamer;
  final String langCode;

  const StreamerGridCard({
    super.key,
    required this.streamer,
    required this.langCode,
  });

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider?>();
    final isOwnCard = appProvider != null &&
        (appProvider.isLoggedInStreamer || appProvider.isStreamerModeEnabled) &&
        appProvider.isOwnStreamerProfile(streamer.streamerId);

    final isLive = streamer.isCurrentlyLive;
    final isAudio = streamer.isAudioLive;
    final isVideo = streamer.isVideoLive;

    Color borderColor;
    double borderWidth;
    if (isOwnCard) {
      borderColor = Colors.white;
      borderWidth = 1.8;
    } else if (isVideo) {
      borderColor = AppTheme.accentRed.withValues(alpha: 0.8);
      borderWidth = 1.5;
    } else if (isAudio) {
      borderColor = const Color(0xFFA1A1AA);
      borderWidth = 1.5;
    } else {
      borderColor = AppTheme.darkBorderSubtle;
      borderWidth = 1.0;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isLive && streamer.activeStreamId != null) {
            context.push('/live/${streamer.activeStreamId}');
          } else {
            context.push('/profile/${streamer.streamerId}');
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.darkSurface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: [
              if (isOwnCard)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              else
                BoxShadow(
                  color: isVideo
                      ? AppTheme.accentRed.withValues(alpha: 0.18)
                      : isAudio
                          ? const Color(0xFFA1A1AA).withValues(alpha: 0.15)
                          : Colors.black26,
                  blurRadius: isLive ? 10 : 4,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🖼️ Top Banner: Flexible 45% height (BoxFit.cover cut-to-fit, NO morphing)
              Expanded(
                flex: 45,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: _getImageProvider(streamer.bannerUrl),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.darkSurface3,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppTheme.textMutedDark),
                      ),
                    ),
                    // Subtle bottom gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black45],
                        ),
                      ),
                    ),
                    // LIVE Badge at top left (Video vs Audio)
                    if (isLive)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isVideo ? AppTheme.accentRed : const Color(0xFF3F3F46),
                            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                            border: Border.all(
                              color: isVideo
                                  ? AppTheme.accentRed.withValues(alpha: 0.6)
                                  : AppTheme.darkBorderSubtle,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                isVideo
                                    ? 'feed.badge_live'.tr()
                                    : 'live.audio_live_indicator'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // ✨ "Your Channel / قناتك" Badge at top right
                    if (isOwnCard)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                            border: Border.all(color: Colors.white, width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 11),
                              const SizedBox(width: 3),
                              Text(
                                langCode == 'ar' ? 'قناتك' : 'Your Channel',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 📝 Bottom Content: Flexible 62% height with zero overflow risk
              Expanded(
                flex: 55,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar & Name Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(1.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isLive
                                    ? AppTheme.accentRed
                                    : AppTheme.darkBorderHighlight,
                                width: 1.2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.darkSurface3,
                              backgroundImage:
                                  _getImageProvider(streamer.avatarUrl),
                              onBackgroundImageError: (_, __) {},
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        streamer.getLocalizedName(langCode),
                                        style: const TextStyle(
                                          color: AppTheme.textPrimaryDark,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (streamer.isVerified) ...[
                                      const SizedBox(width: 3),
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 12,
                                        color: AppTheme.accentPurple,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  streamer.getLocalizedTitle(langCode),
                                  style: const TextStyle(
                                    color: AppTheme.textSecondaryDark,
                                    fontSize: 9.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // 🏷️ Centered Tag Pills
                      if (streamer.tags.isNotEmpty)
                        SizedBox(
                          height: 25,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: streamer.tags.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 4),
                            itemBuilder: (context, idx) {
                              final tag = streamer.tags[idx];
                              return Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkSurface1,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: AppTheme.darkBorderSubtle,
                                      width: 0.8),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: AppTheme.accentBlue,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // 📍 Bottom Venue & Location Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface1,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXs),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 10,
                              color: AppTheme.accentRed,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '${streamer.getLocalizedCity(langCode)} • ${streamer.getLocalizedVenue(langCode)}',
                                style: const TextStyle(
                                  color: AppTheme.textMutedDark,
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
    );
  }
}
