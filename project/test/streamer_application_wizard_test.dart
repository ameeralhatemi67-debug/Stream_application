import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/translation/auto_translation_service.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Streamer Application Wizard & Staged Activation Tests', () {
    late AppProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = AppProvider();
    });

    test('TC-WIZARD-01: AutoTranslationService transliterates & translates bilingual profile correctly', () async {
      const input = ApplicantProfileInput(
        name: 'Dr. Ameer Al-Hatemi',
        bio: 'Leading researcher in AI and mobile stream computing.',
        institution: 'King Fahd University of Petroleum and Minerals',
        venueName: 'Grand Innovation Auditorium',
        isOrganization: false,
      );

      final result = await AutoTranslationService.translateAndTransliterate(input);

      expect(result.nameEn.isNotEmpty, isTrue);
      expect(result.nameAr.isNotEmpty, isTrue);
      expect(result.bioEn.isNotEmpty, isTrue);
      expect(result.bioAr.isNotEmpty, isTrue);
      expect(result.institutionEn.isNotEmpty, isTrue);
      expect(result.institutionAr.isNotEmpty, isTrue);
      expect(result.academicTitleEn, isNotNull);
      expect(result.academicTitleAr, isNotNull);
    });

    test('TC-WIZARD-02: BroadcasterApplicationModel creates valid pending model with media URLs', () {
      final app = BroadcasterApplicationModel(
        id: 'test-app-001',
        applicantProfileId: 'user-profile-uuid-1234',
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Amir Al-Hatemi',
        applicantNameAr: 'أمير الحاتمي',
        email: 'amir@example.com',
        phone: '+966501234567',
        academicTitleEn: 'Lecturer & Cloud Architect',
        academicTitleAr: 'محاضر ومهندس سحابي',
        institutionEn: 'Tech Academy',
        institutionAr: 'أكاديمية التقنية',
        categoryId: 'cs_tech',
        tags: const ['#AI', '#Cloud'],
        venueNameEn: 'Khobar Innovation Hub',
        venueNameAr: 'مركز الابتكار بالخبر',
        latitude: 26.2871,
        longitude: 50.2125,
        youtubeChannelUrl: 'https://youtube.com/@amirtech',
        youtubeHandle: 'amirtech',
        bioEn: 'Pioneering streaming architectures.',
        bioAr: 'باحث في تقنيات البث المباشر.',
        avatarUrl: 'https://storage.supabase.co/streamer-assets/avatar_123.jpg',
        bannerUrl: 'https://storage.supabase.co/streamer-assets/banner_123.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime(2026, 8, 24),
      );

      expect(app.isPending, isTrue);
      expect(app.isApproved, isFalse);
      expect(app.avatarUrl, contains('supabase.co'));
      expect(app.bannerUrl, contains('supabase.co'));
      expect(app.latitude, equals(26.2871));
      expect(app.longitude, equals(50.2125));
    });

    test('TC-WIZARD-03: Staged approval pipeline executes all 5 stages and plots streamer on Map & Feed', () async {
      final app = BroadcasterApplicationModel(
        id: 'stage-app-999',
        applicantProfileId: 'profile-uuid-999',
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Professor Sarah Al-Dosari',
        applicantNameAr: 'أ.د. سارة الدوسري',
        email: 'sarah@example.com',
        phone: '+966555555555',
        academicTitleEn: 'Professor of Computer Science',
        academicTitleAr: 'أستاذ علوم الحاسب',
        institutionEn: 'KFUPM',
        institutionAr: 'جامعة الملك فهد',
        categoryId: 'cs_tech',
        tags: const ['#AI', '#Algorithms'],
        venueNameEn: 'Dhahran Cyber Hall',
        venueNameAr: 'قاعة الظهران السيبرانية',
        latitude: 26.3050,
        longitude: 50.1450,
        youtubeChannelUrl: 'https://youtube.com/@sarah_cs',
        youtubeHandle: 'sarah_cs',
        bioEn: 'AI & Data Science Professor delivering open lectures.',
        bioAr: 'أستاذة الذكاء الاصطناعي وعلوم البيانات.',
        avatarUrl: 'https://storage.supabase.co/streamer-assets/avatar_sarah.jpg',
        bannerUrl: 'https://storage.supabase.co/streamer-assets/banner_sarah.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      // Submit application into provider
      await provider.submitBroadcasterApplication(app);

      // List of recorded progress stages
      final List<int> completedStages = [];
      final List<String> stageMessages = [];

      final success = await provider.approveBroadcasterApplication(
        app.id,
        adminNotes: 'Verified official university credentials.',
        onProgress: (stage, desc) {
          completedStages.add(stage);
          stageMessages.add(desc);
        },
      );

      expect(success, isTrue);
      expect(completedStages, containsAll([1, 2, 3, 4, 5]));
      expect(stageMessages.length, equals(5));

      // Verify the new streamer is in provider.streamers
      final matching = provider.streamers.where((s) => s.fullNameEn.contains('Sarah')).toList();
      expect(matching.isNotEmpty, isTrue);
      final streamer = matching.first;
      expect(streamer.fullNameEn, equals('Professor Sarah Al-Dosari'));
      expect(streamer.isVerified, isTrue);
      expect(streamer.latitude, equals(26.3050));
      expect(streamer.longitude, equals(50.1450));
      expect(streamer.avatarUrl, equals('https://storage.supabase.co/streamer-assets/avatar_sarah.jpg'));
    });
  });
}
