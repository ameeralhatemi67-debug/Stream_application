import 'package:hijri/hijri_calendar.dart';

/// Dates in Lessons are calendar days in Saudi time (UTC+3), not instants.
/// Weekday and Hijri date are always derived here, never stored.

/// Today in Riyadh, as a date at local noon (stable across DST-free math).
DateTime lessonsToday([DateTime? now]) {
  final riyadh = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
  return DateTime(riyadh.year, riyadh.month, riyadh.day, 12);
}

/// Hours since midnight, Riyadh time.
double lessonsNowHours([DateTime? now]) {
  final riyadh = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
  return riyadh.hour + riyadh.minute / 60;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day, 12);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, 12);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
int daysBetween(DateTime a, DateTime b) =>
    dateOnly(b).difference(dateOnly(a)).inHours ~/ 24;

String _pad(int n) => n.toString().padLeft(2, '0');
String isoDate(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
DateTime parseIsoDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2], 12);
}

typedef HijriDate = ({int year, int month, int day});

HijriDate hijriOf(DateTime d) {
  final h = HijriCalendar.fromDate(DateTime(d.year, d.month, d.day));
  return (year: h.hYear, month: h.hMonth, day: h.hDay);
}

const _hijriAr = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
];
const _hijriEn = [
  'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Akhir', 'Jumada al-Ula',
  'Jumada al-Akhirah', 'Rajab', 'Shaban', 'Ramadan', 'Shawwal',
  'Dhu al-Qadah', 'Dhu al-Hijjah'
];
const _gregAr = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس',
  'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];
const _gregEn = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'
];
// DateTime.weekday: 1 Monday .. 7 Sunday.
const _dayAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _dayEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _dayEnShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

bool _ar(String lang) => lang == 'ar';

String weekdayName(DateTime d, String lang, {bool short = false}) =>
    _ar(lang) ? _dayAr[d.weekday - 1] : (short ? _dayEnShort : _dayEn)[d.weekday - 1];

/// "21 October" / "21 أكتوبر"; [short] abbreviates English months.
String gregorianLabel(DateTime d, String lang, {bool year = false, bool short = false}) {
  final month = _ar(lang)
      ? _gregAr[d.month - 1]
      : (short ? _gregEn[d.month - 1].substring(0, 3) : _gregEn[d.month - 1]);
  return '${d.day} $month${year ? ' ${d.year}' : ''}';
}

/// "18 Rabi al-Akhir 1448 AH" / "18 ربيع الآخر 1448 هـ".
String hijriLabel(DateTime d, String lang, {bool year = true}) {
  final h = hijriOf(d);
  final month = (_ar(lang) ? _hijriAr : _hijriEn)[h.month - 1];
  if (!year) return '${h.day} $month';
  return '${h.day} $month ${h.year} ${_ar(lang) ? 'هـ' : 'AH'}';
}

String hijriMonthLabel(DateTime d, String lang) {
  final h = hijriOf(d);
  return '${(_ar(lang) ? _hijriAr : _hijriEn)[h.month - 1]} ${h.year} ${_ar(lang) ? 'هـ' : 'AH'}';
}

String gregorianMonthLabel(DateTime d, String lang) =>
    '${(_ar(lang) ? _gregAr : _gregEn)[d.month - 1]} ${d.year}';

/// "8:30 PM" / "8:30 م" from hours since midnight.
String clockLabel(double hours, String lang) {
  var mins = (hours * 60).round();
  mins = ((mins % 1440) + 1440) % 1440;
  final hh = mins ~/ 60, mm = mins % 60, pm = hh >= 12, h12 = hh % 12 == 0 ? 12 : hh % 12;
  return '$h12:${_pad(mm)} ${_ar(lang) ? (pm ? 'م' : 'ص') : (pm ? 'PM' : 'AM')}';
}

double hhmmToHours(String s) {
  final p = s.split(':');
  return int.parse(p[0]) + int.parse(p[1]) / 60;
}

/// "Today", "Tomorrow" or the weekday.
String relativeDayLabel(DateTime d, String lang, {DateTime? today}) {
  final t = today ?? lessonsToday();
  if (sameDay(d, t)) return _ar(lang) ? 'اليوم' : 'Today';
  if (sameDay(d, addDays(t, 1))) return _ar(lang) ? 'غدًا' : 'Tomorrow';
  return weekdayName(d, lang);
}

/// "5 min ago" style, for notifications and the action log.
String agoLabel(DateTime at, String lang, {DateTime? now}) {
  final m = ((now ?? DateTime.now()).difference(at).inMinutes).clamp(1, 1 << 30);
  if (m < 60) return _ar(lang) ? 'قبل $m د' : '$m min ago';
  final h = (m / 60).round();
  if (h < 24) return _ar(lang) ? 'قبل $h س' : '$h h ago';
  final d = (h / 24).round();
  return _ar(lang) ? 'قبل $d يوم' : '$d d ago';
}
