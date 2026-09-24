import '../../../core/widgets/safe_image_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../profile/models/streamer_models.dart';
import '../models/map_models.dart';
import 'map_cluster_layout.dart';
import 'map_visible_catalog.dart';
import 'venue_directions_launcher.dart';
import 'widgets/spatial_streamer_marker.dart';
import 'widgets/marker_summary_card.dart';
import 'widgets/top_spatial_search_bar.dart';
import 'widgets/city_selector_dropdown.dart';
import 'widgets/topic_selector_dropdown.dart';
import 'widgets/streamer_sliding_drawer.dart';

/// Online light raster basemap (Esri World Light Gray Canvas) with an
/// OpenStreetMap network fallback. Both sources require visible attribution.
///
/// UI-07: this used to be the dark-canvas sibling tile set
/// (`World_Dark_Gray_Base`), which read as dark/low-contrast/noisy against
/// the rest of the app's light theme (brief/Ui_issues/Map_when_wifi_on.jpg).
/// The light-canvas service replaced the dark-canvas sibling to match the
/// app's white theme. See store/map_licensing.md before changing providers.
const String kSpatialMapTileUrlTemplate =
    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}';

/// Network fallback used when the primary tile request fails. No prefetch.
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
  VoidCallback? _cameraAnimationListener;

  // Initial Regional State: AlSharqia Focused View (Zoom 12.0 - 22% more zoomed in)
  static const double kInitialMapZoom = 12.0;
  static const double kAuditoriumCardZoomThreshold = 13.5;

  MapRegionModel _selectedRegion = alSharqiaRegions.first; // Default: Al Khobar
  String? _selectedStreamerId;
  late final ValueNotifier<double> _zoomNotifier;
  late final ValueNotifier<int> _cameraRevision;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isRetryingConnectivity = false;
  int _tileFailures = 0;
  bool _tileError = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _zoomNotifier = ValueNotifier<double>(kInitialMapZoom);
    _cameraRevision = ValueNotifier<int>(0);
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _zoomNotifier.dispose();
    _cameraRevision.dispose();
    _cameraAnimationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _animateCameraTo(LatLng targetCenter, double targetZoom) {
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;

    if (_cameraAnimationListener != null) {
      _cameraAnimationController.removeListener(_cameraAnimationListener!);
      _cameraAnimationListener = null;
    }
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

    _cameraAnimationListener = listener;
    _cameraAnimationController.addListener(listener);
    _cameraAnimationController.forward();
  }

  void _selectStreamer(StreamerModel streamer) {
    setState(() {
      _selectedStreamerId = streamer.streamerId;
    });
    _animateCameraTo(LatLng(streamer.latitude, streamer.longitude), 14.5);
  }

  void _centerOnAlKhobar() {
    setState(() => _selectedRegion = alSharqiaRegions.first);
    _animateCameraTo(alSharqiaRegions.first.centerCoordinates, 13.5);
  }

  /// UI-08 "Retry and recover when connectivity returns": a manual nudge on
  /// top of the automatic recovery ConnectivityService.onStatusChange
  /// already drives (AppProvider.ensureConnectivityMonitoringActive) -- the
  /// device connectivity API can report "connected" slightly before the
  /// backend is actually reachable, so a visible retry action matters even
  /// though recovery is also automatic.
  Future<void> _retryConnectivity() async {
    if (_isRetryingConnectivity) return;
    setState(() {
      _isRetryingConnectivity = true;
      _tileFailures = 0;
      _tileError = false;
    });
    final provider = context.read<AppProvider>();
    // Re-probe first: connectivity_plus only emits on *change*, so without
    // this an app that cold started offline never leaves the offline branch
    // however often Retry is tapped. Only fetch if we are actually back.
    final online = await provider.refreshConnectivityNow();
    if (online) {
      await provider.loadVerifiedStreamersFromBackend();
      await provider.ensureAcademicCategoriesLoaded();
    }
    if (!mounted) return;
    setState(() => _isRetryingConnectivity = false);
  }

  /// Tapping a cached (offline) marker can't open the normal
  /// MarkerSummaryCard flow -- that needs a full StreamerModel the offline
  /// cache deliberately doesn't carry (UI-08 caches only what a map pin
  /// needs, not a whole profile). This shows what the cache does have and
  /// says plainly what it doesn't, rather than silently doing nothing or
  /// pretending the summary card's live data is real.
  void _showCachedMarkerInfo(BuildContext context, MapMarkerModel marker) {
    final isAr = context.locale.languageCode == 'ar';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                marker.getLocalizedName(isAr ? 'ar' : 'en'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                marker.getLocalizedVenue(isAr ? 'ar' : 'en'),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppTheme.textMuted, size: 18),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Text(
                        'map.offline_marker_details_unavailable'.tr(),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: Text('map.open_in_maps'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    launchVenueDirections(marker.latitude, marker.longitude);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MapMarkerModel _mapStreamerToMarker(StreamerModel streamer) {
    return MapMarkerModel.fromStreamer(streamer);
  }

  Widget _buildClusterBadge(MapClusterGroup group, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: 'map.cluster_label'
          .tr(namedArgs: {'count': '${group.memberIds.length}'}),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.surface, width: 3),
            boxShadow: const [BoxShadow(color: AppTheme.shadow, blurRadius: 8)],
          ),
          child: Text('${group.memberIds.length}',
              style: const TextStyle(
                  color: AppTheme.onMedia,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
      ),
    );
  }

  void _openCluster<T>(
    MapClusterGroup group,
    Map<String, T> byId,
    String Function(T) label,
    void Function(T) onPick,
  ) {
    final nextZoom = clusterTapZoom(_mapController.camera.zoom);
    if (nextZoom != null) {
      _animateCameraTo(group.center, nextZoom);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: group.memberIds.where(byId.containsKey).map((id) {
            final item = byId[id];
            if (item == null) return const SizedBox.shrink();
            return ListTile(
              leading: const Icon(Icons.place_rounded, color: AppTheme.primary),
              title: Text(label(item)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onPick(item);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// UI-08 offline marker layer: cached venues only, always rendered with
  /// [MarkerStatus.offline] (MapMarkerModel.fromCachedJson forces this), so
  /// there is no risk of replaying a stale "LIVE" badge from before the
  /// device went offline. Cached points use the same bounded cluster layout
  /// and only render IDs still eligible in the current provider catalog.
  Widget _buildOfflineMarkerLayer(
    BuildContext context,
    String categoryFilter,
    Set<String>? currentVisibleIds,
  ) {
    final cached = context
        .select<AppProvider, List<MapMarkerModel>>((p) => p.cachedMapMarkers);
    // The topic dropdown is pure local filtering -- it needs no network, so
    // it must keep working offline rather than looking functional and doing
    // nothing. Same matcher the online path uses (map_models.dart), so the
    // two views can't filter differently.
    final visible = visibleCachedMapMarkers(
      cached,
      currentVisibleIds: currentVisibleIds,
    )
        .where((m) => categoryFilterMatches(categoryFilter, m.categoryId))
        .toList();

    return ValueListenableBuilder<int>(
      valueListenable: _cameraRevision,
      builder: (context, revision, child) {
        final camera = MapCamera.of(context);
        final groups = clusterMapPoints(
          visible.map((m) => MapClusterPoint(m.streamerId, m.coordinates)),
          project: camera.project,
          unproject: camera.unproject,
        );
        final byId = {for (final marker in visible) marker.streamerId: marker};
        return MarkerLayer(
          markers: groups.map((group) {
            final marker = group.isSingle ? byId[group.memberIds.single] : null;
            return Marker(
              key: ValueKey('offline_${group.id}'),
              point: group.center,
              width: 56,
              height: 56,
              child: marker == null
                  ? _buildClusterBadge(
                      group,
                      () => _openCluster(
                          group,
                          byId,
                          (m) =>
                              m.getLocalizedName(context.locale.languageCode),
                          (m) => _showCachedMarkerInfo(context, m)))
                  : SpatialStreamerMarker(
                      marker: marker,
                      onTap: () => _showCachedMarkerInfo(context, marker),
                      onDoubleTap: () =>
                          _animateCameraTo(marker.coordinates, 15.5),
                    ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // AppProvider.select uses DeepCollectionEquality by default, so this
    // only rebuilds when the filtered list's actual contents change (streamer
    // added/removed/mutated), not on every unrelated notifyListeners() call
    // elsewhere in the app.
    final displayedStreamers = visibleMapStreamers(context
        .select<AppProvider, List<StreamerModel>>((p) => p.filteredStreamers));
    final currentCatalog = visibleMapStreamers(
        context.select<AppProvider, List<StreamerModel>>((p) => p.streamers));
    final hasCatalogSnapshot =
        context.select<AppProvider, bool>((p) => p.hasPublicCatalogSnapshot);
    final Set<String>? currentVisibleIds = hasCatalogSnapshot
        ? currentCatalog.map((s) => s.streamerId).toSet()
        : null;
    final ownStreamerId =
        context.select<AppProvider, String?>((p) => p.currentUserStreamerId);
    final selectedStreamer = displayedStreamers
        .where((s) => s.streamerId == _selectedStreamerId)
        .firstOrNull;
    if (selectedStreamer == null) _selectedStreamerId = null;
    final currentCategoryFilter =
        context.select<AppProvider, String>((p) => p.currentCategoryFilter);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    // UI-08: everything below branches on this single flag rather than
    // scattering connectivity checks through the widget tree.
    final isOnline = context.select<AppProvider, bool>((p) => p.isOnline);
    final cachedMarkers = context
        .select<AppProvider, List<MapMarkerModel>>((p) => p.cachedMapMarkers);
    final hasOfflineMarkers = visibleCachedMapMarkers(
      cachedMarkers,
      currentVisibleIds: currentVisibleIds,
    ).any((m) => categoryFilterMatches(currentCategoryFilter, m.categoryId));

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
                    minZoom: 5.0,
                    maxZoom: 17.5,
                    backgroundColor: AppTheme.bg,
                    cameraConstraint: CameraConstraint.containCenter(
                      bounds: saudiMapBounds,
                    ),
                    onPositionChanged: (camera, hasGesture) {
                      if (_zoomNotifier.value != camera.zoom) {
                        _zoomNotifier.value = camera.zoom;
                      }
                      _cameraRevision.value++;
                    },
                    onTap: (tapPosition, latLng) {
                      if (_selectedStreamerId != null) {
                        setState(() {
                          _selectedStreamerId = null;
                        });
                      }
                    },
                  ),
                  children: [
                    // UI-08: no live network means no live tiles -- showing
                    // the (permanently empty, offline) NetworkTileProvider
                    // layer was exactly the "blank white field" bug
                    // (Map_when_wifi_Off.jpg). The bundled schematic layer
                    // below replaces it instead of leaving it mounted to
                    // fail silently.
                    if (isOnline)
                      TileLayer(
                        urlTemplate: kSpatialMapTileUrlTemplate,
                        fallbackUrl: kSpatialMapTileFallbackUrl,
                        subdomains: const ['server', 'services'],
                        maxZoom: 19,
                        userAgentPackageName: 'com.streamer.app',
                        tileProvider: NetworkTileProvider(),
                        errorTileCallback: (tile, error, stackTrace) {
                          if (++_tileFailures < 3 || _tileError) return;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_tileError) {
                              setState(() => _tileError = true);
                            }
                          });
                        },
                        keepBuffer: 6,
                        panBuffer: 2,
                        tileDisplay: const TileDisplay.fadeIn(
                            duration: Duration(milliseconds: 100)),
                      ),

                    // AlSharqia City Boundaries Outlines.
                    //
                    // UI-07/UI-11 (online): every region used to outline in
                    // the same saturated danger-red regardless of selection,
                    // which read as "red everywhere" and competed with both
                    // the basemap and the markers. Red is now reserved for
                    // the one selected region -- the actual highlight -- and
                    // unselected regions recede into a faint neutral so they
                    // still show city extent without dominating the canvas.
                    //
                    // UI-08 (offline): this is also the bundled offline
                    // basemap -- every region gets a filled, labelled land
                    // tone instead of just an outline, which is genuine
                    // geographic context built from the app's own already-
                    // reviewed region geometry (project/lib/features/map/
                    // models/map_models.dart), not a live tile request that
                    // would just fail. It is deliberately schematic, not a
                    // pretend detailed map.
                    RepaintBoundary(
                      child: PolygonLayer<Object>(
                        polygons: alSharqiaRegions.map((region) {
                          final isSelected =
                              region.regionId == _selectedRegion.regionId;
                          if (!isOnline) {
                            return Polygon<Object>(
                              points: region.polygonPoints,
                              color: isSelected
                                  ? AppTheme.surfaceAlt
                                  : AppTheme.surfaceAlt.withValues(alpha: 0.6),
                              borderColor: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.borderStrong
                                      .withValues(alpha: 0.6),
                              borderStrokeWidth: isSelected ? 2.0 : 1.2,
                            );
                          }
                          return Polygon<Object>(
                            points: region.polygonPoints,
                            color: isSelected
                                ? AppTheme.danger.withValues(alpha: 0.06)
                                : Colors.transparent,
                            borderColor: isSelected
                                ? AppTheme.danger
                                : AppTheme.borderStrong.withValues(alpha: 0.45),
                            borderStrokeWidth: isSelected ? 2.0 : 1.0,
                          );
                        }).toList(),
                      ),
                    ),

                    if (!isOnline)
                      _buildOfflineMarkerLayer(
                          context, currentCategoryFilter, currentVisibleIds),

                    // Dynamic Level of Detail (LOD) Markers Layer with ValueListenableBuilder (No FlutterMap Rebuilds)
                    if (isOnline)
                      ValueListenableBuilder<int>(
                        valueListenable: _cameraRevision,
                        builder: (context, revision, child) {
                          final currentZoom = MapCamera.of(context).zoom;
                          final bool showAuditoriumCards =
                              currentZoom >= kAuditoriumCardZoomThreshold;
                          if (displayedStreamers.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final List<Marker> markerList = [];
                          final camera = MapCamera.of(context);
                          final groups = clusterMapPoints(
                            displayedStreamers.map((s) => MapClusterPoint(
                                s.streamerId, LatLng(s.latitude, s.longitude))),
                            project: camera.project,
                            unproject: camera.unproject,
                          );
                          final byId = {
                            for (final s in displayedStreamers) s.streamerId: s
                          };

                          for (final group in groups) {
                            if (!group.isSingle) {
                              markerList.add(Marker(
                                key: ValueKey(group.id),
                                point: group.center,
                                width: 56,
                                height: 56,
                                child: _buildClusterBadge(
                                    group,
                                    () => _openCluster(
                                        group,
                                        byId,
                                        (s) => s.getLocalizedName(
                                            context.locale.languageCode),
                                        _selectStreamer)),
                              ));
                              continue;
                            }
                            final streamer = byId[group.memberIds.single]!;
                            final isSelected =
                                _selectedStreamerId == streamer.streamerId;
                            final markerModel = _mapStreamerToMarker(streamer);
                            final isLive = markerModel.isLive;

                            if (isSelected && showAuditoriumCards) {
                              // Rendered as Anchored Summary Card at the absolute top of the layer below
                              continue;
                            }

                            markerList.add(
                              Marker(
                                key: ValueKey('marker_${streamer.streamerId}'),
                                point: group.center,
                                width: isLive ? 56.0 : 48.0,
                                height: isLive ? 56.0 : 48.0,
                                rotate: true,
                                alignment: Alignment.center,
                                child: SpatialStreamerMarker(
                                  key:
                                      ValueKey('avatar_${streamer.streamerId}'),
                                  marker: markerModel,
                                  isSelected: isSelected,
                                  isMine: ownStreamerId == streamer.streamerId,
                                  onTap: () => _selectStreamer(streamer),
                                  onDoubleTap: () => _animateCameraTo(
                                    LatLng(
                                        streamer.latitude, streamer.longitude),
                                    15.5,
                                  ),
                                ),
                              ),
                            );
                          }

                          // 2. Render Selected Streamer Summary Card LAST
                          if (selectedStreamer != null && showAuditoriumCards) {
                            markerList.add(
                              Marker(
                                key: ValueKey(
                                    'card_${selectedStreamer.streamerId}'),
                                point: LatLng(selectedStreamer.latitude,
                                    selectedStreamer.longitude),
                                width: 320.0,
                                height: 175.0,
                                rotate: true,
                                alignment: Alignment.topCenter,
                                child: MarkerSummaryCard(
                                  key: ValueKey(
                                      'summary_card_${selectedStreamer.streamerId}'),
                                  streamer: selectedStreamer,
                                  onClose: () {
                                    setState(() {
                                      _selectedStreamerId = null;
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

                    // UI-07: the basemap's licence requires visible
                    // attribution -- there was none before. Bottom-left so
                    // it never collides with the bottom-right floating
                    // action buttons. Only shown online: the offline layer
                    // below is bundled app data (the region polygons already
                    // in map_models.dart), not third-party tiles, so no
                    // tile-provider attribution applies to it.
                    //
                    // A plain Text in a bounded, wrapping box rather than
                    // flutter_map's own SimpleAttributionWidget: that widget
                    // sizes its Row to its own intrinsic content with no
                    // width constraint, which overflowed on a narrow Arabic
                    // (RTL) screen at a large text scale -- caught by
                    // layout_sweep_test.dart's "empty map ar" case.
                    if (isOnline)
                      Align(
                        // Directional, not Alignment.bottomLeft: the floating
                        // action buttons are PositionedDirectional(end:), so a
                        // hard-coded left anchor put the attribution on the
                        // same side as those buttons in Arabic. bottomStart
                        // keeps the two on opposite sides in both locales, and
                        // matches the "no side-anchored alignment" rule in
                        // Core_files/Desgin.md.
                        alignment: AlignmentDirectional.bottomStart,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: InkWell(
                            onTap: () => launchUrl(
                              Uri.parse(
                                  'https://www.openstreetmap.org/copyright'),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: Container(
                              color: AppTheme.surface.withValues(alpha: 0.75),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Text(
                                'map.attribution_esri'.tr(),
                                softWrap: true,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                if (isOnline ? displayedStreamers.isEmpty : !hasOfflineMarkers)
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(
                          top: 96,
                          left: AppTheme.spaceLg,
                          right: AppTheme.spaceLg),
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          border: Border.all(color: AppTheme.borderStrong),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.location_off_outlined,
                              color: AppTheme.textSecondary),
                          Text('map.empty_title'.tr(),
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              (isOnline
                                      ? 'map.empty_body'
                                      : 'map.offline_empty_body')
                                  .tr(),
                              textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _isRetryingConnectivity
                                ? null
                                : _retryConnectivity,
                            child: Text('map.offline_retry'.tr()),
                          ),
                        ]),
                      ),
                    ),
                  ),
                if (isOnline && _tileError)
                  PositionedDirectional(
                    bottom: 84,
                    start: 16,
                    end: 76,
                    child: Material(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceSm),
                        child: Text('map.tile_error'.tr(),
                            style:
                                const TextStyle(color: AppTheme.textPrimary)),
                      ),
                    ),
                  ),

                // Top Spatial Map Controls (Row 1: Full-Width Search + Language, Row 2: City + Topic Dropdowns)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
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
                          if (!isOnline) ...[
                            _buildOfflineBanner(context),
                            const SizedBox(height: AppTheme.spaceSm),
                          ],
                          // Row 1: Search bar taking nearly 100% width + Language Switcher Toggle
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TopSpatialSearchBar(
                                  visibleStreamers: displayedStreamers,
                                  onSearchResultSelected:
                                      (coordinates, zoom, label) {
                                    _animateCameraTo(coordinates, zoom);
                                  },
                                  onStreamerSelected: (streamerId) {
                                    final current = displayedStreamers
                                        .where(
                                            (s) => s.streamerId == streamerId)
                                        .firstOrNull;
                                    if (current != null) {
                                      _selectStreamer(current);
                                    }
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
                                  categories: context
                                      .watch<AppProvider>()
                                      .academicCategories,
                                  onCategorySelected: (categoryId) {
                                    context
                                        .read<AppProvider>()
                                        .setCategoryFilter(categoryId);
                                    if (selectedStreamer != null &&
                                        categoryId != 'all') {
                                      final sCat = selectedStreamer.categoryId;
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
                                          _selectedStreamerId = null;
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
                PositionedDirectional(
                  bottom: 24,
                  end: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Recenter to Al Khobar Button
                      _buildFloatingMapButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'map.reset_khobar'.tr(),
                        onTap: _centerOnAlKhobar,
                      ),
                      const SizedBox(height: 10),

                      // Open Broadcasters List Drawer Button
                      _buildFloatingMapButton(
                        icon: Icons.format_list_bulleted_rounded,
                        tooltip: 'map.broadcasters_list'.tr(),
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
                    if (selectedStreamer == null ||
                        currentZoom >= kAuditoriumCardZoomThreshold) {
                      return const SizedBox.shrink();
                    }
                    return PositionedDirectional(
                      bottom: 24,
                      start: 16,
                      end: 76,
                      child: Center(
                        child: MarkerSummaryCard(
                          streamer: selectedStreamer,
                          onClose: () {
                            setState(() {
                              _selectedStreamerId = null;
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
                border: Border(left: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: AppTheme.border)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hub_rounded,
                            color: AppTheme.danger, size: 20),
                        const SizedBox(width: AppTheme.spaceSm),
                        Expanded(
                            child: Text(
                          'design_copy.map_venues'.tr(namedArgs: {
                            'count': '${displayedStreamers.length}'
                          }),
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
                        final isSelected =
                            _selectedStreamerId == streamer.streamerId;

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
                                    backgroundImage: buildSafeImageProvider(
                                        path: streamer.avatarUrl),
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
                                      child: Text(
                                        'design_ui.live'.tr(),
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

  /// UI-08 explicit bilingual offline banner: states the state plainly, says
  /// what still works (cached venues) and what doesn't (live status, new
  /// venues), shows when the cache was last refreshed, and offers a manual
  /// retry on top of the automatic recovery.
  Widget _buildOfflineBanner(BuildContext context) {
    final status =
        context.select<AppProvider, NetworkStatus>((p) => p.networkStatus);
    final updatedAt =
        context.select<AppProvider, DateTime?>((p) => p.mapCacheUpdatedAt);
    final lastUpdatedText = updatedAt == null
        ? 'map.offline_last_updated_never'.tr()
        : 'map.offline_last_updated'.tr(namedArgs: {
            'time': DateFormat('yyyy-MM-dd HH:mm').format(updatedAt)
          });

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppTheme.mapOverlayRadius),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
        boxShadow: AppTheme.mapOverlayShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.warning, size: 20),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (status == NetworkStatus.degraded
                          ? 'offline_experience.degraded_title'
                          : 'map.offline_banner_title')
                      .tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (status == NetworkStatus.degraded
                          ? 'offline_experience.body'
                          : 'map.offline_banner_body')
                      .tr(),
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  lastUpdatedText,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          OutlinedButton(
            onPressed: _isRetryingConnectivity ? null : _retryConnectivity,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: Text(
              _isRetryingConnectivity
                  ? 'map.offline_retrying'.tr()
                  : 'map.offline_retry'.tr(),
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // UI-11: same radius and drop-shadow mechanism as the search bar and
  // dropdowns (AppTheme.mapOverlay*) instead of a plain Material elevation,
  // so the floating controls read as the same system of surfaces. The red
  // border/icon stays -- that is this screen's own deliberate "Spatial Map"
  // tab accent (mirrored by the nav label and the selected region outline),
  // not an inconsistency to remove.
  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.mapOverlayRadius),
        boxShadow: AppTheme.mapOverlayShadow,
      ),
      child: Material(
        color:
            AppTheme.surfaceAlt.withValues(alpha: AppTheme.mapOverlayFillAlpha),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.mapOverlayRadius),
          side: const BorderSide(color: AppTheme.danger, width: 1.2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.mapOverlayRadius),
          child: Tooltip(
            message: tooltip,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(icon, color: AppTheme.danger, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
