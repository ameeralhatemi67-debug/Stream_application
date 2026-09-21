import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';

class LocationPickerResult {
  final LatLng coordinates;
  final String suggestedAddress;
  final String city;

  const LocationPickerResult({
    required this.coordinates,
    required this.suggestedAddress,
    required this.city,
  });
}

/// Interactive Spatial Map Pinpoint Location Picker Modal
class LocationPickerModal extends StatefulWidget {
  final LatLng initialLocation;
  final String initialCity;

  const LocationPickerModal({
    super.key,
    required this.initialLocation,
    required this.initialCity,
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
        initialLocation: initialLocation ?? const LatLng(26.2172, 50.1971), // Al Khobar default
        initialCity: initialCity ?? 'khobar',
      ),
    );
  }

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  late final MapController _mapController;
  late LatLng _currentPosition;
  String _resolvedAddress = '';
  String _resolvedCity = 'khobar';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentPosition = widget.initialLocation;
    _resolvedCity = widget.initialCity;
    _resolveAddressFromCoordinates(_currentPosition);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _resolveAddressFromCoordinates(LatLng pos) {
    // Spatial proximity resolver for Eastern Province landmarks & neighborhoods
    final lat = pos.latitude;
    final lng = pos.longitude;

    if (lat > 26.35) {
      _resolvedCity = 'dammam';
      _resolvedAddress = 'Al-Faisaliyah, Dammam (Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)})';
    } else if (lat > 26.27 && lng < 50.17) {
      _resolvedCity = 'dhahran';
      _resolvedAddress = 'KFUPM Innovation District, Dhahran (Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)})';
    } else {
      _resolvedCity = 'khobar';
      _resolvedAddress = 'Corniche / Al-Rakah, Al Khobar (Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Icon(Icons.pin_drop_rounded, color: AppTheme.danger, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('design_ui.pinpoint_broadcast_location'.tr(),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('design_ui.tap_anywhere_on_the_map_or_move_the_marker_to_pin_your_venue'.tr(),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Interactive Map Area
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition,
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _currentPosition = point;
                        _resolveAddressFromCoordinates(point);
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.streamer_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_pin,
                            size: 48,
                            color: AppTheme.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Zoom controls overlay
                PositionedDirectional(
                  end: 16,
                  bottom: 24,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in_picker',
                        backgroundColor: AppTheme.surface,
                        foregroundColor: AppTheme.onMedia,
                        onPressed: () {
                          _mapController.move(
                            _currentPosition,
                            _mapController.camera.zoom + 1,
                          );
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out_picker',
                        backgroundColor: AppTheme.surface,
                        foregroundColor: AppTheme.onMedia,
                        onPressed: () {
                          _mapController.move(
                            _currentPosition,
                            _mapController.camera.zoom - 1,
                          );
                        },
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selected Address Preview & Confirm Bar
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: const Border(top: BorderSide(color: AppTheme.border)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.media.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_rounded, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('design_ui.selected_location_coordinates'.tr(),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _resolvedAddress,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: AppTheme.onMedia,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text('design_ui.use_this_location'.tr(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(
                        LocationPickerResult(
                          coordinates: _currentPosition,
                          suggestedAddress: _resolvedAddress,
                          city: _resolvedCity,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
