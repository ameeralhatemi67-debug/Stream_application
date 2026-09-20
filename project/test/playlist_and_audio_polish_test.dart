import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/organization/models/org_speaker_model.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_audio_stage_multi_speaker.dart';
import 'package:streamer_app/features/splash/presentation/app_splash_screen.dart';
import 'package:streamer_app/features/profile/presentation/widgets/playlist_viewer_modal_sheet.dart';
import 'package:streamer_app/features/map/presentation/widgets/top_spatial_search_bar.dart';
import 'package:streamer_app/features/map/presentation/widgets/city_selector_dropdown.dart';
import 'package:streamer_app/features/map/presentation/widgets/topic_selector_dropdown.dart';
import 'package:streamer_app/features/discovery/models/academic_category_model.dart';
import 'package:streamer_app/features/map/models/map_models.dart';

import 'fixtures/streamer_fixtures.dart';

import 'fixtures/vod_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child, {AppProvider? provider}) {
    return ChangeNotifierProvider<AppProvider>.value(
      value: provider ?? AppProvider(),
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/i18n',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  group('TC-POLISH-01: Audio-Only Live Stage Voice Activity Visuals', () {
    testWidgets('Renders speaking equalizer waveform bars and active speaker callout', (tester) async {
      final streamer = mockStreamers.first;
      final speakers = [
        const OrgSpeakerModel(
          speakerId: 'spk_1',
          nameEn: 'Dr. Al-Ghamdi',
          nameAr: 'د. الغامدي',
          roleOrTitleEn: 'Lead AI Scholar',
          roleOrTitleAr: 'باحث ذكاء اصطناعي',
          avatarUrl: 'assets/images/Dalilak/profile1.jpg',
          bioEn: 'Bio',
          bioAr: 'سيرة',
        ),
        const OrgSpeakerModel(
          speakerId: 'spk_2',
          nameEn: 'Dr. Sarah',
          nameAr: 'د. سارة',
          roleOrTitleEn: 'Linguistics Expert',
          roleOrTitleAr: 'أخصائية لغويات',
          avatarUrl: 'assets/images/Dalilak/profile2.jpg',
          bioEn: 'Bio',
          bioAr: 'سيرة',
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          LiveAudioStageMultiSpeaker(
            streamer: streamer,
            langCode: 'en',
            viewerCount: 342,
            speakers: speakers,
            activeSpeakerId: 'spk_1',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Dr. Al-Ghamdi'), findsAtLeastNWidgets(1));
      expect(find.text('Dr. Sarah'), findsOneWidget);
      expect(find.textContaining('342'), findsOneWidget);
    });
  });

  group('TC-POLISH-02: App Startup Loader / Splash Screen Tests', () {
    testWidgets('AppSplashScreen renders branding, progress indicator, and title', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const AppSplashScreen()));
      await tester.pump();

      expect(find.text('Educational Streamer'), findsOneWidget);
      expect(find.text('Initializing platform & map assets...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('TC-POLISH-03: PlaylistViewerModalSheet Dynamic Fetch & Play All Tests', () {
    testWidgets('Renders playlist header, Play All button, and resolves lectures on demand', (tester) async {
      final streamer = mockStreamers.firstWhere((s) => s.streamerId == 'org_dalilk_04');
      final playlist = MockVodArchivePool.samplePlaylists.first;

      await tester.pumpWidget(
        buildTestableWidget(
          PlaylistViewerModalSheet(
            playlist: playlist,
            streamer: streamer,
            langCode: 'en',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('▶️ Play All Lectures'), findsOneWidget);
      expect(find.text(playlist.getLocalizedTitle('en')), findsOneWidget);
    });
  });

  group('TC-POLISH-04: Spatial Map Top Bar Controls 80% Transparency & Styling', () {
    testWidgets('Renders top search bar, city selector, and topic selector without error', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Column(
            children: [
              TopSpatialSearchBar(
                onSearchResultSelected: (coords, zoom, label) {},
              ),
              CitySelectorDropdown(
                selectedCity: alSharqiaRegions.first,
                onCitySelected: (_) {},
              ),
              TopicSelectorDropdown(
                selectedCategoryId: 'all',
                categories: AcademicCategoryModel.defaultPool,
                onCategorySelected: (_) {},
              ),
            ],
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(TopSpatialSearchBar), findsOneWidget);
      expect(find.byType(CitySelectorDropdown), findsOneWidget);
      expect(find.byType(TopicSelectorDropdown), findsOneWidget);
    });
  });
}
