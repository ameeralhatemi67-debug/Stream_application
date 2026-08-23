import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/utils/id_generator.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';

void main() {
  group('Broadcaster Application UUID Validation Proof', () {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    test('TC-UUID-01: Legacy timestamp string (app_...) FAILS PostgreSQL UUID validation', () {
      final legacyId = 'app_${DateTime.now().millisecondsSinceEpoch}';
      expect(uuidRegex.hasMatch(legacyId), isFalse,
          reason: 'Legacy IDs with app_ prefix must NOT pass UUID check');
    });

    test('TC-UUID-02: newId() generates valid RFC4122 v4 UUID accepted by PostgreSQL', () {
      final id = newId();
      expect(uuidRegex.hasMatch(id), isTrue,
          reason: 'newId() must generate a valid standard UUID');
    });

    test('TC-UUID-03: BroadcasterApplicationModel with newId() satisfies schema format', () {
      final app = BroadcasterApplicationModel(
        id: newId(),
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Test Scholar',
        applicantNameAr: 'باحث تجريبي',
        email: 'scholar@test.com',
        phone: '+966500000000',
        categoryId: 'computer_science',
        tags: const ['#AI'],
        venueNameEn: 'Main Hall',
        venueNameAr: 'القاعة الرئيسية',
        latitude: 26.2871,
        longitude: 50.2125,
        seatingCapacity: 250,
        youtubeChannelUrl: 'https://youtube.com/@test',
        youtubeHandle: 'test',
        bioEn: 'Bio',
        bioAr: 'نبذة',
        avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        bannerUrl: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      expect(uuidRegex.hasMatch(app.id), isTrue);
      expect(app.status, ApplicationStatus.pending);
    });

    test('TC-AUTH-08: Non-streamer users cannot toggle Streamer Mode on', () {
      final provider = AppProvider();
      provider.debugSetSignedInForTests(
        email: 'viewer@example.com',
        name: 'Regular Viewer',
        isStreamer: false,
        isAdmin: false,
      );

      expect(provider.isApprovedStreamer, isFalse);
      expect(provider.isStreamerModeEnabled, isFalse);

      // Attempt to toggle Streamer Mode
      provider.setRoleMode(true);
      expect(provider.isStreamerModeEnabled, isFalse,
          reason: 'Unapproved viewer must not be allowed to enable Streamer Mode');
    });

    test('TC-AUTH-09: Approved streamers can toggle Streamer Mode freely', () {
      final provider = AppProvider();
      provider.debugSetSignedInForTests(
        email: 'scholar@example.com',
        name: 'Approved Scholar',
        isStreamer: true,
        isAdmin: false,
      );

      expect(provider.isApprovedStreamer, isTrue);
      expect(provider.isStreamerModeEnabled, isTrue);

      // Switch to Viewer Mode
      provider.setRoleMode(false);
      expect(provider.isStreamerModeEnabled, isFalse);

      // Switch back to Streamer Mode
      provider.setRoleMode(true);
      expect(provider.isStreamerModeEnabled, isTrue);
    });
  });
}
