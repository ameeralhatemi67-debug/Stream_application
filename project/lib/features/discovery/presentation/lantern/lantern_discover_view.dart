import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../lessons/domain/lessons_dates.dart';
import '../../../lessons/domain/lessons_models.dart';
import '../../../lessons/presentation/lessons_widgets.dart'
    show openLesson, placeOf, typeLabel, whenOf;
import '../../../lessons/state/lessons_controller.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../profile/models/upcoming_schedule.dart';
import '../../models/academic_category_model.dart';
import 'lantern_stream_cards.dart';

/// A planned broadcast of a channel that is not live now.
typedef LanternSoon = ({
  StreamerModel streamer,
  UpcomingSchedule schedule,
  DateTime start
});

/// Discover in Lantern and Arch. It answers "is anything on now?" in one
/// glance and offers the next best thing when nothing is: a night hero with
/// the featured room and the rooms that are also live, a pinned subject bar,
/// Live now, Starting soon, scholars and channels, this week's mosque
/// lessons and the map.
///
/// The screen that owns the data is `DiscoveryFeedScreen`; this view only
/// draws what it is given and calls back.
class LanternDiscoverView extends StatelessWidget implements LanternSkinWidget {
  const LanternDiscoverView(
      {super.key,
      required this.displayed,
      required this.live,
      required this.categories,
      required this.selectedCategory,
      required this.onCategory,
      required this.searchController,
      required this.searchFocus,
      required this.onSearchChanged,
      required this.onClearSearch,
      required this.onFilters,
      required this.tagActive,
      required this.loading,
      required this.onRefresh,
      required this.soon,
      required this.nextLive,
      required this.onRemind,
      required this.ownLiveId,
      required this.totalChannels});

  final List<StreamerModel> displayed, live;
  final List<AcademicCategoryModel> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategory;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch, onFilters;
  final bool tagActive, loading;
  final Future<void> Function() onRefresh;
  final List<LanternSoon> soon;
  final Map<String, DateTime> nextLive;

  /// Null when this build cannot deliver reminders.
  final void Function(StreamerModel streamer)? onRemind;

  /// The signed-in broadcaster's own room while they are live.
  final String? ownLiveId;
  final int totalChannels;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    final gutter = wide ? Lantern.webGutter : Lantern.gutter;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    Widget section(Widget child, {double top = 36}) => SliverToBoxAdapter(
        child: _Column(
            gutter: gutter,
            child: Padding(padding: EdgeInsets.only(top: top), child: child)));
    final filtering = searchController.text.trim().isNotEmpty ||
        selectedCategory != 'all' ||
        tagActive;
    return ColoredBox(
        color: t.bg,
        child: RefreshIndicator(
            onRefresh: onRefresh,
            color: LanternTokens.gold,
            backgroundColor: t.surface,
            child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                      child: _Hero(
                          live: live,
                          loading: loading,
                          topics: categories.where((c) => c.isActive).length,
                          channels: totalChannels,
                          ownLiveId: ownLiveId)),
                  SliverPersistentHeader(
                      pinned: true,
                      delegate: _SubjectBar(
                          height: (wide ? 66 : 112) * scale,
                          wide: wide,
                          gutter: gutter,
                          background: t.bg,
                          line: t.line,
                          categories: categories,
                          selected: selectedCategory,
                          onCategory: onCategory,
                          controller: searchController,
                          focus: searchFocus,
                          onChanged: onSearchChanged,
                          onClear: onClearSearch,
                          onFilters: onFilters,
                          tagActive: tagActive,
                          lang: context.locale.languageCode)),
                  const SliverToBoxAdapter(child: _Connectivity()),
                  if (loading)
                    section(const _LoadingGrid())
                  else if (displayed.isEmpty)
                    section(LEmptyState(
                        title: 'feed.no_results'.tr(),
                        icon: LGlyph.search,
                        action: filtering
                            ? LButton(
                                label: 'feed.clear_search'.tr(),
                                kind: LButtonKind.tonal,
                                onPressed: () {
                                  onClearSearch();
                                  onCategory('all');
                                })
                            : null))
                  else ...[
                    if (live.isNotEmpty)
                      section(Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LSectionHead('web.sec_live'.tr(),
                                count: 'lantern.discover.live_count_label'
                                    .tr(args: ['${live.length}'])),
                            const SizedBox(height: 18),
                            _Grid(wideColumns: 3, children: [
                              for (final s in live) LanternLiveCard(s),
                            ]),
                          ])),
                    if (soon.isNotEmpty)
                      section(Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LSectionHead('lantern.discover.soon_title'.tr(),
                                subtitle: 'lantern.discover.soon_sub'.tr(),
                                isNew: true),
                            const SizedBox(height: 18),
                            _Grid(wideColumns: 3, children: [
                              for (final e in soon)
                                LanternSoonCard(
                                    streamer: e.streamer,
                                    schedule: e.schedule,
                                    start: e.start,
                                    onRemind: onRemind == null
                                        ? null
                                        : () => onRemind!(e.streamer)),
                            ]),
                          ])),
                    section(Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LSectionHead('web.sec_channels'.tr(),
                              count: '${displayed.length}',
                              action: 'web.nav_orgs'.tr(),
                              onAction: () => context.push('/organizations')),
                          const SizedBox(height: 18),
                          _Grid(wideColumns: 4, children: [
                            for (final s in displayed)
                              LanternChannelCard(s,
                                  nextLive: nextLive[s.streamerId]),
                          ]),
                        ])),
                  ],
                  SliverToBoxAdapter(child: _LessonsRail(gutter: gutter)),
                  section(_MapTeaser(streamers: displayed)),
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.only(top: 44),
                          child: wide
                              ? const LanternWebFooter()
                              : SizedBox(height: bottom + 8))),
                ])));
  }
}

/// The content column: 1200 wide on the website layout, with the gutters.
class _Column extends StatelessWidget {
  const _Column({required this.child, required this.gutter});

  final Widget child;
  final double gutter;

  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: Lantern.webContent + gutter * 2),
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: child)));
}

/// Cards in equal columns: [wideColumns] from 1024, two from 640, else one.
class _Grid extends StatelessWidget {
  const _Grid({required this.children, required this.wideColumns});

  final List<Widget> children;
  final int wideColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const gap = 16.0;
        final columns = box.maxWidth >= 960
            ? wideColumns
            : box.maxWidth >= 600
                ? 2
                : 1;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final child in children) SizedBox(width: width, child: child),
        ]);
      });
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) => Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: _Grid(wideColumns: 3, children: [
        for (var i = 0; i < 6; i++)
          const LCard(
              padding: EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                        aspectRatio: 16 / 9, child: LSkeleton(radius: 16)),
                    SizedBox(height: 14),
                    LSkeleton(width: 180, height: 16),
                    SizedBox(height: 8),
                    LSkeleton(width: 120),
                  ])),
      ]));
}

/// Offline or slow: what the banner of the older designs says, as a Lantern
/// banner with Try again.
class _Connectivity extends StatefulWidget {
  const _Connectivity();

  @override
  State<_Connectivity> createState() => _ConnectivityState();
}

class _ConnectivityState extends State<_Connectivity> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final provider = context.read<AppProvider>();
    final online = await provider.refreshConnectivityNow();
    if (online) {
      await provider.loadVerifiedStreamersFromBackend();
      await provider.ensureAcademicCategoriesLoaded();
    }
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final (status, cached) = context.select<AppProvider, (NetworkStatus, bool)>(
        (p) => (p.networkStatus, p.isUsingCachedCatalog));
    if (status == NetworkStatus.online && !cached) {
      return const SizedBox.shrink();
    }
    final title = switch (status) {
      NetworkStatus.offline => 'offline_experience.offline_title',
      NetworkStatus.degraded => 'offline_experience.degraded_title',
      NetworkStatus.online => 'offline_experience.cached_title',
    };
    return _Column(
        gutter: context.lanternWide ? Lantern.webGutter : Lantern.gutter,
        child: Padding(
            key: const ValueKey('lantern-connectivity'),
            padding: const EdgeInsets.only(top: 16),
            child: LBanner(
                '${title.tr()}. ${'offline_experience.body'.tr()}',
                tone: LTone.warn,
                icon: LGlyph.wifioff,
                busy: _retrying,
                action: LButton(
                    label: 'offline_experience.retry'.tr(),
                    kind: LButtonKind.tonal,
                    size: LButtonSize.small,
                    onPressed: _retrying ? null : _retry))));
  }
}

/// The night hero: the promise, two ways in, three numbers, and the featured
/// room with the rooms that are also live (or the quiet card).
class _Hero extends StatelessWidget {
  const _Hero(
      {required this.live,
      required this.loading,
      required this.topics,
      required this.channels,
      required this.ownLiveId});

  final List<StreamerModel> live;
  final bool loading;
  final int topics, channels;
  final String? ownLiveId;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= Lantern.webMinWidth;
    final twoColumns = width >= 720;
    final gutter = wide ? Lantern.webGutter : Lantern.gutter;
    return LNightBand(
        latticeOpacity: .1,
        glow: AlignmentDirectional(wide ? .7 : -.6, -.2)
            .resolve(Directionality.of(context)),
        child: Builder(builder: (context) {
          final t = context.lt;
          final ar = context.lanternArabic;
          final first = live.isEmpty ? null : live.first;
          final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ownLiveId != null) ...[
                  LBanner('lantern.discover.you_are_live'.tr(),
                      tone: LTone.live,
                      icon: LGlyph.live,
                      action: LButton(
                          label: 'lantern.discover.back_to_room'.tr(),
                          kind: LButtonKind.danger,
                          size: LButtonSize.small,
                          onPressed: () => context.push('/live/$ownLiveId'))),
                  const SizedBox(height: 18),
                ],
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const LStar(size: 11, color: LanternTokens.goldHi),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text('web.hero_eyebrow'.tr(),
                          style: Lantern.textStyle(13.5,
                              color: LanternTokens.goldHi,
                              weight: FontWeight.w600,
                              height: 1.4))),
                ]),
                const SizedBox(height: 14),
                Semantics(
                    header: true,
                    child: Text('web.hero_title'.tr(),
                        style: Lantern.displayStyle(
                            wide
                                ? 44
                                : twoColumns
                                    ? 30
                                    : 34,
                            color: const Color(0xFFFBF7ED),
                            height: ar ? 1.35 : 1.14))),
                const SizedBox(height: 14),
                Text('web.hero_lead'.tr(),
                    style: Lantern.textStyle(wide ? 17 : 15.5,
                        color: const Color(0xFFC9D1D8), height: 1.6)),
                SizedBox(height: wide ? 26 : 20),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _Stretch(
                      stretch: !twoColumns,
                      child: LButton(
                          label: 'web.hero_watch'.tr(),
                          icon: LGlyph.live,
                          size: LButtonSize.large,
                          expand: !twoColumns,
                          onPressed: first == null
                              ? null
                              : () => lanternOpenRoom(context, first))),
                  _Stretch(
                      stretch: !twoColumns,
                      child: LButton(
                          label: 'web.hero_map'.tr(),
                          icon: LGlyph.map,
                          kind: LButtonKind.secondary,
                          size: LButtonSize.large,
                          expand: !twoColumns,
                          onPressed: () => context.go('/map'))),
                ]),
                SizedBox(height: wide ? 30 : 22),
                Container(height: 1, color: const Color(0x1FFFFFFF)),
                SizedBox(height: wide ? 22 : 16),
                Wrap(spacing: wide ? 36 : 22, runSpacing: 12, children: [
                  // Plural keys, so Arabic agrees with the number.
                  _Stat(live.length, 'web.stat_live'.plural(live.length)),
                  _Stat(channels, 'web.stat_channels'.plural(channels)),
                  _Stat(topics, 'web.stat_topics'.plural(topics)),
                ]),
              ]);
          final feature = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const AspectRatio(
                      aspectRatio: 16 / 10, child: LSkeleton(radius: 24))
                else if (first == null)
                  const _Quiet()
                else
                  _Featured(first),
                if (live.length > 1) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Text('lantern.discover.also_live'.tr(),
                        style: Lantern.textStyle(12.5,
                            color: t.muted, weight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    const LTag('NEW', tone: LTone.gold),
                  ]),
                  const SizedBox(height: 8),
                  for (final s in live.skip(1).take(2))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AlsoLive(s)),
                ],
              ]);
          return SafeArea(
              top: false,
              bottom: false,
              child: Center(
                  child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: Lantern.webContent + gutter * 2),
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              gutter, wide ? 56 : 30, gutter, wide ? 60 : 34),
                          child: twoColumns
                              ? Row(children: [
                                  Expanded(flex: 21, child: copy),
                                  SizedBox(width: wide ? 48 : 26),
                                  Expanded(flex: 20, child: feature),
                                ])
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                      copy,
                                      const SizedBox(height: 28),
                                      feature,
                                    ])))));
        }));
  }
}

class _Stretch extends StatelessWidget {
  const _Stretch({required this.child, required this.stretch});

  final Widget child;
  final bool stretch;

  @override
  Widget build(BuildContext context) =>
      stretch ? SizedBox(width: double.infinity, child: child) : child;
}

/// A number that counts up once (0.8 s), with its label under it.
class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final calm = Lantern.calm(context);
    return Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                  tween: Tween(begin: calm ? value.toDouble() : 0, end: value.toDouble()),
                  duration: calm
                      ? Lantern.none
                      : const Duration(milliseconds: 800),
                  curve: Lantern.ease,
                  builder: (context, v, _) => Text('${v.round()}',
                      style: Lantern.displayStyle(26,
                              color: LanternTokens.goldHi, height: 1.2)
                          .copyWith(fontFeatures: Lantern.tabular))),
              Text(label,
                  style: Lantern.textStyle(13,
                      color: const Color(0xFFAEB9C2), height: 1.4)),
            ]));
  }
}

/// The featured room: its picture with a play disc, then who and Watch.
class _Featured extends StatelessWidget {
  const _Featured(this.streamer);

  final StreamerModel streamer;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final s = streamer;
    final title = s.getLocalizedTitle(lang);
    return LCard(
        padding: EdgeInsets.zero,
        label: 'lantern.discover.open_room'.tr(args: [title]),
        onTap: () => lanternOpenRoom(context, s),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LanternStage(
              tone: s.isAudioLive
                  ? LanternStageTone.audio
                  : LanternStageTone.live,
              image: resolveImageProviderOrNull(s.bannerUrl),
              topStart: LanternStateBadge(s),
              topEnd: LanternViewers(s),
              center: s.isAudioLive
                  ? const LanternWaveform()
                  : Container(
                      width: 66,
                      height: 66,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: const Color(0x8C0B1117),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x33FFFFFF))),
                      child: const LIcon(LGlyph.play,
                          size: 28, color: LanternTokens.white))),
          Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                LanternChannelAvatar(s, size: 48),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(15.5,
                              color: t.fg,
                              weight: FontWeight.w700,
                              height: 1.4)),
                      Text(
                          [
                            s.getLocalizedName(lang),
                            s.getLocalizedVenue(lang)
                          ].where((v) => v.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(13,
                              color: t.muted, height: 1.4)),
                    ])),
                const SizedBox(width: 10),
                ExcludeSemantics(
                    child: IgnorePointer(
                        child: LButton(
                            label: (s.isAudioLive ? 'web.listen' : 'web.watch')
                                .tr(),
                            icon: s.isAudioLive ? LGlyph.audio : LGlyph.live,
                            size: LButtonSize.small,
                            onPressed: () {}))),
              ])),
        ]));
  }
}

/// A room that is also live, as one row under the featured card.
class _AlsoLive extends StatelessWidget {
  const _AlsoLive(this.streamer);

  final StreamerModel streamer;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final s = streamer;
    final count = context.select<AppProvider, int?>(
        (p) => p.platformViewerCount(s.activeStreamId ?? ''));
    final title = s.getLocalizedTitle(lang);
    return LPressable(
        onTap: () => lanternOpenRoom(context, s),
        label: 'lantern.discover.open_room'.tr(args: [title]),
        radius: Lantern.radiusRow,
        pressScale: .985,
        excludeChildSemantics: true,
        builder: (context, state) => AnimatedContainer(
            duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: Color(state.hovered ? 0x1AFFFFFF : 0x0DFFFFFF),
                borderRadius: BorderRadius.circular(Lantern.radiusRow),
                border: Border.all(color: const Color(0x14FFFFFF))),
            child: Row(children: [
              LanternChannelAvatar(s, size: 38),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lantern.textStyle(14.5,
                            color: t.fg,
                            weight: FontWeight.w600,
                            height: 1.35)),
                    Text(
                        '${s.getLocalizedName(lang)} · ${lanternCount(count)} ${(s.isAudioLive ? 'web.listening' : 'web.watching').tr()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lantern.textStyle(12.5,
                            color: t.muted, height: 1.4)),
                  ])),
              const SizedBox(width: 10),
              LanternStateBadge(s, small: true),
            ])));
  }
}

/// Nothing is live: the arch breathes, and the page says what to do next.
class _Quiet extends StatefulWidget {
  const _Quiet();

  @override
  State<_Quiet> createState() => _QuietState();
}

class _QuietState extends State<_Quiet> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Lantern.calm(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('lantern-discover-quiet'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B252E), LanternTokens.nightGround]),
          borderRadius: BorderRadius.circular(Lantern.radiusDialog),
          border: Border.all(color: const Color(0xFF27323C))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.12).animate(
                CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
            child: const SizedBox(
                width: 64,
                height: 76,
                child: DecoratedBox(
                    decoration: ShapeDecoration(
                        shape: LArchBorder(
                            side: BorderSide(
                                color: LanternTokens.gold, width: 2),
                            bottom: 10)),
                    child: Center(
                        child:
                            LStar(size: 22, color: LanternTokens.goldHi))))),
        const SizedBox(height: 18),
        Text('web.hero_none_title'.tr(),
            textAlign: TextAlign.center,
            style: Lantern.displayStyle(21,
                color: const Color(0xFFFBF7ED),
                height: context.lanternArabic ? 1.45 : 1.3)),
        const SizedBox(height: 8),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text('web.hero_none_body'.tr(),
                textAlign: TextAlign.center,
                style: Lantern.textStyle(14.5,
                    color: const Color(0xFFAEB9C2)))),
      ]));
}

/// The pinned bar under the header: search, Advanced filters and the subject
/// tabs with a gold underline on the chosen one.
class _SubjectBar extends SliverPersistentHeaderDelegate {
  _SubjectBar(
      {required this.height,
      required this.wide,
      required this.gutter,
      required this.background,
      required this.line,
      required this.categories,
      required this.selected,
      required this.onCategory,
      required this.controller,
      required this.focus,
      required this.onChanged,
      required this.onClear,
      required this.onFilters,
      required this.tagActive,
      required this.lang});

  final double height, gutter;
  final bool wide, tagActive;
  final Color background, line;
  final List<AcademicCategoryModel> categories;
  final String selected, lang;
  final ValueChanged<String> onCategory, onChanged;
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onClear, onFilters;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  bool shouldRebuild(_SubjectBar old) =>
      old.height != height ||
      old.wide != wide ||
      old.selected != selected ||
      old.tagActive != tagActive ||
      old.categories != categories ||
      old.background != background ||
      old.lang != lang;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = context.lt;
    final tabs = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _SubjectTab(
              label: 'feed.category_all'.tr(),
              selected: selected == 'all',
              onTap: () => onCategory('all')),
          for (final c in categories.where((c) => c.isActive))
            _SubjectTab(
                label: c.getLocalizedName(lang),
                selected: selected == c.id,
                onTap: () => onCategory(selected == c.id ? 'all' : c.id)),
        ]));
    final search = ListenableBuilder(
        listenable: controller,
        builder: (context, _) => LField(
            controller: controller,
            focusNode: focus,
            hint: 'feed.search_feed'.tr(),
            icon: LGlyph.search,
            pill: true,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            trailing: controller.text.isEmpty
                ? null
                : LIconButton(
                    icon: LGlyph.close,
                    label: 'feed.clear_search'.tr(),
                    size: 40,
                    iconSize: 16,
                    onPressed: onClear)));
    final filters = LButton(
        label: 'feed.filters'.tr() + (tagActive ? ' • 1' : ''),
        icon: LGlyph.filter,
        kind: LButtonKind.tonal,
        size: LButtonSize.small,
        onPressed: onFilters);
    return Material(
        color: background.withValues(alpha: .96),
        child: DecoratedBox(
            decoration:
                BoxDecoration(border: Border(bottom: BorderSide(color: line))),
            child: Center(
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: Lantern.webContent + gutter * 2),
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        child: wide
                            ? Row(children: [
                                Expanded(child: tabs),
                                const SizedBox(width: 14),
                                SizedBox(width: 280, child: search),
                                const SizedBox(width: 10),
                                filters,
                              ])
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    Row(children: [
                                      Expanded(child: search),
                                      const SizedBox(width: 8),
                                      LIconButton(
                                          icon: LGlyph.filter,
                                          label: 'feed.filters'.tr() +
                                              (tagActive ? ' • 1' : ''),
                                          on: tagActive,
                                          color: t.goldInk,
                                          onPressed: onFilters),
                                    ]),
                                    const SizedBox(height: 4),
                                    tabs,
                                  ]))))));
  }
}

class _SubjectTab extends StatelessWidget {
  const _SubjectTab(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return LPressable(
        onTap: onTap,
        label: label,
        selected: selected,
        radius: 10,
        pressScale: 1,
        excludeChildSemantics: true,
        builder: (context, s) => Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color:
                            selected ? LanternTokens.gold : Colors.transparent,
                        width: 3))),
            alignment: Alignment.center,
            child: Text(label,
                maxLines: 1,
                style: Lantern.textStyle(14.5,
                    color: selected || s.hovered ? t.fg : t.muted,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.3))));
  }
}

/// This week's mosque lessons as a row that scrolls sideways. Hidden when
/// there are none (or when the lessons programme is not loaded).
class _LessonsRail extends StatefulWidget {
  const _LessonsRail({required this.gutter});

  final double gutter;

  @override
  State<_LessonsRail> createState() => _LessonsRailState();
}

class _LessonsRailState extends State<_LessonsRail> {
  @override
  void initState() {
    super.initState();
    context.read<LessonsController?>()?.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final ids = context.select<LessonsController?, List<String>>((c) {
      if (c == null) return const [];
      final end = addDays(c.today, 6);
      return [
        for (final l in c.upcoming.where((l) => !l.date.isAfter(end)).take(8))
          l.id
      ];
    });
    if (ids.isEmpty) return const SizedBox.shrink();
    final c = context.read<LessonsController>();
    final lessons = [for (final id in ids) c.lesson(id)!];
    return Padding(
        key: const ValueKey('lantern-discover-lessons'),
        padding: const EdgeInsets.only(top: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Column(
              gutter: widget.gutter,
              child: LSectionHead('feed.lessons_week'.tr(),
                  subtitle: 'lantern.discover.lessons_sub'.tr(),
                  action: 'lessons.see_all'.tr(),
                  onAction: () => context.go('/lessons'))),
          const SizedBox(height: 14),
          Center(
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: Lantern.webContent + widget.gutter * 2),
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.fromLTRB(
                          widget.gutter, 4, widget.gutter, 12),
                      child: IntrinsicHeight(
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            for (final (i, l) in lessons.indexed) ...[
                              if (i > 0) const SizedBox(width: 14),
                              SizedBox(width: 292, child: _LessonCard(l)),
                            ],
                          ]))))),
        ]));
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard(this.lesson);

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final c = context.watch<LessonsController>();
    final lang = context.locale.languageCode;
    final l = lesson;
    final preacher = c.preacher(l.preacherId);
    final liveNow = c.isLiveNow(l);
    Widget meta(LGlyph glyph, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          LIcon(glyph, size: 15, color: t.goldInk),
          const SizedBox(width: 7),
          Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(13, color: t.muted, height: 1.4))),
        ]));
    return LCard(
        onTap: () => openLesson(context, l.id),
        label: l.title(lang),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                    width: 38,
                    height: 42,
                    alignment: const Alignment(0, .3),
                    decoration: ShapeDecoration(
                        color: t.sunk,
                        shape: const LArchBorder(
                            side: BorderSide(color: LanternTokens.gold),
                            bottom: 6)),
                    child: LIcon(LGlyph.mosque, size: 18, color: t.goldInk)),
                const SizedBox(width: 10),
                Expanded(
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                  LTag(typeLabel(l.type)),
                  if (liveNow)
                    LTag('web.badge_live'.tr(),
                        tone: LTone.live, icon: LGlyph.live),
                ])),
              ]),
              const SizedBox(height: 12),
              Text(l.title(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(15.5,
                      color: t.fg, weight: FontWeight.w700, height: 1.45)),
              if (preacher != null)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(preacher.name(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lantern.textStyle(13.5,
                            color: t.muted, height: 1.4))),
              meta(LGlyph.clock, whenOf(c, l, lang)),
              meta(LGlyph.pin, placeOf(c, l, lang)),
            ]));
  }
}

/// The map as an invitation: what it is, one button, and a small drawn map
/// with a pin for every channel that has a place.
class _MapTeaser extends StatelessWidget {
  const _MapTeaser({required this.streamers});

  final List<StreamerModel> streamers;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final pins = [
      for (final s in streamers)
        if (s.latitude != 0 || s.longitude != 0)
          (s.latitude, s.longitude, s.isAudioLive ? 2 : s.isCurrentlyLive ? 1 : 0)
    ];
    final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            LStar(size: 11, color: t.goldInk),
            const SizedBox(width: 8),
            Text('web.nav_map'.tr(),
                style: Lantern.textStyle(13.5,
                    color: t.goldInk, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          Semantics(
              header: true,
              child: Text('web.map_title'.tr(),
                  style: Lantern.displayStyle(wide ? 28 : 24,
                      color: t.fg,
                      height: context.lanternArabic ? 1.4 : 1.2))),
          const SizedBox(height: 8),
          Text('web.map_body'.tr(),
              style: Lantern.textStyle(15, color: t.muted)),
          const SizedBox(height: 18),
          Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LButton(
                    label: 'web.hero_map'.tr(),
                    icon: LGlyph.map,
                    onPressed: () => context.go('/map')),
                if (pins.isNotEmpty)
                  LTag(
                      'lantern.discover.map_pins'.tr(args: ['${pins.length}']),
                      tone: LTone.gold,
                      icon: LGlyph.pin),
              ]),
        ]);
    final map = LPressable(
        onTap: () => context.go('/map'),
        label: 'web.hero_map'.tr(),
        radius: Lantern.radiusCard,
        pressScale: .99,
        excludeChildSemantics: true,
        builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(Lantern.radiusCard),
            child: AspectRatio(
                aspectRatio: wide ? 16 / 9 : 16 / 10,
                child: CustomPaint(
                    painter: _MiniMapPainter(pins,
                        night: t.night,
                        rtl: Directionality.of(context) ==
                            TextDirection.rtl)))));
    return Container(
        key: const ValueKey('lantern-discover-map'),
        padding: EdgeInsets.all(wide ? 28 : 18),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: t.line),
            boxShadow: t.shadow),
        child: wide
            ? Row(children: [
                Expanded(flex: 10, child: copy),
                const SizedBox(width: 28),
                Expanded(flex: 11, child: map),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 18), map]));
  }
}

/// A drawn map of the coast: land, the Gulf, the main road and the real
/// pins, placed by their coordinates inside the three cities' bounds.
class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.pins, {required this.night, required this.rtl});

  final List<(double, double, int)> pins;
  final bool night, rtl;

  // Al Khobar, Dhahran and Dammam.
  static const _south = 26.15, _north = 26.52, _west = 49.95, _east = 50.26;

  @override
  void paint(Canvas canvas, Size size) {
    final land = night ? const Color(0xFF1B252E) : const Color(0xFFF0E8D8);
    final sea = night ? const Color(0xFF12303A) : const Color(0xFFCADDE2);
    final road = night ? const Color(0xFF2C3944) : const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    // The Gulf is to the east.
    final coast = Path()
      ..moveTo(size.width * .72, 0)
      ..cubicTo(size.width * .8, size.height * .3, size.width * .7,
          size.height * .55, size.width * .86, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(coast, Paint()..color = sea);
    final thin = Paint()
      ..color = road
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final f in [.22, .44, .6]) {
      canvas.drawLine(Offset(size.width * f, 0),
          Offset(size.width * (f + .04), size.height), thin);
      canvas.drawLine(Offset(0, size.height * f),
          Offset(size.width * .78, size.height * (f + .03)), thin);
    }
    canvas.drawPath(
        Path()
          ..moveTo(size.width * .06, size.height * .3)
          ..cubicTo(size.width * .35, size.height * .34, size.width * .55,
              size.height * .6, size.width * .74, size.height * .96),
        Paint()
          ..color = LanternTokens.goldHi.withValues(alpha: night ? .5 : .9)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
    for (final (lat, lng, state) in pins) {
      final x = ((lng - _west) / (_east - _west)).clamp(.06, .7);
      final y = (1 - (lat - _south) / (_north - _south)).clamp(.1, .9);
      final at = Offset(size.width * x, size.height * y);
      final fill = state == 1
          ? const Color(0xFFC2343F)
          : state == 2
              ? const Color(0xFF2D6F86)
              : LanternTokens.gold;
      canvas
        ..drawCircle(at, 8, Paint()..color = LanternTokens.white)
        ..drawCircle(at, 6, Paint()..color = fill);
    }
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) =>
      old.night != night || old.pins.length != pins.length;
}

/// Sorts out which channels go live soon, for the Starting soon section.
List<LanternSoon> lanternSoonOf(
    List<StreamerModel> displayed,
    Map<String, ({UpcomingSchedule schedule, DateTime start})> next,
    DateTime now,
    {int limit = 6}) {
  final horizon = now.add(const Duration(days: 7));
  final out = <LanternSoon>[
    for (final s in displayed)
      if (!s.isCurrentlyLive)
        if (next[s.streamerId] case final n?)
          if (n.start.isBefore(horizon))
            (streamer: s, schedule: n.schedule, start: n.start)
  ]..sort((a, b) => a.start.compareTo(b.start));
  return out.take(math.max(0, limit)).toList();
}
