import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../map/models/map_tricity_domain.dart';
import '../../../map/presentation/map_viewport_policy.dart';
import '../../../map/presentation/widgets/map_status_details.dart';
import '../../../map/presentation/widgets/tricity_basemap_layer.dart';
import '../../../map/services/map_pack_controller.dart';

/// The exact point the user placed. Nothing else is inferred: no
/// neighbourhood, address or city is guessed from coordinates. The venue
/// name/address stays the user's own typed text and the city stays their
/// explicit choice.
class LocationPickerResult {
  final LatLng coordinates;

  const LocationPickerResult({required this.coordinates});
}

/// Formats coordinates the same way everywhere they are shown back to the
/// user (5 decimals, about one metre).
String formatPickerCoordinates(LatLng point) =>
    '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

/// Venue pin picker on the same bundled three-city map as the Spatial Map
/// (works offline, same zoom limits and camera policy). New points can only
/// be placed inside the three-city map; an existing saved point elsewhere is
/// shown as a notice and kept unless the user places a new one.
class LocationPickerModal extends StatefulWidget {
  final LatLng? initialLocation;

  /// City view to frame when there is no saved point yet (`khobar`,
  /// `dhahran`, `dammam`); anything else frames all three cities.
  final String? initialCityId;
  final MapPackController? packController;

  const LocationPickerModal({
    super.key,
    this.initialLocation,
    this.initialCityId,
    this.packController,
  });

  static Future<LocationPickerResult?> show({
    required BuildContext context,
    LatLng? initialLocation,
    String? initialCity,
  }) {
    return showModalBottomSheet<LocationPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationPickerModal(
        initialLocation: initialLocation,
        initialCityId: initialCity,
      ),
    );
  }

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  static const MapViewportPolicy _policy = MapViewportPolicy();
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(16, 16, 72, 56);

  late final MapController _mapController;
  late final MapPackController _pack;
  LatLng? _picked;

  /// A saved point outside the map (legacy or other-city venue). Shown and
  /// preserved; never clamped onto the map.
  LatLng? _savedOutside;
  Size _canvas = Size.zero;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pack = widget.packController ?? MapPackController.shared;
    unawaited(_pack.ensureOpened());
    final initial = widget.initialLocation;
    if (initial != null &&
        initial.latitude.isFinite &&
        initial.longitude.isFinite &&
        !(initial.latitude == 0 && initial.longitude == 0)) {
      if (isInTricityMapDomain(initial.latitude, initial.longitude)) {
        _picked = initial;
      } else {
        _savedOutside = initial;
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  MapCameraTarget _initialTarget(Size canvas) {
    final picked = _picked;
    if (picked != null) {
      return _policy.focusTarget(picked, 15, canvas, _padding) ??
          _policy.overviewTarget(canvas, _padding);
    }
    final city = cityViewById(widget.initialCityId);
    return city == null
        ? _policy.overviewTarget(canvas, _padding)
        : _policy.fitExtent(city.view, canvas, _padding);
  }

  void _zoomBy(double delta) {
    if (!_ready) return;
    final camera = _mapController.camera;
    final target = _policy.legalTarget(
        camera.center, camera.zoom + delta, _canvas, _padding);
    if (target != null) _mapController.move(target.center, target.zoom);
  }

  /// Keyboard, switch and screen-reader friendly alternative to tapping:
  /// pin the point under the centre crosshair.
  void _pinCentre() {
    if (!_ready) return;
    _onTap(_mapController.camera.center);
  }

  void _onTap(LatLng point) {
    // Without the map there is nothing to aim at: no blind points.
    if (!_pack.isReady) return;
    if (!isInTricityMapDomain(point.latitude, point.longitude)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('map.picker_outside_tap'.tr()),
      ));
      return;
    }
    setState(() => _picked = point);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final picked = _picked;

    return Container(
      height: size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(Icons.pin_drop_rounded,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'design_ui.pinpoint_broadcast_location'.tr(),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'map.picker_hint'.tr(),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'design_ui.cancel'.tr(),
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Interactive Map Area
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final canvas =
                  _policy.feasibleCanvas(constraints.biggest, _padding);
              _canvas = canvas;
              final initial = _initialTarget(canvas);
              return Stack(
                children: [
                  Positioned.fill(child: Container(color: AppTheme.surfaceAlt)),
                  Center(
                    child: SizedBox(
                      width: canvas.width,
                      height: canvas.height,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: initial.center,
                          initialZoom: initial.zoom,
                          minZoom: _policy.minZoom(canvas, _padding),
                          maxZoom: kMapMaxZoom,
                          backgroundColor: AppTheme.bg,
                          cameraConstraint: CameraConstraint.contain(
                            bounds: kTricityNavigationExtent.bounds,
                          ),
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          onMapReady: () => _ready = true,
                          onTap: (tapPosition, point) => _onTap(point),
                        ),
                        children: [
                          TricityBasemapLayer(controller: _pack),
                          if (picked != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: picked,
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.topCenter,
                                  child: Semantics(
                                    label: 'map.picker_pinned_point'
                                        .tr(namedArgs: {
                                      'coords': formatPickerCoordinates(picked)
                                    }),
                                    child: const Icon(
                                      Icons.location_pin,
                                      size: 48,
                                      color: AppTheme.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Centre crosshair for "Pin map centre".
                  IgnorePointer(
                    child: Center(
                      child: Icon(Icons.add_rounded,
                          size: 32,
                          color: AppTheme.textPrimary.withValues(alpha: 0.7)),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _pack,
                    builder: (context, _) => _pack.isReady
                        ? const SizedBox.shrink()
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spaceLg),
                              child: MapPackStatusCard(
                                controller: _pack,
                                onShowList: () {},
                                showListAction: false,
                              ),
                            ),
                          ),
                  ),
                  // Zoom controls: same limits as every other map path.
                  PositionedDirectional(
                    end: 12,
                    bottom: 64,
                    child: Column(
                      children: [
                        _zoomButton(Icons.add, 'map.picker_zoom_in'.tr(),
                            () => _zoomBy(1)),
                        const SizedBox(height: 8),
                        _zoomButton(Icons.remove, 'map.picker_zoom_out'.tr(),
                            () => _zoomBy(-1)),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    start: 0,
                    bottom: 0,
                    child: ListenableBuilder(
                      listenable: _pack,
                      builder: (context, _) => MapAttributionRail(
                        controller: _pack,
                        onDetails: () {
                          final provider = context.read<AppProvider>();
                          showMapDetailsSheet(
                            context,
                            controller: _pack,
                            venuesUpdatedAt: provider.mapCacheUpdatedAt,
                            backendOnline: provider.isOnline,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),

          // Selected point & confirm bar
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_savedOutside != null && picked == null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppTheme.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'map.picker_outside_saved'.tr(namedArgs: {
                              'coords': formatPickerCoordinates(_savedOutside!)
                            }),
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_rounded,
                          color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            picked == null
                                ? 'map.picker_no_point'.tr()
                                : 'map.picker_coordinates'.tr(namedArgs: {
                                    'lat': picked.latitude.toStringAsFixed(5),
                                    'lng': picked.longitude.toStringAsFixed(5),
                                  }),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    'map.picker_address_note'.tr(),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  ListenableBuilder(
                    listenable: _pack,
                    builder: (context, _) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(_pack.isReady
                            ? 'map.picker_use_centre'.tr()
                            : 'map.picker_map_needed'.tr()),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48)),
                        onPressed: _pack.isReady ? _pinCentre : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      'design_ui.use_this_location'.tr(),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: picked == null
                        ? null
                        : () => Navigator.of(context)
                            .pop(LocationPickerResult(coordinates: picked)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: AppTheme.surface,
      shape: const CircleBorder(side: BorderSide(color: AppTheme.border)),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: AppTheme.textPrimary),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onTap,
      ),
    );
  }
}
