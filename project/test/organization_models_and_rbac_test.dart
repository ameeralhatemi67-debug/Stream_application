import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/features/organization/models/org_venue_branch_model.dart';
import 'package:streamer_app/features/organization/models/org_speaker_model.dart';
import 'package:streamer_app/features/organization/models/org_broadcaster_permissions.dart';
import 'package:streamer_app/features/organization/models/org_audit_log_entry.dart';
import 'package:streamer_app/features/profile/models/vod_models.dart';

import 'fixtures/streamer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Organization Feature Phase 1: Models & RBAC Unit Tests', () {
    test('TC-ORG-01: OrgVenueBranchModel JSON roundtrip & localization', () {
      const venue = OrgVenueBranchModel(
        venueId: 'v_khobar_01',
        nameEn: 'Khobar Main Auditorium',
        nameAr: 'مدرج الخبر الرئيسي',
        cityEn: 'Al Khobar',
        cityAr: 'الخبر',
        latitude: 26.2871,
        longitude: 50.2125,
        seatingCapacity: 400,
        isMainHeadquarters: true,
        addressEn: 'Corniche Road',
        addressAr: 'طريق الكورنيش',
        availableFacilities: ['Fiber AV', '4K Rig'],
      );

      expect(venue.getLocalizedName('en'), equals('Khobar Main Auditorium'));
      expect(venue.getLocalizedName('ar'), equals('مدرج الخبر الرئيسي'));
      expect(venue.isMainHeadquarters, isTrue);

      final json = venue.toJson();
      final reconstructed = OrgVenueBranchModel.fromJson(json);

      expect(reconstructed.venueId, equals(venue.venueId));
      expect(reconstructed.nameEn, equals(venue.nameEn));
      expect(reconstructed.seatingCapacity, equals(400));
      expect(reconstructed.availableFacilities.length, equals(2));
    });

    test('TC-ORG-02: OrgBroadcasterPermissions & OrgSpeakerModel roundtrip', () {
      const perms = OrgBroadcasterPermissions(
        canGoLiveVideo: true,
        canGoAudioOnly: false,
        canChangeLocation: true,
        canEditDescription: false,
        canEditStreamTime: true,
        canAddExternalLinks: false,
      );

      final permJson = perms.toJson();
      final permDecoded = OrgBroadcasterPermissions.fromJson(permJson);
      expect(permDecoded.canGoLiveVideo, isTrue);
      expect(permDecoded.canGoAudioOnly, isFalse);
      expect(permDecoded.canChangeLocation, isTrue);

      const speaker = OrgSpeakerModel(
        speakerId: 'spk_sarah_01',
        nameEn: 'Dr. Sarah Al-Dosari',
        nameAr: 'د. سارة الدوسري',
        roleOrTitleEn: 'IELTS Lead Specialist',
        roleOrTitleAr: 'أخصائية الآيلتس الأولى',
        avatarUrl: 'assets/images/Dalilak/profile2.jpg',
        bioEn: 'IELTS examiner specialist.',
        bioAr: 'أخصائية معايير الآيلتس.',
        isPermanentStaff: true,
        linkedEmail: 'sarah@dalilk.com',
        permissions: perms,
      );

      expect(speaker.getLocalizedName('en'), equals('Dr. Sarah Al-Dosari'));
      expect(speaker.getLocalizedRole('ar'), equals('أخصائية الآيلتس الأولى'));

      final speakerJson = speaker.toJson();
      final speakerDecoded = OrgSpeakerModel.fromJson(speakerJson);
      expect(speakerDecoded.speakerId, equals('spk_sarah_01'));
      expect(speakerDecoded.linkedEmail, equals('sarah@dalilk.com'));
      expect(speakerDecoded.permissions.canChangeLocation, isTrue);
    });

    test('TC-ORG-03: Dalilk 4 IELTS entity replacement in mockStreamers', () {
      final dalilkOrg = mockStreamers.firstWhere(
        (s) => s.streamerId == 'org_dalilk_04',
      );

      expect(dalilkOrg.isOrganization, isTrue);
      expect(dalilkOrg.fullNameEn, contains('Dalilk 4 IELTS'));
      expect(dalilkOrg.youtubeHandle, equals('dalilk4ielts'));
      expect(dalilkOrg.featuredChannelHandles.length, equals(2));
      expect(dalilkOrg.venues.length, equals(3));
      expect(dalilkOrg.affiliatedSpeakers.length, equals(3));

      expect(dalilkOrg.mainVenue?.venueId, equals('dalilk_hq_khobar'));
      expect(dalilkOrg.mainVenue?.isMainHeadquarters, isTrue);

      // Verify sample VODs exist and are attributed
      final dalilkVods = MockVodArchivePool.sampleVods
          .where((v) => v.streamerId == 'org_dalilk_04')
          .toList();
      expect(dalilkVods.length, greaterThanOrEqualTo(4));
      expect(dalilkVods.first.speakerIds, isNotEmpty);
    });

    test('TC-ORG-04: OrgAuditLogEntry JSON roundtrip', () {
      final entry = OrgAuditLogEntry(
        logId: 'audit_test_100',
        organizationId: 'org_dalilk_04',
        timestamp: DateTime.now(),
        actorEmail: 'admin@streamer.app',
        actorName: 'Lead Admin',
        action: OrgAuditAction.addSpeakerToRoster,
        descriptionEn: 'Added new speaker to roster.',
        descriptionAr: 'تمت إضافة مدرب جديد.',
        metadata: {'speaker': 'Dr. Sarah'},
      );

      final json = entry.toJson();
      final decoded = OrgAuditLogEntry.fromJson(json);

      expect(decoded.logId, equals('audit_test_100'));
      expect(decoded.action, equals(OrgAuditAction.addSpeakerToRoster));
      expect(decoded.descriptionEn, equals('Added new speaker to roster.'));
      expect(decoded.metadata['speaker'], equals('Dr. Sarah'));
    });

    test('TC-ORG-05: AppProvider RBAC and Organization helpers', () async {
      final db = await AdminDatabaseService.create();
      final provider = AppProvider(db);
      seedStreamerFixtures(provider);
      // Verify venues and speakers getters
      final venues = provider.getOrganizationVenues('org_dalilk_04');
      final speakers = provider.getOrganizationSpeakers('org_dalilk_04');
      expect(venues.length, equals(3));
      expect(speakers.length, equals(3));

      // Test RBAC for super admin (always allowed) -- admin status now comes
      // from the currently-signed-in session's backend role, not a hardcoded
      // email string, so simulate that session via debugSetSignedInForTests.
      provider.debugSetSignedInForTests(
        email: 'amir.alhatemi@gmail.com',
        isAdmin: true,
      );
      expect(
        provider.canUserBroadcastForOrg(
            'org_dalilk_04', 'amir.alhatemi@gmail.com'),
        isTrue,
      );

      // Test RBAC for authorized speaker
      expect(
        provider.canUserBroadcastForOrg(
            'org_dalilk_04', 'abdulrahman@dalilk.com'),
        isTrue,
      );

      // Test RBAC for unauthorized user
      expect(
        provider.canUserBroadcastForOrg(
            'org_dalilk_04', 'stranger@gmail.com'),
        isFalse,
      );

      // Test update speaker permissions
      await provider.updateSpeakerPermissions(
        'org_dalilk_04',
        'spk_sarah',
        const OrgBroadcasterPermissions(
          canGoLiveVideo: false,
          canGoAudioOnly: false,
        ),
      );

      final updatedSpeakers =
          provider.getOrganizationSpeakers('org_dalilk_04');
      final sarah =
          updatedSpeakers.firstWhere((s) => s.speakerId == 'spk_sarah');
      expect(sarah.permissions.canGoLiveVideo, isFalse);

      // Since Sarah's video and audio permissions are revoked, canUserBroadcastForOrg returns false
      expect(
        provider.canUserBroadcastForOrg('org_dalilk_04', 'sarah@dalilk.com'),
        isFalse,
      );
    });
  });
}
