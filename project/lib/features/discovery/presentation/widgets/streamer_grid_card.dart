import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/widgets/streamer_identity_card.dart';
import '../../../profile/models/streamer_models.dart';

class StreamerGridCard extends StatelessWidget {
  final StreamerModel streamer;
  final String langCode;

  const StreamerGridCard(
      {super.key, required this.streamer, required this.langCode});

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
    void openChannel() => context.push(isLive ? '/live/${streamer.liveSessionId ?? streamer.streamerId}' : '/profile/${streamer.channelProfileId}');

    return StreamerIdentityCard(
      name: streamer.getLocalizedName(langCode),
      title: streamer.getLocalizedTitle(langCode),
      avatarUrl: streamer.avatarUrl,
      bannerUrl: streamer.bannerUrl,
      isVerified: streamer.isVerified,
      status: Wrap(
        spacing: AppTheme.spaceXs,
        runSpacing: AppTheme.spaceXs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StreamerCardStatus(
            isLive: isLive,
            isAudio: streamer.isAudioLive,
            label: uncertain
                ? (cached
                        ? 'offline_experience.cached_card'
                        : 'offline_experience.status_unavailable')
                    .tr()
                : null,
          ),
          if (isOwnCard)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text('feed.your_channel_badge'.tr(),
                  style:
                      const TextStyle(color: AppTheme.primary, fontSize: 11)),
            ),
        ],
      ),
      onTap: openChannel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceXs,
            children: streamer.tags
                .where((tag) => tag.trim().isNotEmpty)
                .toSet()
                .map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSm,
                          vertical: AppTheme.spaceXs),
                      decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm)),
                      child: Text(tag,
                          style: const TextStyle(
                              color: AppTheme.primary, fontSize: 12)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
