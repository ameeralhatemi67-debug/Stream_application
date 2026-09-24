import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/features/map/models/map_models.dart';
import 'package:streamer_app/features/map/presentation/map_cluster_layout.dart';
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
  math.Point<double> project(LatLng p) => math.Point(p.longitude, p.latitude);
  LatLng unproject(math.Point<double> p) => LatLng(p.y, p.x);

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

  test('cluster tap zooms before presenting a member choice', () {
    expect(clusterTapZoom(8), 10);
    expect(clusterTapZoom(16), 17.5);
    expect(clusterTapZoom(17.5), isNull);
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
            onSearchResultSelected: (_, __, ___) {},
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

  test('Saudi presets include owner cities and stay in navigable bounds', () {
    final ids = saudiMapPresets.map((p) => p.regionId).toSet();
    expect(
        ids,
        containsAll([
          'saudi_arabia',
          'eastern_province',
          'khobar',
          'dammam',
          'jubail',
          'hofuf',
          'riyadh',
          'jeddah'
        ]));
    for (final preset in saudiMapPresets) {
      expect(saudiMapBounds.contains(preset.centerCoordinates), isTrue,
          reason: preset.regionId);
      expect(preset.zoomLevelTarget, inInclusiveRange(5, 17.5));
      expect(preset.getLocalizedName('ar'), isNotEmpty);
    }
    expect(saudiMapPresets.first.centerCoordinates.longitude, lessThan(50));
    expect(alSharqiaRegions.first.regionId, 'khobar');
    expect(mapCityId('Riyadh'), 'riyadh');
    expect(mapCityId('Al Jubail'), 'jubail');
    expect(mapCityId('Jeddah'), 'jeddah');
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
