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
                  p.isOwnStreamerProfile(streamer.streamerId),
            ));
    final uncertain = cached || networkStatus != NetworkStatus.online;
    final isLive = !uncertain && streamer.isCurrentlyLive;
    void openChannel() {
      if (isLive && streamer.activeStreamId != null) {
        context.push('/live/${streamer.activeStreamId}');
      } else {
        context.push('/profile/${streamer.streamerId}');
      }
    }

    return StreamerIdentityCard(
      name: streamer.getLocalizedName(langCode),
      title: streamer.getLocalizedTitle(langCode),
      avatarUrl: streamer.avatarUrl,
      bannerUrl: streamer.bannerUrl,
      isVerified: streamer.isVerified,
      status: StreamerCardStatus(
        isLive: isLive,
        isAudio: streamer.isAudioLive,
        label: uncertain
            ? (cached
                    ? 'offline_experience.cached_card'
                    : 'offline_experience.status_unavailable')
                .tr()
            : null,
      ),
      onTap: openChannel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isOwnCard) ...[
            Text('feed.your_channel_badge'.tr(),
                style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
            const SizedBox(height: AppTheme.spaceSm),
          ],
          ElevatedButton.icon(
            onPressed: openChannel,
            icon: Icon(
                isLive
                    ? (streamer.isAudioLive
                        ? Icons.mic_rounded
                        : Icons.play_arrow_rounded)
                    : Icons.person_outline_rounded,
                size: 18),
            label: Text((isLive
                    ? (streamer.isAudioLive
                        ? 'live.listen_live'
                        : 'live.watch_live')
                    : 'profile.view_channel')
                .tr()),
            style: ElevatedButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ],
      ),
    );
  }
}
