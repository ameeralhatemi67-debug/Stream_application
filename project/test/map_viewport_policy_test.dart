import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:streamer_app/features/map/models/map_tricity_domain.dart';
import 'package:streamer_app/features/map/presentation/map_viewport_policy.dart';
import 'package:streamer_app/features/map/presentation/venue_directions_launcher.dart';

const _policy = MapViewportPolicy();
const _padding = EdgeInsets.fromLTRB(16, 132, 72, 56);

/// Screen controls: two rows on narrow canvases, one row from 720 px wide.
EdgeInsets _paddingFor(Size available) => available.width >= 720
    ? const EdgeInsets.fromLTRB(16, 76, 72, 56)
    : _padding;

/// Canvas sizes from the acceptance plan (A10), portrait and landscape.
const _sizes = [
  Size(320, 568),
  Size(360, 800),
  Size(412, 915),
  Size(768, 1024),
  Size(1024, 768),
  Size(1440, 900),
  Size(915, 412),
  Size(280, 900),
];

/// Mercator pixel distance (at [zoom]) by which [corner] lies outside the
/// navigation extent; 0 when inside.
double _outsidePx(LatLng corner, double zoom) {
  final world = 256 * math.pow(2, zoom);
  const nav = kTricityNavigationExtent;
  final x = longitudeToMercatorX(corner.longitude);
  final y = latitudeToMercatorY(corner.latitude);
  final dx = math.max(
          0.0,
          math.max(longitudeToMercatorX(nav.west) - x,
              x - longitudeToMercatorX(nav.east))) *
      world;
  final dy = math.max(
          0.0,
          math.max(latitudeToMercatorY(nav.north) - y,
              y - latitudeToMercatorY(nav.south))) *
      world;
  return math.max(dx, dy);
}

void _expectInside(MapCameraTarget t, Size size, {String reason = ''}) {
  for (final corner in _policy.viewportCorners(t, size)) {
    expect(_outsidePx(corner, t.zoom), lessThanOrEqualTo(1.0),
        reason: '$reason corner $corner of $t at $size');
  }
}

void main() {
  test('every tested canvas becomes feasible and frames the whole overview',
      () {
    for (final available in _sizes) {
      final padding = _paddingFor(available);
      final canvas = _policy.feasibleCanvas(available, padding);
      expect(canvas.width, lessThanOrEqualTo(available.width));
      expect(canvas.height, lessThanOrEqualTo(available.height));
      expect(_policy.isFeasible(canvas, padding), isTrue,
          reason: '$available -> $canvas');
      final overview = _policy.overviewTarget(canvas, padding);
      expect(overview.zoom, closeTo(_policy.minZoom(canvas, padding), 1e-9));
      _expectInside(overview, canvas, reason: 'overview');
      // The overview extent lies inside the safe (padded) area.
      final world = 256 * math.pow(2, overview.zoom);
      final cx = longitudeToMercatorX(overview.center.longitude) * world;
      final cy = latitudeToMercatorY(overview.center.latitude) * world;
      const o = kTricityOverviewExtent;
      final left =
          longitudeToMercatorX(o.west) * world - (cx - canvas.width / 2);
      final right =
          longitudeToMercatorX(o.east) * world - (cx - canvas.width / 2);
      final top =
          latitudeToMercatorY(o.north) * world - (cy - canvas.height / 2);
      final bottom =
          latitudeToMercatorY(o.south) * world - (cy - canvas.height / 2);
      expect(left, greaterThanOrEqualTo(padding.left - 1), reason: '$canvas');
      expect(right, lessThanOrEqualTo(canvas.width - padding.right + 1),
          reason: '$canvas');
      expect(top, greaterThanOrEqualTo(padding.top - 1), reason: '$canvas');
      expect(bottom, lessThanOrEqualTo(canvas.height - padding.bottom + 1),
          reason: '$canvas');
    }
  });

  test('wide and tall layouts shrink only the offending side', () {
    final wide = _policy.feasibleCanvas(
        const Size(1440, 900), _paddingFor(const Size(1440, 900)));
    expect(wide.height, 900);
    expect(wide.width, lessThan(1440));
    final phoneLandscape = _policy.feasibleCanvas(
        const Size(915, 412), _paddingFor(const Size(915, 412)));
    expect(phoneLandscape.height, 412);
    expect(phoneLandscape.width, lessThan(915));
    // A normal portrait phone needs no change.
    expect(_policy.feasibleCanvas(const Size(412, 915), _padding),
        const Size(412, 915));
  });

  test(
      'legal targets keep the whole viewport inside the navigation extent '
      'for far-away centres and every zoom, including beyond both limits', () {
    const size = Size(412, 780);
    final centres = [
      const LatLng(26.33, 50.1),
      const LatLng(24.7136, 46.6753), // Riyadh
      const LatLng(27.5, 51.0),
      const LatLng(25.0, 49.0),
      const LatLng(26.68, 50.33), // navigation corner
      const LatLng(25.97, 49.72),
    ];
    for (final c in centres) {
      for (var z = 0.0; z <= 22; z += 0.25) {
        final t = _policy.legalTarget(c, z, size, _padding)!;
        expect(t.zoom,
            inInclusiveRange(_policy.minZoom(size, _padding), kMapMaxZoom));
        _expectInside(t, size, reason: 'centre $c z$z');
      }
    }
  });

  test('non-finite camera input is rejected, not guessed', () {
    expect(
        _policy.legalTarget(
            const LatLng(double.nan, 50), 12, const Size(400, 800), _padding),
        isNull);
    expect(
        _policy.legalTarget(const LatLng(26.3, double.infinity), 12,
            const Size(400, 800), _padding),
        isNull);
    expect(
        _policy.legalTarget(const LatLng(26.3, 50.1), 12, Size.zero, _padding),
        isNull);
  });

  test(
      'venue focus never moves a venue: out-of-area venues are refused and '
      'edge venues stay visible after clamping', () {
    const size = Size(412, 780);
    expect(
        _policy.focusTarget(
            const LatLng(24.7136, 46.6753), 15.5, size, _padding),
        isNull);
    expect(
        _policy.focusTarget(const LatLng(0, 0), 15.5, size, _padding), isNull);
    for (final venue in const [
      LatLng(26.675, 50.32), // near the north-east navigation corner
      LatLng(25.975, 49.725),
      LatLng(26.2890, 50.2170), // Al Khobar corniche
    ]) {
      final t = _policy.focusTarget(venue, 15.5, size, _padding)!;
      _expectInside(t, size, reason: 'focus $venue');
      final corners = _policy.viewportCorners(t, size);
      final lats = corners.map((c) => c.latitude);
      final lngs = corners.map((c) => c.longitude);
      expect(venue.latitude,
          inInclusiveRange(lats.reduce(math.min), lats.reduce(math.max)));
      expect(venue.longitude,
          inInclusiveRange(lngs.reduce(math.min), lngs.reduce(math.max)));
    }
  });

  test('city views fit inside the safe area at every tested canvas', () {
    for (final available in _sizes) {
      final canvas = _policy.feasibleCanvas(available, _padding);
      for (final view in kTricityCityViews) {
        final t = _policy.fitExtent(view.view, canvas, _padding);
        _expectInside(t, canvas, reason: view.id);
        expect(t.zoom, greaterThanOrEqualTo(_policy.minZoom(canvas, _padding)));
      }
    }
  });

  test('map domain: finite, not null island, inside the navigation extent', () {
    expect(isInTricityMapDomain(26.2890, 50.2170), isTrue);
    expect(isInTricityMapDomain(26.4368, 50.1040), isTrue); // Dammam
    expect(isInTricityMapDomain(26.72, 50.35),
        isTrue); // inside pack, beyond three-city core
    expect(isInTricityMapDomain(26.79, 50.35), isFalse); // beyond map edge
    expect(isInTricityMapDomain(26.72, 50.44), isFalse);
    expect(isInTricityMapDomain(24.7136, 46.6753), isFalse); // Riyadh
    expect(isInTricityMapDomain(0, 0), isFalse);
    expect(isInTricityMapDomain(double.nan, 50.1), isFalse);
    // Swapped latitude/longitude is outside, not silently corrected.
    expect(isInTricityMapDomain(50.1, 26.3), isFalse);
  });

  test('city search tolerates common spellings and the Arabic article', () {
    MapCityView view(String id) => cityViewById(id)!;
    for (final q in ['khobar', 'Al-Khubar', 'alkhobar', 'الخبر', 'خبر']) {
      expect(view('khobar').matchesSearch(q), isTrue, reason: q);
    }
    for (final q in ['dahran', 'Zahran', 'الظهران']) {
      expect(view('dhahran').matchesSearch(q), isTrue, reason: q);
    }
    for (final q in ['damam', 'Dammam', 'الدمام']) {
      expect(view('dammam').matchesSearch(q), isTrue, reason: q);
    }
    expect(view('khobar').matchesSearch('riyadh'), isFalse);
    expect(view('dammam').matchesSearch('a'), isFalse);
  });

  test('directions refuse points that are not a pinned location', () {
    expect(isUsableVenuePoint(26.289, 50.217), isTrue);
    expect(isUsableVenuePoint(0, 0), isFalse);
    expect(isUsableVenuePoint(double.nan, 50), isFalse);
    expect(isUsableVenuePoint(95, 50), isFalse);
  });

  test('cluster taps share the policy maximum', () {
    expect(clusterTapZoom(12), 14);
    expect(clusterTapZoom(17.2), kMapMaxZoom);
    expect(clusterTapZoom(17.6), isNull);
  });
}
