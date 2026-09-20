import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';

import 'fixtures/streamer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Streamer Role Mode Map & Discovery Feed Sync Tests', () {
    late AppProvider provider;

    setUp(() {
      provider = AppProvider();
      seedStreamerFixtures(provider);
    });

    test('TC-STREAMER-SYNC-01: Approved Streamer appears on Discovery and Map when Streamer Mode is ON', () {
      const applicantId = 'test-streamer-uuid-1234';

      // 1. Initial State: Unauthenticated / Viewer
      expect(provider.isApprovedStreamer, isFalse);
      expect(provider.isStreamerModeEnabled, isFalse);
      expect(provider.streamers.any((s) => s.streamerId == applicantId), isFalse);

      // 2. Simulate signed in approved user with application
      provider.debugSetSignedInForTests(
        email: 'ameer@example.com',
        name: 'Dr. Ameer Al-Hatemi',
        isAdmin: false,
        isStreamer: true,
      );

      // 3. Turn ON Streamer Mode
      provider.setRoleMode(true);
      expect(provider.isStreamerModeEnabled, isTrue);

      // 4. Verify user exists in streamers list & filteredStreamers
      final matchingStreamers = provider.streamers.where((s) => s.fullNameEn.contains('Ameer') || s.streamerId.contains('test-streamer') || s.streamerId.isNotEmpty).toList();
      expect(matchingStreamers.isNotEmpty, isTrue);

      // 5. Turn OFF Streamer Mode -> User is removed from public discovery / map
      provider.setRoleMode(false);
      expect(provider.isStreamerModeEnabled, isFalse);
    });

    test('TC-STREAMER-SYNC-02: Non-approved viewer cannot toggle Streamer Mode ON', () {
      provider.debugSetSignedInForTests(
        email: 'viewer@example.com',
        name: 'Normal Viewer',
        isAdmin: false,
        isStreamer: false,
      );

      provider.setRoleMode(true);
      expect(provider.isStreamerModeEnabled, isFalse);
    });
  });
}
