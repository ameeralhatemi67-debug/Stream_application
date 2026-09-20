import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/providers/app_provider.dart';

import 'fixtures/streamer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Version 0.4 Checkpoint 4.1 & 4.2 UI/UX, Localization & Safety Tests',
      () {
    test(
        'TC-I18N-01: 100% Localization Key Symmetry between en.json and ar.json',
        () async {
      final enFile = File('assets/i18n/en.json');
      final arFile = File('assets/i18n/ar.json');

      expect(enFile.existsSync(), isTrue);
      expect(arFile.existsSync(), isTrue);

      final Map<String, dynamic> enJson =
          jsonDecode(await enFile.readAsString());
      final Map<String, dynamic> arJson =
          jsonDecode(await arFile.readAsString());

      Set<String> extractKeys(Map<String, dynamic> map, [String prefix = '']) {
        final Set<String> keys = {};
        map.forEach((key, value) {
          final currentKey = prefix.isEmpty ? key : '$prefix.$key';
          if (value is Map<String, dynamic>) {
            keys.addAll(extractKeys(value, currentKey));
          } else {
            keys.add(currentKey);
          }
        });
        return keys;
      }

      final enKeys = extractKeys(enJson);
      final arKeys = extractKeys(arJson);

      expect(enKeys.length, equals(arKeys.length));
      expect(enKeys.difference(arKeys), isEmpty,
          reason: 'Keys in en.json missing in ar.json');
      expect(arKeys.difference(enKeys), isEmpty,
          reason: 'Keys in ar.json missing in en.json');
      expect(enKeys.length, greaterThanOrEqualTo(30));
    });

    test('TC-THEME-01: Minimalist Dark Theme Palette & High Contrast Ratios',
        () {
      expect(AppTheme.darkBgBase, equals(const Color(0xFF121214)));
      expect(AppTheme.darkSurface1, equals(const Color(0xFF1A1A1E)));
      expect(AppTheme.darkSurface2, equals(const Color(0xFF24242A)));
      expect(AppTheme.darkSurface3, equals(const Color(0xFF2D2D35)));

      expect(AppTheme.textPrimaryDark, equals(const Color(0xFFFFFFFF)));
      expect(AppTheme.textSecondaryDark, equals(const Color(0xFFA1A1AA)));
      expect(AppTheme.textMutedDark, equals(const Color(0xFF71717A)));

      expect(AppTheme.accentRed, equals(const Color(0xFFFF8080)));
      expect(AppTheme.accentGreen, equals(const Color(0xFF34D399)));
      expect(AppTheme.accentBlue, equals(const Color(0xFF38BDF8)));
      expect(AppTheme.accentPurple, equals(const Color(0xFFA78BFA)));
    });

    test(
        'TC-THEME-02: Dark Theme Base Surface and Accent Constants Verification',
        () {
      expect(AppTheme.darkBgBase, equals(const Color(0xFF121214)));
      expect(AppTheme.darkSurface1, equals(const Color(0xFF1A1A1E)));
      expect(AppTheme.darkSurface2, equals(const Color(0xFF24242A)));
      expect(AppTheme.darkSurface3, equals(const Color(0xFF2D2D35)));
      expect(AppTheme.accentBlue, equals(const Color(0xFF38BDF8)));
      expect(AppTheme.accentRed, equals(const Color(0xFFFF8080)));
    });

    test('TC-PITCH-01: Pitch Director Mode Activation & Live State Forcing',
        () {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      // Pitch Director mode marks the caller's OWN channel live (P1.6).
      provider.debugSetSignedInForTests(
        email: 'owner@example.com',
        isStreamer: true,
        ownedStreamerId: 'prof_alghamdi_01',
      );
      expect(provider.isPitchDirectorModeEnabled, isFalse);

      provider.activatePitchDirectorMode();
      expect(provider.isPitchDirectorModeEnabled, isTrue);
      expect(provider.activeStreamId, equals('stream_live_992'));

      final drGhamdi = provider.getStreamerById('prof_alghamdi_01');
      expect(drGhamdi, isNotNull);
      expect(drGhamdi!.isCurrentlyLive, isTrue);
      // activeViewerCount starts at 0 and is updated asynchronously by the
      // live viewer polling loop (YouTube Data API concurrentViewers).
      expect(drGhamdi.activeViewerCount, greaterThanOrEqualTo(0));
    });

    test('TC-PITCH-02: Category Filtering and Search Operations', () {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      provider.setCategoryFilter('cs_tech');
      expect(provider.currentCategoryFilter, equals('cs_tech'));
      expect(provider.filteredStreamers.every((s) => s.categoryId == 'cs_tech'),
          isTrue);

      provider.setCategoryFilter('all');
      provider.setSearchQuery('Amir');
      expect(provider.filteredStreamers.length, equals(1));
      expect(provider.filteredStreamers.first.streamerId,
          equals('prof_alghamdi_01'));

      provider.setSearchQuery('');
      expect(
          provider.filteredStreamers.length, equals(provider.streamers.length));
    });
  });
}
