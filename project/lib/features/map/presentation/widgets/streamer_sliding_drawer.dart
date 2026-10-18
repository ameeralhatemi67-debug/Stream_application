import '../../../../core/widgets/ds/ca_cards.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../venue_directions_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/models/streamer_models.dart';
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
      backgroundColor: paletteColor(context, AppTheme.surface),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: paletteColor(context, AppTheme.surfaceAlt),
                border: Border(
                  bottom: BorderSide(color: paletteColor(context, AppTheme.border), width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.podcasts_rounded,
                      color: paletteColor(context, AppTheme.danger), size: 22),
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
                    icon: Icon(Icons.close_rounded,
                        color: paletteColor(context, AppTheme.textMuted)),
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
                            decoration: BoxDecoration(
                              color: paletteColor(context, AppTheme.danger),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${'map.live_now_count'.tr()} (${liveStreamers.length})',
                            style: TextStyle(
                              color: paletteColor(context, AppTheme.danger),
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
                    Divider(color: paletteColor(context, AppTheme.border), height: 24),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg,
                      vertical: AppTheme.spaceSm,
                    ),
                    child: Text(
                      '${'map.offline_upcoming_count'.tr()} (${offlineStreamers.length})',
                      style: TextStyle(
                        color: paletteColor(context, AppTheme.textMuted),
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
            Divider(color: paletteColor(context, AppTheme.border), height: 1),
            ListTile(
              leading:
                  Icon(Icons.settings_outlined, color: paletteColor(context, AppTheme.primary)),
              title: Text('nav.settings'.tr(),
                  style: TextStyle(
                      color: paletteColor(context, AppTheme.textPrimary), fontSize: 14)),
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
      statusColor = paletteColor(context, AppTheme.danger);
    } else if (isAudio) {
      statusColor = paletteColor(context, AppTheme.textMuted);
    } else {
      statusColor = paletteColor(context, AppTheme.textMuted);
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
                CaAvatar(
                  name: streamer.getLocalizedName(Localizations.localeOf(context).languageCode),
                  url: streamer.avatarUrl,
                  radius: 22,
                  org: streamer.isOrganization,
                ),
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: Container(
                    padding:
                        isAudio ? const EdgeInsets.all(1.5) : EdgeInsets.zero,
                    width: isAudio ? 14 : 10,
                    height: isAudio ? 14 : 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: paletteColor(context, AppTheme.surface), width: 1.5),
                    ),
                    child: isAudio
                        ? Icon(Icons.mic_rounded,
                            size: 8, color: paletteColor(context, AppTheme.onMedia))
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
                          style: TextStyle(
                            color: paletteColor(context, AppTheme.textPrimary),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (streamer.isVerified)
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: paletteColor(context, AppTheme.accent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streamer.getLocalizedVenue(langCode),
                    style: TextStyle(
                      color: paletteColor(context, AppTheme.primary),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streamer.getLocalizedOrganization(langCode),
                    style: TextStyle(
                      color: paletteColor(context, AppTheme.textMuted),
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
                  icon: Icon(
                    Icons.navigation_rounded,
                    size: 18,
                    color: paletteColor(context, AppTheme.primary),
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
                  icon: Icon(
                    Icons.directions_outlined,
                    size: 18,
                    color: paletteColor(context, AppTheme.primary),
                  ),
                  tooltip: 'venue.open_maps'.tr(),
                  onPressed: () => _openInGoogleMaps(context, streamer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Task 9 -- opens the streamer's venue coordinates directly in Google
  /// Maps (native app if installed, browser fallback otherwise), with a
  /// localized message if no maps handler can take it.
  static Future<void> _openInGoogleMaps(
      BuildContext context, StreamerModel streamer) async {
    await openVenueDirections(context, streamer.latitude, streamer.longitude);
  }
}
