/// The programme's fixed vocabulary. Values match the database CHECK
/// constraints (supabase/migrations/20261021120000_taysir_lessons_programme.sql);
/// labels live in assets/i18n under `lessons.*`.
abstract final class LessonsVocab {
  /// Lessons are announced by prayer, the way every mosque does.
  static const slots = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  /// Minutes from adhan to iqama (Ministry of Islamic Affairs timetable);
  /// a lesson starts about ten minutes after the iqama.
  static const iqamaMinutes = {
    'fajr': 25,
    'dhuhr': 20,
    'asr': 20,
    'maghrib': 10,
    'isha': 20
  };
  static const lessonStartsAfterIqama = 10;

  static const types = ['lesson', 'lecture', 'talk'];
  static const topics = [
    'aqeedah', 'fiqh', 'tafsir', 'hadith', 'seerah', 'family', 'raqaiq', 'intro'
  ];
  static const audiences = ['all', 'men', 'women', 'youth', 'kids'];
  static const languages = ['ar', 'en', 'ur', 'tl', 'bn', 'ml', 'id'];

  /// Each language named in itself, for chips a speaker can recognise.
  static const languageNative = {
    'ar': 'العربية',
    'en': 'English',
    'ur': 'اردو',
    'tl': 'Tagalog',
    'bn': 'বাংলা',
    'ml': 'മലയാളം',
    'id': 'Indonesia',
  };
  static const facilities = ['women', 'parking', 'access', 'interp', 'kids'];
  static const affiliations = ['coop', 'ministry'];
  static const statuses = ['pending', 'approved', 'rejected', 'cancelled', 'withdrawn'];
  static const leads = ['adhan', '30', 'day'];
  static const flagKinds = ['time', 'place', 'cancel', 'other'];
  static const reportIssues = ['none', 'sound', 'time', 'place'];

  static const cities = ['khobar', 'dhahran', 'dammam', 'qatif', 'other'];

  /// Cities on the tri-city map pack; others are listed only (ADR-008).
  static const mapCities = ['khobar', 'dhahran', 'dammam'];

  /// City centres, used for prayer times when a mosque has no pin.
  static const cityCentre = {
    'khobar': (26.28, 50.21),
    'dhahran': (26.29, 50.12),
    'dammam': (26.43, 50.09),
    'qatif': (26.56, 50.01),
    'other': (26.28, 50.21),
  };

  static const rejectReasons = ['clash', 'mosque', 'time', 'dup', 'other'];
  static const cancelReasons = ['travel', 'ill', 'mosque', 'other'];
}
