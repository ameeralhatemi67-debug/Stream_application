import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../discovery/models/academic_category_model.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../profile/models/streamer_models.dart';
import '../models/map_models.dart';
import '../models/map_tricity_domain.dart';
import '../services/map_offline_store.dart';
import '../services/map_pack_controller.dart';
import 'map_cluster_layout.dart';
import 'map_viewport_policy.dart';
import 'map_visible_catalog.dart';
import 'venue_directions_launcher.dart';
import 'widgets/map_status_details.dart';
import 'widgets/spatial_streamer_marker.dart';
import 'widgets/marker_summary_card.dart';
import 'widgets/top_spatial_search_bar.dart';
import 'widgets/city_selector_dropdown.dart';
import 'widgets/topic_selector_dropdown.dart';
import 'widgets/streamer_sliding_drawer.dart';
import 'widgets/tricity_basemap_layer.dart';

/// The Al Khobar / Dhahran / Dammam discovery map.
///
/// Streets and labels come from the app-bundled vector pack
/// ([MapPackController]); backend connectivity only decides whether venue
/// pins are current or saved, never whether the map itself can be drawn.
/// Every camera move goes through one [MapViewportPolicy].
class SpatialMapScreen extends StatefulWidget {
  const SpatialMapScreen({super.key, this.packController});

  /// Tests inject a controller; the app uses [MapPackController.shared].
  final MapPackController? packController;

  @override
  State<SpatialMapScreen> createState() => _SpatialMapScreenState();
}

class _SpatialMapScreenState extends State<SpatialMapScreen>
    with SingleTickerProviderStateMixin {
  static const MapViewportPolicy _policy = MapViewportPolicy();
  static const double kVenueFocusZoom = 15.5;

  late final MapController _mapController;
  late final AnimationController _cameraAnimationController;
  VoidCallback? _cameraAnimationListener;
  late final MapPackController _pack;

  String _selectedCityId = kAllCitiesId;
  String? _selectedStreamerId;
  late final ValueNotifier<double> _zoomNotifier;
  late final ValueNotifier<int> _cameraRevision;
  double? _lastClusterZoom;

  /// The camera for clustering, read from the controller rather than
  /// `MapCamera.of(context)`: the inherited lookup subscribes the builder to
  /// every camera change, which rebuilt the marker layer on every pan frame.
  MapCamera _clusterCamera(BuildContext context) {
    try {
      return _mapController.camera;
    } catch (_) {
      return MapCamera.of(context);
    }
  }
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _topControlsKey = GlobalKey();
  final GlobalKey _emptyNoticeKey = GlobalKey();

  /// Web only: whether the user dismissed the "use offline" suggestion.
  static const String _webHintDismissedKey =
      'map_web_offline_hint_dismissed_v1';
  bool _webHintDismissed = true;
  bool _isRetryingConnectivity = false;
  bool _mapReady = false;

  /// False until the user or the app moves the camera. Until then the first
  /// overview is re-framed whenever the measured insets change (controls,
  /// notice, Arabic mirroring), since it was built before they were known.
  bool _cameraMoved = false;

  /// Map canvas and the parts of it covered by floating controls, updated
  /// after every layout so every path frames against what is visible.
  Size _canvas = Size.zero;
  EdgeInsets _safePadding = const EdgeInsets.fromLTRB(16, 132, 72, 56);

  @override
  void initState() {
    super.initState();
    _pack = widget.packController ?? MapPackController.shared;
    unawaited(_pack.ensureOpened());
    if (_pack.supportsWebOffline) unawaited(_loadWebHintState());
    _mapController = MapController();
    _zoomNotifier = ValueNotifier<double>(0);
    _cameraRevision = ValueNotifier<int>(0);
    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Live markers expire with the catalog read behind them: other accounts'
    // live changes never reach this client over Realtime (profiles RLS).
    _catalogFreshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      // Paused while the map tab is hidden or the app is backgrounded (the
      // feed shares the same catalog read; audit NET-02).
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) return;
      final provider = context.read<AppProvider>();
      if (provider.isOnline) {
        unawaited(
            provider.refreshCatalogIfOlderThan(const Duration(seconds: 30)));
      }
    });
  }

  Timer? _catalogFreshnessTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _selectedStreamerId = null;
  }

  @override
  void dispose() {
    _catalogFreshnessTimer?.cancel();
    _zoomNotifier.dispose();
    _cameraRevision.dispose();
    _cameraAnimationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Camera: every path below ends in [_moveTo], which clamps each animation
  // frame with the shared policy (the FlutterMap constraint applies the same
  // containment to gestures, wheel and keyboard input).
  // ---------------------------------------------------------------------

  void _stopCameraAnimation() {
    if (_cameraAnimationListener != null) {
      _cameraAnimationController.removeListener(_cameraAnimationListener!);
      _cameraAnimationListener = null;
    }
    _cameraAnimationController.stop();
    _cameraAnimationController.reset();
  }

  void _moveTo(MapCameraTarget target,
      {bool animate = true, bool userIntent = true}) {
    if (!_mapReady || _canvas.isEmpty) return;
    if (userIntent) _cameraMoved = true;
    _stopCameraAnimation();
    final startCenter = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    void apply(double t) {
      final lat = startCenter.latitude +
          (target.center.latitude - startCenter.latitude) * t;
      final lng = startCenter.longitude +
          (target.center.longitude - startCenter.longitude) * t;
      final zoom = startZoom + (target.zoom - startZoom) * t;
      final legal =
          _policy.legalTarget(LatLng(lat, lng), zoom, _canvas, _safePadding);
      if (legal != null) _mapController.move(legal.center, legal.zoom);
    }

    if (!animate) {
      apply(1);
      return;
    }
    final curve = CurvedAnimation(
      parent: _cameraAnimationController,
      curve: Curves.fastOutSlowIn,
    );
    void listener() => apply(curve.value);
    _cameraAnimationListener = listener;
    _cameraAnimationController.addListener(listener);
    _cameraAnimationController.forward();
  }

  /// After resize, orientation, text-size or tab-restore layout changes:
  /// keep the current view if it is still legal, otherwise the nearest
  /// legal one.
  void _enforceLegalCamera() {
    if (!_mapReady || _canvas.isEmpty) return;
    final camera = _mapController.camera;
    final legal =
        _policy.legalTarget(camera.center, camera.zoom, _canvas, _safePadding);
    if (legal == null) return;
    final moved = (legal.zoom - camera.zoom).abs() > 1e-6 ||
        (legal.center.latitude - camera.center.latitude).abs() > 1e-9 ||
        (legal.center.longitude - camera.center.longitude).abs() > 1e-9;
    if (moved) _moveTo(legal, animate: false, userIntent: false);
  }

  /// Re-frames the untouched first overview with the measured insets.
  void _reframeInitialOverview() {
    if (!_mapReady || _cameraMoved || _canvas.isEmpty) return;
    _moveTo(_policy.overviewTarget(_canvas, _safePadding),
        animate: false, userIntent: false);
  }

  void _showOverview() {
    setState(() => _selectedCityId = kAllCitiesId);
    _moveTo(_policy.overviewTarget(_canvas, _safePadding));
  }

  /// Dropdown and search share this: select the city view and frame it.
  void _selectCity(String cityId) {
    final view = cityViewById(cityId);
    if (view == null) {
      _showOverview();
      return;
    }
    setState(() => _selectedCityId = cityId);
    _moveTo(_policy.fitExtent(view.view, _canvas, _safePadding));
  }

  /// Padding used when focusing a venue: keeps it above the summary card.
  EdgeInsets get _focusPadding => _safePadding.copyWith(
      bottom: math.max(_safePadding.bottom, 240).toDouble());

  void _focusVenue(LatLng venue, double zoom) {
    final target = _policy.focusTarget(venue, zoom, _canvas, _focusPadding);
    if (target == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('map.outside_area'.tr()),
        action: SnackBarAction(
          label: 'map.overview_button'.tr(),
          onPressed: _showOverview,
        ),
      ));
      return;
    }
    _moveTo(target);
  }

  void _selectStreamer(StreamerModel streamer) {
    setState(() {
      _selectedStreamerId = streamer.streamerId;
    });
    _focusVenue(LatLng(streamer.latitude, streamer.longitude), kVenueFocusZoom);
  }

  /// UI-08 "Retry and recover when connectivity returns": a manual nudge on
  /// top of the automatic recovery ConnectivityService.onStatusChange
  /// already drives (AppProvider.ensureConnectivityMonitoringActive) -- the
  /// device connectivity API can report "connected" slightly before the
  /// backend is actually reachable, so a visible retry action matters even
  /// though recovery is also automatic.
  Future<void> _retryConnectivity() async {
    if (_isRetryingConnectivity) return;
    setState(() => _isRetryingConnectivity = true);
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

  void _openDetails() {
    final provider = context.read<AppProvider>();
    showMapDetailsSheet(
      context,
      controller: _pack,
      venuesUpdatedAt: provider.mapCacheUpdatedAt,
      backendOnline: provider.isOnline,
    );
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
                    openVenueDirections(
                        context, marker.latitude, marker.longitude);
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
      _focusVenue(group.center, nextZoom);
      return;
    }
    // Deepest zoom: overlapping or same-coordinate venues are listed, each
    // at its own true coordinates.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg,
                  AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceXs),
              child: Semantics(
                header: true,
                child: Text(
                  'map.cluster_list_title'
                      .tr(namedArgs: {'count': '${group.memberIds.length}'}),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ...group.memberIds.where(byId.containsKey).map((id) {
              final item = byId[id];
              if (item == null) return const SizedBox.shrink();
              return ListTile(
                leading:
                    const Icon(Icons.place_rounded, color: AppTheme.primary),
                title: Text(label(item)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onPick(item);
                },
              );
            }),
          ],
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
    List<MapMarkerModel> visible,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable: _cameraRevision,
      builder: (context, revision, child) {
        final camera = _clusterCamera(context);
        final groups = clusterMapPoints(
          visible.map((m) => MapClusterPoint(m.streamerId, m.coordinates)),
          project: camera.projectAtZoom,
          unproject: camera.unprojectAtZoom,
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
                      onDoubleTap: () => _focusVenue(
                          marker.coordinates,
                          math.min(
                              _mapController.camera.zoom + 2, kMapMaxZoom)),
                    ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _loadWebHintState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_webHintDismissedKey) ?? false;
      if (mounted) setState(() => _webHintDismissed = dismissed);
    } catch (_) {}
  }

  Future<void> _dismissWebHint() async {
    setState(() => _webHintDismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_webHintDismissedKey, true);
    } catch (_) {}
  }

  /// Browser only: suggest preparing the offline map once, and again
  /// whenever the browser has removed a prepared copy.
  bool get _showWebOfflineHint {
    final state = _pack.webOffline?.state;
    if (!_pack.supportsWebOffline || !_pack.canPrepareWebOffline) return false;
    if (state == WebOfflineState.evicted) return true;
    return state == WebOfflineState.notPrepared && !_webHintDismissed;
  }

  /// Measures the floating controls so framing keeps cities and venues clear
  /// of them at every text size, and mirrors the side inset for the button
  /// column in right-to-left layouts.
  void _measureInsets() {
    final box =
        _topControlsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = box.size.height + AppTheme.spaceSm;
    final notice =
        _emptyNoticeKey.currentContext?.findRenderObject() as RenderBox?;
    final bottom = notice != null && notice.hasSize
        ? 60 + notice.size.height + AppTheme.spaceSm
        : 56.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final next = EdgeInsets.fromLTRB(
        desktop || !rtl ? 16 : 72, top, desktop || !rtl ? 72 : 16, bottom);
    if ((next.top - _safePadding.top).abs() > 1 ||
        (next.bottom - _safePadding.bottom).abs() > 1 ||
        next.left != _safePadding.left) {
      setState(() => _safePadding = next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reframeInitialOverview();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Most strings below use plain `.tr()`, which does not subscribe to
    // locale changes; reading the locale here makes a language switch
    // rebuild this screen (the camera and selection are kept).
    final locale = context.locale;
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    // Backend reachability: decides current versus saved venue pins only.
    final isOnline = context.select<AppProvider, bool>((p) => p.isOnline);
    final cachedMarkers = context
        .select<AppProvider, List<MapMarkerModel>>((p) => p.cachedMapMarkers);
    final visibleCachedMarkers = visibleCachedMapMarkers(
      cachedMarkers,
      currentVisibleIds: currentVisibleIds,
    )
        .where(
            (m) => categoryFilterMatches(currentCategoryFilter, m.categoryId))
        .toList();
    final hasOfflineMarkers = visibleCachedMarkers.isNotEmpty;
    final networkStatus =
        context.select<AppProvider, NetworkStatus>((p) => p.networkStatus);
    final venuesUpdatedAt =
        context.select<AppProvider, DateTime?>((p) => p.mapCacheUpdatedAt);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureInsets();
    });

    return Scaffold(
      key: _scaffoldKey,
      drawerScrimColor: isDesktop ? Colors.transparent : null,
      endDrawerEnableOpenDragGesture: !isDesktop,
      endDrawer: StreamerSlidingDrawer(
        streamers: displayedStreamers,
        onStreamerSelected: (streamer) => _selectStreamer(streamer),
      ),
      body: Row(
        children: [
          // Main Map Canvas Viewport
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final available = constraints.biggest;
              final canvas = isDesktop
                  ? available
                  : _policy.feasibleCanvas(available, _safePadding);
              if (canvas != _canvas) {
                _canvas = canvas;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _enforceLegalCamera();
                });
              }
              final initial = _policy.overviewTarget(canvas, _safePadding);
              final searchBar = TopSpatialSearchBar(
                visibleStreamers: displayedStreamers,
                cachedMarkers: isOnline ? const [] : visibleCachedMarkers,
                onCitySelected: _selectCity,
                onStreamerSelected: (streamerId) {
                  final current = displayedStreamers
                      .where((s) => s.streamerId == streamerId)
                      .firstOrNull;
                  if (current != null) _selectStreamer(current);
                },
                onCachedMarkerSelected: (marker) {
                  _focusVenue(marker.coordinates, kVenueFocusZoom);
                  _showCachedMarkerInfo(context, marker);
                },
              );
              final cityDropdown = CitySelectorDropdown(
                selectedCityId: _selectedCityId,
                onCitySelected: _selectCity,
              );
              final topicDropdown = TopicSelectorDropdown(
                selectedCategoryId: currentCategoryFilter,
                categories: context.select<AppProvider, List<AcademicCategoryModel>>(
                    (p) => p.academicCategories),
                onCategorySelected: (categoryId) {
                  context.read<AppProvider>().setCategoryFilter(categoryId);
                  if (selectedStreamer != null &&
                      !categoryFilterMatches(
                          categoryId, selectedStreamer.categoryId)) {
                    setState(() {
                      _selectedStreamerId = null;
                    });
                  }
                },
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: AppTheme.surfaceAlt),
                  ),
                  Center(
                    child: SizedBox(
                      width: canvas.width,
                      height: canvas.height,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: initial.center,
                          initialZoom: initial.zoom,
                          minZoom: _policy.minZoom(canvas, _safePadding),
                          maxZoom: kMapMaxZoom,
                          backgroundColor: AppTheme.bg,
                          cameraConstraint: CameraConstraint.contain(
                            bounds: kTricityNavigationExtent.bounds,
                          ),
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          onMapReady: () {
                            _mapReady = true;
                            _enforceLegalCamera();
                            _reframeInitialOverview();
                          },
                          onPositionChanged: (camera, hasGesture) {
                            if (hasGesture) {
                              _cameraMoved = true;
                              _stopCameraAnimation();
                            }
                            if (_zoomNotifier.value != camera.zoom) {
                              _zoomNotifier.value = camera.zoom;
                            }
                            // Clusters depend on zoom only (the grid is in absolute
                            // world pixels), and MarkerLayer repositions markers on
                            // pan by itself, so re-cluster only when the zoom
                            // changes, not on every pan frame (audit MAP-01).
                            if (_lastClusterZoom != camera.zoom) {
                              _lastClusterZoom = camera.zoom;
                              _cameraRevision.value++;
                            }
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
                          TricityBasemapLayer(controller: _pack),
                          if (!isOnline)
                            _buildOfflineMarkerLayer(
                                context, visibleCachedMarkers),
                          if (isOnline)
                            _buildLiveMarkerLayer(displayedStreamers,
                                selectedStreamer, ownStreamerId),
                        ],
                      ),
                    ),
                  ),

                  // No eligible venues: a compact notice above the credit
                  // rail, so the map itself stays visible and usable.
                  if (isOnline
                      ? displayedStreamers.isEmpty
                      : !hasOfflineMarkers)
                    PositionedDirectional(
                      key: ValueKey('map_empty_$locale'),
                      start: AppTheme.spaceMd,
                      end: 76,
                      bottom: 60,
                      child: Container(
                        key: _emptyNoticeKey,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            AppTheme.spaceMd,
                            AppTheme.spaceSm,
                            AppTheme.spaceXs,
                            AppTheme.spaceSm),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          border: Border.all(color: AppTheme.borderStrong),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          boxShadow: AppTheme.mapOverlayShadow,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_off_outlined,
                                    color: AppTheme.textSecondary, size: 20),
                                const SizedBox(width: AppTheme.spaceSm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('map.empty_title'.tr(),
                                          style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          (isOnline
                                                  ? 'map.empty_body'
                                                  : 'map.offline_empty_body')
                                              .tr(),
                                          style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Offline, the connection line at the top already
                            // offers Retry; one Retry is enough.
                            if (isOnline)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  onPressed: _isRetryingConnectivity
                                      ? null
                                      : _retryConnectivity,
                                  style: TextButton.styleFrom(
                                      minimumSize: const Size(48, 48)),
                                  child: Text('map.offline_retry'.tr()),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Local pack opening or unusable: pins/list/live actions
                  // above still work.
                  ListenableBuilder(
                    listenable: _pack,
                    builder: (context, _) => _pack.isReady
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spaceLg),
                              child: MapPackStatusCard(
                                controller: _pack,
                                onShowList: () =>
                                    _scaffoldKey.currentState?.openEndDrawer(),
                              ),
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
                        key: _topControlsKey,
                        padding: EdgeInsets.fromLTRB(
                          AppTheme.spaceMd,
                          AppTheme.spaceSm,
                          isDesktop ? 72 : AppTheme.spaceMd,
                          AppTheme.spaceSm,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isOnline) ...[
                              MapConnectionChip(
                                label: _connectionLabel(
                                    networkStatus, venuesUpdatedAt),
                                isRetrying: _isRetryingConnectivity,
                                onRetry: _retryConnectivity,
                                onDetails: _openDetails,
                              ),
                              const SizedBox(height: AppTheme.spaceSm),
                            ],
                            // Wide canvases (landscape phones, tablets,
                            // desktop) use one control row so the overview
                            // keeps enough visible map below the controls.
                            if (available.width >= 720)
                              Row(
                                children: [
                                  Expanded(flex: 5, child: searchBar),
                                  const SizedBox(width: AppTheme.spaceSm),
                                  Expanded(flex: 3, child: cityDropdown),
                                  const SizedBox(width: AppTheme.spaceSm),
                                  Expanded(flex: 3, child: topicDropdown),
                                  const SizedBox(width: AppTheme.spaceSm),
                                  const LanguageSwitcher(),
                                ],
                              )
                            else ...[
                              // Row 1: Search bar taking nearly 100% width + Language Switcher Toggle
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: searchBar),
                                  const SizedBox(width: AppTheme.spaceSm),
                                  const LanguageSwitcher(),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spaceSm),
                              // Row 2 (Fixed, non-scrolling): City view picker alongside Topic/Category Dropdown
                              Row(
                                children: [
                                  Expanded(child: cityDropdown),
                                  const SizedBox(width: AppTheme.spaceSm),
                                  Expanded(child: topicDropdown),
                                ],
                              ),
                            ],
                            ListenableBuilder(
                              listenable: _pack,
                              builder: (context, _) => _showWebOfflineHint
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                          top: AppTheme.spaceSm),
                                      child: MapWebOfflineHint(
                                        evicted: _pack.webOffline?.state ==
                                            WebOfflineState.evicted,
                                        // Not dismissed here: success hides
                                        // the prompt (ready), a failure
                                        // keeps it so the user can retry.
                                        onPrepare: () {
                                          unawaited(_pack.prepareWebOffline());
                                          _openDetails();
                                        },
                                        onDismiss: _dismissWebHint,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (isDesktop)
                    Positioned(
                      right: AppTheme.spaceMd,
                      top: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spaceSm),
                          child: _buildFloatingMapButton(
                            icon: Icons.format_list_bulleted_rounded,
                            tooltip: 'map.broadcasters_list'.tr(),
                            onTap: () =>
                                _scaffoldKey.currentState?.openEndDrawer(),
                          ),
                        ),
                      ),
                    ),

                  // Keep the card above a shared attribution/control row.
                  PositionedDirectional(
                    top: _safePadding.top,
                    bottom: 0,
                    start: 0,
                    end: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (selectedStreamer != null)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Center(
                                heightFactor: 1,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: 420,
                                    maxHeight: available.height * 0.55,
                                  ),
                                  child: SingleChildScrollView(
                                    child: MarkerSummaryCard(
                                      streamer: selectedStreamer,
                                      onClose: () => setState(() {
                                        _selectedStreamerId = null;
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: ListenableBuilder(
                                  listenable: _pack,
                                  builder: (context, _) => MapAttributionRail(
                                    controller: _pack,
                                    onDetails: _openDetails,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isDesktop) ...[
                              _buildFloatingMapButton(
                                icon: Icons.format_list_bulleted_rounded,
                                tooltip: 'map.broadcasters_list'.tr(),
                                onTap: () =>
                                    _scaffoldKey.currentState?.openEndDrawer(),
                              ),
                              const SizedBox(width: 16),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  String _connectionLabel(NetworkStatus status, DateTime? updatedAt) {
    final prefix = status == NetworkStatus.degraded
        ? 'map.status_degraded'.tr()
        : 'map.status_offline'.tr();
    final saved = updatedAt == null
        ? 'map.offline_last_updated_never'.tr()
        : 'map.status_saved_venues'.tr(namedArgs: {
            'time': DateFormat('yyyy-MM-dd HH:mm').format(updatedAt),
          });
    return '$prefix · $saved';
  }

  /// Current catalog pins: live state only comes from the current provider
  /// snapshot, never from the saved cache.
  Widget _buildLiveMarkerLayer(
    List<StreamerModel> displayedStreamers,
    StreamerModel? selectedStreamer,
    String? ownStreamerId,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable: _cameraRevision,
      builder: (context, revision, child) {
        final camera = _clusterCamera(context);
        if (displayedStreamers.isEmpty) {
          return const SizedBox.shrink();
        }
        final List<Marker> markerList = [];
        final groups = clusterMapPoints(
          displayedStreamers
              .where((s) => s.streamerId != selectedStreamer?.streamerId)
              .map((s) => MapClusterPoint(
                  s.streamerId, LatLng(s.latitude, s.longitude))),
          project: camera.projectAtZoom,
          unproject: camera.unprojectAtZoom,
        );
        if (selectedStreamer != null) {
          groups.add(MapClusterGroup(
            'marker_${selectedStreamer.streamerId}',
            [selectedStreamer.streamerId],
            LatLng(selectedStreamer.latitude, selectedStreamer.longitude),
          ));
        }
        final byId = {for (final s in displayedStreamers) s.streamerId: s};

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
                      (s) => s.getLocalizedName(context.locale.languageCode),
                      _selectStreamer)),
            ));
            continue;
          }
          final streamer = byId[group.memberIds.single]!;
          final isSelected = _selectedStreamerId == streamer.streamerId;
          final markerModel = _mapStreamerToMarker(streamer);
          final isLive = markerModel.isLive;

          markerList.add(
            Marker(
              key: ValueKey('marker_${streamer.streamerId}'),
              point: group.center,
              width: isLive ? 56.0 : 48.0,
              height: isLive ? 56.0 : 48.0,
              alignment: Alignment.center,
              child: SpatialStreamerMarker(
                key: ValueKey('avatar_${streamer.streamerId}'),
                marker: markerModel,
                isSelected: isSelected,
                isMine: ownStreamerId == streamer.streamerId,
                onTap: () => _selectStreamer(streamer),
                onDoubleTap: () => _focusVenue(
                  LatLng(streamer.latitude, streamer.longitude),
                  math.min(_mapController.camera.zoom + 2, kMapMaxZoom),
                ),
              ),
            ),
          );
        }

        return MarkerLayer(markers: markerList);
      },
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
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Icon(icon, color: AppTheme.danger, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
