import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../../core/widgets/streamer_avatar.dart';
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

  /// A recording thumbnail, or a neutral tile when the entry has none: an
  /// empty URL used to reach `NetworkImage('')` and fail on every rebuild.
  Widget _thumbnail(String url) {
    Widget fallback() => Container(
          width: 60,
          height: 40,
          color: AppTheme.surfaceAlt,
          alignment: Alignment.center,
          child: const Icon(Icons.video_library_rounded,
              size: 16, color: AppTheme.textMuted),
        );
    final provider = resolveImageProviderOrNull(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: provider == null
          ? fallback()
          : Image(
              image: provider,
              width: 60,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
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
        color: AppTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 1.5),
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
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'profile.speaker_profile_title'.tr(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.border, height: 1),

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
                      StreamerAvatar(
                        radius: 36,
                        avatarUrl: speaker.avatarUrl,
                        borderColor: AppTheme.primary,
                        borderWidth: 2,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              speaker.getLocalizedName(lang),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              speaker.getLocalizedRole(lang),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: speaker.isPermanentStaff
                                    ? AppTheme.primary.withValues(alpha: 0.15)
                                    : AppTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: speaker.isPermanentStaff
                                      ? AppTheme.primary.withValues(alpha: 0.5)
                                      : AppTheme.border,
                                ),
                              ),
                              child: Text(
                                speaker.isPermanentStaff
                                    ? 'profile.permanent_staff'.tr()
                                    : 'profile.guest_speaker'.tr(),
                                style: TextStyle(
                                  color: speaker.isPermanentStaff
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
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
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      speaker.getLocalizedBio(lang),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
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
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.onMedia,
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
                      color: AppTheme.textPrimary,
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
                            color: AppTheme.textSecondary,
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
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              _thumbnail(vod.thumbnailUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vod.getLocalizedTitle(lang),
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
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
                                        color: AppTheme.textSecondary,
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
