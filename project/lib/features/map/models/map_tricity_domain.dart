import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

/// A geographic rectangle in degrees. These are **product settings** for
/// the Al Khobar / Dhahran / Dammam discovery map, not administrative
/// boundaries: no verified municipal geometry is bundled (see
/// brief/research/p5-tricity-map-upgrade, A11).
class GeoExtent {
  const GeoExtent({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west, south, east, north;

  LatLngBounds get bounds =>
      LatLngBounds(LatLng(south, west), LatLng(north, east));

  LatLng get center => LatLng(
        mercatorYToLatitude(
            (latitudeToMercatorY(north) + latitudeToMercatorY(south)) / 2),
        (west + east) / 2,
      );

  bool contains(double latitude, double longitude) =>
      latitude >= south &&
      latitude <= north &&
      longitude >= west &&
      longitude <= east;

  /// Normalised Web Mercator width/height (the whole world is 1 x 1).
  double get mercatorWidth => (east - west) / 360.0;
  double get mercatorHeight =>
      latitudeToMercatorY(south) - latitudeToMercatorY(north);
}

/// Normalised Web Mercator y (0 at the north edge of the world, 1 south).
double latitudeToMercatorY(double latitude) {
  final s = math.sin(latitude * math.pi / 180.0).clamp(-0.9999, 0.9999);
  return 0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi);
}

double mercatorYToLatitude(double y) =>
    (2 * math.atan(math.exp((0.5 - y) * 2 * math.pi)) - math.pi / 2) *
    180.0 /
    math.pi;

double longitudeToMercatorX(double longitude) => (longitude + 180.0) / 360.0;

double mercatorXToLongitude(double x) => x * 360.0 - 180.0;

/// Area the bundled basemap archive covers (`pmtiles extract --bbox`).
const GeoExtent kTricityPackCoverage =
    GeoExtent(west: 49.70, south: 25.95, east: 50.45, north: 26.80);

/// The whole visible map viewport stays inside this rectangle. It sits one
/// z15 tile inside [kTricityPackCoverage], so edges never show missing data.
/// It reaches further east and north (Gulf, Ras Tanura) than
/// [kTricityVenueDomain] so that wide and tall screens can frame the
/// three-city overview below the controls; it does not widen which venues
/// appear.
const GeoExtent kTricityNavigationExtent =
    GeoExtent(west: 49.72, south: 25.97, east: 50.43, north: 26.78);

/// Coordinate safety envelope, not the venue product scope. Catalog and
/// saved pins use [isTricityMapVenue] for city membership and legacy pins.
/// Padding never admits adjacent towns by itself.
const GeoExtent kTricityVenueDomain =
    GeoExtent(west: 49.72, south: 25.97, east: 50.33, north: 26.68);

/// "All three cities" overview composition. Reviewed against the owner's
/// overview screenshot (brief/assets/issues/should_be_max_zoom.jpg): the
/// cores of Dammam, Dhahran and Al Khobar down to Al Aziziyah. It is not a
/// claim that every municipal district fits inside it.
const GeoExtent kTricityOverviewExtent =
    GeoExtent(west: 49.97, south: 26.15, east: 50.24, north: 26.51);

/// Deepest display zoom (FlutterMap 256 px convention). The archive's
/// native data stops at z15; zooms beyond it enlarge vector geometry and
/// keep labels sharp but add no new detail.
const double kMapMaxZoom = 18.0;

enum TricityCity { khobar, dhahran, dammam }

/// A named city **view**: a reviewed framing for the city's core used by the
/// city selector and search. Not a boundary and never used to decide which
/// city a venue belongs to.
class MapCityView {
  const MapCityView({
    required this.city,
    required this.nameEn,
    required this.nameAr,
    required this.view,
    this.searchTerms = const [],
  });

  final TricityCity city;
  final String nameEn;
  final String nameAr;
  final GeoExtent view;

  /// Common spellings people type (transliterations, Arabic with or without
  /// the article); matched after [normalizeSearchText].
  final List<String> searchTerms;

  String get id => city.name;

  bool matchesSearch(String query) {
    final q = normalizeSearchText(query);
    if (q.length < 2) return false;
    return [nameEn, nameAr, ...searchTerms]
        .map(normalizeSearchText)
        .any((term) => term.contains(q) || (q.length >= 4 && q.contains(term)));
  }

  String localizedName(String languageCode) =>
      languageCode == 'ar' ? nameAr : nameEn;
}

const List<MapCityView> kTricityCityViews = [
  MapCityView(
    city: TricityCity.khobar,
    nameEn: 'Al Khobar',
    nameAr: 'الخبر',
    view: GeoExtent(west: 50.155, south: 26.17, east: 50.235, north: 26.365),
    searchTerms: ['Khobar', 'Khubar', 'Alkhobar', 'Al-Khobar', 'Al Khubar'],
  ),
  MapCityView(
    city: TricityCity.dhahran,
    nameEn: 'Dhahran',
    nameAr: 'الظهران',
    view: GeoExtent(west: 50.06, south: 26.25, east: 50.19, north: 26.345),
    searchTerms: ['Dhahran', 'Dahran', 'Zahran', 'Thahran', 'ظهران'],
  ),
  MapCityView(
    city: TricityCity.dammam,
    nameEn: 'Dammam',
    nameAr: 'الدمام',
    view: GeoExtent(west: 49.98, south: 26.34, east: 50.17, north: 26.50),
    searchTerms: ['Dammam', 'Damam', 'Dammaam', 'دمام'],
  ),
];

/// Lower-case, without spaces, hyphens, apostrophes, Arabic tatweel and a
/// leading "al"/"el"/Arabic article, so "Al-Khubar", "alkhobar" and "الخبر"
/// compare sensibly.
String normalizeSearchText(String input) {
  var s = input.toLowerCase().replaceAll(RegExp(r"[\s\-'`’ʿـ]"), '');
  s = s.replaceFirst(RegExp(r'^(al|el)(?=[a-z]{3})'), '');
  s = s.replaceFirst(RegExp(r'^ال'), '');
  return s;
}

MapCityView? cityViewById(String? id) {
  for (final view in kTricityCityViews) {
    if (view.id == id) return view;
  }
  return null;
}

/// Whether a record's coordinates can be drawn on the three-city map.
/// Non-finite, null-island (0,0) and out-of-area coordinates are left out of
/// the map only; the record itself is never altered.
bool isInTricityMapDomain(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    !(latitude == 0 && longitude == 0) &&
    kTricityVenueDomain.contains(latitude, longitude);

/// Use existing city metadata, never infer municipal membership from a box.
/// Does not change missing or other city metadata.
bool isTricityVenueCity(String city) => kTricityCityViews.any((view) => [
      view.id,
      view.nameEn,
      view.nameAr,
      ...view.searchTerms
    ].map(normalizeSearchText).contains(normalizeSearchText(city)));

/// Older profiles have exact pins but no city metadata. Keep those pins in
/// the existing three-city overview, without assigning a municipal city or
/// admitting unknown locations in the wider navigation padding.
bool isTricityMapVenue(
    double latitude, double longitude, Iterable<String> cities) {
  if (!isInTricityMapDomain(latitude, longitude)) return false;
  final names = cities.where((city) => city.trim().isNotEmpty).toList();
  // ponytail: legacy fallback uses the existing overview, not municipal borders;
  // replace it when verified boundary geometry is available.
  return names.any(isTricityVenueCity) ||
      (names.isEmpty && kTricityOverviewExtent.contains(latitude, longitude));
}
