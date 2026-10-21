import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_fixed_lines.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../discovery/models/bookmark_entry.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/streamer_models.dart';
import '../../models/vod_models.dart';
import 'vod_player_modal_sheet.dart';

/// 2-Column VOD grid item tile for displaying past lecture recordings in Profile screen.
class VodGridTile extends StatelessWidget {
  final VodModel vod;
  final StreamerModel? streamer;

  const VodGridTile({
    super.key,
    required this.vod,
    this.streamer,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final title = vod.getLocalizedTitle(lang);
    final saved = context.select<AppProvider, bool>(
        (p) => p.isBookmarked(BookmarkEntry.recording(vod).id));

    return CaCard(
        padding: EdgeInsets.zero,
        onTap: () =>
            VodPlayerModalSheet.show(context, vod: vod, streamer: streamer),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    Image(
                        image: buildSafeImageProvider(
                            path: vod.thumbnailUrl.startsWith('http') ||
                                    vod.thumbnailUrl.startsWith('assets/')
                                ? vod.thumbnailUrl
                                : 'https://img.youtube.com/vi/${vod.youtubeVideoId}/hqdefault.jpg'),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: Canopy.mint)),
                    const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppGradients.mediaScrim)),
                    const Center(
                        child: CaIcon(CaGlyph.play, color: Canopy.paper)),
                    if (saved)
                      PositionedDirectional(
                        top: AppTheme.spaceSm,
                        end: AppTheme.spaceSm,
                        child: Semantics(
                            label: 'profile.saved_lecture'.tr(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spaceSm,
                                  vertical: AppTheme.spaceXs),
                              decoration: BoxDecoration(
                                  color: Canopy.mint,
                                  borderRadius:
                                      BorderRadius.circular(CanopyRadius.pill)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CaIcon(CaGlyph.check,
                                        size: CanopySize.inlineIcon),
                                    const SizedBox(width: AppTheme.spaceXs),
                                    Text('profile.saved_lecture'.tr(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                                color: Canopy.brandGreen)),
                                  ]),
                            )),
                      ),
                    if (vod.durationSeconds > 0)
                      PositionedDirectional(
                          bottom: AppTheme.spaceSm,
                          end: AppTheme.spaceSm,
                          child: Container(
                              padding: const EdgeInsets.all(AppTheme.spaceXs),
                              decoration: BoxDecoration(
                                  color: Canopy.forestDeep,
                                  borderRadius:
                                      BorderRadius.circular(CanopyRadius.pill)),
                              child: Text(vod.formattedDuration,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Canopy.paper)))),
                  ])),
              Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Two title lines and one detail line are always
                        // reserved, so every tile is the same height.
                        CaFixedLines(title,
                            lines: 2,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: Canopy.ink)),
                        const SizedBox(height: AppTheme.spaceXs),
                        CaFixedLines(
                            '${vod.recordedDate} • ${vod.viewCount} ${'profile.views'.tr()}',
                            lines: 1,
                            style: Theme.of(context).textTheme.bodySmall),
                      ])),
            ]));
  }
}
