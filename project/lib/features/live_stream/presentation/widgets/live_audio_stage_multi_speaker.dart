import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../organization/models/org_speaker_model.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../profile/models/vod_models.dart';
import '../../../profile/presentation/widgets/org_speaker_inspection_sheet.dart';

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
  State<LiveAudioStageMultiSpeaker> createState() => _LiveAudioStageMultiSpeakerState();
}

class _LiveAudioStageMultiSpeakerState extends State<LiveAudioStageMultiSpeaker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }

  void _inspectSpeaker(OrgSpeakerModel speaker) {
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
    final List<OrgSpeakerModel> speakers = widget.speakers.isNotEmpty
        ? widget.speakers
        : [
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

    final effectiveActiveId = widget.activeSpeakerId ?? speakers.first.speakerId;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF18181B),
            Color(0xFF09090B),
            AppTheme.darkSurface1,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Soundwave Radar Rings (Animated)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140 + (_pulseAnimation.value * 25),
                    height: 140 + (_pulseAnimation.value * 25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentBlue.withValues(
                          alpha: 0.15 + (0.15 * (1.0 - _pulseAnimation.value)),
                        ),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 190 + (_pulseAnimation.value * 35),
                    height: 190 + (_pulseAnimation.value * 35),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentBlue.withValues(
                          alpha: 0.08 + (0.10 * (1.0 - _pulseAnimation.value)),
                        ),
                        width: 1.2,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Speakers Layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: speakers.length == 1
                ? _buildSingleSpeakerLayout(speakers.first)
                : _buildMultiSpeakerRoster(speakers, effectiveActiveId),
          ),

          // Bottom Live Audio Status Bar
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 14,
                    color: Color(0xFF22C55E), // Active green voice EQ
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'live.speaking_now'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• ${widget.viewerCount} ${'live.listening_count'.tr()}',
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
    );
  }

  Widget _buildSingleSpeakerLayout(OrgSpeakerModel speaker) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _inspectSpeaker(speaker),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentAmber,
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentAmber.withValues(
                        alpha: 0.25 + (0.35 * _pulseAnimation.value),
                      ),
                      blurRadius: 16 + (8 * _pulseAnimation.value),
                      spreadRadius: 2 + (4 * _pulseAnimation.value),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
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
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          speaker.getLocalizedName(widget.langCode),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          speaker.getLocalizedRole(widget.langCode),
          style: const TextStyle(
            color: AppTheme.accentBlue,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMultiSpeakerRoster(List<OrgSpeakerModel> speakers, String activeId) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: speakers.map((speaker) {
            final isActive = speaker.speakerId == activeId;
            return GestureDetector(
              onTap: () => _inspectSpeaker(speaker),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? AppTheme.accentAmber
                                : AppTheme.accentBlue.withValues(alpha: 0.6),
                            width: isActive ? 2.0 : 1.2,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppTheme.accentAmber.withValues(
                                      alpha: 0.25 + (0.35 * _pulseAnimation.value),
                                    ),
                                    blurRadius: 12 + (6 * _pulseAnimation.value),
                                    spreadRadius: 1 + (3 * _pulseAnimation.value),
                                  ),
                                ]
                              : null,
                        ),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: isActive ? 28 : 24,
                              backgroundColor: AppTheme.darkSurface2,
                              backgroundImage: _getImageProvider(speaker.avatarUrl),
                            ),
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF22C55E) : AppTheme.darkSurface1,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 1.2),
                              ),
                              child: Icon(
                                isActive ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                                size: 10,
                                color: isActive ? Colors.white : AppTheme.textSecondaryDark,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 75,
                    child: Text(
                      speaker.getLocalizedName(widget.langCode),
                      style: TextStyle(
                        color: isActive ? Colors.white : AppTheme.textSecondaryDark,
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
