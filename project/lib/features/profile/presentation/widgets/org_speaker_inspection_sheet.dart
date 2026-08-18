import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../organization/models/org_speaker_model.dart';
import '../../models/vod_models.dart';

class OrgSpeakerInspectionSheet extends StatelessWidget {
  final OrgSpeakerModel speaker;
  final String orgName;
  final List<VodModel> speakerVods;
  final VoidCallback? onFilterSelected;

  const OrgSpeakerInspectionSheet({
    super.key,
    required this.speaker,
    required this.orgName,
    required this.speakerVods,
    this.onFilterSelected,
  });

  static void show(
    BuildContext context, {
    required OrgSpeakerModel speaker,
    required String orgName,
    required List<VodModel> speakerVods,
    VoidCallback? onFilterSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrgSpeakerInspectionSheet(
        speaker: speaker,
        orgName: orgName,
        speakerVods: speakerVods,
        onFilterSelected: onFilterSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkBgBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        border: Border(
          top: BorderSide(color: AppTheme.darkBorderSubtle, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.textSecondaryDark.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'profile.speaker_profile_title'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondaryDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.darkBorderSubtle, height: 1),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Speaker Avatar, Name & Roles
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accentBlue, width: 2),
                          image: DecorationImage(
                            image: speaker.avatarUrl.startsWith('assets/')
                                ? AssetImage(speaker.avatarUrl) as ImageProvider
                                : NetworkImage(speaker.avatarUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              speaker.getLocalizedName(lang),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              speaker.getLocalizedRole(lang),
                              style: const TextStyle(
                                color: AppTheme.accentBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: speaker.isPermanentStaff
                                    ? AppTheme.accentBlue.withValues(alpha: 0.15)
                                    : AppTheme.darkSurface2,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: speaker.isPermanentStaff
                                      ? AppTheme.accentBlue.withValues(alpha: 0.5)
                                      : AppTheme.darkBorderSubtle,
                                ),
                              ),
                              child: Text(
                                speaker.isPermanentStaff
                                    ? 'profile.permanent_staff'.tr()
                                    : 'profile.guest_speaker'.tr(),
                                style: TextStyle(
                                  color: speaker.isPermanentStaff
                                      ? AppTheme.accentBlue
                                      : AppTheme.textSecondaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Bio Section
                  if (speaker.getLocalizedBio(lang).isNotEmpty) ...[
                    Text(
                      'profile.about'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      speaker.getLocalizedBio(lang),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Button to filter lectures
                  if (onFilterSelected != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.filter_list_rounded, size: 18),
                        label: Text('profile.filter_lectures_by_this_speaker'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onFilterSelected!();
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Lectures by this speaker
                  Text(
                    '${'profile.archived_lectures'.tr()} (${speakerVods.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (speakerVods.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'profile.no_instructor_vods'.tr(),
                          style: const TextStyle(
                            color: AppTheme.textSecondaryDark,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: speakerVods.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final vod = speakerVods[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface1,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.darkBorderSubtle),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image(
                                  image: vod.thumbnailUrl.startsWith('assets/')
                                      ? AssetImage(vod.thumbnailUrl) as ImageProvider
                                      : NetworkImage(vod.thumbnailUrl),
                                  width: 60,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vod.getLocalizedTitle(lang),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${vod.formattedDuration} • ${vod.recordedDate}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondaryDark,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
