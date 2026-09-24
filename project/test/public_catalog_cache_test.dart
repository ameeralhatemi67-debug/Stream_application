import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/public_catalog_cache.dart';
import 'package:streamer_app/features/discovery/models/academic_category_model.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

const streamer = StreamerModel(
  streamerId: 'public-streamer',
  fullNameEn: 'Public lecturer',
  fullNameAr: 'محاضر عام',
  titleEn: 'Lecturer',
  titleAr: 'محاضر',
  organizationEn: 'Independent',
  organizationAr: 'مستقل',
  avatarUrl: '',
  bannerUrl: '',
  bioEn: 'Public bio',
  bioAr: 'سيرة عامة',
  isVerified: true,
  followerCount: 42,
  categoryId: 'education',
  cityEn: 'Dammam',
  cityAr: 'الدمام',
  venueNameEn: 'Public venue',
  venueNameAr: 'قاعة عامة',
  latitude: 26.4,
  longitude: 50.1,
  isCurrentlyLive: true,
  broadcastType: BroadcastType.liveVideo,
  activeStreamId: 'current-live-room',
  activeViewerCount: 100,
  youtubeVideoId: 'current-video',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('snapshot retains public streamer, organization and category only',
      () async {
    final cache = PublicCatalogCache();
    final org = streamer.copyWith(
      streamerId: 'public-org',
      isOrganization: true,
      fullNameEn: 'Public academy',
    );
    final timestamp = DateTime.utc(2026, 9, 24, 12);
    await cache.save([
      streamer,
      org
    ], [
      const AcademicCategoryModel(
          id: 'education', nameEn: 'Education', nameAr: 'تعليم')
    ], updatedAt: timestamp);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PublicCatalogCache.key)!;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    expect(json['version'], PublicCatalogCache.schemaVersion);
    expect(raw, isNot(contains('current-live-room')));
    expect(raw, isNot(contains('current-video')));
    expect(raw, isNot(contains('activeViewerCount')));
    expect(raw, isNot(contains('followerCount')));
    expect(raw, isNot(contains('email')));

    final restored = (await cache.load())!;
    expect(restored.updatedAt, timestamp);
    expect(restored.streamers, hasLength(2));
    expect(restored.streamers.last.isOrganization, isTrue);
    expect(restored.categories.single.nameAr, 'تعليم');
    expect(restored.streamers.first.isCurrentlyLive, isFalse);
    expect(restored.streamers.first.activeStreamId, isNull);
    expect(restored.streamers.first.activeViewerCount, 0);
  });

  test('offline cold start restores public catalog without live facts',
      () async {
    final cache = PublicCatalogCache();
    await cache
        .save([streamer], const [], updatedAt: DateTime.utc(2026, 9, 24, 12));
    final provider = AppProvider();
    provider.debugSetOnlineForTests(false);
    await provider.restorePublicCatalogFromDisk();
    expect(provider.isUsingCachedCatalog, isTrue);
    expect(provider.hasPublicCatalogSnapshot, isTrue);
    expect(provider.streamers.single.fullNameEn, 'Public lecturer');
    expect(provider.streamers.single.isCurrentlyLive, isFalse);
    expect(provider.cachedMapMarkers.single.isLive, isFalse);
    expect(provider.publicCatalogUpdatedAt, DateTime.utc(2026, 9, 24, 12));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await cache.load())!.streamers.single.streamerId,
        'public-streamer');
    provider.dispose();
  });

  test('restored catalog excludes hidden and unverified cached map pins',
      () async {
    await PublicCatalogCache().save([
      streamer,
      streamer.copyWith(
        streamerId: 'hidden',
        isTemporarilyHiddenFromMap: true,
      ),
      streamer.copyWith(streamerId: 'unverified', isVerified: false),
    ], const [], updatedAt: DateTime.utc(2026, 9, 24, 12));
    final provider = AppProvider();
    await provider.restorePublicCatalogFromDisk();
    expect(provider.cachedMapMarkers.map((m) => m.streamerId),
        ['public-streamer']);
    provider.dispose();
  });

  test('unknown schema leaves existing cache untouched', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        PublicCatalogCache.key,
        jsonEncode({
          'version': 99,
          'updatedAt': '2026-09-24T12:00:00Z',
          'streamers': [],
          'categories': []
        }));
    expect(await PublicCatalogCache().load(), isNull);
    expect(prefs.getString(PublicCatalogCache.key), isNotNull);
  });
}
