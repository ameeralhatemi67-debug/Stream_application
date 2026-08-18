import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/services/translation/arabic_transliteration_engine.dart';
import 'package:streamer_app/core/services/translation/academic_lexicon_service.dart';
import 'package:streamer_app/core/services/translation/auto_translation_service.dart';

void main() {
  group('TC-TR-01: Pure-Dart ArabicTransliterationEngine Phonetic Mapping Tests', () {
    test('Transliterates Saudi/Arab names without semantic corruption', () {
      // "أمير الحاتمي" must NOT become "Prince of the Decisive"
      expect(
        ArabicTransliterationEngine.transliterateArabicToEnglish('أمير الحاتمي'),
        equals('Amir Al-Hatemi'),
      );

      // "عسير يوسف" must NOT become "Difficult Joseph"
      expect(
        ArabicTransliterationEngine.transliterateArabicToEnglish('عسير يوسف'),
        equals('Aseer Yusuf'),
      );

      // "فيصل العقل" must NOT become "Separator of the Brain"
      expect(
        ArabicTransliterationEngine.transliterateArabicToEnglish('فيصل العقل'),
        equals('Faisal Al-Aql'),
      );

      expect(
        ArabicTransliterationEngine.transliterateArabicToEnglish('سارة الدوسري'),
        equals('Sarah Al-Dosari'),
      );
    });

    test('Handles theophoric compound names with proper prefixes', () {
      expect(
        ArabicTransliterationEngine.transliterateArabicToEnglish('عبدالرحمن بن سعود الدوسري'),
        equals('Abdulrahman bin Saud Al-Dosari'),
      );

      expect(
        ArabicTransliterationEngine.transliterateArabicToEnglish('عبدالله الغامدي'),
        equals('Abdullah Al-Ghamdi'),
      );

      expect(
        ArabicTransliterationEngine.transliterateArabicToEnglish('عبد العزيز بن سلمان'),
        equals('Abdulaziz bin Salman'),
      );
    });

    test('Performs English to Arabic phonetic Arabization', () {
      expect(
        ArabicTransliterationEngine.transliterateEnglishToArabic('Amir Al-Hatemi'),
        equals('أمير الحاتمي'),
      );

      expect(
        ArabicTransliterationEngine.transliterateEnglishToArabic('Alex Thompson'),
        equals('أليكس تومسون'),
      );
    });

    test('Correctly detects Arabic vs English text', () {
      expect(ArabicTransliterationEngine.isArabicText('أمير الحاتمي'), isTrue);
      expect(ArabicTransliterationEngine.isArabicText('Amir Al-Hatemi'), isFalse);
      expect(ArabicTransliterationEngine.isArabicText(''), isFalse);
    });
  });

  group('TC-TR-02: AcademicLexiconService Domain Translation Tests', () {
    test('Bidirectionally translates faculty & academic ranks', () {
      expect(
        AcademicLexiconService.translateTitle('أستاذ مشارك', isArabicInput: true),
        equals('Associate Professor'),
      );

      expect(
        AcademicLexiconService.translateTitle('Associate Professor', isArabicInput: false),
        equals('أستاذ مشارك'),
      );

      expect(
        AcademicLexiconService.translateTitle('طبيب استشاري', isArabicInput: true),
        equals('Consultant Physician'),
      );

      expect(
        AcademicLexiconService.translateTitle('مدرب رئيسي لاختبار آيلتس', isArabicInput: true),
        equals('Lead IELTS Instructor'),
      );
    });

    test('Translates Saudi Universities & Organizations', () {
      expect(
        AcademicLexiconService.translateInstitution(
          'جامعة الملك فهد للبترول والمعادن',
          isArabicInput: true,
        ),
        equals('King Fahd University of Petroleum and Minerals'),
      );

      expect(
        AcademicLexiconService.translateInstitution(
          'King Fahd University of Petroleum and Minerals',
          isArabicInput: false,
        ),
        equals('جامعة الملك فهد للبترول والمعادن'),
      );
    });

    test('Translates Venues & Eastern Province Cities', () {
      expect(
        AcademicLexiconService.translateVenue(
          'قاعة الابتكار والمؤتمرات الكبرى',
          isArabicInput: true,
        ),
        equals('Grand Innovation & Conference Hall'),
      );

      expect(
        AcademicLexiconService.translateVenue(
          'Innovation Hall',
          isArabicInput: false,
        ),
        equals('قاعة الابتكار'),
      );
    });
  });

  group('TC-TR-03: AutoTranslationService End-to-End Orchestration Tests', () {
    test('Populates full bilingual profile when user submits in Arabic', () async {
      const input = ApplicantProfileInput(
        name: 'أمير الحاتمي',
        bio: 'مدرب معتمد في الذكاء الاصطناعي',
        academicTitle: 'أستاذ مشارك',
        institution: 'جامعة الملك فهد للبترول والمعادن',
        venueName: 'قاعة الابتكار',
        isOrganization: false,
      );

      final bilingual = await AutoTranslationService.translateAndTransliterate(input);

      // Name is phonetically transliterated
      expect(bilingual.nameAr, equals('أمير الحاتمي'));
      expect(bilingual.nameEn, equals('Amir Al-Hatemi'));

      // Title is semantically translated
      expect(bilingual.academicTitleAr, equals('أستاذ مشارك'));
      expect(bilingual.academicTitleEn, equals('Associate Professor'));

      // Institution is translated
      expect(bilingual.institutionAr, equals('جامعة الملك فهد للبترول والمعادن'));
      expect(bilingual.institutionEn, equals('King Fahd University of Petroleum and Minerals'));

      // Venue is translated
      expect(bilingual.venueNameAr, equals('قاعة الابتكار'));
      expect(bilingual.venueNameEn, equals('Innovation Hall'));

      // Bio is translated
      expect(bilingual.bioAr, equals('مدرب معتمد في الذكاء الاصطناعي'));
      expect(bilingual.bioEn, equals('Certified Trainer in Artificial Intelligence'));
    });

    test('Populates full bilingual profile when user submits in English', () async {
      const input = ApplicantProfileInput(
        name: 'Amir Al-Hatemi',
        bio: 'Certified Trainer in Artificial Intelligence',
        academicTitle: 'Associate Professor',
        institution: 'King Fahd University of Petroleum and Minerals',
        venueName: 'Innovation Hall',
        isOrganization: false,
      );

      final bilingual = await AutoTranslationService.translateAndTransliterate(input);

      // Name is Arabized
      expect(bilingual.nameEn, equals('Amir Al-Hatemi'));
      expect(bilingual.nameAr, equals('أمير الحاتمي'));

      // Title is translated to Arabic
      expect(bilingual.academicTitleEn, equals('Associate Professor'));
      expect(bilingual.academicTitleAr, equals('أستاذ مشارك'));

      // Institution is translated to Arabic
      expect(bilingual.institutionEn, equals('King Fahd University of Petroleum and Minerals'));
      expect(bilingual.institutionAr, equals('جامعة الملك فهد للبترول والمعادن'));

      // Venue is translated to Arabic
      expect(bilingual.venueNameEn, equals('Innovation Hall'));
      expect(bilingual.venueNameAr, equals('قاعة الابتكار'));

      // Bio is translated to Arabic
      expect(bilingual.bioEn, equals('Certified Trainer in Artificial Intelligence'));
      expect(bilingual.bioAr, equals('مدرب معتمد في الذكاء الاصطناعي'));
    });
  });
}
