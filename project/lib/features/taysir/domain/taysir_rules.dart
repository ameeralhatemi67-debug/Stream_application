import 'prayer_times.dart';
import 'taysir_dates.dart';
import 'taysir_models.dart';
import 'taysir_vocab.dart';

/// Where to compute prayer times for a mosque: its pin, else its city centre.
(double, double) mosqueCoordinates(TaysirMosque? m, Map<String, TaysirDistrict> districts) {
  if (m != null && m.hasPin) return (m.latitude!, m.longitude!);
  final city = districts[m?.districtId]?.city ?? 'khobar';
  return TaysirVocab.cityCentre[city] ?? TaysirVocab.cityCentre['khobar']!;
}

String cityOf(TaysirMosque? m, Map<String, TaysirDistrict> districts) =>
    districts[m?.districtId]?.city ?? 'other';

PrayerTimes prayerTimesFor(DateTime date, TaysirMosque? m, Map<String, TaysirDistrict> districts) {
  final (lat, lng) = mosqueCoordinates(m, districts);
  return PrayerTimes.on(date, lat, lng);
}

/// When a lesson starts, in hours after midnight: its fixed clock time, else
/// the slot's adhan plus the iqama gap and ten minutes.
double lessonStartHours(TaysirLesson l, TaysirCatalog c) {
  if (l.exactTime != null) return hhmmToHours(l.exactTime!);
  final pt = prayerTimesFor(l.date, c.mosques[l.mosqueId], c.districts);
  return pt.of(l.slot) +
      (TaysirVocab.iqamaMinutes[l.slot]! + TaysirVocab.lessonStartsAfterIqama) / 60;
}

/// The lesson's start as an instant (Saudi time is UTC+3 all year).
DateTime lessonStartInstant(TaysirLesson l, TaysirCatalog c) {
  final minutes = (lessonStartHours(l, c) * 60).round();
  return DateTime.utc(l.date.year, l.date.month, l.date.day)
      .add(Duration(minutes: minutes - 180));
}

/// When a reminder with [lead] fires.
DateTime reminderInstant(TaysirLesson l, String lead, TaysirCatalog c) {
  final start = lessonStartInstant(l, c);
  switch (lead) {
    case '30':
      return start.subtract(const Duration(minutes: 30));
    case 'day':
      return DateTime.utc(l.date.year, l.date.month, l.date.day)
          .subtract(const Duration(days: 1))
          .add(const Duration(hours: 17)); // 8 PM Riyadh the evening before
    default:
      final pt = prayerTimesFor(l.date, c.mosques[l.mosqueId], c.districts);
      final adhan = (pt.of(l.slot) * 60).round();
      return DateTime.utc(l.date.year, l.date.month, l.date.day).add(Duration(minutes: adhan - 180));
  }
}

int slotIndex(String slot) => TaysirVocab.slots.indexOf(slot);

int compareLessons(TaysirLesson a, TaysirLesson b) {
  final d = a.date.compareTo(b.date);
  return d != 0 ? d : slotIndex(a.slot).compareTo(slotIndex(b.slot));
}

/// Same mosque and slot on the same day, or the same preacher booked twice.
List<TaysirLesson> clashesFor(
  ({String? id, String requestId, DateTime date, String slot, String mosqueId, String preacherId}) l,
  Iterable<TaysirLesson> lessons,
) =>
    lessons
        .where((o) =>
            o.id != l.id &&
            o.requestId != l.requestId &&
            (o.status == 'approved' || o.status == 'pending') &&
            sameDay(o.date, l.date) &&
            o.slot == l.slot &&
            (o.mosqueId == l.mosqueId || o.preacherId == l.preacherId))
        .toList();

List<TaysirLesson> clashesOfLesson(TaysirLesson l, Iterable<TaysirLesson> lessons) => clashesFor(
    (id: l.id, requestId: l.requestId, date: l.date, slot: l.slot, mosqueId: l.mosqueId, preacherId: l.preacherId),
    lessons);

/// One submission: a single lesson or every session of a series.
class TaysirRequest {
  TaysirRequest(this.id, this.items) {
    items.sort(compareLessons);
  }
  final String id;
  final List<TaysirLesson> items;
  TaysirLesson get first => items.first;
  bool get isSeries => items.length > 1;
  String get status => first.status;
  DateTime get submittedAt => first.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// Requests with any session in [statuses], newest first.
List<TaysirRequest> requestsOf(Iterable<TaysirLesson> lessons,
    {Set<String> statuses = const {'pending'}}) {
  final map = <String, List<TaysirLesson>>{};
  for (final l in lessons) {
    if (!statuses.contains(l.status)) continue;
    (map[l.requestId] ??= []).add(l);
  }
  final out = [for (final e in map.entries) TaysirRequest(e.key, e.value)];
  out.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  return out;
}

/// The dates of a weekly series: [count] sessions from [start] on [weekdays]
/// (DateTime.weekday values); with no weekday chosen, the start's weekday.
List<DateTime> seriesDates(DateTime start, Set<int> weekdays, int count) {
  final days = weekdays.isEmpty ? {start.weekday} : weekdays;
  final out = <DateTime>[];
  var cur = dateOnly(start);
  var guard = 0;
  while (out.length < count && guard++ < 400) {
    if (days.contains(cur.weekday)) out.add(cur);
    cur = addDays(cur, 1);
  }
  return out;
}

/// The public calendar's filters.
class TaysirFilter {
  const TaysirFilter({
    this.query = '',
    this.city,
    this.districtId,
    this.mosqueId,
    this.preacherId,
    this.type,
    this.topic,
    this.language,
    this.audience,
    this.womenOnly = false,
    this.streamedOnly = false,
    this.seriesOnly = false,
  });
  final String query;
  final String? city, districtId, mosqueId, preacherId, type, topic, language, audience;
  final bool womenOnly, streamedOnly, seriesOnly;

  static const none = TaysirFilter();

  int get activeCount => [
        city, districtId, mosqueId, preacherId, type, topic, language, audience
      ].where((v) => v != null).length +
      [womenOnly, streamedOnly, seriesOnly].where((v) => v).length;

  TaysirFilter copyWith({
    String? query,
    Object? city = _keep,
    Object? districtId = _keep,
    Object? mosqueId = _keep,
    Object? preacherId = _keep,
    Object? type = _keep,
    Object? topic = _keep,
    Object? language = _keep,
    Object? audience = _keep,
    bool? womenOnly,
    bool? streamedOnly,
    bool? seriesOnly,
  }) =>
      TaysirFilter(
        query: query ?? this.query,
        city: city == _keep ? this.city : city as String?,
        districtId: districtId == _keep ? this.districtId : districtId as String?,
        mosqueId: mosqueId == _keep ? this.mosqueId : mosqueId as String?,
        preacherId: preacherId == _keep ? this.preacherId : preacherId as String?,
        type: type == _keep ? this.type : type as String?,
        topic: topic == _keep ? this.topic : topic as String?,
        language: language == _keep ? this.language : language as String?,
        audience: audience == _keep ? this.audience : audience as String?,
        womenOnly: womenOnly ?? this.womenOnly,
        streamedOnly: streamedOnly ?? this.streamedOnly,
        seriesOnly: seriesOnly ?? this.seriesOnly,
      );

  /// Keeps the search text, clears everything else.
  TaysirFilter cleared() => TaysirFilter(query: query);

  bool matches(TaysirLesson l, TaysirCatalog c) {
    final m = c.mosques[l.mosqueId], p = c.preachers[l.preacherId];
    if (m == null || p == null) return false;
    final d = c.districts[m.districtId];
    if (city != null && d?.city != city) return false;
    if (districtId != null && m.districtId != districtId) return false;
    if (mosqueId != null && l.mosqueId != mosqueId) return false;
    if (preacherId != null && l.preacherId != preacherId) return false;
    if (type != null && l.type != type) return false;
    if (topic != null && l.topic != topic) return false;
    if (language != null && l.language != language && l.interpretation != language) return false;
    if (audience != null && l.audience != audience) return false;
    if (womenOnly && !l.womenSection) return false;
    if (streamedOnly && !l.streamed) return false;
    if (seriesOnly && l.seriesId == null) return false;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty &&
        ![l.titleAr, l.titleEn, p.nameAr, p.nameEn, m.nameAr, m.nameEn, d?.nameAr ?? '', d?.nameEn ?? '']
            .any((s) => s.toLowerCase().contains(q))) {
      return false;
    }
    return true;
  }
}

const _keep = Object();

/// Excel-safe CSV: every cell quoted, formula prefixes neutralised (the
/// original Taysir export allowed formula injection).
String excelSafeCsv(List<List<Object?>> rows) => rows
    .map((row) => row.map((cell) {
          var s = cell?.toString() ?? '';
          if (RegExp(r'^[=+\-@]').hasMatch(s)) s = "'$s";
          return '"${s.replaceAll('"', '""')}"';
        }).join(','))
    .join('\n');

/// Masks a phone for display: "05•• ••• 101".
String maskPhone(String? phone) =>
    phone == null || phone.length < 5 ? '—' : '${phone.substring(0, 2)}•• ••• ${phone.substring(phone.length - 3)}';
