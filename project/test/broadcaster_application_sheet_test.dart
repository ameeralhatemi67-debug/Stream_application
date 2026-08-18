import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Broadcaster Application Sheet & State Management Tests (Phase 2)', () {
    late AppProvider provider;

    setUp(() async {
      final service = AdminDatabaseService(null);
      provider = AppProvider(service);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('TC-APP-01: Dual-Track Application Distinction (Scholar vs Org)', () {
      final scholarApp = BroadcasterApplicationModel(
        id: 'app_scholar_01',
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Dr. Fatima Al-Zahrani',
        applicantNameAr: 'د. فاطمة الزهراني',
        email: 'fatima@iau.edu.sa',
        phone: '+966501234567',
        academicTitleEn: 'Associate Professor',
        academicTitleAr: 'أستاذ مشارك',
        institutionEn: 'Imam Abdulrahman Bin Faisal University',
        institutionAr: 'جامعة الإمام عبد الرحمن بن فيصل',
        categoryId: 'computer_science',
        tags: const ['#AI', '#DataScience'],
        venueNameEn: 'College of Computer Science Auditorium',
        venueNameAr: 'مدرج كلية علوم الحاسب',
        latitude: 26.3927,
        longitude: 50.1906,
        seatingCapacity: 200,
        youtubeChannelUrl: 'https://youtube.com/@iau_cs',
        youtubeHandle: 'iau_cs',
        bioEn: 'Lectures on machine learning.',
        bioAr: 'محاضرات في تعلم الآلة.',
        avatarUrl: 'assets/images/default.jpg',
        bannerUrl: 'assets/images/default_banner.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      final orgApp = BroadcasterApplicationModel(
        id: 'app_org_01',
        accountType: ApplicationAccountType.organizationVenue,
        applicantNameEn: 'Ithra Cultural Center',
        applicantNameAr: 'مركز الملك عبد العزيز الثقافي العالمي (إثراء)',
        email: 'events@ithra.com',
        phone: '+966138169799',
        organizationType: 'Cultural & Educational Hub',
        venueNameEn: 'Ithra Grand Auditorium',
        venueNameAr: 'مدرج إثراء الرئيسي',
        latitude: 26.3075,
        longitude: 50.1250,
        seatingCapacity: 900,
        officialWebsiteUrl: 'https://ithra.com',
        categoryId: 'engineering',
        tags: const ['#Culture', '#Innovation'],
        youtubeChannelUrl: 'https://youtube.com/@ithra',
        youtubeHandle: 'ithra',
        bioEn: 'Flagship cultural and knowledge hub in Dhahran.',
        bioAr: 'المركز الثقافي والمعرفي الرائد في الظهران.',
        avatarUrl: 'assets/images/ithra.jpg',
        bannerUrl: 'assets/images/ithra_banner.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      expect(scholarApp.isOrganization, isFalse);
      expect(scholarApp.academicTitleEn, equals('Associate Professor'));

      expect(orgApp.isOrganization, isTrue);
      expect(orgApp.seatingCapacity, equals(900));
      expect(orgApp.organizationType, equals('Cultural & Educational Hub'));
    });

    test('TC-APP-02: AppProvider Application Submission & Mutation', () async {
      final initialCount = provider.applications.length;

      final newApp = BroadcasterApplicationModel(
        id: 'app_test_submit_${DateTime.now().millisecondsSinceEpoch}',
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Dr. Nasser Al-Ghamdi',
        applicantNameAr: 'د. ناصر الغامدي',
        email: 'nghamdi@kfupm.edu.sa',
        phone: '+966551234567',
        academicTitleEn: 'Professor of Physics',
        academicTitleAr: 'أستاذ الفيزياء',
        institutionEn: 'KFUPM',
        institutionAr: 'جامعة الملك فهد للبترول والمعادن',
        categoryId: 'engineering',
        tags: const ['#Quantum', '#Physics'],
        venueNameEn: 'Building 6 Physics Hall',
        venueNameAr: 'قاعة فيزياء مبنى 6',
        latitude: 26.3050,
        longitude: 50.1450,
        seatingCapacity: 150,
        youtubeChannelUrl: 'https://youtube.com/@kfupm_physics',
        youtubeHandle: 'kfupm_physics',
        bioEn: 'Quantum mechanics lectures.',
        bioAr: 'محاضرات في ميكانيكا الكم.',
        avatarUrl: 'assets/images/default.jpg',
        bannerUrl: 'assets/images/default_banner.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      await provider.submitBroadcasterApplication(newApp);

      expect(provider.applications.length, equals(initialCount + 1));
      expect(provider.applications.any((a) => a.id == newApp.id), isTrue);

      final fetched = provider.applications.firstWhere((a) => a.id == newApp.id);
      expect(fetched.applicantNameEn, equals('Dr. Nasser Al-Ghamdi'));
      expect(fetched.status, equals(ApplicationStatus.pending));
    });

    test('TC-APP-03: Rejection with Admin Feedback Notes Lifecycle', () async {
      final app = BroadcasterApplicationModel(
        id: 'app_rejection_test',
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Eng. Sarah Al-Dosari',
        applicantNameAr: 'م. سارة الدوسري',
        email: 'sarah.dosari@test.com',
        phone: '+966509876543',
        academicTitleEn: 'Lecturer',
        academicTitleAr: 'محاضر',
        institutionEn: 'Dammam College',
        institutionAr: 'كلية الدمام',
        categoryId: 'computer_science',
        tags: const ['#WebDev'],
        venueNameEn: 'Hall A',
        venueNameAr: 'القاعة أ',
        latitude: 26.4207,
        longitude: 50.0888,
        seatingCapacity: 80,
        youtubeChannelUrl: 'https://youtube.com/@sarah_dev',
        youtubeHandle: 'sarah_dev',
        bioEn: 'Web development tutorials.',
        bioAr: 'شروحات تطوير الويب.',
        avatarUrl: 'assets/images/default.jpg',
        bannerUrl: 'assets/images/default_banner.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      await provider.submitBroadcasterApplication(app);

      // Super Admin rejects with specific feedback note
      const feedbackReason =
          'Please provide official university department email for verification.';
      final rejected = await provider.rejectBroadcasterApplication(
        app.id,
        reason: feedbackReason,
      );

      expect(rejected, isTrue);

      final updatedApp =
          provider.applications.firstWhere((a) => a.id == app.id);
      expect(updatedApp.status, equals(ApplicationStatus.rejected));
      expect(updatedApp.adminReviewNotes, equals(feedbackReason));
      expect(updatedApp.reviewNotes, equals(feedbackReason));
    });

    test('TC-APP-04: Approval Lifecycle & Auto Live Streamer Registration', () async {
      final initialStreamers = provider.streamers.length;

      final app = BroadcasterApplicationModel(
        id: 'app_approval_test',
        accountType: ApplicationAccountType.organizationVenue,
        applicantNameEn: 'Dammam Technology Hub',
        applicantNameAr: 'مركز الدمام للتقنية',
        email: 'admin@dammamtech.sa',
        phone: '+966138001122',
        organizationType: 'Technology Innovation Hub',
        venueNameEn: 'Innovation Auditorium',
        venueNameAr: 'مدرج الابتكار',
        latitude: 26.4300,
        longitude: 50.1000,
        seatingCapacity: 400,
        categoryId: 'computer_science',
        tags: const ['#Tech', '#Startups'],
        youtubeChannelUrl: 'https://youtube.com/@dammamtech',
        youtubeHandle: 'dammamtech',
        bioEn: 'Fostering tech ecosystem.',
        bioAr: 'دعم المنظومة التقنية في الشرقية.',
        avatarUrl: 'assets/images/default.jpg',
        bannerUrl: 'assets/images/default_banner.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      await provider.submitBroadcasterApplication(app);

      final approved = await provider.approveBroadcasterApplication(
        app.id,
        adminNotes: 'Verified accreditation and venue facilities.',
      );

      expect(approved, isTrue);
      expect(provider.streamers.length, equals(initialStreamers + 1));

      final createdStreamer = provider.streamers.firstWhere(
        (s) => s.streamerId == 'streamer_${app.id}',
      );
      expect(createdStreamer.fullNameEn, equals('Dammam Technology Hub'));
      expect(createdStreamer.isVerified, isTrue);
      expect(createdStreamer.isOrganization, isTrue);
      expect(createdStreamer.latitude, equals(26.4300));
      expect(createdStreamer.longitude, equals(50.1000));
    });
  });
}
