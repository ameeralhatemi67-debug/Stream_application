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
      borderColor = AppTheme.onMedia;
      borderWidth = 1.8;
    } else if (isVideo) {
      borderColor = AppTheme.danger.withValues(alpha: 0.8);
      borderWidth = 1.5;
    } else if (isAudio) {
      borderColor = AppTheme.textMuted;
      borderWidth = 1.5;
    } else {
      borderColor = AppTheme.border;
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
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: [
              if (isOwnCard)
                BoxShadow(
                  color: AppTheme.onMedia.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              else
                BoxShadow(
                  color: isVideo
                      ? AppTheme.danger.withValues(alpha: 0.18)
                      : isAudio
                          ? AppTheme.textMuted.withValues(alpha: 0.15)
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
              //  Top Banner: Flexible 45% height (BoxFit.cover cut-to-fit, NO morphing)
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
                        color: AppTheme.surface,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppTheme.textMuted),
                      ),
                    ),
                    // Subtle bottom gradient
                    Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.media,
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
                            color: isVideo ? AppTheme.danger : AppTheme.media,
                            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                            border: Border.all(
                              color: isVideo
                                  ? AppTheme.danger.withValues(alpha: 0.6)
                                  : AppTheme.border,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
                                size: 10,
                                color: AppTheme.onMedia,
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                isVideo
                                    ? 'feed.badge_live'.tr()
                                    : 'live.audio_live_indicator'.tr(),
                                style: const TextStyle(
                                  color: AppTheme.onMedia,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    //  "Your Channel / قناتك"Badge at top right
                    if (isOwnCard)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.media.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                            border: Border.all(color: AppTheme.onMedia, width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppTheme.warning, size: 11),
                              const SizedBox(width: 3),
                              Text(
                                langCode == 'ar' ? 'قناتك' : 'Your Channel',
                                style: const TextStyle(
                                  color: AppTheme.onMedia,
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

              //  Bottom Content: Flexible 62% height with zero overflow risk
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
                                    ? AppTheme.danger
                                    : AppTheme.borderStrong,
                                width: 1.2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.surface,
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
                                          color: AppTheme.textPrimary,
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
                                        color: AppTheme.accent,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  streamer.getLocalizedTitle(langCode),
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
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

                      //  Centered Tag Pills
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
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: AppTheme.border,
                                      width: 0.8),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      //  Bottom Venue & Location Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXs),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 10,
                              color: AppTheme.danger,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '${streamer.getLocalizedCity(langCode)} • ${streamer.getLocalizedVenue(langCode)}',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
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
