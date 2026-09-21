/// High-performance, offline Pure-Dart Arabic <-> English Phonetic Transliteration Engine
/// Implements UNGEGN & Saudi Standard conventions with morphological prefix handling.
class ArabicTransliterationEngine {
  static const Map<String, String> _arabicToLatinGraphemes = {
    'ا': 'a', 'أ': 'a', 'إ': 'i', 'آ': 'aa', 'ء': "'", 'ؤ': 'u', 'ئ': 'e',
    'ب': 'b', 'ت': 't', 'ث': 'th', 'ج': 'j', 'ح': 'h', 'خ': 'kh',
    'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z', 'س': 's', 'ش': 'sh',
    'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': 'a', 'غ': 'gh',
    'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n',
    'ه': 'h', 'و': 'w', 'ي': 'y', 'ى': 'a', 'ة': 'ah',
    'پ': 'p', 'ڤ': 'v', 'چ': 'ch', 'گ': 'g',
  };

  static const Map<String, String> _commonArabicNames = {
    'محمد': 'Mohammed',
    'احمد': 'Ahmed',
    'أحمد': 'Ahmed',
    'علي': 'Ali',
    'عمر': 'Omar',
    'عمرو': 'Amr',
    'عثمان': 'Othman',
    'خالد': 'Khalid',
    'سعود': 'Saud',
    'فيصل': 'Faisal',
    'سلمان': 'Salman',
    'عبدالله': 'Abdullah',
    'عبد الله': 'Abdullah',
    'عبدالرحمن': 'Abdulrahman',
    'عبد الرحمن': 'Abdulrahman',
    'عبدالعزيز': 'Abdulaziz',
    'عبد العزيز': 'Abdulaziz',
    'عبدالمحسن': 'Abdulmohsen',
    'عبد المحسن': 'Abdulmohsen',
    'عبدالمجيد': 'Abdulmajeed',
    'عبد المجيد': 'Abdulmajeed',
    'عبدالاله': 'Abdulilah',
    'عبد الإله': 'Abdulilah',
    'أمير': 'Amir',
    'امير': 'Amir',
    'عسير': 'Aseer',
    'يوسف': 'Yusuf',
    'إبراهيم': 'Ibrahim',
    'ابراهيم': 'Ibrahim',
    'سارة': 'Sarah',
    'ساره': 'Sarah',
    'فاطمة': 'Fatimah',
    'فاطمه': 'Fatimah',
    'نورة': 'Noura',
    'نوره': 'Noura',
    'مريم': 'Maryam',
    'عائشة': 'Aisha',
    'عائشه': 'Aisha',
    'هند': 'Hind',
    'منى': 'Mona',
    'هدى': 'Huda',
    'رشا': 'Rasha',
    'ريم': 'Reem',
    'شهد': 'Shahad',
    'العقل': 'Al-Aql',
    'الحاتمي': 'Al-Hatemi',
    'العتيبي': 'Al-Otaibi',
    'الدوسري': 'Al-Dosari',
    'الغامدي': 'Al-Ghamdi',
    'الشمري': 'Al-Shammari',
    'الشهري': 'Al-Shehri',
    'القحطاني': 'Al-Qahtani',
    'الزهراني': 'Al-Zahrani',
    'المالكي': 'Al-Malki',
    'الحربي': 'Al-Harbi',
    'المطيري': 'Al-Mutairi',
    'العنزي': 'Al-Enezi',
    'السبيعي': 'Al-Subaie',
    'التميمي': 'Al-Tamimi',
    'الخالدي': 'Al-Khaldi',
    'الهاجري': 'Al-Hajri',
    'الرويلي': 'Al-Ruwaili',
    'الشهراني': 'Al-Shahrani',
    'العسيري': 'Al-Asiri',
    'النجار': 'Al-Najjar',
    'الحداد': 'Al-Haddad',
    'حجازي': 'Hejazi',
  };

  static const Map<String, String> _commonEnglishToArabicNames = {
    'mohammed': 'محمد',
    'mohammad': 'محمد',
    'muhammad': 'محمد',
    'ahmed': 'أحمد',
    'ahmad': 'أحمد',
    'ali': 'علي',
    'omar': 'عمر',
    'amr': 'عمرو',
    'othman': 'عثمان',
    'khalid': 'خالد',
    'saud': 'سعود',
    'faisal': 'فيصل',
    'salman': 'سلمان',
    'abdullah': 'عبدالله',
    'abdulrahman': 'عبدالرحمن',
    'abdulaziz': 'عبدالعزيز',
    'abdulmohsen': 'عبدالمحسن',
    'abdulmajeed': 'عبدالمجيد',
    'amir': 'أمير',
    'ameer': 'أمير',
    'aseer': 'عسير',
    'asir': 'عسير',
    'yusuf': 'يوسف',
    'yousef': 'يوسف',
    'ibrahim': 'إبراهيم',
    'sarah': 'سارة',
    'sara': 'سارة',
    'fatimah': 'فاطمة',
    'fatima': 'فاطمة',
    'noura': 'نورة',
    'nora': 'نورة',
    'maryam': 'مريم',
    'aisha': 'عائشة',
    'hind': 'هند',
    'mona': 'منى',
    'huda': 'هدى',
    'reem': 'ريم',
    'al-hatemi': 'الحاتمي',
    'al-otaibi': 'العتيبي',
    'al-dosari': 'الدوسري',
    'al-ghamdi': 'الغامدي',
    'al-shammari': 'الشمري',
    'al-shehri': 'الشهري',
    'al-qahtani': 'القحطاني',
    'al-zahrani': 'الزهراني',
    'al-malki': 'المالكي',
    'al-harbi': 'الحربي',
    'al-mutairi': 'المطيري',
    'al-aql': 'العقل',
    'alex': 'أليكس',
    'thompson': 'تومسون',
    'john': 'جون',
    'david': 'ديفيد',
    'michael': 'مايكل',
    'james': 'جيمس',
    'robert': 'روبرت',
    'william': 'ويليام',
    'richard': 'ريتشارد',
    'thomas': 'توماس',
    'daniel': 'دانيال',
  };

  /// Transliterates an Arabic personal/broadcaster name into Romanized English
  static String transliterateArabicToEnglish(String input) {
    if (input.trim().isEmpty) return '';

    // Handle compound theophoric names (e.g. "عبد الرحمن" -> "عبدالرحمن", "عبد العزيز" -> "عبدالعزيز")
    String text = input.trim();
    text = text.replaceAllMapped(RegExp(r'(^|\s+)عبد\s+'), (m) => '${m[1]}عبد');

    final words = text.split(RegExp(r'\s+'));
    final resultWords = <String>[];

    for (var word in words) {
      final normalizedWord = _normalizeArabic(word);
      final rawCleanWord = word.replaceAll(RegExp(r'[\u064B-\u065F]'), '');

      // Check common dictionary
      if (_commonArabicNames.containsKey(rawCleanWord)) {
        resultWords.add(_commonArabicNames[rawCleanWord]!);
        continue;
      }
      if (_commonArabicNames.containsKey(normalizedWord)) {
        resultWords.add(_commonArabicNames[normalizedWord]!);
        continue;
      }

      // Check "بن" (bin) or "ابن" (ibn)
      if (rawCleanWord == 'بن' || normalizedWord == 'بن') {
        resultWords.add('bin');
        continue;
      }
      if (rawCleanWord == 'ابن' || normalizedWord == 'ابن') {
        resultWords.add('Ibn');
        continue;
      }

      // Check "الـ"prefix
      bool hasAlPrefix = false;
      String coreWord = rawCleanWord;
      if (coreWord.startsWith('ال') && coreWord.length > 3) {
        hasAlPrefix = true;
        coreWord = coreWord.substring(2);
      }

      // Transliterate letter by letter
      final buffer = StringBuffer();
      for (int i = 0; i < coreWord.length; i++) {
        final char = coreWord[i];
        buffer.write(_arabicToLatinGraphemes[char] ?? char);
      }

      String romanized = buffer.toString();
      if (romanized.isNotEmpty) {
        romanized = romanized[0].toUpperCase() + romanized.substring(1).toLowerCase();
      }

      if (hasAlPrefix) {
        romanized = 'Al-$romanized';
      }

      resultWords.add(romanized.isNotEmpty ? romanized : word);
    }

    return resultWords.join(' ');
  }

  /// Transliterates/Arabizes an English personal name into Arabic script
  static String transliterateEnglishToArabic(String input) {
    if (input.trim().isEmpty) return '';

    final words = input.trim().split(RegExp(r'\s+'));
    final resultWords = <String>[];

    for (var word in words) {
      final clean = word.toLowerCase().replaceAll(RegExp(r'[^\w\-]'), '');

      if (_commonEnglishToArabicNames.containsKey(clean)) {
        resultWords.add(_commonEnglishToArabicNames[clean]!);
        continue;
      }

      // Check if word has "al-"or "el-"prefix
      bool hasAlPrefix = false;
      String coreWord = clean;
      if (clean.startsWith('al-') || clean.startsWith('el-')) {
        hasAlPrefix = true;
        coreWord = clean.substring(3);
      }

      // Algorithmic English -> Arabic phoneme expansion
      final arabized = _arabizeLatinWord(coreWord);
      if (hasAlPrefix) {
        resultWords.add('ال$arabized');
      } else {
        resultWords.add(arabized);
      }
    }

    return resultWords.join(' ');
  }

  static String _arabizeLatinWord(String word) {
    if (word.isEmpty) return '';
    String w = word.toLowerCase();

    // Common digraph substitutions
    w = w.replaceAll('th', 'ث')
        .replaceAll('sh', 'ش')
        .replaceAll('ch', 'تش')
        .replaceAll('kh', 'خ')
        .replaceAll('gh', 'غ')
        .replaceAll('ph', 'ف');

    final buffer = StringBuffer();
    for (int i = 0; i < w.length; i++) {
      final c = w[i];
      switch (c) {
        case 'a':
          buffer.write(i == 0 ? 'أ' : 'ا');
          break;
        case 'b': buffer.write('ب'); break;
        case 'c': buffer.write('ك'); break;
        case 'd': buffer.write('د'); break;
        case 'e': buffer.write(i == 0 ? 'إ' : 'ي'); break;
        case 'f': buffer.write('ف'); break;
        case 'g': buffer.write('ج'); break;
        case 'h': buffer.write('ه'); break;
        case 'i': buffer.write(i == 0 ? 'إ' : 'ي'); break;
        case 'j': buffer.write('ج'); break;
        case 'k': buffer.write('ك'); break;
        case 'l': buffer.write('ل'); break;
        case 'm': buffer.write('م'); break;
        case 'n': buffer.write('ن'); break;
        case 'o': buffer.write(i == 0 ? 'أو' : 'و'); break;
        case 'p': buffer.write('ب'); break;
        case 'q': buffer.write('ق'); break;
        case 'r': buffer.write('ر'); break;
        case 's': buffer.write('س'); break;
        case 't': buffer.write('ت'); break;
        case 'u': buffer.write(i == 0 ? 'أو' : 'و'); break;
        case 'v': buffer.write('ف'); break;
        case 'w': buffer.write('و'); break;
        case 'x': buffer.write('كس'); break;
        case 'y': buffer.write('ي'); break;
        case 'z': buffer.write('ز'); break;
        default:
          buffer.write(c);
      }
    }

    return buffer.toString();
  }

  /// Removes Tashkeel and normalizes Arabic character variants
  static String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '') // Strip Tashkeel
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  /// Detects whether the input string is predominantly Arabic
  static bool isArabicText(String text) {
    if (text.trim().isEmpty) return false;
    final arabicMatches = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
    final latinMatches = RegExp(r'[a-zA-Z]').allMatches(text).length;
    return arabicMatches >= latinMatches;
  }
}
