import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/auth/presentation/viewer_setup_screen.dart';
import 'package:streamer_app/features/auth/presentation/role_select_screen.dart';
import 'package:streamer_app/features/auth/presentation/application_pending_screen.dart';
import 'package:streamer_app/features/auth/presentation/streamer_apply_screen.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';
import 'package:streamer_app/features/admin/presentation/admin_hub_screen.dart';

class DirectJsonAssetLoader extends AssetLoader {
  final Map<String, dynamic> data;
  const DirectJsonAssetLoader(this.data);
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data[locale.languageCode];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalogs = <String,dynamic>{};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for(final lang in ['en','ar']) {
      catalogs[lang] = jsonDecode(File('assets/i18n/$lang.json').readAsStringSync());
    }
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
    for (final entry in {
      'IBM Plex Sans': ['assets/fonts/IBMPlexSans-Variable.ttf'],
      'IBM Plex Sans Arabic': ['assets/fonts/IBMPlexSansArabic-400.ttf', 'assets/fonts/IBMPlexSansArabic-700.ttf'],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) { loader.addFont(rootBundle.load(path)); }
      await loader.load();
    }
  });
  const sizes = [Size(320,568), Size(360,640), Size(412,915), Size(600,960), Size(800,1280), Size(1280,800), Size(568,320)];
  final screens = <String, Widget Function()>{
    'welcome': () => const WelcomeScreen(),
    'viewer setup': () => const ViewerSetupScreen(),
    'role select': () => const RoleSelectScreen(),
    'application pending': () => const ApplicationPendingScreen(),
    'application identity': () => const StreamerApplyScreen(),
    'empty feed': () => const DiscoveryFeedScreen(),
    'viewer settings': () => const SettingsScreen(),
    'admin access denied': () => const AdminHubScreen(),
  };
  for(final entry in screens.entries) {
    for(final lang in ['en','ar']) {
      testWidgets('${entry.key} $lang at all sizes and text scales', (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for(final size in sizes) {
          for(final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = size;
            final provider = AppProvider();
            final previewKey = GlobalKey();
            final details = <String>[];
            final previousHandler = FlutterError.onError;
            FlutterError.onError = (error) {
              details.add(error.toString());
              previousHandler?.call(error);
            };
            await tester.pumpWidget(EasyLocalization(
              key: UniqueKey(), supportedLocales: const [Locale('en'), Locale('ar')],
              path:'assets/i18n', assetLoader: DirectJsonAssetLoader(catalogs),
              startLocale: Locale(lang), saveLocale:false,
              child: Builder(builder:(context) => ChangeNotifierProvider.value(value:provider,
                child: MaterialApp(locale:context.locale,
                  supportedLocales:context.supportedLocales,
                  localizationsDelegates:context.localizationDelegates,
                  theme:AppTheme.forLocale(Locale(lang)),
                  builder:(context,child)=>RepaintBoundary(key:previewKey, child:MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(scale)),child:child!)),
                  home:entry.value()),
              )),
            ));
            await tester.pump(const Duration(milliseconds:200));
            final errors=<Object>[];
            Object? error;
            while((error=tester.takeException()) != null) { errors.add(error!); }
            FlutterError.onError = previousHandler;
            if (Platform.environment['UPDATE_DESIGN_PREVIEWS'] == '1' && size == const Size(360,640) && scale == 1.0 && errors.isEmpty) {
              await tester.runAsync(() async {
                final boundary = previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
                final image = await boundary.toImage();
                final bytes = await image.toByteData(format:ui.ImageByteFormat.png);
                final directory = Directory('../brief/assets/scheme_a_evidence')..createSync(recursive:true);
                File('${directory.path}/${entry.key.replaceAll(" ", "_")}_$lang.png').writeAsBytesSync(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            provider.dispose();
            expect(errors, isEmpty, reason:'${entry.key} $lang $size scale=$scale\n${details.join("\n")}');
          }
        }
      });
    }
  }
}
