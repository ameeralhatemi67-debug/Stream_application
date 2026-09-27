import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../profile/models/streamer_models.dart';
import 'map_tricity_domain.dart';

enum MarkerStatus { liveVideo, liveAudio, offline }

class MapMarkerModel {
  final String markerId;
  final String streamerId;
  final String displayNameEn;
  final String displayNameAr;
  final String venueNameEn;
  final String venueNameAr;
  final double latitude;
  final double longitude;
  final String cityId;
  final String categoryId;
  final MarkerStatus status;
  final int viewerCount;
  final String avatarUrl;
  final bool isOrganization;

  const MapMarkerModel({
    required this.markerId,
    required this.streamerId,
    required this.displayNameEn,
    required this.displayNameAr,
    required this.venueNameEn,
    required this.venueNameAr,
    required this.latitude,
    required this.longitude,
    required this.cityId,
    required this.categoryId,
    required this.status,
    required this.viewerCount,
    required this.avatarUrl,
    this.isOrganization = false,
  });

  bool get isLive =>
      status == MarkerStatus.liveVideo || status == MarkerStatus.liveAudio;
  bool get isVideoLive => status == MarkerStatus.liveVideo;
  bool get isAudioLive => status == MarkerStatus.liveAudio;

  LatLng get coordinates => LatLng(latitude, longitude);

  String getLocalizedName(String languageCode) =>
      languageCode == 'ar' ? displayNameAr : displayNameEn;

  String getLocalizedVenue(String languageCode) =>
      languageCode == 'ar' ? venueNameAr : venueNameEn;

  factory MapMarkerModel.fromStreamer(StreamerModel streamer) {
    MarkerStatus markerStatus;
    if (streamer.isAudioLive) {
      markerStatus = MarkerStatus.liveAudio;
    } else if (streamer.isVideoLive) {
      markerStatus = MarkerStatus.liveVideo;
    } else {
      markerStatus = MarkerStatus.offline;
    }

    return MapMarkerModel(
      markerId: 'pin_${streamer.streamerId}',
      streamerId: streamer.streamerId,
      displayNameEn: streamer.fullNameEn,
      displayNameAr: streamer.fullNameAr,
      venueNameEn: streamer.venueNameEn,
      venueNameAr: streamer.venueNameAr,
      latitude: streamer.latitude,
      longitude: streamer.longitude,
      cityId: mapCityId(isTricityVenueCity(streamer.cityEn)
          ? streamer.cityEn
          : isTricityVenueCity(streamer.cityAr)
              ? streamer.cityAr
              : streamer.cityEn.trim().isNotEmpty
                  ? streamer.cityEn
                  : streamer.cityAr),
      categoryId: streamer.categoryId,
      status: markerStatus,
      viewerCount: streamer.activeViewerCount,
      avatarUrl: streamer.avatarUrl,
      isOrganization: streamer.isOrganization,
    );
  }

  /// UI-08: serialized to `shared_preferences` as the last-known-good venue
  /// snapshot, so the spatial map still has real markers to show (with a
  /// "last updated" timestamp) the moment the device goes offline, rather
  /// than an empty canvas.
  Map<String, dynamic> toJson() => {
        'markerId': markerId,
        'streamerId': streamerId,
        'displayNameEn': displayNameEn,
        'displayNameAr': displayNameAr,
        'venueNameEn': venueNameEn,
        'venueNameAr': venueNameAr,
        'latitude': latitude,
        'longitude': longitude,
        'cityId': cityId,
        'categoryId': categoryId,
        'avatarUrl': avatarUrl,
        'isOrganization': isOrganization,
      };

  /// Cached markers always deserialize as [MarkerStatus.offline]: live status
  /// is inherently a live-network fact and must never be replayed from a
  /// stale cache (UI-08 "live status marked unavailable while offline").
  factory MapMarkerModel.fromCachedJson(Map<String, dynamic> json) {
    return MapMarkerModel(
      markerId: json['markerId'] as String,
      streamerId: json['streamerId'] as String,
      displayNameEn: json['displayNameEn'] as String,
      displayNameAr: json['displayNameAr'] as String,
      venueNameEn: json['venueNameEn'] as String,
      venueNameAr: json['venueNameAr'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      cityId: json['cityId'] as String,
      categoryId: json['categoryId'] as String,
      status: MarkerStatus.offline,
      viewerCount: 0,
      avatarUrl: json['avatarUrl'] as String,
      isOrganization: json['isOrganization'] as bool? ?? false,
    );
  }
}

/// Canonicalize exact city metadata for cached pins; substring matches such
/// as "Greater Dammam" must not change membership after an offline restart.
String mapCityId(String cityEn) {
  final city = normalizeSearchText(cityEn);
  for (final view in kTricityCityViews) {
    if ([view.id, view.nameEn, view.nameAr, ...view.searchTerms]
        .map(normalizeSearchText)
        .contains(city)) {
      return view.id;
    }
  }
  return city;
}

/// Whether a streamer/marker in [categoryId] survives the map's current
/// topic filter.
///
/// The Spatial Map matched categories with its own inline copy of this
/// aliasing table (cs_tech == computer_science, islamic_studies == sharia,
/// and so on), and the offline marker layer needed the same rules again --
/// a third hand-written copy is how the offline view would end up filtering
/// differently from the online one. One function, used by both.
bool categoryFilterMatches(String filter, String categoryId) {
  if (filter == 'all' || filter == categoryId) return true;
  const aliases = <String, Set<String>>{
    'computer_science': {'cs_tech', 'computer_science'},
    'cs_tech': {'cs_tech', 'computer_science'},
    'islamic_studies': {'islamic_studies', 'sharia'},
    'medicine': {'medicine', 'health'},
    'engineering': {'engineering', 'innovation'},
  };
  return aliases[filter]?.contains(categoryId) ?? false;
}

/// Haversine Formula for GIS distance estimation in kilometers between two LatLng coordinates
double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusKm = 6371.0;
  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLon = _degreesToRadians(lon2 - lon1);

  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degreesToRadians(lat1)) *
          math.cos(_degreesToRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;

/// Formats distance in km with language localization
String formatDistanceKm(double distanceKm, String langCode) {
  final formatted = distanceKm < 10
      ? distanceKm.toStringAsFixed(1)
      : distanceKm.round().toString();
  return langCode == 'ar' ? '$formatted كم' : '$formatted km';
}

/// Formats estimated driving travel time
String estimateTravelTime(double distanceKm, String langCode) {
  final double timeHours = distanceKm / 40.0;
  final int minutes = math.max(3, (timeHours * 60).round());
  return langCode == 'ar'
      ? 'حوالي $minutes دقائق بالسيارة'
      : '~$minutes mins drive';
}

/// Generates Google Maps / Apple Maps web deep link URL
String generateExternalMapUrl(double lat, double lng, [String? label]) {
  final query = Uri.encodeComponent(label ?? '$lat,$lng');
  return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$query';
}

/// One-click Google Maps deep link for a raw coordinate pair (Task 9). A
/// coordinate-only query -- no place id, no label -- is what actually opens
/// the exact venue pin in the Google Maps app; shared by
/// VenueNavigationSheet, MarkerSummaryCard and StreamerSlidingDrawer so all
/// three "open in Maps"actions on the Spatial Map stay byte-for-byte
/// identical rather than three hand-typed copies drifting apart.
String buildGoogleMapsSearchUrl(double lat, double lng) {
  return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
}

/// Structured Campus & Auditorium Details for Eastern Province Broadcasters
class VenueAuditoriumInfo {
  final String addressEn;
  final String addressAr;
  final String auditoriumDetailsEn;
  final String auditoriumDetailsAr;
  final String gateInfoEn;
  final String gateInfoAr;
  final int seatingCapacity;

  const VenueAuditoriumInfo({
    required this.addressEn,
    required this.addressAr,
    required this.auditoriumDetailsEn,
    required this.auditoriumDetailsAr,
    required this.gateInfoEn,
    required this.gateInfoAr,
    required this.seatingCapacity,
  });

  String getLocalizedAddress(String langCode) =>
      langCode == 'ar' ? addressAr : addressEn;

  String getLocalizedAuditorium(String langCode) =>
      langCode == 'ar' ? auditoriumDetailsAr : auditoriumDetailsEn;

  String getLocalizedGate(String langCode) =>
      langCode == 'ar' ? gateInfoAr : gateInfoEn;
}

/// Preset Auditorium Data for AlSharqia Universities & Public Venues
/// Venue details for a streamer's card and navigation sheet, derived from the
/// streamer's own venue/city fields. The per-streamer presets that used to sit
/// here described the five sample broadcasters that shipped inside lib/ (P2);
/// the remaining capacity/gate wording is still generic and is replaced with
/// real venue data in P5.
VenueAuditoriumInfo getAuditoriumInfoForStreamer(StreamerModel streamer) {
  switch (streamer.streamerId) {
    default:
      return VenueAuditoriumInfo(
        addressEn: '${streamer.venueNameEn}, ${streamer.cityEn}, KSA',
        addressAr:
            '${streamer.venueNameAr}، ${streamer.cityAr}، المملكة العربية السعودية',
        auditoriumDetailsEn: 'Main University Auditorium (Capacity: 350 Seats)',
        auditoriumDetailsAr: 'المدرج الجامعي الرئيسي (سعة 350 مقعداً)',
        gateInfoEn: 'Main Campus Gate - General Parking',
        gateInfoAr: 'البوابة الرئيسية - مواقف الزوار',
        seatingCapacity: 350,
      );
  }
}
