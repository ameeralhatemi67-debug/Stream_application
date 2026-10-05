import 'ds/ca_cards.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'safe_image_provider.dart';

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
    this.headerAction,
    this.maxWidth = 420,
    this.statusTop = AppTheme.spaceSm,
  });

  final String name, title, avatarUrl, bannerUrl;
  final bool isVerified;
  final Widget status;
  final Widget? child, headerAction;
  final VoidCallback? onTap, onClose;
  final double maxWidth, statusTop;

  @override
  Widget build(BuildContext context) {
    final image = resolveImageProviderOrNull(bannerUrl);
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            elevation: onClose == null ? 0 : 4,
            shadowColor: AppTheme.shadow,
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              side: const BorderSide(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 420;
                final bannerHeight = (constraints.maxWidth * .28)
                    .clamp(80.0, wide ? 160.0 : 112.0);
                final avatarSize = wide ? 96.0 : 64.0;
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
                          top: statusTop,
                          end: onClose != null || headerAction != null
                              ? 56
                              : AppTheme.spaceSm,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth - 80),
                            child: status,
                          ),
                        ),
                        if (headerAction != null || onClose != null)
                          PositionedDirectional(
                            top: 0,
                            end: 0,
                            child: headerAction ??
                                IconButton(
                                  tooltip: 'common.close'.tr(),
                                  onPressed: onClose,
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                  padding: const EdgeInsets.all(8),
                                  icon: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.surface
                                          .withValues(alpha: .6),
                                    ),
                                    child: const Icon(Icons.close_rounded,
                                        size: 21.6,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                          ),
                        PositionedDirectional(
                          start: AppTheme.spaceMd,
                          top: bannerHeight - avatarSize / 2,
                          child: Stack(
                            children: [
                              // A white stroke, then the account's identity ring.
                              DecoratedBox(
                                decoration: const BoxDecoration(
                                    color: AppTheme.surface,
                                    shape: BoxShape.circle),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: CaAvatar(
                                    name: name,
                                    url: avatarUrl,
                                    radius: avatarSize / 2 - 6,
                                    ring: CaAvatarRing.brand,
                                  ),
                                ),
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
