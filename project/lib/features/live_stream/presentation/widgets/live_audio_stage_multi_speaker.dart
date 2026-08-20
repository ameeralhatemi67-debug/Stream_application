import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../organization/models/org_speaker_model.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../profile/models/vod_models.dart';
import '../../../profile/presentation/widgets/org_speaker_inspection_sheet.dart';

/// Interactive Live Audio Stage for single and multi-speaker broadcasts.
/// Proportionally scaled for 16:9 viewports with zero overflow, rock-solid
/// non-jittering animation containers, real-time voice ripples, and animated equalizers.
class LiveAudioStageMultiSpeaker extends StatefulWidget {
  final StreamerModel streamer;
  final String langCode;
  final int viewerCount;
  final List<OrgSpeakerModel> speakers;
  final List<VodModel> allVods;
  final String? activeSpeakerId;
  final Function(OrgSpeakerModel)? onSpeakerTap;
  final VoidCallback? onStageTap;

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

  @override
  void initState() {
    super.initState();
    _voiceRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: false);

    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _voiceRippleAnimation = CurvedAnimation(
      parent: _voiceRippleController,
      curve: Curves.easeOutQuad,
    );

    _currentSpeakingSpeakerId = widget.activeSpeakerId;

    // In multi-speaker stages, simulate natural conversational turn-taking
    // if no explicit static activeSpeakerId is forced
    if (widget.speakers.length > 1 && widget.activeSpeakerId == null) {
      _speakerRotationTimer =
          Timer.periodic(const Duration(seconds: 7), (timer) {
        if (!mounted) return;
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
      onTap: widget.onStageTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF141416),
              Color(0xFF0D0D0E),
              AppTheme.darkSurface1,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Subtle Ambient Voice Wave Glow (Static bounding box)
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _voiceRippleAnimation,
                  builder: (context, child) {
                    final d = 160.0 + (_voiceRippleAnimation.value * 40.0);
                    return Container(
                      width: d,
                      height: d,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF22C55E).withValues(
                              alpha: 0.10 * (1.0 - _voiceRippleAnimation.value),
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
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
                    Text(
                      activeSpeaker.getLocalizedName(widget.langCode),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'live.speaking_now'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF22C55E),
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
                      '${widget.viewerCount} ${'live.listening_count'.tr()}',
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
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
                // Expanding Voice Ripple Ring 1 (Static SizedBox bounds)
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
                      color: const Color(0xFF22C55E),
                      width: 2.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x5522C55E),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
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
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          size: 11,
                          color: Colors.white,
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
                        if (isSpeaking)
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
                              color: isSpeaking
                                  ? const Color(0xFF22C55E)
                                  : AppTheme.darkBorderSubtle,
                              width: isSpeaking ? 2.0 : 1.0,
                            ),
                            boxShadow: isSpeaking
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
                                  color: isSpeaking
                                      ? const Color(0xFF22C55E)
                                      : AppTheme.darkSurface2,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  isSpeaking
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  size: isSpeaking ? 9.5 : 8,
                                  color: isSpeaking
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
          final val = _equalizerController.value;
          final h1 = minH + ((maxH - minH) * math.sin(val * math.pi));
          final h2 =
              minH + ((maxH - minH) * math.sin((val + 0.33) % 1.0 * math.pi));
          final h3 =
              minH + ((maxH - minH) * math.sin((val + 0.66) % 1.0 * math.pi));

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: barW,
                height: h1,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 2),
              Container(
                width: barW,
                height: h2,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 2),
              Container(
                width: barW,
                height: h3,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
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
