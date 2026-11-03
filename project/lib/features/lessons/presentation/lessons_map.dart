import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../map/models/map_tricity_domain.dart';
import '../../map/presentation/widgets/tricity_basemap_layer.dart';
import '../../map/services/map_pack_controller.dart';
import 'lessons_kit.dart';

/// The line under a mosque: green while a lesson is on, red when it is also
/// live, dark for a countdown, light for a day and time.
enum MosqueChipTone { onSite, live, countdown, day }

/// One mosque on the lessons map.
class MosquePin {
  const MosquePin(
      {required this.id,
      required this.lat,
      required this.lng,
      required this.label,
      this.count = 0,
      this.live = false,
      this.onSite = false,
      this.quiet = false,
      this.dim = false,
      this.verified = true,
      this.chip = '',
      this.chipTone = MosqueChipTone.day});
  final String id, label, chip;
  final double lat, lng;
  final int count;

  /// [onSite]: a lesson is on at the mosque now. [live]: and it is streaming.
  /// [quiet]: nothing is coming up, so the arch is hollow.
  final bool live, onSite, quiet, dim, verified;
  final MosqueChipTone chipTone;
}

/// Mosques on the bundled tri-city basemap (the same offline pack as the
/// Spatial Map). Pins outside the pack's area are listed by the caller only.
class LessonsMap extends StatefulWidget {
  const LessonsMap({super.key, required this.pins, this.selected, this.onPin, this.interactive = true, this.focusZoom = 14.5, this.markers = const []});
  final List<MosquePin> pins;
  final String? selected;
  final ValueChanged<String>? onPin;
  final bool interactive;
  final double focusZoom;

  /// Other pins drawn above the mosques (broadcasters' venues on Discover).
  final List<Marker> markers;

  /// Widget tests replace the vector map with a plain surface.
  @visibleForTesting
  static bool debugPlaceholder = false;

  /// For other lessons maps that stand in for the vector map in widget tests.
  static bool get placeholderOn => debugPlaceholder;

  static bool covers(double lat, double lng) => kTricityNavigationExtent.contains(lat, lng);

  @override
  State<LessonsMap> createState() => _LessonsMapState();
}

class _LessonsMapState extends State<LessonsMap> {
  final _map = MapController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (!LessonsMap.debugPlaceholder) unawaited(MapPackController.shared.ensureOpened());
  }

  @override
  void didUpdateWidget(LessonsMap old) {
    super.didUpdateWidget(old);
    if (_ready && widget.selected != null && widget.selected != old.selected) {
      final p = widget.pins.where((p) => p.id == widget.selected).firstOrNull;
      if (p != null) _map.move(LatLng(p.lat, p.lng), widget.focusZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (LessonsMap.debugPlaceholder) {
      return Container(color: const Color(0xFFF4EBDA), alignment: Alignment.center, child: Text('${widget.pins.length + widget.markers.length}'));
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
            for (final p in widget.pins.where((p) => LessonsMap.covers(p.lat, p.lng)))
              Marker(
                point: LatLng(p.lat, p.lng),
                width: 52,
                height: 52,
                child: MosqueArch(pin: p, selected: p.id == widget.selected, onTap: widget.onPin == null ? null : () => widget.onPin!(p.id)),
              ),
          ]),
          if (widget.markers.isNotEmpty) MarkerLayer(markers: widget.markers),
        ],
      ),
    );
  }
}

/// A mosque on any map: a gold arch holding its lesson count, so it can't be
/// taken for a streamer's round photo. Red only ever means live in the app,
/// green only ever means on at the mosque.
class MosqueArch extends StatefulWidget {
  const MosqueArch({super.key, required this.pin, this.selected = false, this.onTap});
  final MosquePin pin;
  final bool selected;
  final VoidCallback? onTap;
  @override
  State<MosqueArch> createState() => _MosqueArchState();
}

class _MosqueArchState extends State<MosqueArch> with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  bool get _active => widget.pin.live || widget.pin.onSite;

  // Only a mosque with something on animates, and never in widget tests that
  // stand in for the map: a repeating animation would never settle.
  void _syncPulse() {
    final run = _active &&
        !LessonsMap.debugPlaceholder &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (run) {
      final pulse = _pulse ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
      if (!pulse.isAnimating) pulse.repeat();
    } else {
      _pulse?.reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(MosqueArch old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin, selected = widget.selected;
    final width = pin.quiet ? 28.0 : (selected ? 44.0 : 38.0), height = width * 46 / 40;
    final pulse = _pulse;
    return Semantics(
      button: widget.onTap != null,
      selected: selected,
      label: [pin.label, tPlural('lessons', pin.count), if (pin.chip.isNotEmpty) pin.chip].join(', '),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: pin.dim ? .45 : 1,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            if (pulse != null && _active)
              RepaintBoundary(child: _Ripple(animation: pulse, color: pin.live ? TC.live : TC.successFg)),
            CustomPaint(
                size: Size(width, height),
                painter: _ArchPainter(hollow: pin.quiet, selected: selected)),
            if (!pin.quiet)
              Padding(
                padding: EdgeInsets.only(top: height * .2),
                child: pin.verified
                    ? Text(pin.count > 0 ? '${pin.count}' : '', style: tStrong(13, color: TC.ink))
                    : const TIcon(TGlyph.plus, size: 14, color: TC.ink),
              ),
            if (pin.live)
              Positioned(
                top: -7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(color: TC.live, borderRadius: BorderRadius.circular(8)),
                  child: Text('lessons.lesson.live'.tr(), style: tStrong(8.5, color: HidayahGold.card)),
                ),
              ),
            if (pin.chip.isNotEmpty)
              Positioned(
                top: 26 + height / 2,
                left: -80,
                right: -80,
                child: Center(child: _Chip(pin.chip, pin.chipTone)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  const _Ripple({required this.animation, required this.color});
  final Animation<double> animation;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(animation.value);
          return Transform.scale(
            scale: 1 + t * .9,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: (1 - t) * .28),
                border: Border.all(color: color.withValues(alpha: (1 - t) * .7), width: 1.5),
              ),
            ),
          );
        },
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.tone);
  final String text;
  final MosqueChipTone tone;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      MosqueChipTone.onSite => (TC.successFg, HidayahGold.card),
      MosqueChipTone.live => (TC.live, HidayahGold.card),
      MosqueChipTone.countdown => (TC.ink, HidayahGold.g200),
      MosqueChipTone.day => (HidayahGold.card, TC.ink2),
    };
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: tone == MosqueChipTone.day ? Border.all(color: TC.hair) : null,
          boxShadow: const [BoxShadow(color: Color(0x4D151D24), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Text(text, maxLines: 1, style: tStrong(10.5, color: fg)),
      ),
    );
  }
}

class _ArchPainter extends CustomPainter {
  const _ArchPainter({required this.hollow, required this.selected});
  final bool hollow, selected;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 40, y = size.height / 46;
    final arch = Path()
      ..moveTo(3 * x, 44 * y)
      ..lineTo(3 * x, 23 * y)
      ..cubicTo(3 * x, 12.5 * y, 12 * x, 7.5 * y, 20 * x, 2 * y)
      ..cubicTo(28 * x, 7.5 * y, 37 * x, 12.5 * y, 37 * x, 23 * y)
      ..lineTo(37 * x, 44 * y)
      ..close();
    canvas.drawShadow(arch, const Color(0xFF4B320E), 3, false);
    final area = Offset.zero & size;
    canvas.drawPath(
        arch,
        hollow
            ? (Paint()..color = HidayahGold.card)
            : (Paint()..shader = HidayahGradients.minted.createShader(area)));
    canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = selected ? 3 : (hollow ? 2.2 : 1.3)
          ..color = selected ? TC.ink : (hollow ? HidayahGold.g600 : HidayahGold.g800));
  }

  @override
  bool shouldRepaint(_ArchPainter old) => old.hollow != hollow || old.selected != selected;
}

/// Tap to place a mosque's pin.
class MosquePinPicker extends StatelessWidget {
  const MosquePinPicker({super.key, required this.value, required this.onPick});
  final (double, double)? value;
  final ValueChanged<(double, double)> onPick;
  @override
  Widget build(BuildContext context) {
    if (LessonsMap.debugPlaceholder) {
      return GestureDetector(
        onTap: () => onPick((26.29, 50.2)),
        child: Container(color: const Color(0xFFF4EBDA), alignment: Alignment.center, child: Text(value == null ? 'lessons.submit.tap_map'.tr() : '✓')),
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
