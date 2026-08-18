import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/streamer_models.dart';
import '../../models/vod_models.dart';
import 'vod_player_modal_sheet.dart';

/// 2-Column VOD grid item tile for displaying past lecture recordings in Profile screen.
class VodGridTile extends StatelessWidget {
  final VodModel vod;
  final StreamerModel? streamer;

  const VodGridTile({
    super.key,
    required this.vod,
    this.streamer,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final title = vod.getLocalizedTitle(lang);

    return InkWell(
      onTap: () => VodPlayerModalSheet.show(
        context,
        vod: vod,
        streamer: streamer,
      ),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.darkBorderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail container with play overlay and duration pill
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image thumbnail background
                  vod.thumbnailUrl.startsWith('assets/')
                      ? Image.asset(
                          vod.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppTheme.darkSurface2,
                            child: const Center(
                              child: Icon(Icons.video_library_rounded,
                                  size: 32, color: AppTheme.accentPurple),
                            ),
                          ),
                        )
                      : Image.network(
                          vod.thumbnailUrl.startsWith('http')
                              ? vod.thumbnailUrl
                              : 'https://img.youtube.com/vi/${vod.youtubeVideoId}/hqdefault.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppTheme.darkSurface2,
                            child: const Center(
                              child: Icon(Icons.video_library_rounded,
                                  size: 32, color: AppTheme.accentPurple),
                            ),
                          ),
                        ),

                  // Dark gradient overlay for contrast
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),

                  // Center Play Action Icon Button
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentRed.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),

                  // Duration Pill Overlay on Bottom Right
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Text(
                        vod.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Localized VOD Details Text Container (Bottom padding is 10px)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 11,
                          color: AppTheme.textMutedDark,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${vod.recordedDate} • ${vod.viewCount} views',
                            style: const TextStyle(
                              color: AppTheme.textMutedDark,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
