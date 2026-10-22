import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../map/models/map_tricity_domain.dart';
import '../../map/presentation/widgets/tricity_basemap_layer.dart';
import '../../map/services/map_pack_controller.dart';
import 'taysir_kit.dart';

/// One mosque on the lessons map.
class TaysirPin {
  const TaysirPin({required this.id, required this.lat, required this.lng, required this.label, this.count = 0, this.live = false, this.dim = false, this.verified = true});
  final String id, label;
  final double lat, lng;
  final int count;
  final bool live, dim, verified;
}

/// Mosques on the bundled tri-city basemap (the same offline pack as the
/// Spatial Map). Pins outside the pack's area are listed by the caller only.
class TaysirMap extends StatefulWidget {
  const TaysirMap({super.key, required this.pins, this.selected, this.onPin, this.interactive = true, this.focusZoom = 14.5});
  final List<TaysirPin> pins;
  final String? selected;
  final ValueChanged<String>? onPin;
  final bool interactive;
  final double focusZoom;

  /// Widget tests replace the vector map with a plain surface.
  @visibleForTesting
  static bool debugPlaceholder = false;

  static bool covers(double lat, double lng) => kTricityNavigationExtent.contains(lat, lng);

  @override
  State<TaysirMap> createState() => _TaysirMapState();
}

class _TaysirMapState extends State<TaysirMap> {
  final _map = MapController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (!TaysirMap.debugPlaceholder) unawaited(MapPackController.shared.ensureOpened());
  }

  @override
  void didUpdateWidget(TaysirMap old) {
    super.didUpdateWidget(old);
    if (_ready && widget.selected != null && widget.selected != old.selected) {
      final p = widget.pins.where((p) => p.id == widget.selected).firstOrNull;
      if (p != null) _map.move(LatLng(p.lat, p.lng), widget.focusZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (TaysirMap.debugPlaceholder) {
      return Container(color: const Color(0xFFF4EBDA), alignment: Alignment.center, child: Text('${widget.pins.length}'));
    }
    final sel = widget.pins.where((p) => p.id == widget.selected).firstOrNull;
    return ClipRect(
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: sel != null ? LatLng(sel.lat, sel.lng) : kTricityOverviewExtent.center,
          initialZoom: sel != null ? widget.focusZoom : 11.2,
          minZoom: 9,
          maxZoom: kMapMaxZoom,
          backgroundColor: const Color(0xFFF4EBDA),
          cameraConstraint: CameraConstraint.contain(bounds: kTricityNavigationExtent.bounds),
          interactionOptions: InteractionOptions(
              flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none),
          onMapReady: () => _ready = true,
        ),
        children: [
          TricityBasemapLayer(controller: MapPackController.shared),
          MarkerLayer(markers: [
            for (final p in widget.pins.where((p) => TaysirMap.covers(p.lat, p.lng)))
              Marker(
                point: LatLng(p.lat, p.lng),
                width: p.id == widget.selected ? 46 : 38,
                height: p.id == widget.selected ? 46 : 38,
                child: TaysirMosqueCoin(pin: p, selected: p.id == widget.selected, onTap: widget.onPin == null ? null : () => widget.onPin!(p.id)),
              ),
          ]),
        ],
      ),
    );
  }
}

/// A mosque coin: its lesson count, ringed red while one is streamed live.
class TaysirMosqueCoin extends StatelessWidget {
  const TaysirMosqueCoin({super.key, required this.pin, this.selected = false, this.onTap});
  final TaysirPin pin;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        selected: selected,
        label: '${pin.label}, ${tPlural('lessons', pin.count)}',
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: pin.dim ? .45 : 1,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(center: Alignment(0, -.4), colors: [HidayahGold.g300, HidayahGold.g400, HidayahGold.g500]),
                border: Border.all(
                    color: pin.live ? TC.live : (selected ? TC.ink : HidayahGold.g800),
                    width: pin.live || selected ? 3 : 1.2),
                boxShadow: const [BoxShadow(color: Color(0x594B320E), blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: pin.verified
                  ? Text(pin.count > 0 ? '${pin.count}' : '', style: tStrong(13, color: TC.ink))
                  : const TIcon(TGlyph.plus, size: 14, color: TC.ink),
            ),
          ),
        ),
      );
}

/// Tap to place a mosque's pin.
class TaysirPinPicker extends StatelessWidget {
  const TaysirPinPicker({super.key, required this.value, required this.onPick});
  final (double, double)? value;
  final ValueChanged<(double, double)> onPick;
  @override
  Widget build(BuildContext context) {
    if (TaysirMap.debugPlaceholder) {
      return GestureDetector(
        onTap: () => onPick((26.29, 50.2)),
        child: Container(color: const Color(0xFFF4EBDA), alignment: Alignment.center, child: Text(value == null ? 'taysir.submit.tap_map'.tr() : '✓')),
      );
    }
    unawaited(MapPackController.shared.ensureOpened());
    return ClipRRect(
      borderRadius: BorderRadius.circular(TC.r),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: value == null ? kTricityOverviewExtent.center : LatLng(value!.$1, value!.$2),
          initialZoom: value == null ? 11.2 : 15,
          minZoom: 9,
          maxZoom: kMapMaxZoom,
          backgroundColor: const Color(0xFFF4EBDA),
          cameraConstraint: CameraConstraint.contain(bounds: kTricityNavigationExtent.bounds),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onTap: (_, p) => onPick((double.parse(p.latitude.toStringAsFixed(6)), double.parse(p.longitude.toStringAsFixed(6)))),
        ),
        children: [
          TricityBasemapLayer(controller: MapPackController.shared),
          if (value != null)
            MarkerLayer(markers: [
              Marker(
                point: LatLng(value!.$1, value!.$2),
                width: 36,
                height: 36,
                child: const TIcon(TGlyph.pin, size: 36, color: TC.live, stroke: 2.2),
              ),
            ]),
        ],
      ),
    );
  }
}
