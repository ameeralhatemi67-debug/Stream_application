import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/canopy_motion.dart';
import '../../../profile/models/streamer_models.dart';

class StreamerGridCard extends StatelessWidget {
  final StreamerModel streamer;
  final String langCode;

  const StreamerGridCard(
      {super.key, required this.streamer, required this.langCode});

  static const _bannerHeight = 128.0;

  @override
  Widget build(BuildContext context) {
    final (networkStatus, cached, isOwnCard) =
        context.select<AppProvider, (NetworkStatus, bool, bool)>((p) => (
              p.networkStatus,
              p.isUsingCachedCatalog,
              (p.isLoggedInStreamer || p.isStreamerModeEnabled) &&
                  p.isOwnStreamerProfile(streamer.channelProfileId),
            ));
    final uncertain = cached || networkStatus != NetworkStatus.online;
    final isLive = !uncertain && streamer.isCurrentlyLive;
    void openChannel() => context.push(
        isLive
            ? '/live/${streamer.liveSessionId ?? streamer.streamerId}'
            : '/profile/${streamer.channelProfileId}',
        extra: canopyOrigin(context));

    final tags = streamer.tags
        .where((t) => t.trim().isNotEmpty)
        .toSet()
        .take(2)
        .toList();
    return CanopyPress(
        child: CaScholarCard(
            name: streamer.getLocalizedName(langCode),
            subtitle: streamer.getLocalizedTitle(langCode),
            avatarUrl: streamer.avatarUrl,
            bannerUrl: streamer.bannerUrl,
            verified: streamer.isVerified,
            org: streamer.isOrganization,
            live: isLive,
            // Owner choices: a taller banner, a larger avatar, and the status
            // badges on the banner's top end corner instead of in the body.
            bannerHeight: _bannerHeight,
            largeAvatar: true,
            statusKind: isLive
                ? (streamer.isAudioLive
                    ? CaStatusKind.audio
                    : CaStatusKind.live)
                : CaStatusKind.offline,
            statusLabel: uncertain
                ? (cached
                        ? 'offline_experience.cached_card'
                        : 'offline_experience.status_unavailable')
                    .tr()
                : null,
            bannerOverlay: Wrap(
                spacing: AppTheme.spaceXs,
                runSpacing: AppTheme.spaceXs,
                alignment: WrapAlignment.end,
                children: [
                  CaStatusChip(
                      kind: isLive
                          ? (streamer.isAudioLive
                              ? CaStatusKind.audio
                              : CaStatusKind.live)
                          : CaStatusKind.offline,
                      label: uncertain
                          ? (cached
                                  ? 'offline_experience.cached_card'
                                  : 'offline_experience.status_unavailable')
                              .tr()
                          : null),
                  if (isOwnCard)
                    DecoratedBox(
                        decoration: BoxDecoration(
                            color: Canopy.paper,
                            borderRadius:
                                BorderRadius.circular(CanopyRadius.pill)),
                        child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: AppTheme.spaceSm,
                                vertical: AppTheme.spaceXs),
                            child: Text('feed.your_channel_badge'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: Canopy.brandGreen)))),
                ]),
            onTap: openChannel,
            footer: tags.isEmpty
                ? null
                : Wrap(
                    spacing: AppTheme.spaceXs,
                    runSpacing: AppTheme.spaceXs,
                    children: [
                        for (final tag in tags)
                          DecoratedBox(
                              decoration: BoxDecoration(
                                  color: Canopy.mint,
                                  borderRadius:
                                      BorderRadius.circular(CanopyRadius.pill)),
                              child: Padding(
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
                                          horizontal: AppTheme.spaceSm,
                                          vertical: AppTheme.spaceXs),
                                  child: Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(tag,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall)))),
                      ])));
  }
}
