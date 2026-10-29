import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/lessons_dates.dart';
import '../domain/lessons_models.dart';
import '../domain/lessons_rules.dart';
import 'lessons_repository.dart';

/// Who the sample data is being viewed as. admin covers every admin who
/// manages lessons (admins, master admins and lessons-only admins).
enum LessonsDemoPersona { guest, viewer, admin }

/// A sample preacher link (the real server keeps only hashes of the key
/// and of the phone it is bound to).
class DemoPreacherLink {
  DemoPreacherLink({
    required this.id,
    required this.preacherId,
    required this.kind,
    this.validFrom,
    this.validUntil,
    this.note = '',
    required this.createdAt,
  });
  final String id, preacherId, kind, note;
  final DateTime? validFrom, validUntil;
  final DateTime createdAt;
  String? device;
  DateTime? openedAt, lastUsedAt, revokedAt;

  PreacherKey get view => PreacherKey(
      id: id, kind: kind, validFrom: validFrom, validUntil: validUntil, openedAt: openedAt, lastUsedAt: lastUsedAt,
      revokedAt: revokedAt, note: note, createdAt: createdAt, bound: device != null);
}

/// Sample data for builds without a backend and for widget tests. Names of
/// people are invented; neighbourhoods are real. The permission rules mirror
/// the server functions so the screens behave the same way.
class DemoLessonsRepository implements LessonsRepository {
  DemoLessonsRepository({this.persona = LessonsDemoPersona.guest, DateTime? today})
      : _today = today ?? lessonsToday() {
    _seed();
  }

  LessonsDemoPersona persona;
  final DateTime _today;
  int _seq = 1000;
  String _id(String p) => '$p-${++_seq}';

  /// The sample one-time link of Sheikh Fahd (p1): `/preacher/demo-fahd`.
  static const fahdLink = 'demo-fahd';

  /// A timed link of Sheikh Muhammad Iqbal (p4), open this week.
  static const iqbalLink = 'demo-iqbal';

  /// The sample application waiting for the admins.
  static const sampleApplication = 'app-1';

  @override
  bool get isDemo => true;

  @override
  String? get currentUserId =>
      persona == LessonsDemoPersona.guest ? null : 'demo-${persona.name}';

  bool get _admin => persona == LessonsDemoPersona.admin;

  void _need(bool ok) {
    if (!ok) throw const LessonsException(LessonsFailure.forbidden);
  }

  void _signedIn() => _need(currentUserId != null);

  // ---------------------------------------------------------------- state
  final districts = <String, District>{};
  final mosques = <String, Mosque>{};
  final preachers = <String, Preacher>{};
  final series = <String, LessonSeries>{};
  final lessons = <String, Lesson>{};
  final reports = <String, LessonsReport>{};
  final flags = <LessonsFlag>[];
  final audit = <LessonsAuditEntry>[];
  final phones = <String, String>{};

  /// Preachers' private emails, by preacher.
  final emails = <String, String>{};
  final edits = <PreacherEdit>[];
  final applications = <PreacherApplication>[];

  /// The email outbox. Sample data sends nothing: emails show as sent at
  /// once, except decisions, which wait out the 15-minute undo window as on
  /// the server.
  final outbox = <PreacherEmailEntry>[];
  /// Preacher links by their key.
  final links = <String, DemoPreacherLink>{};

  /// Accounts an admin can find (invented people, example.invalid emails).
  static const accounts = [
    LessonsAccount(id: 'demo-account-fahd', nameAr: 'فهد العتيبي', nameEn: 'Fahd Al-Otaibi', email: 'fahd@example.invalid'),
    LessonsAccount(id: 'demo-account-badr', nameAr: 'بدر الشمري', nameEn: 'Badr Al-Shammari', email: 'badr@example.invalid'),
    LessonsAccount(id: 'demo-viewer', nameAr: 'عبدالله السالم', nameEn: 'Abdullah Al-Salem', email: 'abdullah@example.invalid'),
  ];
  final _mine = <String, LessonsMine>{};

  LessonsMine _me() => _mine[currentUserId] ?? const LessonsMine();
  void _setMe(LessonsMine m) => _mine[currentUserId!] = m;

  void _notify(String? profile, String icon, String titleAr, String titleEn, String bodyAr, String bodyEn, String route) {
    if (profile == null || profile == currentUserId) return;
    final m = _mine[profile] ?? const LessonsMine();
    _mine[profile] = m.copyWith(notifications: [
      LessonsNotification(
          id: _id('n'), icon: icon, titleAr: titleAr, titleEn: titleEn, bodyAr: bodyAr, bodyEn: bodyEn,
          route: route, createdAt: DateTime.now()),
      ...m.notifications
    ]);
  }

  void _notifyAdmins(String icon, String titleAr, String titleEn, String bodyAr, String bodyEn, String route) =>
      _notify('demo-admin', icon, titleAr, titleEn, bodyAr, bodyEn, route);

  void _log(String action, String ar, String en, {String? preacherId, bool byLink = false, String note = ''}) =>
      audit.insert(
          0,
          LessonsAuditEntry(
              id: _id('a'), actorId: byLink ? null : currentUserId, preacherId: preacherId,
              actorName: byLink ? '' : _personaName(persona), actorEmail: byLink ? '' : _personaEmail(persona),
              action: action, targetAr: ar, targetEn: en, note: note, createdAt: DateTime.now()));

  static String _personaName(LessonsDemoPersona p) => switch (p) {
        LessonsDemoPersona.admin => 'Khalid Al-Dosari',
        LessonsDemoPersona.viewer => 'Abdullah Al-Salem',
        LessonsDemoPersona.guest => '',
      };

  static String _personaEmail(LessonsDemoPersona p) => switch (p) {
        LessonsDemoPersona.admin => 'khalid@example.invalid',
        LessonsDemoPersona.viewer => 'abdullah@example.invalid',
        LessonsDemoPersona.guest => '',
      };

  static const _decisions = {'request_approved', 'request_rejected', 'application_approved', 'application_rejected'};

  /// Queues an email the way private.preacher_email() does: nothing for a
  /// preacher without an address.
  void _email(String kind, {String? preacherId, String? applicationId}) {
    final app = applications.where((a) => a.id == applicationId).firstOrNull;
    final to = preacherId != null ? emails[preacherId] : app?.email;
    if (to == null || to.isEmpty) return;
    final p = preachers[preacherId];
    final now = DateTime.now();
    final waits = _decisions.contains(kind);
    outbox.insert(
        0,
        PreacherEmailEntry(
            id: _id('em'), kind: kind, status: waits ? 'queued' : 'sent', preacherId: preacherId,
            applicationId: applicationId, to: maskEmail(to), attempts: waits ? 0 : 1, createdAt: now,
            sentAt: waits ? null : now, sendAfter: waits ? now.add(const Duration(minutes: 15)) : now,
            nameAr: p?.nameAr ?? app?.nameAr ?? '', nameEn: p?.name('en') ?? app?.name('en') ?? ''));
  }

  /// An undone decision's waiting email is not sent.
  void _cancelEmails(bool Function(PreacherEmailEntry e) test) {
    for (var i = 0; i < outbox.length; i++) {
      final e = outbox[i];
      if (e.status == 'queued' && test(e)) {
        outbox[i] = PreacherEmailEntry(
            id: e.id, kind: e.kind, status: 'cancelled', preacherId: e.preacherId, applicationId: e.applicationId,
            to: e.to, createdAt: e.createdAt, nameAr: e.nameAr, nameEn: e.nameEn);
      }
    }
  }

  /// In-app notice for a preacher whose card is linked to an account.
  void _notifyPreacher(String preacherId, String icon, String titleAr, String titleEn, String bodyAr, String bodyEn) =>
      _notify(preachers[preacherId]?.linkedProfileId, icon, titleAr, titleEn, bodyAr, bodyEn, '/lessons/me/preacher');

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  // ----------------------------------------------------------------- seed
  void _seed() {
    void district(String id, String city, String ar, String en, int sort) =>
        districts[id] = District(id: id, city: city, nameAr: ar, nameEn: en, sort: sort);
    district('aqrabiyah', 'khobar', 'العقربية', 'Al-Aqrabiyah', 10);
    district('thuqbah', 'khobar', 'الثقبة', 'Al-Thuqbah', 20);
    district('khobar_north', 'khobar', 'الخبر الشمالية', 'North Khobar', 30);
    district('rakah_south', 'khobar', 'الراكة الجنوبية', 'South Al-Rakah', 40);
    district('yarmouk', 'khobar', 'اليرموك', 'Al-Yarmouk', 50);
    district('golden_belt', 'khobar', 'الحزام الذهبي', 'Golden Belt', 60);
    district('doha_south', 'dhahran', 'الدوحة الجنوبية', 'South Doha', 10);
    district('qusur', 'dhahran', 'القصور', 'Al-Qusur', 20);
    district('faisaliyah', 'dammam', 'الفيصلية', 'Al-Faisaliyah', 10);
    district('shati_west', 'dammam', 'الشاطئ الغربي', 'West Shati', 20);
    district('badiyah', 'dammam', 'البادية', 'Al-Badiyah', 30);
    district('rayyan', 'dammam', 'الريان', 'Al-Rayyan', 40);
    district('qatif_central', 'qatif', 'وسط القطيف', 'Central Qatif', 10);

    void mosque(String id, String ar, String en, String d, double lat, double lng, List<String> fac, {bool verified = true}) =>
        mosques[id] = Mosque(
            id: id, nameAr: ar, nameEn: en, districtId: d, latitude: lat, longitude: lng, facilities: fac, verified: verified);
    mosque('m1', 'جامع الهدى', 'Al-Huda Grand Mosque', 'aqrabiyah', 26.292, 50.198, ['women', 'parking', 'access', 'kids']);
    mosque('m2', 'مسجد الفرقان', 'Al-Furqan Mosque', 'thuqbah', 26.270, 50.184, ['women', 'interp']);
    mosque('m3', 'جامع الإحسان', 'Al-Ihsan Grand Mosque', 'khobar_north', 26.305, 50.207, ['women', 'parking', 'access', 'interp']);
    mosque('m4', 'مسجد التوحيد', 'Al-Tawhid Mosque', 'rakah_south', 26.343, 50.193, ['parking']);
    mosque('m5', 'جامع الرحمن', 'Al-Rahman Grand Mosque', 'doha_south', 26.312, 50.158, ['women', 'parking', 'access']);
    mosque('m6', 'مسجد السلام', 'Al-Salam Mosque', 'qusur', 26.286, 50.122, ['parking']);
    mosque('m7', 'جامع النور', 'Al-Noor Grand Mosque', 'faisaliyah', 26.402, 50.058, ['women', 'parking', 'access']);
    mosque('m8', 'مسجد البر', 'Al-Birr Mosque', 'shati_west', 26.452, 50.098, ['women']);
    mosque('m9', 'جامع الصفا', 'Al-Safa Grand Mosque', 'badiyah', 26.432, 50.082, ['women', 'parking', 'kids']);
    mosque('m10', 'مسجد التقوى', 'Al-Taqwa Mosque', 'rayyan', 26.392, 50.132, ['parking', 'interp']);
    mosque('m11', 'جامع المغفرة', 'Al-Maghfirah Grand Mosque', 'yarmouk', 26.255, 50.196, ['women', 'parking']);
    mosque('m12', 'مسجد الأنصار', 'Al-Ansar Mosque', 'qatif_central', 26.565, 50.005, ['women']);
    // Hidden from the public until an admin checks its pin.
    mosque('m13', 'مسجد الإيمان', 'Al-Iman Mosque', 'golden_belt', 26.262, 50.172, ['parking'], verified: false);

    void preacher(String id, String ar, String en, String tAr, String tEn, String city, String aff, List<String> langs,
        {String bioAr = '', String bioEn = ''}) {
      preachers[id] = Preacher(
          id: id, nameAr: ar, nameEn: en, titleAr: tAr, titleEn: tEn, city: city,
          affiliation: aff, languages: langs, bioAr: bioAr, bioEn: bioEn);
      phones[id] = '05000001${id.substring(1).padLeft(2, '0')}';
    }

    preacher('p1', 'الشيخ فهد بن سالم العتيبي', 'Sheikh Fahd Al-Otaibi', 'داعية ومدرّس شرعي', 'Preacher and Sharia teacher', 'khobar', 'coop', ['ar'],
        bioAr: 'يدرّس العقيدة والفقه في مساجد الخبر منذ خمس عشرة سنة، ويبث دروسه الأسبوعية على منصة هداية.',
        bioEn: 'Has taught Aqeedah and Fiqh in Al Khobar mosques for fifteen years and streams his weekly lessons on Hadayah Live.');
    preacher('p2', 'د. عبدالله بن محمد الشهري', 'Dr. Abdullah Al-Shehri', 'أستاذ الفقه المشارك', 'Associate professor of Fiqh', 'dammam', 'ministry', ['ar']);
    preacher('p3', 'الشيخ ياسر بن علي القرني', 'Sheikh Yasser Al-Qarni', 'مدرّس القرآن وعلومه', 'Teacher of the Quran and its sciences', 'dhahran', 'coop', ['ar', 'en']);
    preacher('p4', 'الشيخ محمد إقبال الندوي', 'Sheikh Muhammad Iqbal Nadwi', 'داعية الجالية الناطقة بالأردية', 'Preacher to the Urdu-speaking community', 'khobar', 'coop', ['ur', 'en', 'ar']);
    preacher('p5', 'الشيخ عمر بن خالد الحربي', 'Sheikh Omar Al-Harbi', 'إمام وخطيب', 'Imam and khateeb', 'dammam', 'coop', ['ar']);
    preacher('p6', 'الشيخ عبدالكريم سانتوس', 'Sheikh Abdulkareem Santos', 'داعية الجالية الفلبينية', 'Preacher to the Filipino community', 'khobar', 'coop', ['tl', 'en']);
    preacher('p7', 'د. سلمان بن إبراهيم الزهراني', 'Dr. Salman Al-Zahrani', 'داعية في فرع الوزارة', 'Ministry branch preacher', 'khobar', 'ministry', ['ar']);
    preacher('p8', 'الشيخ نايف بن سعد الدوسري', 'Sheikh Naif Al-Dosari', 'إمام جامع', 'Mosque imam', 'khobar', 'coop', ['ar']);
    preacher('p9', 'أ. نورة بنت عبدالله السبيعي', 'Ustadha Noura Al-Subaie', 'داعية ومدرّسة (دروس النساء)', "Preacher and teacher (women's lessons)", 'khobar', 'coop', ['ar']);
    preacher('p10', 'الشيخ حسن الرحمن', 'Sheikh Hasan Rahman', 'داعية الجالية البنغالية', 'Preacher to the Bengali community', 'dammam', 'coop', ['bn', 'ar']);
    preacher('p11', 'الشيخ منصور بن علي الخالدي', 'Sheikh Mansour Al-Khalidi', 'داعية في فرع الوزارة', 'Ministry branch preacher', 'qatif', 'ministry', ['ar']);
    // Where each starts (lessons can be at any mosque), and the emails the
    // admins hold for some of them.
    const home = {
      'p1': 'm1', 'p2': 'm7', 'p3': 'm5', 'p4': 'm2', 'p5': 'm9', 'p6': 'm3', 'p7': 'm11', 'p8': 'm4', 'p9': 'm1',
      'p10': 'm10', 'p11': 'm12',
    };
    for (final e in home.entries) {
      preachers[e.key] = preachers[e.key]!.copyWith(homeMosqueId: e.value);
    }
    emails['p1'] = 'fahd@example.invalid';
    emails['p4'] = 'iqbal@example.invalid';
    emails['p9'] = 'noura@example.invalid';

    const desc = {
      'lesson': ('درس أسبوعي منتظم يُشرح فيه الكتاب مقطعًا مقطعًا، مع وقت للأسئلة في آخره.',
          'A regular weekly lesson that works through the book passage by passage, with time for questions at the end.'),
      'lecture': ('محاضرة عامة في موضوع واحد، مدتها نحو ساعة، تليها أسئلة الحضور.',
          'A public lecture on one subject, about an hour long, followed by questions from the audience.'),
      'talk': ('كلمة قصيرة بعد الصلاة لا تتجاوز خمس عشرة دقيقة.', 'A short talk after the prayer, no longer than fifteen minutes.'),
    };

    Lesson lesson({
      required String type,
      required String topic,
      required String ar,
      required String en,
      required String preacher,
      String mosque = '',
      required DateTime date,
      required String slot,
      String? seriesId,
      int? seq,
      String? requestId,
      String status = 'approved',
      String source = 'admin',
      String note = '',
      String language = 'ar',
      String audience = 'all',
      String? interp,
      bool streamed = false,
      String? reason,
      Duration submittedAgo = const Duration(days: 7),
    }) {
      final id = _id('l');
      final l = Lesson(
          id: id, requestId: requestId ?? 'r-$id', seriesId: seriesId, seq: seq,
          type: type, topic: topic, titleAr: ar, titleEn: en,
          descriptionAr: source == 'admin' ? desc[type]!.$1 : '', descriptionEn: source == 'admin' ? desc[type]!.$2 : '',
          preacherId: preacher, mosqueId: mosque, date: date, slot: slot, language: language, interpretation: interp,
          audience: audience, womenSection: audience == 'women' || (mosques[mosque]?.facilities.contains('women') ?? false),
          streamed: streamed, status: status, source: source, preacherNote: note, rejectionReason: reason,
          submittedBy: source == 'admin' ? 'demo-admin' : null, submittedAt: DateTime.now().subtract(submittedAgo),
          reviewedBy: status == 'approved' || status == 'rejected' ? 'demo-admin' : null);
      lessons[id] = l;
      return l;
    }

    // Weekly series: four weeks back, up to six ahead.
    final seriesSeed = [
      ('s1', 'شرح كتاب التوحيد', 'Explaining Kitab al-Tawhid', 'p1', 'm1', DateTime.tuesday, 'isha', 20, 9, 'aqeedah', 'ar', 'all', null, true),
      ('s2', 'تفسير جزء عمّ', 'Tafsir of Juz Amma', 'p3', 'm5', DateTime.saturday, 'maghrib', 12, 6, 'tafsir', 'ar', 'all', 'en', false),
      ('s3', 'الأربعون النووية (بالأردية)', 'The Forty Hadith of an-Nawawi (in Urdu)', 'p4', 'm2', DateTime.friday, 'asr', 40, 15, 'hadith', 'ur', 'all', null, false),
      ('s4', 'فقه الصلاة (بالتغالوغ)', 'The Fiqh of Prayer (in Tagalog)', 'p6', 'm3', DateTime.thursday, 'isha', 10, 4, 'fiqh', 'tl', 'all', null, false),
      ('s5', 'أحكام الأسرة في الإسلام', 'Family rulings in Islam', 'p9', 'm1', DateTime.monday, 'asr', 8, 3, 'family', 'ar', 'women', null, false),
      ('s6', 'السيرة النبوية', "The Prophet's biography", 'p2', 'm7', DateTime.sunday, 'maghrib', 24, 12, 'seerah', 'ar', 'all', null, false),
      ('s7', 'الفقه الميسّر', 'Simplified Fiqh', 'p5', 'm8', DateTime.wednesday, 'fajr', 15, 7, 'fiqh', 'ar', 'men', null, false),
    ];
    for (final s in seriesSeed) {
      final reqId = 'rs-${s.$1}';
      series[s.$1] = LessonSeries(
          id: s.$1, requestId: reqId, preacherId: s.$4, mosqueId: s.$5, titleAr: s.$2, titleEn: s.$3,
          type: 'lesson', topic: s.$10, language: s.$11, audience: s.$12, slot: s.$7, total: s.$8, status: 'approved');
      var first = _today;
      while (first.weekday != s.$6) {
        first = addDays(first, 1);
      }
      for (var w = -4; w <= 6; w++) {
        final seq = s.$9 + w;
        if (seq < 1 || seq > s.$8) continue;
        final l = lesson(
            type: 'lesson', topic: s.$10, ar: s.$2, en: s.$3, preacher: s.$4, mosque: s.$5, date: addDays(first, w * 7),
            slot: s.$7, seriesId: s.$1, seq: seq, requestId: reqId, language: s.$11, audience: s.$12, interp: s.$13,
            streamed: s.$14);
        if (l.date.isBefore(_today) && !(s.$4 == 'p1' && w >= -2)) {
          reports[l.id] = LessonsReport(lessonId: l.id, attendance: 40 + (seq * 37 + s.$8) % 90, women: (seq * 7) % 25);
        }
      }
    }

    // One-off lectures and talks around today.
    void one(int off, String slot, String type, String topic, String ar, String en, String p, String m,
            {String language = 'ar', String audience = 'all', bool streamed = false, bool report = false}) {
      final l = lesson(type: type, topic: topic, ar: ar, en: en, preacher: p, mosque: m, date: addDays(_today, off),
          slot: slot, language: language, audience: audience, streamed: streamed);
      if (report) reports[l.id] = LessonsReport(lessonId: l.id, attendance: 72, women: 20);
    }

    one(0, 'isha', 'lecture', 'raqaiq', 'قيمة الوقت في حياة المسلم', 'The value of time in a Muslim’s life', 'p1', 'm3', streamed: true);
    one(0, 'fajr', 'talk', 'raqaiq', 'فضل صلاة الفجر في جماعة', 'The virtue of praying Fajr in congregation', 'p5', 'm9');
    one(0, 'asr', 'talk', 'family', 'حق الجار', 'The rights of neighbours', 'p8', 'm4');
    one(0, 'maghrib', 'lecture', 'intro', 'مدخل إلى الإسلام لغير المسلمين', 'An introduction to Islam for non-Muslims', 'p3', 'm10', language: 'en');
    one(1, 'isha', 'lecture', 'raqaiq', 'التوبة باب مفتوح', 'Repentance, an open door', 'p7', 'm1');
    one(1, 'maghrib', 'lecture', 'intro', 'الإسلام في الحياة اليومية (بالإنجليزية)', 'Islam in everyday life (in English)', 'p6', 'm3', language: 'en');
    one(2, 'dhuhr', 'talk', 'fiqh', 'أحكام الجمع والقصر للمسافر', 'Combining and shortening prayers when travelling', 'p2', 'm7');
    one(2, 'isha', 'lecture', 'family', 'الشباب والهوية', 'Youth and identity', 'p1', 'm4', audience: 'youth');
    one(3, 'maghrib', 'lecture', 'seerah', 'دروس من الهجرة', 'Lessons from the Hijrah', 'p2', 'm9', streamed: true);
    one(4, 'isha', 'lecture', 'raqaiq', 'أهمية الصلاة (بالأردية)', 'The importance of prayer (in Urdu)', 'p4', 'm2', language: 'ur');
    one(5, 'asr', 'talk', 'raqaiq', 'الصدقة الخفية', 'Charity in secret', 'p8', 'm11');
    one(6, 'isha', 'lecture', 'aqeedah', 'أركان الإيمان', 'The pillars of faith', 'p11', 'm12');
    one(8, 'maghrib', 'lecture', 'family', 'تربية الأبناء على الصلاة', 'Raising children to pray', 'p9', 'm5', audience: 'women');
    one(-2, 'isha', 'lecture', 'raqaiq', 'استقبال الشتاء: آداب وأحكام', 'Welcoming winter: etiquette and rulings', 'p1', 'm3');
    one(-5, 'maghrib', 'lecture', 'aqeedah', 'محبة النبي ﷺ', 'Love of the Prophet ﷺ', 'p3', 'm5', report: true);
    one(-9, 'isha', 'lecture', 'intro', 'من هو محمد ﷺ؟ (بالإنجليزية)', 'Who is Muhammad ﷺ? (in English)', 'p6', 'm3', language: 'en', report: true);

    // Requests preachers sent through their links: no mosque yet, the
    // approving admin chooses it.
    lesson(type: 'lecture', topic: 'raqaiq', ar: 'الأمانة في العمل', en: '', preacher: 'p1',
        date: addDays(_today, 3), slot: 'isha', status: 'pending', source: 'preacher', note: 'في جامع الإحسان إن أمكن.',
        submittedAgo: const Duration(hours: 5));
    final s7next = lessons.values.firstWhere((l) => l.seriesId == 's7' && !l.date.isBefore(_today)).date;
    lesson(type: 'talk', topic: 'raqaiq', ar: 'فضل الذكر', en: '', preacher: 'p5', date: s7next, slot: 'fajr',
        status: 'pending', source: 'preacher', submittedAgo: const Duration(hours: 9));
    lesson(type: 'lecture', topic: 'intro', ar: 'مدخل إلى الإسلام (بالتغالوغ)', en: '', preacher: 'p6',
        date: addDays(_today, 2), slot: 'asr', status: 'pending', source: 'preacher', language: 'tl',
        note: 'للجالية الفلبينية، يُفضّل مسجد فيه ترجمة.', submittedAgo: const Duration(hours: 20));
    lesson(type: 'talk', topic: 'fiqh', ar: 'أحكام الوضوء', en: '', preacher: 'p8', date: addDays(_today, 5),
        slot: 'maghrib', status: 'pending', source: 'preacher', submittedAgo: const Duration(hours: 26));
    // A weekly series of eight sessions, one request.
    series['s8'] = const LessonSeries(
        id: 's8', requestId: 'rq-s8', preacherId: 'p4', titleAr: 'السيرة للمبتدئين (بالأردية)', type: 'lesson',
        topic: 'seerah', language: 'ur', audience: 'all', slot: 'isha', total: 8, status: 'pending');
    var d8 = addDays(_today, 1);
    while (d8.weekday != DateTime.wednesday) {
      d8 = addDays(d8, 1);
    }
    for (var i = 0; i < 8; i++) {
      lesson(type: 'lesson', topic: 'seerah', ar: 'السيرة للمبتدئين (بالأردية)', en: '', preacher: 'p4',
          date: addDays(d8, i * 7), slot: 'isha', seriesId: 's8', seq: i + 1, requestId: 'rq-s8', status: 'pending',
          source: 'preacher', language: 'ur', note: 'في مسجد الفرقان كالعادة.', submittedAgo: const Duration(hours: 2));
    }
    // One request an admin turned down, which the preacher sees on his link.
    lesson(type: 'lecture', topic: 'family', ar: 'السعادة الزوجية', en: '', preacher: 'p1', date: addDays(_today, 2),
        slot: 'isha', status: 'rejected', source: 'preacher', submittedAgo: const Duration(days: 3),
        reason: 'تتعارض مع محاضرة الجمعية الكبرى في الليلة نفسها. نقترح الخميس بعد العشاء.');

    final s2next = lessons.values.firstWhere((l) => l.seriesId == 's2' && !l.date.isBefore(_today));
    flags.add(LessonsFlag(
        id: 'f1', lessonId: s2next.id, kind: 'time', message: 'إمام المسجد أعلن أن الدرس صار بعد العصر بدل المغرب.',
        reporterId: 'demo-viewer', createdAt: DateTime.now().subtract(const Duration(hours: 7))));

    // Sheikh Muhammad Iqbal proposed a fuller card through his link.
    edits.add(PreacherEdit(
        id: 'e1', preacherId: 'p4',
        changes: const {
          'title_ar': 'داعية الجالية الناطقة بالأردية ومدرّس الحديث',
          'bio_ar': 'يلقي دروسه بالأردية في مساجد الخبر منذ عشر سنين، ويشرح الأربعين النووية كل جمعة.',
          'languages': ['ur', 'en', 'ar'],
        },
        createdAt: DateTime.now().subtract(const Duration(hours: 3))));

    // Links: Sheikh Fahd's one-time link not opened yet; Sheikh Iqbal's
    // timed link open this week (he has opened it); an old revoked one.
    links[fahdLink] = DemoPreacherLink(id: 'k1', preacherId: 'p1', kind: 'once', createdAt: DateTime.now().subtract(const Duration(days: 1)));
    links[iqbalLink] = DemoPreacherLink(
        id: 'k2', preacherId: 'p4', kind: 'window', validFrom: DateTime.now().subtract(const Duration(days: 2)),
        validUntil: DateTime.now().add(const Duration(days: 5)), note: 'رمضان', createdAt: DateTime.now().subtract(const Duration(days: 2)))
      ..openedAt = DateTime.now().subtract(const Duration(hours: 4))
      ..lastUsedAt = DateTime.now().subtract(const Duration(hours: 3));
    links['demo-old'] = DemoPreacherLink(id: 'k3', preacherId: 'p4', kind: 'once', createdAt: DateTime.now().subtract(const Duration(days: 40)))
      ..device = 'old-phone'
      ..revokedAt = DateTime.now().subtract(const Duration(days: 30));

    final s1next = lessons.values.firstWhere((l) => l.seriesId == 's1' && !l.date.isBefore(_today));
    _mine['demo-viewer'] = LessonsMine(
      reminders: {s1next.id: LessonsReminder(lessonId: s1next.id, lead: 'adhan', remindAt: DateTime.now().add(const Duration(days: 1)))},
      follows: const {'preacher:p1', 'preacher:p4', 'series:s1', 'mosque:m1'},
      attended: {for (final l in lessons.values.where((l) => l.seriesId == 's1' && l.date.isBefore(_today)).take(3)) l.id},
      notifications: [
        LessonsNotification(id: 'n1', icon: 'bell', titleAr: 'تذكير: دروس الليلة', titleEn: "Reminder: tonight's lessons",
            bodyAr: 'لديك تذكير بدرس بعد العشاء في جامع الهدى.', bodyEn: 'You have a reminder for a lesson after Isha at Al-Huda Grand Mosque.',
            route: '/lessons/lesson/${s1next.id}', createdAt: DateTime.now().subtract(const Duration(minutes: 40))),
        LessonsNotification(id: 'n2', icon: 'sparkle', titleAr: 'محاضرة جديدة من داعية تتابعه', titleEn: 'New lecture from a preacher you follow',
            bodyAr: 'الشيخ فهد العتيبي: الشباب والهوية.', bodyEn: 'Sheikh Fahd Al-Otaibi: Youth and identity.',
            route: '/lessons/preachers/p1', createdAt: DateTime.now().subtract(const Duration(hours: 5))),
      ],
    );
    _mine['demo-admin'] = LessonsMine(notifications: [
      LessonsNotification(id: 'n7', icon: 'inbox', titleAr: 'طلبات جديدة من الدعاة', titleEn: 'New requests from preachers',
          bodyAr: 'منها سلسلة أسبوعية من ثماني جلسات بالأردية.', bodyEn: 'Including an eight-session weekly series in Urdu.',
          route: '/admin/lessons/approvals', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    ]);
    // Someone applied from his account; the admins have not decided yet.
    applications.add(PreacherApplication(
        id: sampleApplication, profileId: 'demo-applicant', nameAr: 'الشيخ سعد بن عمر الغامدي', nameEn: 'Sheikh Saad Al-Ghamdi',
        titleAr: 'إمام وخطيب', bioAr: 'إمام جامع منذ ثماني سنوات، ويدرّس الفقه الميسّر للشباب.', city: 'dammam',
        mosqueId: 'm9', languages: const ['ar'], phone: '0500000177', email: 'saad@example.invalid',
        experience: 'إجازة في الفقه من كلية الشريعة، وثماني سنوات إمامًا وخطيبًا في الدمام.',
        createdAt: DateTime.now().subtract(const Duration(hours: 6))));
    final sent = DateTime.now().subtract(const Duration(days: 1));
    outbox.addAll([
      PreacherEmailEntry(id: 'em1', kind: 'application_received', status: 'sent', applicationId: sampleApplication,
          to: maskEmail('saad@example.invalid'), attempts: 1, createdAt: DateTime.now().subtract(const Duration(hours: 6)),
          sentAt: DateTime.now().subtract(const Duration(hours: 6)), nameAr: 'الشيخ سعد بن عمر الغامدي', nameEn: 'Sheikh Saad Al-Ghamdi'),
      PreacherEmailEntry(id: 'em2', kind: 'invite', status: 'sent', preacherId: 'p1', to: maskEmail('fahd@example.invalid'),
          attempts: 1, createdAt: sent, sentAt: sent, nameAr: preachers['p1']!.nameAr, nameEn: preachers['p1']!.nameEn),
    ]);
    audit.addAll([
      LessonsAuditEntry(id: 'a0', action: 'applicationReceived', actorId: 'demo-applicant', actorName: 'Saad Al-Ghamdi',
          actorEmail: 'saad@example.invalid', targetAr: 'الشيخ سعد بن عمر الغامدي', targetEn: 'Sheikh Saad Al-Ghamdi',
          createdAt: DateTime.now().subtract(const Duration(hours: 6))),
      LessonsAuditEntry(id: 'a1', actorId: 'demo-admin', actorName: 'Khalid Al-Dosari', actorEmail: 'khalid@example.invalid',
          action: 'reject', preacherId: 'p1', note: 'تتعارض مع محاضرة الجمعية الكبرى في الليلة نفسها. نقترح الخميس بعد العشاء.',
          targetAr: 'السعادة الزوجية — الشيخ فهد العتيبي', targetEn: 'A happy marriage, Sheikh Fahd Al-Otaibi',
          createdAt: DateTime.now().subtract(const Duration(days: 2))),
      LessonsAuditEntry(id: 'a2', actorId: 'demo-admin', actorName: 'Khalid Al-Dosari', actorEmail: 'khalid@example.invalid',
          action: 'add', preacherId: 'p1',
          targetAr: 'الشباب والهوية — الشيخ فهد العتيبي', targetEn: 'Youth and identity, Sheikh Fahd Al-Otaibi',
          createdAt: DateTime.now().subtract(const Duration(days: 4))),
    ]);
  }

  // ---------------------------------------------------------------- reads
  bool _visible(Lesson l) => l.status == 'approved' || l.status == 'cancelled' || _admin;

  @override
  Future<LessonsCatalog> loadCatalog() async => LessonsCatalog(
        districts: Map.of(districts),
        mosques: {for (final m in mosques.values.where((m) => m.verified || _admin)) m.id: m},
        preachers: {
          for (final p in preachers.values.where((p) => p.listed || _admin || p.linkedProfileId == currentUserId)) p.id: p
        },
        series: {for (final s in series.values.where((s) => s.status == 'approved' || _admin)) s.id: s},
        lessons: {for (final l in lessons.values.where(_visible)) l.id: l},
      );

  @override
  Future<LessonsRoles> loadRoles() async {
    if (persona == LessonsDemoPersona.guest) return LessonsRoles.guest;
    final mine = applications.where((a) => a.profileId == currentUserId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final app = mine.firstOrNull;
    return LessonsRoles(
        signedIn: true,
        admin: _admin,
        preacherId: preachers.values.where((p) => p.linkedProfileId == currentUserId).firstOrNull?.id,
        application: app == null
            ? null
            : MyPreacherApplication(id: app.id, status: app.status, reason: app.reason, createdAt: app.createdAt));
  }

  @override
  Future<LessonsMine> loadMine() async => currentUserId == null ? const LessonsMine() : _me();

  @override
  Future<LessonsAdminData> loadAdmin() async {
    _need(_admin);
    final now = DateTime.now();
    return LessonsAdminData(
      roster: [
        for (final p in preachers.values.toList()..sort((a, b) => a.nameAr.compareTo(b.nameAr)))
          LessonsRosterEntry(
              preacher: p,
              phoneMask: phones[p.id] == null ? null : maskPhone(phones[p.id]),
              emailMask: emails[p.id] == null ? null : maskEmail(emails[p.id]!),
              activeKeys: links.values
                  .where((k) => k.preacherId == p.id && k.revokedAt == null && (k.validUntil == null || k.validUntil!.isAfter(now)))
                  .length,
              lastSeen: links.values
                  .where((k) => k.preacherId == p.id && k.lastUsedAt != null)
                  .map((k) => k.lastUsedAt!)
                  .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a),
              pendingEdits: edits.where((e) => e.preacherId == p.id && e.pending).length,
              lessons30d: lessons.values
                  .where((l) =>
                      l.preacherId == p.id &&
                      l.status == 'approved' &&
                      !l.date.isAfter(_today) &&
                      !l.date.isBefore(addDays(_today, -30)))
                  .length)
      ],
      edits: [for (final e in edits.where((e) => e.pending)) e],
      flags: List.of(flags),
      audit: List.of(audit),
      reports: Map.of(reports),
      applications: List.of(applications)..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  // --------------------------------------------------------------- viewer
  @override
  Future<void> setReminder(String lessonId, String lead, DateTime remindAt) async {
    _signedIn();
    if (lessons[lessonId]?.status != 'approved') throw const LessonsException(LessonsFailure.forbidden);
    _setMe(_me().copyWith(
        reminders: {..._me().reminders, lessonId: LessonsReminder(lessonId: lessonId, lead: lead, remindAt: remindAt)}));
  }

  @override
  Future<void> removeReminder(String lessonId) async {
    _signedIn();
    _setMe(_me().copyWith(reminders: Map.of(_me().reminders)..remove(lessonId)));
  }

  @override
  Future<void> setFollow(String kind, String id, bool on) async {
    _signedIn();
    final f = {..._me().follows};
    on ? f.add('$kind:$id') : f.remove('$kind:$id');
    _setMe(_me().copyWith(follows: f));
  }

  @override
  Future<void> setAttended(String lessonId, bool on) async {
    _signedIn();
    final a = {..._me().attended};
    on ? a.add(lessonId) : a.remove(lessonId);
    _setMe(_me().copyWith(attended: a));
  }

  @override
  Future<void> savePreferences(LessonsPreferences preferences) async {
    _signedIn();
    _setMe(_me().copyWith(preferences: preferences));
  }

  @override
  Future<void> markNotificationsRead([List<String>? ids]) async {
    _signedIn();
    _setMe(_me().copyWith(notifications: [
      for (final n in _me().notifications) (ids == null || ids.contains(n.id)) && n.unread ? n.markRead() : n
    ]));
  }

  @override
  Future<void> flag(String lessonId, String kind, String message) async {
    _signedIn();
    final l = lessons[lessonId]!;
    flags.insert(0, LessonsFlag(
        id: _id('f'), lessonId: lessonId, kind: kind, message: message, reporterId: currentUserId, createdAt: DateTime.now()));
    _notifyAdmins('flag', 'بلاغ جديد من مستخدم', 'New report from a user', l.titleAr, l.title('en'), '/admin/lessons/reports');
  }

  // --------------------------------------------------------------- lessons
  void _notifyFollowers(Preacher p, Lesson l) {
    for (final e in _mine.entries.toList()) {
      if (e.value.isFollowing('preacher', p.id) || e.value.isFollowing('mosque', l.mosqueId)) {
        _notify(e.key, 'sparkle', 'درس جديد من داعية تتابعه', 'New lesson from a preacher you follow',
            '${p.nameAr}: ${l.titleAr}', '${p.name('en')}: ${l.title('en')}', '/lessons/requests/${l.requestId}');
      }
    }
  }

  @override
  Future<String> addLessons(LessonDraft d) async {
    _need(_admin);
    final p = preachers[d.preacherId];
    final dates = {...d.dates}.toList()..sort();
    if (p == null || dates.isEmpty || dates.length > 40 ||
        dates.first.isBefore(addDays(_today, -60)) || dates.last.isAfter(addDays(_today, 400))) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    var mosqueId = d.mosqueId;
    if (d.newMosque != null) {
      mosqueId = _id('m');
      mosques[mosqueId] = Mosque(
          id: mosqueId, nameAr: d.newMosque!.nameAr, nameEn: d.newMosque!.nameEn, districtId: d.newMosque!.districtId,
          latitude: d.newMosque!.latitude, longitude: d.newMosque!.longitude, facilities: d.newMosque!.facilities);
      _log('addMosque', d.newMosque!.nameAr, d.newMosque!.nameEn.isEmpty ? d.newMosque!.nameAr : d.newMosque!.nameEn);
    }
    if (mosqueId == null || !mosques.containsKey(mosqueId)) throw const LessonsException(LessonsFailure.invalid);
    final req = _id('rq');
    String? seriesId;
    if (dates.length > 1) {
      seriesId = _id('s');
      series[seriesId] = LessonSeries(
          id: seriesId, requestId: req, preacherId: d.preacherId, mosqueId: mosqueId, titleAr: d.titleAr,
          titleEn: d.titleEn, type: d.type, topic: d.topic, language: d.language, audience: d.audience, slot: d.slot,
          total: dates.length, status: 'approved');
    }
    final added = [
      for (var i = 0; i < dates.length; i++)
        Lesson(
            id: _id('l'), requestId: req, seriesId: seriesId, seq: seriesId == null ? null : i + 1, type: d.type,
            topic: d.topic, titleAr: d.titleAr, titleEn: d.titleEn, descriptionAr: d.descriptionAr,
            preacherId: d.preacherId, mosqueId: mosqueId, date: dates[i], slot: d.slot, exactTime: d.exactTime,
            language: d.language, interpretation: d.interpretation, audience: d.audience,
            womenSection: d.womenSection, streamed: d.streamed, notifyFollowers: d.notifyFollowers,
            submittedBy: currentUserId, submittedAt: DateTime.now(), reviewedBy: currentUserId,
            reviewedAt: DateTime.now()),
    ];
    for (final l in added) {
      lessons[l.id] = l;
    }
    _log('add', '${d.titleAr} — ${p.nameAr}', '${d.titleEn.isEmpty ? d.titleAr : d.titleEn}, ${p.name('en')}',
        preacherId: p.id);
    if (d.notifyFollowers) _notifyFollowers(p, added.first);
    if (added.any((l) => !l.date.isBefore(_today))) {
      _email('lesson_assigned', preacherId: p.id);
      _notifyPreacher(p.id, 'calendar', 'أُضيف لك درس: ${d.titleAr}', 'A lesson was added for you: ${added.first.title('en')}',
          isoDate(added.first.date), isoDate(added.first.date));
    }
    return req;
  }

  @override
  Future<int> review(List<String> requestIds, String decision, {String? reason, String? mosqueId}) async {
    _need(_admin);
    if (decision != 'approve' && decision != 'reject') throw const LessonsException(LessonsFailure.invalid);
    if (decision == 'reject' && (reason == null || reason.trim().length < 3)) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    if (mosqueId != null && !mosques.containsKey(mosqueId)) throw const LessonsException(LessonsFailure.invalid);
    final status = decision == 'approve' ? 'approved' : 'rejected';
    var n = 0;
    for (final rid in requestIds) {
      final items = lessons.values.where((l) => l.requestId == rid && l.status == 'pending').toList();
      if (items.isEmpty) continue;
      if (status == 'approved' && items.any((l) => !l.hasMosque) && mosqueId == null) {
        throw const LessonsException(LessonsFailure.invalid, 'mosque');
      }
      n++;
      for (final l in items) {
        lessons[l.id] = l.copyWith(
            status: status, reviewedBy: currentUserId, reviewedAt: DateTime.now(),
            mosqueId: status == 'approved' && !l.hasMosque ? mosqueId : null,
            rejectionReason: status == 'rejected' ? reason : null);
      }
      for (final s in series.values.where((s) => s.requestId == rid).toList()) {
        series[s.id] = s.copyWith(status: status, mosqueId: status == 'approved' && s.mosqueId.isEmpty ? mosqueId : null);
      }
      final l = lessons[items.first.id]!, p = preachers[l.preacherId]!;
      _log(decision, '${l.titleAr} — ${p.nameAr}', '${l.title('en')}, ${p.name('en')}', preacherId: p.id,
          note: status == 'rejected' ? reason!.trim() : '');
      if (status == 'approved' && l.notifyFollowers) _notifyFollowers(p, l);
      if (l.fromPreacher) _email(status == 'approved' ? 'request_approved' : 'request_rejected', preacherId: p.id);
      _notifyPreacher(
          p.id,
          status == 'approved' ? 'check' : 'x',
          status == 'approved' ? 'قُبل طلبك: ${l.titleAr}' : 'لم يُقبل طلبك: ${l.titleAr}',
          status == 'approved' ? 'Your request was approved: ${l.title('en')}' : 'Your request was declined: ${l.title('en')}',
          status == 'approved' ? isoDate(l.date) : reason!.trim(),
          status == 'approved' ? isoDate(l.date) : reason!.trim());
    }
    return n;
  }

  @override
  Future<int> undoReview(List<String> requestIds) async {
    _need(_admin);
    var n = 0;
    for (final l in lessons.values.toList()) {
      if (requestIds.contains(l.requestId) && l.fromPreacher && (l.status == 'approved' || l.status == 'rejected') &&
          l.reviewedBy == currentUserId) {
        lessons[l.id] = l.copyWith(status: 'pending', clearReview: true, clearRejection: true);
        n++;
      }
    }
    for (final s in series.values.where((s) => requestIds.contains(s.requestId)).toList()) {
      series[s.id] = s.copyWith(status: 'pending');
    }
    if (n > 0) {
      final undone = {for (final l in lessons.values.where((l) => requestIds.contains(l.requestId))) l.preacherId};
      _cancelEmails((e) => e.kind.startsWith('request_') && undone.contains(e.preacherId));
      _log('undo', 'تراجع عن قرار', 'Undid a decision');
    }
    return n;
  }

  void _withdraw(String requestId, {bool byLink = false}) {
    final items = lessons.values.where((l) => l.requestId == requestId && l.status == 'pending').toList();
    if (items.isEmpty) throw const LessonsException(LessonsFailure.invalid);
    for (final l in items) {
      lessons[l.id] = l.copyWith(status: 'withdrawn');
    }
    for (final s in series.values.where((s) => s.requestId == requestId).toList()) {
      series[s.id] = s.copyWith(status: 'withdrawn');
    }
    _log('withdraw', items.first.titleAr, items.first.title('en'), preacherId: items.first.preacherId, byLink: byLink);
  }

  @override
  Future<void> withdraw(String requestId) async {
    _need(_admin);
    _withdraw(requestId);
  }

  @override
  Future<int> cancelLesson(String lessonId, String reason) async {
    _need(_admin);
    final l = lessons[lessonId];
    if (l == null || l.status != 'approved' || l.date.isBefore(_today) || reason.trim().isEmpty) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    lessons[lessonId] = l.copyWith(status: 'cancelled', cancelReason: reason);
    var n = 0;
    for (final e in _mine.entries.toList()) {
      if (e.value.reminders.containsKey(lessonId)) {
        n++;
        _notify(e.key, 'alert', 'أُلغي موعد: ${l.titleAr}', 'Cancelled: ${l.title('en')}', '${isoDate(l.date)} — $reason',
            '${isoDate(l.date)}: $reason', '/lessons/lesson/$lessonId');
      }
    }
    _log('cancel', '${l.titleAr} — ${isoDate(l.date)}', '${l.title('en')}, ${isoDate(l.date)}', preacherId: l.preacherId,
        note: reason.trim());
    _email('lesson_cancelled', preacherId: l.preacherId);
    _notifyPreacher(l.preacherId, 'alert', 'أُلغي موعد: ${l.titleAr}', 'Cancelled: ${l.title('en')}', reason, reason);
    return n;
  }

  @override
  Future<void> editLesson(String lessonId, Map<String, dynamic> patch) async {
    _need(_admin);
    final l = lessons[lessonId];
    if (l == null || (l.status != 'approved' && l.status != 'pending')) throw const LessonsException(LessonsFailure.invalid);
    if (patch['mosque_id'] != null && !mosques.containsKey(patch['mosque_id'])) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    lessons[lessonId] = l.copyWith(
        titleAr: patch['title_ar'] as String?,
        titleEn: patch['title_en'] as String?,
        type: patch['type'] as String?,
        topic: patch['topic'] as String?,
        mosqueId: patch['mosque_id'] as String?,
        date: patch['lesson_date'] == null ? null : parseIsoDate(patch['lesson_date'] as String),
        slot: patch['slot'] as String?,
        exactTime: patch['exact_time'] as String?,
        clearExact: patch.containsKey('exact_time') && patch['exact_time'] == null);
    _log('edit', l.titleAr, l.title('en'), preacherId: l.preacherId);
    final n = lessons[lessonId]!;
    if (l.status == 'approved' && !n.date.isBefore(_today) &&
        (n.date != l.date || n.slot != l.slot || n.exactTime != l.exactTime || n.mosqueId != l.mosqueId)) {
      _email('lesson_changed', preacherId: l.preacherId);
      _notifyPreacher(l.preacherId, 'clock', 'تغيّر موعد درسك: ${l.titleAr}', 'Your lesson moved: ${l.title('en')}',
          isoDate(n.date), isoDate(n.date));
    }
  }

  @override
  Future<void> postReport(String lessonId, int attendance, int women, String issue, String notes) async {
    _need(_admin);
    final l = lessons[lessonId]!;
    if (l.status != 'approved' || l.date.isAfter(_today)) throw const LessonsException(LessonsFailure.invalid);
    reports[lessonId] = LessonsReport(lessonId: lessonId, attendance: attendance, women: women, issue: issue, notes: notes);
    _log('report', l.titleAr, l.title('en'), preacherId: l.preacherId);
  }

  @override
  Future<void> resolveFlag(String flagId) async {
    _need(_admin);
    final i = flags.indexWhere((f) => f.id == flagId);
    if (i < 0) throw const LessonsException(LessonsFailure.invalid);
    flags[i] = flags[i].resolved();
    _log('resolve', 'بلاغ على درس', 'Report on a lesson');
  }

  // ------------------------------------------------------------ preachers
  @override
  Future<String> upsertPreacher(Map<String, dynamic> p) async {
    _need(_admin);
    final id = p['id'] as String? ?? _id('p');
    final old = preachers[id];
    final name = (p['name_ar'] as String? ?? old?.nameAr ?? '').trim();
    if (name.length < 3) throw const LessonsException(LessonsFailure.invalid);
    final email = (p['email'] as String? ?? '').trim().toLowerCase();
    if (email.isNotEmpty && !_emailShape.hasMatch(email)) throw const LessonsException(LessonsFailure.invalid);
    final home = p['home_mosque_id'] as String?;
    if (home != null && !mosques.containsKey(home)) throw const LessonsException(LessonsFailure.invalid);
    preachers[id] = Preacher(
        id: id,
        linkedProfileId: p.containsKey('linked_profile_id') ? p['linked_profile_id'] as String? : old?.linkedProfileId,
        nameAr: name,
        nameEn: p['name_en'] as String? ?? old?.nameEn ?? '',
        titleAr: p['title_ar'] as String? ?? old?.titleAr ?? '',
        titleEn: p['title_en'] as String? ?? old?.titleEn ?? '',
        bioAr: p['bio_ar'] as String? ?? old?.bioAr ?? '',
        bioEn: p['bio_en'] as String? ?? old?.bioEn ?? '',
        photoUrl: p.containsKey('photo_url') ? p['photo_url'] as String? : old?.photoUrl,
        city: p['city'] as String? ?? old?.city ?? 'khobar',
        affiliation: p['affiliation'] as String? ?? old?.affiliation ?? 'coop',
        languages: (p['languages'] as List?)?.cast<String>() ?? old?.languages ?? const ['ar'],
        listed: p['listed'] as bool? ?? old?.listed ?? true,
        homeMosqueId: p.containsKey('home_mosque_id') ? home : old?.homeMosqueId,
        joinedVia: old?.joinedVia ?? 'admin');
    if (p.containsKey('phone')) {
      final phone = (p['phone'] as String? ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
      phone.isEmpty ? phones.remove(id) : phones[id] = phone;
    }
    if (p.containsKey('email')) email.isEmpty ? emails.remove(id) : emails[id] = email;
    _log(old == null ? 'addPreacher' : 'editPreacher', preachers[id]!.nameAr, preachers[id]!.name('en'), preacherId: id);
    return id;
  }

  @override
  Future<int> removePreacher(String preacherId) async {
    _need(_admin);
    final p = preachers.remove(preacherId);
    if (p == null) throw const LessonsException(LessonsFailure.invalid);
    final n = lessons.values.where((l) => l.preacherId == preacherId).length;
    lessons.removeWhere((_, l) => l.preacherId == preacherId);
    series.removeWhere((_, s) => s.preacherId == preacherId);
    links.removeWhere((_, k) => k.preacherId == preacherId);
    edits.removeWhere((e) => e.preacherId == preacherId);
    phones.remove(preacherId);
    emails.remove(preacherId);
    outbox.removeWhere((e) => e.preacherId == preacherId);
    for (final e in _mine.entries.toList()) {
      _mine[e.key] = e.value.copyWith(follows: {...e.value.follows}..remove('preacher:$preacherId'));
    }
    _log('removePreacher', p.nameAr, p.name('en'));
    return n;
  }

  @override
  Future<int> importPreachers(List<Map<String, dynamic>> rows) async {
    _need(_admin);
    if (rows.length > 500) throw const LessonsException(LessonsFailure.invalid);
    for (final r in rows) {
      final id = _id('p');
      preachers[id] = Preacher(
          id: id, nameAr: (r['name'] as String).trim(), city: r['city'] as String? ?? 'khobar',
          affiliation: r['affiliation'] as String? ?? 'coop');
      final phone = (r['phone'] as String? ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
      if (phone.isNotEmpty) phones[id] = phone;
    }
    _log('import', 'استيراد ${rows.length} داعية', 'Imported ${rows.length} preachers');
    return rows.length;
  }

  @override
  Future<String?> revealPhone(String preacherId) async {
    _need(_admin);
    final p = preachers[preacherId];
    if (p == null) throw const LessonsException(LessonsFailure.invalid);
    _log('phone', p.nameAr, p.name('en'), preacherId: preacherId);
    return phones[preacherId];
  }

  @override
  Future<String?> revealEmail(String preacherId) async {
    _need(_admin);
    final p = preachers[preacherId];
    if (p == null) throw const LessonsException(LessonsFailure.invalid);
    _log('email', p.nameAr, p.name('en'), preacherId: preacherId);
    return emails[preacherId];
  }

  /// Sample data keeps the picture in the address itself.
  @override
  Future<String> uploadPhoto(Uint8List bytes, {bool application = false}) async {
    if (application ? currentUserId == null : !_admin) throw const LessonsException(LessonsFailure.forbidden);
    final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    return 'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
  }

  @override
  Future<void> decideEdit(String editId, bool approve, {String? reason}) async {
    _need(_admin);
    final i = edits.indexWhere((e) => e.id == editId && e.pending);
    if (i < 0) throw const LessonsException(LessonsFailure.invalid);
    final e = edits[i];
    final p = preachers[e.preacherId]!;
    if (approve) {
      final x = e.changes;
      final name = (x['name_ar'] as String? ?? '').trim();
      if ((x['email'] as String? ?? '').isNotEmpty) emails[p.id] = x['email'] as String;
      preachers[p.id] = p.copyWith(
          nameAr: name.isEmpty ? null : name,
          nameEn: x['name_en'] as String?,
          titleAr: x['title_ar'] as String?,
          titleEn: x['title_en'] as String?,
          bioAr: x['bio_ar'] as String?,
          bioEn: x['bio_en'] as String?,
          languages: (x['languages'] as List?)?.cast<String>());
    }
    edits[i] = PreacherEdit(
        id: e.id, preacherId: e.preacherId, changes: e.changes, status: approve ? 'approved' : 'rejected',
        reason: reason, createdAt: e.createdAt);
    _log(approve ? 'editApproved' : 'editRejected', p.nameAr, p.name('en'), preacherId: p.id, note: reason ?? '');
    _email(approve ? 'card_approved' : 'card_rejected', preacherId: p.id);
    _notifyPreacher(p.id, approve ? 'check' : 'x', approve ? 'اعتُمد تعديل بطاقتك' : 'لم يُعتمد تعديل بطاقتك',
        approve ? 'Your card change was approved' : 'Your card change was declined', reason ?? '', reason ?? '');
  }

  // --------------------------------------------------------- applications
  @override
  Future<String> apply(PreacherApplicationDraft d) async {
    _signedIn();
    if (preachers.values.any((p) => p.linkedProfileId == currentUserId)) {
      throw const LessonsException(LessonsFailure.conflict, 'already_preacher');
    }
    if (applications.any((a) => a.profileId == currentUserId && a.pending)) {
      throw const LessonsException(LessonsFailure.conflict, 'pending');
    }
    final m = mosques[d.mosqueId];
    final mosqueOk = d.mosqueId != null
        ? m != null && m.verified && districts[m.districtId]?.city == d.city
        : (d.newMosqueName ?? '').trim().length >= 2 && districts[d.newMosqueDistrict]?.city == d.city;
    final phone = d.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!mosqueOk || d.nameAr.trim().length < 3 || phone.length < 7 || !_emailShape.hasMatch(d.email.trim())) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    final a = PreacherApplication(
        id: _id('app'), profileId: currentUserId!, nameAr: d.nameAr.trim(), nameEn: d.nameEn.trim(),
        titleAr: d.titleAr.trim(), bioAr: d.bioAr.trim(), photoUrl: d.photoUrl, city: d.city, mosqueId: d.mosqueId,
        newMosqueName: d.mosqueId == null ? d.newMosqueName?.trim() : null,
        newMosqueDistrict: d.mosqueId == null ? d.newMosqueDistrict : null, languages: d.languages, phone: phone,
        email: d.email.trim().toLowerCase(), experience: d.experience.trim(), sampleUrl: d.sampleUrl,
        createdAt: DateTime.now());
    applications.add(a);
    _log('applicationReceived', a.nameAr, a.name('en'));
    _notifyAdmins('user', 'طلب انضمام جديد من داعية', 'A new preacher application', a.nameAr, a.name('en'),
        '/admin/lessons/approvals');
    _email('application_received', applicationId: a.id);
    return a.id;
  }

  void _setApplication(PreacherApplication a, {required String status, String? reason, String? preacherId, String? mosqueId}) {
    final i = applications.indexWhere((x) => x.id == a.id);
    applications[i] = PreacherApplication(
        id: a.id, profileId: a.profileId, nameAr: a.nameAr, nameEn: a.nameEn, titleAr: a.titleAr, bioAr: a.bioAr,
        photoUrl: a.photoUrl, city: a.city, mosqueId: mosqueId ?? a.mosqueId, newMosqueName: a.newMosqueName,
        newMosqueDistrict: a.newMosqueDistrict, languages: a.languages, phone: a.phone, email: a.email,
        experience: a.experience, sampleUrl: a.sampleUrl, status: status, reason: reason, preacherId: preacherId,
        decidedBy: status == 'pending' || status == 'withdrawn' ? null : currentUserId,
        decidedAt: status == 'pending' || status == 'withdrawn' ? null : DateTime.now(), createdAt: a.createdAt);
  }

  @override
  Future<void> withdrawApplication() async {
    _signedIn();
    final a = applications.where((a) => a.profileId == currentUserId && a.pending).firstOrNull;
    if (a == null) throw const LessonsException(LessonsFailure.invalid);
    _setApplication(a, status: 'withdrawn');
    _log('applicationWithdrawn', a.nameAr, a.name('en'));
  }

  @override
  Future<String?> decideApplication(String applicationId, bool approve,
      {String? reason, String? mosqueId, String? affiliation}) async {
    _need(_admin);
    final a = applications.where((a) => a.id == applicationId && a.pending).firstOrNull;
    if (a == null) throw const LessonsException(LessonsFailure.invalid);
    final why = reason?.trim() ?? '';
    if (!approve) {
      if (why.length < 3) throw const LessonsException(LessonsFailure.invalid);
      _setApplication(a, status: 'rejected', reason: why);
      _log('applicationRejected', a.nameAr, a.name('en'), note: why);
      _notify(a.profileId, 'x', 'لم يُقبل طلب انضمامك داعيةً', 'Your preacher application was declined', why, why, '/lessons/apply');
      _email('application_rejected', applicationId: a.id);
      return null;
    }
    if (preachers.values.any((p) => p.linkedProfileId == a.profileId)) {
      throw const LessonsException(LessonsFailure.conflict, 'already_preacher');
    }
    var mid = mosqueId ?? a.mosqueId;
    if (mid == null) {
      if (a.newMosqueName == null || a.newMosqueDistrict == null) throw const LessonsException(LessonsFailure.invalid);
      mid = _id('m');
      mosques[mid] = Mosque(id: mid, nameAr: a.newMosqueName!, districtId: a.newMosqueDistrict!);
      _log('addMosque', a.newMosqueName!, a.newMosqueName!);
    } else if (!mosques.containsKey(mid)) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    final pid = _id('p');
    preachers[pid] = Preacher(
        id: pid, linkedProfileId: a.profileId, nameAr: a.nameAr, nameEn: a.nameEn, titleAr: a.titleAr, bioAr: a.bioAr,
        photoUrl: a.photoUrl, city: a.city, affiliation: affiliation ?? 'coop', languages: a.languages,
        homeMosqueId: mid, joinedVia: 'application');
    phones[pid] = a.phone;
    emails[pid] = a.email;
    _setApplication(a, status: 'approved', reason: why.isEmpty ? null : why, preacherId: pid, mosqueId: mid);
    _log('applicationApproved', a.nameAr, a.name('en'), preacherId: pid, note: why);
    _notify(a.profileId, 'check', 'قُبلتَ داعيةً في برنامج الدروس', 'You are now a preacher in the lessons programme',
        'صفحتك في الإعدادات: صفحتي داعيةً.', 'Your page is in Settings: My preacher page.', '/lessons/me/preacher');
    outbox.removeWhere((e) => e.applicationId == a.id && e.kind == 'application_approved');
    _email('application_approved', preacherId: pid, applicationId: a.id);
    return pid;
  }

  @override
  Future<void> undoApplication(String applicationId) async {
    _need(_admin);
    final a = applications.where((a) => a.id == applicationId).firstOrNull;
    if (a == null || a.pending || a.status == 'withdrawn' || a.decidedBy != currentUserId ||
        DateTime.now().difference(a.decidedAt!) > const Duration(minutes: 15)) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    if (a.status == 'approved') {
      if (lessons.values.any((l) => l.preacherId == a.preacherId)) throw const LessonsException(LessonsFailure.conflict);
      preachers.remove(a.preacherId);
      phones.remove(a.preacherId);
      emails.remove(a.preacherId);
    }
    _cancelEmails((e) => e.applicationId == a.id && e.kind.startsWith('application_'));
    _setApplication(a, status: 'pending');
    _log('undo', a.nameAr, a.name('en'));
  }

  // --------------------------------------------------------------- emails
  @override
  Future<List<PreacherEmailEntry>> loadEmails({String? preacherId}) async {
    _need(_admin);
    return [for (final e in outbox) if (preacherId == null || e.preacherId == preacherId) e];
  }

  @override
  Future<void> retryEmail(String emailId) async {
    _need(_admin);
    final i = outbox.indexWhere((e) => e.id == emailId && (e.status == 'failed' || e.status == 'skipped'));
    if (i < 0) throw const LessonsException(LessonsFailure.invalid);
    final e = outbox[i];
    outbox[i] = PreacherEmailEntry(
        id: e.id, kind: e.kind, status: 'sent', preacherId: e.preacherId, applicationId: e.applicationId, to: e.to,
        attempts: 1, createdAt: e.createdAt, sentAt: DateTime.now(), nameAr: e.nameAr, nameEn: e.nameEn);
    _log('emailRetry', e.nameAr, e.nameEn, preacherId: e.preacherId, note: e.kind);
  }

  @override
  Future<List<LessonsAccount>> searchAccounts(String query) async {
    _need(_admin);
    final q = query.trim().toLowerCase();
    return [
      for (final a in accounts)
        if (q.isEmpty || a.nameAr.contains(q) || a.nameEn.toLowerCase().contains(q) || a.email.contains(q)) a
    ];
  }

  // ---------------------------------------------------------------- links
  @override
  Future<NewPreacherKey> createKey(String preacherId, String kind,
      {DateTime? validFrom, DateTime? validUntil, String note = '', bool email = false}) async {
    _need(_admin);
    final p = preachers[preacherId];
    if (p == null || (kind != 'once' && kind != 'window')) throw const LessonsException(LessonsFailure.invalid);
    if (email && emails[preacherId] == null) throw const LessonsException(LessonsFailure.invalid, 'no_email');
    if (kind == 'window' && (validFrom == null || validUntil == null)) throw const LessonsException(LessonsFailure.invalid);
    if (validUntil != null && !validUntil.isAfter(DateTime.now())) throw const LessonsException(LessonsFailure.invalid);
    if (validFrom != null && validUntil != null && !validUntil.isAfter(validFrom)) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    final token = List.generate(32, (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[math.Random().nextInt(32)]).join();
    final k = links[token] = DemoPreacherLink(
        id: _id('k'), preacherId: preacherId, kind: kind, validFrom: kind == 'window' ? validFrom : null,
        validUntil: validUntil, note: note.trim(), createdAt: DateTime.now());
    _log(kind == 'once' ? 'keyOnce' : 'keyWindow', p.nameAr, p.name('en'), preacherId: preacherId);
    if (email) {
      _email('invite', preacherId: preacherId);
      _log('invite', p.nameAr, p.name('en'), preacherId: preacherId);
    }
    return NewPreacherKey(
        id: k.id, token: token, kind: kind, validFrom: k.validFrom, validUntil: k.validUntil, emailed: email);
  }

  @override
  Future<List<PreacherKey>> loadKeys(String preacherId) async {
    _need(_admin);
    return [
      for (final k in links.values.where((k) => k.preacherId == preacherId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        k.view
    ];
  }

  @override
  Future<void> revokeKey(String keyId) async {
    _need(_admin);
    final k = links.values.where((k) => k.id == keyId).firstOrNull;
    if (k == null) throw const LessonsException(LessonsFailure.invalid);
    k.revokedAt ??= DateTime.now();
    final p = preachers[k.preacherId]!;
    _log('keyRevoke', p.nameAr, p.name('en'), preacherId: p.id);
  }

  /// The checks of the server's private.preacher_key().
  DemoPreacherLink _key(String token, String device) {
    final k = links[token];
    final now = DateTime.now();
    if (k == null || k.revokedAt != null || !preachers.containsKey(k.preacherId)) {
      throw const LessonsException(LessonsFailure.expired, 'revoked');
    }
    if (k.validFrom != null && now.isBefore(k.validFrom!)) throw const LessonsException(LessonsFailure.expired, 'not_yet');
    if (k.validUntil != null && now.isAfter(k.validUntil!)) throw const LessonsException(LessonsFailure.expired, 'expired');
    if (k.kind == 'once') {
      if (device.length < 16) throw const LessonsException(LessonsFailure.invalid);
      if (k.device == null) {
        k
          ..device = device
          ..openedAt = now;
      } else if (k.device != device) {
        throw const LessonsException(LessonsFailure.expired, 'used');
      }
    } else {
      k.openedAt ??= now;
    }
    k.lastUsedAt = now;
    return k;
  }

  @override
  Future<PreacherLinkView> openLink(String token, String device) async {
    final k = _key(token, device);
    return _page(k.preacherId, k.kind, k.validUntil);
  }

  PreacherLinkView _page(String preacherId, String kind, DateTime? validUntil) {
    final p = preachers[preacherId]!;
    final since = addDays(_today, -60);
    final mine = lessons.values.where((l) => l.preacherId == p.id && l.status != 'withdrawn' && !l.date.isBefore(since)).toList()
      ..sort(compareLessons);
    return PreacherLinkView(
      preacher: p,
      kind: kind,
      validUntil: validUntil,
      emailSet: emails.containsKey(p.id),
      pendingEdit: edits.where((e) => e.preacherId == p.id && e.pending).lastOrNull?.changes,
      lessons: [
        for (final l in mine)
          PreacherLinkLesson(
              id: l.id, requestId: l.requestId, seriesId: l.seriesId, seq: l.seq, titleAr: l.titleAr,
              titleEn: l.titleEn, type: l.type, topic: l.topic, date: l.date, slot: l.slot, exactTime: l.exactTime,
              status: l.status, source: l.source, preacherNote: l.preacherNote, rejectionReason: l.rejectionReason,
              cancelReason: l.cancelReason, mosqueAr: mosques[l.mosqueId]?.nameAr ?? '',
              mosqueEn: mosques[l.mosqueId]?.nameEn ?? '', mosqueId: l.hasMosque ? l.mosqueId : null),
      ],
    );
  }

  @override
  Future<void> proposeCardEdit(String token, String device, Map<String, dynamic> changes) async =>
      _propose(_key(token, device).preacherId, changes, byLink: true);

  void _propose(String preacherId, Map<String, dynamic> changes, {required bool byLink}) {
    const fields = ['name_ar', 'name_en', 'title_ar', 'title_en', 'bio_ar', 'bio_en'];
    final email = (changes['email'] as String? ?? '').trim().toLowerCase();
    final x = <String, dynamic>{
      for (final f in fields)
        if (changes.containsKey(f)) f: (changes[f] as String? ?? '').trim(),
      if (changes['languages'] is List) 'languages': (changes['languages'] as List).cast<String>(),
      if (email.isNotEmpty) 'email': email,
    };
    final langs = x['languages'] as List<String>?;
    if (x.isEmpty ||
        (x.containsKey('name_ar') && ((x['name_ar'] as String).length < 3 || (x['name_ar'] as String).length > 120)) ||
        ['bio_ar', 'bio_en'].any((f) => ((x[f] as String?) ?? '').length > 1500) ||
        ['name_en', 'title_ar', 'title_en'].any((f) => ((x[f] as String?) ?? '').length > 120) ||
        (email.isNotEmpty && !_emailShape.hasMatch(email)) ||
        (langs != null && (langs.isEmpty || langs.length > 7))) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    final i = edits.indexWhere((e) => e.preacherId == preacherId && e.pending);
    final edit = PreacherEdit(id: i < 0 ? _id('e') : edits[i].id, preacherId: preacherId, changes: x, createdAt: DateTime.now());
    i < 0 ? edits.add(edit) : edits[i] = edit;
    final p = preachers[preacherId]!;
    _log('preacherEdit', p.nameAr, p.name('en'), preacherId: p.id, byLink: byLink);
    _notifyAdmins('user', 'داعية اقترح تعديلًا على بطاقته', 'A preacher proposed a card change', p.nameAr, p.name('en'),
        '/admin/lessons/approvals');
  }

  @override
  Future<String> requestLesson(String token, String device, LessonRequestDraft d) async =>
      _request(_key(token, device).preacherId, d, byLink: true);

  String _request(String preacherId, LessonRequestDraft d, {required bool byLink}) {
    final waiting = lessons.values.where((l) => l.preacherId == preacherId && l.status == 'pending').map((l) => l.requestId).toSet();
    if (waiting.length >= 20) throw const LessonsException(LessonsFailure.busy);
    final dates = {...d.dates}.toList()..sort();
    if (dates.isEmpty || dates.length > 12 || dates.first.isBefore(_today) || dates.last.isAfter(addDays(_today, 180)) ||
        d.titleAr.trim().length < 3 || (d.mosqueId != null && mosques[d.mosqueId]?.verified != true)) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    final req = _id('rq');
    String? seriesId;
    if (dates.length > 1) {
      seriesId = _id('s');
      series[seriesId] = LessonSeries(
          id: seriesId, requestId: req, preacherId: preacherId, mosqueId: d.mosqueId ?? '', titleAr: d.titleAr.trim(),
          type: d.type, topic: d.topic, language: d.language, audience: d.audience, slot: d.slot, total: dates.length,
          status: 'pending');
    }
    for (var i = 0; i < dates.length; i++) {
      final id = _id('l');
      lessons[id] = Lesson(
          id: id, requestId: req, seriesId: seriesId, seq: seriesId == null ? null : i + 1, type: d.type,
          topic: d.topic, titleAr: d.titleAr.trim(), preacherId: preacherId, mosqueId: d.mosqueId ?? '',
          date: dates[i], slot: d.slot, language: d.language, audience: d.audience, status: 'pending',
          source: 'preacher', preacherNote: d.note.trim(), submittedAt: DateTime.now());
    }
    final p = preachers[preacherId]!;
    _log('request', '${d.titleAr} — ${p.nameAr}', '${d.titleAr}, ${p.name('en')}', preacherId: p.id, byLink: byLink);
    _notifyAdmins('inbox', 'طلب درس جديد من داعية', 'A preacher requested a lesson', '${d.titleAr} — ${p.nameAr}',
        '${d.titleAr}, ${p.name('en')}', '/admin/lessons/approvals');
    return req;
  }

  @override
  Future<void> withdrawRequest(String token, String device, String requestId) async =>
      _withdrawOwn(_key(token, device).preacherId, requestId, byLink: true);

  void _withdrawOwn(String preacherId, String requestId, {required bool byLink}) {
    if (!lessons.values.any((l) => l.requestId == requestId && l.preacherId == preacherId && l.status == 'pending')) {
      throw const LessonsException(LessonsFailure.invalid);
    }
    _withdraw(requestId, byLink: byLink);
  }

  // ------------------------------------------------- preacher by account
  String _myCard() {
    _signedIn();
    final p = preachers.values.where((p) => p.linkedProfileId == currentUserId).firstOrNull;
    if (p == null) throw const LessonsException(LessonsFailure.forbidden, 'not_preacher');
    return p.id;
  }

  @override
  Future<PreacherLinkView> openMyPage() async => _page(_myCard(), 'account', null);

  @override
  Future<void> proposeMyCardEdit(Map<String, dynamic> changes) async => _propose(_myCard(), changes, byLink: false);

  @override
  Future<String> requestMyLesson(LessonRequestDraft draft) async => _request(_myCard(), draft, byLink: false);

  @override
  Future<void> withdrawMyRequest(String requestId) async => _withdrawOwn(_myCard(), requestId, byLink: false);

  // -------------------------------------------------------------- mosques
  @override
  Future<String> upsertMosque(Map<String, dynamic> m) async {
    _need(_admin);
    final id = m['id'] as String? ?? _id('m');
    final old = mosques[id];
    final name = (m['name_ar'] as String? ?? old?.nameAr ?? '').trim();
    final district = m['district_id'] as String? ?? old?.districtId;
    if (name.length < 2 || !districts.containsKey(district)) throw const LessonsException(LessonsFailure.invalid);
    mosques[id] = Mosque(
        id: id,
        nameAr: name,
        nameEn: m['name_en'] as String? ?? old?.nameEn ?? '',
        districtId: district!,
        latitude: m.containsKey('latitude') ? (m['latitude'] as num?)?.toDouble() : old?.latitude,
        longitude: m.containsKey('longitude') ? (m['longitude'] as num?)?.toDouble() : old?.longitude,
        facilities: (m['facilities'] as List?)?.cast<String>() ?? old?.facilities ?? const [],
        verified: m['verified'] as bool? ?? old?.verified ?? true);
    _log(old == null ? 'addMosque' : 'editMosque', mosques[id]!.nameAr, mosques[id]!.name('en'));
    return id;
  }

  @override
  Future<void> removeMosque(String mosqueId, {String? mergeInto}) async {
    _need(_admin);
    final m = mosques[mosqueId];
    if (m == null) throw const LessonsException(LessonsFailure.invalid);
    if (mergeInto != null) {
      if (mergeInto == mosqueId || !mosques.containsKey(mergeInto)) throw const LessonsException(LessonsFailure.invalid);
      for (final l in lessons.values.where((l) => l.mosqueId == mosqueId).toList()) {
        lessons[l.id] = l.copyWith(mosqueId: mergeInto);
      }
      for (final s in series.values.where((s) => s.mosqueId == mosqueId).toList()) {
        series[s.id] = s.copyWith(mosqueId: mergeInto);
      }
      for (final p in preachers.values.where((p) => p.homeMosqueId == mosqueId).toList()) {
        preachers[p.id] = p.copyWith(homeMosqueId: mergeInto);
      }
    } else if (lessons.values.any((l) => l.mosqueId == mosqueId)) {
      throw const LessonsException(LessonsFailure.conflict);
    }
    for (final e in _mine.entries.toList()) {
      final f = {...e.value.follows};
      if (f.remove('mosque:$mosqueId') && mergeInto != null) f.add('mosque:$mergeInto');
      _mine[e.key] = e.value.copyWith(follows: f);
    }
    mosques.remove(mosqueId);
    _log(mergeInto == null ? 'removeMosque' : 'mergeMosque', m.nameAr, m.name('en'));
  }
}
