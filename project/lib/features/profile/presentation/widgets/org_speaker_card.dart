import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../organization/models/org_speaker_model.dart';
import '../../models/vod_models.dart';

class OrgSpeakerCard extends StatelessWidget {
  final OrgSpeakerModel speaker;
  final String orgName;
  final List<VodModel> speakerVods;
  final VoidCallback? onFilterSelected;

  const OrgSpeakerCard({
    super.key,
    required this.speaker,
    required this.orgName,
    required this.speakerVods,
    this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return InkWell(
      onTap: onFilterSelected,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.darkBorderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar with border
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accentBlue.withValues(alpha: 0.8),
                      width: 2,
                    ),
                    image: DecorationImage(
                      image: speaker.avatarUrl.startsWith('assets/')
                          ? AssetImage(speaker.avatarUrl) as ImageProvider
                          : NetworkImage(speaker.avatarUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        speaker.getLocalizedName(lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        speaker.getLocalizedRole(lang),
                        style: const TextStyle(
                          color: AppTheme.accentBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: speaker.isPermanentStaff
                              ? AppTheme.accentBlue.withValues(alpha: 0.12)
                              : AppTheme.darkSurface2,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          speaker.isPermanentStaff
                              ? 'profile.permanent_staff'.tr()
                              : 'profile.guest_speaker'.tr(),
                          style: TextStyle(
                            color: speaker.isPermanentStaff
                                ? AppTheme.accentBlue
                                : AppTheme.textSecondaryDark,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (speaker.getLocalizedBio(lang).isNotEmpty)
              Text(
                speaker.getLocalizedBio(lang),
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 11.5,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${speakerVods.length} ${'profile.lectures_count'.tr()}',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppTheme.accentBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
