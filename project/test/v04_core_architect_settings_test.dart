import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/map/models/map_models.dart';

void main() {
  group('Version 0.4 Core Architect Settings & State Unit Tests', () {
    late AppProvider provider;

    setUp(() {
      provider = AppProvider();
    });

    test('TC-V04-SET-01: Streaming Quality Preference State Management', () {
      expect(provider.selectedStreamingQuality, equals('Auto (1080p)'));

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.setSelectedStreamingQuality('High (720p)');
      expect(provider.selectedStreamingQuality, equals('High (720p)'));
      expect(notified, isTrue);
    });

    test('TC-V04-SET-02: Pitch Director Mode Toggle & Active State Trigger',
        () {
      // Pitch Director mode marks the caller's OWN channel live (P1.6), so
      // the test account owns prof_alghamdi_01 through its application.
      provider.debugSetSignedInForTests(
        email: 'owner@example.com',
        isStreamer: true,
        ownedStreamerId: 'prof_alghamdi_01',
      );
      expect(provider.isPitchDirectorModeEnabled, isFalse);

      provider.togglePitchDirectorMode();
      expect(provider.isPitchDirectorModeEnabled, isTrue);

      provider.togglePitchDirectorMode();
      expect(provider.isPitchDirectorModeEnabled, isFalse);

      provider.activatePitchDirectorMode();
      expect(provider.isPitchDirectorModeEnabled, isTrue);
      expect(provider.activeStreamId, equals('stream_live_992'));

      final drAbdullah = provider.getStreamerById('prof_alghamdi_01');
      expect(drAbdullah, isNotNull);
      expect(drAbdullah!.isCurrentlyLive, isTrue);
      // activeViewerCount starts at 0 and is updated asynchronously by the
      // live viewer polling loop (YouTube Data API concurrentViewers).
      expect(drAbdullah.activeViewerCount, greaterThanOrEqualTo(0));
    });

    test('TC-V04-SET-03: Local RTMP Laptop IP Update & Stream URL Generation',
        () {
      expect(provider.rtmpLaptopIp, equals('192.168.1.100'));
      expect(provider.rtmpStreamUrl,
          equals('http://192.168.1.100:8888/live/demo/'));

      provider.updateRtmpLaptopIp('10.0.0.55');
      expect(provider.rtmpLaptopIp, equals('10.0.0.55'));
      expect(
          provider.rtmpStreamUrl, equals('http://10.0.0.55:8888/live/demo/'));
    });

    test(
        'TC-V04-SET-04: Settings Localization Keys Symmetry in en.json and ar.json',
        () async {
      final enFile = File('assets/i18n/en.json');
      final arFile = File('assets/i18n/ar.json');

      expect(enFile.existsSync(), isTrue);
      expect(arFile.existsSync(), isTrue);

      final Map<String, dynamic> enJson =
          json.decode(await enFile.readAsString());
      final Map<String, dynamic> arJson =
          json.decode(await arFile.readAsString());

      expect(enJson.containsKey('nav'), isTrue);
      expect(arJson.containsKey('nav'), isTrue);

      final Map<String, dynamic> enNav = enJson['nav'];
      final Map<String, dynamic> arNav = arJson['nav'];

      expect(enNav.containsKey('settings'), isTrue);
      expect(arNav.containsKey('settings'), isTrue);
      expect(enNav.keys.toSet(), equals(arNav.keys.toSet()));
    });

    test('TC-V04-SET-05: Streamer CRUD and Protected Original 5 Verification',
        () async {
      expect(provider.streamers.length, equals(5));
      expect(provider.isProtectedStreamer('prof_alghamdi_01'), isTrue);
      expect(provider.isProtectedStreamer('prof_otaibi_02'), isTrue);

      // Cannot delete original protected streamers
      final deleteProtectedResult =
          await provider.deleteStreamer('prof_alghamdi_01');
      expect(deleteProtectedResult, isFalse);
      expect(provider.streamers.length, equals(5));

      // Add new custom streamer
      const customStreamer = StreamerModel(
        streamerId: 'custom_dr_fahad',
        fullNameEn: 'Dr. Fahad Al-Mutairi',
        fullNameAr: 'د. فهد المطيري',
        titleEn: 'Professor of Software Engineering',
        titleAr: 'أستاذ هندسة البرمجيات',
        organizationEn: 'KFUPM',
        organizationAr: 'جامعة الملك فهد',
        avatarUrl: 'https://images.unsplash.com/avatar',
        bannerUrl: 'https://images.unsplash.com/banner',
        bioEn: 'Cloud and microservices lecturer',
        bioAr: 'محاضر في الحوسبة السحابية',
        isVerified: true,
        followerCount: 500,
        categoryId: 'computer_science',
        tags: ['#Cloud', '#DevOps'],
        cityEn: 'Al Khobar',
        cityAr: 'الخبر',
        venueNameEn: 'KFUPM Bldg 24',
        venueNameAr: 'مبنى 24',
        latitude: 26.2871,
        longitude: 50.2125,
        isCurrentlyLive: false,
        activeViewerCount: 0,
      );

      provider.addStreamer(customStreamer);
      expect(provider.streamers.length, equals(6));
      expect(provider.isProtectedStreamer('custom_dr_fahad'), isFalse);

      // Update custom streamer
      provider.updateStreamer(
          customStreamer.copyWith(fullNameEn: 'Dr. Fahad M. Al-Mutairi'));
      final updated = provider.getStreamerById('custom_dr_fahad');
      expect(updated?.fullNameEn, equals('Dr. Fahad M. Al-Mutairi'));

      // Delete custom streamer
      final deleteResult = await provider.deleteStreamer('custom_dr_fahad');
      expect(deleteResult, isTrue);
      expect(provider.streamers.length, equals(5));
    });

    test('TC-V04-SET-06: Broadcast Type & Audio-Only Live State Management',
        () {
      // Broadcast-type changes apply to the caller's OWN channel only (P1.6),
      // so the test account owns prof_alghamdi_01 through its application.
      provider.debugSetSignedInForTests(
        email: 'owner@example.com',
        isStreamer: true,
        ownedStreamerId: 'prof_alghamdi_01',
      );
      expect(provider.customBroadcastType, equals(BroadcastType.liveVideo));

      // Toggle broadcast type to liveAudio
      provider.setBroadcastType(BroadcastType.liveAudio);
      expect(provider.customBroadcastType, equals(BroadcastType.liveAudio));

      // Toggle Amir Go Live with Audio-Only mode
      provider.toggleBroadcasterGoLive();
      expect(provider.isBroadcastingLive, isFalse);
      expect(provider.broadcastSessionError, 'broadcast_primary_required');
      // Keep audio/video marker coverage using the explicit local fixture tool.
      provider.setPitchDirectorMode(true);
      final amir = provider.getStreamerById('prof_alghamdi_01');
      expect(amir, isNotNull);
      expect(amir!.isCurrentlyLive, isTrue);
      expect(amir.broadcastType, equals(BroadcastType.liveAudio));
      expect(amir.isAudioLive, isTrue);
      expect(amir.isVideoLive, isFalse);

      final markerAudio = MapMarkerModel.fromStreamer(amir);
      expect(markerAudio.status, equals(MarkerStatus.liveAudio));
      expect(markerAudio.isAudioLive, isTrue);
      expect(markerAudio.isVideoLive, isFalse);

      // Switch to Video Mode
      provider.setBroadcastType(BroadcastType.liveVideo);
      final amirVideo = provider.getStreamerById('prof_alghamdi_01');
      expect(amirVideo!.isCurrentlyLive, isTrue);
      expect(amirVideo.broadcastType, equals(BroadcastType.liveVideo));
      expect(amirVideo.isVideoLive, isTrue);
      expect(amirVideo.isAudioLive, isFalse);

      final markerVideo = MapMarkerModel.fromStreamer(amirVideo);
      expect(markerVideo.status, equals(MarkerStatus.liveVideo));
      expect(markerVideo.isVideoLive, isTrue);
      expect(markerVideo.isAudioLive, isFalse);

      // Stop broadcasting
      provider.setPitchDirectorMode(false);
      final amirOffline = provider.getStreamerById('prof_alghamdi_01');
      expect(amirOffline!.isCurrentlyLive, isFalse);

      // Test Pitch Director mode with Audio-Only format
      provider.setBroadcastType(BroadcastType.liveAudio);
      provider.setPitchDirectorMode(true);
      final amirPitch = provider.getStreamerById('prof_alghamdi_01');
      expect(amirPitch!.isCurrentlyLive, isTrue);
      expect(amirPitch.broadcastType, equals(BroadcastType.liveAudio));
      expect(amirPitch.isAudioLive, isTrue);
      expect(amirPitch.isVideoLive, isFalse);

      final markerPitch = MapMarkerModel.fromStreamer(amirPitch);
      expect(markerPitch.status, equals(MarkerStatus.liveAudio));
      expect(markerPitch.isAudioLive, isTrue);
    });

    test(
        'TC-V04-AUTH-01: Onboarding Role Selection & Google Auth State Management',
        () async {
      expect(provider.hasCompletedOnboarding, isFalse);
      expect(provider.isLoggedInStreamer, isFalse);
      expect(provider.isStreamerModeEnabled, isFalse);

      // Select Viewer Mode
      provider.selectViewerMode();
      expect(provider.hasCompletedOnboarding, isTrue);
      expect(provider.isLoggedInStreamer, isFalse);
      expect(provider.isStreamerModeEnabled, isFalse);

      // Login as Streamer with Google (simulated -- no real Supabase backend
      // in this widget test; see debugSetSignedInForTests's doc comment)
      provider.debugSetSignedInForTests(
        email: 'amir.alhatemi@gmail.com',
        name: 'Amir Al-Hatemi',
      );
      expect(provider.hasCompletedOnboarding, isTrue);
      expect(provider.isLoggedInStreamer, isTrue);
      expect(provider.isStreamerModeEnabled, isTrue);
      expect(provider.googleUserEmail, equals('amir.alhatemi@gmail.com'));
      expect(provider.googleUserName, equals('Amir Al-Hatemi'));

      // Logout back to Viewer Mode
      await provider.logout();
      expect(provider.isLoggedInStreamer, isFalse);
      expect(provider.isStreamerModeEnabled, isFalse);
      expect(provider.googleUserEmail, isNull);

      // Reset Onboarding
      await provider.resetOnboarding();
      expect(provider.hasCompletedOnboarding, isFalse);
    });

    test(
        'TC-V04-MAP-01: Live Streamer Max Zoom Visibility & Z-Index Prioritization',
        () {
      final allStreamers = provider.streamers;
      expect(allStreamers.length, equals(5));

      // Pitch Director mode marks the caller's OWN channel live (P1.6), so
      // the test account owns prof_alghamdi_01 through its application.
      provider.debugSetSignedInForTests(
        email: 'owner@example.com',
        isStreamer: true,
        ownedStreamerId: 'prof_alghamdi_01',
      );

      // Make the owned channel Live Audio
      provider.setBroadcastType(BroadcastType.liveAudio);
      provider.setPitchDirectorMode(true);

      const double regionalZoom = 9.5;
      const double zoomThreshold = 11.2;

      // Filter simulation matching spatial_map_screen logic
      final visibleAtRegionalZoom = provider.streamers.where((s) {
        if (s.isCurrentlyLive) return true;
        return regionalZoom >= zoomThreshold;
      }).toList();

      // Only live streamers visible at regional zoom
      expect(visibleAtRegionalZoom.length, greaterThanOrEqualTo(1));
      expect(
          visibleAtRegionalZoom.any((s) => s.streamerId == 'prof_alghamdi_01'),
          isTrue);
      expect(visibleAtRegionalZoom.every((s) => s.isCurrentlyLive), isTrue);

      // Test Z-index sorting score
      final sortedStreamers = List<StreamerModel>.from(provider.streamers)
        ..sort((a, b) {
          int scoreA = a.isVideoLive ? 3 : (a.isAudioLive ? 2 : 1);
          int scoreB = b.isVideoLive ? 3 : (b.isAudioLive ? 2 : 1);
          return scoreA.compareTo(scoreB);
        });

      // The live streamers must be prioritized over offline streamers
      expect(sortedStreamers.last.isCurrentlyLive, isTrue);
    });
  });
}
