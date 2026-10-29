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
import '../../map/presentation/map_visible_catalog.dart';
import '../../profile/models/streamer_models.dart';
import '../../web/presentation/hidayah_web_kit.dart';
import '../domain/lessons_dates.dart';
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

/// A mosque on the map with its approved lessons in the coming week.
typedef MapMosque = ({String id, LatLng point, String label, int count, bool live});

/// Mosques inside the map's area that host a lesson in the next seven days.
List<MapMosque> mapMosques(LessonsController c, String lang) {
  final end = addDays(c.today, 6);
  final counts = <String, int>{};
  final live = <String>{};
  for (final l in c.upcoming) {
    if (l.date.isAfter(end)) continue;
    counts[l.mosqueId] = (counts[l.mosqueId] ?? 0) + 1;
    if (c.isLiveNow(l)) live.add(l.mosqueId);
  }
  return [
    for (final e in counts.entries)
      if (c.mosque(e.key) case final m?
          when m.verified && m.hasPin && LessonsMap.covers(m.latitude!, m.longitude!))
        (id: m.id, point: LatLng(m.latitude!, m.longitude!), label: m.name(lang), count: e.value, live: live.contains(m.id)),
  ];
}

/// The mosque coins as a map layer.
Widget mosqueMarkerLayer(List<MapMosque> mosques, {String? selected, required ValueChanged<MapMosque> onTap}) =>
    MarkerLayer(markers: [
      for (final m in mosques)
        Marker(
          key: ValueKey('map-mosque-${m.id}'),
          point: m.point,
          width: m.id == selected ? 46 : 38,
          height: m.id == selected ? 46 : 38,
          child: MosqueCoin(
              pin: MosquePin(id: m.id, lat: m.point.latitude, lng: m.point.longitude, label: m.label, count: m.count, live: m.live),
              selected: m.id == selected,
              onTap: () => onTap(m)),
        ),
    ]);

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
  const MapMosqueCard({super.key, required this.mosqueId, required this.onClose});
  final String mosqueId;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final m = c.mosque(mosqueId);
    if (m == null) return const SizedBox.shrink();
    final lang = context.lang;
    final end = addDays(c.today, 6);
    final lessons = c.upcomingWhere((l) => l.mosqueId == m.id && !l.date.isAfter(end));
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
        if (lessons.isEmpty)
          Text('lessons.map.none_period'.tr(), style: tBody(13, color: TC.muted))
        else
          for (final l in lessons.take(3)) Padding(padding: const EdgeInsets.only(bottom: 6), child: LessonRow(l, showDate: true)),
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
    final mosques = context.select<LessonsController?, List<MapMosque>>(
        (c) => c == null ? const [] : mapMosques(c, lang));
    final venues = visibleMapStreamers(streamers);
    final counts = [
      if (streamers.isNotEmpty) 'web.map_count'.plural(venues.length),
      if (mosques.isNotEmpty || streamers.isEmpty)
        '${tPlural('mosques', mosques.length)} ${'lessons.map.with_lessons'.tr()}',
    ].join(' · ');
    final pins = [
      for (final m in mosques)
        MosquePin(id: m.id, lat: m.point.latitude, lng: m.point.longitude, label: m.label, count: m.count, live: m.live),
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
