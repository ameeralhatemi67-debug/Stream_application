/// Comprehensive Domain Lexicon & Gazetteer for Academic Titles, Universities,
/// Saudi Geographic Venues, and Educational Disciplines.
class AcademicLexiconService {
  //  Academic & Professional Titles (Arabic -> English)
  static const Map<String, String> _titlesArToEn = {
    'أستاذ دكتور': 'Distinguished Professor',
    'بروفيسور': 'Professor',
    'أستاذ مشارك': 'Associate Professor',
    'أستاذ مساعد': 'Assistant Professor',
    'محاضر': 'Lecturer',
    'معيد': 'Teaching Assistant',
    'باحث أكاديمي': 'Academic Researcher',
    'طبيب استشاري': 'Consultant Physician',
    'طبيب أخصائي': 'Specialist Physician',
    'مهندس استشاري': 'Consultant Engineer',
    'مدرب معتمد': 'Certified Trainer',
    'مدرب رئيسي لاختبار آيلتس': 'Lead IELTS Instructor',
    'داعية إسلامي': 'Islamic Scholar & Educator',
    'مقدم برامج تعليمية': 'Academic Broadcaster',
    'ممثل الجهة الأكاديمية': 'Organization Representative',
    'باحث مستقل': 'Independent Scholar',
    'مدرب ومحاضر': 'Trainer & Lecturer',
    'استشاري تقنية المعلومات': 'IT Consultant',
    'مختص ذكاء اصطناعي': 'AI Specialist',
  };

  //  Universities & Organizations (Arabic -> English)
  static const Map<String, String> _institutionsArToEn = {
    'جامعة الملك فهد للبترول والمعادن': 'King Fahd University of Petroleum and Minerals',
    'جامعة الإمام عبدالرحمن بن فيصل': 'Imam Abdulrahman Bin Faisal University',
    'جامعة الملك فيصل': 'King Faisal University',
    'جامعة الملك سعود': 'King Saud University',
    'جامعة الملك عبدالعزيز': 'King Abdulaziz University',
    'أكاديمية دليلك التعليمية': 'Dalilk Educational Academy',
    'أكاديمية طويق': 'Tuwaiq Academy',
    'أكاديمية مسك': 'Misk Academy',
    'الهيئة السعودية للبيانات والذكاء الاصطناعي': 'SDAIA',
  };

  //  Saudi Cities & Regions (Arabic -> English)
  static const Map<String, String> _citiesArToEn = {
    'الخبر': 'Al Khobar',
    'الظهران': 'Dhahran',
    'الدمام': 'Dammam',
    'الجبيل': 'Jubail',
    'الأحساء': 'Al-Ahsa',
    'القطيف': 'Qatif',
    'الرياض': 'Riyadh',
    'جدة': 'Jeddah',
    'مكة المكرمة': 'Makkah',
    'المدينة المنورة': 'Madinah',
    'حفر الباطن': 'Hafar Al-Batin',
    'رأس تنورة': 'Ras Tanura',
    'المنطقة الشرقية': 'Eastern Province',
  };

  //  Venue Components & Buildings (Arabic -> English)
  static const Map<String, String> _venuePhrasesArToEn = {
    'قاعة الابتكار والمؤتمرات الكبرى': 'Grand Innovation & Conference Hall',
    'قاعة الابتكار': 'Innovation Hall',
    'المدرج الرئيسي': 'Main Auditorium',
    'مدرج المؤتمرات': 'Conference Auditorium',
    'مركز المؤتمرات والمعارض': 'Exhibition & Conference Center',
    'مركز المؤتمرات': 'Conference Center',
    'الحرم الجامعي الرئيسي': 'Main University Campus',
    'الحرم الرئيسي': 'Main Campus',
    'المقر الرئيسي': 'Main Headquarters (HQ)',
    'فرع الخبر': 'Al Khobar Branch',
    'فرع الدمام': 'Dammam Branch',
    'فرع الظهران': 'Dhahran Branch',
    'فرع الأحساء': 'Al-Ahsa Branch',
    'مركز التدريب والتطوير': 'Training & Development Center',
    'مكتبة الملك فهد': 'King Fahd Library',
    'مركز رعاية الموهوبين': 'Talent & Gifted Center',
  };

  //  Academic Disciplines & Categories (Arabic -> English)
  static const Map<String, String> _categoriesArToEn = {
    'علوم الحاسب والذكاء الاصطناعي': 'Computer Science & AI',
    'الدراسات الإسلامية والشريعة': 'Islamic Studies & Sharia',
    'أكاديمية اللغات والآيلتس': 'Languages & IELTS Academy',
    'الهندسة والابتكار': 'Engineering & Innovation',
    'الطب والصحة السريرية': 'Medicine & Clinical Health',
    'الثقافة والتعليم العام': 'Culture & General Education',
  };

  // Reverse Maps (English -> Arabic)
  static final Map<String, String> _titlesEnToAr = _invertMap(_titlesArToEn);
  static final Map<String, String> _institutionsEnToAr = _invertMap(_institutionsArToEn);
  static final Map<String, String> _citiesEnToAr = _invertMap(_citiesArToEn);
  static final Map<String, String> _venuePhrasesEnToAr = _invertMap(_venuePhrasesArToEn);
  static final Map<String, String> _categoriesEnToAr = _invertMap(_categoriesArToEn);

  static Map<String, String> _invertMap(Map<String, String> source) {
    return source.map((k, v) => MapEntry(v.toLowerCase(), k));
  }

  /// Translates Academic Titles between Arabic and English
  static String translateTitle(String input, {required bool isArabicInput}) {
    final clean = input.trim();
    if (clean.isEmpty) return '';

    if (isArabicInput) {
      if (_titlesArToEn.containsKey(clean)) return _titlesArToEn[clean]!;
      for (final entry in _titlesArToEn.entries) {
        if (clean.contains(entry.key)) {
          return clean.replaceAll(entry.key, entry.value);
        }
      }
      return clean;
    } else {
      final lower = clean.toLowerCase();
      if (_titlesEnToAr.containsKey(lower)) return _titlesEnToAr[lower]!;
      for (final entry in _titlesEnToAr.entries) {
        if (lower.contains(entry.key)) {
          return clean.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
        }
      }
      return clean;
    }
  }

  /// Translates Universities and Institutions
  static String translateInstitution(String input, {required bool isArabicInput}) {
    final clean = input.trim();
    if (clean.isEmpty) return '';

    if (isArabicInput) {
      if (_institutionsArToEn.containsKey(clean)) return _institutionsArToEn[clean]!;
      for (final entry in _institutionsArToEn.entries) {
        if (clean.contains(entry.key)) {
          return clean.replaceAll(entry.key, entry.value);
        }
      }
      return clean;
    } else {
      final lower = clean.toLowerCase();
      if (_institutionsEnToAr.containsKey(lower)) return _institutionsEnToAr[lower]!;
      for (final entry in _institutionsEnToAr.entries) {
        if (lower.contains(entry.key)) {
          return clean.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
        }
      }
      return clean;
    }
  }

  /// Translates Geographic Venues, Halls, and Campuses
  static String translateVenue(String input, {required bool isArabicInput}) {
    final clean = input.trim();
    if (clean.isEmpty) return '';

    if (isArabicInput) {
      String translated = clean;
      // Replace known venue phrases
      for (final entry in _venuePhrasesArToEn.entries) {
        translated = translated.replaceAll(entry.key, entry.value);
      }
      // Replace known cities
      for (final entry in _citiesArToEn.entries) {
        translated = translated.replaceAll(entry.key, entry.value);
      }
      return translated;
    } else {
      String translated = clean;
      for (final entry in _venuePhrasesEnToAr.entries) {
        translated = translated.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
      }
      for (final entry in _citiesEnToAr.entries) {
        translated = translated.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
      }
      return translated;
    }
  }

  /// Translates Academic Disciplines and Categories
  static String translateCategory(String input, {required bool isArabicInput}) {
    final clean = input.trim();
    if (clean.isEmpty) return '';

    if (isArabicInput) {
      return _categoriesArToEn[clean] ?? clean;
    } else {
      return _categoriesEnToAr[clean.toLowerCase()] ?? clean;
    }
  }
}
