import 'dart:math' as math;

import 'lessons_dates.dart';

/// Prayer times by the Umm al-Qura method: Fajr at 18.5 degrees, Isha 90
/// minutes after Maghrib (120 in Ramadan), Asr by the standard shadow.
/// Times are hours from local midnight in Saudi time (UTC+3), the zone every
/// Lessons mosque is in.
class PrayerTimes {
  const PrayerTimes(
      {required this.fajr,
      required this.sunrise,
      required this.dhuhr,
      required this.asr,
      required this.maghrib,
      required this.isha});

  final double fajr, sunrise, dhuhr, asr, maghrib, isha;

  double of(String slot) => switch (slot) {
        'fajr' => fajr,
        'dhuhr' => dhuhr,
        'asr' => asr,
        'maghrib' => maghrib,
        _ => isha,
      };

  static final _cache = <String, PrayerTimes>{};

  static PrayerTimes on(DateTime date, double lat, double lng,
      {double timezone = 3}) {
    final key = '${isoDate(date)}:$lat:$lng';
    return _cache[key] ??= _compute(date, lat, lng, timezone);
  }

  static const _deg = math.pi / 180;
  static double _sin(double d) => math.sin(d * _deg);
  static double _cos(double d) => math.cos(d * _deg);
  static double _tan(double d) => math.tan(d * _deg);
  static double _asin(double x) => math.asin(x) / _deg;
  static double _acos(double x) => math.acos(x.clamp(-1.0, 1.0)) / _deg;
  static double _atan2(double y, double x) => math.atan2(y, x) / _deg;
  static double _acot(double x) => math.atan(1 / x) / _deg;
  static double _fix(double a, double b) {
    final r = a - b * (a / b).floorToDouble();
    return r < 0 ? r + b : r;
  }

  static double _julian(int y, int m, int d) {
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floorToDouble() +
        (30.6001 * (m + 1)).floorToDouble() +
        d +
        b -
        1524.5;
  }

  static ({double decl, double eqt}) _sun(double jd) {
    final d = jd - 2451545.0;
    final g = _fix(357.529 + 0.98560028 * d, 360);
    final q = _fix(280.459 + 0.98564736 * d, 360);
    final l = _fix(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g), 360);
    final e = 23.439 - 0.00000036 * d;
    final ra = _atan2(_cos(e) * _sin(l), _cos(l)) / 15;
    return (decl: _asin(_sin(e) * _sin(l)), eqt: q / 15 - _fix(ra, 24));
  }

  static PrayerTimes _compute(
      DateTime date, double lat, double lng, double tz) {
    final jDate = _julian(date.year, date.month, date.day) - lng / (15 * 24);
    double midDay(double t) => _fix(12 - _sun(jDate + t).eqt, 24);
    double angleTime(double angle, double t, {bool ccw = false}) {
      final decl = _sun(jDate + t).decl;
      final tt = _acos((-_sin(angle) - _sin(decl) * _sin(lat)) /
              (_cos(decl) * _cos(lat))) /
          15;
      return midDay(t) + (ccw ? -tt : tt);
    }

    double asrTime(double t) {
      final decl = _sun(jDate + t).decl;
      return angleTime(-_acot(1 + _tan((lat - decl).abs())), t);
    }

    double local(double v) => v + tz - lng / 15;
    final maghrib = local(angleTime(0.833, 18 / 24));
    return PrayerTimes(
      fajr: local(angleTime(18.5, 5 / 24, ccw: true)),
      sunrise: local(angleTime(0.833, 6 / 24, ccw: true)),
      dhuhr: local(midDay(12 / 24)),
      asr: local(asrTime(13 / 24)),
      maghrib: maghrib,
      isha: maghrib + (hijriOf(date).month == 9 ? 2 : 1.5),
    );
  }
}
