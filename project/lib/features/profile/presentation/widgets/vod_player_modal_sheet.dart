import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feature_in_progress_modal.dart';
import '../../../live_stream/presentation/adapters/youtube_player_adapter.dart';
import '../../models/streamer_models.dart';
import '../../models/vod_models.dart';

/// Modal sheet for inline playback of archived YouTube VOD lectures.
class VodPlayerModalSheet extends StatelessWidget {
  final VodModel vod;
  final StreamerModel? streamer;

  const VodPlayerModalSheet({
    super.key,
    required this.vod,
    this.streamer,
  });

  static Future<void> show(
    BuildContext context, {
    required VodModel vod,
    StreamerModel? streamer,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => VodPlayerModalSheet(
        vod: vod,
        streamer: streamer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final title = vod.getLocalizedTitle(lang);
    final description = vod.getLocalizedDescription(lang);
    final broadcasterName = streamer != null
        ? streamer!.getLocalizedName(lang)
        : vod.streamerId;
    final organization = streamer?.getLocalizedOrganization(lang) ?? '';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface3,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle Indicator bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppTheme.spaceSm, bottom: AppTheme.spaceXs),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkBorderHighlight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header Title & Close Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceLg,
                vertical: AppTheme.spaceSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$broadcasterName ${organization.isNotEmpty ? "• $organization" : ""}',
                          style: const TextStyle(
                            color: AppTheme.accentBlue,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondaryDark),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Embedded YouTube Video Player Adapter
            ClipRRect(
              child: YouTubePlayerAdapter(
                streamUrl: vod.youtubeVideoId,
                autoPlay: true,
                aspectRatio: 16 / 9,
              ),
            ),

            // VOD Metadata & Localized Description Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Pill Row: Duration, Recorded Date, Views Count
                    Row(
                      children: [
                        _buildStatChip(
                          icon: Icons.timer_outlined,
                          label: vod.formattedDuration,
                          color: AppTheme.accentPurple,
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                        _buildStatChip(
                          icon: Icons.calendar_today_outlined,
                          label: vod.recordedDate,
                          color: AppTheme.textSecondaryDark,
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                        _buildStatChip(
                          icon: Icons.visibility_outlined,
                          label: '${vod.viewCount} ${'profile.views'.tr()}',
                          color: AppTheme.accentGreen,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spaceLg),
                    const Divider(color: AppTheme.darkBorderSubtle, height: 1),
                    const SizedBox(height: AppTheme.spaceLg),

                    // Full Title & Description
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceLg),

                    // Interactive Action Buttons Bar
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => FeatureInProgressModal.show(
                              context,
                              featureName: 'profile.save_lecture'.tr(),
                            ),
                            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                            label: Text('profile.save_lecture'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: AppTheme.darkBorderHighlight),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => FeatureInProgressModal.show(
                              context,
                              featureName: 'profile.share_vod'.tr(),
                            ),
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: Text('profile.share_vod'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentBlue,
                              foregroundColor: AppTheme.darkBgBase,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
