import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/features/admin/models/terms_and_conditions_model.dart';
import 'package:streamer_app/features/admin/models/viewer_analytics_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Hub Dashboard & Multi-Account RBAC Tests (Phase 3)', () {
    late AppProvider provider;

    setUp(() async {
      final service = AdminDatabaseService(null);
      provider = AppProvider(service);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('TC-ADMIN-01: Admin Authorization Reflects Backend Role, Not Email',
        () async {
      // Default: Not logged in as streamer -> isAdminUser is false
      expect(provider.isAdminUser, isFalse);

      // Admin status now comes from the user_roles table (via the
      // is_admin_tier() RPC), not a hardcoded email allowlist -- there's no
      // real Supabase backend in this widget test, so debugSetSignedInForTests
      // simulates what AppProvider's auth listener would have set from a
      // live session + RPC round trip. See VULN-RBAC-03.
      provider.debugSetSignedInForTests(
        email: 'someone@example.com',
        name: 'Admin User 1',
        isAdmin: true,
      );
      expect(provider.isLoggedInStreamer, isTrue);
      expect(provider.isAdminUser, isTrue);

      // A signed-in user without the admin role is not an admin, regardless
      // of which email they used to sign in.
      provider.debugSetSignedInForTests(
        email: 'random.scholar@university.edu',
        name: 'Regular Scholar',
        isAdmin: false,
      );
      expect(provider.isLoggedInStreamer, isTrue);
      expect(provider.isAdminUser, isFalse);
    });

    test('TC-ADMIN-02: Verification Queue Approval & Live Streamer Instantiation',
        () async {
      provider.debugSetSignedInForTests(
        email: 'polkgvd2@gmail.com',
        isAdmin: true,
      );

      final initialStreamers = provider.streamers.length;
      final pendingCount = provider.pendingApplicationsCount;

      expect(pendingCount, greaterThanOrEqualTo(1));
      final appToApprove = provider.pendingApplications.first;

      final success = await provider.approveBroadcasterApplication(
        appToApprove.id,
        adminNotes: 'Verified official credentials and venue facilities.',
      );

      expect(success, isTrue);
      expect(provider.streamers.length, equals(initialStreamers + 1));
      expect(provider.pendingApplications.any((a) => a.id == appToApprove.id),
          isFalse);
      expect(provider.approvedApplications.any((a) => a.id == appToApprove.id),
          isTrue);

      final newStreamer = provider.streamers.firstWhere(
        (s) => s.streamerId == 'streamer_${appToApprove.id}',
      );
      expect(newStreamer.isVerified, isTrue);
      expect(newStreamer.fullNameEn, equals(appToApprove.applicantNameEn));
    });

    test('TC-ADMIN-03: Rejection with Admin Feedback Note Retention', () async {
      provider.debugSetSignedInForTests(
        email: 'ameeralhatemi67@gmail.com',
        name: 'Amir Al-Hatemi',
        isAdmin: true,
      );

      final testApp = BroadcasterApplicationModel(
        id: 'app_admin_reject_01',
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Lecturer Tariq Al-Dosari',
        applicantNameAr: 'المحاضر طارق الدوسري',
        email: 'tariq@test.edu.sa',
        phone: '+966550011223',
        academicTitleEn: 'Lecturer',
        academicTitleAr: 'محاضر',
        institutionEn: 'Dammam Technical Institute',
        institutionAr: 'معهد الدمام التقني',
        categoryId: 'computer_science',
        tags: const ['#Coding'],
        venueNameEn: 'Lab 3',
        venueNameAr: 'مختبر 3',
        latitude: 26.4200,
        longitude: 50.0900,
        seatingCapacity: 40,
        youtubeChannelUrl: 'https://youtube.com/@tariq_code',
        youtubeHandle: 'tariq_code',
        bioEn: 'Introductory programming tutorials.',
        bioAr: 'شروحات برمجية للمبتدئين.',
        avatarUrl: 'assets/images/default.jpg',
        bannerUrl: 'assets/images/default_banner.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      await provider.submitBroadcasterApplication(testApp);

      const feedback =
          'Please provide official university department accreditation letter.';
      final rejected = await provider.rejectBroadcasterApplication(
        testApp.id,
        reason: feedback,
      );

      expect(rejected, isTrue);
      final fetched =
          provider.applications.firstWhere((a) => a.id == testApp.id);
      expect(fetched.status, equals(ApplicationStatus.rejected));
      expect(fetched.adminReviewNotes, equals(feedback));
      expect(fetched.reviewNotes, equals(feedback));
      expect(fetched.reviewedBy, contains('Amir Al-Hatemi'));
    });

    test('TC-ADMIN-04: Dynamic Terms & Conditions Real-Time Save', () async {
      provider.debugSetSignedInForTests(
        email: 'polkgvd2@gmail.com',
        isAdmin: true,
      );

      final updatedTerms = TermsAndConditionsModel(
        version: 'v2.1.0-governance',
        termsOfServiceEn: 'Updated Platform Educational Terms 2026.',
        termsOfServiceAr: 'الشروط التعليمية المحدثة للمنصة 2026.',
        broadcasterGuidelinesEn: 'Updated Academic Integrity Code of Conduct.',
        broadcasterGuidelinesAr: 'ميثاق النزاهة الأكاديمية وقواعد البث المحدثة.',
        privacyPolicyEn: 'Compliant with Saudi PDPL regulations 2026.',
        privacyPolicyAr: 'متوافق مع نظام حماية البيانات الشخصية السعودي 2026.',
        lastUpdated: DateTime.now(),
      );

      await provider.updateTermsAndConditions(updatedTerms);

      expect(provider.termsAndConditions.version, equals('v2.1.0-governance'));
      expect(provider.termsAndConditions.getLocalizedTerms('en'),
          contains('Updated Platform Educational Terms 2026.'));
      expect(provider.termsAndConditions.getLocalizedTerms('ar'),
          contains('الشروط التعليمية المحدثة للمنصة 2026.'));
    });

    test('TC-ADMIN-05: Viewer Analytics & Telemetry State Updates', () async {
      provider.debugSetSignedInForTests(
        email: 'ameeralhatemi67@gmail.com',
        isAdmin: true,
      );

      final newAnalytics = ViewerAnalyticsModel(
        totalGuestSessions: 2500,
        totalRegisteredGoogleUsers: 340,
        totalAuditoriumRsvps: 580,
        totalLectureBookmarks: 1200,
        totalBroadcastHours: 180.5,
        activeViewersLive: 95,
        lastRefreshed: DateTime.now(),
      );

      await provider.updateViewerAnalytics(newAnalytics);

      expect(provider.viewerAnalytics.totalGuestSessions, equals(2500));
      expect(provider.viewerAnalytics.totalRegisteredGoogleUsers, equals(340));
      expect(provider.viewerAnalytics.totalAuditoriumRsvps, equals(580));
      expect(provider.viewerAnalytics.totalLectureBookmarks, equals(1200));
    });

    test('TC-ADMIN-06: Batch Approve Applies Every Selected Application',
        () async {
      provider.debugSetSignedInForTests(
        email: 'polkgvd2@gmail.com',
        isAdmin: true,
      );

      final batch = [
        _buildTestApplication('app_batch_approve_01', 'Batch Applicant One'),
        _buildTestApplication('app_batch_approve_02', 'Batch Applicant Two'),
      ];
      for (final app in batch) {
        await provider.submitBroadcasterApplication(app);
      }

      final initialStreamers = provider.streamers.length;
      final result = await provider.bulkApproveBroadcasterApplications(
        batch.map((a) => a.id).toList(),
        adminNotes: 'Batch-verified official credentials and venue facilities.',
      );

      expect(result.succeeded, equals(2));
      expect(result.failed, equals(0));
      expect(provider.streamers.length, equals(initialStreamers + 2));
      for (final app in batch) {
        expect(provider.approvedApplications.any((a) => a.id == app.id),
            isTrue);
        expect(provider.pendingApplications.any((a) => a.id == app.id),
            isFalse);
      }
    });

    test('TC-ADMIN-07: Batch Reject Applies the Same Feedback to Every Selected Application',
        () async {
      provider.debugSetSignedInForTests(
        email: 'polkgvd2@gmail.com',
        isAdmin: true,
      );

      final batch = [
        _buildTestApplication('app_batch_reject_01', 'Batch Reject One'),
        _buildTestApplication('app_batch_reject_02', 'Batch Reject Two'),
      ];
      for (final app in batch) {
        await provider.submitBroadcasterApplication(app);
      }

      const feedback = 'Batch rejected: missing accreditation documents.';
      final result = await provider.bulkRejectBroadcasterApplications(
        batch.map((a) => a.id).toList(),
        reason: feedback,
      );

      expect(result.succeeded, equals(2));
      expect(result.failed, equals(0));
      for (final app in batch) {
        final fetched =
            provider.applications.firstWhere((a) => a.id == app.id);
        expect(fetched.status, equals(ApplicationStatus.rejected));
        expect(fetched.adminReviewNotes, equals(feedback));
      }
    });
  });
}

BroadcasterApplicationModel _buildTestApplication(String id, String nameEn) {
  return BroadcasterApplicationModel(
    id: id,
    accountType: ApplicationAccountType.individualScholar,
    applicantNameEn: nameEn,
    applicantNameAr: nameEn,
    email: '$id@test.edu.sa',
    phone: '+966550011224',
    academicTitleEn: 'Lecturer',
    academicTitleAr: 'محاضر',
    institutionEn: 'Dammam Technical Institute',
    institutionAr: 'معهد الدمام التقني',
    categoryId: 'computer_science',
    tags: const ['#Coding'],
    venueNameEn: 'Lab 4',
    venueNameAr: 'مختبر 4',
    latitude: 26.4200,
    longitude: 50.0900,
    seatingCapacity: 40,
    youtubeChannelUrl: 'https://youtube.com/@$id',
    youtubeHandle: id,
    bioEn: 'Introductory programming tutorials.',
    bioAr: 'شروحات برمجية للمبتدئين.',
    avatarUrl: 'assets/images/default.jpg',
    bannerUrl: 'assets/images/default_banner.jpg',
    status: ApplicationStatus.pending,
    submittedAt: DateTime.now(),
  );
}
