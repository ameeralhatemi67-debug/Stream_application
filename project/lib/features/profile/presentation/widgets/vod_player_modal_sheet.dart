import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../live_stream/presentation/abstract_video_player.dart';
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
    final isSaved = context.select<AppProvider, bool>(
        (p) => p.isBookmarked(vod.vodId));
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
        color: AppTheme.surface,
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
                  color: AppTheme.borderStrong,
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
                            color: AppTheme.textPrimary,
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
                            color: AppTheme.primary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Embedded YouTube Video Player Adapter, built through the
            // polymorphic factory like every other player in the app, rather
            // than naming the adapter directly.
            //
            // Capped at half the viewport: at 16:9 on a 1280 px landscape
            // tablet the player alone wanted 720 of the 800 available pixels
            // and pushed the title and actions off the sheet.
            ConstrainedBox(
              // Measured against the viewport, not the incoming constraints:
              // this sits in a `mainAxisSize: min` Column, whose children are
              // laid out with an unbounded height, so a LayoutBuilder here
              // would cap the player at infinity.
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: ClipRRect(
                child: AbstractVideoPlayer.fromSource(
                  sourceType: StreamSourceType.youtubeEmbed,
                  streamUrl: vod.youtubeVideoId,
                  autoPlay: true,
                  aspectRatio: 16 / 9,
                ),
              ),
            ),

            // VOD Metadata & Localized Description Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats pills: duration, recorded date and view count.
                    // Three chips in a fixed Row overran a 320 px sheet, so
                    // they wrap onto a second line instead.
                    Wrap(
                      spacing: AppTheme.spaceSm,
                      runSpacing: AppTheme.spaceXs,
                      children: [
                        _buildStatChip(
                          icon: Icons.timer_outlined,
                          label: vod.formattedDuration,
                          color: AppTheme.accent,
                        ),
                        _buildStatChip(
                          icon: Icons.calendar_today_outlined,
                          label: vod.recordedDate,
                          color: AppTheme.textSecondary,
                        ),
                        _buildStatChip(
                          icon: Icons.visibility_outlined,
                          label: '${vod.viewCount} ${'profile.views'.tr()}',
                          color: AppTheme.success,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spaceLg),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: AppTheme.spaceLg),

                    // Full Title & Description
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceLg),

                    // Cluster 1 Task 5 -- the escape hatch for a VOD the
                    // in-app WebView cannot play (embedding disabled by the
                    // uploader, age-gated, or an outdated system WebView).
                    // Always offered, not only after a visible failure: by
                    // the time a viewer decides the embed is broken they
                    // have usually already given up on this sheet.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openInYouTube(vod.youtubeVideoId),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text('live.open_in_youtube'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceMd),

                    // Interactive Action Buttons Bar
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            // Real bookmark (05 D-07): persisted per account
                            // for signed-in viewers, local for guests.
                            onPressed: () => context
                                .read<AppProvider>()
                                .toggleBookmark(vod.vodId,
                                    streamerId: vod.streamerId),
                            icon: Icon(
                                isSaved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_add_outlined,
                                size: 18),
                            label: Text(isSaved
                                ? 'profile.saved_lecture'.tr()
                                : 'profile.save_lecture'.tr()),
                            style: OutlinedButton.styleFrom(
                              // An outlined button has no fill, so its label
                              // sits on the white sheet: `onMedia` white made
                              // it invisible.
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.borderStrong),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(
                          child: ElevatedButton.icon(
                            // Shares the recording's real watch URL.
                            onPressed: () => Share.share(
                              'https://www.youtube.com/watch?v=${vod.youtubeVideoId}',
                              subject: title,
                            ),
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: Text('profile.share_vod'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.bg,
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

  Future<void> _openInYouTube(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) return;

    // 1. Try launching native YouTube app via custom scheme
    final appUri = Uri.parse('vnd.youtube:$id');
    try {
      final launched =
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}

    // 2. Fallback: Launch standard web URL in external browser/app
    final webUri = Uri.parse('https://www.youtube.com/watch?v=$id');
    try {
      final launched =
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}

    // 3. Last-resort fallback: platformDefault
    try {
      await launchUrl(webUri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('[VodPlayerModalSheet] openInYouTube failed: $e');
    }
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(color: AppTheme.border),
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
