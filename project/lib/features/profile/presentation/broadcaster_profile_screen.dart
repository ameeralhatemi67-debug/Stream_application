import '../../../core/widgets/ds/canopy_content_motion.dart';
import '../../../core/widgets/ds/ca_feedback.dart';
import '../../live_stream/models/broadcast_session.dart';
import '../../../core/widgets/ds/ca_navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/widgets/ds/ca_layout.dart';
import '../../../core/widgets/ds/ca_cards.dart';
import '../../../core/widgets/ds/ca_fixed_lines.dart';
import '../../../core/widgets/ds/ca_button.dart';
import '../../../core/widgets/ds/ca_fields.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_surfaces.dart';
import '../../../core/widgets/ds/canopy_lattice_background.dart';
import '../../../core/theme/app_theme.dart';
import '../../live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import '../models/streamer_models.dart';
import '../models/vod_models.dart';
import 'widgets/vod_grid_tile.dart';
import 'widgets/org_branches_modal_sheet.dart';
import 'widgets/join_org_modal_sheet.dart';
import 'widgets/playlist_viewer_modal_sheet.dart';
import 'widgets/upcoming_schedule_tab.dart';
import '../../../core/services/reminder_push_service.dart';

class BroadcasterProfileScreen extends StatefulWidget {
  final String streamerId;
  final int initialTab;

  const BroadcasterProfileScreen(
      {super.key, required this.streamerId, this.initialTab = 0});

  @override
  State<BroadcasterProfileScreen> createState() =>
      _BroadcasterProfileScreenState();
}

class _BroadcasterProfileScreenState extends State<BroadcasterProfileScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String? _selectedSpeakerId;
  bool _detailsExpanded = false;

  /// The banner on the profile card, and the avatar that straddles its edge:
  /// the avatar plus its white stroke on each side.
  static const _bannerHeight = 132.0;

  /// How far the card rises over the green panel: about 18% of the card.
  static const _headerOverlap = 56.0;
  static const _avatarStroke = 4.0;
  static const _avatarBox =
      CanopySize.profileAvatar * 2 + AppTheme.spaceXs + _avatarStroke * 2;
  bool get _dockPrimary =>
      context.usesPillNav &&
      (MediaQuery.textScalerOf(context).scale(1) >= 1.3 || context.isShort);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final streamer = appProvider.getStreamerById(widget.streamerId);
      if (streamer == null) return;
      final handle = streamer.youtubeHandle;
      appProvider.loadYouTubeChannelData(
        streamerId: widget.streamerId,
        handle: handle,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    const expectedTabs = 3;
    if (_tabController == null || _tabController!.length != expectedTabs) {
      _tabController?.dispose();
      _tabController = TabController(
          length: expectedTabs, vsync: this, initialIndex: widget.initialTab);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    context
        .select<AppProvider, (bool, bool, bool, bool, bool, String?)>((p) => (
              p.isOnline,
              p.isUsingCachedCatalog,
              p.isLoggedInStreamer,
              p.isApprovedStreamer,
              p.isStreamerModeEnabled,
              p.currentUserStreamerId
            ));
    context.select<AppProvider, List<BroadcastSession>>(
        (p) => p.broadcastSessions);
    final lang = context.locale.languageCode;

    // Missing channels have an explicit unavailable state.
    final streamer = context.select<AppProvider, StreamerModel?>(
        (p) => p.getStreamerById(widget.streamerId));
    if (streamer == null) {
      return Scaffold(
        appBar: CaAppBar(),
        body: Center(child: Text('profile.channel_unavailable'.tr())),
      );
    }

    final isFollowing = context
        .select<AppProvider, bool>((p) => p.isFollowing(streamer.streamerId));
    final watchLive = !appProvider.isUsingCachedCatalog &&
        appProvider.isOnline &&
        streamer.isCurrentlyLive &&
        streamer.activeStreamId != null;
    final hasReminder = context
        .select<AppProvider, bool>((p) => p.hasReminder(streamer.streamerId));

    // Only recordings loaded for this channel are shown.
    final allVods = context.select<AppProvider, List<VodModel>>(
        (p) => p.getVodsForStreamer(streamer.streamerId));
    final activePlaylists = context.select<AppProvider, List<PlaylistModel>>(
        (p) => p.getPlaylistsForStreamer(streamer.streamerId));

    // Apply speaker filtering if an individual instructor is selected
    final displayedVods =
        (_selectedSpeakerId != null && _selectedSpeakerId != 'all')
            ? allVods
                .where((v) => v.speakerIds.contains(_selectedSpeakerId))
                .toList()
            : allVods;

    final displayedPlaylists =
        (_selectedSpeakerId != null && _selectedSpeakerId != 'all')
            ? activePlaylists
                .where((p) => p.speakerIds.contains(_selectedSpeakerId))
                .toList()
            : activePlaylists;

    final header = _buildHeaderCard(context, streamer, isFollowing, hasReminder,
        lang, appProvider, allVods, activePlaylists);
    Widget tabs() => AnimatedBuilder(
        animation: _tabController!,
        builder: (context, _) => Padding(
            padding: const EdgeInsets.all(AppTheme.spaceSm),
            child: CaSegmentedTabs(
                labels: [
                  'profile.upcoming_tab'.tr(),
                  'profile.playlists'.tr(),
                  'profile.archive_tab'.tr()
                ],
                index: 2 - _tabController!.index,
                onChanged: (visual) => _tabController!.animateTo(2 - visual))));
    Widget body() => TabBarView(controller: _tabController, children: [
          _buildVodArchiveGrid(displayedVods, streamer),
          _buildPlaylistsGrid(displayedPlaylists, streamer, lang),
          UpcomingScheduleTab(streamer: streamer),
        ]);
    Widget panel(Widget child) => DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.panel),
        child: child);
    final single = NestedScrollView(
        headerSliverBuilder: (context, scrolled) => [
              SliverToBoxAdapter(child: header),
              SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                      tabs(),
                      CaSegmentedTabs.heightFor(
                              context,
                              [
                                'profile.upcoming_tab'.tr(),
                                'profile.playlists'.tr(),
                                'profile.archive_tab'.tr()
                              ],
                              MediaQuery.sizeOf(context).width -
                                  AppTheme.spaceLg) +
                          AppTheme.spaceSm +
                          AppTheme.spaceLg)),
            ],
        body: panel(body()));
    return Scaffold(
        backgroundColor: Canopy.dawn,
        bottomNavigationBar: _dockPrimary
            ? SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        AppTheme.spaceLg,
                        AppTheme.spaceSm,
                        AppTheme.spaceLg,
                        AppTheme.spaceSm),
                    child: CaButton(
                        icon: isFollowing && !watchLive ? CaGlyph.check : null,
                        confirm: isFollowing && !watchLive,
                        label: (!appProvider.isUsingCachedCatalog &&
                                    appProvider.isOnline &&
                                    streamer.isCurrentlyLive &&
                                    streamer.activeStreamId != null
                                ? (streamer.isAudioLive
                                    ? 'live.listen_live'
                                    : 'feed.watch_live')
                                : (isFollowing
                                    ? 'profile.following_btn'
                                    : 'profile.follow_btn'))
                            .tr(),
                        onPressed: () => !appProvider.isUsingCachedCatalog &&
                                appProvider.isOnline &&
                                streamer.isCurrentlyLive &&
                                streamer.activeStreamId != null
                            ? context.push('/live/${streamer.activeStreamId}')
                            : appProvider.toggleFollow(streamer.streamerId))))
            : null,
        body: SafeArea(
            bottom: false,
            child: CaPane(
                single: single,
                secondaryAtStart: true,
                secondaryWidth: CanopySize.profilePane,
                largeSecondaryWidth: CanopySize.profilePaneLarge,
                secondary: SingleChildScrollView(child: header),
                primary: panel(Column(children: [tabs(), Expanded(child: body())])))));
  }

  Widget _buildHeaderCard(
      BuildContext context,
      StreamerModel streamer,
      bool following,
      bool reminder,
      String lang,
      AppProvider provider,
      List<VodModel> vods,
      List<PlaylistModel> playlists) {
    final uncertain = !provider.isOnline || provider.isUsingCachedCatalog;
    final live = !uncertain &&
        streamer.isCurrentlyLive &&
        streamer.activeStreamId != null;
    final own = provider.isLoggedInStreamer &&
        provider.isApprovedStreamer &&
        provider.isStreamerModeEnabled &&
        provider.isOwnStreamerProfile(streamer.streamerId);
    final canJoin = !streamer.isOrganization &&
        provider.isLoggedInStreamer &&
        provider.isOwnStreamerProfile(streamer.streamerId);
    final watchAction = CaButton(
        label: (streamer.isAudioLive ? 'live.listen_live' : 'feed.watch_live')
            .tr(),
        icon: streamer.isAudioLive ? CaGlyph.mic : CaGlyph.play,
        onPressed: () => context.push('/live/${streamer.activeStreamId}'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Stack(fit: StackFit.passthrough, children: [
        SizedBox(
            height: CanopySize.profileHeader,
            child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(CanopyRadius.hero)),
                child: CanopyLatticeBackground(
                    child: SizedBox.expand(
                        child: ColoredBox(
                            color: CanopyGradients.entryTextScrim,
                            child: Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    AppTheme.spaceSm,
                                    AppTheme.spaceXs,
                                    AppTheme.spaceSm,
                                    0),
                                child: Align(
                                    alignment: Alignment.topCenter,
                                    // A fixed 48 px row: the compact language control is a Center that
                                    // would otherwise stretch to the whole panel and carry the icons to
                                    // its middle.
                                    child: SizedBox(
                                        height: CanopySize.target,
                                        child: Row(children: [
                                          CaIconButton(
                                              bare: true,
                                              icon: CaGlyph.back,
                                              label: MaterialLocalizations.of(
                                                      context)
                                                  .backButtonTooltip,
                                              glass: true,
                                              onPressed: () => context.canPop()
                                                  ? context.pop()
                                                  : context.go('/feed')),
                                          const Spacer(),
                                          const CaLanguageChip(
                                              glass: true,
                                              compact: true,
                                              bare: true),
                                          if (own)
                                            CaIconButton(
                                                bare: true,
                                                icon: CaGlyph.video,
                                                label:
                                                    'live.rtmp_ip_tooltip'.tr(),
                                                glass: true,
                                                onPressed: () =>
                                                    LiveBroadcasterStudioSheet
                                                        .show(context)),
                                          if (streamer.youtubeHandle
                                              .trim()
                                              .isNotEmpty)
                                            CaIconButton(
                                                bare: true,
                                                icon: CaGlyph.share,
                                                label: 'profile.share_btn'.tr(),
                                                glass: true,
                                                onPressed: () => _shareChannel(
                                                    streamer, lang)),
                                        ]))))))))),
        // The card rises over the green panel, so the panel keeps its height and
        // everything below the card moves up with it.
        Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                AppTheme.spaceLg,
                CanopySize.profileHeader - _headerOverlap,
                AppTheme.spaceLg,
                AppTheme.spaceLg),
            child: CaCard(
                padding: EdgeInsets.zero,
                child: Stack(clipBehavior: Clip.none, children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            height: _bannerHeight,
                            width: double.infinity,
                            child: Stack(fit: StackFit.expand, children: [
                              CaCardImage(url: streamer.bannerUrl),
                              PositionedDirectional(
                                  top: AppTheme.spaceSm,
                                  end: AppTheme.spaceSm,
                                  child: CaStatusChip(
                                      key: const ValueKey(
                                          'profile-header-status'),
                                      kind: live
                                          ? (streamer.isAudioLive
                                              ? CaStatusKind.audio
                                              : CaStatusKind.live)
                                          : CaStatusKind.offline,
                                      label: uncertain
                                          ? 'offline_experience.status_unavailable'
                                              .tr()
                                          : null)),
                            ])),
                        Padding(
                            padding: const EdgeInsets.all(AppTheme.spaceLg),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // The avatar straddles the banner's lower edge; the
                                  // name sits beside its lower half.
                                  ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          minHeight: _avatarBox / 2),
                                      child: Padding(
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                  start: _avatarBox +
                                                      AppTheme.spaceMd),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    streamer
                                                        .getLocalizedName(lang),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleLarge),
                                                Text(
                                                    streamer.getLocalizedTitle(
                                                        lang),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall),
                                              ]))),
                                  const SizedBox(height: AppTheme.spaceMd),
                                  Text(streamer.getLocalizedOrganization(lang),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Canopy.brandGreen)),
                                  LayoutBuilder(
                                      builder: (context, constraints) {
                                    final bioStyle =
                                        Theme.of(context).textTheme.bodyMedium;
                                    final measure = TextPainter(
                                      text: TextSpan(
                                          text: streamer.getLocalizedBio(lang),
                                          style: bioStyle),
                                      textDirection: Directionality.of(context),
                                      textScaler:
                                          MediaQuery.textScalerOf(context),
                                      maxLines: 2,
                                    )..layout(maxWidth: constraints.maxWidth);
                                    final hasMore = measure.didExceedMaxLines ||
                                        (streamer.isOrganization &&
                                            streamer.venues.isNotEmpty) ||
                                        canJoin;
                                    measure.dispose();
                                    return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(streamer.getLocalizedBio(lang),
                                              maxLines:
                                                  _detailsExpanded ? null : 2,
                                              overflow: _detailsExpanded
                                                  ? null
                                                  : TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium),
                                          if (hasMore)
                                            IconButton(
                                                key: const ValueKey(
                                                    'profile-details-toggle'),
                                                tooltip: (_detailsExpanded
                                                        ? 'profile.show_less'
                                                        : 'profile.show_more')
                                                    .tr(),
                                                color: Canopy.brandGreen,
                                                icon: Icon(_detailsExpanded
                                                    ? Icons
                                                        .keyboard_arrow_up_rounded
                                                    : Icons
                                                        .keyboard_arrow_down_rounded),
                                                onPressed: () => setState(() =>
                                                    _detailsExpanded =
                                                        !_detailsExpanded)),
                                        ]);
                                  }),
                                  if (_detailsExpanded)
                                    Wrap(spacing: AppTheme.spaceSm, children: [
                                      if (streamer.isOrganization &&
                                          streamer.venues.isNotEmpty)
                                        CaButton(
                                            label:
                                                '${streamer.venues.length} ${'profile.campus_branches_btn'.tr()}',
                                            variant: CaButtonVariant.text,
                                            onPressed: () =>
                                                OrgBranchesModalSheet.show(
                                                    context,
                                                    orgName: streamer
                                                        .getLocalizedName(lang),
                                                    venues: streamer.venues)),
                                      if (canJoin)
                                        CaButton(
                                            label:
                                                'design_ui.join_an_organization'
                                                    .tr(),
                                            variant: CaButtonVariant.text,
                                            onPressed: () =>
                                                JoinOrgModalSheet.show(
                                                    context)),
                                    ]),
                                  if (live && !_dockPrimary) ...[
                                    if (context.windowClass ==
                                        WindowClass.compact)
                                      LayoutBuilder(
                                          builder: (context, constraints) =>
                                              SizedBox(
                                                  width: constraints.maxWidth -
                                                      CanopySize.target -
                                                      AppTheme.spaceSm,
                                                  child: watchAction))
                                    else
                                      watchAction,
                                    const SizedBox(height: AppTheme.spaceSm)
                                  ],
                                  Row(children: [
                                    if (!_dockPrimary || live)
                                      Expanded(
                                          child: CanopyConfirmMotion(
                                              active: following,
                                              child: CaButton(
                                                  icon: following
                                                      ? CaGlyph.check
                                                      : null,
                                                  confirm: following,
                                                  label: (following
                                                          ? 'profile.following_btn'
                                                          : 'profile.follow_btn')
                                                      .tr(),
                                                  variant: live || following
                                                      ? CaButtonVariant
                                                          .secondary
                                                      : CaButtonVariant.primary,
                                                  onPressed: () => provider
                                                      .toggleFollow(streamer
                                                          .streamerId)))),
                                    const SizedBox(width: AppTheme.spaceSm),
                                    CanopyConfirmMotion(
                                        active: reminder,
                                        wiggle: true,
                                        child: CaIconButton(
                                            bare: true,
                                            icon: CaGlyph.bell,
                                            label: (reminder
                                                    ? 'profile.reminder_on'
                                                    : 'profile.reminder_btn')
                                                .tr(),
                                            onPressed: () =>
                                                _toggleChannelReminder(context,
                                                    streamer.streamerId)))
                                  ]),
                                  ...provider.broadcastSessions
                                      .where((s) =>
                                          !s.hidden &&
                                          (s.organizationId ?? s.presenterId) ==
                                              streamer.streamerId &&
                                          (s.live ||
                                              s.replayStatus == 'available'))
                                      .map((s) => ListTile(
                                          title: Text(s.title(lang)),
                                          subtitle: Text(
                                              'organization_v1.state_${s.state}'
                                                  .tr()),
                                          trailing: const CaIcon(CaGlyph.play),
                                          onTap: () =>
                                              context.push('/live/${s.id}'))),
                                ])),
                      ]),
                  PositionedDirectional(
                      top: _bannerHeight - _avatarBox / 2,
                      start: AppTheme.spaceLg,
                      child: _AvatarStroke(
                          org: streamer.isOrganization,
                          child: CaAvatar(
                              name: streamer.getLocalizedName(lang),
                              url: streamer.avatarUrl,
                              verified: streamer.isVerified,
                              org: streamer.isOrganization,
                              radius: CanopySize.profileAvatar))),
                ]))),
      ]),
      if (streamer.isOrganization && streamer.affiliatedSpeakers.isNotEmpty)
        Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: _buildFeaturedChannelsSection(
                context, streamer, vods, playlists, lang)),
    ]);
  }

  void _shareChannel(StreamerModel streamer, String lang) => Share.share(
        'https://www.youtube.com/@${streamer.youtubeHandle.trim().replaceFirst('@', '')}',
        subject: streamer.getLocalizedName(lang),
      );

  Future<void> _toggleChannelReminder(BuildContext context, String id) async {
    final provider = context.read<AppProvider>();
    if (!provider.isLoggedInStreamer) {
      final signIn = await showCaSheet<bool>(context,
          title: 'upcoming.sign_in_title'.tr(),
          job: CaSheetJob.confirmation,
          bareChrome: true,
          body: Text('upcoming.sign_in_body'.tr()),
          actions: [
            Builder(
                builder: (ctx) => CaButton(
                    label: 'upcoming.cancel'.tr(),
                    variant: CaButtonVariant.text,
                    onPressed: () => Navigator.pop(ctx, false))),
            Builder(
                builder: (ctx) => CaButton(
                    label: 'upcoming.sign_in'.tr(),
                    onPressed: () => Navigator.pop(ctx, true))),
          ]);
      if (signIn == true && context.mounted) {
        context.push('/welcome');
      }
      return;
    }
    try {
      await provider.toggleReminder(id, language: context.locale.languageCode);
      if (context.mounted &&
          provider.hasReminder(id) &&
          provider.reminderPushStatus != ReminderPushStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                (provider.reminderPushStatus == ReminderPushStatus.notGranted
                        ? 'upcoming.permission_denied'
                        : 'upcoming.permission_unavailable')
                    .tr())));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('upcoming.save_failed'.tr())));
      }
    }
  }

  Widget _buildFeaturedChannelsSection(
    BuildContext context,
    StreamerModel streamer,
    List<VodModel> allVods,
    List<PlaylistModel> allPlaylists,
    String lang,
  ) {
    final speakers = streamer.affiliatedSpeakers;
    if (speakers.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('profile.featured_channels'.tr(),
          style: Theme.of(context).textTheme.titleMedium),
      Text('profile.featured_channels_hint'.tr(),
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppTheme.spaceMd),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final speaker in speakers)
              Padding(
                  padding:
                      const EdgeInsetsDirectional.only(end: AppTheme.spaceMd),
                  child: SizedBox(
                      width: CanopySize.profilePane,
                      child: CaCard(
                          onTap: () => setState(() {
                                if (_selectedSpeakerId == speaker.speakerId) {
                                  _selectedSpeakerId = null;
                                } else {
                                  _selectedSpeakerId = speaker.speakerId;
                                  _tabController?.animateTo(0);
                                }
                              }),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CaAvatar(
                                    name: speaker.getLocalizedName(lang),
                                    url: speaker.avatarUrl),
                                Text(speaker.getLocalizedName(lang),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(color: Canopy.ink)),
                                Text(
                                    '@${speaker.youtubeHandle ?? streamer.youtubeHandle}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Canopy.ink)),
                                Text(speaker.getLocalizedRole(lang),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                Text(speaker.getLocalizedBio(lang),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                    '${allVods.where((v) => v.speakerIds.contains(speaker.speakerId)).length} ${'profile.lectures_count'.tr()} • ${allPlaylists.where((p) => p.speakerIds.contains(speaker.speakerId)).length} ${'profile.playlists'.tr()}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                Text(
                                    (_selectedSpeakerId == speaker.speakerId
                                            ? 'profile.filter_active_badge'
                                            : 'profile.view_channel_content')
                                        .tr(),
                                    style:
                                        Theme.of(context).textTheme.labelSmall),
                              ])))),
          ])),
    ]);
  }

  Widget _buildVodArchiveGrid(List<VodModel> vodList, StreamerModel streamer) {
    if (vodList.isEmpty) {
      return SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: CaCard(
                  child: CaEmptyState(
                      title: 'profile.no_instructor_vods'.tr(), body: ''))));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final requested = context.windowClass == WindowClass.compact ? 2 : 3;
      final columns = ((constraints.maxWidth - AppTheme.spaceLg) /
              (CanopyWindow.scholarCardMinWidth + AppTheme.spaceMd))
          .floor()
          .clamp(1, requested);
      final width = (constraints.maxWidth -
              AppTheme.spaceLg * 2 -
              AppTheme.spaceMd * (columns - 1)) /
          columns;
      return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Wrap(
              spacing: AppTheme.spaceMd,
              runSpacing: AppTheme.spaceMd,
              children: [
                for (final vod in vodList)
                  SizedBox(
                      width: width,
                      child: VodGridTile(vod: vod, streamer: streamer)),
              ]));
    });
  }

  Widget _buildPlaylistsGrid(
    List<PlaylistModel> playlists,
    StreamerModel streamer,
    String lang,
  ) {
    if (playlists.isEmpty) {
      return SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: CaCard(
                  child: CaEmptyState(
                      title: 'profile.no_videos_playlist'.tr(), body: ''))));
    }

    return Builder(builder: (context) {
      final titleStyle =
          Theme.of(context).textTheme.labelLarge?.copyWith(color: Canopy.ink);
      final countStyle = Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: Canopy.brandGreen, fontWeight: FontWeight.w600);
      // One shared row height (a 2-line title and the count line), so every
      // playlist is the same size whatever its title.
      final rowHeight = [
        CanopySize.lectureImageHeight,
        CaFixedLines.heightOf(context, titleStyle, 2) +
            AppTheme.spaceXs +
            CaFixedLines.heightOf(context, countStyle, 1),
      ].reduce((a, b) => a > b ? a : b);
      return ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        itemCount: playlists.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return CaCard(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            onTap: () => _showPlaylistModal(context, playlist, streamer, lang),
            child: SizedBox(
              height: rowHeight,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(CanopyRadius.input),
                    child: SizedBox(
                      width: CanopySize.lectureImageWidth,
                      height: CanopySize.lectureImageHeight,
                      child: CaCardImage(url: playlist.thumbnailUrl),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CaFixedLines(playlist.getLocalizedTitle(lang),
                            lines: 2, style: titleStyle),
                        const SizedBox(height: AppTheme.spaceXs),
                        CaFixedLines(
                            '${playlist.videoCount} ${'profile.lectures_count'.tr()}',
                            lines: 1,
                            style: countStyle),
                      ],
                    ),
                  ),
                  Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: Canopy.slate),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _showPlaylistModal(
    BuildContext context,
    PlaylistModel playlist,
    StreamerModel streamer,
    String lang,
  ) {
    PlaylistViewerModalSheet.show(
      context,
      playlist: playlist,
      streamer: streamer,
      langCode: lang,
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget _tabBar;
  final double height;

  _SliverTabBarDelegate(this._tabBar, this.height);

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Canopy.dawn,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate._tabBar != _tabBar;
  }
}

/// A white ring around the profile picture, so it reads as a stroke against
/// the banner behind it.
class _AvatarStroke extends StatelessWidget {
  const _AvatarStroke({required this.child, required this.org});
  final Widget child;
  final bool org;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: Canopy.paper,
          shape: org ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: org
              ? BorderRadius.circular(CanopyRadius.orgAvatar +
                  _BroadcasterProfileScreenState._avatarStroke)
              : null),
      child: Padding(
          padding: const EdgeInsets.all(
              _BroadcasterProfileScreenState._avatarStroke),
          child: child));
}
