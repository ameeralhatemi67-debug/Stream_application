import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/map_models.dart';

/// Compact Discovery-Feed Styled Channel Card Map Marker
/// Renders a high-performance mini Channel Card on the spatial map
/// matching the Discovery Feed card design system (avatar, scholar name, live badge, category, viewer count).
class MapDiscoveryChannelCardMarker extends StatelessWidget {
  final MapMarkerModel marker;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const MapDiscoveryChannelCardMarker({
    super.key,
    required this.marker,
    required this.isSelected,
    this.isCompact = false,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final isLive = marker.isLive;

    if (isCompact) {
      return RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surface,
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : isLive
                        ? AppTheme.danger
                        : AppTheme.border,
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.4)
                      : (isLive
                          ? AppTheme.danger.withValues(alpha: 0.3)
                          : Colors.black45),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipOval(
                  child: marker.avatarUrl.startsWith('assets/')
                      ? Image.asset(
                          marker.avatarUrl,
                          fit: BoxFit.cover,
                          width: 44,
                          height: 44,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppTheme.surfaceAlt,
                            child: const Icon(Icons.person_rounded,
                                size: 18, color: AppTheme.textMuted),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: marker.avatarUrl,
                          fit: BoxFit.cover,
                          width: 44,
                          height: 44,
                          placeholder: (context, url) => Container(
                            color: AppTheme.surfaceAlt,
                            child: const Icon(Icons.person_rounded,
                                size: 18, color: AppTheme.textMuted),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppTheme.surfaceAlt,
                            child: const Icon(Icons.person_rounded,
                                size: 18, color: AppTheme.textMuted),
                          ),
                        ),
                ),
                if (isLive)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.danger,
                        border: Border.all(
                            color: AppTheme.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.surfaceAlt
                : AppTheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : isLive
                      ? AppTheme.danger.withValues(alpha: 0.8)
                      : AppTheme.border,
              width: isSelected ? 2.0 : (isLive ? 1.5 : 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.3)
                    : (isLive
                        ? AppTheme.danger.withValues(alpha: 0.2)
                        : Colors.black38),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row: Scholar Avatar + Name & Live/Offline Badge
              Row(
                children: [
                  // Scholar Avatar with CachedNetworkImage
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isLive ? AppTheme.danger : AppTheme.border,
                        width: 1.2,
                      ),
                    ),
                    child: ClipOval(
                      child: marker.avatarUrl.startsWith('assets/')
                          ? Image.asset(
                              marker.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppTheme.surfaceAlt,
                                child: const Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: marker.avatarUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppTheme.surfaceAlt,
                                child: const Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppTheme.surfaceAlt,
                                child: const Icon(
                                  Icons.person_rounded,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Name & Live Badge Stack
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          marker.getLocalizedName(langCode),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLive ? AppTheme.danger : AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isLive
                                  ? 'map.live_badge'.tr()
                                  : 'map.offline_badge'.tr(),
                              style: TextStyle(
                                color: isLive ? AppTheme.danger : AppTheme.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isLive) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${marker.viewerCount}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Bottom Row: Category Tag & Venue Location Name Pill
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 0.5),
                    ),
                    child: Text(
                      'feed.${marker.categoryId == 'cs_tech' ? 'cat_cs' : marker.categoryId == 'islamic_studies' ? 'cat_islamic' : marker.categoryId == 'engineering' ? 'cat_eng' : 'cat_all'}'.tr(),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        marker.getLocalizedVenue(langCode),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
