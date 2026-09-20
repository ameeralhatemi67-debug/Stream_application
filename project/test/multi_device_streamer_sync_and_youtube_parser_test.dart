import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/auth/presentation/steps/apply_step_3_professional.dart';

import 'fixtures/streamer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Device Streamer Sync & Flexible YouTube Parsing Tests', () {
    late AppProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = AppProvider();
      seedStreamerFixtures(provider);
    });

    test('TC-YT-PARSER-01: Correctly extracts clean handle from various URL formats', () {
      const expected = 'apop8091';

      final testCases = [
        'youtube.com/@apop8091',
        'www.youtube.com/@apop8091',
        '@apop8091',
        'https://www.youtube.com/@apop8091',
        'http://youtube.com/@apop8091',
        'https://www.youtube.com/c/apop8091',
        'https://youtube.com/user/apop8091',
        'apop8091',
        'https://www.youtube.com/@apop8091/videos?si=12345',
        'https://youtube.com/@apop8091/featured',
      ];

      for (final input in testCases) {
        final parsed = ApplyStep3Professional.extractCleanYouTubeHandle(input);
        expect(parsed, equals(expected), reason: 'Failed for input: $input');
      }
    });

    test('TC-YT-PARSER-02: Handles empty or whitespace inputs gracefully', () {
      expect(ApplyStep3Professional.extractCleanYouTubeHandle(''), equals(''));
      expect(ApplyStep3Professional.extractCleanYouTubeHandle('   '), equals(''));
    });

    test('TC-SYNC-01: AppProvider merges backend verified streamers correctly', () async {
      // Initially has local mock streamers
      expect(provider.streamers.isNotEmpty, isTrue);
      final initialCount = provider.streamers.length;

      // Simulate loadVerifiedStreamersFromBackend
      await provider.loadVerifiedStreamersFromBackend();

      // Ensure mock streamers are preserved and list is valid
      expect(provider.streamers.length, greaterThanOrEqualTo(initialCount));
    });

    test('TC-REVOKE-01: deleteStreamer successfully removes non-protected streamer and updates registry', () async {
      final customStreamer = mockStreamers.first.copyWith(
        streamerId: '550e8400-e29b-41d4-a716-446655440000',
        fullNameEn: 'Custom Test Broadcaster',
      );

      provider.addStreamer(customStreamer);
      expect(provider.streamers.any((s) => s.streamerId == customStreamer.streamerId), isTrue);

      final success = await provider.deleteStreamer(customStreamer.streamerId);
      expect(success, isTrue);
      expect(provider.streamers.any((s) => s.streamerId == customStreamer.streamerId), isFalse);
    });

    test('TC-PROTECT-01: Protected seed streamers cannot be deleted', () async {
      const protectedId = 'prof_alghamdi_01';
      expect(provider.streamers.any((s) => s.streamerId == protectedId), isTrue);

      final success = await provider.deleteStreamer(protectedId);
      expect(success, isFalse);
      expect(provider.streamers.any((s) => s.streamerId == protectedId), isTrue);
    });
  });
}

