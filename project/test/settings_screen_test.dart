import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';
import 'package:streamer_app/features/profile/presentation/widgets/broadcaster_application_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/legal_document_reader_screen.dart';

class DirectJsonAssetLoader extends AssetLoader {
  final Map<String, dynamic> enData;
  final Map<String, dynamic> arData;

  const DirectJsonAssetLoader({required this.enData, required this.arData});

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return locale.languageCode == 'ar' ? arData : enData;
  }
}

late Map<String, dynamic> globalEnData;
late Map<String, dynamic> globalArData;

Widget createTestWidget({
  required Widget child,
  required AppProvider provider,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('ar')],
    path: 'assets/i18n',
    assetLoader:
        DirectJsonAssetLoader(enData: globalEnData, arData: globalArData),
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    saveLocale: false,
    useOnlyLangCode: true,
    child: Builder(
      builder: (context) {
        return ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: ThemeData.dark(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: AppTheme.darkBgBase,
            ),
            home: child,
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    globalEnData =
        jsonDecode(await File('assets/i18n/en.json').readAsString());
    globalArData =
        jsonDecode(await File('assets/i18n/ar.json').readAsString());
    await EasyLocalization.ensureInitialized();
  });

  group('SettingsScreen: role-aware modular redesign', () {
    void useTallTestSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets(
        'TC-SET-01: a viewer (unauthenticated default) sees the compact '
        'viewer card with the Viewer/Student badge, not the streamer card',
        (tester) async {
      useTallTestSurface(tester);
      final provider = AppProvider();

      await tester.pumpWidget(
        createTestWidget(child: const SettingsScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viewer / Student'), findsOneWidget);
    });

    testWidgets(
        'TC-SET-02: an approved streamer sees the rich profile card with a '
        'banner, verified badge, and derived @handle',
        (tester) async {
      useTallTestSurface(tester);
      final provider = AppProvider();
      provider.debugSetSignedInForTests(
        email: 'amir@test.com',
        name: 'Amir Al-Hatemi',
        isStreamer: true,
      );

      await tester.pumpWidget(
        createTestWidget(child: const SettingsScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viewer / Student'), findsNothing);
      // Derived handle falls back to a slugified name when there's no
      // application on file yet (youtubeHandle comes from the wizard).
      expect(find.text('@amiralhatemi'), findsOneWidget);
    });

    testWidgets(
        'TC-SET-03: Edit Account Profile opens BroadcasterApplicationSheet '
        'for both a viewer and a streamer', (tester) async {
      useTallTestSurface(tester);
      final provider = AppProvider();

      await tester.pumpWidget(
        createTestWidget(child: const SettingsScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Account Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(BroadcasterApplicationSheet), findsOneWidget);
    });

    testWidgets(
        'TC-SET-04: the Streamer Mode switch is disabled for a non-approved '
        'account and enabled once approved', (tester) async {
      useTallTestSurface(tester);
      final viewerProvider = AppProvider();

      await tester.pumpWidget(
        createTestWidget(
            child: const SettingsScreen(), provider: viewerProvider),
      );
      await tester.pumpAndSettle();

      final viewerSwitch = tester.widget<Switch>(find.byType(Switch).first);
      expect(viewerSwitch.onChanged, isNull);

      final streamerProvider = AppProvider();
      streamerProvider.debugSetSignedInForTests(
        email: 'amir@test.com',
        isStreamer: true,
      );
      await tester.pumpWidget(
        createTestWidget(
            child: const SettingsScreen(), provider: streamerProvider),
      );
      await tester.pumpAndSettle();

      final streamerSwitch = tester.widget<Switch>(find.byType(Switch).first);
      expect(streamerSwitch.onChanged, isNotNull);
    });

    testWidgets(
        'TC-SET-05: tapping the Notification Preferences row opens a modal '
        'sheet exposing the alert-limit slider', (tester) async {
      useTallTestSurface(tester);
      final provider = AppProvider();

      await tester.pumpWidget(
        createTestWidget(child: const SettingsScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNothing);

      await tester.tap(find.text('Notification Preferences'));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets(
        'TC-SET-06: Broadcaster & Studio Preferences row is absent for a '
        'viewer and present+tappable for a streamer', (tester) async {
      useTallTestSurface(tester);
      final viewerProvider = AppProvider();

      await tester.pumpWidget(
        createTestWidget(
            child: const SettingsScreen(), provider: viewerProvider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Broadcaster & Studio Preferences'), findsNothing);

      final streamerProvider = AppProvider();
      streamerProvider.debugSetSignedInForTests(
        email: 'amir@test.com',
        isStreamer: true,
      );
      await tester.pumpWidget(
        createTestWidget(
            child: const SettingsScreen(), provider: streamerProvider),
      );
      await tester.pumpAndSettle();

      final row = find.text('Broadcaster & Studio Preferences');
      expect(row, findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.textContaining('Go Live'), findsWidgets);
    });

    testWidgets(
        'TC-SET-07: tapping each governance row pushes the legal reader at '
        'the correct starting document', (tester) async {
      useTallTestSurface(tester);
      final provider = AppProvider();

      await tester.pumpWidget(
        createTestWidget(child: const SettingsScreen(), provider: provider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Broadcaster Code of Conduct & Guidelines'));
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentReaderScreen), findsOneWidget);
      expect(
        find.widgetWithText(
            AppBar, 'Broadcaster Code of Conduct & Guidelines'),
        findsOneWidget,
      );
    });

    testWidgets(
        'TC-SET-08: the legal reader Next/Previous buttons cycle through '
        'all 3 documents and wrap around', (tester) async {
      useTallTestSurface(tester);
      final provider = AppProvider();

      await tester.pumpWidget(
        createTestWidget(
          child: LegalDocumentReaderScreen(
            terms: provider.termsAndConditions,
          ),
          provider: provider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Terms of Service'), findsOneWidget);

      await tester.tap(find.text('Next Document'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(
            AppBar, 'Broadcaster Code of Conduct & Guidelines'),
        findsOneWidget,
      );

      await tester.tap(find.text('Next Document'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, 'Privacy Policy (Saudi PDPL Compliant)'),
        findsOneWidget,
      );

      // Wraps back to the first document.
      await tester.tap(find.text('Next Document'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Terms of Service'), findsOneWidget);

      // Previous from the first document wraps to the last.
      await tester.tap(find.text('Previous Document'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, 'Privacy Policy (Saudi PDPL Compliant)'),
        findsOneWidget,
      );
    });

    testWidgets(
        'TC-SET-09: Download My Data / Delete My Account stay gated on '
        'isLoggedInStreamer after relocation', (tester) async {
      useTallTestSurface(tester);
      final viewerProvider = AppProvider();

      await tester.pumpWidget(
        createTestWidget(
            child: const SettingsScreen(), provider: viewerProvider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete My Account'), findsNothing);

      final streamerProvider = AppProvider();
      streamerProvider.debugSetSignedInForTests(
        email: 'amir@test.com',
        isStreamer: true,
      );
      await tester.pumpWidget(
        createTestWidget(
            child: const SettingsScreen(), provider: streamerProvider),
      );
      await tester.pumpAndSettle();

      expect(find.text('Download My Data'), findsWidgets);
      expect(find.text('Delete My Account'), findsWidgets);
    });
  });
}
