import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../organization/models/org_speaker_model.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../profile/models/vod_models.dart';
import '../../../profile/presentation/widgets/org_speaker_inspection_sheet.dart';
import '../abstract_video_player.dart';

/// Interactive Live Audio Stage for single and multi-speaker broadcasts.
/// Proportionally scaled for 16:9 viewports with zero overflow, rock-solid
/// non-jittering animation containers, real-time voice ripples, and animated equalizers.
class LiveAudioStageMultiSpeaker extends StatefulWidget {
  final StreamerModel streamer;
  final String langCode;
  /// Live viewers counted by the server, or null while unknown (P3 /
  /// 05 D-08). Null renders as "—": the app never shows a number it does not
  /// have.
  final int? viewerCount;
  final List<OrgSpeakerModel> speakers;
  final List<VodModel> allVods;
  final String? activeSpeakerId;
  final Function(OrgSpeakerModel)? onSpeakerTap;
  final VoidCallback? onStageTap;
  final VoidCallback? onUnmuteRequested;
  final bool isPlaying;
  final StreamState streamState;

  const LiveAudioStageMultiSpeaker({
    super.key,
    required this.streamer,
    required this.langCode,
    required this.viewerCount,
    this.speakers = const [],
    this.allVods = const [],
    this.activeSpeakerId,
    this.onSpeakerTap,
    this.onStageTap,
    this.onUnmuteRequested,
    this.isPlaying = true,
    this.streamState = StreamState.live,
  });

  @override
  State<LiveAudioStageMultiSpeaker> createState() =>
      _LiveAudioStageMultiSpeakerState();
}

class _LiveAudioStageMultiSpeakerState extends State<LiveAudioStageMultiSpeaker>
    with TickerProviderStateMixin {
  late AnimationController _voiceRippleController;
  late AnimationController _equalizerController;
  late Animation<double> _voiceRippleAnimation;

  String? _currentSpeakingSpeakerId;
  Timer? _speakerRotationTimer;

  bool get _shouldAnimate =>
      widget.isPlaying && widget.streamState == StreamState.live;

  @override
  void initState() {
    super.initState();
    _voiceRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _voiceRippleAnimation = CurvedAnimation(
      parent: _voiceRippleController,
      curve: Curves.easeOutQuad,
    );

    _currentSpeakingSpeakerId = widget.activeSpeakerId;

    _syncAnimationState();
  }

  void _syncAnimationState() {
    if (_shouldAnimate) {
      if (!_voiceRippleController.isAnimating) {
        _voiceRippleController.repeat(reverse: false);
      }
      if (!_equalizerController.isAnimating) {
        _equalizerController.repeat(reverse: true);
      }
      _startRotationTimerIfNeeded();
    } else {
      _voiceRippleController.stop();
      _voiceRippleController.value = 0.0;
      _equalizerController.stop();
      _equalizerController.value = 0.0;
      _speakerRotationTimer?.cancel();
      _speakerRotationTimer = null;
    }
  }

  void _startRotationTimerIfNeeded() {
    if (widget.speakers.length > 1 &&
        widget.activeSpeakerId == null &&
        _speakerRotationTimer == null) {
      _speakerRotationTimer =
          Timer.periodic(const Duration(seconds: 7), (timer) {
        if (!mounted || !_shouldAnimate) return;
        final list = _resolvedSpeakers;
        final currentIdx = list
            .indexWhere((s) => s.speakerId == _currentSpeakingSpeakerId);
        final nextIdx = (currentIdx + 1) % list.length;
        setState(() {
          _currentSpeakingSpeakerId = list[nextIdx].speakerId;
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant LiveAudioStageMultiSpeaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeSpeakerId != oldWidget.activeSpeakerId) {
      _currentSpeakingSpeakerId = widget.activeSpeakerId;
    }
    if (widget.isPlaying != oldWidget.isPlaying ||
        widget.streamState != oldWidget.streamState) {
      _syncAnimationState();
    }
  }

  @override
  void dispose() {
    _speakerRotationTimer?.cancel();
    _voiceRippleController.dispose();
    _equalizerController.dispose();
    super.dispose();
  }

  List<OrgSpeakerModel> get _resolvedSpeakers {
    if (widget.speakers.isNotEmpty) return widget.speakers;
    return [
      OrgSpeakerModel(
        speakerId: widget.streamer.streamerId,
        nameEn: widget.streamer.fullNameEn,
        nameAr: widget.streamer.fullNameAr,
        roleOrTitleEn: widget.streamer.titleEn,
        roleOrTitleAr: widget.streamer.titleAr,
        avatarUrl: widget.streamer.avatarUrl,
        bioEn: widget.streamer.bioEn,
        bioAr: widget.streamer.bioAr,
        isPermanentStaff: true,
      ),
    ];
  }

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }

  void _onSpeakerClicked(OrgSpeakerModel speaker) {
    setState(() {
      _currentSpeakingSpeakerId = speaker.speakerId;
    });

    widget.onStageTap?.call();
    widget.onUnmuteRequested?.call();

    if (widget.onSpeakerTap != null) {
      widget.onSpeakerTap!(speaker);
    } else {
      final speakerVods = widget.allVods
          .where((v) => v.speakerIds.contains(speaker.speakerId))
          .toList();
      OrgSpeakerInspectionSheet.show(
        context,
        speaker: speaker,
        orgName: widget.streamer.getLocalizedName(widget.langCode),
        speakerVods: speakerVods,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final speakers = _resolvedSpeakers;
    final activeId = _currentSpeakingSpeakerId ?? speakers.first.speakerId;
    final activeSpeaker = speakers.firstWhere(
      (s) => s.speakerId == activeId,
      orElse: () => speakers.first,
    );

    return GestureDetector(
      onTap: () {
        widget.onStageTap?.call();
        widget.onUnmuteRequested?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0C0D12),
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 0.85,
            colors: [
              Color(0xFF1B2232),
              Color(0xFF0C0D12),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Glow Behind the Speaker (Static containment)
            Positioned(
              top: 15,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E).withValues(alpha: _shouldAnimate ? 0.08 : 0.02),
                ),
              ),
            ),

            // Top Status Bar: Live Audio Indicator & Reciter Count
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: _shouldAnimate ? AppTheme.accentRed : AppTheme.darkSurface1,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          size: 11,
                          color: _shouldAnimate ? Colors.white : AppTheme.textMutedDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'live.audio_live_badge'.tr(),
                          style: TextStyle(
                            color: _shouldAnimate ? Colors.white : AppTheme.textMutedDark,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (speakers.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                          color: AppTheme.darkBorderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 12, color: AppTheme.accentBlue),
                          const SizedBox(width: 4),
                          Text(
                            '${speakers.length} ${'live.speakers_count'.tr()}',
                            style: const TextStyle(
                              color: AppTheme.textPrimaryDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Main Speakers Roster (Centered, strictly constrained)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: speakers.length == 1
                    ? _buildSingleSpeakerLayout(speakers.first)
                    : _buildMultiSpeakerRoster(speakers, activeId),
              ),
            ),

            // Bottom Live Audio Status Bar with Active Speaking Callout
            Positioned(
              bottom: 8,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14151B),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(
                      color: _shouldAnimate
                          ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                          : AppTheme.darkBorderSubtle,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAnimatedEqualizerBars(isSmall: true),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          activeSpeaker.getLocalizedName(widget.langCode),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _shouldAnimate
                            ? 'live.speaking_now'.tr()
                            : (widget.streamState == StreamState.offline ||
                                    widget.streamState == StreamState.ended
                                ? 'live.state_offline_title'.tr()
                                : 'live.audio_paused'.tr()),
                        style: TextStyle(
                          color: _shouldAnimate
                              ? const Color(0xFF22C55E)
                              : AppTheme.textMutedDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: const BoxDecoration(
                          color: AppTheme.textMutedDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.viewerCount ?? '—'} ${'live.listening_count'.tr()}',
                        style: const TextStyle(
                          color: AppTheme.textSecondaryDark,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSpeakerLayout(OrgSpeakerModel speaker) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _onSpeakerClicked(speaker),
          child: SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Expanding Voice Ripple Ring 1 (Only active when producing audio)
                if (_shouldAnimate)
                  AnimatedBuilder(
                    animation: _voiceRippleAnimation,
                    builder: (context, child) {
                      final d = 72.0 + (_voiceRippleAnimation.value * 24.0);
                      return Container(
                        width: d,
                        height: d,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF22C55E).withValues(
                              alpha: 0.60 * (1.0 - _voiceRippleAnimation.value),
                            ),
                            width: 1.8,
                          ),
                        ),
                      );
                    },
                  ),
                // Expanding Voice Ripple Ring 2 (Offset phase)
                if (_shouldAnimate)
                  AnimatedBuilder(
                    animation: _voiceRippleAnimation,
                    builder: (context, child) {
                      final progress = (_voiceRippleAnimation.value + 0.5) % 1.0;
                      final d = 72.0 + (progress * 24.0);
                      return Container(
                        width: d,
                        height: d,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(
                              alpha: 0.45 * (1.0 - progress),
                            ),
                            width: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
                // Core Glowing Avatar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _shouldAnimate ? const Color(0xFF22C55E) : AppTheme.darkBorderSubtle,
                      width: 2.2,
                    ),
                    boxShadow: _shouldAnimate
                        ? const [
                            BoxShadow(
                              color: Color(0x5522C55E),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppTheme.darkSurface2,
                        backgroundImage: _getImageProvider(speaker.avatarUrl),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _shouldAnimate ? const Color(0xFF22C55E) : AppTheme.darkSurface2,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: Icon(
                          _shouldAnimate ? Icons.mic_rounded : Icons.mic_off_rounded,
                          size: 11,
                          color: _shouldAnimate ? Colors.white : AppTheme.textMutedDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAnimatedEqualizerBars(),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                speaker.getLocalizedName(widget.langCode),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 220,
          child: Text(
            speaker.getLocalizedRole(widget.langCode),
            style: const TextStyle(
              color: AppTheme.accentBlue,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSpeakerRoster(
      List<OrgSpeakerModel> speakers, String activeId) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: speakers.map((speaker) {
          final isSpeaking = speaker.speakerId == activeId;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () => _onSpeakerClicked(speaker),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Active Speaker Expanding Wave Ring
                        if (isSpeaking && _shouldAnimate)
                          AnimatedBuilder(
                            animation: _voiceRippleAnimation,
                            builder: (context, child) {
                              final d = 56.0 + (_voiceRippleAnimation.value * 16.0);
                              return Container(
                                width: d,
                                height: d,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF22C55E).withValues(
                                      alpha: 0.65 *
                                          (1.0 - _voiceRippleAnimation.value),
                                    ),
                                    width: 1.6,
                                  ),
                                ),
                              );
                            },
                          ),
                        // Avatar Container
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSpeaking && _shouldAnimate
                                  ? const Color(0xFF22C55E)
                                  : AppTheme.darkBorderSubtle,
                              width: isSpeaking && _shouldAnimate ? 2.0 : 1.0,
                            ),
                            boxShadow: isSpeaking && _shouldAnimate
                                ? const [
                                    BoxShadow(
                                      color: Color(0x5522C55E),
                                      blurRadius: 10,
                                      spreadRadius: 1.5,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: isSpeaking ? 25 : 22,
                                backgroundColor: AppTheme.darkSurface2,
                                backgroundImage:
                                    _getImageProvider(speaker.avatarUrl),
                              ),
                              Container(
                                padding: const EdgeInsets.all(3.0),
                                decoration: BoxDecoration(
                                  color: isSpeaking && _shouldAnimate
                                      ? const Color(0xFF22C55E)
                                      : AppTheme.darkSurface2,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  isSpeaking && _shouldAnimate
                                      ? Icons.mic_rounded
                                      : Icons.mic_off_rounded,
                                  size: isSpeaking ? 9.5 : 8,
                                  color: isSpeaking && _shouldAnimate
                                      ? Colors.white
                                      : AppTheme.textMutedDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSpeaking) ...[
                        _buildAnimatedEqualizerBars(isSmall: true),
                        const SizedBox(width: 3),
                      ],
                      SizedBox(
                        width: 72,
                        child: Text(
                          speaker.getLocalizedName(widget.langCode),
                          style: TextStyle(
                            color: isSpeaking
                                ? Colors.white
                                : AppTheme.textSecondaryDark,
                            fontSize: isSpeaking ? 11 : 10.5,
                            fontWeight: isSpeaking
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Animated 3-Bar Voice Equalizer Waveform (`|||`) with Fixed Bounding Box
  Widget _buildAnimatedEqualizerBars({bool isSmall = false}) {
    final double maxH = isSmall ? 10.0 : 13.0;
    final double minH = isSmall ? 3.0 : 3.5;
    final double barW = isSmall ? 2.0 : 2.6;
    final double totalW = (barW * 3) + 4.0;

    return SizedBox(
      width: totalW,
      height: maxH,
      child: AnimatedBuilder(
        animation: _equalizerController,
        builder: (context, child) {
          final val = _shouldAnimate ? _equalizerController.value : 0.0;
          final h1 = _shouldAnimate
              ? (minH + ((maxH - minH) * math.sin(val * math.pi)))
              : 2.0;
          final h2 = _shouldAnimate
              ? (minH + ((maxH - minH) * math.sin((val + 0.33) % 1.0 * math.pi)))
              : 2.0;
          final h3 = _shouldAnimate
              ? (minH + ((maxH - minH) * math.sin((val + 0.66) % 1.0 * math.pi)))
              : 2.0;
          final barColor =
              _shouldAnimate ? const Color(0xFF22C55E) : AppTheme.textMutedDark;

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: barW,
                height: h1,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 2),
              Container(
                width: barW,
                height: h2,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 2),
              Container(
                width: barW,
                height: h3,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
