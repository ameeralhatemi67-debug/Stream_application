import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/hidden_content_service.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../discovery/models/bookmark_entry.dart';
import '../../models/streamer_models.dart';
import '../../models/vod_models.dart';
import '../widgets/channel_content_item.dart';
import '../widgets/playlist_viewer_modal_sheet.dart';
import '../widgets/upcoming_schedule_tab.dart';
import '../widgets/vod_player_modal_sheet.dart';

/// The tabs of a channel page.
enum LanternChannelTab { upcoming, playlists, archive, about }

/// A channel id that is not in the catalog.
class LanternChannelUnavailable extends StatelessWidget
    implements LanternSkinWidget {
  const LanternChannelUnavailable({super.key});

  @override
  Widget build(BuildContext context) => LanternSurface(
      child: Builder(
          builder: (context) => _ChannelFrame(
              title: 'profile.channel_unavailable'.tr(),
              children: [
                const SizedBox(height: 24),
                LCard(
                    child: LEmptyState(
                        key: const ValueKey('lantern-channel-unavailable'),
                        icon: LGlyph.videooff,
                        title: 'profile.channel_unavailable'.tr(),
                        body: 'lantern.channel.unavailable_body'.tr(),
                        action: LButton(
                            label: 'lantern.channel.discover_others'.tr(),
                            onPressed: () => context.go('/feed')))),
              ])));
}

/// The channel page in Lantern and Arch (/profile/:id): a night cover band
/// with the lattice, the avatar over its lower edge, the name, place and
/// counts under it, the actions, then Upcoming, Playlists, Archive and
/// About. Every value and action comes from BroadcasterProfileScreen; the
/// view keeps only which tab is open.
class LanternChannelView extends StatefulWidget implements LanternSkinWidget {
  const LanternChannelView(
      {super.key,
      required this.streamer,
      required this.live,
      required this.uncertain,
      required this.following,
      required this.reminder,
      required this.remindersAvailable,
      required this.own,
      required this.recordings,
      required this.playlists,
      required this.archiveKnown,
      required this.recordingCount,
      required this.playlistCount,
      required this.selectedSpeakerId,
      required this.onSpeaker,
      required this.onWatch,
      required this.onFollow,
      required this.onReminder,
      this.onShare,
      this.onStudio,
      this.onSettings,
      this.onBranches,
      this.onJoin,
      this.onReport,
      this.initialTab = LanternChannelTab.archive});

  final StreamerModel streamer;

  /// Live and playable (online, a fresh catalog, a stream id).
  final bool live;

  /// Offline or a saved catalog: the live state is not known.
  final bool uncertain;
  final bool following, reminder, remindersAvailable, own;

  /// What the archive and playlist tabs show (after the speaker filter).
  final List<VodModel> recordings;
  final List<PlaylistModel> playlists;
  final bool archiveKnown;

  /// Null until the archive has loaded: shown as a dash, never 0.
  final int? recordingCount, playlistCount;
  final String? selectedSpeakerId;
  final ValueChanged<String> onSpeaker;
  final VoidCallback onWatch, onReminder;
  final Future<void> Function() onFollow;
  final VoidCallback? onShare, onStudio, onSettings, onBranches, onJoin;

  /// Report this channel to the platform's admins. Null on one's own.
  final VoidCallback? onReport;
  final LanternChannelTab initialTab;

  @override
  State<LanternChannelView> createState() => _LanternChannelViewState();
}

class _LanternChannelViewState extends State<LanternChannelView> {
  late LanternChannelTab _tab = widget.initialTab;

  Future<void> _follow() async {
    if (!widget.following) return widget.onFollow();
    final yes = await showLanternDialog<bool>(context,
        title: 'lantern.channel.unfollow_title'.tr(),
        body: (context) => Text('lantern.channel.unfollow_body'.tr(),
            style: Lantern.textStyle(14.5, color: context.lt.muted)),
        actions: (dialog) => [
              LButton(
                  key: const ValueKey('lantern-channel-keep-following'),
                  label: 'lantern.channel.keep_following'.tr(),
                  kind: LButtonKind.ghost,
                  onPressed: () => Navigator.pop(dialog, false)),
              LButton(
                  key: const ValueKey('lantern-channel-unfollow'),
                  label: 'lantern.channel.unfollow'.tr(),
                  kind: LButtonKind.danger,
                  onPressed: () => Navigator.pop(dialog, true)),
            ]);
    if (yes == true && mounted) await widget.onFollow();
  }

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final s = widget.streamer;
    final lang = context.locale.languageCode;
    final wide = context.lanternWide;
    final upcomingCount = context.select<AppProvider, int?>((p) {
      final rows = p.upcomingSchedulesFor(s.streamerId);
      if (rows == null) return null;
      final now = DateTime.now();
      return rows.where((r) => r.nextStartUtc(now) != null).length;
    });

    final tabs = _ChannelTabs(
        value: _tab,
        onChanged: (v) => setState(() => _tab = v),
        tabs: [
          (
            value: LanternChannelTab.upcoming,
            label: 'profile.upcoming_tab'.tr(),
            count: upcomingCount
          ),
          (
            value: LanternChannelTab.playlists,
            label: 'profile.playlists'.tr(),
            count: widget.archiveKnown ? widget.playlists.length : null
          ),
          (
            value: LanternChannelTab.archive,
            label: 'profile.archive_tab'.tr(),
            count: widget.archiveKnown ? widget.recordings.length : null
          ),
          (
            value: LanternChannelTab.about,
            label: 'web.about'.tr(),
            count: null
          ),
        ]);
    final body = KeyedSubtree(
        key: ValueKey('lantern-channel-tab-${_tab.name}'),
        child: switch (_tab) {
          LanternChannelTab.upcoming => UpcomingScheduleTab(streamer: s),
          LanternChannelTab.playlists => _playlists(context),
          LanternChannelTab.archive => _archive(context),
          LanternChannelTab.about => _about(context, lang),
        });
    final featured = s.isOrganization && s.affiliatedSpeakers.isNotEmpty
        ? _featured(context, lang)
        : null;

    final content = wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [tabs, const SizedBox(height: 22), body])),
            const SizedBox(width: 32),
            SizedBox(
                key: const ValueKey('lantern-channel-side'),
                width: 340,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _aboutPanel(context, lang, compact: true),
                      if (featured != null) ...[
                        const SizedBox(height: 16),
                        featured,
                      ],
                    ])),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (featured != null) ...[featured, const SizedBox(height: 18)],
            tabs,
            const SizedBox(height: 18),
            body,
          ]);

    return _ChannelFrame(
        title: s.getLocalizedName(lang),
        header: _header(context, lang),
        actions: _barActions(),
        children: [content]);
  }

  /// The owner's tools in the phone's page bar, at its end (the top left in
  /// Arabic): share, the broadcast studio as an icon, and Settings in the
  /// corner (owner notes 2026-11-12). The website layout keeps them in the
  /// header's row.
  List<Widget> _barActions() => [
        if (widget.onShare != null)
          LIconButton(
              key: const ValueKey('lantern-channel-share'),
              icon: LGlyph.share,
              label: 'profile.share_btn'.tr(),
              onPressed: widget.onShare),
        if (widget.onStudio != null)
          LIconButton(
              key: const ValueKey('lantern-channel-studio'),
              icon: LGlyph.video,
              label: 'organization_v1.studio'.tr(),
              onPressed: widget.onStudio),
        if (widget.onSettings != null)
          LIconButton(
              key: const ValueKey('lantern-channel-settings'),
              icon: LGlyph.settings,
              label: 'nav.settings'.tr(),
              onPressed: widget.onSettings),
      ];

  // ---------------------------------------------------------------- header

  Widget _header(BuildContext context, String lang) {
    final t = context.lt;
    final s = widget.streamer;
    final wide = context.lanternWide;
    final band = wide ? 200.0 : 150.0;
    final avatar = wide ? 112.0 : 88.0;
    final cover = resolveImageProviderOrNull(s.bannerUrl);

    Widget stat(int? n, String key) => Semantics(
        label: n == null
            ? '${key.plural(0)}: ${'lantern.channel.stat_unknown'.tr()}'
            : '$n ${key.plural(n)}',
        child: ExcludeSemantics(
            child: Text.rich(TextSpan(children: [
          TextSpan(
              text: n == null ? '—' : '$n',
              style: Lantern.textStyle(14,
                      color: t.fg, weight: FontWeight.w700, height: 1.4)
                  .copyWith(fontFeatures: Lantern.tabular)),
          TextSpan(
              text: ' ${key.plural(n ?? 0)}',
              style: Lantern.textStyle(14, color: t.muted, height: 1.4)),
        ]))));

    final place = [
      s.getLocalizedTitle(lang),
      s.getLocalizedCity(lang),
    ].where((x) => x.trim().isNotEmpty).join(' · ');
    final organization = s.getLocalizedOrganization(lang).trim();

    final identity = Column(
        key: const ValueKey('lantern-channel-identity'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (widget.live)
              LBadge(
                  (s.isAudioLive ? 'web.badge_audio' : 'web.badge_live').tr(),
                  kind: s.isAudioLive ? LBadgeKind.audio : LBadgeKind.live)
            else
              LBadge(
                  (widget.uncertain
                          ? 'offline_experience.status_unavailable'
                          : 'ds.status_offline')
                      .tr(),
                  kind: LBadgeKind.off),
            if (s.isOrganization)
              LTag('profile.org_badge'.tr(), tone: LTone.mod, icon: LGlyph.org),
            if (s.isVerified)
              LTag(
                  (s.isOrganization
                          ? 'profile.verified_organization'
                          : 'profile.verified_scholar')
                      .tr(),
                  tone: LTone.gold,
                  icon: LGlyph.verified),
          ]),
          const SizedBox(height: 8),
          Semantics(
              header: true,
              child: Text(s.getLocalizedName(lang),
                  style: Lantern.displayStyle(wide ? 30 : 24,
                      color: t.fg,
                      height: context.lanternArabic ? 1.45 : 1.25))),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(place,
                style: Lantern.textStyle(14.5, color: t.muted, height: 1.45)),
          ],
          if (organization.isNotEmpty && !s.isOrganization) ...[
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              LIcon(LGlyph.home, size: 15, color: t.goldInk),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(organization,
                      style: Lantern.textStyle(14,
                          color: t.goldInk,
                          weight: FontWeight.w600,
                          height: 1.4))),
            ]),
          ],
          const SizedBox(height: 8),
          Wrap(
              key: const ValueKey('lantern-channel-stats'),
              spacing: 18,
              runSpacing: 4,
              children: [
                stat(widget.recordingCount, 'web.stat_recordings'),
                stat(widget.playlistCount, 'web.stat_playlists'),
              ]),
        ]);

    final actions = Wrap(
        key: const ValueKey('lantern-channel-actions'),
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (widget.live)
            LButton(
                key: const ValueKey('lantern-channel-watch'),
                label: (s.isAudioLive ? 'live.listen_live' : 'feed.watch_live')
                    .tr(),
                icon: s.isAudioLive ? LGlyph.audio : LGlyph.live,
                onPressed: widget.onWatch)
          else if (widget.remindersAvailable)
            LButton(
                key: const ValueKey('lantern-channel-reminder'),
                label: (widget.reminder
                        ? 'profile.reminder_on'
                        : 'profile.reminder_btn')
                    .tr(),
                icon: widget.reminder ? LGlyph.check : LGlyph.bell,
                kind: widget.reminder
                    ? LButtonKind.secondary
                    : LButtonKind.primary,
                onPressed: widget.onReminder),
          LButton(
              key: const ValueKey('lantern-channel-follow'),
              label: (widget.following
                      ? 'profile.following_btn'
                      : 'profile.follow_btn')
                  .tr(),
              icon: widget.following ? LGlyph.check : LGlyph.plus,
              kind: widget.following ? LButtonKind.secondary : LButtonKind.tonal,
              onPressed: _follow),
          if (widget.live && widget.remindersAvailable)
            LIconButton(
                key: const ValueKey('lantern-channel-reminder'),
                icon: LGlyph.bell,
                on: widget.reminder,
                label: (widget.reminder
                        ? 'profile.reminder_on'
                        : 'profile.reminder_btn')
                    .tr(),
                onPressed: widget.onReminder),
          // On a phone these three sit in the page bar ([_barActions]).
          if (wide && widget.onShare != null)
            LIconButton(
                key: const ValueKey('lantern-channel-share'),
                icon: LGlyph.share,
                label: 'profile.share_btn'.tr(),
                onPressed: widget.onShare),
          if (wide && widget.onStudio != null)
            LButton(
                key: const ValueKey('lantern-channel-studio'),
                label: 'organization_v1.studio'.tr(),
                icon: LGlyph.video,
                kind: LButtonKind.dark,
                onPressed: widget.onStudio),
          if (wide && widget.onSettings != null)
            LIconButton(
                key: const ValueKey('lantern-channel-settings'),
                icon: LGlyph.settings,
                label: 'nav.settings'.tr(),
                onPressed: widget.onSettings),
          if (widget.onReport != null)
            LIconButton(
                key: const ValueKey('lantern-channel-report'),
                icon: LGlyph.flag,
                label: 'lantern.report.action_channel'.tr(),
                onPressed: widget.onReport),
          if (widget.onBranches != null)
            LButton(
                key: const ValueKey('lantern-channel-branches'),
                label:
                    '${s.venues.length} ${'profile.campus_branches_btn'.tr()}',
                icon: LGlyph.pin,
                kind: LButtonKind.secondary,
                onPressed: widget.onBranches),
        ]);

    final ring = widget.live
        ? (s.isAudioLive ? LRing.audio : LRing.live)
        : LRing.none;
    final face = DecoratedBox(
        decoration: BoxDecoration(
            color: t.bg,
            shape: s.isOrganization ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: s.isOrganization
                ? BorderRadius.circular((avatar + 18) * .3)
                : null),
        child: Padding(
            padding: const EdgeInsets.all(5),
            child: LAvatar(
                key: const ValueKey('lantern-channel-avatar'),
                name: s.getLocalizedName(lang),
                image: resolveImageProviderOrNull(s.avatarUrl),
                size: avatar,
                ring: ring,
                org: s.isOrganization,
                verified: s.isVerified)));

    final g = wide ? Lantern.webGutter : Lantern.gutter;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Stack(clipBehavior: Clip.none, children: [
        SizedBox(
            key: const ValueKey('lantern-channel-cover'),
            height: band,
            child: LNightBand(
                latticeOpacity: .16,
                latticeStep: 30,
                child: cover == null
                    ? const SizedBox.expand()
                    : Opacity(
                        opacity: .5,
                        child: SizedBox.expand(
                            child: Image(
                                image: cover,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink()))))),
        Positioned.fill(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: Lantern.webContent + 2 * Lantern.webGutter),
                    child: Stack(clipBehavior: Clip.none, children: [
                      PositionedDirectional(
                          start: g, bottom: -(avatar / 2 + 5), child: face),
                    ])))),
      ]),
      Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: Lantern.webContent + 2 * Lantern.webGutter),
              child: Padding(
                  padding: EdgeInsets.fromLTRB(g, avatar / 2 + 18, g, 0),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Expanded(child: identity),
                              const SizedBox(width: 24),
                              Flexible(child: actions),
                            ])
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              identity,
                              const SizedBox(height: 16),
                              actions,
                            ])))),
    ]);
  }

  // ------------------------------------------------------------------ tabs

  int _columns(BuildContext context, double width) {
    if (context.lanternWide) return 3;
    return width >= 560 ? 2 : 1;
  }

  Widget _grid(List<Widget> cards) => LayoutBuilder(builder: (context, c) {
        final columns = _columns(context, c.maxWidth);
        final gap = context.lanternWide ? 20.0 : 14.0;
        final w = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final card in cards) SizedBox(width: w, child: card),
        ]);
      });

  Widget _loading() => LayoutBuilder(
      builder: (context, c) => _grid([
            for (var i = 0; i < math.max(2, _columns(context, c.maxWidth)); i++)
              const LSkeleton(height: 190, radius: Lantern.radiusCard),
          ]));

  Widget _archive(BuildContext context) {
    final vods = widget.recordings;
    if (vods.isEmpty && !widget.archiveKnown) {
      return KeyedSubtree(
          key: const ValueKey('lantern-channel-loading'), child: _loading());
    }
    if (vods.isEmpty) {
      return LCard(
          child: LEmptyState(
              key: const ValueKey('lantern-channel-no-recordings'),
              icon: LGlyph.video,
              title: 'profile.no_instructor_vods'.tr()));
    }
    final lang = context.locale.languageCode;
    return _grid([
      for (final vod in vods)
        vod.youtubeVideoId.isEmpty
            ? _RecordingCard(vod: vod, streamer: widget.streamer)
            : ChannelContentItem(
                streamerId: widget.streamer.streamerId,
                kind: HiddenContentKind.video,
                itemId: vod.youtubeVideoId,
                title: vod.getLocalizedTitle(lang),
                shareText:
                    '${vod.getLocalizedTitle(lang)}\nhttps://www.youtube.com/watch?v=${vod.youtubeVideoId}',
                child: _RecordingCard(vod: vod, streamer: widget.streamer)),
    ]);
  }

  Widget _playlists(BuildContext context) {
    final lists = widget.playlists;
    if (lists.isEmpty && !widget.archiveKnown) {
      return KeyedSubtree(
          key: const ValueKey('lantern-channel-loading'), child: _loading());
    }
    if (lists.isEmpty) {
      return LCard(
          child: LEmptyState(
              key: const ValueKey('lantern-channel-no-playlists'),
              icon: LGlyph.list,
              title: 'profile.no_videos_playlist'.tr()));
    }
    final lang = context.locale.languageCode;
    return _grid([
      for (final (i, p) in lists.indexed)
        ChannelContentItem(
            streamerId: widget.streamer.streamerId,
            kind: HiddenContentKind.playlist,
            itemId: p.playlistId,
            title: p.getLocalizedTitle(lang),
            shareText:
                '${p.getLocalizedTitle(lang)}\n${p.youtubePlaylistUrl.isNotEmpty ? p.youtubePlaylistUrl : 'https://www.youtube.com/playlist?list=${p.playlistId}'}',
            child: _PlaylistCard(
                playlist: p, streamer: widget.streamer, tone: i % 5)),
    ]);
  }

  /// City, venue, affiliation and subjects; [compact] is the side panel of
  /// the website layout, without the biography.
  Widget _aboutPanel(BuildContext context, String lang,
      {bool compact = false}) {
    final t = context.lt;
    final s = widget.streamer;
    final bio = s.getLocalizedBio(lang).trim();
    final rows = <(String, String)>[
      if (s.getLocalizedCity(lang).trim().isNotEmpty)
        ('profile.city'.tr(), s.getLocalizedCity(lang)),
      if (s.getLocalizedVenue(lang).trim().isNotEmpty)
        ('lantern.channel.venue'.tr(), s.getLocalizedVenue(lang)),
      if (s.getLocalizedOrganization(lang).trim().isNotEmpty &&
          !s.isOrganization)
        ('lantern.channel.affiliation'.tr(), s.getLocalizedOrganization(lang)),
    ];
    final tags = s.tags.where((x) => x.trim().isNotEmpty).toSet().toList();
    final empty = rows.isEmpty &&
        tags.isEmpty &&
        (compact || bio.isEmpty) &&
        widget.onBranches == null &&
        widget.onJoin == null;
    return LCard(
        key: ValueKey(compact ? 'lantern-channel-about-side' : 'lantern-channel-about'),
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                  header: true,
                  child: Text('web.about'.tr(),
                      style: Lantern.displayStyle(17,
                          color: t.fg,
                          height: context.lanternArabic ? 1.45 : 1.25))),
              const SizedBox(height: 12),
              if (empty)
                Text('lantern.channel.no_about'.tr(),
                    style: Lantern.textStyle(14, color: t.muted)),
              if (!compact && bio.isNotEmpty) ...[
                Text(bio,
                    style: Lantern.textStyle(15, color: t.fg, height: 1.75)),
                const SizedBox(height: 14),
              ],
              for (final (i, (k, v)) in rows.indexed)
                Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                        border: i == rows.length - 1 && tags.isEmpty
                            ? null
                            : Border(bottom: BorderSide(color: t.line2))),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k,
                              style: Lantern.textStyle(14,
                                  color: t.muted, height: 1.4)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(v,
                                  textAlign: TextAlign.end,
                                  style: Lantern.textStyle(14,
                                      color: t.fg,
                                      weight: FontWeight.w600,
                                      height: 1.4))),
                        ])),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('lantern.channel.subjects'.tr(),
                    style: Lantern.textStyle(13,
                        color: t.muted, weight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final tag in tags) LTag(tag, tone: LTone.gold),
                ]),
              ],
              if (widget.onBranches != null || widget.onJoin != null) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (widget.onBranches != null && !compact)
                    LButton(
                        label:
                            '${s.venues.length} ${'profile.campus_branches_btn'.tr()}',
                        icon: LGlyph.map,
                        kind: LButtonKind.secondary,
                        size: LButtonSize.small,
                        onPressed: widget.onBranches),
                  if (widget.onJoin != null)
                    LButton(
                        key: ValueKey(compact
                            ? 'lantern-channel-join-side'
                            : 'lantern-channel-join'),
                        label: 'design_ui.join_an_organization'.tr(),
                        icon: LGlyph.org,
                        kind: LButtonKind.secondary,
                        size: LButtonSize.small,
                        onPressed: widget.onJoin),
                ]),
              ],
            ]));
  }

  Widget _about(BuildContext context, String lang) =>
      _aboutPanel(context, lang);

  /// The organization's speakers: a tap shows only that speaker's lectures
  /// and playlists, as in the older designs.
  Widget _featured(BuildContext context, String lang) {
    final t = context.lt;
    final s = widget.streamer;
    return LCard(
        key: const ValueKey('lantern-channel-featured'),
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                  header: true,
                  child: Text('profile.featured_channels'.tr(),
                      style: Lantern.displayStyle(17,
                          color: t.fg,
                          height: context.lanternArabic ? 1.45 : 1.25))),
              const SizedBox(height: 4),
              Text('profile.featured_channels_hint'.tr(),
                  style: Lantern.textStyle(13, color: t.muted)),
              const SizedBox(height: 12),
              for (final sp in s.affiliatedSpeakers)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                        selected: sp.speakerId == widget.selectedSpeakerId,
                        label: (sp.speakerId == widget.selectedSpeakerId
                                ? 'lantern.channel.speaker_filter_on'
                                : 'lantern.channel.speaker_filter')
                            .tr(args: [sp.getLocalizedName(lang)]),
                        child: LRow(
                            key: ValueKey(
                                'lantern-channel-speaker-${sp.speakerId}'),
                            title: sp.getLocalizedName(lang),
                            subtitle: sp.getLocalizedRole(lang).trim().isEmpty
                                ? null
                                : sp.getLocalizedRole(lang),
                            leading: LAvatar(
                                name: sp.getLocalizedName(lang),
                                image: resolveImageProviderOrNull(sp.avatarUrl),
                                size: 40),
                            trailing: sp.speakerId == widget.selectedSpeakerId
                                ? LTag('profile.filter_active_badge'.tr(),
                                    tone: LTone.gold, icon: LGlyph.check)
                                : null,
                            onTap: () {
                              widget.onSpeaker(sp.speakerId);
                              setState(() => _tab = LanternChannelTab.archive);
                            }))),
            ]));
  }
}

/// The page frame: the page bar on a phone; the website header and footer
/// on the website layout. One scroll for the whole page.
class _ChannelFrame extends StatelessWidget implements LanternSkinWidget {
  const _ChannelFrame(
      {required this.title,
      required this.children,
      this.header,
      this.actions = const []});

  final String title;
  final Widget? header;
  final List<Widget> children;

  /// The phone page bar's buttons, at its end.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    final g = wide ? Lantern.webGutter : Lantern.gutter;
    final scroll = SingleChildScrollView(
        key: const ValueKey('lantern-channel-scroll'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (header != null) header!,
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: Lantern.webContent + 2 * Lantern.webGutter),
                  child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          g,
                          wide ? 32 : 24,
                          g,
                          wide ? 56 : 28 + MediaQuery.paddingOf(context).bottom),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children)))),
          if (wide) const LanternWebFooter(),
        ]));
    if (wide) {
      return Scaffold(
          key: const ValueKey('lantern-channel'),
          backgroundColor: t.bg,
          body: SafeArea(
              child: Column(children: [
            const LanternWebHeader(),
            Expanded(child: scroll),
          ])));
    }
    return Scaffold(
        key: const ValueKey('lantern-channel'),
        backgroundColor: t.bg,
        appBar: LanternPageBar(title: title, actions: actions),
        body: scroll);
  }
}

/// Tabs with the gold underline and their counts; a count that is not
/// known yet is left out.
class _ChannelTabs extends StatelessWidget implements LanternSkinWidget {
  const _ChannelTabs(
      {required this.tabs, required this.value, required this.onChanged});

  final List<({LanternChannelTab value, String label, int? count})> tabs;
  final LanternChannelTab value;
  final ValueChanged<LanternChannelTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final calm = Lantern.calm(context);
    return DecoratedBox(
        key: const ValueKey('lantern-channel-tabs'),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final tab in tabs)
                LPressable(
                    key: ValueKey('lantern-channel-tab-button-${tab.value.name}'),
                    onTap: () => onChanged(tab.value),
                    label: tab.count == null
                        ? tab.label
                        : '${tab.label}, ${tab.count}',
                    selected: tab.value == value,
                    radius: 10,
                    pressScale: 1,
                    excludeChildSemantics: true,
                    builder: (context, s) {
                      final on = tab.value == value;
                      return SizedBox(
                          height: 48,
                          child: Stack(alignment: Alignment.center, children: [
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(tab.label,
                                      style: Lantern.textStyle(14.5,
                                          color: on || s.hovered ? t.fg : t.muted,
                                          weight: FontWeight.w600,
                                          height: 1.2)),
                                  if (tab.count != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: t.sunk,
                                            borderRadius: BorderRadius.circular(
                                                Lantern.radiusPill)),
                                        child: Text('${tab.count}',
                                            style: Lantern.textStyle(11.5,
                                                    color: t.goldInk,
                                                    weight: FontWeight.w600,
                                                    height: 1.3)
                                                .copyWith(
                                                    fontFeatures:
                                                        Lantern.tabular))),
                                  ],
                                ])),
                            PositionedDirectional(
                                start: 12,
                                end: 12,
                                bottom: 0,
                                child: AnimatedScale(
                                    scale: on ? 1 : 0,
                                    duration: calm
                                        ? Lantern.none
                                        : const Duration(milliseconds: 300),
                                    curve: Lantern.ease,
                                    child: Container(
                                        height: 3,
                                        decoration: const BoxDecoration(
                                            color: LanternTokens.gold,
                                            borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(3)))))),
                          ]));
                    }),
            ])));
  }
}

/// A recording: its picture, length, title and date. A tap opens the same
/// player sheet as the older designs.
class _RecordingCard extends StatelessWidget implements LanternSkinWidget {
  const _RecordingCard({required this.vod, required this.streamer});

  final VodModel vod;
  final StreamerModel streamer;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final title = vod.getLocalizedTitle(lang);
    final saved = context.select<AppProvider, bool>(
        (p) => p.isBookmarked(BookmarkEntry.recording(vod).id));
    final thumb = resolveImageProviderOrNull(
        vod.thumbnailUrl.startsWith('http') ||
                vod.thumbnailUrl.startsWith('assets/')
            ? vod.thumbnailUrl
            : vod.youtubeVideoId.isEmpty
                ? null
                : 'https://img.youtube.com/vi/${vod.youtubeVideoId}/hqdefault.jpg');
    return LCard(
        key: ValueKey('lantern-channel-recording-${vod.vodId}'),
        padding: EdgeInsets.zero,
        label: 'lantern.channel.open_recording'.tr(args: [title]),
        onTap: () =>
            VodPlayerModalSheet.show(context, vod: vod, streamer: streamer),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    const ColoredBox(color: LanternTokens.nightGround),
                    if (thumb != null)
                      Image(
                          image: thumb,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [.45, 1],
                                colors: [
                          LanternTokens.nightGround.withValues(alpha: 0),
                          LanternTokens.nightGround.withValues(alpha: .55)
                        ]))),
                    Center(
                        child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: LanternTokens.nightGround
                                    .withValues(alpha: .55),
                                shape: BoxShape.circle),
                            child: const LIcon(LGlyph.playfill,
                                size: 22, color: LanternTokens.white))),
                    if (saved)
                      PositionedDirectional(
                          top: 10,
                          start: 10,
                          child: LBadge('lantern.channel.saved'.tr(),
                              kind: LBadgeKind.glass,
                              icon: LGlyph.bookmarkfill,
                              small: true)),
                    if (vod.durationSeconds > 0)
                      PositionedDirectional(
                          bottom: 10,
                          end: 10,
                          child: LBadge(vod.formattedDuration,
                              kind: LBadgeKind.glass, small: true)),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            height: 15 * 1.35 * 2,
                            child: Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Lantern.textStyle(15,
                                    color: t.fg,
                                    weight: FontWeight.w600,
                                    height: 1.35))),
                        const SizedBox(height: 4),
                        Text(
                            [
                              if (vod.recordedDate.trim().isNotEmpty)
                                vod.recordedDate,
                              '${vod.viewCount} ${'profile.views'.tr()}',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Lantern.textStyle(12.5,
                                color: t.muted, height: 1.4)),
                      ])),
            ]));
  }
}

/// A playlist: its picture with the number of videos, and its title. A tap
/// opens the same playlist sheet as the older designs.
class _PlaylistCard extends StatelessWidget implements LanternSkinWidget {
  const _PlaylistCard(
      {required this.playlist, required this.streamer, required this.tone});

  final PlaylistModel playlist;
  final StreamerModel streamer;
  final int tone;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final title = playlist.getLocalizedTitle(lang);
    final thumb = resolveImageProviderOrNull(playlist.thumbnailUrl);
    final colors = LAvatar.tones[tone];
    return LCard(
        key: ValueKey('lantern-channel-playlist-${playlist.playlistId}'),
        padding: EdgeInsets.zero,
        label: 'lantern.channel.open_playlist'.tr(args: [title]),
        onTap: () => PlaylistViewerModalSheet.show(context,
            playlist: playlist, streamer: streamer, langCode: lang),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: AlignmentDirectional.topStart,
                                end: AlignmentDirectional.bottomEnd,
                                colors: colors))),
                    const LLattice(
                        color: LanternTokens.goldHi, opacity: .15, step: 20),
                    if (thumb != null)
                      Image(
                          image: thumb,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FractionallySizedBox(
                            widthFactor: .38,
                            heightFactor: 1,
                            child: ColoredBox(
                                color: LanternTokens.nightGround
                                    .withValues(alpha: .62),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('${playlist.videoCount}',
                                          style: Lantern.displayStyle(22,
                                                  color: LanternTokens.white,
                                                  height: 1)
                                              .copyWith(
                                                  fontFeatures:
                                                      Lantern.tabular)),
                                      const SizedBox(height: 6),
                                      const LIcon(LGlyph.list,
                                          size: 20,
                                          color: LanternTokens.white),
                                    ])))),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            height: 15 * 1.35 * 2,
                            child: Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Lantern.textStyle(15,
                                    color: t.fg,
                                    weight: FontWeight.w600,
                                    height: 1.35))),
                        const SizedBox(height: 4),
                        Text(
                            'profile.lectures_count'
                                .plural(playlist.videoCount),
                            style: Lantern.textStyle(12.5,
                                color: t.muted, height: 1.4)),
                      ])),
            ]));
  }
}
