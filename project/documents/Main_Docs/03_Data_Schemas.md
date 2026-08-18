# Data Schemas & Model Architecture: Educational Streaming App

## Overview

This document specifies the authoritative **Data Schemas**, **JSON Payloads**, and **Dart Class Definitions** for the Educational Cloud Streaming Application. 

These models unify data contracts across all 4 feature modules (Spatial Map, Discovery Feed, Broadcaster Profiles, and Live Streaming & Chat) and specify fallback strategies for the GIS map asset (`gadm41_SAU_2.svg`).

---

## 1. Spatial Map & GIS Schemas (`map_models.dart`)

### SVG vs. GeoJSON Ingestion Strategy & Fallback Pipeline

The project includes `gadm41_SAU_2.svg` representing Saudi Arabia's Level-2 administrative boundaries (Al Khobar, Dammam, Dhahran, Jubail, Ahsa).

```
+---------------------------------------------------------------------------------------------------+
|                                  SPATIAL MAP DATA INGEST PIPELINE                                 |
|                                                                                                   |
|  [ Primary Strategy ]   Load `gadm41_SAU_2.svg` via `flutter_svg` / `path_drawing` for vector    |
|                         polygon rendering and click-detection bounds.                             |
|                                                                                                   |
|  [ Fallback Strategy]   If SVG path parsing encounters coordinate projection mismatches or        |
|                         rendering FPS drops on mobile devices, extract polygon LatLng bounds      |
|                         into a optimized `al_sharqia_sectors.json` GeoJSON file for `flutter_map`.|
+---------------------------------------------------------------------------------------------------+
```

### A. Map Region Model (`MapRegionModel`)

```json
{
  "region_id": "sau_eastern_khobar",
  "name_en": "Al Khobar",
  "name_ar": "الخبر",
  "center_coordinates": {
    "latitude": 26.2172,
    "longitude": 50.1971
  },
  "bounding_box": {
    "south_west": { "latitude": 26.1500, "longitude": 50.1000 },
    "north_east": { "latitude": 26.3000, "longitude": 50.2500 }
  },
  "svg_element_id": "SAU.2.4_1",
  "geojson_polygon_file": "assets/map/khobar_boundary.json",
  "zoom_level_target": 13.5
}
```

### B. Broadcaster Map Pin Model (`MapMarkerModel`)

```json
{
  "marker_id": "pin_prof_001",
  "streamer_id": "prof_alghamdi_01",
  "display_name_en": "Dr. Abdullah Al-Ghamdi",
  "display_name_ar": "د. عبد الله الغامدي",
  "venue_name_en": "KFUPM Building 24 Auditorium",
  "venue_name_ar": "قاعة قصر المؤتمرات - مبنى 24",
  "coordinates": {
    "latitude": 26.3042,
    "longitude": 50.1462
  },
  "city_id": "khobar",
  "status": "live",
  "viewer_count": 482,
  "pulsing_color_hex": "#FF8080"
}
```

### Dart Data Classes (`SpatialMapModel`)

```dart
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
  final MarkerStatus status; // enum: live, offline
  final int viewerCount;

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
    required this.status,
    required this.viewerCount,
  });

  bool get isLive => status == MarkerStatus.live;
}

enum MarkerStatus { live, offline }
```

---

## 2. Streamer & Creator Identity Schemas (`streamer_models.dart`)

Streamers are **controlled, approved creators** (professors, verified scholars, universities, and recognized educational centers).

```json
{
  "streamer_id": "prof_alghamdi_01",
  "full_name_en": "Dr. Abdullah Al-Ghamdi",
  "full_name_ar": "د. عبد الله الغامدي",
  "title_en": "Professor of Computer Engineering",
  "title_ar": "أستاذ هندسة الحاسب الآلي",
  "organization_en": "King Fahd University of Petroleum and Minerals (KFUPM)",
  "organization_ar": "جامعة الملك فهد للبترول والمعادن",
  "avatar_url": "assets/images/avatars/prof_alghamdi.jpg",
  "banner_url": "assets/images/banners/kfupm_auditorium.jpg",
  "bio_en": "Specializing in Cloud Architectures, Distributed Systems, and AI.",
  "bio_ar": "متخصص في معماريات السحاب، الأنظمة الموزعة، والذكاء الاصطناعي.",
  "is_verified": true,
  "follower_count": 14200,
  "category_id": "cs_tech",
  "location": {
    "city_en": "Dhahran / Al Khobar",
    "city_ar": "الظهران / الخبر",
    "latitude": 26.3042,
    "longitude": 50.1462
  },
  "is_currently_live": true,
  "active_stream_id": "stream_live_992"
}
```

### Dart Class (`StreamerModel`)

```dart
class StreamerModel {
  final String streamerId;
  final String fullNameEn;
  final String fullNameAr;
  final String titleEn;
  final String titleAr;
  final String organizationEn;
  final String organizationAr;
  final String avatarUrl;
  final String bannerUrl;
  final String bioEn;
  final String bioAr;
  final bool isVerified;
  final int followerCount;
  final String categoryId;
  final String cityEn;
  final String cityAr;
  final bool isCurrentlyLive;
  final String? activeStreamId;

  const StreamerModel({
    required this.streamerId,
    required this.fullNameEn,
    required this.fullNameAr,
    required this.titleEn,
    required this.titleAr,
    required this.organizationEn,
    required this.organizationAr,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.bioEn,
    required this.bioAr,
    required this.isVerified,
    required this.followerCount,
    required this.categoryId,
    required this.cityEn,
    required this.cityAr,
    required this.isCurrentlyLive,
    this.activeStreamId,
  });

  String getLocalizedName(String languageCode) =>
      languageCode == 'ar' ? fullNameAr : fullNameEn;

  String getLocalizedTitle(String languageCode) =>
      languageCode == 'ar' ? titleAr : titleEn;
}
```

---

## 3. Live Broadcast Schemas (`live_stream_models.dart`)

Supports both **Cloud Media Pipelines (AWS IVS / YouTube Live)** and **Local Pitch Wi-Fi Loopback (VLC RTMP)**.

```json
{
  "stream_id": "stream_live_992",
  "streamer_id": "prof_alghamdi_01",
  "title_en": "Advanced Cloud Systems & Edge Distribution in KSA",
  "title_ar": "الأنظمة السحابية المتقدمة والتوزيع الطرفي في المملكة",
  "category_id": "cs_tech",
  "stream_source_type": "local_rtmp",
  "playback_urls": {
    "local_rtmp": "rtmp://192.168.1.100/live/demo",
    "aws_ivs_hls": "https://a1b2c3.us-east-1.playback.live-video.net/api/video/v1/master.m3u8",
    "youtube_embed_id": "dQw4w9WgXcQ"
  },
  "viewer_count": 348,
  "started_at": "2026-08-03T16:30:00Z",
  "state": "live"
}
```

### Dart Class (`LiveStreamModel`)

```dart
enum StreamSourceType { localRtmp, awsIvsHls, youtubeEmbed }
enum StreamState { live, offline, ended, fallbackError }

class LiveStreamModel {
  final String streamId;
  final String streamerId;
  final String titleEn;
  final String titleAr;
  final String categoryId;
  final StreamSourceType sourceType;
  final String playbackUrl;
  final int viewerCount;
  final DateTime startedAt;
  final StreamState state;

  const LiveStreamModel({
    required this.streamId,
    required this.streamerId,
    required this.titleEn,
    required this.titleAr,
    required this.categoryId,
    required this.sourceType,
    required this.playbackUrl,
    required this.viewerCount,
    required this.startedAt,
    required this.state,
  });

  String getLocalizedTitle(String languageCode) =>
      languageCode == 'ar' ? titleAr : titleEn;
}
```

---

## 4. Archived VOD Lecture Schemas (`vod_models.dart`)

```json
{
  "vod_id": "vod_lecture_804",
  "streamer_id": "prof_alghamdi_01",
  "title_en": "Introduction to Distributed Microservices Architecture",
  "title_ar": "مقدمة في معمارية الخدمات المصغرة الموزعة",
  "description_en": "Recorded past lecture at KFUPM covering REST APIs, gRPC, and container orchestration.",
  "description_ar": "تسجيل محاضرة سابقة بجامعة الملك فهد تغطي واجهات REST، وgRPC، وحاويات التطبيقات.",
  "youtube_video_id": "9bZkp7q19f0",
  "duration_seconds": 3240,
  "recorded_date": "2026-07-20",
  "thumbnail_url": "assets/images/vods/microservices_thumb.jpg",
  "view_count": 2840
}
```

---

## 5. Live Chat & "Ghost Audience" Schemas (`chat_models.dart`)

### Chat Message Model

```json
{
  "message_id": "msg_88102",
  "stream_id": "stream_live_992",
  "sender_name": "Fahad Al-Otaibi",
  "sender_avatar": "assets/images/avatars/user_fahad.jpg",
  "message_text_en": "Is the slide deck available on the course portal?",
  "message_text_ar": "هل الشرائح متوفرة في بوابة المقرر؟",
  "timestamp": "16:42:10",
  "is_current_user": false,
  "is_ghost_simulation": true,
  "reaction_type": "none"
}
```

### Localized Ghost Comment Dataset (`ghost_comments.dart`)

```dart
class GhostCommentPool {
  static const List<Map<String, String>> comments = [
    {
      'en': 'Peace be upon you all! Greetings from Al Khobar.',
      'ar': 'السلام عليكم ورحمة الله وبركاته! تحياتي من الخبر.'
    },
    {
      'en': 'Excellent explanation of cloud latency in KSA.',
      'ar': 'شرح ممتاز عن زمن الاستجابة السحابي في المملكة.'
    },
    {
      'en': 'Will the lecture recording be saved in VODs?',
      'ar': 'هل ستكون التسجيلات محفوظة في أرشيف المحاضرات؟'
    },
    {
      'en': 'Can we attend the physical seminar tomorrow at KFUPM?',
      'ar': 'هل يمكننا حضور الندوة المباشرة غداً في الجامعة؟'
    },
    {
      'en': 'Great point regarding edge nodes in Jeddah!',
      'ar': 'نقطة رائعة جداً بخصوص الخوادم الطرفية في جدة!'
    },
  ];
}
```

---

## 6. Category Filter Schema (`category_models.dart`)

```json
[
  {
    "category_id": "all",
    "name_en": "All Streams",
    "name_ar": "الكل",
    "icon_key": "grid_view"
  },
  {
    "category_id": "cs_tech",
    "name_en": "Computer Science & AI",
    "name_ar": "الحاسب والذكاء الاصطناعي",
    "icon_key": "code"
  },
  {
    "category_id": "islamic_studies",
    "name_en": "Islamic Studies & Lectures",
    "name_ar": "العلوم الإسلامية والمحاضرات",
    "icon_key": "book"
  },
  {
    "category_id": "engineering",
    "name_en": "Engineering & Innovation",
    "name_ar": "الهندسة والابتكار",
    "icon_key": "settings"
  }
]
```

---

## Summary Data Flow Diagram

```
 +------------------+     Select City / Pin     +------------------+
 | Spatial Map Engine| =======================> | Streamer Profile |
 | (gadm41_SAU_2)   |                          | & VOD Archives   |
 +------------------+                          +------------------+
          ||                                            ||
          || Tap Live Stream                            || Tap Watch Live
          \/                                            \/
 +-----------------------------------------------------------------+
 |                    LIVE BROADCAST ENGINE                        |
 | • Video Viewport (Local RTMP / AWS IVS / YouTube Embed)         |
 | • Inverted Live Chat ListView & Local Input                      |
 | • Ghost Audience Engine (Timer.periodic injects 4-7s comments)   |
 | • Floating Reaction Keyframes (Claps, Hearts, Hand Raise)        |
 +-----------------------------------------------------------------+
```
