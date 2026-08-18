import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
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
    final isLive = streamer.isCurrentlyLive;
    final isAudio = streamer.isAudioLive;
    final isVideo = streamer.isVideoLive;

    Color borderColor;
    if (isVideo) {
      borderColor = AppTheme.accentRed.withValues(alpha: 0.8);
    } else if (isAudio) {
      borderColor = const Color(0xFFA1A1AA);
    } else {
      borderColor = AppTheme.darkBorderSubtle;
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
              width: isLive ? 1.5 : 1.0,
            ),
            boxShadow: [
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
              // 🖼️ Top Banner: Flexible 38% height (BoxFit.cover cut-to-fit, NO morphing)
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
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXs),
                            border: isAudio
                                ? Border.all(color: const Color(0xFFA1A1AA), width: 0.8)
                                : null,
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAudio) ...[
                                const Icon(
                                  Icons.mic_rounded,
                                  size: 10,
                                  color: Color(0xFFE4E4E7),
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  'feed.audio_live_badge'.tr(),
                                  style: const TextStyle(
                                    color: Color(0xFFE4E4E7),
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'feed.live_badge'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
