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
import 'package:streamer_app/features/organization/models/org_speaker_model.dart';
import 'package:streamer_app/features/profile/models/vod_models.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_multi_speaker_overlay.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_audio_stage_multi_speaker.dart';

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
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    globalEnData = jsonDecode(await File('assets/i18n/en.json').readAsString());
    globalArData = jsonDecode(await File('assets/i18n/ar.json').readAsString());
    await EasyLocalization.ensureInitialized();
  });

  group('Organization Feature Phase 3: Live Multi-Speaker Dynamics Tests', () {
    testWidgets('TC-LIVE-SPK-01: Multi-speaker video overlay renders avatars for active instructors', (tester) async {
      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      final speakers = provider.getOrganizationSpeakers('org_dalilk_04');

      await pumpTestApp(
        tester,
        Scaffold(
          body: Center(
            child: LiveMultiSpeakerOverlay(
              speakers: speakers,
              orgName: 'Dalilk 4 IELTS',
            ),
          ),
        ),
        provider,
      );

      // Verify all 3 avatars exist in overlay
      expect(find.byType(LiveMultiSpeakerOverlay), findsOneWidget);
      expect(find.byType(Tooltip), findsNWidgets(3));
    });

    testWidgets('TC-LIVE-SPK-02: Overlay supports horizontal scrolling when > 5 speakers', (tester) async {
      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);

      // Create a list of 7 mock speakers
      final sevenSpeakers = List<OrgSpeakerModel>.generate(
        7,
        (i) => OrgSpeakerModel(
          speakerId: 'spk_$i',
          nameEn: 'Instructor $i',
          nameAr: 'مدرب $i',
          roleOrTitleEn: 'Specialist $i',
          roleOrTitleAr: 'أخصائي $i',
          avatarUrl: 'assets/images/Dalilak/profile1.jpg',
          bioEn: 'Bio $i',
          bioAr: 'نبذة $i',
        ),
      );

      await pumpTestApp(
        tester,
        Scaffold(
          body: Center(
            child: LiveMultiSpeakerOverlay(
              speakers: sevenSpeakers,
              orgName: 'Dalilk 4 IELTS',
            ),
          ),
        ),
        provider,
      );

      // Should render as a scrollable horizontal ListView
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('TC-LIVE-SPK-03: Tapping an avatar in LiveMultiSpeakerOverlay triggers callback', (tester) async {
      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      final speakers = provider.getOrganizationSpeakers('org_dalilk_04');

      OrgSpeakerModel? tappedSpeaker;

      await pumpTestApp(
        tester,
        Scaffold(
          body: Center(
            child: LiveMultiSpeakerOverlay(
              speakers: speakers,
              orgName: 'Dalilk 4 IELTS',
              onSpeakerTap: (spk) {
                tappedSpeaker = spk;
              },
            ),
          ),
        ),
        provider,
      );

      // Tap first avatar (Abdulrahman Hejazi)
      final firstAvatar = find.byType(GestureDetector).first;
      await tester.tap(firstAvatar);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tappedSpeaker, isNotNull);
      expect(tappedSpeaker!.nameEn, equals('Abdulrahman Hejazi'));
    });

    testWidgets('TC-LIVE-SPK-04: LiveAudioStageMultiSpeaker renders kinetic multi-speaker roster', (tester) async {
      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      final streamer = provider.getStreamerById('org_dalilk_04')!;

      await pumpTestApp(
        tester,
        Scaffold(
          body: LiveAudioStageMultiSpeaker(
            streamer: streamer,
            langCode: 'en',
            viewerCount: 840,
            speakers: streamer.affiliatedSpeakers,
          ),
        ),
        provider,
      );

      // Verify all 3 speaker names rendered
      expect(find.text('Abdulrahman Hejazi'), findsAtLeastNWidgets(1));
      expect(find.text('Dr. Sarah Al-Dosari'), findsOneWidget);
      expect(find.text('Alex Thompson'), findsOneWidget);

      // Verify speaking status bar
      expect(find.text('Speaking Now'), findsOneWidget);
      expect(find.textContaining('840'), findsOneWidget);
    });

    testWidgets('TC-LIVE-SPK-05: Tapping speaker in LiveAudioStageMultiSpeaker triggers inspection', (tester) async {
      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      final streamer = provider.getStreamerById('org_dalilk_04')!;

      OrgSpeakerModel? inspectedSpeaker;

      await pumpTestApp(
        tester,
        Scaffold(
          body: LiveAudioStageMultiSpeaker(
            streamer: streamer,
            langCode: 'en',
            viewerCount: 840,
            speakers: streamer.affiliatedSpeakers,
            onSpeakerTap: (spk) {
              inspectedSpeaker = spk;
            },
          ),
        ),
        provider,
      );

      // Tap on Dr. Sarah Al-Dosari
      final sarahText = find.text('Dr. Sarah Al-Dosari');
      expect(sarahText, findsOneWidget);
      await tester.tap(sarahText);
      await tester.pump(const Duration(milliseconds: 100));

      expect(inspectedSpeaker, isNotNull);
      expect(inspectedSpeaker!.speakerId, equals('spk_sarah'));
    });

    testWidgets('TC-LIVE-SPK-06: Integrated video viewport stack correctly renders LiveMultiSpeakerOverlay for organizations', (tester) async {
      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      final streamer = provider.getStreamerById('org_dalilk_04')!;

      await pumpTestApp(
        tester,
        Scaffold(
          body: Stack(
            children: [
              Container(color: Colors.black),
              Positioned(
                top: 44,
                left: 12,
                child: LiveMultiSpeakerOverlay(
                  speakers: streamer.affiliatedSpeakers,
                  orgName: streamer.getLocalizedName('en'),
                  allVods: MockVodArchivePool.sampleVods,
                ),
              ),
            ],
          ),
        ),
        provider,
      );

      expect(find.byType(LiveMultiSpeakerOverlay), findsOneWidget);
      expect(find.byType(Tooltip), findsNWidgets(3));
    });
  });
}
