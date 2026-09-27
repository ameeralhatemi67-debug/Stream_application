import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/features/map/models/map_models.dart';
import 'package:streamer_app/features/map/models/map_tricity_domain.dart';
import 'package:streamer_app/features/map/presentation/map_cluster_layout.dart';
import 'package:streamer_app/features/map/presentation/map_viewport_policy.dart';
import 'package:streamer_app/features/map/presentation/map_visible_catalog.dart';
import 'package:streamer_app/features/map/presentation/venue_directions_launcher.dart';
import 'package:streamer_app/features/map/presentation/widgets/spatial_streamer_marker.dart';
import 'package:streamer_app/features/map/presentation/widgets/top_spatial_search_bar.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';

class _CatalogLoader extends AssetLoader {
  const _CatalogLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

Widget _localizedWidget(Widget child) => EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/i18n',
      assetLoader: const _CatalogLoader(),
      saveLocale: false,
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: Builder(
          builder: (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                home: Scaffold(body: child),
              )),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  Offset project(LatLng p) => Offset(p.longitude, p.latitude);
  LatLng unproject(Offset p) => LatLng(p.dy, p.dx);

  test('dense points form one stable cluster with bounded projection work', () {
    var projections = 0;
    final dense = List.generate(
        1000,
        (i) => MapClusterPoint(
            'id_$i', LatLng(26.3 + i / 100000, 50.1 + i / 100000)));
    final first = clusterMapPoints(dense, project: (p) {
      projections++;
      return project(p);
    }, unproject: unproject);
    final refreshed = clusterMapPoints(dense.reversed,
        project: project, unproject: unproject);
    expect(projections, 1000);
    expect(first, hasLength(1));
    expect(first.single.memberIds, hasLength(1000));
    expect(first.single.id, refreshed.single.id);
    expect(first.single.memberIds, refreshed.single.memberIds);
  });

  test('sparse points retain coordinates and identity after a removal', () {
    final points = [
      const MapClusterPoint('a', LatLng(26.3, 50.1)),
      const MapClusterPoint('b', LatLng(26.3, 250.1)),
      const MapClusterPoint('c', LatLng(26.3, 450.1)),
    ];
    final first =
        clusterMapPoints(points, project: project, unproject: unproject);
    final refreshed = clusterMapPoints([points[2], points[0]],
        project: project, unproject: unproject);
    expect(first.every((g) => g.isSingle), isTrue);
    expect(first.map((g) => g.id),
        containsAll(['marker_a', 'marker_b', 'marker_c']));
    expect(refreshed.map((g) => g.id), containsAll(['marker_a', 'marker_c']));
    expect(refreshed.map((g) => g.id), isNot(contains('marker_b')));
    expect(first.firstWhere((g) => g.id == 'marker_a').center,
        points[0].coordinates);
  });

  test('cluster tap zooms up to the shared maximum, then lists members', () {
    expect(clusterTapZoom(11), 13);
    expect(clusterTapZoom(17), kMapMaxZoom);
    expect(clusterTapZoom(kMapMaxZoom - 0.25), isNull);
    expect(clusterTapZoom(kMapMaxZoom), isNull);
  });

  test('search and cached marker IDs follow the refreshed public catalog', () {
    final base = mockStreamers.first.copyWith(
      streamerId: 'visible',
      isVerified: true,
      isTemporarilyHiddenFromMap: false,
      fullNameEn: 'Current Lecturer',
      latitude: 26.3,
      longitude: 50.1,
    );
    final hidden = base.copyWith(
        streamerId: 'hidden',
        fullNameEn: 'Hidden Lecturer',
        isTemporarilyHiddenFromMap: true);
    final unverified = base.copyWith(
        streamerId: 'unverified',
        fullNameEn: 'Unverified Lecturer',
        isVerified: false);
    final first = visibleMapStreamers([base, hidden, unverified]);
    expect(first.map((s) => s.streamerId), ['visible']);
    expect(searchMapStreamers(first, 'lecturer').map((s) => s.streamerId),
        ['visible']);
    expect(searchMapStreamers(first, 'hidden'), isEmpty);
    final refreshed = visibleMapStreamers([hidden, unverified]);
    expect(searchMapStreamers(refreshed, 'lecturer'), isEmpty);
    final cachedIds = {'visible', 'hidden', 'unverified'};
    cachedIds.removeWhere((id) => !refreshed.any((s) => s.streamerId == id));
    expect(cachedIds, isEmpty);
  });

  test('marker-only cold start retains pins until a catalog is available', () {
    final cached = [
      const MapMarkerModel(
        markerId: 'pin_cached',
        streamerId: 'cached',
        displayNameEn: 'Cached venue',
        displayNameAr: 'موقع مخزن',
        venueNameEn: 'Hall',
        venueNameAr: 'قاعة',
        latitude: 26.3,
        longitude: 50.1,
        cityId: 'khobar',
        categoryId: 'cs_tech',
        status: MarkerStatus.offline,
        viewerCount: 0,
        avatarUrl: '',
      ),
    ];
    expect(visibleCachedMapMarkers(cached, currentVisibleIds: null), cached);
    expect(
        visibleCachedMapMarkers(cached, currentVisibleIds: {'cached'}), cached);
    expect(visibleCachedMapMarkers(cached, currentVisibleIds: {}), isEmpty);
  });

  test('padding does not admit adjacent towns or invent a city for a pin', () {
    final original =
        mockStreamers.first.copyWith(latitude: 26.52, longitude: 50.02);
    final adjacent = original.copyWith(cityEn: 'Saihat', cityAr: 'سيهات');
    final unknown = original.copyWith(cityEn: '', cityAr: '');
    expect(visibleMapStreamers([adjacent, unknown]), isEmpty);
    for (final city in kTricityCityViews) {
      final venue = original.copyWith(cityEn: city.nameEn, cityAr: city.nameAr);
      final result = visibleMapStreamers([venue]).single;
      expect(identical(result, venue), isTrue);
      expect(result.latitude, 26.52);
      expect(result.longitude, 50.02);
    }
    expect(adjacent.cityEn, 'Saihat');
    expect(isTricityVenueCity('Al-Khobar'), isTrue);
    expect(isTricityVenueCity('Greater Dammam'), isFalse);
    final ambiguous = original.copyWith(cityEn: 'Greater Dammam', cityAr: '');
    expect(
        visibleCachedMapMarkers([MapMarkerModel.fromStreamer(ambiguous)],
            currentVisibleIds: null),
        isEmpty);
    final arabicOnly = original.copyWith(cityEn: '', cityAr: 'الخبر');
    expect(MapMarkerModel.fromStreamer(arabicOnly).cityId, 'khobar');
  });

  test('legacy exact pins without city metadata survive catalog and cache', () {
    for (final point in [
      const LatLng(26.3050, 50.1450),
      const LatLng(26.2172, 50.1971),
      const LatLng(26.42, 50.09),
    ]) {
      final venue = mockStreamers.first.copyWith(
        cityEn: '',
        cityAr: '',
        latitude: point.latitude,
        longitude: point.longitude,
      );
      expect(visibleMapStreamers([venue]), [venue]);
      final cached = MapMarkerModel.fromStreamer(venue);
      expect(cached.cityId, isEmpty);
      expect(
          visibleCachedMapMarkers([cached], currentVisibleIds: null), [cached]);
      expect(visibleCachedMapMarkers([cached], currentVisibleIds: {}), isEmpty);
      expect(
          visibleMapStreamers([
            venue.copyWith(isVerified: false),
            venue.copyWith(isTemporarilyHiddenFromMap: true),
            venue.copyWith(latitude: 0, longitude: 0),
            venue.copyWith(cityEn: 'Riyadh'),
          ]),
          isEmpty);
      expect(venue.cityEn, isEmpty);
      expect(venue.cityAr, isEmpty);
      final outsideCity = venue.copyWith(cityAr: 'الرياض');
      expect(visibleMapStreamers([outsideCity]), isEmpty);
      expect(
          visibleCachedMapMarkers([MapMarkerModel.fromStreamer(outsideCity)],
              currentVisibleIds: null),
          isEmpty);
    }
  });

  testWidgets('search selection and refresh use the current visible list',
      (tester) async {
    final venue = mockStreamers.first.copyWith(
        streamerId: 'visible',
        fullNameEn: 'Current Lecturer',
        isVerified: true,
        latitude: 26.3,
        longitude: 50.1);
    final picks = <String>[];
    Widget search(List<StreamerModel> streamers) => _localizedWidget(
          TopSpatialSearchBar(
            visibleStreamers: streamers,
            onStreamerSelected: picks.add,
            onCitySelected: (_) {},
          ),
        );
    await tester.pumpWidget(search([venue]));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Current Lecturer');
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await tester.pump();
    expect(picks, ['visible']);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pumpWidget(search([]));
    await tester.pump();
    expect(find.text('No current map results'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  test('three city views stay inside the map domain; legacy ids remain hints',
      () {
    expect(kTricityCityViews.map((v) => v.id), ['khobar', 'dhahran', 'dammam']);
    for (final view in kTricityCityViews) {
      final c = view.view.center;
      expect(isInTricityMapDomain(c.latitude, c.longitude), isTrue,
          reason: view.id);
      expect(view.localizedName('ar'), isNotEmpty);
      expect(kTricityOverviewExtent.contains(c.latitude, c.longitude), isTrue,
          reason: view.id);
    }
    // mapCityId is only a display hint derived from free text.
    expect(mapCityId('Riyadh'), 'riyadh');
    expect(mapCityId('Al Jubail'), 'jubail');
    expect(isInTricityMapDomain(24.7136, 46.6753), isFalse);
  });

  test('native directions target exact coordinates on Android and iOS', () {
    final android =
        nativeVenueDirectionsUri(26.3042, 50.1462, TargetPlatform.android);
    expect(android.host, 'www.google.com');
    expect(android.path, '/maps/dir/');
    expect(android.queryParameters['destination'], '26.3042,50.1462');
    expect(android.queryParameters['dir_action'], 'navigate');
    final ios = nativeVenueDirectionsUri(26.3042, 50.1462, TargetPlatform.iOS);
    expect(ios.host, 'maps.apple.com');
    expect(ios.queryParameters['daddr'], '26.3042,50.1462');
  });

  testWidgets('own marker has accessible name and taps once', (tester) async {
    final streamer = mockStreamers.first.copyWith(isVerified: true);
    var taps = 0;
    await tester.pumpWidget(_localizedWidget(SpatialStreamerMarker(
      marker: MapMarkerModel.fromStreamer(streamer),
      isMine: true,
      onTap: () => taps++,
      onDoubleTap: () {},
    )));
    await tester.pump();
    await tester.tap(find.byType(SpatialStreamerMarker));
    await tester.pump(const Duration(milliseconds: 400));
    expect(taps, 1);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });
}
