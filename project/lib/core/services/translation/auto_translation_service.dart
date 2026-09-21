import 'arabic_transliteration_engine.dart';
import 'academic_lexicon_service.dart';

/// Applicant profile payload to be converted into bilingual representation
class ApplicantProfileInput {
  final String name;
  final String? bio;
  final String? academicTitle;
  final String? institution;
  final String? venueName;
  final bool isOrganization;

  const ApplicantProfileInput({
    required this.name,
    this.bio,
    this.academicTitle,
    this.institution,
    this.venueName,
    this.isOrganization = false,
  });
}

/// Fully populated bilingual result container
class BilingualProfileData {
  final String nameEn;
  final String nameAr;
  final String bioEn;
  final String bioAr;
  final String academicTitleEn;
  final String academicTitleAr;
  final String institutionEn;
  final String institutionAr;
  final String venueNameEn;
  final String venueNameAr;

  const BilingualProfileData({
    required this.nameEn,
    required this.nameAr,
    required this.bioEn,
    required this.bioAr,
    required this.academicTitleEn,
    required this.academicTitleAr,
    required this.institutionEn,
    required this.institutionAr,
    required this.venueNameEn,
    required this.venueNameAr,
  });
}

/// Pluggable interface for future translation backends (OmniRoute LLM, Cloud APIs)
abstract class TranslationProvider {
  Future<String> translateText(String text, {required bool fromArabicToEnglish});
}

/// Pure-Dart offline local rule provider
class PureDartLocalTranslationProvider implements TranslationProvider {
  const PureDartLocalTranslationProvider();

  @override
  Future<String> translateText(String text, {required bool fromArabicToEnglish}) async {
    if (text.trim().isEmpty) return '';

    // 1. Check full phrase & composite mappings first
    String result = _translateHeuristicPhrases(text, fromArabicToEnglish: fromArabicToEnglish);
    if (result != text) return result;

    // 2. Check domain lexicons
    final translatedTitle = AcademicLexiconService.translateTitle(text, isArabicInput: fromArabicToEnglish);
    if (translatedTitle != text) return translatedTitle;

    final translatedVenue = AcademicLexiconService.translateVenue(text, isArabicInput: fromArabicToEnglish);
    if (translatedVenue != text) return translatedVenue;

    final translatedInst = AcademicLexiconService.translateInstitution(text, isArabicInput: fromArabicToEnglish);
    if (translatedInst != text) return translatedInst;

    return result;
  }

  String _translateHeuristicPhrases(String text, {required bool fromArabicToEnglish}) {
    // Ordered from longest phrase to shortest component
    const List<MapEntry<String, String>> phrasePairs = [
      MapEntry('مدرب معتمد في الذكاء الاصطناعي', 'Certified Trainer in Artificial Intelligence'),
      MapEntry('مدرب معتمد في هندسة البرمجيات', 'Certified Trainer in Software Engineering'),
      MapEntry('مدرب معتمد في علوم الحاسب', 'Certified Trainer in Computer Science'),
      MapEntry('محاضر وباحث أكاديمي', 'Academic Lecturer & Researcher'),
      MapEntry('مقدم برامج تعليمية', 'Academic Broadcaster'),
      MapEntry('طبيب استشاري وباحث سريري', 'Consultant Physician & Clinical Researcher'),
      MapEntry('مهندس استشاري في الطاقة المتجددة', 'Consultant Engineer in Renewable Energy'),
      MapEntry('مؤسسة تعليمية غير ربحية', 'Non-Profit Educational Institution'),
      MapEntry('صرح تعليمي وأكاديمية معتمدة', 'Accredited Academy & Educational Institution'),
      MapEntry('أعضاء هيئة التدريس الأساسية', 'Core Faculty Members'),
      MapEntry('مدرب رئيسي لاختبار آيلتس', 'Lead IELTS Instructor'),
      MapEntry('محاضر زائر', 'Guest Speaker'),
      MapEntry('مدرب رئيسي', 'Lead Instructor'),
      MapEntry('مدرب معتمد', 'Certified Trainer'),
      MapEntry('الذكاء الاصطناعي', 'Artificial Intelligence'),
      MapEntry('هندسة البرمجيات', 'Software Engineering'),
      MapEntry('علوم الحاسب', 'Computer Science'),
      MapEntry('الدراسات الإسلامية', 'Islamic Studies'),
      MapEntry('الطاقة المتجددة', 'Renewable Energy'),
      MapEntry('باحث سريري', 'Clinical Researcher'),
      MapEntry('باحث أكاديمي', 'Academic Researcher'),
      MapEntry('في ', 'in '),
      MapEntry('و ', ' & '),
    ];

    if (fromArabicToEnglish) {
      String res = text;
      for (final pair in phrasePairs) {
        res = res.replaceAll(pair.key, pair.value);
      }
      return res;
    } else {
      String res = text;
      for (final pair in phrasePairs) {
        res = res.replaceAll(RegExp(RegExp.escape(pair.value), caseSensitive: false), pair.key);
      }
      return res;
    }
  }
}

/// Unified Auto-Translation & Transliteration Service Facade
class AutoTranslationService {
  static TranslationProvider _activeProvider = const PureDartLocalTranslationProvider();
  static final Map<String, String> _cache = {};

  /// Configures custom translation provider (e.g. for future OmniRoute or Cloud APIs)
  static void setProvider(TranslationProvider provider) {
    _activeProvider = provider;
  }

  /// Processes raw applicant input and returns a fully populated bilingual record
  static Future<BilingualProfileData> translateAndTransliterate(ApplicantProfileInput input) async {
    final rawName = input.name.trim();
    final rawBio = (input.bio ?? '').trim();
    final rawTitle = (input.academicTitle ?? '').trim();
    final rawInstitution = (input.institution ?? '').trim();
    final rawVenue = (input.venueName ?? '').trim();

    final isNameArabic = ArabicTransliterationEngine.isArabicText(rawName);

    // 1. Personal Name Transliteration (Phonetic Sound Mapping)
    final String nameEn;
    final String nameAr;
    if (isNameArabic) {
      nameAr = rawName;
      nameEn = ArabicTransliterationEngine.transliterateArabicToEnglish(rawName);
    } else {
      nameEn = rawName;
      nameAr = ArabicTransliterationEngine.transliterateEnglishToArabic(rawName);
    }

    // 2. Academic Title Translation
    final String titleEn;
    final String titleAr;
    if (rawTitle.isNotEmpty) {
      final isTitleAr = ArabicTransliterationEngine.isArabicText(rawTitle);
      if (isTitleAr) {
        titleAr = rawTitle;
        titleEn = AcademicLexiconService.translateTitle(rawTitle, isArabicInput: true);
      } else {
        titleEn = rawTitle;
        titleAr = AcademicLexiconService.translateTitle(rawTitle, isArabicInput: false);
      }
    } else {
      titleEn = input.isOrganization ? 'Organization Representative' : 'Academic Broadcaster';
      titleAr = input.isOrganization ? 'ممثل الجهة الأكاديمية' : 'مقدم برامج تعليمية';
    }

    // 3. Institution / Academy Translation
    final String institutionEn;
    final String institutionAr;
    if (rawInstitution.isNotEmpty) {
      final isInstAr = ArabicTransliterationEngine.isArabicText(rawInstitution);
      if (isInstAr) {
        institutionAr = rawInstitution;
        institutionEn = AcademicLexiconService.translateInstitution(rawInstitution, isArabicInput: true);
      } else {
        institutionEn = rawInstitution;
        institutionAr = AcademicLexiconService.translateInstitution(rawInstitution, isArabicInput: false);
      }
    } else {
      institutionEn = input.isOrganization ? '$nameEn Campus' : 'Independent Scholar';
      institutionAr = input.isOrganization ? 'حرم $nameAr' : 'باحث مستقل';
    }

    // 4. Venue Name & Hall Translation
    final String venueEn;
    final String venueAr;
    if (rawVenue.isNotEmpty) {
      final isVenueAr = ArabicTransliterationEngine.isArabicText(rawVenue);
      if (isVenueAr) {
        venueAr = rawVenue;
        venueEn = AcademicLexiconService.translateVenue(rawVenue, isArabicInput: true);
      } else {
        venueEn = rawVenue;
        venueAr = AcademicLexiconService.translateVenue(rawVenue, isArabicInput: false);
      }
    } else {
      venueEn = input.isOrganization ? '$nameEn HQ Auditorium' : 'Al Khobar Educational Center';
      venueAr = input.isOrganization ? 'مدرج $nameAr الرئيسي' : 'مركز الخبر التعليمي';
    }

    // 5. Biography & Descriptions Translation
    final String bioEn;
    final String bioAr;
    if (rawBio.isNotEmpty) {
      final isBioAr = ArabicTransliterationEngine.isArabicText(rawBio);
      if (isBioAr) {
        bioAr = rawBio;
        bioEn = await _translateWithCache(rawBio, fromArabicToEnglish: true);
      } else {
        bioEn = rawBio;
        bioAr = await _translateWithCache(rawBio, fromArabicToEnglish: false);
      }
    } else {
      bioEn = '';
      bioAr = '';
    }

    return BilingualProfileData(
      nameEn: nameEn,
      nameAr: nameAr,
      bioEn: bioEn,
      bioAr: bioAr,
      academicTitleEn: titleEn,
      academicTitleAr: titleAr,
      institutionEn: institutionEn,
      institutionAr: institutionAr,
      venueNameEn: venueEn,
      venueNameAr: venueAr,
    );
  }

  static Future<String> _translateWithCache(String text, {required bool fromArabicToEnglish}) async {
    final cacheKey = '${fromArabicToEnglish ? "ar2en" : "en2ar"}:$text';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final translated = await _activeProvider.translateText(text, fromArabicToEnglish: fromArabicToEnglish);
    _cache[cacheKey] = translated;
    return translated;
  }
}
