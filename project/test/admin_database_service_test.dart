import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/features/admin/models/terms_and_conditions_model.dart';
import 'package:streamer_app/features/admin/models/viewer_analytics_model.dart';

import 'fixtures/admin_applications.dart';

void main() {
  group('Admin Hub & Database Layer Unit Tests (Phase 1)', () {
    test('TC-DB-01: BroadcasterApplicationModel JSON Round-Trip & Dual-Track Verification', () {
      final scholarApp = BroadcasterApplicationModel(
        id: 'app_scholar_test_01',
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Dr. Zaid Al-Otaibi',
        applicantNameAr: 'د. زيد العتيبي',
        email: 'zaid.otaibi@kfupm.edu.sa',
        phone: '+966 55 987 6543',
        academicTitleEn: 'Professor of Software Engineering',
        academicTitleAr: 'أستاذ هندسة البرمجيات',
        institutionEn: 'KFUPM',
        institutionAr: 'جامعة الملك فهد',
        categoryId: 'computer_science',
        tags: const ['#Flutter', '#CleanArchitecture'],
        venueNameEn: 'Auditorium 24',
        venueNameAr: 'قاعة 24',
        latitude: 26.3050,
        longitude: 50.1450,
        youtubeChannelUrl: 'https://youtube.com/@dr_zaid',
        youtubeHandle: 'dr_zaid',
        bioEn: 'Senior researcher in distributed computing.',
        bioAr: 'باحث أول في الحوسبة الموزعة.',
        avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        bannerUrl: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
        submittedAt: DateTime(2026, 8, 17, 10, 0),
      );

      final jsonScholar = scholarApp.toJson();
      final reconstitutedScholar = BroadcasterApplicationModel.fromJson(jsonScholar);

      expect(reconstitutedScholar.id, equals('app_scholar_test_01'));
      expect(reconstitutedScholar.isOrganization, isFalse);
      expect(reconstitutedScholar.isPending, isTrue);
      expect(reconstitutedScholar.getLocalizedTitle('en'), equals('Professor of Software Engineering'));
      expect(reconstitutedScholar.getLocalizedTitle('ar'), equals('أستاذ هندسة البرمجيات'));

      final orgApp = BroadcasterApplicationModel(
        id: 'app_org_test_02',
        accountType: ApplicationAccountType.organizationVenue,
        applicantNameEn: 'Eastern Province Technology Hub',
        applicantNameAr: 'مركز تقنية المنطقة الشرقية',
        email: 'events@eptech.sa',
        phone: '+966 13 800 1234',
        categoryId: 'cs_tech',
        tags: const ['#Innovation', '#Khobar'],
        organizationType: 'Technology Center & Auditorium',
        venueNameEn: 'Innovation Hall A',
        venueNameAr: 'قاعة الابتكار أ',
        latitude: 26.2871,
        longitude: 50.2125,
        seatingCapacity: 600,
        officialWebsiteUrl: 'https://eptech.sa',
        youtubeChannelUrl: 'https://youtube.com/@eptech_live',
        youtubeHandle: 'eptech_live',
        bioEn: 'Flagship innovation and tech conference venue in Khobar.',
        bioAr: 'المركز الرئيسي للابتكار والمؤتمرات التقنية بالخبر.',
        avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        bannerUrl: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
        submittedAt: DateTime(2026, 8, 17, 11, 0),
      );

      final jsonOrg = orgApp.toJson();
      final reconstitutedOrg = BroadcasterApplicationModel.fromJson(jsonOrg);

      expect(reconstitutedOrg.id, equals('app_org_test_02'));
      expect(reconstitutedOrg.isOrganization, isTrue);
      expect(reconstitutedOrg.seatingCapacity, equals(600));
      expect(reconstitutedOrg.getLocalizedTitle('en'), equals('Technology Center & Auditorium'));
    });

    test('TC-DB-02: TermsAndConditionsModel Serialization & Bilingual Helpers', () {
      final terms = TermsAndConditionsModel.createDefault();
      expect(terms.version, equals('v1.0.0'));
      expect(terms.getLocalizedTerms('en'), contains('Educational Purpose'));
      expect(terms.getLocalizedTerms('ar'), contains('الغرض التعليمي'));
      expect(terms.getLocalizedGuidelines('en'), contains('Academic Integrity'));
      expect(terms.getLocalizedGuidelines('ar'), contains('الأمانة الأكاديمية'));

      final json = terms.toJson();
      final reconstituted = TermsAndConditionsModel.fromJson(json);
      expect(reconstituted.version, equals('v1.0.0'));
    });

    test('TC-DB-03: ViewerAnalyticsModel Serialization & Metrics Default', () {
      final analytics = ViewerAnalyticsModel.createDefault();
      expect(analytics.totalGuestSessions, equals(1420));
      expect(analytics.totalRegisteredGoogleUsers, equals(185));
      expect(analytics.totalLectureBookmarks, equals(920));
      expect(analytics.totalAuditoriumRsvps, equals(365));

      final json = analytics.toJson();
      final reconstituted = ViewerAnalyticsModel.fromJson(json);
      expect(reconstituted.totalGuestSessions, equals(1420));
      expect(reconstituted.totalRegisteredGoogleUsers, equals(185));
    });

    test('TC-DB-04: Submitted Applications & Application Mutations', () async {
      final service = AdminDatabaseService(null);
      // The service no longer seeds sample applications (P1.6/P2): an empty
      // queue is the truthful state, so this test submits its own fixtures.
      expect(await service.loadApplications(), isEmpty);
      for (final fixture in sampleBroadcasterApplications()) {
        await service.submitApplication(fixture);
      }
      final apps = await service.loadApplications();

      expect(apps.length, greaterThanOrEqualTo(2));
      expect(apps.any((a) => a.id == 'app_kfupm_ai_01'), isTrue);
      expect(apps.any((a) => a.id == 'app_dr_tariq_02'), isTrue);

      final kfupmApp = apps.firstWhere((a) => a.id == 'app_kfupm_ai_01');
      expect(kfupmApp.isOrganization, isTrue);
      expect(kfupmApp.seatingCapacity, equals(450));
      expect(kfupmApp.isPending, isTrue);

      // Update status to Approved
      final approved = await service.updateApplicationStatus(
        'app_kfupm_ai_01',
        ApplicationStatus.approved,
        reviewNotes: 'Valid university credentials confirmed.',
        reviewedBy: 'Amir Al-Hatemi (Super Admin)',
      );

      expect(approved, isNotNull);
      expect(approved!.isApproved, isTrue);
      expect(approved.adminReviewNotes, equals('Valid university credentials confirmed.'));
    });

    test('TC-DB-05: AppProvider Verification State Machine (Approve Application -> Live Streamer)', () async {
      final service = AdminDatabaseService(null);
      for (final fixture in sampleBroadcasterApplications()) {
        await service.submitApplication(fixture);
      }
      final provider = AppProvider(service);

      // Wait for async init to load the submitted applications
      await Future.delayed(const Duration(milliseconds: 50));

      final initialStreamersCount = provider.streamers.length;
      expect(provider.pendingApplications.length, greaterThanOrEqualTo(2));

      // Approve KFUPM AI Center
      final success = await provider.approveBroadcasterApplication(
        'app_kfupm_ai_01',
        adminNotes: 'Verified KFUPM research center affiliation.',
      );

      expect(success, isTrue);
      expect(provider.streamers.length, equals(initialStreamersCount + 1));

      final newStreamer = provider.streamers.firstWhere((s) => s.streamerId == 'streamer_app_kfupm_ai_01');
      expect(newStreamer.isVerified, isTrue);
      expect(newStreamer.isOrganization, isTrue);
      expect(newStreamer.fullNameEn, equals('KFUPM AI & Robotics Research Center'));
      expect(newStreamer.latitude, equals(26.3050));
      expect(newStreamer.longitude, equals(50.1450));

      // Check notification created
      expect(provider.notifications.any((n) => n.id.contains('app_kfupm_ai_01')), isTrue);
    });

    test('TC-DB-06: AppProvider Rejection Workflow and Reason Retention', () async {
      final service = AdminDatabaseService(null);
      for (final fixture in sampleBroadcasterApplications()) {
        await service.submitApplication(fixture);
      }
      final provider = AppProvider(service);

      await Future.delayed(const Duration(milliseconds: 50));

      final success = await provider.rejectBroadcasterApplication(
        'app_dr_tariq_02',
        reason: 'Please provide official medical faculty email.',
      );

      expect(success, isTrue);
      final rejected = provider.rejectedApplications.firstWhere((a) => a.id == 'app_dr_tariq_02');
      expect(rejected.isRejected, isTrue);
      expect(rejected.adminReviewNotes, equals('Please provide official medical faculty email.'));
    });
  });
}
