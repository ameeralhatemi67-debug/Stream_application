import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/models/streamer_models.dart';
import '../../models/map_models.dart';

/// Modal Bottom Sheet for In-Person Venue Navigation, Campus Auditorium Info & Distance Estimation
class VenueNavigationSheet extends StatelessWidget {
  final StreamerModel streamer;
  final LatLng userCoordinates;

  const VenueNavigationSheet({
    super.key,
    required this.streamer,
    this.userCoordinates =
        const LatLng(26.2871, 50.2125), // Default: Al Khobar Center
  });

  /// Displays the venue navigation sheet as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    required StreamerModel streamer,
    LatLng? userCoordinates,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => VenueNavigationSheet(
        streamer: streamer,
        userCoordinates: userCoordinates ?? const LatLng(26.2871, 50.2125),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final auditoriumInfo = getAuditoriumInfoForStreamer(streamer);
    final distanceKm = calculateDistanceKm(
      userCoordinates.latitude,
      userCoordinates.longitude,
      streamer.latitude,
      streamer.longitude,
    );
    final formattedDistance = formatDistanceKm(distanceKm, langCode);
    final travelTimeStr = estimateTravelTime(distanceKm, langCode);
    final mapUrl = generateExternalMapUrl(
      streamer.latitude,
      streamer.longitude,
      streamer.getLocalizedVenue(langCode),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLg,
        AppTheme.spaceMd,
        AppTheme.spaceLg,
        AppTheme.spaceXl,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface3,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppTheme.darkBorderHighlight, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle Pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkBorderHighlight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),

            // Sheet Header Title Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: AppTheme.accentBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'venue.title'.tr(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        streamer.getLocalizedCity(langCode),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.accentBlue,
                            ),
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
            const SizedBox(height: AppTheme.spaceLg),

            // Broadcaster Identity Header Card
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface1,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.darkBorderSubtle),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.darkSurface2,
                    backgroundImage: NetworkImage(streamer.avatarUrl),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                        Text(
                          streamer.getLocalizedOrganization(langCode),
                          style: const TextStyle(
                            color: AppTheme.textMutedDark,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),

            // Venue Address & Location Details
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.darkBorderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 16, color: AppTheme.accentRed),
                      const SizedBox(width: 8),
                      Text(
                        'venue.address_label'.tr(),
                        style: const TextStyle(
                          color: AppTheme.textMutedDark,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    streamer.getLocalizedVenue(langCode),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auditoriumInfo.getLocalizedAddress(langCode),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),

            // University Auditorium & Campus Info
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.darkBorderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_rounded,
                          size: 16, color: AppTheme.accentPurple),
                      const SizedBox(width: 8),
                      Text(
                        'venue.auditorium_label'.tr(),
                        style: const TextStyle(
                          color: AppTheme.textMutedDark,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXs),
                        ),
                        child: Text(
                          '${auditoriumInfo.seatingCapacity} Seats',
                          style: const TextStyle(
                            color: AppTheme.accentPurple,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    auditoriumInfo.getLocalizedAuditorium(langCode),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.meeting_room_outlined,
                          size: 14, color: AppTheme.textMutedDark),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          auditoriumInfo.getLocalizedGate(langCode),
                          style: const TextStyle(
                            color: AppTheme.textMutedDark,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),

            // Distance Estimation Card
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                    color: AppTheme.accentBlue.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: AppTheme.accentBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'venue.distance_label'.tr(),
                          style: const TextStyle(
                            color: AppTheme.accentBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              formattedDistance,
                              style: const TextStyle(
                                color: AppTheme.textPrimaryDark,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '($travelTimeStr)',
                              style: const TextStyle(
                                color: AppTheme.textSecondaryDark,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),

            // External Map Deep Link Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _openInGoogleMaps(context, streamer, mapUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: AppTheme.darkBgBase,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                icon: const Icon(Icons.map_rounded, size: 20),
                label: Text(
                  'venue.open_maps'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Task 9 -- one-click Google Maps launch. Replaces the previous
  /// clipboard-copy-only flow: a signed coordinate query
  /// (`?api=1&query=lat,lng`) opens directly in the Google Maps app (or its
  /// web fallback) via [LaunchMode.externalApplication], with the clipboard
  /// copy kept only as a last resort for a device with no maps handler at
  /// all.
  static Future<void> _openInGoogleMaps(
    BuildContext context,
    StreamerModel streamer,
    String fallbackMapUrl,
  ) async {
    final googleMapsUrl = Uri.parse(
        buildGoogleMapsSearchUrl(streamer.latitude, streamer.longitude));

    Navigator.of(context).pop();

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('[VenueNavigationSheet] Error launching Google Maps: $e');
    }

    // No maps handler available on this device -- fall back to the old
    // clipboard behavior rather than leaving the tap silently do nothing.
    await Clipboard.setData(ClipboardData(text: fallbackMapUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.darkSurface3,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.open_in_new_rounded, color: AppTheme.accentBlue),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'venue.navigating_toast'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    fallbackMapUrl,
                    style: const TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
