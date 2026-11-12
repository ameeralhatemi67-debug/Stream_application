import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../discovery/models/academic_category_model.dart';
import '../../../lessons/domain/lessons_rules.dart';
import '../../../lessons/presentation/lessons_in_app.dart'
    show MapLayers, MapMosque, MapSearchHit;
import '../../../profile/models/streamer_models.dart';
import '../../models/map_models.dart';
import '../../models/map_tricity_domain.dart';
import '../../services/map_offline_store.dart';
import '../../services/map_pack_controller.dart';
import '../map_visible_catalog.dart';
import '../venue_directions_launcher.dart';
import 'lantern_map_pins.dart';

/// Everything around the Lantern map that is not a pin or a place card: the
/// search, the filters, the side panel of the website layout, the buttons on
/// the map, the connection line, the credit and the map details.
///
/// The map screen keeps every piece of state and every action; these widgets
/// only draw and call back (ADR-026).

/// The id of "all three cities" in the city filter.
const String kLanternAllCities = 'all';

const List<BoxShadow> _floatShadow = [
  BoxShadow(
      color: Color(0x29000000),
      blurRadius: 14,
      spreadRadius: -4,
      offset: Offset(0, 6)),
];

/// A round button that floats on the map.
class LanternMapButton extends StatelessWidget implements LanternSkinWidget {
  const LanternMapButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.on = false});

  final LGlyph icon;
  final String label;
  final VoidCallback? onPressed;

  /// Shown as chosen (the legend is open, a filter is set).
  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return DecoratedBox(
        decoration: BoxDecoration(
            color: t.surface,
            shape: BoxShape.circle,
            border: Border.all(color: t.line),
            boxShadow: _floatShadow),
        child: LIconButton(
            icon: icon, label: label, onPressed: onPressed, on: on));
  }
}

/// The buttons on the map: closer and farther in one capsule, the legend,
/// and on a phone the list of places.
class LanternMapControls extends StatelessWidget implements LanternSkinWidget {
  const LanternMapControls(
      {super.key,
      required this.onZoomIn,
      required this.onZoomOut,
      required this.onLegend,
      this.canZoomIn = true,
      this.canZoomOut = true,
      this.legendOn = false,
      this.zoomOnly = false,
      this.onList});

  final VoidCallback onZoomIn, onZoomOut, onLegend;

  /// On a phone with a place card open: the card needs the room.
  final bool zoomOnly;
  final bool canZoomIn, canZoomOut, legendOn;

  /// Null on the website layout, where the list is the side panel.
  final VoidCallback? onList;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      DecoratedBox(
          decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(Lantern.radiusPill),
              border: Border.all(color: t.line),
              boxShadow: _floatShadow),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LIconButton(
                key: const ValueKey('lantern-map-zoom-in'),
                icon: LGlyph.plus,
                label: 'lantern.map.zoom_in'.tr(),
                onPressed: canZoomIn ? onZoomIn : null),
            Container(width: 22, height: 1, color: t.line),
            LIconButton(
                key: const ValueKey('lantern-map-zoom-out'),
                icon: LGlyph.minus,
                label: 'lantern.map.zoom_out'.tr(),
                onPressed: canZoomOut ? onZoomOut : null),
          ])),
      if (!zoomOnly) ...[
        const SizedBox(height: 8),
        LanternMapButton(
            key: const ValueKey('lantern-map-legend-button'),
            icon: LGlyph.layers,
            label: 'lantern.map.legend'.tr(),
            on: legendOn,
            onPressed: onLegend),
      ],
      if (!zoomOnly && onList != null) ...[
        const SizedBox(height: 8),
        LanternMapButton(
            key: const ValueKey('lantern-map-list-button'),
            icon: LGlyph.list,
            label: 'lantern.map.list'.tr(),
            onPressed: onList),
      ],
    ]);
  }
}

/// All, broadcasters, or mosque lessons.
class LanternMapLayerChips extends StatelessWidget
    implements LanternSkinWidget {
  const LanternMapLayerChips(
      {super.key, required this.value, required this.onChanged});

  final MapLayers value;
  final ValueChanged<MapLayers> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      label: 'map.layers_label'.tr(),
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(children: [
            for (final (layer, key, glyph) in const [
              (MapLayers.all, 'map.layer_all', null),
              (MapLayers.streamers, 'map.layer_streamers', LGlyph.mic),
              (MapLayers.lessons, 'map.layer_lessons', LGlyph.mosque),
            ])
              Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: LChip(
                      key: ValueKey('lantern-map-layer-${layer.name}'),
                      label: key.tr(),
                      icon: glyph,
                      dense: true,
                      selected: value == layer,
                      onTap: () => onChanged(layer))),
          ])));
}

/// The city and the topic. In the side panel each is one row that scrolls
/// sideways; in the sheet of the phone they wrap.
class LanternMapFilters extends StatelessWidget implements LanternSkinWidget {
  const LanternMapFilters(
      {super.key,
      required this.cityId,
      required this.onCity,
      required this.topics,
      required this.topicId,
      required this.onTopic,
      this.wrap = false});

  final String cityId, topicId;
  final ValueChanged<String> onCity, onTopic;
  final List<AcademicCategoryModel> topics;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    Widget head(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Lantern.textStyle(12.5,
                color: t.muted, weight: FontWeight.w600, height: 1.3)));
    Widget row(String label, List<Widget> chips) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              head(label),
              Semantics(
                  container: true,
                  label: label,
                  child: wrap
                      ? Wrap(spacing: 8, runSpacing: 8, children: chips)
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(children: [
                            for (final chip in chips)
                              Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                      end: 8),
                                  child: chip)
                          ]))),
            ]);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          row('lantern.map.city'.tr(), [
            LChip(
                key: const ValueKey('lantern-map-city-all'),
                label: 'map.all_cities'.tr(),
                dense: true,
                selected: cityId == kLanternAllCities,
                onTap: () => onCity(kLanternAllCities)),
            for (final view in kTricityCityViews)
              LChip(
                  key: ValueKey('lantern-map-city-${view.id}'),
                  label: view.localizedName(lang),
                  dense: true,
                  selected: cityId == view.id,
                  onTap: () => onCity(view.id)),
          ]),
          const SizedBox(height: 14),
          row('lantern.map.topic'.tr(), [
            LChip(
                key: const ValueKey('lantern-map-topic-all'),
                label: 'map.all_topics'.tr(),
                dense: true,
                selected: topicId == 'all',
                onTap: () => onTopic('all')),
            for (final topic in topics)
              LChip(
                  key: ValueKey('lantern-map-topic-${topic.id}'),
                  label: topic.getLocalizedName(lang),
                  dense: true,
                  selected: topicId == topic.id,
                  onTap: () => onTopic(topic.id)),
          ]),
        ]);
  }
}

/// The filters of a phone, in a sheet. A choice applies at once.
Future<void> showLanternMapFilters(BuildContext context,
        {required String cityId,
        required ValueChanged<String> onCity,
        required List<AcademicCategoryModel> topics,
        required String topicId,
        required ValueChanged<String> onTopic}) =>
    showLanternSheet<void>(context,
        title: 'lantern.map.filters'.tr(),
        body: (context) => _FilterSheet(
            cityId: cityId,
            onCity: onCity,
            topics: topics,
            topicId: topicId,
            onTopic: onTopic));

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(
      {required this.cityId,
      required this.onCity,
      required this.topics,
      required this.topicId,
      required this.onTopic});

  final String cityId, topicId;
  final ValueChanged<String> onCity, onTopic;
  final List<AcademicCategoryModel> topics;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _city = widget.cityId, _topic = widget.topicId;

  @override
  Widget build(BuildContext context) => LanternMapFilters(
      key: const ValueKey('lantern-map-filter-sheet'),
      wrap: true,
      cityId: _city,
      topics: widget.topics,
      topicId: _topic,
      onCity: (id) {
        setState(() => _city = id);
        widget.onCity(id);
      },
      onTopic: (id) {
        setState(() => _topic = id);
        widget.onTopic(id);
      });
}

typedef _Hit = ({
  String title,
  String subtitle,
  LGlyph icon,
  bool live,
  VoidCallback open
});

/// Search over the three city views, the broadcasters on the map, saved
/// places and the mosque lessons. A choice goes back to the map screen,
/// which alone moves the camera.
class LanternMapSearch extends StatefulWidget implements LanternSkinWidget {
  const LanternMapSearch(
      {super.key,
      required this.streamers,
      required this.onCity,
      required this.onStreamer,
      required this.onMosque,
      required this.onCached,
      required this.searchLessons,
      this.cached = const [],
      this.floating = false});

  final List<StreamerModel> streamers;

  /// Saved places, searched by name only when there is no connection.
  final List<MapMarkerModel> cached;
  final ValueChanged<String> onCity, onStreamer, onMosque;
  final ValueChanged<MapMarkerModel> onCached;
  final List<MapSearchHit> Function(String query) searchLessons;

  /// Over the map, where the field needs a shadow to stand out.
  final bool floating;

  @override
  State<LanternMapSearch> createState() => _LanternMapSearchState();
}

class _LanternMapSearchState extends State<LanternMapSearch> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (!mounted) return;
    if (_focus.hasFocus && _controller.text.trim().isNotEmpty && !_open) {
      setState(() => _open = true);
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  List<_Hit> _hits(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <_Hit>[];
    for (final view in kTricityCityViews) {
      if (view.matchesSearch(q)) {
        hits.add((
          title: view.localizedName(lang),
          subtitle: 'map.place_preset'.tr(),
          icon: LGlyph.map,
          live: false,
          open: () => widget.onCity(view.id)
        ));
      }
    }
    final ids = <String>{};
    for (final s in searchMapStreamers(widget.streamers, q)) {
      ids.add(s.streamerId);
      hits.add((
        title: s.getLocalizedName(lang),
        subtitle: s.getLocalizedVenue(lang),
        icon: s.isCurrentlyLive ? LGlyph.live : LGlyph.pin,
        live: s.isCurrentlyLive,
        open: () => widget.onStreamer(s.streamerId)
      ));
    }
    for (final marker in widget.cached) {
      if (ids.contains(marker.streamerId)) continue;
      final hit = [
        marker.displayNameEn,
        marker.displayNameAr,
        marker.venueNameEn,
        marker.venueNameAr,
      ].any((v) => v.toLowerCase().contains(q));
      if (!hit) continue;
      hits.add((
        title: marker.getLocalizedName(lang),
        subtitle: marker.getLocalizedVenue(lang),
        icon: LGlyph.pin,
        live: false,
        open: () => widget.onCached(marker)
      ));
    }
    for (final hit in widget.searchLessons(q)) {
      hits.add((
        title: hit.title,
        subtitle: hit.subtitle,
        icon: LGlyph.mosque,
        live: false,
        open: () => widget.onMosque(hit.mosqueId)
      ));
    }
    return hits;
  }

  void _clear() {
    _controller.clear();
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final hasQuery = _controller.text.trim().isNotEmpty;
    final hits = hasQuery && _open ? _hits(_controller.text, lang) : const <_Hit>[];
    Widget field = LField(
        key: const ValueKey('lantern-map-search'),
        controller: _controller,
        focusNode: _focus,
        pill: true,
        icon: LGlyph.search,
        hint: 'map.search_placeholder'.tr(),
        textInputAction: TextInputAction.search,
        onChanged: (q) => setState(() => _open = q.trim().isNotEmpty),
        trailing: hasQuery
            ? LIconButton(
                icon: LGlyph.close,
                label: 'lantern.map.clear_search'.tr(),
                iconSize: 16,
                onPressed: _clear)
            : null);
    if (widget.floating) {
      field = DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lantern.radiusPill),
              boxShadow: _floatShadow),
          child: field);
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          if (hasQuery && _open)
            Container(
                key: const ValueKey('lantern-map-search-results'),
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 264),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: t.raised,
                    borderRadius: BorderRadius.circular(Lantern.radiusRow),
                    border: Border.all(color: t.line),
                    boxShadow: _floatShadow),
                child: hits.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          LIcon(LGlyph.search, size: 18, color: t.muted),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text('map.no_search_results'.tr(),
                                  style: Lantern.textStyle(14,
                                      color: t.muted, height: 1.4))),
                        ]))
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(6),
                        itemCount: hits.length,
                        itemBuilder: (context, i) {
                          final hit = hits[i];
                          return LPressable(
                              label:
                                  '${hit.title}, ${hit.subtitle}${hit.live ? ', ${'web.badge_live'.tr()}' : ''}',
                              excludeChildSemantics: true,
                              radius: Lantern.radiusTile,
                              pressScale: .99,
                              onTap: () {
                                hit.open();
                                _controller.text = hit.title;
                                setState(() => _open = false);
                                _focus.unfocus();
                              },
                              builder: (context, s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 7),
                                  decoration: BoxDecoration(
                                      color: s.hovered || s.pressed
                                          ? t.sunk
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                          Lantern.radiusTile)),
                                  child: Row(children: [
                                    Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                            color:
                                                hit.live ? t.liveSoft : t.sunk,
                                            shape: BoxShape.circle),
                                        child: LIcon(hit.icon,
                                            size: 17,
                                            color: hit.live
                                                ? t.liveText
                                                : t.goldInk)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                          Text(hit.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Lantern.textStyle(14,
                                                  color: t.fg,
                                                  weight: FontWeight.w600,
                                                  height: 1.35)),
                                          Text(hit.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Lantern.textStyle(12.5,
                                                  color: t.muted,
                                                  height: 1.35)),
                                        ])),
                                    if (hit.live) ...[
                                      const SizedBox(width: 8),
                                      LBadge('web.badge_live'.tr(),
                                          kind: LBadgeKind.live, small: true),
                                    ],
                                  ])));
                        })),
        ]);
  }
}

/// How many places the map shows, and what is on right now: green at
/// mosques, red in the app, each with its words.
class LanternMapCounts extends StatelessWidget implements LanternSkinWidget {
  const LanternMapCounts(
      {super.key,
      required this.total,
      required this.onSite,
      required this.live});

  final int total, onSite, live;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('lantern.map.on_map'.tr(args: ['$total']),
              style: Lantern.textStyle(13,
                      color: t.muted, weight: FontWeight.w600, height: 1.3)
                  .copyWith(fontFeatures: Lantern.tabular)),
          if (onSite > 0)
            LTag('lessons.map.now_mosques'.tr(args: ['$onSite']),
                tone: LTone.ok, icon: LGlyph.mosque),
          if (live > 0)
            LTag('lessons.map.now_live'.tr(args: ['$live']),
                tone: LTone.live, icon: LGlyph.live),
        ]);
  }
}

/// On a phone the same two counts float on the map as one ink pill.
class LanternMapNowPill extends StatelessWidget implements LanternSkinWidget {
  const LanternMapNowPill({super.key, required this.onSite, required this.live});

  final int onSite, live;

  @override
  Widget build(BuildContext context) {
    Widget part(Color dot, String text) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(12,
                          color: LanternTokens.white,
                          weight: FontWeight.w600,
                          height: 1.3)
                      .copyWith(fontFeatures: Lantern.tabular))),
        ]);
    return Container(
        key: const ValueKey('lantern-map-now-pill'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: LanternTokens.ink.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(Lantern.radiusPill),
            boxShadow: _floatShadow),
        child: Wrap(spacing: 12, runSpacing: 2, children: [
          if (onSite > 0)
            part(LanternTokens.dark.ok,
                'lessons.map.now_mosques'.tr(args: ['$onSite'])),
          if (live > 0)
            part(LanternTokens.dark.live,
                'lessons.map.now_live'.tr(args: ['$live'])),
        ]));
  }
}

/// The places of the map as a list: mosques with a lesson today first, then
/// the broadcasters, live ones first. A row selects its pin.
class LanternMapPlaceList extends StatelessWidget
    implements LanternSkinWidget {
  const LanternMapPlaceList(
      {super.key,
      required this.mosques,
      required this.streamers,
      required this.onMosque,
      required this.onStreamer,
      required this.onShowAll,
      this.selectedMosqueId,
      this.selectedStreamerId,
      this.scrolls = true});

  final List<MapMosque> mosques;
  final List<StreamerModel> streamers;
  final ValueChanged<MapMosque> onMosque;
  final ValueChanged<StreamerModel> onStreamer;
  final VoidCallback onShowAll;
  final String? selectedMosqueId, selectedStreamerId;

  /// False inside a sheet, which scrolls by itself.
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    if (mosques.isEmpty && streamers.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: LEmptyState(
              key: const ValueKey('lantern-map-list-empty'),
              compact: true,
              icon: LGlyph.pin,
              title: 'map.empty_title'.tr(),
              body: 'map.empty_body'.tr(),
              action: LButton(
                  label: 'map.overview_button'.tr(),
                  kind: LButtonKind.tonal,
                  size: LButtonSize.small,
                  onPressed: onShowAll)));
    }
    final ordered = [
      ...streamers.where((s) => s.isCurrentlyLive),
      ...streamers.where((s) => !s.isCurrentlyLive),
    ];
    Widget head(String title, int count) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(children: [
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(title,
                      style: Lantern.displayStyle(14,
                          color: t.fg,
                          height: context.lanternArabic ? 1.45 : 1.25)))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: t.sunk,
                  borderRadius: BorderRadius.circular(Lantern.radiusPill)),
              child: Text('$count',
                  style: Lantern.textStyle(12,
                          color: t.goldInk,
                          weight: FontWeight.w600,
                          height: 1.2)
                      .copyWith(fontFeatures: Lantern.tabular))),
        ]));
    final rows = <Widget>[
      if (mosques.isNotEmpty) ...[
        head('lessons.map.today_list'.tr(), mosques.length),
        for (final m in mosques)
          _PlaceRow(
              key: ValueKey('lantern-map-row-m-${m.id}'),
              selected: m.id == selectedMosqueId,
              title: m.label,
              spoken: '${m.label}${m.chip.isEmpty ? '' : ', ${m.chip}'}',
              leading: Container(
                  width: 38,
                  height: 40,
                  alignment: const Alignment(0, .2),
                  decoration: ShapeDecoration(
                      color: t.sunk,
                      shape: LArchBorder(
                          bottom: 6, side: BorderSide(color: t.line))),
                  child: LIcon(LGlyph.mosque, size: 18, color: t.goldInk)),
              trailing: m.live
                  ? LBadge('web.badge_live'.tr(),
                      kind: LBadgeKind.live, small: true)
                  : m.chip.isEmpty
                      ? null
                      : m.status == MosqueStatus.now
                          ? LBadge(m.chip, kind: LBadgeKind.now, small: true)
                          : LTag(m.chip),
              onTap: () => onMosque(m)),
      ],
      if (ordered.isNotEmpty) ...[
        head('lantern.map.channels_head'.tr(), ordered.length),
        for (final s in ordered)
          _PlaceRow(
              key: ValueKey('lantern-map-row-s-${s.streamerId}'),
              selected: s.streamerId == selectedStreamerId,
              title: s.getLocalizedName(lang),
              subtitle: s.getLocalizedVenue(lang),
              spoken:
                  '${s.getLocalizedName(lang)}, ${s.getLocalizedVenue(lang)}${s.isAudioLive ? ', ${'web.badge_audio'.tr()}' : s.isCurrentlyLive ? ', ${'web.badge_live'.tr()}' : ''}',
              leading: LAvatar(
                  name: s.getLocalizedName(lang),
                  image: resolveImageProviderOrNull(s.avatarUrl),
                  size: 38,
                  org: s.isOrganization,
                  ring: s.isAudioLive
                      ? LRing.audio
                      : s.isCurrentlyLive
                          ? LRing.live
                          : LRing.none),
              trailing: s.isAudioLive
                  ? LBadge('web.badge_audio'.tr(),
                      kind: LBadgeKind.audio, small: true)
                  : s.isCurrentlyLive
                      ? LBadge('web.badge_live'.tr(),
                          kind: LBadgeKind.live, small: true)
                      : null,
              onTap: () => onStreamer(s)),
      ],
    ];
    return scrolls
        ? ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
            children: rows)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows);
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow(
      {super.key,
      required this.title,
      required this.spoken,
      required this.leading,
      required this.onTap,
      this.subtitle,
      this.trailing,
      this.selected = false});

  final String title, spoken;
  final String? subtitle;
  final Widget leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: LPressable(
            label: spoken,
            selected: selected,
            excludeChildSemantics: true,
            radius: Lantern.radiusRow,
            pressScale: .985,
            onTap: onTap,
            builder: (context, s) => AnimatedContainer(
                duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
                constraints: const BoxConstraints(minHeight: Lantern.target),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                    color: selected || s.hovered ? t.sunk : t.surface,
                    borderRadius: BorderRadius.circular(Lantern.radiusRow),
                    border: Border.all(
                        color: selected
                            ? LanternTokens.gold
                            : s.hovered
                                ? t.line
                                : t.line2),
                    boxShadow: [
                      if (selected) BoxShadow(color: t.glow, spreadRadius: 3)
                    ]),
                child: Row(children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Lantern.textStyle(14,
                                color: t.fg,
                                weight: FontWeight.w600,
                                height: 1.35)),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Lantern.textStyle(12.5,
                                  color: t.muted, height: 1.4)),
                      ])),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Flexible(flex: 0, child: trailing!)
                  ],
                ]))));
  }
}

/// The side panel of the website layout: the title, the search, the
/// filters, the counts and the list. It scrolls apart from the map.
class LanternMapPanel extends StatelessWidget implements LanternSkinWidget {
  const LanternMapPanel(
      {super.key,
      required this.search,
      required this.filters,
      required this.counts,
      required this.list,
      this.layers});

  final Widget search, filters, counts, list;
  final Widget? layers;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final arabic = context.lanternArabic;
    return Container(
        width: Lantern.sideChat,
        decoration: BoxDecoration(
            color: t.surface,
            border: BorderDirectional(end: BorderSide(color: t.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('lantern.map.eyebrow'.tr(),
                        style: Lantern.textStyle(12.5,
                            color: t.goldInk,
                            weight: FontWeight.w700,
                            height: 1.3)),
                    const SizedBox(height: 6),
                    Semantics(
                        header: true,
                        child: Text('lantern.map.title'.tr(),
                            style: Lantern.displayStyle(26,
                                color: t.fg, height: arabic ? 1.45 : 1.2))),
                    const SizedBox(height: 4),
                    Text('lantern.map.lead'.tr(),
                        style: Lantern.textStyle(13.5,
                            color: t.muted, height: 1.5)),
                    const SizedBox(height: 14),
                    search,
                    if (layers != null) ...[
                      const SizedBox(height: 12),
                      layers!
                    ],
                    const SizedBox(height: 12),
                    filters,
                    const SizedBox(height: 14),
                    counts,
                  ])),
          Container(height: 1, color: t.line),
          Expanded(child: list),
        ]));
  }
}

/// The map's credit, always visible and never cut short, with the button
/// that opens the map details.
///
/// [compact] is the phone's: a small chip in the strip under the floating
/// navigation, in the bottom corner, so it no longer lifts the place cards
/// (owner notes 2026-11-12). It opens the map details, whose credits section
/// links to the licence.
class LanternMapAttribution extends StatelessWidget
    implements LanternSkinWidget {
  const LanternMapAttribution(
      {super.key,
      required this.credit,
      required this.url,
      required this.onDetails,
      this.compact = false});

  final String credit, url;
  final VoidCallback onDetails;
  final bool compact;

  /// The compact chip's height: it fits the 14 px under the navigation.
  static const compactHeight = 14.0;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    if (compact) {
      return LPressable(
          key: const ValueKey('lantern-map-credit'),
          label: '$credit, ${'map.details_open'.tr()}',
          radius: 7,
          pressScale: 1,
          excludeChildSemantics: true,
          onTap: onDetails,
          // A taller touch area than the chip, clear above it.
          builder: (context, s) => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                  height: compactHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                      color: t.surface.withValues(alpha: .86),
                      borderRadius: BorderRadius.circular(7)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(credit,
                        textDirection: TextDirection.ltr,
                        style: Lantern.textStyle(9.5,
                            color: t.muted, height: 1.2)),
                    const SizedBox(width: 4),
                    LIcon(LGlyph.info, size: 10, color: t.muted),
                  ]))));
    }
    return Container(
        key: const ValueKey('lantern-map-credit'),
        decoration: BoxDecoration(
            color: t.surface.withValues(alpha: .92),
            borderRadius: const BorderRadiusDirectional.only(
                topEnd: Radius.circular(Lantern.radiusTile))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
              child: LPressable(
                  label:
                      'map.credit_link_label'.tr(namedArgs: {'credit': credit}),
                  button: false,
                  excludeChildSemantics: true,
                  radius: Lantern.radiusTile,
                  pressScale: 1,
                  onTap: () => launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication),
                  builder: (context, s) => ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: Lantern.target),
                      child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                              start: 10, end: 4),
                          child: Center(
                              widthFactor: 1,
                              child: Text(credit,
                                  textDirection: TextDirection.ltr,
                                  style: Lantern.textStyle(12,
                                          color: t.muted, height: 1.3)
                                      .copyWith(
                                          decoration: TextDecoration.underline,
                                          decorationColor: t.muted))))))),
          LIconButton(
              icon: LGlyph.info,
              label: 'map.details_open'.tr(),
              iconSize: 18,
              color: t.muted,
              onPressed: onDetails),
        ]));
  }
}

/// One line that says the venues are saved ones, with Retry. Streets never
/// depend on it.
class LanternMapConnection extends StatelessWidget
    implements LanternSkinWidget {
  const LanternMapConnection(
      {super.key,
      required this.label,
      required this.retrying,
      required this.onRetry,
      required this.onDetails});

  final String label;
  final bool retrying;
  final VoidCallback onRetry, onDetails;

  @override
  Widget build(BuildContext context) => LPressable(
      key: const ValueKey('lantern-map-connection'),
      label: 'map.details_open'.tr(),
      radius: Lantern.radiusField,
      pressScale: 1,
      onTap: onDetails,
      builder: (context, s) => DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lantern.radiusField),
              boxShadow: _floatShadow),
          child: LBanner(label,
              tone: LTone.warn,
              icon: LGlyph.wifioff,
              action: LButton(
                  label: (retrying ? 'map.offline_retrying' : 'map.offline_retry')
                      .tr(),
                  kind: LButtonKind.ghost,
                  size: LButtonSize.small,
                  loading: retrying,
                  onPressed: retrying ? null : onRetry))));
}

/// Browser only: one line that offers to save the map for use without a
/// connection.
class LanternMapOfflineHint extends StatelessWidget
    implements LanternSkinWidget {
  const LanternMapOfflineHint(
      {super.key,
      required this.evicted,
      required this.onPrepare,
      required this.onDismiss});

  final bool evicted;
  final VoidCallback onPrepare, onDismiss;

  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Lantern.radiusField),
          boxShadow: _floatShadow),
      child: LBanner(
          (evicted ? 'map.web_offline_hint_evicted' : 'map.web_offline_hint')
              .tr(),
          icon: LGlyph.download,
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            LButton(
                label: 'map.web_offline_hint_prepare'.tr(),
                kind: LButtonKind.tonal,
                size: LButtonSize.small,
                onPressed: onPrepare),
            if (!evicted)
              LIconButton(
                  icon: LGlyph.close,
                  label: 'map.web_offline_hint_dismiss'.tr(),
                  iconSize: 16,
                  onPressed: onDismiss),
          ])));
}

String _packProblem(MapPackProblem? problem) => switch (problem) {
      MapPackProblem.corrupt => 'map.pack_problem_corrupt'.tr(),
      MapPackProblem.incompatible => 'map.pack_problem_incompatible'.tr(),
      _ => 'map.pack_problem_missing'.tr(),
    };

/// Over the map while the stored map is opening, or when it cannot be used.
/// The pins, the list and the live actions keep working under it.
class LanternMapPackStatus extends StatelessWidget
    implements LanternSkinWidget {
  const LanternMapPackStatus(
      {super.key, required this.controller, this.onShowList});

  final MapPackController controller;

  /// Null on the website layout, where the list is always in view.
  final VoidCallback? onShowList;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    if (controller.status == MapPackStatus.loading) {
      return Semantics(
          liveRegion: true,
          label: 'map.pack_loading'.tr(),
          child: ExcludeSemantics(
              child: Container(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 8),
                  decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(Lantern.radiusPill),
                      border: Border.all(color: t.line),
                      boxShadow: _floatShadow),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const LStarLoader(size: 20),
                    const SizedBox(width: 10),
                    Flexible(
                        child: Text('map.pack_loading'.tr(),
                            style: Lantern.textStyle(13.5,
                                color: t.fg,
                                weight: FontWeight.w600,
                                height: 1.3))),
                  ]))));
    }
    return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Semantics(
            liveRegion: true,
            child: LCard(
                key: const ValueKey('lantern-map-pack-problem'),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        LIcon(LGlyph.map, size: 20, color: t.warn),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('map.pack_unavailable_title'.tr(),
                                style: Lantern.displayStyle(16,
                                    color: t.fg,
                                    height:
                                        context.lanternArabic ? 1.45 : 1.25))),
                      ]),
                      const SizedBox(height: 6),
                      Text(_packProblem(controller.problem),
                          style: Lantern.textStyle(14,
                              color: t.muted, height: 1.5)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        LButton(
                            label: 'map.pack_retry'.tr(),
                            kind: LButtonKind.secondary,
                            size: LButtonSize.small,
                            icon: LGlyph.refresh,
                            onPressed: controller.retry),
                        if (onShowList != null)
                          LButton(
                              label: 'lantern.map.list'.tr(),
                              kind: LButtonKind.ghost,
                              size: LButtonSize.small,
                              onPressed: onShowList),
                      ]),
                    ]))));
  }
}

/// No place matches: a small card over the map, so the map stays in use.
class LanternMapEmptyNotice extends StatelessWidget
    implements LanternSkinWidget {
  const LanternMapEmptyNotice(
      {super.key,
      required this.online,
      required this.retrying,
      required this.onRetry});

  final bool online, retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return LCard(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
        radius: Lantern.radiusRow,
        child: Row(children: [
          LIcon(LGlyph.pin, size: 20, color: t.muted),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text('map.empty_title'.tr(),
                    style: Lantern.textStyle(13.5,
                        color: t.fg, weight: FontWeight.w700, height: 1.35)),
                Text((online ? 'map.empty_body' : 'map.offline_empty_body').tr(),
                    style:
                        Lantern.textStyle(12.5, color: t.muted, height: 1.4)),
              ])),
          // Without a connection the line at the top already offers Retry.
          if (online)
            LButton(
                label: 'map.offline_retry'.tr(),
                kind: LButtonKind.ghost,
                size: LButtonSize.small,
                loading: retrying,
                onPressed: retrying ? null : onRetry),
        ]));
  }
}

/// The legend as a card on the map (website layout).
class LanternMapLegendCard extends StatelessWidget
    implements LanternSkinWidget {
  const LanternMapLegendCard({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return LCard(
        key: const ValueKey('lantern-map-legend-card'),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
                child: Semantics(
                    header: true,
                    child: Text('lantern.map.legend'.tr(),
                        style: Lantern.displayStyle(15,
                            color: t.fg,
                            height: context.lanternArabic ? 1.45 : 1.25)))),
            LIconButton(
                icon: LGlyph.close,
                label: MaterialLocalizations.of(context).closeButtonLabel,
                iconSize: 16,
                onPressed: onClose),
          ]),
          const Padding(
              padding: EdgeInsetsDirectional.only(end: 8),
              child: LanternMapLegend()),
        ]));
  }
}

/// A saved place chosen without a connection: what is held, said plainly,
/// and the way there.
Future<void> showLanternCachedPlace(
    BuildContext context, MapMarkerModel marker) {
  final lang = context.locale.languageCode;
  return showLanternSheet<void>(context,
      title: marker.getLocalizedName(lang),
      body: (sheetContext) {
        final t = sheetContext.lt;
        return Column(
            key: const ValueKey('lantern-map-cached-place'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(marker.getLocalizedVenue(lang),
                  style: Lantern.textStyle(14, color: t.muted, height: 1.45)),
              const SizedBox(height: 14),
              LBanner('map.offline_marker_details_unavailable'.tr(),
                  icon: LGlyph.wifioff),
              const SizedBox(height: 14),
              LButton(
                  label: 'map.open_in_maps'.tr(),
                  kind: LButtonKind.secondary,
                  icon: LGlyph.directions,
                  expand: true,
                  onPressed: () {
                    Navigator.of(sheetContext).maybePop();
                    openVenueDirections(
                        context, marker.latitude, marker.longitude);
                  }),
            ]);
      });
}

String _date(DateTime? value) =>
    value == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());

/// Map details: what is stored on the device, how old the venue list is,
/// saving the map in a browser, the credits and the licence notices.
Future<void> showLanternMapDetails(BuildContext context,
    {required MapPackController controller,
    required DateTime? venuesUpdatedAt,
    required bool backendOnline}) {
  // The browser may have cleared its copy since the status was last read.
  unawaited(controller.refreshWebOffline());
  return showLanternSheet<void>(context,
      title: 'map.details_open'.tr(),
      body: (context) => ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _MapDetails(
              controller: controller,
              venuesUpdatedAt: venuesUpdatedAt,
              backendOnline: backendOnline)));
}

class _MapDetails extends StatelessWidget {
  const _MapDetails(
      {required this.controller,
      required this.venuesUpdatedAt,
      required this.backendOnline});

  final MapPackController controller;
  final DateTime? venuesUpdatedAt;
  final bool backendOnline;

  String _webText(WebOfflineStatus status, int? packBytes) {
    final size =
        packBytes == null ? '' : (packBytes / (1 << 20) + 20).toStringAsFixed(0);
    return switch (status.state) {
      WebOfflineState.notPrepared =>
        'map.web_offline_not_prepared'.tr(namedArgs: {'size': size}),
      WebOfflineState.preparing => 'map.web_offline_preparing'.plural(
          status.total,
          name: 'total',
          namedArgs: {'done': '${status.done}'}),
      WebOfflineState.ready => 'map.web_offline_ready'
          .tr(namedArgs: {'date': _date(status.preparedAt)}),
      WebOfflineState.evicted => 'map.web_offline_evicted'.tr(),
      WebOfflineState.unsupported => 'map.web_offline_unsupported'.tr(),
      WebOfflineState.failed => switch (status.detail) {
          'quota' => 'map.web_offline_failed_quota'.tr(),
          'private' => 'map.web_offline_failed_private'.tr(),
          'mismatch' => 'map.web_offline_failed_mismatch'.tr(),
          'incomplete' => 'map.web_offline_failed_incomplete'.tr(),
          'unsupported' => 'map.web_offline_unsupported'.tr(),
          _ => 'map.web_offline_failed_network'.tr(),
        },
    };
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final remove = await showLanternDialog<bool>(context,
        title: 'map.web_offline_remove_title'.tr(),
        body: (context) => Text('map.web_offline_remove_body'.tr(),
            style: Lantern.textStyle(14.5,
                color: context.lt.muted, height: 1.5)),
        actions: (context) => [
              LButton(
                  label: 'design_ui.cancel'.tr(),
                  kind: LButtonKind.ghost,
                  onPressed: () => Navigator.of(context).pop(false)),
              LButton(
                  label: 'map.web_offline_remove'.tr(),
                  kind: LButtonKind.danger,
                  onPressed: () => Navigator.of(context).pop(true)),
            ]);
    if (remove == true) await controller.resetWebOffline();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final manifest = controller.manifest;
    final pack = manifest?.file('basemap.pmtiles');
    final web = controller.webOffline;
    final credit = manifest?.attributionShort ?? kOsmCreditFallback;
    final creditUrl =
        manifest?.attributionUrl ?? 'https://www.openstreetmap.org/copyright';
    Widget body(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: Lantern.textStyle(14, color: t.muted, height: 1.5)));
    Widget section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                  header: true,
                  child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(title,
                          style: Lantern.displayStyle(15,
                              color: t.fg,
                              height: context.lanternArabic ? 1.45 : 1.25)))),
              ...children,
            ]));
    return Column(
        key: const ValueKey('lantern-map-details'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('map.details_title'.tr(), [
            body(controller.isReady
                ? (!controller.supportsWebOffline
                        ? 'map.details_pack_ready'
                        : web?.state == WebOfflineState.ready
                            ? 'map.details_pack_saved_web'
                            : 'map.details_pack_ready_web')
                    .tr(namedArgs: {'date': manifest?.dataDate ?? ''})
                : controller.status == MapPackStatus.loading
                    ? 'map.pack_loading'.tr()
                    : _packProblem(controller.problem)),
            body('map.details_coverage'.tr()),
            if (manifest != null && manifest.isStale(DateTime.now()))
              body('map.details_pack_stale'
                  .tr(namedArgs: {'date': manifest.dataDate})),
            if (pack != null)
              Text(
                  'map.details_pack_id'.tr(namedArgs: {
                    'id': manifest!.packId,
                    'size': (pack.bytes / (1 << 20)).toStringAsFixed(1),
                  }),
                  style: Lantern.textStyle(12, color: t.muted, height: 1.4)),
            if (!controller.isReady &&
                controller.status != MapPackStatus.loading)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: LButton(
                      label: 'map.pack_retry'.tr(),
                      kind: LButtonKind.secondary,
                      size: LButtonSize.small,
                      icon: LGlyph.refresh,
                      onPressed: controller.retry)),
          ]),
          section('map.details_venues_title'.tr(), [
            body(backendOnline
                ? 'map.details_venues_online'.tr()
                : venuesUpdatedAt == null
                    ? 'map.offline_last_updated_never'.tr()
                    : 'map.details_venues_saved'
                        .tr(namedArgs: {'time': _date(venuesUpdatedAt)})),
          ]),
          if (controller.supportsWebOffline && web != null)
            section('map.web_offline_title'.tr(), [
              body(_webText(web, pack?.bytes)),
              const SizedBox(height: 6),
              if (web.state == WebOfflineState.preparing)
                web.total == 0
                    ? const Center(child: LStarLoader())
                    : LProgress(web.done / web.total)
              else if (web.state != WebOfflineState.unsupported)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (web.state != WebOfflineState.ready)
                    LButton(
                        label: 'map.web_offline_prepare'.tr(),
                        size: LButtonSize.small,
                        icon: LGlyph.download,
                        // Needs this website in reach, not the backend: a
                        // failed download is reported, never "ready".
                        onPressed: controller.canPrepareWebOffline
                            ? controller.prepareWebOffline
                            : null),
                  if (web.state == WebOfflineState.ready ||
                      web.state == WebOfflineState.evicted)
                    LButton(
                        label: 'map.web_offline_remove'.tr(),
                        kind: LButtonKind.secondary,
                        size: LButtonSize.small,
                        onPressed: () => _confirmRemove(context)),
                ]),
            ]),
          section('map.details_credits_title'.tr(), [
            body('map.details_credits_body'.tr()),
            LLink(credit,
                icon: LGlyph.external,
                arrow: false,
                onTap: () => launchUrl(Uri.parse(creditUrl),
                    mode: LaunchMode.externalApplication)),
            if (controller.notice != null) _Notices(controller.notice!),
          ]),
        ]);
  }
}

/// The licence notices stored in the app, folded until asked for.
class _Notices extends StatefulWidget {
  const _Notices(this.text);

  final String text;

  @override
  State<_Notices> createState() => _NoticesState();
}

class _NoticesState extends State<_Notices> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LLink('map.details_notices'.tr(),
              arrow: false,
              icon: _open ? LGlyph.minus : LGlyph.plus,
              onTap: () => setState(() => _open = !_open)),
          if (_open)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SelectableText(widget.text,
                    textDirection: TextDirection.ltr,
                    style:
                        Lantern.textStyle(12, color: t.muted, height: 1.45))),
        ]);
  }
}
