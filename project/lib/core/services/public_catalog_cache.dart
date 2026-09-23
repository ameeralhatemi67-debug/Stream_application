import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/discovery/models/academic_category_model.dart';
import '../../features/profile/models/streamer_models.dart';

/// A device-wide snapshot of public discovery fields only. Keep this allowlist
/// explicit: account, session, moderation and live fields must never enter it.
class PublicCatalogSnapshot {
  const PublicCatalogSnapshot(this.updatedAt, this.streamers, this.categories);

  final DateTime updatedAt;
  final List<StreamerModel> streamers;
  final List<AcademicCategoryModel> categories;
}

class PublicCatalogCache {
  static const key = 'public_catalog_snapshot_v1';
  static const schemaVersion = 1;

  Future<void> save(
    List<StreamerModel> streamers,
    List<AcademicCategoryModel> categories, {
    DateTime? updatedAt,
  }) async {
    final data = {
      'version': schemaVersion,
      'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'streamers': streamers.map(_streamerToJson).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<PublicCatalogSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != schemaVersion) return null;
      final updatedAt = DateTime.tryParse(data['updatedAt'] as String);
      if (updatedAt == null) return null;
      return PublicCatalogSnapshot(
        updatedAt,
        (data['streamers'] as List)
            .map((item) => _streamerFromJson(item as Map<String, dynamic>))
            .toList(),
        (data['categories'] as List)
            .map((item) =>
                AcademicCategoryModel.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _streamerToJson(StreamerModel s) => {
        'id': s.streamerId,
        'nameEn': s.fullNameEn,
        'nameAr': s.fullNameAr,
        'titleEn': s.titleEn,
        'titleAr': s.titleAr,
        'organizationEn': s.organizationEn,
        'organizationAr': s.organizationAr,
        'avatar': s.avatarUrl,
        'banner': s.bannerUrl,
        'bioEn': s.bioEn,
        'bioAr': s.bioAr,
        'categoryId': s.categoryId,
        'tags': s.tags,
        'cityEn': s.cityEn,
        'cityAr': s.cityAr,
        'venueEn': s.venueNameEn,
        'venueAr': s.venueNameAr,
        'latitude': s.latitude,
        'longitude': s.longitude,
        'isOrganization': s.isOrganization,
        'isVerified': s.isVerified,
        'hiddenFromMap': s.isTemporarilyHiddenFromMap,
      };

  StreamerModel _streamerFromJson(Map<String, dynamic> data) => StreamerModel(
        streamerId: data['id'] as String,
        fullNameEn: data['nameEn'] as String,
        fullNameAr: data['nameAr'] as String,
        titleEn: data['titleEn'] as String,
        titleAr: data['titleAr'] as String,
        organizationEn: data['organizationEn'] as String,
        organizationAr: data['organizationAr'] as String,
        avatarUrl: data['avatar'] as String,
        bannerUrl: data['banner'] as String,
        bioEn: data['bioEn'] as String,
        bioAr: data['bioAr'] as String,
        isVerified: data['isVerified'] as bool,
        followerCount: 0,
        categoryId: data['categoryId'] as String,
        tags: (data['tags'] as List).cast<String>(),
        cityEn: data['cityEn'] as String,
        cityAr: data['cityAr'] as String,
        venueNameEn: data['venueEn'] as String,
        venueNameAr: data['venueAr'] as String,
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        isCurrentlyLive: false,
        broadcastType: BroadcastType.offline,
        activeStreamId: null,
        activeViewerCount: 0,
        isOrganization: data['isOrganization'] as bool,
        youtubeHandle: '',
        youtubeVideoId: '',
        isTemporarilyHiddenFromMap: data['hiddenFromMap'] as bool? ?? false,
      );
}
