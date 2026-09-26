// Real-engine render check of the venue location picker (A19, round-1 D3)
// and the "no pinned location" directions message (round-1 D2).
//
// Runs the actual LocationPickerModal on the real MapPackController (bundled
// pack, styles and platform fonts) and saves PNG captures. It proves the
// crosshair, the keyboard/screen-reader "Pin the map centre" action and the
// Arabic layout on this platform; it does not replace a TalkBack run on a
// phone.
//
//   flutter test integration_test/picker_render_test.dart -d windows \
//     --dart-define=MAP_RENDER_OUT=<absolute output dir>
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/auth/presentation/widgets/location_picker_modal.dart';
import 'package:streamer_app/features/map/models/map_tricity_domain.dart';
import 'package:streamer_app/features/map/presentation/venue_directions_launcher.dart';
import 'package:streamer_app/features/map/services/map_pack_controller.dart';

const _outDir = String.fromEnvironment('MAP_RENDER_OUT');

class _JsonLoader extends AssetLoader {
  const _JsonLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(await rootBundle.loadString('$path/${locale.languageCode}.json'))
          as Map<String, dynamic>;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final boundaryKey = GlobalKey();
  final results = <String, Object?>{};

  Future<void> settle(WidgetTester tester, [int seconds = 4]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (_outDir.isEmpty) return;
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  testWidgets('picker crosshair, centre pin and no-location directions',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final provider = AppProvider(AdminDatabaseService(null))
      ..debugSetOnlineForTests(false);
    final pack = MapPackController.shared;
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/i18n',
        assetLoader: const _JsonLoader(),
        startLocale: const Locale('en'),
        saveLocale: false,
        child: ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: Builder(
            builder: (context) => MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: AppTheme.forLocale(context.locale),
              home: SizedBox(
                width: 412,
                height: 860,
                child: Scaffold(
                  backgroundColor: Colors.black54,
                  body: Builder(
                    builder: (context) => Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: TextButton(
                              key: const Key('directions-no-point'),
                              onPressed: () => openVenueDirections(context, 0, 0,
                                  launcher: (_, __) async => true),
                              child: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        const LocationPickerModal(initialCityId: 'khobar'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    final watch = Stopwatch()..start();
    while (!pack.isReady && watch.elapsed < const Duration(seconds: 20)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (pack.status == MapPackStatus.unavailable) break;
    }
    results['pack_status'] = pack.status.name;
    expect(pack.isReady, isTrue);
    await settle(tester, 6);
    await capture(tester, 'P01-picker-crosshair-en');
    results['no_point_text_shown'] =
        find.text('No point chosen yet. Tap the map.').evaluate().isNotEmpty;

    final controller =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    final centre = controller.camera.center;
    await tester.tap(find.text('Pin the map centre (+)'));
    await settle(tester, 2);
    await capture(tester, 'P02-picker-centre-pinned-en');
    final expected = 'Latitude ${centre.latitude.toStringAsFixed(5)}, '
        'Longitude ${centre.longitude.toStringAsFixed(5)}';
    results['centre'] = [centre.latitude, centre.longitude];
    results['centre_in_domain'] =
        isInTricityMapDomain(centre.latitude, centre.longitude);
    results['pinned_text_matches_centre'] =
        find.text(expected).evaluate().isNotEmpty;

    final context = tester.element(find.byType(LocationPickerModal));
    await EasyLocalization.of(context)!.setLocale(const Locale('ar'));
    await settle(tester, 8);
    await capture(tester, 'P03-picker-centre-pinned-ar');

    await EasyLocalization.of(context)!.setLocale(const Locale('en'));
    await settle(tester, 4);
    await tester.tap(find.byKey(const Key('directions-no-point')),
        warnIfMissed: false);
    await settle(tester, 2);
    results['no_location_message_shown'] = find
        .text('This venue has no pinned location yet, so directions '
            "aren't available.")
        .evaluate()
        .isNotEmpty;
    await capture(tester, 'P04-directions-no-pinned-location-en');

    if (_outDir.isNotEmpty) {
      File('$_outDir/picker-render-results-${Platform.operatingSystem}.json')
          .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(results));
    }
    // ignore: avoid_print
    print('PICKER_RENDER_RESULTS ${jsonEncode(results)}');
    expect(results['pinned_text_matches_centre'], isTrue);
    expect(results['centre_in_domain'], isTrue);
    expect(results['no_location_message_shown'], isTrue);
  });
}
