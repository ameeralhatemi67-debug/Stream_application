import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/lessons_names.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_modals.dart';
import '../lessons_widgets.dart';
import 'lessons_admin_modals.dart';
import 'place_option_widgets.dart';

/// The Mosques page's map: every mosque with a pin, a city and an area to
/// choose (the map moves to them) and a way to add more cities and areas.
class MosquesMapView extends StatefulWidget {
  const MosquesMapView({super.key});
  @override
  State<MosquesMapView> createState() => _MosquesMapViewState();
}

class _MosquesMapViewState extends State<MosquesMapView> {
  String city = 'khobar';
  String? district, selectedMosque;

  /// The next tap on the map sets the location of the chosen city or area.
  bool placing = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final cityIds = LessonsNames.cityIds.where((x) => x != 'other').toList();
    if (!cityIds.contains(city) && cityIds.isNotEmpty) city = cityIds.first;
    final districts = c.districtsOf(city);
    if (district != null && !districts.any((d) => d.id == district)) district = null;
    final d = district == null ? null : c.district(district);
    final cityRow = c.catalog.cities[city];

    final (double, double) centre;
    final double zoom;
    if (d != null && d.hasPin) {
      centre = (d.latitude!, d.longitude!);
      zoom = 15;
    } else if (cityRow != null && cityRow.hasPin) {
      centre = (cityRow.latitude!, cityRow.longitude!);
      zoom = cityRow.zoom.toDouble();
    } else {
      centre = LessonsNames.centre(city) ?? (26.35, 50.12);
      zoom = 12;
    }
    final inView = [
      for (final m in c.catalog.mosques.values)
        if (c.cityOfMosque(m.id) == city && (district == null || m.districtId == district)) m
    ];
    final pinned = inView.where((m) => m.hasPin).toList();
    final target = d != null ? d.name(lang) : cityLabel(city);
    final targetHasPin = d != null ? d.hasPin : (cityRow?.hasPin ?? false);
    final picked = selectedMosque == null ? null : c.mosque(selectedMosque);

    void pickCity(String id) => setState(() {
          city = id;
          district = null;
          selectedMosque = null;
          placing = false;
        });
    void pickDistrict(String? id) => setState(() {
          district = id;
          selectedMosque = null;
          placing = false;
        });

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('lessons.mosques.map_body'.tr(), style: tBody(14, color: TC.muted)),
      const SizedBox(height: 12),
      LabelWithAdd('lessons.submit.city'.tr(), addKey: const ValueKey('map-city-plus'), onAdd: () async {
        final id = await showAddPlaceSheet(context);
        if (id != null && mounted) pickCity(id);
      }),
      FitOrDropdown(
        labels: [for (final x in cityIds) cityLabel(x)],
        perItem: 36,
        fits: () => TSeg<String>(value: city, onChanged: pickCity, options: [for (final x in cityIds) TSegOption(x, cityLabel(x))]),
        dropdown: () => DropdownButtonFormField<String>(
          key: ValueKey('map-city-$city-${cityIds.length}'),
          initialValue: city,
          isExpanded: true,
          decoration: tInput(),
          items: [for (final x in cityIds) DropdownMenuItem(value: x, child: Text(cityLabel(x)))],
          onChanged: (v) {
            if (v != null) pickCity(v);
          },
        ),
      ),
      const SizedBox(height: 14),
      LabelWithAdd('lessons.submit.district'.tr(), addKey: const ValueKey('map-district-plus'), onAdd: () async {
        final id = await showAddPlaceSheet(context, cityId: city);
        if (id != null && mounted) pickDistrict(id);
      }),
      FitOrDropdown(
        labels: [for (final x in districts) x.name(lang)],
        fits: () => TChips([
          for (final x in districts) TChip(x.name(lang), small: true, selected: district == x.id, onTap: () => pickDistrict(district == x.id ? null : x.id)),
        ]),
        dropdown: () => DropdownButtonFormField<String?>(
          key: ValueKey('map-district-$city-$district-${districts.length}'),
          initialValue: district,
          isExpanded: true,
          decoration: tInput(),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('lessons.all'.tr())),
            for (final x in districts) DropdownMenuItem<String?>(value: x.id, child: Text(x.name(lang))),
          ],
          onChanged: pickDistrict,
        ),
      ),
      const SizedBox(height: 12),
      if (!targetHasPin)
        TCallout(
          key: const ValueKey('map-no-location'),
          tone: TTone.info,
          icon: TGlyph.pin,
          action: TButton(placing ? 'lessons.cancel'.tr() : 'lessons.mosques.map_set'.tr(),
              key: const ValueKey('map-set-location'), small: true, onPressed: () => setState(() => placing = !placing)),
          child: Text(placing ? 'lessons.mosques.map_placing'.tr(args: [target]) : 'lessons.mosques.map_unplaced'.tr(args: [target])),
        ),
      if (!targetHasPin) const SizedBox(height: 12),
      SizedBox(
        height: 420,
        child: PlaceMap(
          center: centre,
          zoom: zoom,
          markers: [for (final m in pinned) PlaceMarker(id: m.id, lat: m.latitude!, lng: m.longitude!, label: m.name(lang))],
          onMarkerTap: (id) => setState(() => selectedMosque = id),
          onTap: !placing
              ? null
              : (p) async {
                  final kind = d != null ? 'district' : 'city';
                  final id = d?.id ?? city;
                  setState(() => placing = false);
                  await tRun(context, () => c.setPlaceLocation(kind, id, p.$1, p.$2), success: 'lessons.mosques.map_placed'.tr());
                },
        ),
      ),
      const SizedBox(height: 8),
      Text(
          '${tPlural('mosques', inView.length)} · ${'lessons.mosques.map_on_map'.tr(args: ['${pinned.length}'])}'
          '${inView.length > pinned.length ? ' · ${'lessons.mosques.map_off_map'.tr(args: ['${inView.length - pinned.length}'])}' : ''}',
          key: const ValueKey('map-count'),
          style: tBody(13, color: TC.muted)),
      if (picked != null) ...[
        const SizedBox(height: 10),
        TCard(
          key: const ValueKey('map-picked'),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(picked.name(lang), style: tStrong(15)),
            Text(c.district(picked.districtId)?.name(lang) ?? '', style: tBody(12.5, color: TC.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (picked.directions != null)
                TButton('lessons.mosques.open_maps'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.map, onPressed: () => openExternal(picked.directions!)),
              TButton('lessons.lesson.edit'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.edit, onPressed: () => showMosqueSheet(context, mosque: picked)),
            ]),
          ]),
        ),
      ],
    ]);
  }
}
