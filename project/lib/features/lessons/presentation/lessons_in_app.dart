import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ds/ca_cards.dart';
import '../../../core/widgets/ds/ca_fields.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_rows.dart';
import '../../discovery/models/academic_category_model.dart';
import '../../map/presentation/map_cluster_layout.dart';
import '../../map/presentation/map_visible_catalog.dart';
import '../../profile/models/streamer_models.dart';
import '../../web/presentation/hidayah_web_kit.dart';
import '../domain/lessons_dates.dart';
import '../domain/lessons_models.dart';
import '../domain/lessons_rules.dart';
import '../domain/lessons_vocab.dart';
import '../state/lessons_controller.dart';
import '../state/preacher_link_controller.dart';
import 'lessons_kit.dart';
import 'lessons_map.dart';
import 'lessons_modals.dart';
import 'lessons_widgets.dart';

// The places where Lessons, the mosque lessons programme, shows inside Hadayah
// Live's own screens (ADR-014): mosques on the map, a lessons row on
// Discover, and a person's programme pages in Settings. Each reads the
// LessonsController when the app provides one and shows nothing without it.

/// A mosque on the map: what its marker says right now. [minutes] counts to
/// the end of the lesson that is on, or to the start of the next one. [count]
/// is its lessons in the coming seven days. [chip] is the line under it.
typedef MapMosque = ({
  String id,
  LatLng point,
  String label,
  int count,
  bool live,
  MosqueStatus status,
  int minutes,
  String chip,
});

/// Every approved mosque inside the map's area. With a [topic], only mosques
/// with a coming lesson on it. Without a connection nothing here can be
/// trusted as happening now, so there is no status, only the lessons we hold.
List<MapMosque> mapMosques(LessonsController c, String lang, {DateTime? now, bool online = true, String? topic}) {
  final at = now ?? DateTime.now();
  final byMosque = <String, List<Lesson>>{};
  for (final l in c.upcoming) {
    if (topic == null || l.topic == topic) (byMosque[l.mosqueId] ??= []).add(l);
  }
  return [
    for (final m in c.verifiedMosques)
      if (m.hasPin && LessonsMap.covers(m.latitude!, m.longitude!) && (topic == null || byMosque.containsKey(m.id)))
        _mapMosque(c, m, byMosque[m.id] ?? const [], lang, at, online),
  ];
}

MapMosque _mapMosque(LessonsController c, Mosque m, List<Lesson> lessons, String lang, DateTime at, bool online) {
  final state = mosqueNow(lessons, c.catalog, at);
  final l = state.lesson;
  final status = online || state.status == MosqueStatus.quiet ? state.status : MosqueStatus.week;
  return (
    id: m.id,
    point: LatLng(m.latitude!, m.longitude!),
    label: m.name(lang),
    count: state.count,
    live: online && l != null && c.isLiveNow(l, now: at),
    status: status,
    minutes: state.minutes,
    chip: !online || l == null
        ? ''
        : switch (status) {
            MosqueStatus.now => 'lessons.map.now_left'.tr(args: [durationLabel(state.minutes, lang)]),
            MosqueStatus.soon || MosqueStatus.today => 'lessons.map.in'.tr(args: [durationLabel(state.minutes, lang)]),
            MosqueStatus.week => '${relativeDayLabel(l.date, lang)} · ${clockLabel(c.startHours(l), lang)}',
            MosqueStatus.quiet => '',
          },
  );
}

/// Which marker anchors a bubble: what is happening now comes first.
int mapMosquePriority(MapMosque m) => switch (m.status) {
      MosqueStatus.now => m.live ? 7 : 6,
      MosqueStatus.soon => 5,
      MosqueStatus.today => 3,
      MosqueStatus.week => 2,
      MosqueStatus.quiet => 0,
    };

/// Mosques with a lesson on now or later today, the soonest first, for the
/// lists beside the map.
List<MapMosque> activeMapMosques(Iterable<MapMosque> mosques) {
  int order(MapMosque m) => m.status == MosqueStatus.now ? -1 : m.minutes;
  return mosques.where((m) => m.status.index <= MosqueStatus.today.index).toList()
    ..sort((a, b) => order(a).compareTo(order(b)));
}

/// One mosque as a map marker. The further out the map is, the less each one
/// says: only what is happening soon keeps its line.
Marker mosqueMarker(MapMosque m, {required double zoom, bool selected = false, required VoidCallback onTap}) {
  final showChip = switch (m.status) {
    MosqueStatus.now || MosqueStatus.soon => true,
    MosqueStatus.today => zoom >= 11.2,
    MosqueStatus.week => zoom >= kMapQuietMosqueZoom,
    MosqueStatus.quiet => false,
  };
  return Marker(
    key: ValueKey('map-mosque-${m.id}'),
    point: m.point,
    width: 52,
    height: 52,
    child: MosqueArch(
        pin: MosquePin(
            id: m.id,
            lat: m.point.latitude,
            lng: m.point.longitude,
            label: m.label,
            count: m.count,
            live: m.live,
            onSite: m.status == MosqueStatus.now && !m.live,
            quiet: m.status == MosqueStatus.quiet,
            chip: showChip ? m.chip : '',
            chipTone: switch (m.status) {
              MosqueStatus.now => m.live ? MosqueChipTone.live : MosqueChipTone.onSite,
              MosqueStatus.soon || MosqueStatus.today => MosqueChipTone.countdown,
              _ => MosqueChipTone.day,
            }),
        selected: selected,
        onTap: onTap),
  );
}

/// A mosque with something on today, in the lists beside the map.
class MapMosqueTile extends StatelessWidget {
  const MapMosqueTile({super.key, required this.mosque, required this.onTap});
  final MapMosque mosque;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        key: ValueKey('map-mosque-tile-${mosque.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm),
          child: Row(children: [
            const TIcon(TGlyph.mosque, size: 22, color: TC.goldIcon),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mosque.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tStrong(14)),
                Text(mosque.chip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tBody(12, color: mosque.status == MosqueStatus.now ? TC.successFg : TC.bronze, weight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      );
}

/// What is happening right now, at a glance: green at mosques, red in the app.
class MapNowPill extends StatelessWidget {
  const MapNowPill({super.key, required this.onSite, required this.live});
  final int onSite, live;
  @override
  Widget build(BuildContext context) {
    Widget part(Color dot, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(12, color: TC.onNight, weight: FontWeight.w600))),
        ]);
    return Container(
      key: const ValueKey('map-now-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: TC.ink.withValues(alpha: .9), borderRadius: BorderRadius.circular(99)),
      child: Wrap(spacing: 10, runSpacing: 2, children: [
        if (onSite > 0) part(const Color(0xFF5BC184), 'lessons.map.now_mosques'.tr(args: ['$onSite'])),
        if (live > 0) part(const Color(0xFFE5545F), 'lessons.map.now_live'.tr(args: ['$live'])),
      ]),
    );
  }
}

/// A hit for the map's search: a mosque, or a coming lesson at one.
typedef MapSearchHit = ({String mosqueId, String title, String subtitle});

/// Mosques by name or area, then coming lessons by title or preacher.
List<MapSearchHit> searchMapLessons(LessonsController c, String query, String lang, {int limit = 8}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  bool hit(Iterable<String> values) => values.any((v) => v.toLowerCase().contains(q));
  final mosques = c.verifiedMosques.where((m) => m.hasPin);
  final out = <MapSearchHit>[
    for (final m in mosques)
      if (hit([m.nameAr, m.nameEn, c.district(m.districtId)?.nameAr ?? '', c.district(m.districtId)?.nameEn ?? '']))
        (mosqueId: m.id, title: m.name(lang), subtitle: c.district(m.districtId)?.name(lang) ?? ''),
  ];
  final end = addDays(c.today, 6);
  for (final l in c.upcoming) {
    if (l.date.isAfter(end)) continue;
    final p = c.preacher(l.preacherId), m = c.mosque(l.mosqueId);
    if (m == null || !m.hasPin || !m.verified) continue;
    if (hit([l.titleAr, l.titleEn, p?.nameAr ?? '', p?.nameEn ?? ''])) {
      out.add((mosqueId: m.id, title: l.title(lang), subtitle: '${m.name(lang)} · ${relativeDayLabel(l.date, lang)}'));
    }
  }
  return out.take(limit).toList();
}

/// The lesson topics, in the shape the map's topic dropdown takes.
List<AcademicCategoryModel> lessonTopicCategories() => [
      for (final t in LessonsVocab.topics)
        AcademicCategoryModel(id: t, nameEn: topicLabel(t), nameAr: topicLabel(t), iconName: 'mosque'),
    ];

/// What the map shows: broadcasters, mosque lessons, or both.
enum MapLayers { all, streamers, lessons }

class MapLayerSwitch extends StatelessWidget {
  const MapLayerSwitch({super.key, required this.value, required this.onChanged});
  final MapLayers value;
  final ValueChanged<MapLayers> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'map.layers_label'.tr(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (layer, key, glyph) in const [
              (MapLayers.all, 'map.layer_all', null),
              (MapLayers.streamers, 'map.layer_streamers', CaGlyph.video),
              (MapLayers.lessons, 'map.layer_lessons', CaGlyph.cal),
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppTheme.spaceSm),
                child: CaChip(
                    key: ValueKey('map-layer-${layer.name}'),
                    label: key.tr(),
                    icon: glyph,
                    selected: value == layer,
                    onSelected: (_) => onChanged(layer)),
              ),
          ]),
        ),
      );
}

/// The selected mosque: its next lessons, its page and directions.
class MapMosqueCard extends StatelessWidget {
  const MapMosqueCard({super.key, required this.mosqueId, required this.onClose, this.online = true});
  final String mosqueId;
  final VoidCallback onClose;

  /// Without a connection we can't say what is happening now.
  final bool online;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final m = c.mosque(mosqueId);
    if (m == null) return const SizedBox.shrink();
    final lang = context.lang;
    final end = addDays(c.today, 6);
    final lessons = c.upcomingWhere((l) => l.mosqueId == m.id && !l.date.isAfter(end));
    final next = mosqueNow(lessons, c.catalog, DateTime.now()).lesson;
    final preachers = c.listedPreachers.where((p) => p.homeMosqueId == m.id).take(2).toList();
    return TCard(
      key: const ValueKey('map-mosque-card'),
      highlight: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name(lang), style: tStrong(15.5)),
              Text('${c.district(m.districtId)?.name(lang) ?? ''} · ${cityLabel(c.cityOfMosque(m.id))}', style: tBody(13, color: TC.muted)),
            ]),
          ),
          TIconButton(TGlyph.x, tooltip: 'lessons.close'.tr(), onPressed: onClose),
        ]),
        const SizedBox(height: 8),
        if (online && next != null) ...[LessonStatusCard(next), const SizedBox(height: 8)],
        if (lessons.isEmpty)
          Text('lessons.map.none_period'.tr(), style: tBody(13, color: TC.muted))
        else
          for (final l in lessons.take(3)) Padding(padding: const EdgeInsets.only(bottom: 6), child: LessonRow(l, dense: true)),
        if (preachers.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('lessons.map.preachers_here'.tr(), style: tBody(13, color: TC.bronze, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final p in preachers)
                InkWell(
                  onTap: () => context.push('/lessons/preachers/${p.id}'),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      TAvatar(name: p.name(lang), size: 24),
                      const SizedBox(width: 6),
                      Text(p.name(lang), maxLines: 1, style: tBody(13, color: TC.ink, weight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          TButton('lessons.map.mosque_page'.tr(), kind: TBtn.minted, small: true, iconEnd: TGlyph.arrowEnd, onPressed: () => context.push('/lessons/mosques/${m.id}')),
          if (m.directions != null) TButton('lessons.lesson.directions'.tr(), small: true, icon: TGlyph.nav, onPressed: () => openExternal(m.directions!)),
        ]),
      ]),
    );
  }
}

/// A preview of the shared map beside a title and "Open the map": mosques
/// with lessons this week and, when [streamers] are given, the broadcasters'
/// venues. Discover shows both; the Lessons tab shows the mosques.
class MapPreviewCard extends StatelessWidget {
  const MapPreviewCard({super.key, required this.title, required this.body, this.streamers = const []});
  final String title, body;
  final List<StreamerModel> streamers;
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final mosques = context.select<LessonsController?, List<MapMosque>>((c) => c == null
        ? const []
        : mapMosques(c, lang).where((m) => m.status != MosqueStatus.quiet).toList());
    final venues = visibleMapStreamers(streamers);
    final counts = [
      if (streamers.isNotEmpty) 'web.map_count'.plural(venues.length),
      if (mosques.isNotEmpty || streamers.isEmpty)
        '${tPlural('mosques', mosques.length)} ${'lessons.map.with_lessons'.tr()}',
    ].join(' · ');
    final pins = [
      for (final m in mosques)
        MosquePin(
            id: m.id,
            lat: m.point.latitude,
            lng: m.point.longitude,
            label: m.label,
            count: m.count,
            live: m.live,
            onSite: m.status == MosqueStatus.now && !m.live),
    ];
    final markers = [
      for (final s in venues)
        Marker(
          point: LatLng(s.latitude, s.longitude),
          width: 34,
          height: 34,
          child: CaAvatar(
              name: s.getLocalizedName(lang),
              url: s.avatarUrl,
              org: s.isOrganization,
              ring: CaAvatarRing.brand,
              radius: 15),
        ),
    ];
    void open() => context.go('/map');
    final text = Padding(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: tDisplay(22)),
        const SizedBox(height: 8),
        Text(body, style: tBody(14, color: TC.muted)),
        const SizedBox(height: 6),
        Text(counts, style: tBody(13, color: TC.ink2, weight: FontWeight.w600)),
        const SizedBox(height: 14),
        TButton('web.hero_map'.tr(), icon: TGlyph.map, onPressed: open),
      ]),
    );
    final map = SizedBox(height: 240, child: IgnorePointer(child: LessonsMap(pins: pins, markers: markers, interactive: false)));
    return ClipRRect(
      key: const ValueKey('map-preview'),
      borderRadius: BorderRadius.circular(TC.rLg),
      child: TCard(
        padding: EdgeInsets.zero,
        onTap: open,
        child: context.wide
            ? Row(children: [Expanded(flex: 3, child: map), Expanded(flex: 2, child: text)])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [map, text]),
      ),
    );
  }
}

/// Discover's row of mosque lessons in the coming week, hidden when there
/// are none. [web] uses the website's section header and a card grid.
class LessonsRail extends StatefulWidget {
  const LessonsRail({super.key, this.web = false});
  final bool web;
  @override
  State<LessonsRail> createState() => _LessonsRailState();
}

class _LessonsRailState extends State<LessonsRail> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<LessonsController?>()?.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final ids = context.select<LessonsController?, List<String>>((c) {
      if (c == null) return const [];
      final end = addDays(c.today, 6);
      return [for (final l in c.upcoming.where((l) => !l.date.isAfter(end)).take(8)) l.id];
    });
    if (ids.isEmpty) return const SizedBox.shrink();
    final c = context.read<LessonsController>();
    final lessons = [for (final id in ids) c.lesson(id)!];
    void seeAll() => context.go('/lessons');
    if (widget.web) {
      return Padding(
        key: const ValueKey('feed-lessons-rail'),
        padding: const EdgeInsets.only(top: 44),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          HidayahSectionHeader(title: 'feed.lessons_week'.tr(), count: lessons.length, action: 'lessons.see_all'.tr(), onAction: seeAll),
          TGrid(minWidth: 280, children: [for (final l in lessons.take(4)) LessonCard(l)]),
        ]),
      );
    }
    return Column(key: const ValueKey('feed-lessons-rail'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
        child: Row(children: [
          Expanded(child: Text('feed.lessons_week'.tr(), style: Theme.of(context).textTheme.titleMedium)),
          TextButton(onPressed: seeAll, child: Text('lessons.see_all'.tr())),
        ]),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final l in lessons)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppTheme.spaceMd),
              child: SizedBox(width: 280, child: LessonCard(l)),
            ),
        ]),
      ),
      const SizedBox(height: AppTheme.spaceLg),
    ]);
  }
}

/// Settings' card for a person's own programme pages: reminders,
/// notifications, Preachers & lessons for admins, applying to give lessons
/// (or its state), a preacher's page (his account's, or the link that opened
/// on this phone), and the full programme page (following, learning log,
/// preferences).
class LessonsSettingsCard extends StatefulWidget {
  const LessonsSettingsCard({super.key});
  @override
  State<LessonsSettingsCard> createState() => _LessonsSettingsCardState();
}

class _LessonsSettingsCardState extends State<LessonsSettingsCard> {
  String? preacherLink;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<LessonsController?>()?.ensureLoaded());
    unawaited(PreacherLinkController.lastLink().then((t) {
      if (mounted && t != null) setState(() => preacherLink = t);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController?>();
    if (c == null) return const SizedBox.shrink();
    final application = c.myApplication;
    final rows = <(CaGlyph, String, String, String?, int)>[
      (CaGlyph.cal, 'lessons.programme'.tr(), '/lessons/me', 'settings.lessons_hint'.tr(), 0),
      if (c.canManage) (CaGlyph.shield, 'lessons.admin.title'.tr(), '/admin/lessons', null, c.waitingCount),
      // A preacher whose card is linked to this account opens his page here;
      // anyone else signed in can apply to give lessons (ADR-020).
      if (c.myPreacherId != null)
        (CaGlyph.user, 'lessons.me.preacher_page'.tr(), '/lessons/me/preacher', 'lessons.me.preacher_page_hint'.tr(), 0)
      else if (c.signedIn)
        (
          CaGlyph.mic,
          application?.pending == true ? 'lessons.apply.settings_waiting'.tr() : 'lessons.apply.settings_row'.tr(),
          '/lessons/apply',
          application?.pending == true
              ? 'lessons.apply.settings_waiting_hint'.tr()
              : application?.status == 'rejected'
                  ? 'lessons.apply.settings_rejected_hint'.tr()
                  : 'lessons.apply.settings_hint'.tr(),
          0
        ),
      if (preacherLink != null && c.myPreacherId == null)
        (CaGlyph.user, 'lessons.link.my_page'.tr(), '/preacher/$preacherLink', 'lessons.link.my_page_hint'.tr(), 0),
      (CaGlyph.clock, 'lessons.me.reminders'.tr(), '/lessons/me/saved?tab=reminders', null, c.mine.reminders.length),
      (CaGlyph.bell, 'lessons.me.notifications'.tr(), '/lessons/me/notifications', null, c.mine.unread),
    ];
    return CaCard(
      key: const ValueKey('settings-lessons'),
      child: Column(children: [
        for (final (i, (icon, title, route, subtitle, n)) in rows.indexed)
          CaSettingsRow(
              icon: icon,
              title: title,
              subtitle: subtitle,
              badge: n == 0 ? null : TTag('$n', tone: TTone.gold),
              trailing: const RotatedBox(quarterTurns: 2, child: CaIcon(CaGlyph.back)),
              divider: i > 0,
              onTap: () => context.push(route)),
      ]),
    );
  }
}
