import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/profile/presentation/broadcaster_profile_screen.dart';
import 'package:streamer_app/features/profile/presentation/widgets/org_branches_modal_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/org_speaker_inspection_sheet.dart';

import 'fixtures/streamer_fixtures.dart';

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
    assetLoader: DirectJsonAssetLoader(
      enData: globalEnData,
      arData: globalArData,
    ),
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
              cardColor: AppTheme.darkSurface1,
            ),
            home: child,
          ),
        );
      },
    ),
  );
}

Future<void> pumpTestApp(WidgetTester tester, Widget child, AppProvider provider) async {
  await tester.pumpWidget(createTestWidget(child: child, provider: provider));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    globalEnData = jsonDecode(await File('assets/i18n/en.json').readAsString());
    globalArData = jsonDecode(await File('assets/i18n/ar.json').readAsString());
    await EasyLocalization.ensureInitialized();
  });

  group('Organization Feature Phase 2: Profile Screen & Speaker Filter Tests', () {
    testWidgets('TC-ORG-UI-01: Organization Profile renders Org badge & branches button', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      seedStreamerFixtures(provider);
      await pumpTestApp(
        tester,
        const BroadcasterProfileScreen(streamerId: 'org_dalilk_04'),
        provider,
      );

      // Verify Organization name is rendered
      expect(find.textContaining('Dalilk 4 IELTS'), findsWidgets);

      // Verify Campus Branches button is rendered (3 branches)
      expect(find.byIcon(Icons.location_city_rounded), findsWidgets);
    });

    testWidgets('TC-ORG-UI-02: Header card renders top-right action buttons and featured channels', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      seedStreamerFixtures(provider);
      await pumpTestApp(
        tester,
        const BroadcasterProfileScreen(streamerId: 'org_dalilk_04'),
        provider,
      );

      // Check for Follow & Set Reminder buttons
      expect(find.text('Follow Channel'), findsOneWidget);
      expect(find.text('Set Reminder'), findsOneWidget);

      // Check Featured Channels
      expect(find.text('Featured Channels'), findsOneWidget);
      expect(find.text('@dalilk4ielts'), findsOneWidget);
      expect(find.text('@dalilk4english'), findsOneWidget);
      expect(find.text('@dalilk4english_podcast'), findsOneWidget);
    });

    testWidgets('TC-ORG-UI-03: Tapping a Featured Channel card filters VODs and Playlists', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      seedStreamerFixtures(provider);
      await pumpTestApp(
        tester,
        const BroadcasterProfileScreen(streamerId: 'org_dalilk_04'),
        provider,
      );

      // Tap on Dr. Sarah Al-Dosari channel card (@dalilk4english)
      final sarahCard = find.text('@dalilk4english');
      expect(sarahCard, findsOneWidget);
      await tester.tap(sarahCard);
      await tester.pumpAndSettle();

      // Verify filtered VOD grid contains Sarah's lecture
      expect(find.textContaining('IELTS Speaking Part 2 & 3'), findsOneWidget);
    });

    testWidgets('TC-ORG-UI-04: OrgBranchesModalSheet renders all 3 campus locations', (tester) async {
      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      seedStreamerFixtures(provider);
      final venues = provider.getOrganizationVenues('org_dalilk_04');

      await pumpTestApp(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => OrgBranchesModalSheet.show(
              ctx,
              orgName: 'Dalilk 4 IELTS',
              venues: venues,
            ),
            child: const Text('Open Branches'),
          ),
        ),
        provider,
      );

      await tester.tap(find.text('Open Branches'));
      await tester.pumpAndSettle();

      // Verify all 3 branches rendered in bottom sheet
      expect(find.text('Khobar Academic Campus (Main HQ)'), findsOneWidget);
      expect(find.text('Dhahran Tech Innovation Hall'), findsOneWidget);
      expect(find.text('Dammam Executive Training Suite'), findsOneWidget);

      // Verify seating counts
      expect(find.textContaining('350'), findsOneWidget);
      expect(find.textContaining('150'), findsOneWidget);
      expect(find.textContaining('100'), findsOneWidget);
    });

    testWidgets('TC-ORG-UI-05: OrgSpeakerInspectionSheet displays instructor details & bio', (tester) async {
      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      seedStreamerFixtures(provider);
      final speakers = provider.getOrganizationSpeakers('org_dalilk_04');
      final speaker = speakers.first; // Abdulrahman Hejazi

      await pumpTestApp(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => OrgSpeakerInspectionSheet.show(
              ctx,
              speaker: speaker,
              orgName: 'Dalilk 4 IELTS',
              speakerVods: const [],
            ),
            child: const Text('Open Speaker Details'),
          ),
        ),
        provider,
      );

      await tester.tap(find.text('Open Speaker Details'));
      await tester.pumpAndSettle();

      // Verify speaker details rendered
      expect(find.text('Abdulrahman Hejazi'), findsOneWidget);
      expect(find.text('Founder & Lead IELTS Strategist'), findsOneWidget);
      expect(find.textContaining('over 10 years of experience'), findsOneWidget);
    });
  });
}
