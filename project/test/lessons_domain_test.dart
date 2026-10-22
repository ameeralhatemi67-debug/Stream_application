import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/data/lessons_repository.dart';
import 'package:streamer_app/features/lessons/domain/prayer_times.dart';
import 'package:streamer_app/features/lessons/domain/lessons_dates.dart';
import 'package:streamer_app/features/lessons/domain/lessons_models.dart';
import 'package:streamer_app/features/lessons/domain/lessons_rules.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';

void main() {
  group('prayer times (Umm al-Qura)', () {
    test('Al Khobar on 21 October 2026 falls in the published ranges', () {
      final pt = PrayerTimes.on(DateTime(2026, 10, 21, 12), 26.28, 50.21);
      // Published Umm al-Qura times for Al Khobar, late October: Fajr ~4:20,
      // Dhuhr ~11:25, Asr ~14:45, Maghrib ~17:10, Isha 90 min after Maghrib.
      expect(pt.fajr, inInclusiveRange(4.0, 4.7));
      expect(pt.dhuhr, inInclusiveRange(11.2, 11.6));
      expect(pt.asr, inInclusiveRange(14.4, 15.0));
      expect(pt.maghrib, inInclusiveRange(16.9, 17.4));
      expect(pt.isha - pt.maghrib, closeTo(1.5, 1e-9));
    });

    test('Isha is two hours after Maghrib in Ramadan', () {
      // 1 Ramadan 1448 AH is in February 2027.
      final ramadan = DateTime(2027, 2, 15, 12);
      expect(hijriOf(ramadan).month, 9);
      final pt = PrayerTimes.on(ramadan, 26.28, 50.21);
      expect(pt.isha - pt.maghrib, closeTo(2, 1e-9));
    });
  });

  group('dates', () {
    test('Hijri labels in both languages', () {
      final d = DateTime(2026, 10, 21, 12);
      final h = hijriOf(d);
      expect(h.year, 1448);
      expect(hijriLabel(d, 'en'), endsWith('1448 AH'));
      expect(hijriLabel(d, 'ar'), endsWith('1448 هـ'));
    });

    test('Riyadh today is UTC+3', () {
      final lateUtc = DateTime.utc(2026, 10, 21, 22, 30); // 01:30 on the 22nd in Riyadh
      expect(isoDate(lessonsToday(lateUtc)), '2026-10-22');
    });

    test('clock labels', () {
      expect(clockLabel(19.5, 'en'), '7:30 PM');
      expect(clockLabel(5.25, 'ar'), '5:15 ص');
    });
  });

  group('rules', () {
    test('a weekly series lands on the chosen weekdays', () {
      final start = DateTime(2026, 10, 21, 12); // a Wednesday
      final dates = seriesDates(start, {DateTime.tuesday, DateTime.thursday}, 4);
      expect(dates.map((d) => d.weekday), [DateTime.thursday, DateTime.tuesday, DateTime.thursday, DateTime.tuesday]);
      expect(seriesDates(start, {}, 2).map(isoDate), ['2026-10-21', '2026-10-28']);
    });

    test('a clash is the same mosque and slot, or the preacher booked twice', () {
      final day = DateTime(2026, 10, 25, 12);
      Lesson l(String id, String req, String mosque, String preacher, {String slot = 'isha', String status = 'approved'}) =>
          Lesson(id: id, organizationId: 'o', requestId: req, type: 'talk', topic: 'fiqh', titleAr: 'درس',
              preacherId: preacher, mosqueId: mosque, date: day, slot: slot, status: status);
      final existing = [l('a', 'r1', 'm1', 'p1'), l('b', 'r2', 'm2', 'p2', slot: 'asr'), l('c', 'r3', 'm9', 'p9', status: 'rejected')];
      expect(clashesOfLesson(l('x', 'rx', 'm1', 'p5'), existing).map((c) => c.id), ['a']);
      expect(clashesOfLesson(l('y', 'ry', 'm7', 'p1'), existing).map((c) => c.id), ['a']);
      expect(clashesOfLesson(l('z', 'rz', 'm9', 'p9'), existing), isEmpty);
    });

    test('CSV export neutralises formulas', () {
      expect(excelSafeCsv([
        ['=HYPERLINK("x")', '+1', 'normal', 'quote "q"']
      ]), '"\'=HYPERLINK(""x"")","\'+1","normal","quote ""q"""');
    });

    test('phone masks keep only the edges', () => expect(maskPhone('0500000101'), '05•• ••• 101'));
  });

  group('controller on sample data', () {
    test('a preacher submits, a coordinator approves, a guest sees it', () async {
      final repo = DemoLessonsRepository(persona: LessonsDemoPersona.preacher);
      final c = LessonsController(repo);
      await c.ensureLoaded();
      expect(c.canSubmitOwn, isTrue);
      final before = c.publicLessons.length;
      final req = await c.submit(LessonDraft(
          preacherId: DemoLessonsRepository.ownPreacher, type: 'lecture', topic: 'raqaiq', titleAr: 'محاضرة اختبار',
          slot: 'isha', dates: [addDays(c.today, 9)], mosqueId: 'm1'));
      expect(c.myRequests().map((r) => r.id), contains(req));

      c.setDemoPersona(LessonsDemoPersona.coordinator);
      await c.refresh();
      expect(c.pendingRequests.map((r) => r.id), contains(req));
      expect(await c.review([req], 'approve'), 1);

      c.setDemoPersona(LessonsDemoPersona.guest);
      await c.refresh();
      expect(c.publicLessons.length, before + 1);
      expect(() => c.review([req], 'approve'), throwsA(isA<LessonsException>()));
    });

    test('a viewer reminder is timed to the adhan', () async {
      final c = LessonsController(DemoLessonsRepository(persona: LessonsDemoPersona.viewer));
      await c.ensureLoaded();
      final l = c.upcoming.firstWhere((l) => !c.hasReminder(l.id));
      await c.setReminder(l, 'adhan');
      expect(c.reminderLead(l.id), 'adhan');
      await c.setReminder(l, null);
      expect(c.hasReminder(l.id), isFalse);
    });

    test('rejecting needs a reason, and only staff see pending requests', () async {
      final c = LessonsController(DemoLessonsRepository(persona: LessonsDemoPersona.coordinator));
      await c.ensureLoaded();
      final req = c.pendingRequests.first.id;
      expect(() => c.review([req], 'reject', reason: ''), throwsA(isA<LessonsException>()));
      c.setDemoPersona(LessonsDemoPersona.viewer);
      await c.refresh();
      expect(c.pendingRequests, isEmpty);
      expect(c.catalog.lessons.values.where((l) => l.status == 'pending'), isEmpty);
    });
  });
}
