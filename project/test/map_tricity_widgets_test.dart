import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/auth/presentation/steps/apply_step_4_location.dart';
import 'package:streamer_app/features/auth/presentation/widgets/location_picker_modal.dart';
import 'package:streamer_app/features/map/models/map_tricity_domain.dart';
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/map/presentation/venue_directions_launcher.dart';
import 'package:streamer_app/features/map/presentation/widgets/city_selector_dropdown.dart';
import 'package:streamer_app/features/map/services/map_pack_controller.dart';
import 'package:streamer_app/features/map/services/map_offline_store.dart';
import 'package:streamer_app/features/map/presentation/widgets/venue_navigation_sheet.dart';
import 'package:streamer_app/features/map/presentation/widgets/marker_summary_card.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'fixtures/streamer_fixtures.dart';
import 'package:streamer_app/features/map/presentation/widgets/spatial_streamer_marker.dart';

late Map<String, dynamic> enData, arData;

class DirectJsonAssetLoader extends AssetLoader {
  const DirectJsonAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      locale.languageCode == 'ar' ? arData : enData;
}

/// A bundle with no map files: the controller settles on "unavailable"
/// without rendering tiles (real rendering is covered on devices/Chrome).
class _NoPackBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('no $key');
}

/// Serves the real shipped pack files, so the controller verifies and opens
/// the actual bundle (used where the picker needs a ready map).
class _FilePackBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

Future<MapPackController> _readyPack(WidgetTester tester) async {
  final pack = MapPackController(
    bundle: _FilePackBundle(),
    hasher: (bytes) async => sha256.convert(bytes).toString(),
    useWebStore: false,
  );
  await tester.runAsync(pack.ensureOpened);
  expect(pack.isReady, isTrue);
  return pack;
}

MapPackController _unavailablePack() =>
    MapPackController(bundle: _NoPackBundle(), useWebStore: false);

Widget _app(Widget home, AppProvider provider,
        {String lang = 'en', double textScale = 1}) =>
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      startLocale: Locale(lang),
      saveLocale: false,
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: AppTheme.forLocale(context.locale),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: home,
          ),
        ),
      ),
    );

/// A point on the picker map away from the centred pack-status card, which
/// is shown in these tests because no pack files are provided.
Offset _mapPoint(WidgetTester tester) =>
    tester.getTopLeft(find.byType(FlutterMap)) + const Offset(60, 40);

/// Web offline store whose results the test scripts (no browser needed).
class _ScriptedWebStore implements WebOfflineMapStore {
  WebOfflineStatus state = const WebOfflineStatus(WebOfflineState.notPrepared);
  WebOfflineStatus prepareResult =
      const WebOfflineStatus(WebOfflineState.failed, detail: 'incomplete');
  int prepares = 0;

  @override
  Future<WebOfflineStatus> inspect({required String packSha256}) async => state;

  @override
  Future<WebOfflineStatus> prepare({
    required String packSha256,
    required String packAssetKey,
    required List<String> requiredAssetKeys,
    required int packBytes,
    void Function(int done, int total)? onProgress,
  }) async {
    prepares++;
    return state = prepareResult;
  }

  @override
  Future<void> reset() async =>
      state = const WebOfflineStatus(WebOfflineState.notPrepared);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    enData = jsonDecode(File('assets/i18n/en.json').readAsStringSync());
    arData = jsonDecode(File('assets/i18n/ar.json').readAsStringSync());
    await EasyLocalization.ensureInitialized();
  });
  tearDown(() => MapPackController.debugShared = null);

  for (final lang in ['en', 'ar']) {
    for (final width in [320.0, 360.0, 384.0, 412.0]) {
      for (final scale in [1.0, 1.6, 2.0]) {
        for (final type in BroadcastType.values) {
          testWidgets('selected card $lang width=$width text=$scale $type',
              (tester) async {
            final previousError = FlutterError.onError;
            FlutterError.onError = (details) {
              debugPrint(details.toString());
              previousError?.call(details);
            };
            addTearDown(() => FlutterError.onError = previousError);
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final provider = AppProvider(AdminDatabaseService(null))
              ..debugSetOnlineForTests(true)
              ..addStreamerForTests(mockStreamers.first.copyWith(
                fullNameEn: 'Selected Venue',
                fullNameAr: 'الموقع المحدد',
                isCurrentlyLive: type != BroadcastType.offline,
                broadcastType: type,
                activeStreamId: 'abcdefghijk',
                avatarUrl: '',
              ));
            final pack = _unavailablePack();
            await tester.pumpWidget(_app(
                SpatialMapScreen(packController: pack), provider,
                lang: lang, textScale: scale));
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump();
            // Select the real marker callback. Layout/hit tests below exercise
            // the populated card, independent of tile rendering or search.
            tester
                .widget<SpatialStreamerMarker>(
                    find.byType(SpatialStreamerMarker).first)
                .onTap();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump();
            expect(find.byType(MarkerSummaryCard), findsOneWidget);
            final action = find.descendant(
                of: find.byType(MarkerSummaryCard),
                matching: find.byType(ElevatedButton));
            await tester.ensureVisible(action);
            expect(action.hitTestable(), findsOneWidget);
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
            expect(tester.takeException(), isNull);
            // The same selected venue stays usable at overview and close zoom.
            final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
            map.mapController!.move(map.mapController!.camera.center, 12);
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump();
            await tester.ensureVisible(action);
            expect(action.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
            final close = find.descendant(
                of: find.byType(MarkerSummaryCard),
                matching: find.byTooltip('common.close'.tr()));
            await tester.ensureVisible(close);
            expect(tester.getSize(close), const Size(48, 48));
            await tester.tap(close);
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump();
            expect(find.byType(MarkerSummaryCard), findsNothing);
            await tester.pumpWidget(const SizedBox.shrink());
            provider.dispose();
            pack.dispose();
          });
        }
      }
    }
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Spatial map (A13/A14 widget level)', () {
    testWidgets(
        'backend offline and pack unavailable are shown separately, the '
        'credit stays visible, and city search and dropdown agree',
        (tester) async {
      phone(tester);
      final provider = AppProvider(AdminDatabaseService(null))
        ..debugSetOnlineForTests(false);
      final pack = _unavailablePack();
      await tester
          .pumpWidget(_app(SpatialMapScreen(packController: pack), provider));
      await tester.pumpAndSettle();

      expect(pack.status, MapPackStatus.unavailable);
      expect(find.text("The map can't be shown"), findsOneWidget);
      expect(find.textContaining('Offline ·'), findsOneWidget);
      expect(find.text(kOsmCreditFallback), findsOneWidget);
      expect(find.byTooltip('Map details and credits'), findsOneWidget);
      expect(find.byTooltip('Show all three cities'), findsOneWidget);
      expect(find.textContaining('Esri'), findsNothing);

      // Dropdown lists exactly the overview plus the three cities.
      await tester.tap(find.byType(CitySelectorDropdown));
      await tester.pumpAndSettle();
      for (final label in [
        'All three cities',
        'Al Khobar',
        'Dhahran',
        'Dammam'
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Riyadh'), findsNothing);
      await tester.tap(find.text('Dammam').last);
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(CitySelectorDropdown),
              matching: find.text('Dammam')),
          findsOneWidget);

      // Searching a city selects the same city view.
      await tester.enterText(find.byType(TextField), 'dhah');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Dhahran'));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(CitySelectorDropdown),
              matching: find.text('Dhahran')),
          findsOneWidget);

      // Overview returns to all three cities.
      await tester.tap(find.byTooltip('Show all three cities'));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(CitySelectorDropdown),
              matching: find.text('All three cities')),
          findsOneWidget);

      // The map never rotates and stays within the policy zoom range.
      final camera = tester.state<State<FlutterMap>>(find.byType(FlutterMap));
      expect(camera.mounted, isTrue);
      final options =
          tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
      expect(options.interactionOptions.flags & InteractiveFlag.rotate, 0);
      expect(options.maxZoom, kMapMaxZoom);
      expect(options.minZoom, greaterThan(9));
    });

    testWidgets(
        'backend online hides the offline chip; pack state is '
        'independent of it', (tester) async {
      phone(tester);
      final provider = AppProvider(AdminDatabaseService(null))
        ..debugSetOnlineForTests(true);
      final pack = _unavailablePack();
      await tester
          .pumpWidget(_app(SpatialMapScreen(packController: pack), provider));
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline ·'), findsNothing);
      expect(find.text("The map can't be shown"), findsOneWidget);
      expect(find.text(kOsmCreditFallback), findsOneWidget);
    });

    testWidgets('details sheet shows local notices and venue freshness',
        (tester) async {
      phone(tester);
      final provider = AppProvider(AdminDatabaseService(null))
        ..debugSetOnlineForTests(false);
      final pack = _unavailablePack();
      await tester
          .pumpWidget(_app(SpatialMapScreen(packController: pack), provider));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Map details and credits'));
      await tester.pumpAndSettle();
      expect(find.text('Map'), findsWidgets);
      expect(find.text('Venues'), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget);
      expect(find.textContaining('Open Database License'), findsOneWidget);
      expect(find.text('Try again'), findsWidgets);
    });

    testWidgets('Arabic layout mirrors and keeps every control reachable',
        (tester) async {
      phone(tester);
      final provider = AppProvider(AdminDatabaseService(null))
        ..debugSetOnlineForTests(false);
      await tester.pumpWidget(_app(
          SpatialMapScreen(packController: _unavailablePack()), provider,
          lang: 'ar'));
      await tester.pumpAndSettle();
      expect(find.text('المدن الثلاث'), findsOneWidget);
      expect(find.byTooltip('عرض المدن الثلاث'), findsOneWidget);
      expect(find.text(kOsmCreditFallback), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
      'directions that no app can open show a localized message '
      '(A18)', (tester) async {
    phone(tester);
    var opened = true;
    await tester.pumpWidget(_app(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => opened = await openVenueDirections(
                  context, 26.289, 50.217,
                  launcher: (_, __) async => false),
              child: const Text('go'),
            ),
          ),
        ),
        AppProvider(AdminDatabaseService(null))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(opened, isFalse);
    expect(find.text("Couldn't open a maps app or browser on this device."),
        findsOneWidget);
  });

  testWidgets(
      'directions for a venue without a pinned point explain it '
      'instead of opening 0,0', (tester) async {
    phone(tester);
    var launched = false;
    await tester.pumpWidget(_app(
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => openVenueDirections(context, 0, 0,
                  launcher: (_, __) async => launched = true),
              child: const Text('go'),
            ),
          ),
        ),
        AppProvider(AdminDatabaseService(null))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(launched, isFalse);
    expect(find.textContaining('no pinned location'), findsOneWidget);
  });

  group('Venue location picker (A19)', () {
    Future<LocationPickerResult?> openPicker(
        WidgetTester tester, LatLng? initial,
        {String? city}) async {
      LocationPickerResult? result;
      var done = false;
      await tester.pumpWidget(_app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await LocationPickerModal.show(
                        context: context,
                        initialLocation: initial,
                        initialCity: city);
                    done = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          AppProvider(AdminDatabaseService(null))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(done, isFalse);
      return result;
    }

    Finder useButton() =>
        find.widgetWithText(ElevatedButton, 'Use This Location');

    testWidgets(
        'a legacy point outside the map is shown and kept, never '
        'clamped; confirm stays disabled until a new point is chosen',
        (tester) async {
      phone(tester);
      MapPackController.debugShared = _unavailablePack();
      await openPicker(tester, const LatLng(24.7136, 46.6753));
      expect(find.textContaining('24.71360, 46.67530'), findsOneWidget);
      expect(find.textContaining('outside this map'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(useButton()).onPressed, isNull);
      // No invented neighbourhood or address text anywhere.
      expect(find.textContaining('KFUPM'), findsNothing);
      expect(find.textContaining('Al-Faisaliyah'), findsNothing);
      expect(find.textContaining('Corniche'), findsNothing);
    });

    testWidgets('without a visible map no blind pin can be placed',
        (tester) async {
      phone(tester);
      MapPackController.debugShared = _unavailablePack();
      await openPicker(tester, null, city: 'dammam');
      await tester.tapAt(_mapPoint(tester));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('No point chosen yet.'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(useButton()).onPressed, isNull);
      expect(
          find.text('The map must be showing to place a pin'), findsOneWidget);
    });

    testWidgets(
        '"Pin the map centre" places the point under the crosshair '
        '(keyboard and screen-reader path)', (tester) async {
      phone(tester);
      MapPackController.debugShared = await _readyPack(tester);
      await openPicker(tester, null, city: 'dammam');
      await tester.tap(find.text('Pin the centre mark'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.textContaining('Latitude'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(useButton()).onPressed, isNotNull);
      final shown = tester.widget<Text>(find.textContaining('Latitude')).data!;
      final numbers = RegExp(r'\d+\.\d+')
          .allMatches(shown)
          .map((m) => double.parse(m.group(0)!))
          .toList();
      // The centre of the Dammam city view the picker opened on.
      expect(
          cityViewById('dammam')!.view.contains(numbers[0], numbers[1]), isTrue,
          reason: shown);
    });

    testWidgets(
        'tapping the map records the exact point; the result carries '
        'coordinates only', (tester) async {
      phone(tester);
      MapPackController.debugShared = await _readyPack(tester);
      LocationPickerResult? result;
      await tester.pumpWidget(_app(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async => result = await LocationPickerModal.show(
                    context: context, initialCity: 'dammam'),
                child: const Text('open'),
              ),
            ),
          ),
          AppProvider(AdminDatabaseService(null))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('No point chosen yet.'), findsOneWidget);
      await tester.tapAt(_mapPoint(tester));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.textContaining('Latitude'), findsOneWidget);
      await tester.tap(useButton());
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      final p = result!.coordinates;
      expect(isInTricityMapDomain(p.latitude, p.longitude), isTrue);
      // Framed on the Dammam view: the tapped point is near it.
      expect(
          p.latitude, greaterThan(cityViewById('dammam')!.view.south - 0.05));
    });

    testWidgets(
        'step 4 main venue: pin changes only the point; typed venue '
        'text and chosen city are kept; cancel keeps the old point',
        (tester) async {
      phone(tester);
      MapPackController.debugShared = await _readyPack(tester);
      final venue = TextEditingController(text: 'My own hall, King Fahd Rd');
      final phoneCtrl = TextEditingController();
      LatLng? picked;
      var cityChanges = 0;
      await tester.pumpWidget(_app(
          Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ApplyStep4Location(
                selectedCity: 'riyadh',
                venueController: venue,
                phoneController: phoneCtrl,
                preferredContact: 'whatsapp',
                selectedCoordinates: picked,
                onCityChanged: (_) => cityChanges++,
                onContactPrefChanged: (_) {},
                onCoordinatesSelected: (c) => setState(() => picked = c),
                onAddBranch: (_) {},
                onRemoveBranch: (_) {},
              ),
            ),
          ),
          AppProvider(AdminDatabaseService(null))));
      await tester.pumpAndSettle();
      expect(find.text('No point chosen yet.'), findsOneWidget);

      // Cancel: nothing changes.
      await tester.tap(find.byIcon(Icons.pin_drop_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(picked, isNull);

      // Pin and use.
      await tester.tap(find.byIcon(Icons.pin_drop_rounded));
      await tester.pumpAndSettle();
      await tester.tapAt(_mapPoint(tester));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.tap(useButton());
      await tester.pumpAndSettle();
      expect(picked, isNotNull);
      expect(venue.text, 'My own hall, King Fahd Rd');
      expect(cityChanges, 0);
      expect(find.textContaining('Pinned point:'), findsOneWidget);
    });

    testWidgets(
        'additional branch: no invented coordinate when not pinned; '
        'the pinned point is kept when pinned', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      MapPackController.debugShared = await _readyPack(tester);
      final branches = <OrgBranchVenue>[];
      await tester.pumpWidget(_app(
          Scaffold(
            body: ApplyStep4Location(
              selectedCity: 'khobar',
              venueController: TextEditingController(text: 'HQ'),
              phoneController: TextEditingController(),
              preferredContact: 'whatsapp',
              isOrganization: true,
              onCityChanged: (_) {},
              onContactPrefChanged: (_) {},
              onCoordinatesSelected: (_) {},
              onAddBranch: branches.add,
              onRemoveBranch: (_) {},
            ),
          ),
          AppProvider(AdminDatabaseService(null))));
      await tester.pumpAndSettle();

      Future<void> addBranch({required bool pin}) async {
        await tester
            .tap(find.widgetWithText(ElevatedButton, 'Add Branch').first);
        await tester.pumpAndSettle();
        final fields = find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField));
        await tester.enterText(fields.at(0), 'North campus');
        await tester.enterText(fields.at(1), 'Typed address');
        if (pin) {
          await tester.tap(find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byIcon(Icons.pin_drop_rounded)));
          await tester.pumpAndSettle();
          await tester.tapAt(_mapPoint(tester));
          await tester.pumpAndSettle(const Duration(milliseconds: 400));
          await tester.tap(useButton());
          await tester.pumpAndSettle();
          expect(
              find.descendant(
                  of: find.byType(AlertDialog),
                  matching: find.textContaining('Pinned point:')),
              findsOneWidget);
        }
        await tester.tap(find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(ElevatedButton, 'Add Branch')));
        await tester.pumpAndSettle();
      }

      await addBranch(pin: false);
      expect(branches.single.coordinates, isNull);
      expect(branches.single.address, 'Typed address');
      await addBranch(pin: true);
      final pinned = branches.last.coordinates!;
      expect(isInTricityMapDomain(pinned.latitude, pinned.longitude), isTrue);
      expect(branches.last.address, 'Typed address');
    });
  });

  group('Round 2 repairs', () {
    testWidgets('a pinned venue has directions but no invented user distance',
        (tester) async {
      phone(tester);
      final provider = AppProvider(AdminDatabaseService(null));
      await tester.pumpWidget(_app(
          Scaffold(body: VenueNavigationSheet(streamer: mockStreamers.first)),
          provider));
      await tester.pumpAndSettle();
      expect(find.text('Estimated Distance'), findsNothing);
      expect(
          find.text('Open External Map (Google / Apple Maps)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'an unpinned (0,0) venue shows no distance and no directions, only '
        'the no-location message', (tester) async {
      phone(tester);
      final provider = AppProvider(AdminDatabaseService(null));
      const unpinned = StreamerModel(
        streamerId: 'unpinned_1',
        fullNameEn: 'Dr. No Pin',
        fullNameAr: 'د. بلا موقع',
        titleEn: 'Professor',
        titleAr: 'أستاذ',
        organizationEn: 'KFUPM',
        organizationAr: 'جامعة الملك فهد',
        cityEn: 'Al Khobar',
        cityAr: 'الخبر',
        venueNameEn: 'Hall',
        venueNameAr: 'قاعة',
        latitude: 0,
        longitude: 0,
        isCurrentlyLive: false,
        activeViewerCount: 0,
        avatarUrl: '',
        bannerUrl: '',
        bioEn: '',
        bioAr: '',
        followerCount: 0,
        isVerified: true,
        categoryId: 'cs_tech',
      );
      await tester.pumpWidget(_app(
          const Scaffold(body: VenueNavigationSheet(streamer: unpinned)),
          provider));
      await tester.pumpAndSettle();
      expect(
          find.text("This venue has no pinned location yet, so directions "
              "aren't available."),
          findsOneWidget);
      expect(find.text('Estimated Distance'), findsNothing);
      expect(
          find.text('Open External Map (Google / Apple Maps)'), findsNothing);
    });

    testWidgets(
        'web prompt: Save keeps the prompt when saving fails and hides it '
        'once the copy is ready; details then say it is saved', (tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({});
      final provider = AppProvider(AdminDatabaseService(null))
        ..debugSetOnlineForTests(false);
      final store = _ScriptedWebStore();
      final pack = MapPackController(
        bundle: _FilePackBundle(),
        hasher: (bytes) async => sha256.convert(bytes).toString(),
        webStore: store,
      );
      await tester.runAsync(pack.ensureOpened);
      expect(pack.isReady, isTrue);
      await tester
          .pumpWidget(_app(SpatialMapScreen(packController: pack), provider));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      const prompt = 'Use this map without internet? Save it once in this '
          'browser.';
      expect(find.text(prompt), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(store.prepares, 1);
      expect(pack.webOffline?.state, WebOfflineState.failed);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('map_web_offline_hint_dismissed_v1'), isNull,
          reason: 'a failed save must not dismiss the prompt for good');

      store.prepareResult = const WebOfflineStatus(WebOfflineState.ready);
      await tester.runAsync(pack.prepareWebOffline);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(pack.webOffline?.state, WebOfflineState.ready);
      expect(find.text(prompt), findsNothing);
      expect(find.textContaining('are saved in this browser'), findsOneWidget);
    });
  });
}
