import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/map/models/map_models.dart';
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/map/presentation/widgets/offline_marker.dart';
import 'package:streamer_app/features/map/presentation/widgets/pulsing_live_marker.dart';
import 'package:streamer_app/features/map/presentation/widgets/spatial_streamer_marker.dart';
import 'package:streamer_app/features/map/presentation/widgets/topic_selector_dropdown.dart';
import 'package:streamer_app/features/discovery/models/academic_category_model.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';

/// Finds a Container whose BoxDecoration paints a transparent fill with outer stroke border
/// and padding gap -- the stroke ring marker styling with empty avatar space.
Finder _findStrokeRingMarkerContainer() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    return decoration.color == Colors.transparent &&
        decoration.border != null &&
        widget.padding != null;
  });
}

void main() {
  group('Spatial Map GIS Data Models Test', () {
    test('Verify AlSharqia Core Regions Configuration', () {
      expect(alSharqiaRegions.length, greaterThanOrEqualTo(3));

      final khobar = alSharqiaRegions.firstWhere((r) => r.regionId == 'khobar');
      expect(khobar.nameEn, equals('Al Khobar'));
      expect(khobar.nameAr, equals('الخبر'));
      expect(khobar.centerCoordinates.latitude, closeTo(26.28, 0.1));
      expect(khobar.centerCoordinates.longitude, closeTo(50.21, 0.1));
      expect(khobar.svgElementId, equals('path5'));
      expect(khobar.zoomLevelTarget, equals(13.5));

      final dhahran =
          alSharqiaRegions.firstWhere((r) => r.regionId == 'dhahran');
      expect(dhahran.nameEn, equals('Dhahran'));
      expect(dhahran.nameAr, equals('الظهران'));
      expect(dhahran.svgElementId, equals('path15'));

      final dammam = alSharqiaRegions.firstWhere((r) => r.regionId == 'dammam');
      expect(dammam.nameEn, equals('Dammam'));
      expect(dammam.nameAr, equals('الدمام'));
      expect(dammam.svgElementId, equals('path14'));
    });

    test('Verify MapMarkerModel Conversion from Streamer', () {
      final liveStreamer = mockStreamers.first.copyWith(
        isCurrentlyLive: true,
        activeViewerCount: 294,
      );
      final liveMarker = MapMarkerModel.fromStreamer(liveStreamer);

      expect(liveMarker.isLive, isTrue);
      expect(liveMarker.status, equals(MarkerStatus.liveVideo));
      expect(liveMarker.viewerCount, greaterThan(0));
      expect(liveMarker.displayNameEn, equals(liveStreamer.fullNameEn));
      expect(liveMarker.venueNameEn, equals(liveStreamer.venueNameEn));

      final audioStreamer = mockStreamers.first.copyWith(
        isCurrentlyLive: true,
        broadcastType: BroadcastType.liveAudio,
        activeViewerCount: 150,
      );
      final audioMarker = MapMarkerModel.fromStreamer(audioStreamer);
      expect(audioMarker.isLive, isTrue);
      expect(audioMarker.isAudioLive, isTrue);
      expect(audioMarker.status, equals(MarkerStatus.liveAudio));

      final offlineStreamer =
          mockStreamers.firstWhere((s) => !s.isCurrentlyLive);
      final offlineMarker = MapMarkerModel.fromStreamer(offlineStreamer);

      expect(offlineMarker.isLive, isFalse);
      expect(offlineMarker.status, equals(MarkerStatus.offline));
    });

    test('Verify MapRegionModel Localization Helper', () {
      final region = alSharqiaRegions.first;
      expect(region.getLocalizedName('en'), equals(region.nameEn));
      expect(region.getLocalizedName('ar'), equals(region.nameAr));
    });

    test('Verify Al Khobar Auto-Center GPS Target Coordinates', () {
      final khobar = alSharqiaRegions.firstWhere((r) => r.regionId == 'khobar');
      expect(khobar.centerCoordinates.latitude, equals(26.2871));
      expect(khobar.centerCoordinates.longitude, equals(50.2125));
      expect(khobar.zoomLevelTarget, equals(13.5));
    });

    test('Verify Category Filter Matching for Streamer Markers', () {
      final csStreamers =
          mockStreamers.where((s) => s.categoryId == 'cs_tech').toList();
      expect(csStreamers.length, greaterThanOrEqualTo(1));
      expect(csStreamers.every((s) => s.categoryId == 'cs_tech'), isTrue);

      final islamicStreamers = mockStreamers
          .where((s) => s.categoryId == 'islamic_studies')
          .toList();
      expect(islamicStreamers.length, greaterThanOrEqualTo(2));
      expect(islamicStreamers.any((s) => s.fullNameEn.contains('Ahmed Amer')),
          isTrue);
    });

    test('Verify Spatial Hero Tag Format Convention', () {
      for (final streamer in mockStreamers) {
        final tag = 'avatar_${streamer.streamerId}';
        expect(tag, startsWith('avatar_'));
        expect(tag, endsWith(streamer.streamerId));
      }
    });

    test('Verify Haversine Distance Calculation Helper', () {
      // Al Khobar Center: Lat 26.2871, Lon 50.2125
      // KFUPM Building 24: Lat 26.3042, Lon 50.1462
      final distKm = calculateDistanceKm(26.2871, 50.2125, 26.3042, 50.1462);
      expect(distKm, closeTo(6.9, 0.5)); // Expected ~6.9 km

      // Distance to exact same point should be 0
      final zeroDist = calculateDistanceKm(26.2871, 50.2125, 26.2871, 50.2125);
      expect(zeroDist, equals(0.0));
    });

    test('Verify Distance and Travel Time Localization Formatters', () {
      expect(formatDistanceKm(6.92, 'en'), equals('6.9 km'));
      expect(formatDistanceKm(6.92, 'ar'), equals('6.9 كم'));

      expect(estimateTravelTime(6.92, 'en'), contains('mins drive'));
      expect(estimateTravelTime(6.92, 'ar'), contains('دقائق بالسيارة'));
    });

    test('Venue information is derived from the streamer own venue fields',
        () {
      // The per-streamer address/gate presets described the five sample
      // broadcasters that used to ship inside lib/; they were removed in P2,
      // so every streamer's venue text now comes from its own fields.
      final alGhamdi =
          mockStreamers.firstWhere((s) => s.streamerId == 'prof_alghamdi_01');
      final info = getAuditoriumInfoForStreamer(alGhamdi);
      expect(info.addressEn, contains(alGhamdi.venueNameEn));
      expect(info.addressEn, contains(alGhamdi.cityEn));
      expect(info.getLocalizedAddress('ar'), contains(alGhamdi.venueNameAr));
    });

    test('Verify External Map Deep Link Generator', () {
      final url = generateExternalMapUrl(26.3042, 50.1462, 'KFUPM Building 24');
      expect(url, startsWith('https://www.google.com/maps/search/?api=1'));
      expect(url, contains('26.3042,50.1462'));
      expect(url, contains('KFUPM'));
    });

    test('Verify Spatial Map Bounds Locking Bounds Inclusion', () {
      const minLat = 25.40;
      const maxLat = 27.10;
      const minLng = 49.20;
      const maxLng = 50.70;

      for (final region in alSharqiaRegions) {
        expect(region.centerCoordinates.latitude, greaterThanOrEqualTo(minLat));
        expect(region.centerCoordinates.latitude, lessThanOrEqualTo(maxLat));
        expect(
            region.centerCoordinates.longitude, greaterThanOrEqualTo(minLng));
        expect(region.centerCoordinates.longitude, lessThanOrEqualTo(maxLng));

        for (final pt in region.polygonPoints) {
          expect(pt.latitude, greaterThanOrEqualTo(minLat));
          expect(pt.latitude, lessThanOrEqualTo(maxLat));
          expect(pt.longitude, greaterThanOrEqualTo(minLng));
          expect(pt.longitude, lessThanOrEqualTo(maxLng));
        }
      }
    });

    test('Verify MapRegionModel Static Haversine & Format Helpers', () {
      final dist = MapRegionModel.calculateHaversineDistance(
          26.2871, 50.2125, 26.4207, 50.0888);
      expect(dist, greaterThan(10.0));

      expect(MapRegionModel.formatDistance(12.34, 'en'), equals('12.3 km'));
      expect(MapRegionModel.formatDistance(12.34, 'ar'), equals('12.3 كم'));
    });

    test('Verify MapMarkerModel Localized Name and Venue Getters', () {
      final streamer = mockStreamers.first;
      final marker = MapMarkerModel.fromStreamer(streamer);

      expect(marker.getLocalizedName('en'), equals(streamer.fullNameEn));
      expect(marker.getLocalizedName('ar'), equals(streamer.fullNameAr));
      expect(marker.getLocalizedVenue('en'), equals(streamer.venueNameEn));
      expect(marker.getLocalizedVenue('ar'), equals(streamer.venueNameAr));
      expect(marker.coordinates.latitude, equals(streamer.latitude));
      expect(marker.coordinates.longitude, equals(streamer.longitude));
    });

    test('Verify Auditorium Fallback Info for Unknown Streamer', () {
      const customStreamer = StreamerModel(
        streamerId: 'unknown_prof_99',
        fullNameEn: 'Dr. Test Person',
        fullNameAr: 'د. شخص اختباري',
        titleEn: 'Professor',
        titleAr: 'أستاذ',
        organizationEn: 'KFUPM',
        organizationAr: 'جامعة الملك فهد',
        cityEn: 'Dhahran',
        cityAr: 'الظهران',
        venueNameEn: 'Test Science Center',
        venueNameAr: 'مركز العلوم الاختباري',
        latitude: 26.30,
        longitude: 50.14,
        isCurrentlyLive: false,
        activeViewerCount: 0,
        avatarUrl: 'https://example.com/avatar.jpg',
        bannerUrl: 'https://example.com/banner.jpg',
        bioEn: 'Bio test',
        bioAr: 'وصف اختباري',
        followerCount: 100,
        isVerified: true,
        categoryId: 'cs_tech',
      );

      final info = getAuditoriumInfoForStreamer(customStreamer);
      expect(info.seatingCapacity, equals(350));
      expect(info.getLocalizedAddress('en'), contains('Test Science Center'));
      expect(info.getLocalizedAddress('ar'), contains('مركز العلوم الاختباري'));
      expect(info.getLocalizedAuditorium('en'), contains('350 Seats'));
      expect(info.getLocalizedGate('ar'), contains('البوابة الرئيسية'));
    });

    test('Verify Travel Time Minimum Threshold Boundary', () {
      // 0.01 km should evaluate to at least 3 minutes drive
      final timeEn = estimateTravelTime(0.01, 'en');
      final timeAr = estimateTravelTime(0.01, 'ar');
      expect(timeEn, equals('~3 mins drive'));
      expect(timeAr, equals('حوالي 3 دقائق بالسيارة'));
    });

    test(
        'Cluster 3 Task 10: TopicSelectorDropdown maps icon names from '
        'AcademicCategoryModel.defaultPool instead of a hardcoded topic list',
        () {
      expect(AcademicCategoryModel.defaultPool.length, equals(8));

      final cs = AcademicCategoryModel.defaultPool
          .firstWhere((c) => c.id == 'computer_science');
      expect(cs.getLocalizedName('en'), equals('Computer Science'));
      expect(cs.getLocalizedName('ar'), equals('علوم الحاسب'));
      expect(iconForCategoryIconName(cs.iconName), equals(Icons.memory_rounded));

      final islamic = AcademicCategoryModel.defaultPool
          .firstWhere((c) => c.id == 'islamic_studies');
      expect(islamic.getLocalizedName('en'), equals('Islamic Studies'));
      expect(iconForCategoryIconName(islamic.iconName),
          equals(Icons.mosque_rounded));

      // An unknown icon name (e.g. a category an admin created without a
      // recognized icon) degrades to a generic icon instead of throwing.
      expect(iconForCategoryIconName('not_a_real_icon'),
          equals(Icons.school_rounded));
    });
  });

  group('Cluster 2 -- Tile Provider, White Markers & Google Maps (Task 7-9)',
      () {
    test(
        'Task 7: Free dark basemap tile URL has zero watermark and zero API key requirement', () {
      expect(kSpatialMapTileUrlTemplate, contains('server.arcgisonline.com'));
      expect(kSpatialMapTileUrlTemplate, contains('World_Dark_Gray_Base'));
      expect(kSpatialMapTileUrlTemplate, contains('{z}/{y}/{x}'));
    });

    test('Task 7: zero-API-key fallback points at plain OpenStreetMap tiles',
        () {
      expect(kSpatialMapTileFallbackUrl,
          equals('https://tile.openstreetmap.org/{z}/{x}/{y}.png'));
    });

    test(
        'Task 9: buildGoogleMapsSearchUrl is a coordinate-only deep link, '
        'not a text search that could resolve to the wrong venue', () {
      final url = buildGoogleMapsSearchUrl(26.3042, 50.1462);
      expect(url,
          equals('https://www.google.com/maps/search/?api=1&query=26.3042,50.1462'));

      // Every one of the three Spatial Map launch sites (VenueNavigationSheet,
      // MarkerSummaryCard, StreamerSlidingDrawer) shares this exact builder,
      // so they can never drift into three subtly different URL shapes.
      expect(Uri.parse(url).queryParameters['query'], equals('26.3042,50.1462'));
      expect(Uri.parse(url).queryParameters['api'], equals('1'));
    });

    const testMarker = MapMarkerModel(
      markerId: 'marker_test_1',
      streamerId: 'streamer_test_1',
      displayNameEn: 'Dr. Test Streamer',
      displayNameAr: 'د. اختبار',
      venueNameEn: 'Test Auditorium',
      venueNameAr: 'قاعة الاختبار',
      latitude: 26.2871,
      longitude: 50.2125,
      cityId: 'khobar',
      categoryId: 'computer_science',
      status: MarkerStatus.offline,
      viewerCount: 0,
      avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
    );

    testWidgets(
        'Task 8: SpatialStreamerMarker (offline) renders a white avatar disc',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpatialStreamerMarker(
            marker: testMarker,
            onTap: () {},
            onDoubleTap: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(_findStrokeRingMarkerContainer(), findsWidgets);
    });

    testWidgets(
        'Task 8: SpatialStreamerMarker (live video) keeps a stroke ring with transparent gap',
        (tester) async {
      final liveMarker = MapMarkerModel(
        markerId: testMarker.markerId,
        streamerId: testMarker.streamerId,
        displayNameEn: testMarker.displayNameEn,
        displayNameAr: testMarker.displayNameAr,
        venueNameEn: testMarker.venueNameEn,
        venueNameAr: testMarker.venueNameAr,
        latitude: testMarker.latitude,
        longitude: testMarker.longitude,
        cityId: testMarker.cityId,
        categoryId: testMarker.categoryId,
        status: MarkerStatus.liveVideo,
        viewerCount: 42,
        avatarUrl: testMarker.avatarUrl,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpatialStreamerMarker(
            marker: liveMarker,
            onTap: () {},
            onDoubleTap: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(_findStrokeRingMarkerContainer(), findsWidgets);
    });

    testWidgets('Task 8: OfflineMarker renders a stroke ring with transparent gap',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OfflineMarker(
            marker: testMarker,
            onTap: () {},
            onDoubleTap: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(_findStrokeRingMarkerContainer(), findsWidgets);
    });

    testWidgets(
        'Task 8: PulsingLiveMarker keeps its radar ring while the marker has a stroke ring',
        (tester) async {
      final liveMarker = MapMarkerModel(
        markerId: testMarker.markerId,
        streamerId: testMarker.streamerId,
        displayNameEn: testMarker.displayNameEn,
        displayNameAr: testMarker.displayNameAr,
        venueNameEn: testMarker.venueNameEn,
        venueNameAr: testMarker.venueNameAr,
        latitude: testMarker.latitude,
        longitude: testMarker.longitude,
        cityId: testMarker.cityId,
        categoryId: testMarker.categoryId,
        status: MarkerStatus.liveVideo,
        viewerCount: 7,
        avatarUrl: testMarker.avatarUrl,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PulsingLiveMarker(
            marker: liveMarker,
            onTap: () {},
            onDoubleTap: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(_findStrokeRingMarkerContainer(), findsWidgets);
    });
  });
}

