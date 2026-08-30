import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/models/streamer_models.dart';
import '../../models/map_models.dart';
import 'venue_navigation_sheet.dart';

class StreamerSlidingDrawer extends StatelessWidget {
  final List<StreamerModel> streamers;
  final ValueChanged<StreamerModel> onStreamerSelected;

  const StreamerSlidingDrawer({
    super.key,
    required this.streamers,
    required this.onStreamerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final liveStreamers = streamers.where((s) => s.isCurrentlyLive).toList();
    final offlineStreamers =
        streamers.where((s) => !s.isCurrentlyLive).toList();

    return Drawer(
      width: 320,
      backgroundColor: AppTheme.darkSurface1,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: const BoxDecoration(
                color: AppTheme.darkSurface2,
                border: Border(
                  bottom:
                      BorderSide(color: AppTheme.darkBorderSubtle, width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.podcasts_rounded,
                      color: AppTheme.accentRed, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'map.drawer_title'.tr(),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          '${streamers.length} ${'map.scholars_available'.tr()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textMutedDark),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Broadcasters List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                children: [
                  if (liveStreamers.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg,
                        vertical: AppTheme.spaceSm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.accentRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${'map.live_now_count'.tr()} (${liveStreamers.length})',
                            style: const TextStyle(
                              color: AppTheme.accentRed,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...liveStreamers.map((streamer) =>
                        _buildStreamerTile(context, streamer, langCode)),
                    const Divider(color: AppTheme.darkBorderSubtle, height: 24),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg,
                      vertical: AppTheme.spaceSm,
                    ),
                    child: Text(
                      '${'map.offline_upcoming_count'.tr()} (${offlineStreamers.length})',
                      style: const TextStyle(
                        color: AppTheme.textMutedDark,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...offlineStreamers.map((streamer) =>
                      _buildStreamerTile(context, streamer, langCode)),
                ],
              ),
            ),
            const Divider(color: AppTheme.darkBorderSubtle, height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: AppTheme.accentBlue),
              title: Text('nav.settings'.tr(),
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark, fontSize: 14)),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamerTile(
      BuildContext context, StreamerModel streamer, String langCode) {
    final isAudio = streamer.isAudioLive;
    final isVideo = streamer.isVideoLive;

    Color statusColor;
    if (isVideo) {
      statusColor = AppTheme.accentRed;
    } else if (isAudio) {
      statusColor = const Color(0xFFA1A1AA);
    } else {
      statusColor = AppTheme.textMutedDark;
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onStreamerSelected(streamer);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLg,
          vertical: AppTheme.spaceMd,
        ),
        child: Row(
          children: [
            // Avatar with status ring
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.darkSurface2,
                  backgroundImage: streamer.avatarUrl.startsWith('assets/')
                      ? AssetImage(streamer.avatarUrl) as ImageProvider
                      : NetworkImage(streamer.avatarUrl),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding:
                        isAudio ? const EdgeInsets.all(1.5) : EdgeInsets.zero,
                    width: isAudio ? 14 : 10,
                    height: isAudio ? 14 : 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppTheme.darkSurface1, width: 1.5),
                    ),
                    child: isAudio
                        ? const Icon(Icons.mic_rounded,
                            size: 8, color: Colors.white)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppTheme.spaceMd),

            // Name and Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          streamer.getLocalizedName(langCode),
                          style: const TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (streamer.isVerified)
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppTheme.accentPurple,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streamer.getLocalizedVenue(langCode),
                    style: const TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streamer.getLocalizedOrganization(langCode),
                    style: const TextStyle(
                      color: AppTheme.textMutedDark,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),

            // Focus Location & In-Person Navigation Triggers
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.navigation_rounded,
                    size: 18,
                    color: AppTheme.accentBlue,
                  ),
                  tooltip: 'venue.visit_venue'.tr(),
                  onPressed: () {
                    Navigator.of(context).pop();
                    VenueNavigationSheet.show(context, streamer: streamer);
                  },
                ),
                // Task 9 -- one-click external Google Maps launch, distinct
                // from the button above which opens the in-app
                // VenueNavigationSheet with full auditorium/distance details.
                IconButton(
                  icon: const Icon(
                    Icons.directions_outlined,
                    size: 18,
                    color: AppTheme.accentBlue,
                  ),
                  tooltip: 'venue.open_maps'.tr(),
                  onPressed: () => _openInGoogleMaps(streamer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Task 9 -- opens the streamer's venue coordinates directly in Google
  /// Maps (native app if installed, browser fallback otherwise). Silently
  /// no-ops if no maps handler exists on the device.
  static Future<void> _openInGoogleMaps(StreamerModel streamer) async {
    final url = Uri.parse(
        buildGoogleMapsSearchUrl(streamer.latitude, streamer.longitude));
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
