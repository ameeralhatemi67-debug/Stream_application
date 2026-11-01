import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../venue_directions_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/streamer_identity_card.dart';
import '../../../profile/models/streamer_models.dart';

class MarkerSummaryCard extends StatelessWidget {
  final StreamerModel streamer;
  final VoidCallback onClose;

  /// When this channel next goes live, if it has announced it.
  final String? nextLive;

  const MarkerSummaryCard(
      {super.key,
      required this.streamer,
      required this.onClose,
      this.nextLive});

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return StreamerIdentityCard(
      name: streamer.getLocalizedName(lang),
      title: streamer.getLocalizedTitle(lang),
      avatarUrl: streamer.avatarUrl,
      bannerUrl: streamer.bannerUrl,
      isVerified: streamer.isVerified,
      status: StreamerCardStatus(
          isLive: streamer.isCurrentlyLive, isAudio: streamer.isAudioLive),
      onClose: onClose,
      onTap: () => context.push(streamer.isCurrentlyLive ? '/live/${streamer.liveSessionId ?? streamer.streamerId}' : '/profile/${streamer.channelProfileId}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        button: true,
        label: 'venue.open_maps'.tr(),
        child: Material(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: InkWell(
            key: const ValueKey('map-card-venue'),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            onTap: () => openVenueDirections(
                context, streamer.latitude, streamer.longitude,
                googleOnly: true),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(streamer.getLocalizedVenue(lang),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      if (streamer.getLocalizedCity(lang).trim().isNotEmpty)
                        Text(streamer.getLocalizedCity(lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  )),
                  const SizedBox(width: AppTheme.spaceSm),
                  const Icon(Icons.directions_rounded,
                      color: AppTheme.primary, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      if (nextLive != null)
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.spaceSm),
          child: Text(nextLive!,
              key: const ValueKey('map-card-next-live'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
        ),
      ]),
    );
  }
}
