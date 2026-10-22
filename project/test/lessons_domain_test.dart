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
          Lesson(id: id, requestId: req, type: 'talk', topic: 'fiqh', titleAr: 'درس',
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
    const phone = 'test-phone-0123456789abcdef';

    test('a preacher asks through his link, an admin approves with a mosque, a guest sees it', () async {
      final repo = DemoLessonsRepository();
      final c = LessonsController(repo);
      await c.ensureLoaded();
      final before = c.publicLessons.length;
      final req = await repo.requestLesson(DemoLessonsRepository.fahdLink, phone, LessonRequestDraft(
          type: 'lecture', topic: 'raqaiq', titleAr: 'محاضرة اختبار', slot: 'isha', dates: [addDays(c.today, 9)]));
      final view = await repo.openLink(DemoLessonsRepository.fahdLink, phone);
      expect(view.lessons.where((l) => l.requestId == req).single.status, 'pending');

      c.setDemoPersona(LessonsDemoPersona.admin);
      await c.refresh();
      expect(c.pendingRequests.map((r) => r.id), contains(req));
      // Approving needs a mosque: the request came without one.
      expect(() => c.review([req], 'approve'), throwsA(isA<LessonsException>()));
      expect(await c.review([req], 'approve', mosqueId: 'm1'), 1);
      expect(repo.lessons.values.where((l) => l.requestId == req).single.mosqueId, 'm1');

      c.setDemoPersona(LessonsDemoPersona.guest);
      await c.refresh();
      expect(c.publicLessons.length, before + 1);
      expect(() => c.review([req], 'approve'), throwsA(isA<LessonsException>()));
    });

    test('an admin adds a lesson that is public at once', () async {
      final c = LessonsController(DemoLessonsRepository(persona: LessonsDemoPersona.admin));
      await c.ensureLoaded();
      final req = await c.addLessons(LessonDraft(
          preacherId: 'p7', type: 'talk', topic: 'fiqh', titleAr: 'كلمة اختبار', slot: 'asr',
          dates: [addDays(c.today, 4), addDays(c.today, 11)], mosqueId: 'm2'));
      final added = c.catalog.lessons.values.where((l) => l.requestId == req).toList();
      expect(added, hasLength(2));
      expect(added.every((l) => l.status == 'approved' && l.seriesId != null), isTrue);
      expect(c.pendingRequests.map((r) => r.id), isNot(contains(req)));
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

    test('rejecting needs a reason, and only admins see pending requests', () async {
      final c = LessonsController(DemoLessonsRepository(persona: LessonsDemoPersona.admin));
      await c.ensureLoaded();
      expect(c.canManage, isTrue);
      final req = c.pendingRequests.first.id;
      expect(() => c.review([req], 'reject', reason: ''), throwsA(isA<LessonsException>()));
      c.setDemoPersona(LessonsDemoPersona.viewer);
      await c.refresh();
      expect(c.canManage, isFalse);
      expect(c.pendingRequests, isEmpty);
      expect(c.catalog.lessons.values.where((l) => l.status == 'pending'), isEmpty);
    });

    test('a one-time link keeps to the first phone; a timed link to its window', () async {
      final repo = DemoLessonsRepository();
      Future<String> opens(String token, String device) async {
        try {
          await repo.openLink(token, device);
          return 'opened';
        } on LessonsException catch (e) {
          return e.detail;
        }
      }

      expect((await repo.openLink(DemoLessonsRepository.fahdLink, phone)).preacher.id, 'p1');
      expect(await opens(DemoLessonsRepository.fahdLink, phone), 'opened');
      expect(await opens(DemoLessonsRepository.fahdLink, 'another-phone-0123456789'), 'used');
      expect(await opens('demo-old', phone), 'revoked');
      expect(await opens('not-a-link', phone), 'revoked');
      // A timed link opens on any phone while it lasts.
      expect(await opens(DemoLessonsRepository.iqbalLink, 'another-phone-0123456789'), 'opened');

      repo.persona = LessonsDemoPersona.admin;
      final soon = await repo.createKey('p2', 'window',
          validFrom: DateTime.now().add(const Duration(days: 1)), validUntil: DateTime.now().add(const Duration(days: 2)));
      expect(await opens(soon.token, phone), 'not_yet');
      final keys = await repo.loadKeys('p2');
      expect(keys.single.state(DateTime.now()), 'scheduled');
      await repo.revokeKey(keys.single.id);
      expect((await repo.loadKeys('p2')).single.state(DateTime.now()), 'revoked');
      expect(await opens(soon.token, phone), 'revoked');
    });

    test('a card change waits for an admin, who applies it', () async {
      final repo = DemoLessonsRepository();
      await repo.proposeCardEdit(DemoLessonsRepository.fahdLink, phone, {'title_ar': 'إمام وخطيب جامع الهدى'});
      expect(repo.preachers['p1']!.titleAr, isNot('إمام وخطيب جامع الهدى'));
      expect((await repo.openLink(DemoLessonsRepository.fahdLink, phone)).pendingEdit, {'title_ar': 'إمام وخطيب جامع الهدى'});

      final c = LessonsController(repo..persona = LessonsDemoPersona.admin);
      await c.ensureLoaded();
      final edit = c.pendingEdits.firstWhere((e) => e.preacherId == 'p1');
      await c.decideEdit(edit.id, true);
      expect(repo.preachers['p1']!.titleAr, 'إمام وخطيب جامع الهدى');
      expect(c.pendingEdits.where((e) => e.preacherId == 'p1'), isEmpty);
    });
  });
}
