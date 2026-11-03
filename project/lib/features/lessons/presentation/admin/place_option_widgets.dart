import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../../domain/lessons_models.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_map.dart';
import '../lessons_widgets.dart';

/// The «+» next to a field: adds one more option to it.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TIconButton(TGlyph.plus, tooltip: 'lessons.add.plus_tip'.tr(), onPressed: onPressed);
}

/// A label with a «+» at its end (the left in Arabic, the right in English).
class LabelWithAdd extends StatelessWidget {
  const LabelWithAdd(this.text, {super.key, required this.onAdd, this.addKey});
  final String text;
  final VoidCallback onAdd;
  final Key? addKey;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Expanded(child: Text(text, style: tBody(13, color: TC.ink2, weight: FontWeight.w700))),
          KeyedSubtree(key: addKey, child: AddButton(onPressed: onAdd)),
        ]),
      );
}

/// A dropdown with a «+» at its end, for topics, languages and audiences.
class DropdownWithAdd extends StatelessWidget {
  const DropdownWithAdd({super.key, required this.field, required this.onAdd});
  final Widget field;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: field),
        const SizedBox(width: 6),
        AddButton(onPressed: onAdd),
      ]);
}

/// Shows [fits] while every label fits on one row, else [dropdown]: a few
/// cities or areas stay chips, a long list becomes a dropdown menu.
class FitOrDropdown extends StatelessWidget {
  const FitOrDropdown({super.key, required this.labels, required this.fits, required this.dropdown, this.perItem = 24});
  final List<String> labels;
  final Widget Function() fits;
  final Widget Function() dropdown;

  /// Padding and border of one chip, added to its text.
  final double perItem;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final style = tBody(13, weight: FontWeight.w600, height: 1.2);
        final dir = Directionality.of(context);
        var total = 0.0;
        for (final l in labels) {
          final tp = TextPainter(text: TextSpan(text: l, style: style), textDirection: dir, maxLines: 1)..layout();
          total += tp.width + perItem + 6;
        }
        return total <= box.maxWidth ? fits() : dropdown();
      });
}

/// The names that contain what was typed (all of them while nothing is).
List<DropdownMenuEntry<String>> filterMosqueEntries(List<DropdownMenuEntry<String>> entries, String text) {
  final q = text.trim().toLowerCase();
  return q.isEmpty ? entries : entries.where((e) => e.label.toLowerCase().contains(q)).toList();
}

/// A mosque picked from a dropdown that can also be typed into.
class MosqueTypeahead extends StatelessWidget {
  const MosqueTypeahead({super.key, required this.mosques, required this.lang, required this.districtName, required this.selected, required this.onSelected, this.hint});
  final List<Mosque> mosques;
  final String lang;
  final String Function(Mosque) districtName;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String? hint;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        String label(Mosque m) => '${m.name(lang)} · ${districtName(m)}';
        return DropdownMenu<String>(
          key: ValueKey('mosque-typeahead-${mosques.length}-$selected'),
          width: box.maxWidth,
          menuHeight: 320,
          enabled: mosques.isNotEmpty,
          initialSelection: mosques.any((m) => m.id == selected) ? selected : null,
          hintText: hint,
          requestFocusOnTap: true,
          enableFilter: true,
          // Typing narrows the list to the names that contain the text.
          filterCallback: filterMosqueEntries,
          inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            filled: true,
            fillColor: TC.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TC.hair2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TC.hair2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TC.gold, width: 2)),
          ),
          textStyle: tBody(15, color: TC.ink),
          dropdownMenuEntries: [for (final m in mosques) DropdownMenuEntry<String>(value: m.id, label: label(m))],
          onSelected: (v) {
            if (v != null) onSelected(v);
          },
        );
      });
}

// ------------------------------------------------------------------ the map
/// A map for placing and finding things: pins of mosques, the centre of a
/// city or area, a tap to put a point. It moves when [center] changes. It uses
/// the public map tiles (an admin tool), not the offline tri-city pack, so any
/// city an admin adds has a map.
class PlaceMap extends StatefulWidget {
  const PlaceMap({super.key, required this.center, this.zoom = 12, this.markers = const [], this.onTap, this.onMarkerTap});
  final (double, double) center;
  final double zoom;
  final List<PlaceMarker> markers;
  final ValueChanged<(double, double)>? onTap;
  final ValueChanged<String>? onMarkerTap;
  @override
  State<PlaceMap> createState() => _PlaceMapState();
}

class PlaceMarker {
  const PlaceMarker({required this.id, required this.lat, required this.lng, this.label = '', this.mosque = true});
  final String id, label;
  final double lat, lng;

  /// A mosque (the arch) or a plain point (a place being put).
  final bool mosque;
}

class _PlaceMapState extends State<PlaceMap> {
  final controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(PlaceMap old) {
    super.didUpdateWidget(old);
    if (_ready && (old.center != widget.center || old.zoom != widget.zoom)) {
      controller.move(LatLng(widget.center.$1, widget.center.$2), widget.zoom);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (LessonsMap.placeholderOn) {
      return GestureDetector(
        key: const ValueKey('place-map'),
        onTap: () => widget.onTap?.call((widget.center.$1 + 0.001, widget.center.$2 + 0.001)),
        child: Container(
          color: const Color(0xFFF4EBDA),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('map ${widget.center.$1.toStringAsFixed(3)},${widget.center.$2.toStringAsFixed(3)} z${widget.zoom.round()}', key: const ValueKey('place-map-view')),
            for (final m in widget.markers)
              GestureDetector(key: ValueKey('place-marker-${m.id}'), onTap: () => widget.onMarkerTap?.call(m.id), child: Text('pin ${m.label}')),
          ]),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(TC.r),
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: LatLng(widget.center.$1, widget.center.$2),
          initialZoom: widget.zoom,
          minZoom: 4,
          maxZoom: 19,
          backgroundColor: const Color(0xFFF4EBDA),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onMapReady: () => _ready = true,
          onTap: widget.onTap == null ? null : (_, p) => widget.onTap!((double.parse(p.latitude.toStringAsFixed(6)), double.parse(p.longitude.toStringAsFixed(6)))),
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'sa.hadayah.streamer_app'),
          MarkerLayer(markers: [
            for (final m in widget.markers)
              Marker(
                point: LatLng(m.lat, m.lng),
                width: 34,
                height: 34,
                child: GestureDetector(
                  onTap: widget.onMarkerTap == null ? null : () => widget.onMarkerTap!(m.id),
                  child: Tooltip(message: m.label, child: TIcon(m.mosque ? TGlyph.mosque : TGlyph.pin, size: 34, color: m.mosque ? TC.bronze : TC.live, stroke: 2.2)),
                ),
              ),
          ]),
          const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- sheets
/// Adds a topic, language or audience ([kind]) and returns its code. Ticking
/// "keep" saves it for later lessons; unticked it is for this lesson only.
Future<String?> showAddOptionSheet(BuildContext context, String kind) {
  final c = context.read<LessonsController>();
  final ar = TextEditingController(), en = TextEditingController();
  var keep = false;
  return showTModal<String>(context,
      title: 'lessons.add.option_title.$kind'.tr(),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'lessons.mosques.name_ar'.tr(), required: true, child: TextField(key: const ValueKey('option-name-ar'), controller: ar, onChanged: (_) => set(() {}), decoration: tInput())),
              const SizedBox(height: 12),
              TField(
                  label: '${'lessons.mosques.name_en'.tr()} (${'lessons.optional'.tr()})',
                  child: TextField(key: const ValueKey('option-name-en'), controller: en, textDirection: TextDirection.ltr, decoration: tInput())),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const ValueKey('option-keep'),
                value: keep,
                onChanged: (v) => set(() => keep = v ?? false),
                activeColor: TC.gold,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('lessons.add.option_keep'.tr(), style: tBody(14, color: TC.ink, weight: FontWeight.w600)),
                subtitle: Text('lessons.add.option_keep_hint'.tr(), style: tBody(12.5, color: TC.muted)),
              ),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.save'.tr(), key: const ValueKey('option-save'), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
              if (ar.text.trim().length < 2) return tToast(ctx, 'lessons.add.name_needed'.tr(), warn: true);
              final code = await tRun(context, () => c.addOption(kind, ar.text.trim(), en.text.trim(), permanent: keep));
              if (code != null && ctx.mounted) Navigator.of(ctx).pop(code);
            }),
          ]);
}

/// Adds a city ([cityId] null) or an area of [cityId]; the admin may tap the
/// map to put it. Returns the new id.
Future<String?> showAddPlaceSheet(BuildContext context, {String? cityId}) {
  final c = context.read<LessonsController>();
  final ar = TextEditingController(), en = TextEditingController();
  final base = cityId == null ? null : c.catalog.cities[cityId];
  (double, double)? pin;
  final centre = base != null && base.hasPin ? (base.latitude!, base.longitude!) : (26.35, 50.12);
  return showTModal<String>(context,
      title: cityId == null ? 'lessons.add.city_title'.tr() : 'lessons.add.district_title'.tr(),
      subtitle: base == null ? null : cityLabel(base.id),
      wide: true,
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'lessons.mosques.name_ar'.tr(), required: true, child: TextField(key: const ValueKey('place-name-ar'), controller: ar, decoration: tInput())),
              const SizedBox(height: 12),
              TField(
                  label: '${'lessons.mosques.name_en'.tr()} (${'lessons.optional'.tr()})',
                  child: TextField(key: const ValueKey('place-name-en'), controller: en, textDirection: TextDirection.ltr, decoration: tInput())),
              const SizedBox(height: 12),
              Text('lessons.add.place_pin'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              SizedBox(
                  height: 220,
                  child: PlaceMap(
                      center: pin ?? centre,
                      zoom: pin != null ? 14 : (cityId == null ? 9 : 12),
                      markers: [if (pin != null) PlaceMarker(id: 'new', lat: pin!.$1, lng: pin!.$2, mosque: false)],
                      onTap: (p) => set(() => pin = p))),
              const SizedBox(height: 6),
              Text('lessons.add.place_pin_hint'.tr(), style: tBody(12.5, color: TC.muted)),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.save'.tr(), key: const ValueKey('place-save'), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
              if (ar.text.trim().length < 2) return tToast(ctx, 'lessons.add.name_needed'.tr(), warn: true);
              final id = await tRun(
                  context,
                  () => cityId == null
                      ? c.addCity(ar.text.trim(), en.text.trim(), lat: pin?.$1, lon: pin?.$2)
                      : c.addDistrict(cityId, ar.text.trim(), en.text.trim(), lat: pin?.$1, lon: pin?.$2));
              if (id != null && ctx.mounted) Navigator.of(ctx).pop(id);
            }),
          ]);
}
