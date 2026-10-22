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
import '../../web/presentation/hidayah_web_kit.dart';
import '../domain/taysir_dates.dart';
import '../state/taysir_controller.dart';
import 'taysir_kit.dart';
import 'taysir_map.dart';
import 'taysir_modals.dart';
import 'taysir_widgets.dart';

// The places where Taysir, the mosque lessons programme, shows inside Hadayah
// Live's own screens (ADR-014): mosques on the map, a lessons row on
// Discover, and a person's programme pages in Settings. Each reads the
// TaysirController when the app provides one and shows nothing without it.

/// A mosque on the map with its approved lessons in the coming week.
typedef MapMosque = ({String id, LatLng point, String label, int count, bool live});

/// Mosques inside the map's area that host a lesson in the next seven days.
List<MapMosque> mapMosques(TaysirController c, String lang) {
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
          when m.verified && m.hasPin && TaysirMap.covers(m.latitude!, m.longitude!))
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
          child: TaysirMosqueCoin(
              pin: TaysirPin(id: m.id, lat: m.point.latitude, lng: m.point.longitude, label: m.label, count: m.count, live: m.live),
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
    final c = context.watch<TaysirController>();
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
          TIconButton(TGlyph.x, tooltip: 'taysir.close'.tr(), onPressed: onClose),
        ]),
        const SizedBox(height: 8),
        if (lessons.isEmpty)
          Text('taysir.map.none_period'.tr(), style: tBody(13, color: TC.muted))
        else
          for (final l in lessons.take(3)) Padding(padding: const EdgeInsets.only(bottom: 6), child: LessonRow(l, showDate: true)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          TButton('taysir.map.mosque_page'.tr(), kind: TBtn.minted, small: true, iconEnd: TGlyph.arrowEnd, onPressed: () => context.push('/taysir/mosques/${m.id}')),
          if (m.directions != null) TButton('taysir.lesson.directions'.tr(), small: true, icon: TGlyph.nav, onPressed: () => openExternal(m.directions!)),
        ]),
      ]),
    );
  }
}

/// Discover's row of mosque lessons in the coming week, hidden when there
/// are none. [web] uses the website's section header and a card grid.
class TaysirLessonsRail extends StatefulWidget {
  const TaysirLessonsRail({super.key, this.web = false});
  final bool web;
  @override
  State<TaysirLessonsRail> createState() => _TaysirLessonsRailState();
}

class _TaysirLessonsRailState extends State<TaysirLessonsRail> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<TaysirController?>()?.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final ids = context.select<TaysirController?, List<String>>((c) {
      if (c == null) return const [];
      final end = addDays(c.today, 6);
      return [for (final l in c.upcoming.where((l) => !l.date.isAfter(end)).take(8)) l.id];
    });
    if (ids.isEmpty) return const SizedBox.shrink();
    final c = context.read<TaysirController>();
    final lessons = [for (final id in ids) c.lesson(id)!];
    void seeAll() => context.go('/taysir');
    if (widget.web) {
      return Padding(
        key: const ValueKey('feed-lessons-rail'),
        padding: const EdgeInsets.only(top: 44),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          HidayahSectionHeader(title: 'feed.lessons_week'.tr(), count: lessons.length, action: 'taysir.see_all'.tr(), onAction: seeAll),
          TGrid(minWidth: 280, children: [for (final l in lessons.take(4)) LessonCard(l)]),
        ]),
      );
    }
    return Column(key: const ValueKey('feed-lessons-rail'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
        child: Row(children: [
          Expanded(child: Text('feed.lessons_week'.tr(), style: Theme.of(context).textTheme.titleMedium)),
          TextButton(onPressed: seeAll, child: Text('taysir.see_all'.tr())),
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
/// notifications, their lessons as a preacher, the console as a coordinator,
/// and the full programme page (following, learning log, preferences, roles).
class TaysirSettingsCard extends StatefulWidget {
  const TaysirSettingsCard({super.key});
  @override
  State<TaysirSettingsCard> createState() => _TaysirSettingsCardState();
}

class _TaysirSettingsCardState extends State<TaysirSettingsCard> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<TaysirController?>()?.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController?>();
    if (c == null) return const SizedBox.shrink();
    final rows = <(CaGlyph, String, String, String?, int)>[
      (CaGlyph.cal, 'taysir.programme'.tr(), '/taysir/me', 'settings.lessons_hint'.tr(), 0),
      if (c.canCoordinate) (CaGlyph.shield, 'taysir.me.console'.tr(), '/taysir/console', null, c.pendingRequests.length),
      if (c.canSubmitOwn) (CaGlyph.edit, 'taysir.me.my_lessons'.tr(), '/taysir/me/lessons', null, 0),
      (CaGlyph.clock, 'taysir.me.reminders'.tr(), '/taysir/me/saved?tab=reminders', null, c.mine.reminders.length),
      (CaGlyph.bell, 'taysir.me.notifications'.tr(), '/taysir/me/notifications', null, c.mine.unread),
    ];
    return CaCard(
      key: const ValueKey('settings-taysir'),
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
