import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../profile/models/streamer_models.dart';

enum MarkerStatus { liveVideo, liveAudio, offline }

class MapRegionModel {
  final String regionId;
  final String nameEn;
  final String nameAr;
  final LatLng centerCoordinates;
  final String svgElementId;
  final double zoomLevelTarget;
  final List<LatLng> polygonPoints;

  const MapRegionModel({
    required this.regionId,
    required this.nameEn,
    required this.nameAr,
    required this.centerCoordinates,
    required this.svgElementId,
    required this.zoomLevelTarget,
    this.polygonPoints = const [],
  });

  String getLocalizedName(String languageCode) =>
      languageCode == 'ar' ? nameAr : nameEn;

  static double calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return calculateDistanceKm(lat1, lon1, lat2, lon2);
  }

  static String formatDistance(double distanceKm, String languageCode) {
    if (languageCode == 'ar') {
      return '${distanceKm.toStringAsFixed(1)} كم';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

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
      cityId: streamer.cityEn.toLowerCase().contains('dhahran')
          ? 'dhahran'
          : streamer.cityEn.toLowerCase().contains('dammam')
              ? 'dammam'
              : 'khobar',
      categoryId: streamer.categoryId,
      status: markerStatus,
      viewerCount: streamer.activeViewerCount,
      avatarUrl: streamer.avatarUrl,
      isOrganization: streamer.isOrganization,
    );
  }
}

/// AlSharqia Core Regions & 50% Decimated Clean Geographic Municipal Bounding Coordinates
const List<MapRegionModel> alSharqiaRegions = [
  MapRegionModel(
    regionId: 'khobar',
    nameEn: 'Al Khobar',
    nameAr: 'الخبر',
    centerCoordinates: LatLng(26.2871, 50.2125),
    svgElementId: 'path5',
    zoomLevelTarget: 13.5,
    polygonPoints: [
      LatLng(26.4080, 50.1850),
      LatLng(26.4020, 50.1940),
      LatLng(26.3760, 50.2170),
      LatLng(26.3300, 50.2240),
      LatLng(26.3000, 50.2210),
      LatLng(26.2730, 50.2230),
      LatLng(26.2600, 50.2140),
      LatLng(26.2570, 50.1870),
      LatLng(26.2640, 50.1610),
      LatLng(26.2870, 50.1630),
      LatLng(26.3150, 50.1750),
      LatLng(26.3420, 50.1730),
      LatLng(26.3610, 50.1700),
      LatLng(26.3850, 50.1650),
      LatLng(26.4010, 50.1710),
    ],
  ),
  MapRegionModel(
    regionId: 'dhahran',
    nameEn: 'Dhahran',
    nameAr: 'الظهران',
    centerCoordinates: LatLng(26.3042, 50.1462),
    svgElementId: 'path15',
    zoomLevelTarget: 13.5,
    polygonPoints: [
      LatLng(26.4010, 50.1710),
      LatLng(26.3850, 50.1650),
      LatLng(26.3610, 50.1700),
      LatLng(26.3420, 50.1730),
      LatLng(26.3150, 50.1750),
      LatLng(26.2870, 50.1630),
      LatLng(26.2640, 50.1610),
      LatLng(26.2500, 50.1550),
      LatLng(26.2530, 50.1250),
      LatLng(26.2550, 50.0950),
      LatLng(26.2700, 50.0850),
      LatLng(26.2950, 50.1000),
      LatLng(26.3200, 50.1150),
      LatLng(26.3450, 50.1250),
      LatLng(26.3750, 50.1200),
      LatLng(26.3950, 50.1250),
      LatLng(26.4050, 50.1450),
    ],
  ),
  MapRegionModel(
    regionId: 'dammam',
    nameEn: 'Dammam',
    nameAr: 'الدمام',
    centerCoordinates: LatLng(26.4207, 50.0888),
    svgElementId: 'path14',
    zoomLevelTarget: 13.0,
    polygonPoints: [
      LatLng(26.5100, 50.0350),
      LatLng(26.4950, 50.0650),
      LatLng(26.4800, 50.0950),
      LatLng(26.4650, 50.1150),
      LatLng(26.4450, 50.1100),
      LatLng(26.4250, 50.1150),
      LatLng(26.4080, 50.1850),
      LatLng(26.4010, 50.1710),
      LatLng(26.4050, 50.1450),
      LatLng(26.3950, 50.1250),
      LatLng(26.3750, 50.1200),
      LatLng(26.3800, 50.0950),
      LatLng(26.3900, 50.0750),
      LatLng(26.4150, 50.0550),
      LatLng(26.4400, 50.0350),
      LatLng(26.4700, 50.0200),
      LatLng(26.4950, 50.0250),
    ],
  ),
];

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
/// three "open in Maps" actions on the Spatial Map stay byte-for-byte
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
VenueAuditoriumInfo getAuditoriumInfoForStreamer(StreamerModel streamer) {
  switch (streamer.streamerId) {
    case 'prof_alghamdi_01':
      return const VenueAuditoriumInfo(
        addressEn: 'KFUPM Academic Belt, Building 24, Dhahran 31261, KSA',
        addressAr:
            'حزام جامعة الملك فهد الأكاديمي، مبنى 24، الظهران 31261، المملكة العربية السعودية',
        auditoriumDetailsEn:
            'Main Conference Hall 101 (450 Seats, Dual Laser Projectors, Live Stream Console)',
        auditoriumDetailsAr:
            'قاعة المؤتمرات الكبرى 101 (سعة 450 مقعداً، أجهزة عرض ليزرية، وحدة بث مباشر)',
        gateInfoEn: 'Gate 3 (Faculty & Guest Access) - Parking Lot B',
        gateInfoAr:
            'بوابة 3 (بوابة أعضاء هيئة التدريس والزوار) - مواقف السيارات B',
        seatingCapacity: 450,
      );
    case 'prof_otaibi_02':
      return const VenueAuditoriumInfo(
        addressEn:
            'IAU Female Campus, College of Computer Science, Al Rakah, Al Khobar 34251, KSA',
        addressAr:
            'جامعة الإمام عبد الرحمن، كلية علوم الحاسب، الراكة، الخبر 34251، المملكة العربية السعودية',
        auditoriumDetailsEn:
            'Innovation Hub Auditorium 204 (300 Seats, Interactive AI Smartboards)',
        auditoriumDetailsAr:
            'قاعة مركز الابتكار 204 (سعة 300 مقعد، شاشات التفاعلية للذكاء الاصطناعي)',
        gateInfoEn: 'Main Campus Gate 1 - Visitor Parking Area A',
        gateInfoAr: 'البوابة الرئيسية 1 - مواقف الزوار A',
        seatingCapacity: 300,
      );
    case 'prof_dossary_03':
      return const VenueAuditoriumInfo(
        addressEn:
            'Al-Rahmah Grand Mosque Complex, Corniche Road, Al Khobar 34412, KSA',
        addressAr:
            'مجمع جامع الرحمة، طريق الكورنيش، الخبر 34412، المملكة العربية السعودية',
        auditoriumDetailsEn:
            'Main Lecture & Seminar Hall (600 Seats, Integrated Spatial Audio System)',
        auditoriumDetailsAr:
            'قاعة المحاضرات والندوات الرئيسية (سعة 600 مقعد، نظام الصوت المكاني المعزز)',
        gateInfoEn: 'North Mosque Gate - Grand Courtyard Parking',
        gateInfoAr: 'البوابة الشمالية للجامع - مواقف الساحة الكبرى',
        seatingCapacity: 600,
      );
    case 'prof_mansoor_04':
      return const VenueAuditoriumInfo(
        addressEn:
            'Dhahran Techno Valley (DTV) Complex, Building 10, Dhahran 31261, KSA',
        addressAr:
            'مجمع وادي الظهران للتقنية، مبنى 10، الظهران 31261، المملكة العربية السعودية',
        auditoriumDetailsEn:
            'Clean Energy Auditorium Hall B (250 Seats, Solar Grid Demo Wall)',
        auditoriumDetailsAr:
            'قاعة الطاقة النظيفة B (سعة 250 مقعداً، شاشة عرض شبكات الطاقة الشمسية)',
        gateInfoEn: 'DTV Security Gate 2 - Executive East Parking',
        gateInfoAr: 'بوابة وادي الظهران الرئيسية - المواقف الشرقية',
        seatingCapacity: 250,
      );
    case 'prof_zahrani_05':
      return const VenueAuditoriumInfo(
        addressEn:
            'Prince Mohammad Bin Fahd University (PMU), Cyber Sciences Center, Al Khobar 34754, KSA',
        addressAr:
            'جامعة الأمير محمد بن فهد، مبنى العلوم السيبرانية، الخبر 34754، المملكة العربية السعودية',
        auditoriumDetailsEn:
            'Cyber Operations Auditorium 102 (200 Seats, Real-Time Threat Command Wall)',
        auditoriumDetailsAr:
            'قاعة عمليات الأمن السيبراني 102 (سعة 200 مقعد، جدار تحليلات التهديدات)',
        gateInfoEn: 'Gate 2 (Engineering Complex) - Visitor Parking South',
        gateInfoAr: 'البوابة 2 (بوابة الهندسة) - مواقف الزوار الجنوبية',
        seatingCapacity: 200,
      );
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
