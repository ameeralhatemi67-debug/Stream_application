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
/// Features prominent real-time voice activity indicators, soundwave ripples,
/// animated equalizer waveform bars, and clear speaking vs idle visual states.
class LiveAudioStageMultiSpeaker extends StatefulWidget {
  final StreamerModel streamer;
  final String langCode;
  final int viewerCount;
  final List<OrgSpeakerModel> speakers;
  final List<VodModel> allVods;
  final String? activeSpeakerId;
  final Function(OrgSpeakerModel)? onSpeakerTap;

  const LiveAudioStageMultiSpeaker({
    super.key,
    required this.streamer,
    required this.langCode,
    required this.viewerCount,
    this.speakers = const [],
    this.allVods = const [],
    this.activeSpeakerId,
    this.onSpeakerTap,
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

    return Container(
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
          // Background Subtle Ambient Voice Wave Glow
          AnimatedBuilder(
            animation: _voiceRippleAnimation,
            builder: (context, child) {
              return Container(
                width: 220 + (_voiceRippleAnimation.value * 50),
                height: 220 + (_voiceRippleAnimation.value * 50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF22C55E).withValues(
                        alpha: 0.12 * (1.0 - _voiceRippleAnimation.value),
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),

          // Main Speakers Roster
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: speakers.length == 1
                ? _buildSingleSpeakerLayout(speakers.first)
                : _buildMultiSpeakerRoster(speakers, activeId),
          ),

          // Bottom Live Audio Status Bar with Active Speaking Callout
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAnimatedEqualizerBars(isSmall: true),
                  const SizedBox(width: 8),
                  Text(
                    activeSpeaker.getLocalizedName(widget.langCode),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'live.speaking_now'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppTheme.textMutedDark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.viewerCount} ${'live.listening_count'.tr()}',
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSpeakerLayout(OrgSpeakerModel speaker) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _onSpeakerClicked(speaker),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding Voice Ripple Ring 1
              AnimatedBuilder(
                animation: _voiceRippleAnimation,
                builder: (context, child) {
                  return Container(
                    width: 96 + (_voiceRippleAnimation.value * 40),
                    height: 96 + (_voiceRippleAnimation.value * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF22C55E).withValues(
                          alpha: 0.6 * (1.0 - _voiceRippleAnimation.value),
                        ),
                        width: 2.0,
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
                  return Container(
                    width: 96 + (progress * 40),
                    height: 96 + (progress * 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(
                          alpha: 0.45 * (1.0 - progress),
                        ),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),
              // Core Glowing Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF22C55E),
                    width: 2.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x6622C55E),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.darkSurface2,
                      backgroundImage: _getImageProvider(speaker.avatarUrl),
                    ),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnimatedEqualizerBars(),
            const SizedBox(width: 8),
            Text(
              speaker.getLocalizedName(widget.langCode),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          speaker.getLocalizedRole(widget.langCode),
          style: const TextStyle(
            color: AppTheme.accentBlue,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMultiSpeakerRoster(
      List<OrgSpeakerModel> speakers, String activeId) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 16,
          children: speakers.map((speaker) {
            final isSpeaking = speaker.speakerId == activeId;
            return GestureDetector(
              onTap: () => _onSpeakerClicked(speaker),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Active Speaker Expanding Wave Ring
                      if (isSpeaking)
                        AnimatedBuilder(
                          animation: _voiceRippleAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 68 + (_voiceRippleAnimation.value * 28),
                              height: 68 + (_voiceRippleAnimation.value * 28),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF22C55E).withValues(
                                    alpha: 0.65 *
                                        (1.0 - _voiceRippleAnimation.value),
                                  ),
                                  width: 2.0,
                                ),
                              ),
                            );
                          },
                        ),
                      // Avatar Container
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSpeaking
                                ? const Color(0xFF22C55E)
                                : AppTheme.darkBorderSubtle,
                            width: isSpeaking ? 2.5 : 1.2,
                          ),
                          boxShadow: isSpeaking
                              ? const [
                                  BoxShadow(
                                    color: Color(0x6622C55E),
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
                              radius: isSpeaking ? 30 : 26,
                              backgroundColor: AppTheme.darkSurface2,
                              backgroundImage:
                                  _getImageProvider(speaker.avatarUrl),
                            ),
                            Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: BoxDecoration(
                                color: isSpeaking
                                    ? const Color(0xFF22C55E)
                                    : AppTheme.darkSurface2,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                isSpeaking
                                    ? Icons.mic_rounded
                                    : Icons.mic_none_rounded,
                                size: isSpeaking ? 11 : 9,
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
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSpeaking) ...[
                        _buildAnimatedEqualizerBars(isSmall: true),
                        const SizedBox(width: 4),
                      ],
                      SizedBox(
                        width: 78,
                        child: Text(
                          speaker.getLocalizedName(widget.langCode),
                          style: TextStyle(
                            color: isSpeaking
                                ? Colors.white
                                : AppTheme.textSecondaryDark,
                            fontSize: isSpeaking ? 12 : 11,
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
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Animated 3-Bar Voice Equalizer Waveform (`|||`)
  Widget _buildAnimatedEqualizerBars({bool isSmall = false}) {
    final double maxH = isSmall ? 10.0 : 14.0;
    final double minH = isSmall ? 3.0 : 4.0;
    final double barW = isSmall ? 2.2 : 3.0;

    return AnimatedBuilder(
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
    );
  }
}
