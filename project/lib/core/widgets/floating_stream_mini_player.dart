import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// A shortcut back to the broadcast the viewer left, not a player.
///
/// The room's YouTube player is a web view owned by the room screen, so
/// leaving the room stops playback. This used to be a "mini-player" card
/// that showed a stock photo and a mute button with no audio behind it. It
/// now says what is true: playback stopped, and one tap returns to the
/// broadcast. System picture-in-picture is not offered for YouTube streams.
class FloatingStreamMiniPlayer extends StatefulWidget {
  const FloatingStreamMiniPlayer({super.key});

  @override
  State<FloatingStreamMiniPlayer> createState() =>
      _FloatingStreamMiniPlayerState();
}

class _FloatingStreamMiniPlayerState extends State<FloatingStreamMiniPlayer> {
  Offset _position = const Offset(16, 120);

  static const double _edgeInset = 12.0;
  static const double _topInset = 60.0;
  static const double _bottomInset = 90.0;

  Offset _clampToScreen(
      Offset position, Size screen, double width, double height) {
    final maxDx = screen.width - width - _edgeInset;
    final maxDy = screen.height - height - _bottomInset;
    return Offset(
      maxDx <= _edgeInset ? _edgeInset : position.dx.clamp(_edgeInset, maxDx),
      maxDy <= _topInset ? _topInset : position.dy.clamp(_topInset, maxDy),
    );
  }

  void _returnToBroadcast(BuildContext context, AppProvider provider) {
    final streamId = provider.miniPlayerStreamId;
    provider.closeMiniPlayer();
    if (streamId != null && streamId.isNotEmpty) {
      context.push('/live/$streamId');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the whole provider only while the chip is showing; the shell
    // mounts this on every tab and it used to rebuild on every notification.
    final active = context
        .select<AppProvider, bool>((p) => p.isMiniPlayerActive);
    if (!active) return const SizedBox.shrink();
    final provider = context.watch<AppProvider>();

    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 2 * _edgeInset).clamp(160.0, 300.0);
    const height = 64.0;
    final position = _clampToScreen(_position, size, width, height);
    final accentColor =
        provider.isMiniPlayerAudioOnly ? AppTheme.accent : AppTheme.danger;

    return PositionedDirectional(
      start: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) => setState(() {
          // The chip is placed from the start edge, so in right-to-left
          // layouts a drag to the right moves it toward the start.
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final delta =
              rtl ? Offset(-details.delta.dx, details.delta.dy) : details.delta;
          _position = _clampToScreen(position + delta, size, width, height);
        }),
        child: Material(
          key: const ValueKey('mini_player_return_chip'),
          elevation: 12,
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: () => _returnToBroadcast(context, provider),
            child: Container(
              width: width,
              height: height,
              padding: const EdgeInsetsDirectional.only(
                  start: AppTheme.spaceSm, end: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: accentColor.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.open_in_full_rounded,
                      color: accentColor, size: 22),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'live.return_to_broadcast'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          provider.miniPlayerTitle.isEmpty
                              ? 'live.return_chip_paused'.tr()
                              : '${provider.miniPlayerTitle} · '
                                  '${'live.return_chip_paused'.tr()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('mini_player_close_button'),
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppTheme.textSecondary),
                    tooltip: 'live.return_chip_dismiss'.tr(),
                    onPressed: provider.closeMiniPlayer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
