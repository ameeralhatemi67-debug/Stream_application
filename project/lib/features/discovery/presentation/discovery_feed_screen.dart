import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../profile/models/streamer_models.dart';
import '../../notifications/presentation/notification_center_sheet.dart';
import 'widgets/streamer_grid_card.dart';
import 'widgets/tags_filter_bottom_sheet.dart';

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    _searchController.text = appProvider.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNotificationsSheet(BuildContext context) {
    NotificationCenterSheet.show(context);
  }

  void _showBookmarksSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'feed.bookmarks_sheet_title'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.darkBorderSubtle),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'feed.no_bookmarks'.tr(),
                      style: const TextStyle(color: AppTheme.textMutedDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // context.read for method calls (setSearchQuery) -- doesn't need to
    // rebuild this widget on its own. context.select below scopes the
    // rebuild to just the 8 fields this screen actually renders, instead of
    // every AppProvider change (uses DeepCollectionEquality by default, so
    // the two lists only trigger a rebuild when their contents actually
    // change, not on every unrelated notifyListeners() call).
    final appProvider = context.read<AppProvider>();
    final (
      selectedCategory,
      liveStreamers,
      displayedStreamers,
      isStreamerModeEnabled,
      isBroadcastingLive,
      customBroadcastType,
      unreadNotificationsCount,
      selectedTagFilter,
    ) = context.select<
        AppProvider,
        (
          String,
          List<StreamerModel>,
          List<StreamerModel>,
          bool,
          bool,
          BroadcastType,
          int,
          String
        )>((p) => (
          p.currentCategoryFilter,
          p.liveStreamers,
          p.filteredStreamers,
          p.isStreamerModeEnabled,
          p.isBroadcastingLive,
          p.customBroadcastType,
          p.unreadNotificationsCount,
          p.selectedTagFilter,
        ));
    final langCode = context.locale.languageCode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final streamerGridColumns = isDesktop ? 4 : (screenWidth > 600 ? 3 : 2);

    final isUserStreamerLive = isStreamerModeEnabled && isBroadcastingLive;

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      appBar: AppBar(
        titleSpacing: AppTheme.spaceMd,
        title: isUserStreamerLive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: customBroadcastType == BroadcastType.liveAudio
                      ? const Color(0xFF3F3F46)
                      : AppTheme.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: customBroadcastType == BroadcastType.liveAudio
                        ? const Color(0xFFA1A1AA)
                        : AppTheme.accentRed.withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (customBroadcastType == BroadcastType.liveAudio) ...[
                      const Icon(Icons.mic_rounded, size: 12, color: Color(0xFFE4E4E7)),
                      const SizedBox(width: 5),
                      Text(
                        'live.audio_live_indicator'.tr(),
                        style: const TextStyle(
                          color: Color(0xFFE4E4E7),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'live.live_indicator'.tr(),
                        style: const TextStyle(
                          color: AppTheme.accentRed,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : const SizedBox.shrink(),
        actions: [
          const LanguageSwitcher(),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, size: 22),
                if (unreadNotificationsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'nav.notifications'.tr(),
            onPressed: () => _showNotificationsSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded, size: 22),
            tooltip: 'nav.bookmarks'.tr(),
            onPressed: () => _showBookmarksSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'nav.settings'.tr(),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: AppTheme.spaceSm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
        children: [
          // 🔎 Search Bar + Tag Filter Action Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface1,
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(
                        color: AppTheme.darkBorderSubtle,
                        width: 1.2,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                          color: AppTheme.textPrimaryDark, fontSize: 14),
                      onChanged: (value) => appProvider.setSearchQuery(value),
                      decoration: InputDecoration(
                        hintText: 'feed.search_feed'.tr(),
                        hintStyle: const TextStyle(
                            color: AppTheme.textMutedDark, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppTheme.accentBlue, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 18, color: AppTheme.textMutedDark),
                                onPressed: () {
                                  _searchController.clear();
                                  appProvider.setSearchQuery('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                // Filter Tags Button
                Material(
                  color: AppTheme.darkSurface1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.0),
                    side: BorderSide(
                      color: selectedTagFilter != 'all'
                          ? AppTheme.accentRed
                          : AppTheme.darkBorderSubtle,
                      width: 1.2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => TagsFilterBottomSheet.show(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.tune_rounded,
                        color: selectedTagFilter != 'all'
                            ? AppTheme.accentRed
                            : AppTheme.textPrimaryDark,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // 🌟 Top Featured Live Stream Hero (Only shown if a streamer is live!)
          if (liveStreamers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
              child: _buildHeroLiveCarousel(
                  context, liveStreamers.first, langCode),
            ),
            const SizedBox(height: AppTheme.spaceXl),

            // 📍 "Live Now in AlSharqia" Section (Only shown if streamers are live!)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                      Text(
                        'feed.live_in_sharqia'.tr(),
                        style: const TextStyle(
                          color: AppTheme.textPrimaryDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${liveStreamers.length} ${'feed.active_streams'.tr()}',
                    style: const TextStyle(
                        color: AppTheme.accentRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),

            SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
                itemCount: liveStreamers.length,
                itemBuilder: (context, index) {
                  final streamer = liveStreamers[index];
                  return _buildHorizontalLiveCard(context, streamer, langCode);
                },
              ),
            ),
            const SizedBox(height: AppTheme.spaceXl),
          ],

          // 🏷️ Category Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
            child: Text(
              'feed.academic_fields'.tr(),
              style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
            child: Row(
              children: [
                _buildCategoryFilterChip(
                    context, selectedCategory, 'all', 'category_all'),
                const SizedBox(width: AppTheme.spaceSm),
                _buildCategoryFilterChip(
                    context, selectedCategory, 'computer_science', 'cat_cs'),
                const SizedBox(width: AppTheme.spaceSm),
                _buildCategoryFilterChip(
                    context, selectedCategory, 'islamic_studies', 'cat_sharia'),
                const SizedBox(width: AppTheme.spaceSm),
                _buildCategoryFilterChip(
                    context, selectedCategory, 'medicine', 'cat_med'),
                const SizedBox(width: AppTheme.spaceSm),
                _buildCategoryFilterChip(
                    context, selectedCategory, 'engineering', 'cat_eng'),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),

          // 🎙️ "Streamers" Grid Section (Replacing old Lecture Archive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'feed.streamers'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${displayedStreamers.length} ${'feed.streamers_count'.tr()}',
                  style: const TextStyle(
                      color: AppTheme.textMutedDark, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: streamerGridColumns,
                mainAxisSpacing: AppTheme.spaceMd,
                crossAxisSpacing: AppTheme.spaceMd,
                childAspectRatio: isDesktop ? 0.85 : 0.80,
              ),
              itemCount: displayedStreamers.length,
              itemBuilder: (context, index) {
                final streamer = displayedStreamers[index];
                return StreamerGridCard(
                  streamer: streamer,
                  langCode: langCode,
                );
              },
            ),
          ),
          const SizedBox(height: AppTheme.space2Xl),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip(
    BuildContext context,
    String selectedCategory,
    String categoryKey,
    String localizationKey,
  ) {
    final isSelected = selectedCategory == categoryKey;
    return ChoiceChip(
      label: Text('feed.$localizationKey'.tr()),
      selected: isSelected,
      onSelected: (selected) {
        context
            .read<AppProvider>()
            .setCategoryFilter(selected ? categoryKey : 'all');
      },
      selectedColor: AppTheme.accentRed,
      backgroundColor: AppTheme.darkSurface1,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimaryDark,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
    );
  }

  Widget _buildHeroLiveCarousel(
      BuildContext context, StreamerModel streamer, String langCode) {
    final isAudio = streamer.isAudioLive;
    final isVideo = streamer.isVideoLive;

    Color borderColor = isVideo
        ? AppTheme.accentRed.withValues(alpha: 0.4)
        : const Color(0xFFA1A1AA).withValues(alpha: 0.5);

    Color shadowColor = isVideo
        ? AppTheme.accentRed.withValues(alpha: 0.15)
        : const Color(0xFFA1A1AA).withValues(alpha: 0.15);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner image
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image(
                  image: streamer.bannerUrl.startsWith('assets/')
                      ? AssetImage(streamer.bannerUrl)
                      : NetworkImage(streamer.bannerUrl) as ImageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.darkSurface2,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppTheme.textMutedDark,
                      size: 40,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppTheme.spaceMd,
                left: AppTheme.spaceMd,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVideo ? AppTheme.accentRed : const Color(0xFF3F3F46),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: isAudio
                        ? Border.all(color: const Color(0xFFA1A1AA), width: 0.8)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAudio) ...[
                        const Icon(
                          Icons.mic_rounded,
                          size: 13,
                          color: Color(0xFFE4E4E7),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${streamer.activeViewerCount} ${'live.listening_count'.tr()}',
                          style: const TextStyle(
                            color: Color(0xFFE4E4E7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${streamer.activeViewerCount} ${'feed.watching'.tr()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streamer.getLocalizedTitle(langCode),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: streamer.avatarUrl.startsWith('assets/')
                          ? AssetImage(streamer.avatarUrl)
                          : NetworkImage(streamer.avatarUrl) as ImageProvider,
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            streamer.getLocalizedName(langCode),
                            style: const TextStyle(
                              color: AppTheme.textPrimaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            streamer.getLocalizedVenue(langCode),
                            style: const TextStyle(
                              color: AppTheme.textSecondaryDark,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (streamer.activeStreamId != null) {
                          context.push('/live/${streamer.activeStreamId}');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVideo
                            ? AppTheme.accentRed
                            : const Color(0xFF3F3F46),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          side: isAudio
                              ? const BorderSide(color: Color(0xFFA1A1AA), width: 1.0)
                              : BorderSide.none,
                        ),
                      ),
                      icon: Icon(
                        isVideo ? Icons.play_arrow_rounded : Icons.mic_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isVideo ? 'feed.watch_live'.tr() : 'live.listen_live'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalLiveCard(
      BuildContext context, StreamerModel streamer, String langCode) {
    final isAudio = streamer.isAudioLive;
    final isVideo = streamer.isVideoLive;

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isVideo
              ? AppTheme.accentRed.withValues(alpha: 0.6)
              : isAudio
                  ? const Color(0xFFA1A1AA).withValues(alpha: 0.6)
                  : AppTheme.darkBorderSubtle,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (streamer.activeStreamId != null) {
            context.push('/live/${streamer.activeStreamId}');
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Image(
                    image: streamer.bannerUrl.startsWith('assets/')
                        ? AssetImage(streamer.bannerUrl)
                        : NetworkImage(streamer.bannerUrl) as ImageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.darkSurface2,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: AppTheme.textMutedDark,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isVideo ? AppTheme.accentRed : const Color(0xFF3F3F46),
                      borderRadius: BorderRadius.circular(4),
                      border: isAudio
                          ? Border.all(color: const Color(0xFFA1A1AA), width: 0.8)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAudio) ...[
                          const Icon(
                            Icons.mic_rounded,
                            size: 10,
                            color: Color(0xFFE4E4E7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'feed.audio_live_badge'.tr(),
                            style: const TextStyle(
                              color: Color(0xFFE4E4E7),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'feed.live_badge'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streamer.getLocalizedTitle(langCode),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streamer.getLocalizedName(langCode),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
