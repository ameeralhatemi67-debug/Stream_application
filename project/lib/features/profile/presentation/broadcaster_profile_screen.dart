import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feature_in_progress_modal.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import '../models/streamer_models.dart';
import '../models/vod_models.dart';
import 'widgets/vod_grid_tile.dart';
import 'widgets/vod_player_modal_sheet.dart';
import 'widgets/org_branches_modal_sheet.dart';
import 'widgets/join_org_modal_sheet.dart';

class BroadcasterProfileScreen extends StatefulWidget {
  final String streamerId;

  const BroadcasterProfileScreen({super.key, required this.streamerId});

  @override
  State<BroadcasterProfileScreen> createState() =>
      _BroadcasterProfileScreenState();
}

class _BroadcasterProfileScreenState extends State<BroadcasterProfileScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String? _selectedSpeakerId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final streamer = appProvider.getStreamerById(widget.streamerId);
      final handle = streamer?.youtubeHandle ?? 'ahmedamercaller';
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
      _tabController = TabController(length: expectedTabs, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final lang = context.locale.languageCode;

    // Lookup streamer or fallback to default primary scholar
    final streamer = appProvider.getStreamerById(widget.streamerId) ??
        appProvider.streamers.first;

    final isFollowing = appProvider.isFollowing(streamer.streamerId);
    final hasReminder = appProvider.hasReminder(streamer.streamerId);

    // Dynamic VODs and Playlists (Live YouTube API or fallback to mock pool)
    final allVods = appProvider.getVodsForStreamer(streamer.streamerId);
    final activePlaylists =
        appProvider.getPlaylistsForStreamer(streamer.streamerId);

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

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      appBar: AppBar(
        title: Text(streamer.getLocalizedName(lang)),
        actions: [
          // Streamer Broadcast Studio & Pitch Director Access (Only visible to logged-in streamers)
          if (appProvider.isLoggedInStreamer &&
              appProvider.isStreamerModeEnabled)
            IconButton(
              icon: Icon(
                Icons.cell_tower_rounded,
                color: appProvider.isPitchDirectorModeEnabled
                    ? AppTheme.accentRed
                    : AppTheme.textSecondaryDark,
              ),
              tooltip: 'live.rtmp_ip_tooltip'.tr(),
              onPressed: () => RtmpIpSettingsDialog.show(context),
            ),
          const LanguageSwitcher(),
          const SizedBox(width: AppTheme.spaceXs),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'profile.share_btn'.tr(),
            onPressed: () => FeatureInProgressModal.show(
              context,
              featureName: 'profile.share_btn'.tr(),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: _buildHeaderCard(
                  context,
                  streamer,
                  isFollowing,
                  hasReminder,
                  lang,
                  appProvider,
                  allVods,
                  activePlaylists,
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.accentBlue,
                  labelColor: AppTheme.accentBlue,
                  unselectedLabelColor: AppTheme.textSecondaryDark,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(
                      icon:
                          const Icon(Icons.video_collection_outlined, size: 18),
                      text: 'profile.archived_lectures'.tr(),
                    ),
                    Tab(
                      icon: const Icon(Icons.playlist_play_rounded, size: 18),
                      text: 'profile.playlists'.tr(),
                    ),
                    Tab(
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      text: 'profile.upcoming_lectures'.tr(),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: VOD Archive Grid (Filtered by speaker if set)
            _buildVodArchiveGrid(displayedVods, streamer),

            // Tab 2: Playlists View (Filtered by speaker if set)
            _buildPlaylistsGrid(displayedPlaylists, streamer, lang),

            // Tab 3: Upcoming Schedule View
            _buildUpcomingScheduleList(streamer, lang),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    StreamerModel streamer,
    bool isFollowing,
    bool hasReminder,
    String lang,
    AppProvider appProvider,
    List<VodModel> allVods,
    List<PlaylistModel> allPlaylists,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Avatar Image with Status Ring (Squircle for Org, Circle for Scholar)
              Hero(
                tag: 'avatar_${streamer.streamerId}',
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: streamer.isOrganization
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                    borderRadius: streamer.isOrganization
                        ? BorderRadius.circular(16)
                        : null,
                    border: Border.all(
                      color: streamer.isCurrentlyLive
                          ? AppTheme.accentRed
                          : (streamer.isOrganization
                              ? const Color(0xFFD97706)
                              : AppTheme.accentBlue),
                      width: 2.5,
                    ),
                    image: DecorationImage(
                      image: streamer.avatarUrl.startsWith('assets/')
                          ? AssetImage(streamer.avatarUrl) as ImageProvider
                          : NetworkImage(streamer.avatarUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceLg),

              // Name, Title, Verification Badge & Venue
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            streamer.getLocalizedName(lang),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (streamer.isVerified)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.verified_rounded,
                              color: streamer.isOrganization
                                  ? const Color(0xFFD97706)
                                  : AppTheme.accentPurple,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streamer.getLocalizedTitle(lang),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          streamer.isOrganization
                              ? Icons.domain_rounded
                              : Icons.account_balance_outlined,
                          size: 14,
                          color: AppTheme.accentBlue,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            streamer.getLocalizedOrganization(lang),
                            style: const TextStyle(
                              color: AppTheme.accentBlue,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Desktop Top-Right Action Buttons: Follow Channel & Set Reminder
              if (MediaQuery.of(context).size.width >= 700) ...[
                const SizedBox(width: AppTheme.spaceLg),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            appProvider.toggleFollow(streamer.streamerId),
                        icon: Icon(
                          isFollowing
                              ? Icons.check_circle_rounded
                              : Icons.person_add_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isFollowing
                              ? 'profile.following_btn'.tr()
                              : 'profile.follow_btn'.tr(),
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          backgroundColor: isFollowing
                              ? AppTheme.darkSurface2
                              : AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          side: isFollowing
                              ? const BorderSide(
                                  color: AppTheme.accentBlue, width: 1.2)
                              : BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            appProvider.toggleReminder(streamer.streamerId),
                        icon: Icon(
                          hasReminder
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          size: 16,
                          color: hasReminder
                              ? AppTheme.accentPurple
                              : AppTheme.textSecondaryDark,
                        ),
                        label: Text(
                          hasReminder
                              ? 'profile.following_btn'.tr()
                              : 'profile.reminder_btn'.tr(),
                          style: TextStyle(
                            color: hasReminder
                                ? AppTheme.accentPurple
                                : Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          side: BorderSide(
                            color: hasReminder
                                ? AppTheme.accentPurple
                                : AppTheme.darkBorderSubtle,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: AppTheme.spaceSm),

          // Metadata Badges Wrap (Spans full width on the left: Live YouTube Sync + Campus Locations)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: appProvider
                          .isYouTubeLiveSynced(streamer.streamerId)
                      ? AppTheme.accentRed.withValues(alpha: 0.15)
                      : AppTheme.darkSurface2,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusXs),
                  border: Border.all(
                    color: appProvider
                            .isYouTubeLiveSynced(streamer.streamerId)
                        ? AppTheme.accentRed
                        : AppTheme.darkBorderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      appProvider.isYouTubeLiveSynced(
                              streamer.streamerId)
                          ? Icons.sensors_rounded
                          : Icons.ondemand_video_rounded,
                      size: 12,
                      color: appProvider.isYouTubeLiveSynced(
                              streamer.streamerId)
                          ? AppTheme.accentRed
                          : AppTheme.textSecondaryDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appProvider.isYouTubeLiveSynced(
                              streamer.streamerId)
                          ? 'profile.live_youtube_sync'.tr()
                          : 'profile.youtube_archive'.tr(),
                      style: TextStyle(
                        color: appProvider.isYouTubeLiveSynced(
                                streamer.streamerId)
                            ? AppTheme.accentRed
                            : AppTheme.textSecondaryDark,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Campus branches trigger for Organizations
              if (streamer.isOrganization &&
                  streamer.venues.isNotEmpty)
                InkWell(
                  onTap: () => OrgBranchesModalSheet.show(
                    context,
                    orgName: streamer.getLocalizedName(lang),
                    venues: streamer.venues,
                  ),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusXs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.accentBlue.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXs),
                      border: Border.all(
                        color: AppTheme.accentBlue
                            .withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_city_rounded,
                          size: 12,
                          color: AppTheme.accentBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${streamer.venues.length} ${'profile.campus_branches_btn'.tr()}',
                          style: const TextStyle(
                            color: AppTheme.accentBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Join an Organization Action (For Individual Broadcasters)
              if (!streamer.isOrganization && appProvider.isLoggedInStreamer)
                InkWell(
                  onTap: () => JoinOrgModalSheet.show(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                      border: Border.all(
                        color: AppTheme.accentPurple.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.domain_add_rounded,
                          size: 12,
                          color: AppTheme.accentPurple,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Join an Organization',
                          style: TextStyle(
                            color: AppTheme.accentPurple,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Live Stream Banner Trigger (If live)
          if (streamer.isCurrentlyLive) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Material(
              color: AppTheme.accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: InkWell(
                onTap: () {
                  context.push(
                      '/live/${streamer.activeStreamId ?? "stream_live_992"}');
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.accentRed, width: 1.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${'map.live_badge'.tr()} • ${streamer.activeViewerCount} ${'feed.watching'.tr()}',
                              style: const TextStyle(
                                color: AppTheme.accentRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'profile.tap_to_join_live'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppTheme.accentRed,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spaceMd),

          // Bio Text
          Text(
            streamer.getLocalizedBio(lang),
            style: const TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          // Mobile Action Buttons (Below Bio for width < 700)
          if (MediaQuery.of(context).size.width < 700) ...[
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        appProvider.toggleFollow(streamer.streamerId),
                    icon: Icon(
                      isFollowing
                          ? Icons.check_circle_rounded
                          : Icons.person_add_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isFollowing
                          ? 'profile.following_btn'.tr()
                          : 'profile.follow_btn'.tr(),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      backgroundColor: isFollowing
                          ? AppTheme.darkSurface2
                          : AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      side: isFollowing
                          ? const BorderSide(
                              color: AppTheme.accentBlue, width: 1.2)
                          : BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        appProvider.toggleReminder(streamer.streamerId),
                    icon: Icon(
                      hasReminder
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      size: 16,
                      color: hasReminder
                          ? AppTheme.accentPurple
                          : AppTheme.textSecondaryDark,
                    ),
                    label: Text(
                      hasReminder
                          ? 'profile.following_btn'.tr()
                          : 'profile.reminder_btn'.tr(),
                      style: TextStyle(
                        color:
                            hasReminder ? AppTheme.accentPurple : Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      side: BorderSide(
                        color: hasReminder
                            ? AppTheme.accentPurple
                            : AppTheme.darkBorderSubtle,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Featured Channels Full Cards (If Organization)
          if (streamer.isOrganization && streamer.affiliatedSpeakers.isNotEmpty)
            _buildFeaturedChannelsSection(
                context, streamer, allVods, allPlaylists, lang),
        ],
      ),
    );
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

    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.subscriptions_rounded,
                size: 16,
                color: AppTheme.accentRed,
              ),
              const SizedBox(width: 8),
              Text(
                'profile.featured_channels'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.darkBorderSubtle),
                ),
                child: Text(
                  '${speakers.length}',
                  style: const TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'profile.featured_channels_hint'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: speakers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (ctx, idx) {
                final speaker = speakers[idx];
                final isSelected = _selectedSpeakerId == speaker.speakerId;
                final speakerVods = allVods
                    .where((v) => v.speakerIds.contains(speaker.speakerId))
                    .toList();
                final speakerPlaylists = allPlaylists
                    .where((p) => p.speakerIds.contains(speaker.speakerId))
                    .toList();
                final handle = speaker.youtubeHandle ?? streamer.youtubeHandle;

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedSpeakerId == speaker.speakerId) {
                        _selectedSpeakerId = null;
                      } else {
                        _selectedSpeakerId = speaker.speakerId;
                        _tabController?.animateTo(0);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 310,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD97706).withValues(alpha: 0.12)
                          : AppTheme.darkBgBase,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD97706)
                            : AppTheme.darkBorderSubtle,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFD97706)
                                      : (speaker.isPermanentStaff
                                          ? AppTheme.accentBlue
                                          : AppTheme.textSecondaryDark),
                                  width: 2,
                                ),
                                image: DecorationImage(
                                  image: speaker.avatarUrl.startsWith('assets/')
                                      ? AssetImage(speaker.avatarUrl)
                                          as ImageProvider
                                      : NetworkImage(speaker.avatarUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    speaker.getLocalizedName(lang),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentRed
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppTheme.accentRed
                                            .withValues(alpha: 0.4),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 11,
                                          color: AppTheme.accentRed,
                                        ),
                                        const SizedBox(width: 2),
                                        Flexible(
                                          child: Text(
                                            '@$handle',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: Colors.black,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 3),
                        Expanded(
                          child: Text(
                            speaker.getLocalizedBio(lang),
                            style: const TextStyle(
                              color: AppTheme.textSecondaryDark,
                              fontSize: 11,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '${speakerVods.length} ${'profile.lectures_count'.tr()} • ${speakerPlaylists.length} ${'profile.playlists'.tr()}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondaryDark,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isSelected
                                  ? 'profile.filter_active_badge'.tr()
                                  : 'profile.view_channel_content'.tr(),
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFD97706)
                                    : AppTheme.accentBlue,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVodArchiveGrid(List<VodModel> vodList, StreamerModel streamer) {
    if (vodList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.video_library_outlined,
                color: AppTheme.textSecondaryDark,
                size: 48,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                'profile.no_instructor_vods'.tr(),
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final childAspectRatio = isDesktop ? 1.22 : (isTablet ? 1.2 : 1.00);

    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: AppTheme.spaceMd,
        mainAxisSpacing: AppTheme.spaceMd,
      ),
      itemCount: vodList.length,
      itemBuilder: (context, index) {
        final vod = vodList[index];
        return VodGridTile(
          vod: vod,
          streamer: streamer,
        );
      },
    );
  }

  Widget _buildPlaylistsGrid(
    List<PlaylistModel> playlists,
    StreamerModel streamer,
    String lang,
  ) {
    if (playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.playlist_play_rounded,
                color: AppTheme.textSecondaryDark,
                size: 48,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                'profile.no_videos_playlist'.tr(),
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: playlists.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return Material(
          color: AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            onTap: () {
              _showPlaylistModal(context, playlist, streamer, lang);
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.darkBorderSubtle),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Image(
                      image: playlist.thumbnailUrl.startsWith('assets/')
                          ? AssetImage(playlist.thumbnailUrl) as ImageProvider
                          : NetworkImage(playlist.thumbnailUrl),
                      width: 80,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.getLocalizedTitle(lang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.videoCount} ${'profile.lectures_count'.tr()}',
                          style: const TextStyle(
                            color: AppTheme.accentBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondaryDark,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpcomingScheduleList(StreamerModel streamer, String lang) {
    final scheduleList = streamer.getLocalizedSchedule(lang);

    if (scheduleList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_busy_rounded,
                color: AppTheme.textSecondaryDark,
                size: 48,
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                'profile.no_upcoming_schedule'.tr(),
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: scheduleList.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
      itemBuilder: (context, index) {
        final item = scheduleList[index];
        return Container(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface1,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.darkBorderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSm),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.accentBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlaylistModal(
    BuildContext context,
    PlaylistModel playlist,
    StreamerModel streamer,
    String lang,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppTheme.darkBgBase,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
            border: Border(
                top: BorderSide(color: AppTheme.darkBorderSubtle, width: 1.5)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondaryDark.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        playlist.getLocalizedTitle(lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.textSecondaryDark),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.darkBorderSubtle),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: playlist.videos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (c, i) {
                    final video = playlist.videos[i];
                    return ListTile(
                      tileColor: AppTheme.darkSurface1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        side:
                            const BorderSide(color: AppTheme.darkBorderSubtle),
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image(
                          image: video.thumbnailUrl.startsWith('assets/')
                              ? AssetImage(video.thumbnailUrl) as ImageProvider
                              : NetworkImage(video.thumbnailUrl),
                          width: 50,
                          height: 35,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        video.getLocalizedTitle(lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        video.formattedDuration,
                        style: const TextStyle(
                            color: AppTheme.textSecondaryDark, fontSize: 11),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        VodPlayerModalSheet.show(
                          context,
                          vod: video,
                          streamer: streamer,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.darkBgBase,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate._tabBar != _tabBar;
  }
}
