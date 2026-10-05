import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../live_stream/presentation/abstract_video_player.dart';
import '../../models/streamer_models.dart';
import '../../models/vod_models.dart';

/// Modal sheet for inline playback of archived YouTube VOD lectures.
///
/// On a phone the sheet is as wide as the screen and sits flush with its
/// bottom edge; on wider screens it opens as the usual centred panel.
class VodPlayerModalSheet extends StatefulWidget {
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
    return showCaSheet<void>(context,
        title: vod.getLocalizedTitle(context.locale.languageCode),
        body: VodPlayerModalSheet(vod: vod, streamer: streamer),
        framed: false,
        fullWidthOnPhone: true,
        flushOnPhone: true);
  }

  @override
  State<VodPlayerModalSheet> createState() => _VodPlayerModalSheetState();
}

class _VodPlayerModalSheetState extends State<VodPlayerModalSheet> {
  bool _descriptionOpen = false;

  VodModel get vod => widget.vod;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final title = vod.getLocalizedTitle(lang);
    final isSaved =
        context.select<AppProvider, bool>((p) => p.isBookmarked(vod.vodId));
    final description = vod.getLocalizedDescription(lang).trim();
    final streamer = widget.streamer;
    final broadcasterName =
        streamer != null ? streamer.getLocalizedName(lang) : vod.streamerId;
    final organization = streamer?.getLocalizedOrganization(lang) ?? '';
    final textTheme = Theme.of(context).textTheme;

    // Who is speaking, the title, and a plain close icon.
    final header = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppTheme.spaceLg,
          AppTheme.spaceXs, AppTheme.spaceSm, AppTheme.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppTheme.spaceSm),
                Row(children: [
                  CaAvatar(
                      name: broadcasterName,
                      url: streamer?.avatarUrl,
                      radius: 14,
                      ring: CaAvatarRing.brand,
                      org: streamer?.isOrganization ?? false,
                      verified: streamer?.isVerified ?? false),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Text(
                      organization.isEmpty
                          ? broadcasterName
                          : '$broadcasterName • $organization',
                      style: textTheme.bodySmall
                          ?.copyWith(color: Canopy.brandGreen),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          CaIconButton(
            bare: true,
            icon: CaGlyph.close,
            label: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );

    // The player spans the whole sheet width. Capped at 40% of the
    // viewport: at 16:9 on a landscape tablet it alone wanted most of
    // the height and pushed the details off the sheet. Measured against
    // the viewport, not the incoming constraints, because this Column
    // lays its children out with an unbounded height.
    final player = ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
      child: ColoredBox(
        color: Canopy.forestDeep,
        child: AbstractVideoPlayer.fromSource(
          sourceType: StreamSourceType.youtubeEmbed,
          streamUrl: vod.youtubeVideoId,
          autoPlay: true,
          aspectRatio: 16 / 9,
        ),
      ),
    );

    final details = SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Duration, recorded date and view count. They wrap onto a
          // second line instead of overrunning a 320 px sheet.
          Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              if (vod.durationSeconds > 0)
                _StatPill(glyph: CaGlyph.clock, label: vod.formattedDuration),
              _StatPill(glyph: CaGlyph.cal, label: vod.recordedDate),
              _StatPill(
                  glyph: CaGlyph.eye,
                  label: '${vod.viewCount} ${'profile.views'.tr()}'),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceLg),
            Text(
              description,
              maxLines: _descriptionOpen ? null : 3,
              overflow: _descriptionOpen ? null : TextOverflow.ellipsis,
              style: textTheme.bodyMedium
                  ?.copyWith(color: Canopy.slate, height: 1.5),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                tooltip: (_descriptionOpen
                        ? 'profile.show_less'
                        : 'profile.show_more')
                    .tr(),
                color: Canopy.brandGreen,
                icon: Icon(_descriptionOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded),
                onPressed: () =>
                    setState(() => _descriptionOpen = !_descriptionOpen),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          // Side by side when there is room, stacked on a narrow
          // phone so neither label has to wrap.
          LayoutBuilder(builder: (context, constraints) {
            final save = CaButton(
              // Real bookmark (05 D-07): persisted per account for
              // signed-in viewers, local for guests.
              icon: CaGlyph.bookmark,
              variant: CaButtonVariant.secondary,
              label: isSaved
                  ? 'profile.saved_lecture'.tr()
                  : 'profile.save_lecture'.tr(),
              onPressed: () => context
                  .read<AppProvider>()
                  .toggleBookmark(vod.vodId, streamerId: vod.streamerId),
            );
            final share = CaButton(
              // Shares the recording's real watch URL.
              icon: CaGlyph.share,
              label: 'profile.share_vod'.tr(),
              onPressed: () => Share.share(
                'https://www.youtube.com/watch?v=${vod.youtubeVideoId}',
                subject: title,
              ),
            );
            return constraints.maxWidth >= 440
                ? Row(children: [
                    Expanded(child: save),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(child: share),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        share,
                        const SizedBox(height: AppTheme.spaceSm),
                        save,
                      ]);
          }),
          const SizedBox(height: AppTheme.spaceSm),
          // The escape hatch for a VOD the in-app WebView cannot play
          // (embedding disabled, age-gated, outdated system WebView).
          // Always offered, not only after a visible failure: by the
          // time a viewer decides the embed is broken they have
          // usually already given up on this sheet.
          CaButton(
            icon: CaGlyph.external,
            variant: CaButtonVariant.text,
            label: 'live.open_in_youtube'.tr(),
            onPressed: () => _openInYouTube(vod.youtubeVideoId),
          ),
        ],
      ),
    );

    // A short window (a phone on its side, big text) cannot hold the fixed
    // header and player above a scrolling body, so everything scrolls.
    final compact = MediaQuery.sizeOf(context).height < 560;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(
                    top: AppTheme.spaceSm, bottom: AppTheme.spaceXs),
                width: CanopySize.handleWidth,
                height: CanopySize.handleHeight,
                decoration: BoxDecoration(
                  color: Canopy.hairlineStrong,
                  borderRadius: BorderRadius.circular(CanopyRadius.pill),
                ),
              ),
            ),
            if (compact)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [header, player, details],
                  ),
                ),
              )
            else ...[
              header,
              player,
              Flexible(child: details),
            ],
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
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.glyph, required this.label});
  final CaGlyph glyph;
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: Canopy.mint,
          borderRadius: BorderRadius.circular(CanopyRadius.pill)),
      child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CaIcon(glyph, size: CanopySize.inlineIcon),
            const SizedBox(width: AppTheme.spaceSm),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Canopy.ink)),
          ])));
}
