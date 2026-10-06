import '../../../core/widgets/ds/canopy_content_motion.dart';
import '../../../core/widgets/ds/ca_navigation.dart';
import '../../../core/widgets/ds/ca_pull_to_refresh.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/layout/window_class.dart';
import '../../../core/widgets/ds/ca_discovery.dart';
import '../../../core/widgets/ds/ca_cards.dart';
import '../../../core/widgets/ds/ca_button.dart';
import '../../../core/widgets/ds/ca_fields.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_feedback.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/connectivity_banner.dart';
import '../models/academic_category_model.dart';
import '../../profile/models/streamer_models.dart';
import '../../notifications/presentation/notification_center_sheet.dart';
import 'widgets/streamer_grid_card.dart';
import 'widgets/discovery_card_skeleton.dart';
import 'widgets/tags_filter_bottom_sheet.dart';
import '../../../core/widgets/duplicate_channel_resolution_dialog.dart';
import 'bookmarks_sheet.dart';

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late final _entrance = AnimationController(
      vsync: this,
      duration: CanopyMotion.contentIn + CanopyMotion.feedStagger * 5);
  bool _entranceStarted = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanopyMotion.reduced(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _entrance.value = 1;
      _entranceStarted = true;
    } else if (!_entranceStarted) {
      _entranceStarted = true;
      _entrance.forward();
    }
  }

  Widget _firstPaint(Widget child, int index) {
    final duration = _entrance.duration!.inMilliseconds;
    final start = index.clamp(0, 5) * CanopyMotion.feedStagger.inMilliseconds;
    final progress = _entrance.drive(CurveTween(
        curve: Interval(start / duration,
            (start + CanopyMotion.contentIn.inMilliseconds) / duration,
            curve: CanopyMotion.easeOut)));
    return CanopyContentMotion(
        animation: progress,
        child: FadeTransition(opacity: progress, child: child));
  }

  int? _cardLayoutSignature;
  List<GlobalKey> _cardKeys = [];
  double _cardMinHeight = 0;
  bool _cardMeasureQueued = false;

  void _measureCardHeights() {
    if (_cardMeasureQueued) return;
    _cardMeasureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cardMeasureQueued = false;
      if (!mounted) return;
      var tallest = 0.0;
      // ponytail: one O(n) scan per layout change; virtualize if the feed grows.
      for (final key in _cardKeys) {
        final box = key.currentContext?.findRenderObject();
        if (box is RenderBox && box.hasSize && box.size.height > tallest) {
          tallest = box.size.height;
        }
      }
      if (tallest > _cardMinHeight + 0.5) {
        setState(() => _cardMinHeight = tallest);
      }
    });
  }

  Timer? _searchDebounce;

  /// A keystroke used to notify the whole app and re-filter the catalog twice
  /// (feed + map); wait for a short pause in typing first (audit RT-07).
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(CanopyMotion.searchDebounce, () {
      if (mounted) context.read<AppProvider>().setSearchQuery(value);
    });
  }

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    _searchController.text = appProvider.searchQuery;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDuplicateChannelsIfNeeded();
      _refreshVisibleViewerCounts();
    });
    // Live cards show the platform's own viewer count (P3 / 05 D-08). One
    // batched call covers every live card on screen; the provider throttles
    // it to one round trip per 30 s, and an unknown count renders as "—".
    _viewerCountTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isVisibleAndForeground) _refreshVisibleViewerCounts();
    });
    // LIVE badges expire with the catalog read behind them: other accounts'
    // live changes never reach this client over Realtime (profiles RLS), so
    // a stale badge lasts at most about 45 seconds.
    _catalogFreshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_isVisibleAndForeground) return;
      final provider = context.read<AppProvider>();
      if (provider.isOnline) {
        unawaited(
            provider.refreshCatalogIfOlderThan(const Duration(seconds: 30)));
      }
    });
  }

  Timer? _viewerCountTimer;
  Timer? _catalogFreshnessTimer;

  /// Pollers pause while this tab is hidden behind another tab or a pushed
  /// route, and while the app is in the background (audit NET-02).
  bool get _isVisibleAndForeground {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return false;
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _refreshVisibleViewerCounts() {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    if (!provider.isOnline) return;
    final ids = provider.streamers
        .where((s) => s.isCurrentlyLive && (s.activeStreamId ?? '').isNotEmpty)
        .map((s) => s.activeStreamId!)
        .toList();
    if (ids.isEmpty) return;
    unawaited(provider.refreshViewerCountsFor(ids));
  }

  void _checkDuplicateChannelsIfNeeded() async {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    final duplicates = provider.detectDuplicateChannels();
    if (duplicates.length > 1) {
      final chosen = await DuplicateChannelResolutionDialog.show(
        context: context,
        duplicateChannels: duplicates,
      );
      if (chosen != null && mounted) {
        provider.resolveDuplicateChannels(keptStreamerId: chosen.streamerId);
      }
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _viewerCountTimer?.cancel();
    _catalogFreshnessTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();

    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showNotificationsSheet(BuildContext context) {
    NotificationCenterSheet.show(context);
  }

  void _showBookmarksSheet(BuildContext context) {
    BookmarksSheet.show(context);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    context.read<AppProvider>().setSearchQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory =
        context.select<AppProvider, String>((p) => p.currentCategoryFilter);
    final displayed = context
        .select<AppProvider, List<StreamerModel>>((p) => p.filteredStreamers);
    final categories = context.select<AppProvider, List<AcademicCategoryModel>>(
        (p) => p.academicCategories);
    final unread =
        context.select<AppProvider, int>((p) => p.unreadNotificationsCount);
    final tag = context.select<AppProvider, String>((p) => p.selectedTagFilter);
    final online = context.select<AppProvider, bool>((p) => p.isOnline);
    final loadingCards = context.select<AppProvider, bool>((p) =>
        p.isLoadingPublicCatalog &&
        !p.hasPublicCatalogSnapshot &&
        p.streamers.isEmpty);
    final ownLive = context.select<AppProvider, bool>(
        (p) => p.isStreamerModeEnabled && p.isBroadcastingLive);
    final ownAudio = context.select<AppProvider, bool>(
        (p) => p.customBroadcastType == BroadcastType.liveAudio);
    final lang = context.locale.languageCode;
    final live = online
        ? displayed.where((s) => s.isCurrentlyLive).toList()
        : <StreamerModel>[];
    final inlineSearch =
        context.windowClass != WindowClass.compact && !context.isPhoneLandscape;
    if (context.isPhoneLandscape && _searchFocusNode.hasFocus) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _searchFocusNode.unfocus());
    }
    Widget search() => CaSearchField(
        label: 'feed.search_feed'.tr(),
        hint: 'feed.search_feed'.tr(),
        clearLabel: 'feed.clear_search'.tr(),
        controller: _searchController,
        focusNode: _searchFocusNode,
        readOnly: context.isPhoneLandscape,
        onChanged: _onSearchChanged,
        onClear: _searchController.text.isEmpty ? null : _clearSearch,
        onFilter: () => TagsFilterBottomSheet.show(context),
        filterLabel: 'feed.filters'.tr() + (tag == 'all' ? '' : ' • 1'));
    final dock = context.usesPillNav &&
        (MediaQuery.textScalerOf(context).scale(1) >= 1.3 ||
            context.isPhoneLandscape);
    final heroHeight = context.isPhoneLandscape
        ? CanopySize.heroLandscape
        : switch (context.windowClass) {
            WindowClass.compact => CanopySize.heroCompact,
            WindowClass.medium => CanopySize.heroMedium,
            WindowClass.expanded => CanopySize.heroExpanded,
            WindowClass.large => CanopySize.heroLarge
          };
    Widget liveTile(StreamerModel s, {bool stacked = false}) => CaLectureTile(
        stacked: stacked,
        statusKind: s.isAudioLive ? CaStatusKind.audio : CaStatusKind.live,
        title: s.getLocalizedTitle(lang),
        meta: s.getLocalizedName(lang),
        imageUrl: s.bannerUrl,
        onTap: () => s.activeStreamId == null
            ? null
            : context.push('/live/${s.activeStreamId}'));
    Widget hero() => _firstPaint(
        CaHeroCard(
            title: live.first.getLocalizedTitle(lang),
            presenter:
                '${live.first.getLocalizedName(lang)} · ${live.first.getLocalizedVenue(lang)}',
            imageUrl: live.first.bannerUrl,
            audio: live.first.isAudioLive,
            height: heroHeight,
            showAction: !dock,
            viewerCount: context.select<AppProvider, int?>(
                (p) => p.platformViewerCount(live.first.activeStreamId ?? '')),
            viewerSuffix: (live.first.isAudioLive
                    ? 'live.listening_count'
                    : 'feed.watching')
                .tr(),
            action: (live.first.isAudioLive
                    ? 'live.listen_live'
                    : 'feed.watch_live')
                .tr(),
            onTap: live.first.activeStreamId == null
                ? null
                : () => context.push('/live/${live.first.activeStreamId}')),
        0);
    Widget heading(String label, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
        child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppTheme.spaceSm,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              Text('$count', style: Theme.of(context).textTheme.bodySmall)
            ]));
    return Scaffold(
        backgroundColor: Canopy.dawn,
        appBar: CaAppBar(
            compactLanguage: true,
            languageBare: true,
            toolbarHeight: MediaQuery.textScalerOf(context).scale(1) >= 1.3
                ? CanopySize.appBarScaled
                : null,
            titleSpacing: AppTheme.spaceMd,
            title: Row(children: [
              if (inlineSearch) Expanded(child: search()),
              if (ownLive)
                Flexible(
                    child: CaStatusChip(
                        kind:
                            ownAudio ? CaStatusKind.audio : CaStatusKind.live))
            ]),
            actions: [
              if (inlineSearch) const CaAccountMenu(),
              Stack(children: [
                CaIconButton(
                    bare: true,
                    icon: CaGlyph.bell,
                    label: 'nav.notifications'.tr() +
                        (unread > 0 ? ' ($unread)' : ''),
                    onPressed: () => _showNotificationsSheet(context)),
                if (unread > 0)
                  const PositionedDirectional(
                      top: AppTheme.spaceSm,
                      end: AppTheme.spaceSm,
                      child: IgnorePointer(
                          child: SizedBox.square(
                              dimension: AppTheme.spaceSm,
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: Canopy.brandGreen,
                                      shape: BoxShape.circle))))),
              ]),
              CaIconButton(
                  bare: true,
                  icon: CaGlyph.bookmark,
                  label: 'nav.bookmarks'.tr(),
                  onPressed: () => _showBookmarksSheet(context)),
              CaIconButton(
                  bare: true,
                  icon: CaGlyph.gear,
                  label: 'nav.settings'.tr(),
                  onPressed: () => context.push('/settings')),
            ]),
        bottomNavigationBar: dock && live.isNotEmpty
            ? SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        AppTheme.spaceLg,
                        AppTheme.spaceSm,
                        AppTheme.spaceLg,
                        AppTheme.spaceSm),
                    child: CaButton(
                        label: (live.first.isAudioLive
                                ? 'live.listen_live'
                                : 'feed.watch_live')
                            .tr(),
                        icon:
                            live.first.isAudioLive ? CaGlyph.mic : CaGlyph.play,
                        onPressed: live.first.activeStreamId == null
                            ? null
                            : () => context
                                .push('/live/${live.first.activeStreamId}'))))
            : null,
        body: CaPullToRefresh(
            // Pulling the top of the feed re-reads the public catalog now.
            onRefresh: () => context
                .read<AppProvider>()
                .refreshCatalogIfOlderThan(Duration.zero),
            child:
                ListView(padding: EdgeInsetsDirectional.fromSTEB(context.windowInset, AppTheme.spaceSm, context.windowInset, AppTheme.space2Xl), children: [
              const ConnectivityBanner(),
              if (!inlineSearch) ...[
                search(),
                const SizedBox(height: AppTheme.spaceMd)
              ],
              CaChipRow(children: [
                CaChip(
                    label: 'feed.category_all'.tr(),
                    selected: selectedCategory == 'all',
                    onSelected: (_) =>
                        context.read<AppProvider>().setCategoryFilter('all')),
                for (final category in categories.where((c) => c.isActive))
                  CaChip(
                      label: category.getLocalizedName(lang),
                      selected: selectedCategory == category.id,
                      onSelected: (selected) => context
                          .read<AppProvider>()
                          .setCategoryFilter(selected ? category.id : 'all')),
              ]),
              const SizedBox(height: AppTheme.spaceLg),
              if (live.isNotEmpty) ...[
                if (context.windowClass.index >= WindowClass.expanded.index)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 8, child: hero()),
                    const SizedBox(width: AppTheme.spaceLg),
                    Expanded(
                        flex: 4,
                        child: Column(children: [
                          heading('feed.live_in_alsharqia'.tr(), live.length),
                          for (final s in live.take(3))
                            Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppTheme.spaceSm),
                                child: liveTile(s))
                        ])),
                  ])
                else ...[
                  hero(),
                  heading('feed.live_in_alsharqia'.tr(), live.length),
                  if (context.windowClass == WindowClass.medium)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < live.take(3).length; i++) ...[
                            if (i > 0) const SizedBox(width: AppTheme.spaceMd),
                            Expanded(child: liveTile(live[i], stacked: true)),
                          ]
                        ])
                  else
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final s in live)
                                Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        end: AppTheme.spaceMd),
                                    child: SizedBox(
                                        width: CanopySize.liveTile,
                                        child: liveTile(s, stacked: true)))
                            ])),
                ],
              ],
              if (loadingCards)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                    child: Text('feed.streamers'.tr(),
                        style: Theme.of(context).textTheme.titleSmall))
              else
                heading('feed.streamers'.tr(), displayed.length),
              if (loadingCards)
                const DiscoveryCardSkeletonGrid()
              else if (displayed.isEmpty)
                CaEmptyState(
                    title: 'feed.no_results'.tr(),
                    body: 'feed.search_feed'.tr(),
                    action: CaButton(
                        label: 'feed.clear_search'.tr(),
                        variant: CaButtonVariant.text,
                        onPressed: _clearSearch))
              else
                LayoutBuilder(builder: (context, constraints) {
                  // Master's column rule, kept on purpose: one card per row on
                  // a phone, up to four on a laptop (never a forced pair).
                  final columns =
                      (constraints.maxWidth / 300).floor().clamp(1, 4);
                  final width = ((constraints.maxWidth -
                              AppTheme.spaceMd * (columns - 1)) /
                          columns)
                      .clamp(0.0, 420.0);
                  final signature = Object.hash(
                      constraints.maxWidth,
                      lang,
                      MediaQuery.textScalerOf(context).scale(1),
                      Object.hashAll(displayed));
                  if (_cardLayoutSignature != signature) {
                    _cardLayoutSignature = signature;
                    _cardMinHeight = 0;
                    _cardKeys =
                        List.generate(displayed.length, (_) => GlobalKey());
                  }
                  _measureCardHeights();
                  return Wrap(
                      spacing: AppTheme.spaceMd,
                      runSpacing: AppTheme.spaceMd,
                      children: [
                        for (var i = 0; i < displayed.length; i++)
                          SizedBox(
                              width: width,
                              child: NotificationListener<
                                      SizeChangedLayoutNotification>(
                                  onNotification: (_) {
                                    _measureCardHeights();
                                    return false;
                                  },
                                  child: SizeChangedLayoutNotifier(
                                      child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                              minHeight: _cardMinHeight),
                                          child: _firstPaint(
                                              StreamerGridCard(
                                                  key: _cardKeys[i],
                                                  streamer: displayed[i],
                                                  langCode: lang),
                                              i + 1))))),
                      ]);
                }),
            ])));
  }
}
