import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../web/presentation/hidayah_web_kit.dart';
import '../../models/streamer_models.dart';

/// Breadcrumbs, cover, identity and actions of a channel page on the website.
class ProfileWebHero extends StatelessWidget {
  const ProfileWebHero(
      {super.key,
      required this.streamer,
      required this.live,
      required this.uncertain,
      required this.following,
      required this.reminder,
      required this.remindersAvailable,
      required this.recordings,
      required this.playlists,
      required this.onFollow,
      required this.onWatch,
      required this.onReminder,
      this.onShare,
      this.onStudio});
  final StreamerModel streamer;
  final bool live, uncertain, following, reminder, remindersAvailable;
  final int recordings, playlists;
  final VoidCallback onFollow, onWatch, onReminder;
  final VoidCallback? onShare, onStudio;

  static const _cover = 230.0;
  static const _avatar = 62.0;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final s = streamer;
    Widget stat(int value, String label) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$value', style: HidayahText.display(20)),
              const SizedBox(width: 6),
              Text(label,
                  style: HidayahText.body(13, color: HidayahGold.s600)),
            ]);
    final follow = HidayahButton(
        label: (following ? 'profile.following_btn' : 'web.follow').tr(),
        icon: following ? CaGlyph.check : CaGlyph.plus,
        kind: live || following ? HidayahButtonKind.ghost : HidayahButtonKind.gold,
        onPressed: onFollow);
    return HidayahWebWidth(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 14),
          child: Row(children: [
            InkWell(
                onTap: () => context.go('/feed'),
                child: Text('web.nav_discover'.tr(),
                    style: HidayahText.body(13.5, color: HidayahGold.s600))),
            const SizedBox(width: 8),
            const HidayahForwardIcon(size: 14),
            const SizedBox(width: 8),
            Text('web.crumb_channels'.tr(),
                style: HidayahText.body(13.5, color: HidayahGold.s600)),
            const SizedBox(width: 8),
            const HidayahForwardIcon(size: 14),
            const SizedBox(width: 8),
            Flexible(
                child: Text(s.getLocalizedName(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HidayahText.body(13.5,
                        color: HidayahGold.s900, weight: FontWeight.w700))),
          ])),
      Stack(clipBehavior: Clip.none, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                  height: _cover,
                  child: Stack(fit: StackFit.expand, children: [
                    CaCardImage(url: s.bannerUrl),
                    const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [.5, 1],
                                colors: [
                          Color(0x000B1117),
                          Color(0x590B1117)
                        ]))),
                    PositionedDirectional(
                        top: 14,
                        end: 14,
                        child: live
                            ? HidayahLiveBadge(
                                audio: s.isAudioLive,
                                label: (s.isAudioLive
                                        ? 'web.badge_audio'
                                        : 'web.badge_live')
                                    .tr())
                            : HidayahGlassBadge(
                                icon: CaGlyph.clock,
                                label: (uncertain
                                        ? 'offline_experience.status_unavailable'
                                        : 'ds.status_offline')
                                    .tr())),
                  ]))),
          Padding(
              padding: const EdgeInsetsDirectional.only(
                  start: 28 + _avatar * 2 + 14 + 24, top: 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Flexible(
                            child: Text(s.getLocalizedName(lang),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: HidayahText.display(32))),
                        if (s.isVerified) ...[
                          const SizedBox(width: 10),
                          const CaIcon(CaGlyph.verified, size: 22),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(s.getLocalizedTitle(lang),
                          style: HidayahText.body(15, height: 1.4)),
                      if (s.getLocalizedOrganization(lang).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const CaIcon(CaGlyph.home,
                              color: HidayahGold.g700, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(s.getLocalizedOrganization(lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HidayahText.body(14.5,
                                      color: HidayahGold.g700,
                                      weight: FontWeight.w700))),
                        ]),
                      ],
                      const SizedBox(height: 10),
                      Wrap(spacing: 26, runSpacing: 6, children: [
                        stat(recordings, 'web.stat_recordings'.tr()),
                        stat(playlists, 'web.stat_playlists'.tr()),
                      ]),
                    ])),
                const SizedBox(width: 20),
                Flexible(
                    child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                      if (live)
                        HidayahButton(
                            label: (s.isAudioLive ? 'web.listen' : 'web.watch')
                                .tr(),
                            icon: s.isAudioLive ? CaGlyph.mic : CaGlyph.play,
                            onPressed: onWatch),
                      follow,
                      if (remindersAvailable)
                        HidayahButton(
                            label: (reminder
                                    ? 'profile.reminder_on'
                                    : 'profile.reminder_btn')
                                .tr(),
                            icon: reminder ? CaGlyph.check : CaGlyph.bell,
                            kind: HidayahButtonKind.ghost,
                            onPressed: onReminder),
                      if (onShare != null)
                        HidayahButton(
                            label: 'profile.share_btn'.tr(),
                            icon: CaGlyph.share,
                            kind: HidayahButtonKind.ghost,
                            onPressed: onShare),
                      if (onStudio != null)
                        HidayahButton(
                            label: 'organization_v1.studio'.tr(),
                            icon: CaGlyph.video,
                            kind: HidayahButtonKind.ghost,
                            onPressed: onStudio),
                    ]))),
              ])),
        ]),
        PositionedDirectional(
            top: _cover - _avatar - 6,
            start: 28,
            child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: HidayahGold.card,
                    shape: s.isOrganization ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius:
                        s.isOrganization ? BorderRadius.circular(22) : null,
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x660B1117),
                          blurRadius: 30,
                          spreadRadius: -18,
                          offset: Offset(0, 16))
                    ]),
                child: CaAvatar(
                    name: s.getLocalizedName(lang),
                    url: s.avatarUrl,
                    live: live,
                    org: s.isOrganization,
                    ring: CaAvatarRing.brand,
                    radius: _avatar))),
      ]),
    ]));
  }
}

/// The underline tab strip; [index] is visual: upcoming, playlists, archive.
class ProfileWebTabs extends StatelessWidget {
  const ProfileWebTabs(
      {super.key,
      required this.index,
      required this.onChanged,
      required this.playlists,
      required this.recordings});
  final int index, playlists, recordings;
  final ValueChanged<int> onChanged;
  static const height = 77.0;
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: HidayahGold.g50,
      child: HidayahWebWidth(
          child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: DecoratedBox(
                  decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: HidayahGold.hairline))),
                  child: Row(children: [
                    HidayahTab(
                        label: 'profile.upcoming_tab'.tr(),
                        selected: index == 0,
                        onTap: () => onChanged(0)),
                    HidayahTab(
                        label: 'profile.playlists'.tr(),
                        count: playlists,
                        selected: index == 1,
                        onTap: () => onChanged(1)),
                    HidayahTab(
                        label: 'profile.archive_tab'.tr(),
                        count: recordings,
                        selected: index == 2,
                        onTap: () => onChanged(2)),
                  ])))));
}

/// About, organization tools and speakers beside the channel content.
class ProfileWebSidebar extends StatelessWidget {
  const ProfileWebSidebar(
      {super.key,
      required this.streamer,
      required this.selectedSpeakerId,
      required this.onSpeaker,
      this.onBranches,
      this.onJoin});
  final StreamerModel streamer;
  final String? selectedSpeakerId;
  final ValueChanged<String> onSpeaker;
  final VoidCallback? onBranches, onJoin;
  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final s = streamer;
    final tags = s.tags.where((t) => t.trim().isNotEmpty).toSet().toList();
    Widget box(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: HidayahCard(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HidayahText.display(18)),
                  const SizedBox(height: 12),
                  ...children,
                ])));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      box('web.about'.tr(), [
        if (s.getLocalizedBio(lang).isNotEmpty) ...[
          Text(s.getLocalizedBio(lang), style: HidayahText.body(14)),
          const SizedBox(height: 14),
        ],
        if (s.getLocalizedCity(lang).isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HidayahMeta(
                  icon: CaGlyph.pin,
                  text: s.getLocalizedCity(lang),
                  color: HidayahGold.s700)),
        if (s.getLocalizedVenue(lang).isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HidayahMeta(
                  icon: CaGlyph.home,
                  text: s.getLocalizedVenue(lang),
                  color: HidayahGold.s700)),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in tags) HidayahTag(t),
          ]),
        ],
        if (onBranches != null || onJoin != null) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (onBranches != null)
              HidayahButton(
                  label:
                      '${s.venues.length} ${'profile.campus_branches_btn'.tr()}',
                  icon: CaGlyph.map,
                  kind: HidayahButtonKind.ghost,
                  compact: true,
                  onPressed: onBranches),
            if (onJoin != null)
              HidayahButton(
                  label: 'design_ui.join_an_organization'.tr(),
                  icon: CaGlyph.users,
                  kind: HidayahButtonKind.ghost,
                  compact: true,
                  onPressed: onJoin),
          ]),
        ],
      ]),
      if (s.isOrganization && s.affiliatedSpeakers.isNotEmpty)
        box('profile.featured_channels'.tr(), [
          Text('profile.featured_channels_hint'.tr(),
              style: HidayahText.body(12.5, color: HidayahGold.s600)),
          const SizedBox(height: 10),
          for (final sp in s.affiliatedSpeakers)
            Material(
                color: sp.speakerId == selectedSpeakerId
                    ? HidayahGold.g100
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSpeaker(sp.speakerId),
                    child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: [
                          CaAvatar(
                              name: sp.getLocalizedName(lang),
                              url: sp.avatarUrl,
                              radius: 18),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(sp.getLocalizedName(lang),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: HidayahText.body(14,
                                        color: HidayahGold.s900,
                                        weight: FontWeight.w700,
                                        height: 1.3)),
                                Text(sp.getLocalizedRole(lang),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: HidayahText.body(12.5,
                                        color: HidayahGold.s600, height: 1.3)),
                              ])),
                          if (sp.speakerId == selectedSpeakerId)
                            const CaIcon(CaGlyph.check,
                                color: HidayahGold.g700, size: 18),
                        ])))),
        ]),
    ]);
  }
}
