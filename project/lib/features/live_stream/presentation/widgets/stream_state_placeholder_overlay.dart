import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/theme/app_theme.dart';
import '../abstract_video_player.dart';

/// Cluster 1 Task 4a -- the single placeholder surface every non-playing
/// [StreamState] renders through.
///
/// Before this, each adapter grew its own ad-hoc "Connecting to YouTube
/// Feed..." spinner and its own black error card, and
/// `LivePlayerOverlayControls` grew a third one for offline/fallbackError --
/// three visually different answers to the same question. This widget owns
/// all of them, so a new state (or a streamer's own approved artwork, Task
/// 4b) only has to be handled in one place.
///
/// Renders nothing at all for the states where video is actually on screen
/// ([StreamState.live], [StreamState.paused], [StreamState.buffering]), so it
/// is safe to leave permanently mounted in a player Stack.
class StreamStatePlaceholderOverlay extends StatelessWidget {
  final StreamState streamState;

  /// A streamer's own approved card for this state (Task 4b). When null --
  /// nothing uploaded, or uploaded but not yet approved -- the polished
  /// default system placeholder below is used instead.
  final String? customImageUrl;

  /// Technical detail (a WebResourceError description, a video id) shown in
  /// small print under the error copy. Never the primary message.
  final String? errorDetail;

  /// When non-null, a "Retry" button is offered.
  final VoidCallback? onRetry;

  /// When non-null, an "Open in YouTube" escape hatch is offered (Task 5).
  final VoidCallback? onOpenInYouTube;

  const StreamStatePlaceholderOverlay({
    super.key,
    required this.streamState,
    this.customImageUrl,
    this.errorDetail,
    this.onRetry,
    this.onOpenInYouTube,
  });

  /// The states this overlay paints over. Everything else means real video
  /// is (or should be) visible and the overlay stays out of the way.
  static bool coversState(StreamState state) {
    switch (state) {
      case StreamState.live:
      case StreamState.paused:
      case StreamState.buffering:
        return false;
      case StreamState.initializing:
      case StreamState.startingSoon:
      case StreamState.reconnecting:
      case StreamState.ended:
      case StreamState.offline:
      case StreamState.noAudioToken:
      case StreamState.fallbackError:
        return true;
    }
  }

  _PlaceholderSpec get _spec {
    switch (streamState) {
      case StreamState.initializing:
        return const _PlaceholderSpec(
          icon: Icons.settings_input_antenna_rounded,
          accent: AppTheme.accentBlue,
          titleKey: 'live.state_initializing_title',
          subtitleKey: 'live.state_initializing_sub',
          showSpinner: true,
        );
      case StreamState.startingSoon:
        return const _PlaceholderSpec(
          icon: Icons.schedule_rounded,
          accent: AppTheme.accentAmber,
          titleKey: 'live.state_starting_soon_title',
          subtitleKey: 'live.state_starting_soon_sub',
          pulse: true,
        );
      case StreamState.reconnecting:
        return const _PlaceholderSpec(
          icon: Icons.sync_rounded,
          accent: AppTheme.accentAmber,
          titleKey: 'live.state_reconnecting_title',
          subtitleKey: 'live.state_reconnecting_sub',
          showSpinner: true,
        );
      case StreamState.ended:
        return const _PlaceholderSpec(
          icon: Icons.flag_rounded,
          accent: AppTheme.accentGreen,
          titleKey: 'live.state_ended_title',
          subtitleKey: 'live.state_ended_sub',
        );
      case StreamState.offline:
        return const _PlaceholderSpec(
          icon: Icons.satellite_alt_rounded,
          accent: AppTheme.accentRed,
          titleKey: 'live.state_offline_title',
          subtitleKey: 'live.state_offline_sub',
        );
      case StreamState.noAudioToken:
        return const _PlaceholderSpec(
          icon: Icons.volume_off_rounded,
          accent: AppTheme.accentAmber,
          titleKey: 'live.state_no_audio_token_title',
          subtitleKey: 'live.state_no_audio_token_sub',
        );
      case StreamState.fallbackError:
        return const _PlaceholderSpec(
          icon: Icons.error_outline_rounded,
          accent: AppTheme.accentRed,
          titleKey: 'live.state_error_title',
          subtitleKey: 'live.state_error_sub',
        );
      case StreamState.live:
      case StreamState.paused:
      case StreamState.buffering:
        return const _PlaceholderSpec(
          icon: Icons.play_arrow_rounded,
          accent: AppTheme.accentBlue,
          titleKey: 'live.state_initializing_title',
          subtitleKey: 'live.state_initializing_sub',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!coversState(streamState)) return const SizedBox.shrink();

    final spec = _spec;
    final custom = customImageUrl;

    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Container(
          key: ValueKey('placeholder_${streamState.name}'),
          color: Colors.black.withValues(alpha: 0.92),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Streamer's own approved artwork sits behind the copy so the
              // state is still legible over a busy image.
              if (custom != null && custom.isNotEmpty)
                Image.network(
                  custom,
                  fit: BoxFit.cover,
                  // A broken/expired card URL must never replace the state
                  // message with a Flutter error box -- fall through to the
                  // default placeholder ground instead.
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              if (custom != null && custom.isNotEmpty)
                Container(color: Colors.black.withValues(alpha: 0.55)),
              _buildContent(context, spec),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _PlaceholderSpec spec) {
    final detail = errorDetail;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlaceholderGlyph(spec: spec),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              spec.titleKey.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              spec.subtitleKey.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (detail != null && detail.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                detail,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textMutedDark,
                  fontSize: 10.5,
                ),
              ),
            ],
            if (onRetry != null || onOpenInYouTube != null) ...[
              const SizedBox(height: AppTheme.spaceLg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppTheme.spaceSm,
                runSpacing: AppTheme.spaceSm,
                children: [
                  if (onRetry != null)
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text('live.retry_feed'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: spec.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                      ),
                    ),
                  if (onOpenInYouTube != null)
                    ElevatedButton.icon(
                      onPressed: onOpenInYouTube,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text('live.open_in_youtube'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaceholderSpec {
  final IconData icon;
  final Color accent;
  final String titleKey;
  final String subtitleKey;
  final bool showSpinner;
  final bool pulse;

  const _PlaceholderSpec({
    required this.icon,
    required this.accent,
    required this.titleKey,
    required this.subtitleKey,
    this.showSpinner = false,
    this.pulse = false,
  });
}

/// The vector graphic half of a placeholder: a tinted ring around the state
/// icon, optionally wrapped in a progress ring (busy states) or a slow
/// breathing fade (waiting states).
class _PlaceholderGlyph extends StatefulWidget {
  final _PlaceholderSpec spec;

  const _PlaceholderGlyph({required this.spec});

  @override
  State<_PlaceholderGlyph> createState() => _PlaceholderGlyphState();
}

class _PlaceholderGlyphState extends State<_PlaceholderGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.spec.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PlaceholderGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spec.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.spec.pulse && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;

    Widget glyph = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: spec.accent.withValues(alpha: 0.12),
        border: Border.all(color: spec.accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Icon(spec.icon, color: spec.accent, size: 34),
    );

    if (spec.showSpinner) {
      glyph = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(spec.accent),
            ),
          ),
          glyph,
        ],
      );
    }

    if (!spec.pulse) return glyph;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: glyph,
    );
  }
}
