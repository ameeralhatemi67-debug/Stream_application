// Test-only fixtures: the two sample broadcaster applications that used to be
// seeded into AdminDatabaseService at runtime. The runtime seeding was removed
// (P1.6 dev identity / P2 truthful data) so the review queue only ever shows
// real submissions; tests that exercise the approve/reject workflow submit
// these explicitly instead.
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';

List<BroadcasterApplicationModel> sampleBroadcasterApplications() {
  return [

      BroadcasterApplicationModel(
        id: 'app_kfupm_ai_01',
        accountType: ApplicationAccountType.organizationVenue,
        applicantNameEn: 'KFUPM AI & Robotics Research Center',
        applicantNameAr:
            'مركز بحوث الذكاء الاصطناعي والروبوتات بجامعة الملك فهد',
        email: 'ai.center@kfupm.edu.sa',
        phone: '+966 13 860 0000',
        academicTitleEn: 'Research Institution & Venue',
        academicTitleAr: 'مؤسسة بحثية وقاعة فعاليات',
        institutionEn: 'King Fahd University of Petroleum & Minerals',
        institutionAr: 'جامعة الملك فهد للبترول والمعادن',
        categoryId: 'cs_tech',
        tags: const ['#AI', '#Robotics', '#KFUPM', '#Academic'],
        organizationType: 'University Research Center & Auditorium',
        venueNameEn: 'KFUPM Building 24 Grand Auditorium',
        venueNameAr: 'جامعة الملك فهد - مدرج مبنى 24 الرئيسي',
        latitude: 26.3050,
        longitude: 50.1450,
        seatingCapacity: 450,
        officialWebsiteUrl: 'https://kfupm.edu.sa/ai-center',
        youtubeChannelUrl: 'https://youtube.com/@kfupm_ai_center',
        youtubeHandle: 'kfupm_ai_center',
        bioEn:
            'Leading academic hub for advanced artificial intelligence, machine learning seminars, and autonomous systems research in the Eastern Province.',
        bioAr:
            'المركز الأكاديمي الرائد لأبحاث الذكاء الاصطناعي، والتعلم الآلي، والندوات العلمية للأنظمة الذكية في المنطقة الشرقية.',
        avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        bannerUrl: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      BroadcasterApplicationModel(
        id: 'app_dr_tariq_02',
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Dr. Tariq Al-Mansoor',
        applicantNameAr: 'د. طارق المنصور',
        email: 'tariq.mansoor@iau.edu.sa',
        phone: '+966 50 123 4567',
        academicTitleEn: 'Associate Professor of Clinical Medicine',
        academicTitleAr: 'أستاذ مشارك في الطب الباطني والجراحة',
        institutionEn: 'Imam Abdulrahman Bin Faisal University',
        institutionAr: 'جامعة الإمام عبدالرحمن بن فيصل',
        categoryId: 'medical_health',
        tags: const ['#Medicine', '#Cardiology', '#HealthScience'],
        venueNameEn: 'King Fahd Hospital University Auditorium',
        venueNameAr: 'مستشفى الملك فهد الجامعي - القاعة الكبرى',
        latitude: 26.4207,
        longitude: 50.0888,
        youtubeChannelUrl: 'https://youtube.com/@dr_tariq_medicine',
        youtubeHandle: 'dr_tariq_medicine',
        bioEn:
            'Consultant and academic lecturer specializing in internal medicine, public health informatics, and clinical medical conferences.',
        bioAr:
            'استشاري ومحاضر أكاديمي متخصص في الطب الباطني، ونظم المعلوماتية الصحية، والمؤتمرات الطبية السريرية.',
        avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        bannerUrl: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
  ];
}
