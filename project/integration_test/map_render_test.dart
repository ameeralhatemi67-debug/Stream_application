// Real-engine render check of the bundled three-city map (G0/A08/A12).
//
// Runs the actual SpatialMapScreen with the real MapPackController (bundled
// pack, styles, fonts, isolates) on a device/desktop engine, then saves PNG
// captures and timings. It does not replace the owner's first-use run on a
// phone; it proves the renderer, labels and pack on that platform.
//
//   flutter test integration_test/map_render_test.dart -d windows \
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
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
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

  testWidgets('bundled map renders streets and labels on this platform',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final provider = AppProvider(AdminDatabaseService(null))
      ..debugSetOnlineForTests(false);
    final pack = MapPackController.shared;
    final watch = Stopwatch()..start();
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
              home: const SizedBox(
                  width: 412, height: 860, child: SpatialMapScreen()),
            ),
          ),
        ),
      ),
    ));
    while (!pack.isReady && watch.elapsed < const Duration(seconds: 20)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (pack.status == MapPackStatus.unavailable) break;
    }
    results['pack_status'] = pack.status.name;
    results['pack_problem'] = pack.problem?.name;
    results['pack_open_ms'] = pack.lastOpenDuration?.inMilliseconds;
    results['map_entry_to_ready_ms'] = watch.elapsedMilliseconds;
    expect(pack.isReady, isTrue);

    await settle(tester, 6);
    results['ranges_after_overview'] = pack.servedRanges;
    await capture(tester, 'W01-overview-en');

    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    final zoomBefore = controller.camera.zoom;
    results['overview_zoom'] = zoomBefore;

    // City view via the dropdown path.
    await tester.tap(find.text('All three cities'));
    await settle(tester, 1);
    await tester.tap(find.text('Al Khobar').last);
    await settle(tester, 5);
    await capture(tester, 'W02-khobar-view-en');

    // Deepest permitted zoom over the Al Khobar corniche.
    controller.move(controller.camera.center, 30);
    await settle(tester, 6);
    results['clamped_max_zoom'] = controller.camera.zoom;
    await capture(tester, 'W03-khobar-max-zoom-en');

    // Below the minimum is refused by the policy / constraint.
    controller.move(controller.camera.center, 2);
    await settle(tester, 2);
    results['after_request_zoom_2'] = controller.camera.zoom;

    await tester.tap(find.byTooltip('Show all three cities'));
    await settle(tester, 4);
    // Arabic labels and layout.
    final context = tester.element(find.byType(SpatialMapScreen));
    await EasyLocalization.of(context)!.setLocale(const Locale('ar'));
    await settle(tester, 8);
    await capture(tester, 'W04-overview-ar');
    results['camera_after_locale'] = controller.camera.zoom;

    results['style_warnings'] = pack.styleWarnings;
    if (_outDir.isNotEmpty) {
      File('$_outDir/map-render-results-${Platform.operatingSystem}.json')
          .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(results));
    }
    // ignore: avoid_print
    print('MAP_RENDER_RESULTS ${jsonEncode(results)}');
    expect(results['clamped_max_zoom'], lessThanOrEqualTo(18.0));
    expect(results['after_request_zoom_2'] as double, greaterThan(9.0));
  });
}
