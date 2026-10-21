import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../web/presentation/hidayah_web_kit.dart';

/// The live room as a website page (gold palette, laptop), on the dark
/// cinema header. Video: a wide stage with the lecture details under it.
/// Audio only: a listening room, with the title above a framed audio stage.
/// The chat column is the room's own tab panel, unchanged.
class LiveWebLayout extends StatelessWidget {
  const LiveWebLayout(
      {super.key,
      required this.streamer,
      required this.viewport,
      required this.panel,
      required this.viewerCount,
      required this.following,
      required this.onFollow,
      required this.onMinimize,
      this.onStudio});
  final StreamerModel streamer;
  final Widget viewport, panel;
  final int? viewerCount;
  final bool following;
  final VoidCallback onFollow, onMinimize;
  final VoidCallback? onStudio;

  @override
  Widget build(BuildContext context) {
    final audio = streamer.isAudioLive;
    final stage = audio
        ? _AudioRoom(
            streamer: streamer, viewport: viewport, viewerCount: viewerCount)
        : ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    border: Border.all(
                        color: HidayahGold.g300.withValues(alpha: .18))),
                child: viewport));
    return ColoredBox(
        color: HidayahGold.s950,
        child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Expanded(child: stage),
                    const SizedBox(height: 18),
                    _Details(
                        streamer: streamer,
                        showTitle: !audio,
                        viewerCount: viewerCount,
                        following: following,
                        onFollow: onFollow,
                        onMinimize: onMinimize,
                        onStudio: onStudio),
                  ])),
              const SizedBox(width: 24),
              SizedBox(
                  width: 400,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              border: Border.all(color: HidayahGold.s800)),
                          child: panel))),
            ])));
  }
}

String _audience(StreamerModel s, int? count) =>
    '${count ?? '—'} ${(s.isAudioLive ? 'web.listening' : 'web.watching').tr()}';

/// Audio only: the night band with the programme title, then the audio stage
/// framed like a radio dial rather than stretched like a video.
class _AudioRoom extends StatelessWidget {
  const _AudioRoom(
      {required this.streamer,
      required this.viewport,
      required this.viewerCount});
  final StreamerModel streamer;
  final Widget viewport;
  final int? viewerCount;
  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return HidayahNightBand(
        radius: BorderRadius.circular(16),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    HidayahLiveBadge(
                        audio: true, label: 'web.badge_audio'.tr()),
                    const SizedBox(width: 10),
                    HidayahGlassBadge(
                        icon: CaGlyph.mic,
                        label: _audience(streamer, viewerCount)),
                  ]),
                  const SizedBox(height: 14),
                  Text(streamer.getLocalizedTitle(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HidayahText.display(30, color: HidayahGold.g50)),
                  const SizedBox(height: 6),
                  Text('web.audio_hint'.tr(),
                      style: HidayahText.body(14, color: HidayahGold.s300)),
                  const SizedBox(height: 22),
                  Expanded(
                      child: Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                          gradient: HidayahGradients.gilded,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: viewport)))))),
                ])));
  }
}

class _Details extends StatelessWidget {
  const _Details(
      {required this.streamer,
      required this.showTitle,
      required this.viewerCount,
      required this.following,
      required this.onFollow,
      required this.onMinimize,
      this.onStudio});
  final StreamerModel streamer;
  final bool showTitle, following;
  final int? viewerCount;
  final VoidCallback onFollow, onMinimize;
  final VoidCallback? onStudio;
  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final s = streamer;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            Row(children: [
              HidayahLiveBadge(label: 'web.badge_live'.tr()),
              const SizedBox(width: 10),
              HidayahGlassBadge(
                  icon: CaGlyph.eye, label: _audience(s, viewerCount)),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(s.getLocalizedTitle(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HidayahText.display(24, color: HidayahGold.g50))),
            ]),
            const SizedBox(height: 14),
          ],
          // Large text stacks the actions under the identity; otherwise the
          // identity takes what the buttons leave and ellipsizes (a long
          // organization line used to push the buttons off a 1280 px tablet).
          Builder(builder: (context) {
            final identity = Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkWell(
                    onTap: () => context.push('/profile/${s.channelProfileId}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      CaAvatar(
                          name: s.getLocalizedName(lang),
                          url: s.avatarUrl,
                          live: true,
                          ring: CaAvatarRing.brand,
                          org: s.isOrganization,
                          radius: 22),
                      const SizedBox(width: 12),
                      Flexible(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Flexible(
                                  child: Text(s.getLocalizedName(lang),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: HidayahText.body(15.5,
                                          color: HidayahGold.g50,
                                          weight: FontWeight.w700,
                                          height: 1.3))),
                              if (s.isVerified) ...[
                                const SizedBox(width: 5),
                                const CaIcon(CaGlyph.verified, size: 16),
                              ],
                            ]),
                            Text(
                                [
                                  s.getLocalizedOrganization(lang),
                                  s.getLocalizedVenue(lang)
                                ].where((t) => t.isNotEmpty).join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HidayahText.body(13,
                                    color: HidayahGold.s300, height: 1.3)),
                          ])),
                    ])));
            final actions = <Widget>[
              HidayahButton(
                  label:
                      (following ? 'profile.following_btn' : 'web.follow').tr(),
                  icon: following ? CaGlyph.check : CaGlyph.plus,
                  kind: following
                      ? HidayahButtonKind.onDark
                      : HidayahButtonKind.gold,
                  onPressed: onFollow),
              const SizedBox(width: 10),
              HidayahButton(
                  label: 'web.minimize'.tr(),
                  icon: CaGlyph.arrow,
                  kind: HidayahButtonKind.onDark,
                  onPressed: onMinimize),
              if (onStudio != null) ...[
                const SizedBox(width: 10),
                HidayahButton(
                    label: 'organization_v1.studio'.tr(),
                    icon: CaGlyph.video,
                    kind: HidayahButtonKind.onDark,
                    onPressed: onStudio),
              ],
            ];
            if (MediaQuery.textScalerOf(context).scale(10) > 13) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    identity,
                    const SizedBox(height: 12),
                    Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            actions.where((w) => w is! SizedBox).toList()),
                  ]);
            }
            return Row(children: [
              Expanded(child: identity),
              const SizedBox(width: 16),
              ...actions,
            ]);
          }),
        ]);
  }
}
