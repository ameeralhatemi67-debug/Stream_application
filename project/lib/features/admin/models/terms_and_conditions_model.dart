import 'package:flutter/foundation.dart';

/// Platform Terms of Service, Broadcaster Guidelines, and Privacy Policy Model
@immutable
class TermsAndConditionsModel {
  final String version;
  final DateTime lastUpdated;
  final String termsOfServiceEn;
  final String termsOfServiceAr;
  final String broadcasterGuidelinesEn;
  final String broadcasterGuidelinesAr;
  final String privacyPolicyEn;
  final String privacyPolicyAr;

  const TermsAndConditionsModel({
    required this.version,
    required this.lastUpdated,
    required this.termsOfServiceEn,
    required this.termsOfServiceAr,
    required this.broadcasterGuidelinesEn,
    required this.broadcasterGuidelinesAr,
    required this.privacyPolicyEn,
    required this.privacyPolicyAr,
  });

  String getLocalizedTerms(String languageCode) =>
      languageCode == 'ar' ? termsOfServiceAr : termsOfServiceEn;

  String getLocalizedGuidelines(String languageCode) =>
      languageCode == 'ar' ? broadcasterGuidelinesAr : broadcasterGuidelinesEn;

  String getLocalizedPrivacy(String languageCode) =>
      languageCode == 'ar' ? privacyPolicyAr : privacyPolicyEn;

  TermsAndConditionsModel copyWith({
    String? version,
    DateTime? lastUpdated,
    String? termsOfServiceEn,
    String? termsOfServiceAr,
    String? broadcasterGuidelinesEn,
    String? broadcasterGuidelinesAr,
    String? privacyPolicyEn,
    String? privacyPolicyAr,
  }) {
    return TermsAndConditionsModel(
      version: version ?? this.version,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      termsOfServiceEn: termsOfServiceEn ?? this.termsOfServiceEn,
      termsOfServiceAr: termsOfServiceAr ?? this.termsOfServiceAr,
      broadcasterGuidelinesEn:
          broadcasterGuidelinesEn ?? this.broadcasterGuidelinesEn,
      broadcasterGuidelinesAr:
          broadcasterGuidelinesAr ?? this.broadcasterGuidelinesAr,
      privacyPolicyEn: privacyPolicyEn ?? this.privacyPolicyEn,
      privacyPolicyAr: privacyPolicyAr ?? this.privacyPolicyAr,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'lastUpdated': lastUpdated.toIso8601String(),
        'termsOfServiceEn': termsOfServiceEn,
        'termsOfServiceAr': termsOfServiceAr,
        'broadcasterGuidelinesEn': broadcasterGuidelinesEn,
        'broadcasterGuidelinesAr': broadcasterGuidelinesAr,
        'privacyPolicyEn': privacyPolicyEn,
        'privacyPolicyAr': privacyPolicyAr,
      };

  factory TermsAndConditionsModel.fromJson(Map<String, dynamic> json) =>
      TermsAndConditionsModel(
        version: json['version'] as String? ?? 'v1.0.0',
        lastUpdated: DateTime.parse(
            json['lastUpdated'] as String? ?? DateTime.now().toIso8601String()),
        termsOfServiceEn: json['termsOfServiceEn'] as String? ?? '',
        termsOfServiceAr: json['termsOfServiceAr'] as String? ?? '',
        broadcasterGuidelinesEn:
            json['broadcasterGuidelinesEn'] as String? ?? '',
        broadcasterGuidelinesAr:
            json['broadcasterGuidelinesAr'] as String? ?? '',
        privacyPolicyEn: json['privacyPolicyEn'] as String? ?? '',
        privacyPolicyAr: json['privacyPolicyAr'] as String? ?? '',
      );

  static TermsAndConditionsModel createDefault() {
    return TermsAndConditionsModel(
      version: 'v1.0.0',
      lastUpdated: DateTime(2026, 8, 17),
      termsOfServiceEn: '''
# Educational Cloud Streaming Platform — Terms of Service

## 1. Acceptance of Terms
By accessing or using the Educational Cloud Streaming Platform ("Streamer App"), you agree to comply with and be bound by these Terms of Service.

## 2. Educational Purpose & Content Scope
The platform is dedicated strictly to academic lectures, research presentations, cultural seminars, and scientific knowledge dissemination within Saudi Arabia and globally.

## 3. User Conduct & Prohibitions
- Defamatory, obscene, or fraudulent broadcasts are strictly prohibited.
- Impersonation of academic faculty or educational institutions is grounds for immediate termination.
- All live broadcasts must respect Saudi cultural values and applicable laws.

## 4. Broadcaster Verification
Broadcaster and Organization verification is granted subject to manual administrative review and may be revoked at any time for non-compliance.
''',
      termsOfServiceAr: '''
# منصة البث السحابي التعليمية — شروط الخدمة

## ١. قبول الشروط
بوصولك إلى منصة البث السحابي التعليمية أو استخدامها، فإنك توافق على الالتزام بشروط الخدمة هذه.

## ٢. الغرض التعليمي ونطاق المحتوى
المنصة مخصصة حصرياً للمحاضرات الأكاديمية، والندوات العلمية، والملتقيات الثقافية، ونشر المعرفة العلمية داخل المملكة العربية السعودية وعالمياً.

## ٣. سلوك المستخدم والمحظورات
- يُحظر تماماً بث أي محتوى مسيء، أو غير لائق، أو مضلل.
- يُعد انتحال صفة أعضاء هيئة التدريس أو المؤسسات التعليمية سبباً للإيقاف الفوري.
- يجب أن تلتزم جميع عمليات البث بالقيم والثوابت الوطنية والأنظمة المعمول بها.

## ٤. توثيق المذيعين والمؤسسات
يُمنح توثيق المذيعين والمؤسسات بعد مراجعة إدارية دقيقة، ويحق للإدارة سحب التوثيق في حال مخالفة الشروط.
''',
      broadcasterGuidelinesEn: '''
# Broadcaster Code of Conduct & Streaming Guidelines

1. **Academic Integrity:** All presentations, slides, and lectures must cite original sources and maintain high academic rigor.
2. **Physical Venue Safety:** When streaming from a physical auditorium, ensure attendee safety and adhere to venue occupancy limits.
3. **Audio-Visual Quality:** Streams should maintain clear audio levels and minimum 720p video resolution.
4. **Live Interaction:** Maintain a respectful, constructive environment in live Q&A and chat rooms.
''',
      broadcasterGuidelinesAr: '''
# ميثاق سلوك المذيع وإرشادات البث الأكاديمي

١. **الأمانة الأكاديمية:** يجب أن تلتزم كافة العروض والمحاضرات بذكر المصادر العلمية والمعايير الأكاديمية الرصينة.
٢. **سلامة القاعات الميدانية:** عند البث من قاعة أو مدرج فعلي، يجب مراعاة سلامة الحضور والطاقة الاستيعابية للقاعة.
٣. **جودة الصوت والصورة:** يجب توفير بث صوتي نقي وصورة لا تقل دقتها عن 720p.
٤. **التفاعل المباشر:** الحفاظ على بيئة نقاش محترمة وبناءة في غرف الأسئلة والمحادثة المباشرة.
''',
      privacyPolicyEn: '''
# Privacy Policy & Data Protection (Saudi PDPL Compliance)

1. **Data Collection:** We collect only essential profile information (Google OAuth name, email) required for verification and platform operation.
2. **Geospatial Privacy:** Physical venue coordinates represent public lecture halls and not private residences.
3. **No Commercial Resale:** User data is never sold or shared with unauthorized third parties.
''',
      privacyPolicyAr: '''
# سياسة الخصوصية وحماية البيانات (متوافق مع نظام حماية البيانات الشخصية السعودي)

١. **جمع البيانات:** نجمع فقط البيانات الأساسية اللازمة للتوثيق وتشغيل الحسابات (الاسم والبريد عبر Google OAuth).
٢. **الخصوصية المكانية:** تمثل الإحداثيات الجغرافية القاعات والمدرجات العامة المعتمدة ولا تمثل مواقع خاصة.
٣. **عدم البيع التجاري:** لا يتم بيع أو مشاركة بيانات المستخدمين مع أي جهات خارجية غير مصرح لها.
''',
    );
  }
}
