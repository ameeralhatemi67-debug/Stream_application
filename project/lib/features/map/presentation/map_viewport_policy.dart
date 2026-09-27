import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:latlong2/latlong.dart';

import '../models/map_tricity_domain.dart';

/// A camera position the map may legally show.
class MapCameraTarget {
  const MapCameraTarget(this.center, this.zoom);

  final LatLng center;
  final double zoom;

  @override
  String toString() => 'MapCameraTarget(${center.latitude.toStringAsFixed(5)}, '
      '${center.longitude.toStringAsFixed(5)}, z${zoom.toStringAsFixed(2)})';
}

/// The one camera policy every map path uses: initial overview, gestures
/// (through the matching FlutterMap constraint), city selection from the
/// dropdown or search, venue focus, clusters, the overview button, resize and
/// tab restore. It never moves a venue: it only chooses where the camera
/// looks.
///
/// Zoom follows FlutterMap's 256 px Web Mercator convention: at zoom z the
/// world is `256 * 2^z` logical pixels wide.
class MapViewportPolicy {
  const MapViewportPolicy({
    this.navigation = kTricityNavigationExtent,
    this.overview = kTricityOverviewExtent,
    this.maxZoom = kMapMaxZoom,
  });

  final GeoExtent navigation;
  final GeoExtent overview;
  final double maxZoom;

  static double _log2(double v) => math.log(v) / math.ln2;

  /// Smallest zoom at which a [size] viewport fits entirely inside the
  /// navigation extent.
  double containZoom(Size size) => math.max(
        _log2(size.width / (256 * navigation.mercatorWidth)),
        _log2(size.height / (256 * navigation.mercatorHeight)),
      );

  /// Largest zoom that still shows the whole overview inside the safe area
  /// ([size] minus [padding]).
  double overviewZoom(Size size, EdgeInsets padding) {
    final w = math.max(1.0, size.width - padding.horizontal);
    final h = math.max(1.0, size.height - padding.vertical);
    return math.min(
      _log2(w / (256 * overview.mercatorWidth)),
      _log2(h / (256 * overview.mercatorHeight)),
    );
  }

  /// Whether a [size] canvas can show the whole overview inside its safe
  /// area (the canvas minus [padding], which is usually asymmetric because
  /// of the floating controls) while the whole viewport stays inside the
  /// navigation extent, without any clamping.
  bool isFeasible(Size size, EdgeInsets padding) {
    final spill = _overviewSpill(size, padding);
    return !spill.x && !spill.y;
  }

  /// Which axes of the unclamped overview framing spill past the navigation
  /// extent (0.5 px tolerance).
  ({bool x, bool y}) _overviewSpill(Size size, EdgeInsets padding) {
    final z = overviewZoom(size, padding);
    final world = 256 * math.pow(2, z).toDouble();
    const tol = 0.5;
    final cx = longitudeToMercatorX(overview.center.longitude) -
        (padding.left - padding.right) / 2 / world;
    final cy = latitudeToMercatorY(overview.center.latitude) -
        (padding.top - padding.bottom) / 2 / world;
    final hw = size.width / 2 / world, hh = size.height / 2 / world;
    final spillX =
        (longitudeToMercatorX(navigation.west) - (cx - hw)) * world > tol ||
            ((cx + hw) - longitudeToMercatorX(navigation.east)) * world > tol;
    final spillY =
        (latitudeToMercatorY(navigation.north) - (cy - hh)) * world > tol ||
            ((cy + hh) - latitudeToMercatorY(navigation.south)) * world > tol;
    return (x: spillX, y: spillY);
  }

  /// The largest canvas inside [available] that is feasible. Wide landscape
  /// or very tall layouts get a narrower (or shorter) centred canvas instead
  /// of cropping a city or widening the geography; the freed space shows the
  /// app surface around the map.
  Size feasibleCanvas(Size available, EdgeInsets padding) {
    if (available.width <= 0 || available.height <= 0) return available;
    var size = available;
    final minWidth = padding.horizontal + 48, minHeight = padding.vertical + 48;
    for (var i = 0; i < 120; i++) {
      final spill = _overviewSpill(size, padding);
      if (!spill.x && !spill.y) return size;
      if (spill.x && size.width * 0.98 >= minWidth) {
        size = Size(size.width * 0.98, size.height);
      } else if (spill.y && size.height * 0.98 >= minHeight) {
        size = Size(size.width, size.height * 0.98);
      } else {
        break;
      }
    }
    // The safe-area padding itself is too large for this canvas; keep the
    // full canvas and let [minZoom] fall back to containment (documented
    // small-canvas limit: the overview is then partly cropped).
    return isFeasible(size, padding) ? size : available;
  }

  /// The minimum zoom for this canvas: the overview framing when feasible,
  /// otherwise the containment zoom (the canvas should first be reduced with
  /// [feasibleCanvas]).
  double minZoom(Size size, EdgeInsets padding) {
    final contain = containZoom(size);
    final fit = overviewZoom(size, padding);
    return math.min(maxZoom, math.max(contain, fit));
  }

  double clampZoom(double zoom, Size size, EdgeInsets padding) => zoom.isFinite
      ? zoom.clamp(minZoom(size, padding), maxZoom)
      : minZoom(size, padding);

  /// Clamps a desired camera so the whole [size] viewport stays inside the
  /// navigation extent. Returns null for non-finite input.
  MapCameraTarget? legalTarget(
    LatLng center,
    double zoom,
    Size size,
    EdgeInsets padding,
  ) {
    if (!center.latitude.isFinite || !center.longitude.isFinite) return null;
    if (size.width <= 0 || size.height <= 0) return null;
    final z = clampZoom(zoom, size, padding);
    final world = 256 * math.pow(2, z).toDouble();
    final halfW = size.width / 2 / world;
    final halfH = size.height / 2 / world;
    final minX = longitudeToMercatorX(navigation.west) + halfW;
    final maxX = longitudeToMercatorX(navigation.east) - halfW;
    final minY = latitudeToMercatorY(navigation.north) + halfH;
    final maxY = latitudeToMercatorY(navigation.south) - halfH;
    double clampAxis(double v, double lo, double hi) =>
        lo > hi ? (lo + hi) / 2 : v.clamp(lo, hi);
    final x = clampAxis(longitudeToMercatorX(center.longitude), minX, maxX);
    final y = clampAxis(latitudeToMercatorY(center.latitude), minY, maxY);
    return MapCameraTarget(
        LatLng(mercatorYToLatitude(y), mercatorXToLongitude(x)), z);
  }

  /// Frames [extent] inside the safe area and returns the legal camera.
  MapCameraTarget fitExtent(GeoExtent extent, Size size, EdgeInsets padding) {
    final w = math.max(1.0, size.width - padding.horizontal);
    final h = math.max(1.0, size.height - padding.vertical);
    final zoom = math.min(
      _log2(w / (256 * extent.mercatorWidth)),
      _log2(h / (256 * extent.mercatorHeight)),
    );
    return _centredOnSafeArea(extent.center, zoom, size, padding);
  }

  MapCameraTarget overviewTarget(Size size, EdgeInsets padding) =>
      fitExtent(overview, size, padding);

  /// Focus on a venue without moving it. Returns null when the venue is
  /// outside the map domain (the caller explains and keeps the record).
  MapCameraTarget? focusTarget(
    LatLng venue,
    double desiredZoom,
    Size size,
    EdgeInsets padding,
  ) {
    if (!isInTricityMapDomain(venue.latitude, venue.longitude)) return null;
    return _centredOnSafeArea(venue, desiredZoom, size, padding);
  }

  /// Places [point] at the centre of the safe area (the viewport minus
  /// [padding]) and then clamps. Because the viewport stays inside the
  /// navigation extent and [point] is inside it too, the point stays
  /// visible after clamping.
  MapCameraTarget _centredOnSafeArea(
    LatLng point,
    double zoom,
    Size size,
    EdgeInsets padding,
  ) {
    final z = clampZoom(zoom, size, padding);
    final world = 256 * math.pow(2, z).toDouble();
    final dx = (padding.left - padding.right) / 2 / world;
    final dy = (padding.top - padding.bottom) / 2 / world;
    final x = longitudeToMercatorX(point.longitude) - dx;
    final y = latitudeToMercatorY(point.latitude) - dy;
    return legalTarget(
          LatLng(mercatorYToLatitude(y), mercatorXToLongitude(x)),
          z,
          size,
          padding,
        ) ??
        MapCameraTarget(point, z);
  }

  /// Screen corners of a camera, in degrees, for tests and evidence traces.
  List<LatLng> viewportCorners(MapCameraTarget target, Size size) {
    final world = 256 * math.pow(2, target.zoom).toDouble();
    final cx = longitudeToMercatorX(target.center.longitude);
    final cy = latitudeToMercatorY(target.center.latitude);
    final hw = size.width / 2 / world, hh = size.height / 2 / world;
    return [
      for (final (sx, sy) in [(-1, -1), (1, -1), (1, 1), (-1, 1)])
        LatLng(mercatorYToLatitude(cy + sy * hh),
            mercatorXToLongitude(cx + sx * hw)),
    ];
  }
}

/// Next zoom for a cluster tap, or null at the deepest zoom, where the
/// cluster's member list opens instead.
double? clusterTapZoom(double currentZoom, {double maxZoom = kMapMaxZoom}) =>
    currentZoom < maxZoom - 0.5 ? math.min(currentZoom + 2, maxZoom) : null;
