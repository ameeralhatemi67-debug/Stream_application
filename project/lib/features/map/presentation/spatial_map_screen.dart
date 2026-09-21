import '../../../core/widgets/safe_image_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math'as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../profile/models/streamer_models.dart';
import '../models/map_models.dart';
import 'widgets/spatial_streamer_marker.dart';
import 'widgets/marker_summary_card.dart';
import 'widgets/top_spatial_search_bar.dart';
import 'widgets/city_selector_dropdown.dart';
import 'widgets/topic_selector_dropdown.dart';
import 'widgets/streamer_sliding_drawer.dart';

/// Free Dark GIS Basemap (Esri World Dark Gray Canvas & OpenStreetMap fallback)
/// Completely free of watermarks or API key requirements.
const String kSpatialMapTileUrlTemplate =
    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';

/// Zero-API-key fallback used when the primary dark tile request fails.
const String kSpatialMapTileFallbackUrl =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class SpatialMapScreen extends StatefulWidget {
  const SpatialMapScreen({super.key});

  @override
  State<SpatialMapScreen> createState() => _SpatialMapScreenState();
}

class _SpatialMapScreenState extends State<SpatialMapScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _cameraAnimationController;

  // Initial Regional State: AlSharqia Focused View (Zoom 12.0 - 22% more zoomed in)
  static const double kInitialMapZoom = 12.0;
  static const double kStreamerMarkersZoomThreshold = 11.2;
  static const double kAuditoriumCardZoomThreshold = 13.5;

  MapRegionModel _selectedRegion = alSharqiaRegions.first; // Default: Al Khobar
  StreamerModel? _selectedStreamer;
  late final ValueNotifier<double> _zoomNotifier;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _zoomNotifier = ValueNotifier<double>(kInitialMapZoom);
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _zoomNotifier.dispose();
    _cameraAnimationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _animateCameraTo(LatLng targetCenter, double targetZoom) {
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    _cameraAnimationController.stop();
    _cameraAnimationController.reset();

    final Animation<double> curve = CurvedAnimation(
      parent: _cameraAnimationController,
      curve: Curves.fastOutSlowIn,
    );

    void listener() {
      final lat = startCenter.latitude +
          (targetCenter.latitude - startCenter.latitude) * curve.value;
      final lng = startCenter.longitude +
          (targetCenter.longitude - startCenter.longitude) * curve.value;
      final zoom = startZoom + (targetZoom - startZoom) * curve.value;

      _mapController.move(LatLng(lat, lng), zoom);
    }

    _cameraAnimationController.addListener(listener);
    _cameraAnimationController.forward().then((_) {
      _cameraAnimationController.removeListener(listener);
    });
  }

  void _selectStreamer(StreamerModel streamer) {
    setState(() {
      _selectedStreamer = streamer;
    });
    _animateCameraTo(LatLng(streamer.latitude, streamer.longitude), 14.5);
  }

  void _centerOnAlKhobar() {
    _animateCameraTo(alSharqiaRegions.first.centerCoordinates, 13.5);
  }

  MapMarkerModel _mapStreamerToMarker(StreamerModel streamer) {
    return MapMarkerModel.fromStreamer(streamer);
  }

  @override
  Widget build(BuildContext context) {
    // AppProvider.select uses DeepCollectionEquality by default, so this
    // only rebuilds when the filtered list's actual contents change (streamer
    // added/removed/mutated), not on every unrelated notifyListeners() call
    // elsewhere in the app.
    final displayedStreamers = context
        .select<AppProvider, List<StreamerModel>>((p) => p.filteredStreamers);
    final currentCategoryFilter =
        context.select<AppProvider, String>((p) => p.currentCategoryFilter);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: StreamerSlidingDrawer(
        streamers: displayedStreamers,
        onStreamerSelected: (streamer) => _selectStreamer(streamer),
      ),
      body: Row(
        children: [
          // Main Map Canvas Viewport
          Expanded(
            child: Stack(
              children: [
                // Optimized FlutterMap Canvas with Standard Network Tile Provider & Resilient Caching
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedRegion.centerCoordinates,
                    initialZoom: kInitialMapZoom,
                    minZoom: 8.5,
                    maxZoom: 17.5,
                    backgroundColor: AppTheme.bg,
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(25.60, 49.50),
                        const LatLng(27.10, 50.80),
                      ),
                    ),
                    onPositionChanged: (camera, hasGesture) {
                      if (_zoomNotifier.value != camera.zoom) {
                        _zoomNotifier.value = camera.zoom;
                      }
                    },
                    onTap: (tapPosition, latLng) {
                      if (_selectedStreamer != null) {
                        setState(() {
                          _selectedStreamer = null;
                        });
                      }
                    },
                  ),
                  children: [
                    // Fast Dark GIS Basemap Tile Layer with Zero Watermark & Fallback
                    TileLayer(
                      urlTemplate: kSpatialMapTileUrlTemplate,
                      fallbackUrl: kSpatialMapTileFallbackUrl,
                      subdomains: const ['server', 'services'],
                      maxZoom: 19,
                      userAgentPackageName: 'com.streamer.app',
                      tileProvider: NetworkTileProvider(),
                      keepBuffer: 6,
                      panBuffer: 2,
                      tileDisplay: const TileDisplay.fadeIn(
                          duration: Duration(milliseconds: 100)),
                    ),

                    // AlSharqia City Boundaries Outlines
                    RepaintBoundary(
                      child: PolygonLayer<Object>(
                        polygons: alSharqiaRegions.map((region) {
                          final isSelected =
                              region.regionId == _selectedRegion.regionId;
                          return Polygon<Object>(
                            points: region.polygonPoints,
                            color: isSelected
                                ? AppTheme.danger.withValues(alpha: 0.06)
                                : Colors.transparent,
                            borderColor: isSelected
                                ? AppTheme.danger
                                : AppTheme.danger.withValues(alpha: 0.35),
                            borderStrokeWidth: isSelected ? 2.0 : 1.2,
                          );
                        }).toList(),
                      ),
                    ),

                    // Dynamic Level of Detail (LOD) Markers Layer with ValueListenableBuilder (No FlutterMap Rebuilds)
                    ValueListenableBuilder<double>(
                      valueListenable: _zoomNotifier,
                      builder: (context, currentZoom, child) {
                        final bool showAuditoriumCards =
                            currentZoom >= kAuditoriumCardZoomThreshold;

                        // Filter visible streamers:
                        // Live video and audio-only streamers are ALWAYS visible from max zoom out;
                        // Offline streamers appear once currentZoom >= kStreamerMarkersZoomThreshold.
                        final visibleStreamers = displayedStreamers.where((s) {
                          if (s.isCurrentlyLive) return true;
                          return currentZoom >= kStreamerMarkersZoomThreshold;
                        }).toList();

                        if (visibleStreamers.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        // Z-Index Sorting Order:
                        // 1. Offline Broadcasters (Bottom)
                        // 2. Live Audio Broadcasters
                        // 3. Live Video Broadcasters
                        // 4. Selected Broadcaster
                        final sortedStreamers = List<StreamerModel>.from(
                            visibleStreamers)
                          ..sort((a, b) {
                            final isASelected =
                                a.streamerId == _selectedStreamer?.streamerId;
                            final isBSelected =
                                b.streamerId == _selectedStreamer?.streamerId;
                            if (isASelected && !isBSelected) return 1;
                            if (!isASelected && isBSelected) return -1;

                            int scoreA =
                                a.isVideoLive ? 3 : (a.isAudioLive ? 2 : 1);
                            int scoreB =
                                b.isVideoLive ? 3 : (b.isAudioLive ? 2 : 1);
                            return scoreA.compareTo(scoreB);
                          });

                        final List<Marker> markerList = [];
                        final camera = MapCamera.of(context);

                        // Layout resolution model list
                        final List<_LayoutMarker> layoutMarkers = [];
                        final Map<String, LatLng> adjustedPositions = {};

                        for (final streamer in sortedStreamers) {
                          final isLive = streamer.isCurrentlyLive;
                          final double radius = (isLive ? 56.0 : 46.0) / 2.0;
                          final origLatLng =
                              LatLng(streamer.latitude, streamer.longitude);
                          final math.Point<double> pixelPos =
                              camera.project(origLatLng);

                          layoutMarkers.add(_LayoutMarker(
                            streamerId: streamer.streamerId,
                            origPoint: origLatLng,
                            currentPixel: pixelPos,
                            radius: radius,
                          ));
                        }

                        // Run pairwise collision resolution for 10 iterations (force displacement)
                        const int iterations = 10;
                        const double gap =
                            7.0; // Minimum 7px gap between markers

                        for (int iter = 0; iter < iterations; iter++) {
                          for (int i = 0; i < layoutMarkers.length; i++) {
                            for (int j = i + 1; j < layoutMarkers.length; j++) {
                              final m1 = layoutMarkers[i];
                              final m2 = layoutMarkers[j];

                              final double dx =
                                  m2.currentPixel.x - m1.currentPixel.x;
                              final double dy =
                                  m2.currentPixel.y - m1.currentPixel.y;
                              final double distance =
                                  math.sqrt(dx * dx + dy * dy);
                              final double minDistance =
                                  m1.radius + m2.radius + gap;

                              if (distance < minDistance) {
                                final double overlap = minDistance - distance;

                                double pushX, pushY;
                                if (distance == 0) {
                                  // Fan out systematically using index-based angle to avoid stacking in the exact same spot
                                  final double angle = (i + j) *
                                      2.0 *
                                      math.pi /
                                      layoutMarkers.length;
                                  pushX = math.cos(angle) * (minDistance / 2.0);
                                  pushY = math.sin(angle) * (minDistance / 2.0);
                                } else {
                                  pushX = (dx / distance) * (overlap / 2.0);
                                  pushY = (dy / distance) * (overlap / 2.0);
                                }

                                m1.currentPixel = math.Point(
                                    m1.currentPixel.x - pushX,
                                    m1.currentPixel.y - pushY);
                                m2.currentPixel = math.Point(
                                    m2.currentPixel.x + pushX,
                                    m2.currentPixel.y + pushY);
                              }
                            }
                          }
                        }

                        // Save unprojected adjusted coordinates
                        for (final m in layoutMarkers) {
                          adjustedPositions[m.streamerId] =
                              camera.unproject(m.currentPixel);
                        }

                        // 1. Render all Avatar Markers
                        for (final streamer in sortedStreamers) {
                          final isSelected = _selectedStreamer?.streamerId ==
                              streamer.streamerId;
                          final markerModel = _mapStreamerToMarker(streamer);
                          final isLive = markerModel.isLive;

                          if (isSelected && showAuditoriumCards) {
                            // Rendered as Anchored Summary Card at the absolute top of the layer below
                            continue;
                          }

                          final adjustedPoint =
                              adjustedPositions[streamer.streamerId] ??
                                  LatLng(streamer.latitude, streamer.longitude);

                          markerList.add(
                            Marker(
                              key: ValueKey('marker_${streamer.streamerId}'),
                              point: adjustedPoint,
                              width: isLive ? 56.0 : 46.0,
                              height: isLive ? 56.0 : 46.0,
                              rotate: true,
                              alignment: Alignment.center,
                              child: SpatialStreamerMarker(
                                key: ValueKey('avatar_${streamer.streamerId}'),
                                marker: markerModel,
                                isSelected: isSelected,
                                onTap: () => _selectStreamer(streamer),
                                onDoubleTap: () => _animateCameraTo(
                                  LatLng(streamer.latitude, streamer.longitude),
                                  15.5,
                                ),
                              ),
                            ),
                          );
                        }

                        // 2. Render Selected Streamer Summary Card LAST
                        if (_selectedStreamer != null && showAuditoriumCards) {
                          final adjustedPoint = adjustedPositions[
                                  _selectedStreamer!.streamerId] ??
                              LatLng(_selectedStreamer!.latitude,
                                  _selectedStreamer!.longitude);
                          markerList.add(
                            Marker(
                              key: ValueKey(
                                  'card_${_selectedStreamer!.streamerId}'),
                              point: adjustedPoint,
                              width: 320.0,
                              height: 175.0,
                              rotate: true,
                              alignment: Alignment.topCenter,
                              child: MarkerSummaryCard(
                                key: ValueKey(
                                    'summary_card_${_selectedStreamer!.streamerId}'),
                                streamer: _selectedStreamer!,
                                onClose: () {
                                  setState(() {
                                    _selectedStreamer = null;
                                  });
                                },
                              ),
                            ),
                          );
                        }

                        return MarkerLayer(
                          rotate: true,
                          markers: markerList,
                        );
                      },
                    ),
                  ],
                ),

                // Top Spatial Map Controls (Row 1: Full-Width Search + Language, Row 2: City + Topic Dropdowns)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd,
                        vertical: AppTheme.spaceSm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: Search bar taking nearly 100% width + Language Switcher Toggle
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TopSpatialSearchBar(
                                  onSearchResultSelected:
                                      (coordinates, zoom, label) {
                                    _animateCameraTo(coordinates, zoom);
                                  },
                                ),
                              ),
                              const SizedBox(width: AppTheme.spaceSm),
                              const LanguageSwitcher(),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceSm),

                          // Row 2 (Fixed, non-scrolling): Location/City Picker alongside Topic/Category Dropdown
                          Row(
                            children: [
                              Expanded(
                                child: CitySelectorDropdown(
                                  selectedCity: _selectedRegion,
                                  onCitySelected: (region) {
                                    setState(() {
                                      _selectedRegion = region;
                                    });
                                    _animateCameraTo(region.centerCoordinates,
                                        region.zoomLevelTarget);
                                  },
                                ),
                              ),
                              const SizedBox(width: AppTheme.spaceSm),
                              Expanded(
                                child: TopicSelectorDropdown(
                                  selectedCategoryId: currentCategoryFilter,
                                  categories: context.watch<AppProvider>()
                                      .academicCategories,
                                  onCategorySelected: (categoryId) {
                                    context
                                        .read<AppProvider>()
                                        .setCategoryFilter(categoryId);
                                    if (_selectedStreamer != null &&
                                        categoryId != 'all') {
                                      final sCat =
                                          _selectedStreamer!.categoryId;
                                      final bool matches = (categoryId ==
                                              sCat) ||
                                          (categoryId == 'computer_science' &&
                                              (sCat == 'cs_tech' ||
                                                  sCat ==
                                                      'computer_science')) ||
                                          (categoryId == 'cs_tech' &&
                                              (sCat == 'cs_tech' ||
                                                  sCat ==
                                                      'computer_science')) ||
                                          (categoryId == 'islamic_studies' &&
                                              (sCat == 'islamic_studies' ||
                                                  sCat == 'sharia')) ||
                                          (categoryId == 'medicine' &&
                                              (sCat == 'medicine' ||
                                                  sCat == 'health')) ||
                                          (categoryId == 'engineering' &&
                                              (sCat == 'engineering' ||
                                                  sCat == 'innovation'));
                                      if (!matches) {
                                        setState(() {
                                          _selectedStreamer = null;
                                        });
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Floating Action Map Controls (Bottom Right)
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Recenter to Al Khobar Button
                      _buildFloatingMapButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Recenter to Al Khobar',
                        onTap: _centerOnAlKhobar,
                      ),
                      const SizedBox(height: 10),

                      // Open Broadcasters List Drawer Button
                      _buildFloatingMapButton(
                        icon: Icons.format_list_bulleted_rounded,
                        tooltip: 'Broadcasters List',
                        onTap: () {
                          _scaffoldKey.currentState?.openEndDrawer();
                        },
                      ),
                    ],
                  ),
                ),

                // Selected Streamer Summary Modal Card (Mobile Bottom Floating Overlay for Mid-Zoom)
                ValueListenableBuilder<double>(
                  valueListenable: _zoomNotifier,
                  builder: (context, currentZoom, child) {
                    if (_selectedStreamer == null ||
                        currentZoom >= kAuditoriumCardZoomThreshold) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      bottom: 24,
                      left: 16,
                      right: 76,
                      child: Center(
                        child: MarkerSummaryCard(
                          streamer: _selectedStreamer!,
                          onClose: () {
                            setState(() {
                              _selectedStreamer = null;
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Desktop Venue Side Inspection Panel (Width >= 900px)
          if (isDesktop)
            Container(
              width: 380,
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border:
                    Border(left: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: AppTheme.border)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hub_rounded,
                            color: AppTheme.danger, size: 20),
                        const SizedBox(width: AppTheme.spaceSm),
                        Expanded(child: Text(
                          'design_copy.map_venues'.tr(namedArgs: {'count': '${displayedStreamers.length}'}),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppTheme.spaceMd),
                      itemCount: displayedStreamers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppTheme.spaceSm),
                      itemBuilder: (context, index) {
                        final streamer = displayedStreamers[index];
                        final isSelected = _selectedStreamer?.streamerId ==
                            streamer.streamerId;

                        return Material(
                          color: isSelected
                              ? AppTheme.danger.withValues(alpha: 0.12)
                              : AppTheme.surfaceAlt,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.danger
                                  : AppTheme.border,
                              width: 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _selectStreamer(streamer),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spaceMd),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppTheme.surface,
                                    backgroundImage:
                                        buildSafeImageProvider(path: streamer.avatarUrl),
                                  ),
                                  const SizedBox(width: AppTheme.spaceMd),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          streamer.fullNameEn,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          streamer.venueNameEn,
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (streamer.isCurrentlyLive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.danger,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('design_ui.live'.tr(),
                                        style: const TextStyle(
                                          color: AppTheme.onMedia,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: const BorderSide(color: AppTheme.danger, width: 1.2),
      ),
      elevation: 6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: AppTheme.danger, size: 20),
        ),
      ),
    );
  }
}

class _LayoutMarker {
  final String streamerId;
  final LatLng origPoint;
  math.Point<double> currentPixel;
  final double radius;

  _LayoutMarker({
    required this.streamerId,
    required this.origPoint,
    required this.currentPixel,
    required this.radius,
  });
}
