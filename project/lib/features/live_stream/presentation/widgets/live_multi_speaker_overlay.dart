import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../organization/models/org_speaker_model.dart';
import '../../../profile/models/vod_models.dart';
import '../../../profile/presentation/widgets/org_speaker_inspection_sheet.dart';

class LiveMultiSpeakerOverlay extends StatelessWidget {
  final List<OrgSpeakerModel> speakers;
  final String orgName;
  final List<VodModel> allVods;
  final String? activeSpeakerId;
  final Function(OrgSpeakerModel)? onSpeakerTap;

  const LiveMultiSpeakerOverlay({
    super.key,
    required this.speakers,
    required this.orgName,
    this.allVods = const [],
    this.activeSpeakerId,
    this.onSpeakerTap,
  });

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    if (speakers.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 240,
          maxHeight: 44,
        ),
        child: speakers.length <= 5
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: speakers.map((speaker) => _buildSpeakerAvatar(context, speaker)).toList(),
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                itemCount: speakers.length,
                itemBuilder: (ctx, idx) => _buildSpeakerAvatar(context, speakers[idx]),
              ),
      ),
    );
  }

  Widget _buildSpeakerAvatar(BuildContext context, OrgSpeakerModel speaker) {
    final isActive = activeSpeakerId == speaker.speakerId || (activeSpeakerId == null && speaker.isPermanentStaff);
    final borderColor = isActive ? AppTheme.accentAmber : AppTheme.accentBlue.withValues(alpha: 0.8);

    return Tooltip(
      message: '${speaker.nameEn} • ${speaker.roleOrTitleEn}',
      child: GestureDetector(
        onTap: () {
          if (onSpeakerTap != null) {
            onSpeakerTap!(speaker);
          } else {
            final speakerVods = allVods.where((v) => v.speakerIds.contains(speaker.speakerId)).toList();
            OrgSpeakerInspectionSheet.show(
              context,
              speaker: speaker,
              orgName: orgName,
              speakerVods: speakerVods,
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: isActive ? 2.0 : 1.2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppTheme.accentAmber.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: Image(
                    image: _getImageProvider(speaker.avatarUrl),
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E), // Emerald Green Active Voice
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
