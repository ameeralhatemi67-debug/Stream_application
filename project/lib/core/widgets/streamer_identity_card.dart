import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'safe_image_provider.dart';
import 'streamer_avatar.dart';

/// Shared identity layout; each screen supplies only its own details/actions.
class StreamerIdentityCard extends StatelessWidget {
  const StreamerIdentityCard({
    super.key,
    required this.name,
    required this.title,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.isVerified,
    required this.status,
    this.child,
    this.onTap,
    this.onClose,
  });

  final String name, title, avatarUrl, bannerUrl;
  final bool isVerified;
  final Widget status;
  final Widget? child;
  final VoidCallback? onTap, onClose;

  @override
  Widget build(BuildContext context) {
    final image = resolveImageProviderOrNull(bannerUrl);
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              side: const BorderSide(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: LayoutBuilder(builder: (context, constraints) {
                final bannerHeight =
                    (constraints.maxWidth * .28).clamp(80.0, 112.0);
                const avatarSize = 64.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          height: bannerHeight + avatarSize / 2,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              height: bannerHeight,
                              width: double.infinity,
                              child: ColoredBox(
                                color: AppTheme.surfaceAlt,
                                child: image == null
                                    ? null
                                    : Image(
                                        image: image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          top: AppTheme.spaceSm,
                          end: AppTheme.spaceSm,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth - 80),
                            child: status,
                          ),
                        ),
                        if (onClose != null)
                          PositionedDirectional(
                            top: 0,
                            start: 0,
                            child: IconButton.filledTonal(
                              tooltip: 'common.close'.tr(),
                              onPressed: onClose,
                              icon: const Icon(Icons.close_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.surface,
                                foregroundColor: AppTheme.textSecondary,
                                minimumSize: const Size(48, 48),
                              ),
                            ),
                          ),
                        PositionedDirectional(
                          start: AppTheme.spaceMd,
                          top: bannerHeight - avatarSize / 2,
                          child: Stack(
                            children: [
                              StreamerAvatar(
                                avatarUrl: avatarUrl,
                                name: name,
                                radius: avatarSize / 2 - 2,
                                borderColor: AppTheme.surface,
                                borderWidth: 2,
                              ),
                              if (isVerified)
                                const PositionedDirectional(
                                  top: 0,
                                  end: 0,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        color: AppTheme.surface,
                                        shape: BoxShape.circle),
                                    child: Icon(Icons.verified_rounded,
                                        color: AppTheme.primary, size: 20),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            top: bannerHeight + AppTheme.spaceSm,
                            start: AppTheme.spaceMd +
                                avatarSize +
                                AppTheme.spaceSm,
                            end: AppTheme.spaceMd,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary)),
                              if (title.trim().isNotEmpty) ...[
                                const SizedBox(height: AppTheme.spaceXs),
                                Text(title,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceMd),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class StreamerCardStatus extends StatelessWidget {
  const StreamerCardStatus(
      {super.key, this.isLive = false, this.isAudio = false, this.label});
  final bool isLive, isAudio;
  final String? label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(
          label ??
              (isLive
                      ? (isAudio
                          ? 'live.audio_live_indicator'
                          : 'map.live_badge')
                      : 'map.offline_badge')
                  .tr(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isLive ? AppTheme.danger : AppTheme.textMuted),
        ),
      );
}
