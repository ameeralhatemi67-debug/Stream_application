import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/streamer_avatar.dart';
import '../../../profile/models/streamer_models.dart';
import '../../models/map_models.dart';
import 'venue_navigation_sheet.dart';

class MarkerSummaryCard extends StatelessWidget {
  final StreamerModel streamer;
  final VoidCallback onClose;

  const MarkerSummaryCard({
    super.key,
    required this.streamer,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final isLive = streamer.isCurrentlyLive;
    final isAudio = streamer.isAudioLive;
    final isVideo = streamer.isVideoLive;

    Color borderColor;
    if (isVideo) {
      borderColor = AppTheme.danger.withValues(alpha: 0.8);
    } else if (isAudio) {
      borderColor = AppTheme.textMuted;
    } else {
      borderColor = AppTheme.borderStrong;
    }

    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Name, Verified Badge, Close Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StreamerAvatar(radius: 20, avatarUrl: streamer.avatarUrl),
              const SizedBox(width: 10),
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
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: AppTheme.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streamer.getLocalizedTitle(langCode),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppTheme.textMuted),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Venue Tag & Navigation Action
          InkWell(
            onTap: () => VenueNavigationSheet.show(context, streamer: streamer),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppTheme.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      streamer.getLocalizedVenue(langCode),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.navigation_rounded,
                      size: 13, color: AppTheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Row 3: Live Status Badge + In-Person Direction + Watch / Profile Button
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isVideo
                      ? AppTheme.danger.withValues(alpha: 0.2)
                      : isAudio
                          ? AppTheme.media
                          : AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  border: Border.all(
                    color: isVideo
                        ? AppTheme.danger
                        : isAudio
                            ? AppTheme.textMuted
                            : AppTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAudio) ...[
                      const Icon(
                        Icons.mic_rounded,
                        size: 12,
                        color: AppTheme.onMedia,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'live.audio_live_indicator'.tr(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onMedia,
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isVideo
                              ? AppTheme.danger
                              : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isVideo
                            ? 'map.live_badge'.tr()
                            : 'map.offline_badge'.tr(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isVideo
                              ? AppTheme.danger
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              // Task 9 -- one-click external Google Maps launch, distinct
              // from the "Visit Venue"button below which opens the in-app
              // VenueNavigationSheet with full auditorium/distance details.
              IconButton(
                icon: const Icon(Icons.directions_rounded,
                    color: AppTheme.primary, size: 20),
                tooltip: 'venue.open_maps'.tr(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _openInGoogleMaps(streamer),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded,
                    color: AppTheme.primary, size: 20),
                tooltip: 'venue.visit_venue'.tr(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () =>
                    VenueNavigationSheet.show(context, streamer: streamer),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () {
                  if (isLive && streamer.activeStreamId != null) {
                    context.push('/live/${streamer.activeStreamId}');
                  } else {
                    context.push('/profile/${streamer.streamerId}');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isVideo
                      ? AppTheme.danger
                      : isAudio
                          ? AppTheme.media
                          : AppTheme.primary,
                  foregroundColor: AppTheme.onMedia,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: isAudio
                        ? const BorderSide(color: AppTheme.textMuted, width: 1.0)
                        : BorderSide.none,
                  ),
                  elevation: 0,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  isVideo
                      ? Icons.play_arrow_rounded
                      : isAudio
                          ? Icons.mic_rounded
                          : Icons.person_rounded,
                  size: 14,
                ),
                label: Text(
                  isVideo
                      ? 'live.watch_live'.tr()
                      : isAudio
                          ? 'live.listen_live'.tr()
                          : 'nav.profile'.tr(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Task 9 -- opens the streamer's venue coordinates directly in Google
  /// Maps (native app if installed, browser fallback otherwise). Silently
  /// no-ops if no maps handler exists on the device, same as the plan's
  /// other two launch sites -- this is a convenience shortcut, not the only
  /// way to navigate (VenueNavigationSheet's own button remains the
  /// full-featured path with a clipboard fallback).
  static Future<void> _openInGoogleMaps(StreamerModel streamer) async {
    final url = Uri.parse(
        buildGoogleMapsSearchUrl(streamer.latitude, streamer.longitude));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
