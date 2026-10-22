import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_feedback.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../taysir/presentation/taysir_in_hadayah.dart';
import '../../../web/presentation/hidayah_web_header.dart';
import '../../../web/presentation/hidayah_web_kit.dart';
import '../../models/academic_category_model.dart';
import '../widgets/discovery_card_skeleton.dart';

/// Discovery as a website (gold palette, laptop): a night hero with the
/// featured live lecture, an underline category bar with search, "Live now",
/// "Scholars and channels", a map teaser and the site footer.
class DiscoveryWebView extends StatelessWidget {
  const DiscoveryWebView(
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
      required this.loading});
  final List<StreamerModel> displayed, live;
  final List<AcademicCategoryModel> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategory;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch, onFilters;
  final bool tagActive, loading;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return Material(
        color: HidayahGold.g50,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Hero(live: live, total: displayed.length, topics: categories.where((c) => c.isActive).length)),
          SliverToBoxAdapter(
              child: _CategoryBar(
                  categories:
                      categories.where((c) => c.isActive).toList(),
                  selected: selectedCategory,
                  onCategory: onCategory,
                  controller: searchController,
                  focus: searchFocus,
                  onChanged: onSearchChanged,
                  onClear: onClearSearch,
                  onFilters: onFilters,
                  tagActive: tagActive,
                  lang: lang)),
          SliverToBoxAdapter(
              child: HidayahWebWidth(
                  child: Padding(
                      padding: const EdgeInsets.only(top: 44, bottom: 56),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (live.isNotEmpty) ...[
                              HidayahSectionHeader(
                                  title: 'web.sec_live'.tr(),
                                  count: live.length),
                              _Grid(
                                  columns: 3,
                                  children: [
                                    for (final s in live)
                                      _LiveCard(streamer: s, categories: categories)
                                  ]),
                              const SizedBox(height: 44),
                            ],
                            HidayahSectionHeader(
                                title: 'web.sec_channels'.tr(),
                                count: loading ? null : displayed.length),
                            if (loading)
                              const DiscoveryCardSkeletonGrid()
                            else if (displayed.isEmpty)
                              HidayahCard(
                                  padding: const EdgeInsets.all(24),
                                  child: CaEmptyState(
                                      title: 'feed.no_results'.tr(),
                                      body: 'feed.search_feed'.tr(),
                                      action: CaButton(
                                          label: 'feed.clear_search'.tr(),
                                          variant: CaButtonVariant.text,
                                          onPressed: onClearSearch)))
                            else
                              // Three per row: wider channel cards on laptops.
                              _Grid(columns: 3, children: [
                                for (final s in displayed)
                                  _ScholarCard(
                                      streamer: s, categories: categories)
                              ]),
                            // Mosque lessons this week (Taysir), when any.
                            const TaysirLessonsRail(web: true),
                            const SizedBox(height: 44),
                            MapPreviewCard(
                                title: 'web.map_title'.tr(),
                                body: 'web.map_body'.tr(),
                                streamers: displayed),
                          ])))),
          const SliverToBoxAdapter(child: HidayahWebFooter()),
        ]));
  }
}

/// Rows of equal-height cards; the last row keeps empty slots so card widths
/// never stretch.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    const gap = 20.0;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(
          i, (i + columns).clamp(0, children.length));
      rows.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
          child: IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: gap),
                  Expanded(
                      child: c < slice.length ? slice[c] : const SizedBox()),
                ]
              ]))));
    }
    return Column(children: rows);
  }
}

bool _isLiveNow(BuildContext context, StreamerModel s) {
  final (status, cached) = context.select<AppProvider, (NetworkStatus, bool)>(
      (p) => (p.networkStatus, p.isUsingCachedCatalog));
  return !cached && status == NetworkStatus.online && s.isCurrentlyLive;
}

void _openLive(BuildContext context, StreamerModel s) {
  final id = s.activeStreamId ?? s.liveSessionId;
  if (id != null) context.push('/live/$id');
}

void _openChannel(BuildContext context, StreamerModel s, bool live) =>
    context.push(live
        ? '/live/${s.liveSessionId ?? s.streamerId}'
        : '/profile/${s.channelProfileId}');

String _categoryName(List<AcademicCategoryModel> categories, String id,
        String lang) =>
    categories.where((c) => c.id == id).firstOrNull?.getLocalizedName(lang) ??
    '';

class _Hero extends StatelessWidget {
  const _Hero({required this.live, required this.total, required this.topics});
  final List<StreamerModel> live;
  final int total, topics;
  @override
  Widget build(BuildContext context) {
    // The label agrees with the number in Arabic (plural forms, audit 5.3).
    Widget stat(int value, String key) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: HidayahText.display(30, color: HidayahGold.g300)),
              const SizedBox(height: 4),
              Text(key.plural(value),
                  style: HidayahText.body(13, color: HidayahGold.s300)),
            ]);
    return HidayahNightBand(
        child: HidayahWebWidth(
            child: Padding(
                padding: const EdgeInsets.only(top: 56, bottom: 52),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                          flex: 100,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                      width: 28,
                                      height: 2,
                                      decoration: const BoxDecoration(
                                          gradient: HidayahGradients.gilded)),
                                  const SizedBox(width: 10),
                                  Flexible(
                                      child: Text(
                                          HidayahText.upper(
                                              context, 'web.hero_eyebrow'.tr()),
                                          style: HidayahText.eyebrow(
                                              context, HidayahGold.g300))),
                                ]),
                                const SizedBox(height: 16),
                                Text('web.hero_title'.tr(),
                                    style: HidayahText.display(44,
                                        color: HidayahGold.g50)),
                                const SizedBox(height: 16),
                                ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 460),
                                    child: Text('web.hero_lead'.tr(),
                                        style: HidayahText.body(17,
                                            color: HidayahGold.s200))),
                                const SizedBox(height: 28),
                                Wrap(spacing: 12, runSpacing: 12, children: [
                                  if (live.isNotEmpty)
                                    HidayahButton(
                                        label: 'web.hero_watch'.tr(),
                                        icon: live.first.isAudioLive
                                            ? CaGlyph.mic
                                            : CaGlyph.play,
                                        onPressed: () =>
                                            _openLive(context, live.first)),
                                  HidayahButton(
                                      label: 'web.hero_map'.tr(),
                                      icon: CaGlyph.map,
                                      kind: HidayahButtonKind.onDark,
                                      onPressed: () => context.go('/map')),
                                ]),
                                const SizedBox(height: 34),
                                Container(
                                    padding: const EdgeInsets.only(top: 22),
                                    decoration: BoxDecoration(
                                        border: Border(
                                            top: BorderSide(
                                                color: HidayahGold.g300
                                                    .withValues(alpha: .18)))),
                                    child: Wrap(spacing: 34, children: [
                                      stat(live.length, 'web.stat_live'),
                                      stat(total, 'web.stat_channels'),
                                      stat(topics, 'web.stat_topics'),
                                    ])),
                              ])),
                      const SizedBox(width: 56),
                      Expanded(
                          flex: 108,
                          child: live.isEmpty
                              ? const _QuietFeature()
                              : _FeaturedLive(live: live)),
                    ]))));
  }
}

class _FeaturedLive extends StatelessWidget {
  const _FeaturedLive({required this.live});
  final List<StreamerModel> live;
  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final s = live.first;
    final viewers = context.select<AppProvider, int?>(
        (p) => p.platformViewerCount(s.activeStreamId ?? ''));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Semantics(
          button: true,
          label: s.getLocalizedTitle(lang),
          child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                  onTap: () => _openLive(context, s),
                  child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: HidayahGold.g300.withValues(alpha: .22)),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0xCC000000),
                                    blurRadius: 60,
                                    spreadRadius: -30,
                                    offset: Offset(0, 30))
                              ]),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: Stack(fit: StackFit.expand, children: [
                                CaCardImage(url: s.bannerUrl),
                                const DecoratedBox(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: [0, .45, 1],
                                            colors: [
                                      Color(0x000B1117),
                                      Color(0x730B1117),
                                      Color(0xDB0B1117)
                                    ]))),
                                PositionedDirectional(
                                    top: 14,
                                    start: 14,
                                    child: Row(children: [
                                      HidayahLiveBadge(
                                          audio: s.isAudioLive,
                                          label: (s.isAudioLive
                                                  ? 'web.badge_audio'
                                                  : 'web.badge_live')
                                              .tr()),
                                      const SizedBox(width: 8),
                                      HidayahGlassBadge(
                                          icon: s.isAudioLive
                                              ? CaGlyph.mic
                                              : CaGlyph.eye,
                                          label:
                                              '${viewers ?? '—'} ${(s.isAudioLive ? 'web.listening' : 'web.watching').tr()}'),
                                    ])),
                                Center(
                                    child: Container(
                                        width: 68,
                                        height: 68,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: HidayahGradients.minted,
                                            boxShadow: [
                                              ...HidayahShadow.minted,
                                              BoxShadow(
                                                  color: HidayahGold.g300
                                                      .withValues(alpha: .18),
                                                  spreadRadius: 8),
                                            ]),
                                        child: CaIcon(
                                            s.isAudioLive
                                                ? CaGlyph.mic
                                                : CaGlyph.play,
                                            color: HidayahGold.s900,
                                            size: 28))),
                                PositionedDirectional(
                                    start: 20,
                                    end: 20,
                                    bottom: 18,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(s.getLocalizedTitle(lang),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: HidayahText.body(22,
                                                  color: HidayahGold.card,
                                                  weight: FontWeight.w700,
                                                  height: 1.3)),
                                          const SizedBox(height: 8),
                                          Row(children: [
                                            CaAvatar(
                                                name:
                                                    s.getLocalizedName(lang),
                                                url: s.avatarUrl,
                                                org: s.isOrganization,
                                                radius: 14),
                                            const SizedBox(width: 8),
                                            Flexible(
                                                child: Text(
                                                    '${s.getLocalizedName(lang)}  ·  ${s.getLocalizedVenue(lang)}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: HidayahText.body(
                                                        13.5,
                                                        color:
                                                            HidayahGold.s100))),
                                          ]),
                                        ])),
                              ]))))))),
      if (live.length > 1) ...[
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 1; i < live.length && i < 3; i++) ...[
            if (i > 1) const SizedBox(width: 10),
            Expanded(child: _AlsoLive(streamer: live[i])),
          ],
          if (live.length == 2) ...[
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ]),
      ],
    ]);
  }
}

class _AlsoLive extends StatelessWidget {
  const _AlsoLive({required this.streamer});
  final StreamerModel streamer;
  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return Material(
        color: const Color(0x0AFFFFFF),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: HidayahGold.g300.withValues(alpha: .16))),
        child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openLive(context, streamer),
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: SizedBox(
                          width: 76,
                          height: 44,
                          child: CaCardImage(url: streamer.bannerUrl))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(streamer.getLocalizedTitle(lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HidayahText.body(13,
                                color: HidayahGold.g100,
                                weight: FontWeight.w700,
                                height: 1.3)),
                        Text(
                            '${(streamer.isAudioLive ? 'web.badge_audio' : 'web.badge_live').tr()} · ${streamer.getLocalizedName(lang)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HidayahText.body(12,
                                color: HidayahGold.s300, height: 1.3)),
                      ])),
                ]))));
  }
}

/// Nothing live: the brand, and where to look next.
class _QuietFeature extends StatelessWidget {
  const _QuietFeature();
  @override
  // At least 16:9 like the player it stands in for, taller when large text
  // needs the room.
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => Container(
          constraints: BoxConstraints(minHeight: constraints.maxWidth * 9 / 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: const Color(0x08FFFFFF),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: HidayahGold.g300.withValues(alpha: .22))),
          padding: const EdgeInsets.all(32),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 84),
                const SizedBox(height: 18),
                Text('web.hero_none_title'.tr(),
                    textAlign: TextAlign.center,
                    style: HidayahText.display(24, color: HidayahGold.g50)),
                const SizedBox(height: 8),
                Text('web.hero_none_body'.tr(),
                    textAlign: TextAlign.center,
                    style: HidayahText.body(14.5, color: HidayahGold.s300)),
              ])));
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar(
      {required this.categories,
      required this.selected,
      required this.onCategory,
      required this.controller,
      required this.focus,
      required this.onChanged,
      required this.onClear,
      required this.onFilters,
      required this.tagActive,
      required this.lang});
  final List<AcademicCategoryModel> categories;
  final String selected, lang;
  final ValueChanged<String> onCategory, onChanged;
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onClear, onFilters;
  final bool tagActive;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: const BoxDecoration(
          color: HidayahGold.card,
          border: Border(bottom: BorderSide(color: HidayahGold.hairline))),
      child: HidayahWebWidth(
          child: SizedBox(
              height: 64,
              child: Row(children: [
                Expanded(
                    child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          HidayahTab(
                              label: 'feed.category_all'.tr(),
                              selected: selected == 'all',
                              height: 64,
                              onTap: () => onCategory('all')),
                          for (final c in categories)
                            HidayahTab(
                                label: c.getLocalizedName(lang),
                                selected: selected == c.id,
                                height: 64,
                                onTap: () => onCategory(
                                    selected == c.id ? 'all' : c.id)),
                        ]))),
                const SizedBox(width: 16),
                SizedBox(
                    width: 280,
                    height: 40,
                    child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) => TextField(
                            controller: controller,
                            focusNode: focus,
                            onChanged: onChanged,
                            style: HidayahText.body(13.5,
                                color: HidayahGold.s900, height: 1.2),
                            decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFF4EEE1),
                                hintText: 'feed.search_feed'.tr(),
                                hintStyle: HidayahText.body(13.5,
                                    color: HidayahGold.s600, height: 1.2),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                prefixIcon: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CaIcon(CaGlyph.search,
                                        color: HidayahGold.s600, size: 18)),
                                suffixIcon: value.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'feed.clear_search'.tr(),
                                        onPressed: onClear,
                                        icon: const CaIcon(CaGlyph.close,
                                            color: HidayahGold.s600,
                                            size: 16)),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: HidayahGold.g600,
                                        width: 1.5)))))),
                const SizedBox(width: 10),
                HidayahButton(
                    label: 'feed.filters'.tr() + (tagActive ? ' • 1' : ''),
                    icon: CaGlyph.sliders,
                    kind: HidayahButtonKind.ghost,
                    compact: true,
                    onPressed: onFilters),
              ]))));
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.streamer, required this.categories});
  final StreamerModel streamer;
  final List<AcademicCategoryModel> categories;
  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final s = streamer;
    final viewers = context.select<AppProvider, int?>(
        (p) => p.platformViewerCount(s.activeStreamId ?? ''));
    return HidayahCard(
        onTap: () => _openLive(context, s),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    CaCardImage(url: s.bannerUrl),
                    PositionedDirectional(
                        top: 10,
                        start: 10,
                        child: Row(children: [
                          HidayahLiveBadge(
                              audio: s.isAudioLive,
                              label: (s.isAudioLive
                                      ? 'web.badge_audio'
                                      : 'web.badge_live')
                                  .tr()),
                          const SizedBox(width: 6),
                          HidayahGlassBadge(
                              icon: s.isAudioLive ? CaGlyph.mic : CaGlyph.eye,
                              label:
                                  '${viewers ?? '—'} ${(s.isAudioLive ? 'web.listening' : 'web.watching').tr()}'),
                        ])),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.getLocalizedTitle(lang),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HidayahText.body(16,
                                color: HidayahGold.s900,
                                weight: FontWeight.w700,
                                height: 1.4)),
                        const SizedBox(height: 8),
                        Row(children: [
                          CaAvatar(
                              name: s.getLocalizedName(lang),
                              url: s.avatarUrl,
                              org: s.isOrganization,
                              radius: 12),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Text(s.getLocalizedName(lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HidayahText.body(13,
                                      color: HidayahGold.s700, height: 1.3))),
                          if (s.isVerified) ...[
                            const SizedBox(width: 4),
                            const CaIcon(CaGlyph.verified, size: 15),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        HidayahMeta(
                            icon: CaGlyph.pin,
                            text: [
                              s.getLocalizedVenue(lang),
                              _categoryName(categories, s.categoryId, lang)
                            ].where((t) => t.isNotEmpty).join(' · ')),
                      ])),
            ]));
  }
}

class _ScholarCard extends StatelessWidget {
  const _ScholarCard({required this.streamer, required this.categories});
  final StreamerModel streamer;
  final List<AcademicCategoryModel> categories;
  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final s = streamer;
    final live = _isLiveNow(context, s);
    final following =
        context.select<AppProvider, bool>((p) => p.isFollowing(s.streamerId));
    final tags =
        s.tags.where((t) => t.trim().isNotEmpty).toSet().take(2).toList();
    return HidayahCard(
        key: ValueKey('channel-card-${s.streamerId}'),
        onTap: () => _openChannel(context, s, live),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                  height: 124,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 92,
                        child: CaCardImage(url: s.bannerUrl)),
                    if (live)
                      PositionedDirectional(
                          top: 8,
                          end: 8,
                          child: HidayahLiveBadge(
                              audio: s.isAudioLive,
                              label: (s.isAudioLive
                                      ? 'web.badge_audio'
                                      : 'web.badge_live')
                                  .tr())),
                    PositionedDirectional(
                        start: 16,
                        bottom: 0,
                        child: DecoratedBox(
                            decoration: const BoxDecoration(
                                color: HidayahGold.card,
                                shape: BoxShape.circle),
                            child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: CaAvatar(
                                    name: s.getLocalizedName(lang),
                                    url: s.avatarUrl,
                                    live: live,
                                    verified: s.isVerified,
                                    org: s.isOrganization,
                                    ring: CaAvatarRing.brand,
                                    radius: 28)))),
                  ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.getLocalizedName(lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HidayahText.body(15.5,
                                color: HidayahGold.s900,
                                weight: FontWeight.w700,
                                height: 1.35)),
                        const SizedBox(height: 4),
                        Text(s.getLocalizedTitle(lang),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HidayahText.body(13,
                                color: HidayahGold.s700, height: 1.45)),
                        const SizedBox(height: 8),
                        HidayahMeta(
                            icon: CaGlyph.pin,
                            text: [
                              s.getLocalizedCity(lang),
                              _categoryName(categories, s.categoryId, lang)
                            ].where((t) => t.isNotEmpty).join(' · ')),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final t in tags) HidayahTag(t),
                          ]),
                        ],
                      ])),
              const Spacer(),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    if (live) ...[
                      Expanded(
                          child: HidayahButton(
                              label: (s.isAudioLive ? 'web.listen' : 'web.watch')
                                  .tr(),
                              icon: s.isAudioLive ? CaGlyph.mic : CaGlyph.play,
                              compact: true,
                              expand: true,
                              onPressed: () => _openChannel(context, s, true))),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                        child: HidayahButton(
                            label: (following
                                    ? 'profile.following_btn'
                                    : 'web.follow')
                                .tr(),
                            icon: following ? CaGlyph.check : CaGlyph.plus,
                            kind: HidayahButtonKind.ghost,
                            compact: true,
                            expand: true,
                            onPressed: () => context
                                .read<AppProvider>()
                                .toggleFollow(s.streamerId))),
                  ])),
            ]));
  }
}
