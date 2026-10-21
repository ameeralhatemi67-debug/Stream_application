import 'dart:math' as math;

import '../domain/taysir_dates.dart';
import '../domain/taysir_models.dart';
import '../domain/taysir_rules.dart';
import 'taysir_repository.dart';

/// Who the sample data is being viewed as.
enum TaysirDemoPersona { guest, viewer, preacher, coordinator, owner, admin }

/// Sample data for builds without a backend and for widget tests. Names of
/// people are invented; neighbourhoods are real. The permission rules mirror
/// the server functions so the screens behave the same way.
class DemoTaysirRepository implements TaysirRepository {
  DemoTaysirRepository({this.persona = TaysirDemoPersona.guest, DateTime? today})
      : _today = today ?? taysirToday() {
    _seed();
  }

  TaysirDemoPersona persona;
  final DateTime _today;
  int _seq = 1000;
  String _id(String p) => '$p-${++_seq}';

  static const org = 'demo-org-hidayah';
  static const org2 = 'demo-org-dammam';
  static const ownPreacher = 'p1';

  @override
  bool get isDemo => true;

  @override
  String? get currentUserId =>
      persona == TaysirDemoPersona.guest ? null : 'demo-${persona.name}';

  bool get _coord => switch (persona) {
        TaysirDemoPersona.owner || TaysirDemoPersona.admin => true,
        TaysirDemoPersona.coordinator => (coordinatorGrants['demo-coordinator'] ?? const {}).isNotEmpty,
        _ => false,
      };
  bool get _leader => persona == TaysirDemoPersona.owner || persona == TaysirDemoPersona.admin;

  void _need(bool ok) {
    if (!ok) throw const TaysirException(TaysirFailure.forbidden);
  }

  void _signedIn() => _need(currentUserId != null);

  // ---------------------------------------------------------------- state
  final districts = <String, TaysirDistrict>{};
  final organizations = <String, TaysirOrganization>{};
  final mosques = <String, TaysirMosque>{};
  final preachers = <String, TaysirPreacher>{};
  final series = <String, TaysirSeries>{};
  final lessons = <String, TaysirLesson>{};
  final reports = <String, TaysirReport>{};
  final flags = <TaysirFlag>[];
  final audit = <TaysirAuditEntry>[];
  final phones = <String, String>{};
  final invites = <String, String>{}; // token -> preacher
  final submitPermission = <String>{}; // preacher ids whose linked account may submit
  /// activities.coordinate grants: who coordinates which organizations.
  final coordinatorGrants = <String, Set<String>>{
    'demo-coordinator': {org}
  };
  final team = <TaysirTeamMember>[];

  /// Accounts an admin can find (invented people, example.invalid emails).
  static const accounts = [
    TaysirAccount(id: 'demo-owner', nameAr: 'م. سعد القحطاني', nameEn: 'Eng. Saad Al-Qahtani', email: 'saad@example.invalid'),
    TaysirAccount(id: 'demo-coordinator', nameAr: 'خالد الدوسري', nameEn: 'Khalid Al-Dosari', email: 'khalid@example.invalid'),
    TaysirAccount(id: 'demo-member-u3', nameAr: 'بدر الشمري', nameEn: 'Badr Al-Shammari', email: 'badr@example.invalid'),
    TaysirAccount(id: 'demo-member-u4', nameAr: 'ماجد الغامدي', nameEn: 'Majed Al-Ghamdi', email: 'majed@example.invalid'),
    TaysirAccount(id: 'demo-viewer', nameAr: 'عبدالله السالم', nameEn: 'Abdullah Al-Salem', email: 'abdullah@example.invalid'),
    TaysirAccount(id: 'demo-account-reem', nameAr: 'ريم العنزي', nameEn: 'Reem Al-Anazi', email: 'reem@example.invalid'),
  ];
  final _mine = <String, TaysirMine>{};

  TaysirMine _me() => _mine[currentUserId] ?? const TaysirMine();
  void _setMe(TaysirMine m) => _mine[currentUserId!] = m;

  void _notify(String? profile, String icon, String titleAr, String titleEn, String bodyAr, String bodyEn, String route) {
    if (profile == null || profile == currentUserId) return;
    final m = _mine[profile] ?? const TaysirMine();
    _mine[profile] = m.copyWith(notifications: [
      TaysirNotification(
          id: _id('n'), icon: icon, titleAr: titleAr, titleEn: titleEn, bodyAr: bodyAr, bodyEn: bodyEn,
          route: route, createdAt: DateTime.now()),
      ...m.notifications
    ]);
  }

  void _notifyCoordinators(String icon, String titleAr, String titleEn, String bodyAr, String bodyEn, String route) {
    for (final c in {'demo-coordinator', 'demo-owner'}) {
      _notify(c, icon, titleAr, titleEn, bodyAr, bodyEn, route);
    }
  }

  void _log(String action, String ar, String en, {String? organizationId = org}) => audit.insert(
      0,
      TaysirAuditEntry(
          id: _id('a'), organizationId: organizationId, actorId: currentUserId,
          actorName: _personaName(persona), action: action, targetAr: ar, targetEn: en, createdAt: DateTime.now()));

  static String _personaName(TaysirDemoPersona p) => switch (p) {
        TaysirDemoPersona.coordinator => 'Khalid Al-Dosari',
        TaysirDemoPersona.owner => 'Eng. Saad Al-Qahtani',
        TaysirDemoPersona.admin => 'Master admin',
        TaysirDemoPersona.preacher => 'Sheikh Fahd Al-Otaibi',
        TaysirDemoPersona.viewer => 'Abdullah Al-Salem',
        TaysirDemoPersona.guest => '',
      };

  // ----------------------------------------------------------------- seed
  void _seed() {
    void district(String id, String city, String ar, String en, int sort) =>
        districts[id] = TaysirDistrict(id: id, city: city, nameAr: ar, nameEn: en, sort: sort);
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

    organizations[org] = const TaysirOrganization(
        id: org, nameAr: 'جمعية هداية للدعوة والإرشاد وتوعية الجاليات', nameEn: 'Hidayah Society', verified: true);
    organizations[org2] = const TaysirOrganization(
        id: org2, nameAr: 'مركز الدعوة بالدمام (مثال)', nameEn: 'Dammam Dawah Centre (sample)', enabled: false);

    void mosque(String id, String ar, String en, String d, double lat, double lng, List<String> fac, {bool verified = true}) =>
        mosques[id] = TaysirMosque(
            id: id, nameAr: ar, nameEn: en, districtId: d, latitude: lat, longitude: lng, facilities: fac, verified: verified,
            suggestedBy: verified ? null : 'demo-preacher-p8');
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
    mosque('m13', 'مسجد الإيمان', 'Al-Iman Mosque', 'golden_belt', 26.262, 50.172, ['parking'], verified: false);

    void preacher(String id, String ar, String en, String tAr, String tEn, String city, String aff, List<String> langs,
        {String account = 'linked', String bioAr = '', String bioEn = ''}) {
      preachers[id] = TaysirPreacher(
          id: id, organizationId: org, nameAr: ar, nameEn: en, titleAr: tAr, titleEn: tEn, city: city,
          affiliation: aff, languages: langs, bioAr: bioAr, bioEn: bioEn,
          linkedProfileId: account == 'linked' ? (id == ownPreacher ? 'demo-preacher' : 'demo-preacher-$id') : null);
      phones[id] = '05000001${id.substring(1).padLeft(2, '0')}';
      if (account == 'linked') submitPermission.add(id);
      if (account == 'invited') invites['invite-$id'] = id;
    }

    preacher('p1', 'الشيخ فهد بن سالم العتيبي', 'Sheikh Fahd Al-Otaibi', 'داعية ومدرّس شرعي', 'Preacher and Sharia teacher', 'khobar', 'coop', ['ar'],
        bioAr: 'يدرّس العقيدة والفقه في مساجد الخبر منذ خمس عشرة سنة، ويبث دروسه الأسبوعية على منصة هداية.',
        bioEn: 'Has taught Aqeedah and Fiqh in Al Khobar mosques for fifteen years and streams his weekly lessons on Hadayah Live.');
    preacher('p2', 'د. عبدالله بن محمد الشهري', 'Dr. Abdullah Al-Shehri', 'أستاذ الفقه المشارك', 'Associate professor of Fiqh', 'dammam', 'ministry', ['ar']);
    preacher('p3', 'الشيخ ياسر بن علي القرني', 'Sheikh Yasser Al-Qarni', 'مدرّس القرآن وعلومه', 'Teacher of the Quran and its sciences', 'dhahran', 'coop', ['ar', 'en']);
    preacher('p4', 'الشيخ محمد إقبال الندوي', 'Sheikh Muhammad Iqbal Nadwi', 'داعية الجالية الناطقة بالأردية', 'Preacher to the Urdu-speaking community', 'khobar', 'coop', ['ur', 'en', 'ar']);
    preacher('p5', 'الشيخ عمر بن خالد الحربي', 'Sheikh Omar Al-Harbi', 'إمام وخطيب', 'Imam and khateeb', 'dammam', 'coop', ['ar'], account: 'invited');
    preacher('p6', 'الشيخ عبدالكريم سانتوس', 'Sheikh Abdulkareem Santos', 'داعية الجالية الفلبينية', 'Preacher to the Filipino community', 'khobar', 'coop', ['tl', 'en']);
    preacher('p7', 'د. سلمان بن إبراهيم الزهراني', 'Dr. Salman Al-Zahrani', 'داعية في فرع الوزارة', 'Ministry branch preacher', 'khobar', 'ministry', ['ar'], account: 'none');
    preacher('p8', 'الشيخ نايف بن سعد الدوسري', 'Sheikh Naif Al-Dosari', 'إمام جامع', 'Mosque imam', 'khobar', 'coop', ['ar'], account: 'invited');
    preacher('p9', 'أ. نورة بنت عبدالله السبيعي', 'Ustadha Noura Al-Subaie', 'داعية ومدرّسة (دروس النساء)', "Preacher and teacher (women's lessons)", 'khobar', 'coop', ['ar']);
    preacher('p10', 'الشيخ حسن الرحمن', 'Sheikh Hasan Rahman', 'داعية الجالية البنغالية', 'Preacher to the Bengali community', 'dammam', 'coop', ['bn', 'ar'], account: 'none');
    preacher('p11', 'الشيخ منصور بن علي الخالدي', 'Sheikh Mansour Al-Khalidi', 'داعية في فرع الوزارة', 'Ministry branch preacher', 'qatif', 'ministry', ['ar']);

    const desc = {
      'lesson': ('درس أسبوعي منتظم يُشرح فيه الكتاب مقطعًا مقطعًا، مع وقت للأسئلة في آخره.',
          'A regular weekly lesson that works through the book passage by passage, with time for questions at the end.'),
      'lecture': ('محاضرة عامة في موضوع واحد، مدتها نحو ساعة، تليها أسئلة الحضور.',
          'A public lecture on one subject, about an hour long, followed by questions from the audience.'),
      'talk': ('كلمة قصيرة بعد الصلاة لا تتجاوز خمس عشرة دقيقة.', 'A short talk after the prayer, no longer than fifteen minutes.'),
    };

    TaysirLesson lesson({
      required String type,
      required String topic,
      required String ar,
      required String en,
      required String preacher,
      required String mosque,
      required DateTime date,
      required String slot,
      String? seriesId,
      int? seq,
      String? requestId,
      String status = 'approved',
      String language = 'ar',
      String audience = 'all',
      String? interp,
      bool streamed = false,
      String? reason,
      Duration submittedAgo = const Duration(days: 7),
    }) {
      final id = _id('l');
      final l = TaysirLesson(
          id: id, organizationId: org, requestId: requestId ?? 'r-$id', seriesId: seriesId, seq: seq,
          type: type, topic: topic, titleAr: ar, titleEn: en,
          descriptionAr: desc[type]!.$1, descriptionEn: desc[type]!.$2, preacherId: preacher, mosqueId: mosque,
          date: date, slot: slot, language: language, interpretation: interp, audience: audience,
          womenSection: audience == 'women' || mosques[mosque]!.facilities.contains('women'), streamed: streamed,
          status: status, rejectionReason: reason, submittedBy: 'demo-preacher',
          submittedAt: DateTime.now().subtract(submittedAgo),
          reviewedBy: status == 'approved' ? 'demo-coordinator' : null);
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
      series[s.$1] = TaysirSeries(
          id: s.$1, organizationId: org, requestId: reqId, preacherId: s.$4, mosqueId: s.$5, titleAr: s.$2, titleEn: s.$3,
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
          reports[l.id] = TaysirReport(lessonId: l.id, attendance: 40 + (seq * 37 + s.$8) % 90, women: (seq * 7) % 25);
        }
      }
    }

    // One-off lectures and talks around today.
    void one(int off, String slot, String type, String topic, String ar, String en, String p, String m,
            {String language = 'ar', String audience = 'all', bool streamed = false, bool report = false}) {
      final l = lesson(type: type, topic: topic, ar: ar, en: en, preacher: p, mosque: m, date: addDays(_today, off),
          slot: slot, language: language, audience: audience, streamed: streamed);
      if (report) reports[l.id] = TaysirReport(lessonId: l.id, attendance: 72, women: 20);
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

    // Pending requests for the coordinator queue.
    lesson(type: 'lecture', topic: 'raqaiq', ar: 'الأمانة في العمل', en: 'Integrity at work', preacher: 'p1', mosque: 'm3',
        date: addDays(_today, 3), slot: 'isha', status: 'pending', submittedAgo: const Duration(hours: 5));
    final clashDate = lessons.values
        .firstWhere((l) => l.seriesId == 's1' && !l.date.isBefore(_today), orElse: () => lessons.values.first)
        .date;
    lesson(type: 'talk', topic: 'raqaiq', ar: 'فضل الذكر', en: 'The virtue of remembrance', preacher: 'p5', mosque: 'm1',
        date: clashDate, slot: 'isha', status: 'pending', submittedAgo: const Duration(hours: 9));
    lesson(type: 'lecture', topic: 'intro', ar: 'مدخل إلى الإسلام (بالإنجليزية والتغالوغ)', en: 'Introduction to Islam (English and Tagalog)',
        preacher: 'p6', mosque: 'm3', date: addDays(_today, 2), slot: 'asr', status: 'pending', language: 'tl', interp: 'en',
        submittedAgo: const Duration(hours: 20));
    lesson(type: 'talk', topic: 'fiqh', ar: 'أحكام الوضوء', en: 'The rulings of wudu', preacher: 'p8', mosque: 'm13',
        date: addDays(_today, 5), slot: 'maghrib', status: 'pending', submittedAgo: const Duration(hours: 26));
    // A pending weekly series of eight sessions, one request.
    series['s8'] = const TaysirSeries(
        id: 's8', organizationId: org, requestId: 'rq-s8', preacherId: 'p4', mosqueId: 'm2', titleAr: 'السيرة للمبتدئين (بالأردية)',
        titleEn: 'Seerah for beginners (in Urdu)', type: 'lesson', topic: 'seerah', language: 'ur', audience: 'all', slot: 'isha',
        total: 8, status: 'pending');
    var d8 = addDays(_today, 1);
    while (d8.weekday != DateTime.wednesday) {
      d8 = addDays(d8, 1);
    }
    for (var i = 0; i < 8; i++) {
      lesson(type: 'lesson', topic: 'seerah', ar: 'السيرة للمبتدئين (بالأردية)', en: 'Seerah for beginners (in Urdu)', preacher: 'p4',
          mosque: 'm2', date: addDays(d8, i * 7), slot: 'isha', seriesId: 's8', seq: i + 1, requestId: 'rq-s8', status: 'pending',
          language: 'ur', submittedAgo: const Duration(hours: 2));
    }
    // One rejection the preacher can see and fix.
    lesson(type: 'lecture', topic: 'family', ar: 'السعادة الزوجية', en: 'A happy marriage', preacher: 'p1', mosque: 'm1',
        date: addDays(_today, 2), slot: 'isha', status: 'rejected', submittedAgo: const Duration(days: 3),
        reason: 'تتعارض مع محاضرة الجمعية الكبرى في الليلة نفسها. نقترح الخميس بعد العشاء.');

    final s2next = lessons.values.firstWhere((l) => l.seriesId == 's2' && !l.date.isBefore(_today));
    flags.add(TaysirFlag(
        id: 'f1', lessonId: s2next.id, organizationId: org, kind: 'time',
        message: 'إمام المسجد أعلن أن الدرس صار بعد العصر بدل المغرب.', reporterId: 'demo-viewer',
        createdAt: DateTime.now().subtract(const Duration(hours: 7))));

    team.addAll(const [
      TaysirTeamMember(profileId: 'demo-owner', role: 'owner', nameAr: 'م. سعد القحطاني', nameEn: 'Eng. Saad Al-Qahtani'),
      TaysirTeamMember(profileId: 'demo-coordinator', role: 'manager', nameAr: 'خالد الدوسري', nameEn: 'Khalid Al-Dosari',
          coordinator: true, grantedByAr: 'م. سعد القحطاني', grantedByEn: 'Eng. Saad Al-Qahtani'),
      TaysirTeamMember(profileId: 'demo-member-u3', role: 'manager', nameAr: 'بدر الشمري', nameEn: 'Badr Al-Shammari'),
      TaysirTeamMember(profileId: 'demo-member-u4', role: 'moderator', nameAr: 'ماجد الغامدي', nameEn: 'Majed Al-Ghamdi'),
    ]);

    final s1next = lessons.values.firstWhere((l) => l.seriesId == 's1' && !l.date.isBefore(_today));
    _mine['demo-viewer'] = TaysirMine(
      reminders: {s1next.id: TaysirReminder(lessonId: s1next.id, lead: 'adhan', remindAt: DateTime.now().add(const Duration(days: 1)))},
      follows: const {'preacher:p1', 'preacher:p4', 'series:s1', 'mosque:m1'},
      attended: {for (final l in lessons.values.where((l) => l.seriesId == 's1' && l.date.isBefore(_today)).take(3)) l.id},
      notifications: [
        TaysirNotification(id: 'n1', icon: 'bell', titleAr: 'تذكير: دروس الليلة', titleEn: "Reminder: tonight's lessons",
            bodyAr: 'لديك تذكير بدرس بعد العشاء في جامع الهدى.', bodyEn: 'You have a reminder for a lesson after Isha at Al-Huda Grand Mosque.',
            route: '/taysir/lessons/${s1next.id}', createdAt: DateTime.now().subtract(const Duration(minutes: 40))),
        TaysirNotification(id: 'n2', icon: 'sparkle', titleAr: 'محاضرة جديدة من داعية تتابعه', titleEn: 'New lecture from a preacher you follow',
            bodyAr: 'الشيخ فهد العتيبي: الشباب والهوية.', bodyEn: 'Sheikh Fahd Al-Otaibi: Youth and identity.',
            route: '/taysir/preachers/p1', createdAt: DateTime.now().subtract(const Duration(hours: 5))),
      ],
    );
    _mine['demo-preacher'] = TaysirMine(notifications: [
      TaysirNotification(id: 'n4', icon: 'x', titleAr: 'لم يُعتمد طلبك: السعادة الزوجية', titleEn: 'Not approved: A happy marriage',
          bodyAr: 'السبب: تتعارض مع محاضرة الجمعية الكبرى.', bodyEn: "Reason: it clashes with the Society's main lecture.",
          route: '/taysir/me/lessons?tab=rejected', createdAt: DateTime.now().subtract(const Duration(days: 2))),
    ]);
    _mine['demo-coordinator'] = TaysirMine(notifications: [
      TaysirNotification(id: 'n7', icon: 'inbox', titleAr: 'طلبات جديدة بانتظار المراجعة', titleEn: 'New requests to review',
          bodyAr: 'منها سلسلة أسبوعية من ثماني جلسات بالأردية.', bodyEn: 'Including an eight-session weekly series in Urdu.',
          route: '/taysir/console/review', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    ]);
    audit.addAll([
      TaysirAuditEntry(id: 'a1', organizationId: org, actorId: 'demo-coordinator', actorName: 'Khalid Al-Dosari', action: 'reject',
          targetAr: 'السعادة الزوجية — الشيخ فهد العتيبي', targetEn: 'A happy marriage, Sheikh Fahd Al-Otaibi',
          createdAt: DateTime.now().subtract(const Duration(days: 2))),
      TaysirAuditEntry(id: 'a2', organizationId: org, actorId: 'demo-coordinator', actorName: 'Khalid Al-Dosari', action: 'approve',
          targetAr: 'الشباب والهوية — الشيخ فهد العتيبي', targetEn: 'Youth and identity, Sheikh Fahd Al-Otaibi',
          createdAt: DateTime.now().subtract(const Duration(days: 4))),
    ]);
  }

  // ---------------------------------------------------------------- reads
  bool _visible(TaysirLesson l) =>
      (organizations[l.organizationId]?.enabled ?? false) && (l.status == 'approved' || l.status == 'cancelled') ||
      _coord ||
      (persona == TaysirDemoPersona.preacher && l.preacherId == ownPreacher);

  @override
  Future<TaysirCatalog> loadCatalog() async => TaysirCatalog(
        districts: Map.of(districts),
        organizations: {for (final o in organizations.values.where((o) => o.enabled)) o.id: o},
        mosques: {
          for (final m in mosques.values.where((m) => m.verified || _coord || m.suggestedBy == currentUserId)) m.id: m
        },
        preachers: {
          for (final p in preachers.values.where((p) => p.listed || _coord || p.linkedProfileId == currentUserId)) p.id: p
        },
        series: {
          for (final s in series.values.where((s) =>
              s.status == 'approved' || _coord || (persona == TaysirDemoPersona.preacher && s.preacherId == ownPreacher)))
            s.id: s
        },
        lessons: {for (final l in lessons.values.where(_visible)) l.id: l},
      );

  @override
  Future<TaysirRoles> loadRoles() async => switch (persona) {
        TaysirDemoPersona.guest => TaysirRoles.guest,
        TaysirDemoPersona.viewer => const TaysirRoles(signedIn: true),
        TaysirDemoPersona.preacher => TaysirRoles(signedIn: true, preacherCards: [
            (preacherId: ownPreacher, organizationId: org, canSubmit: submitPermission.contains(ownPreacher))
          ]),
        TaysirDemoPersona.coordinator => TaysirRoles(signedIn: true, coordinate: {
            for (final o in coordinatorGrants['demo-coordinator'] ?? const <String>{})
              if (organizations[o]?.enabled ?? false) o
          }),
        TaysirDemoPersona.owner => const TaysirRoles(signedIn: true, coordinate: {org}, lead: {org}),
        TaysirDemoPersona.admin => const TaysirRoles(signedIn: true, admin: true, master: true, coordinate: {org}),
      };

  @override
  Future<TaysirMine> loadMine() async => currentUserId == null ? const TaysirMine() : _me();

  @override
  Future<TaysirStaffData> loadStaff(String organizationId) async {
    _need(_coord);
    return TaysirStaffData(
      roster: [
        for (final p in preachers.values.where((p) => p.organizationId == organizationId))
          TaysirRosterEntry(
              preacher: p,
              phoneMask: phones[p.id] == null ? null : maskPhone(phones[p.id]),
              account: p.linkedProfileId != null ? 'linked' : invites.containsValue(p.id) ? 'invited' : 'none',
              canSubmit: p.linkedProfileId != null && submitPermission.contains(p.id),
              lessons30d: lessons.values
                  .where((l) =>
                      l.preacherId == p.id &&
                      l.status == 'approved' &&
                      !l.date.isAfter(_today) &&
                      !l.date.isBefore(addDays(_today, -30)))
                  .length)
      ],
      team: [for (final t in team) t],
      flags: [for (final f in flags.where((f) => f.organizationId == organizationId)) f],
      audit: [for (final a in audit.where((a) => a.organizationId == organizationId || a.organizationId == null)) a],
      reports: Map.of(reports),
    );
  }

  @override
  Future<List<TaysirOrganization>> loadAdminOrganizations() async {
    _need(persona == TaysirDemoPersona.admin);
    return organizations.values.toList();
  }

  // --------------------------------------------------------------- viewer
  @override
  Future<void> setReminder(String lessonId, String lead, DateTime remindAt) async {
    _signedIn();
    if (lessons[lessonId]?.status != 'approved') throw const TaysirException(TaysirFailure.forbidden);
    _setMe(_me().copyWith(
        reminders: {..._me().reminders, lessonId: TaysirReminder(lessonId: lessonId, lead: lead, remindAt: remindAt)}));
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
  Future<void> savePreferences(TaysirPreferences preferences) async {
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
    flags.insert(0, TaysirFlag(
        id: _id('f'), lessonId: lessonId, organizationId: l.organizationId, kind: kind, message: message,
        reporterId: currentUserId, createdAt: DateTime.now()));
    _notifyCoordinators('flag', 'بلاغ جديد من مستخدم', 'New report from a user', l.titleAr, l.title('en'),
        '/taysir/console/review?filter=reports');
  }

  // ----------------------------------------------------- preacher / coord
  bool _ownCard(String preacherId) =>
      persona == TaysirDemoPersona.preacher && preacherId == ownPreacher && submitPermission.contains(ownPreacher);

  @override
  Future<String> submit(TaysirDraft d) async {
    _need(_coord || _ownCard(d.preacherId));
    if (d.direct) _need(_coord);
    if (d.dates.isEmpty || d.dates.length > 40 || d.dates.any((x) => x.isBefore(_today))) {
      throw const TaysirException(TaysirFailure.invalid);
    }
    var mosqueId = d.mosqueId;
    if (d.newMosque != null) {
      mosqueId = _id('m');
      mosques[mosqueId] = TaysirMosque(
          id: mosqueId, nameAr: d.newMosque!.nameAr, nameEn: d.newMosque!.nameEn, districtId: d.newMosque!.districtId,
          latitude: d.newMosque!.latitude, longitude: d.newMosque!.longitude, facilities: d.newMosque!.facilities,
          verified: _coord, suggestedBy: currentUserId);
    }
    if (mosqueId == null || !mosques.containsKey(mosqueId)) throw const TaysirException(TaysirFailure.invalid);
    if (d.replaces != null) {
      for (final l in lessons.values.where((l) => l.requestId == d.replaces && (l.status == 'pending' || l.status == 'rejected')).toList()) {
        lessons[l.id] = l.copyWith(status: 'withdrawn');
      }
    }
    final req = _id('rq');
    final status = d.direct ? 'approved' : 'pending';
    String? seriesId;
    final dates = [...d.dates]..sort();
    if (dates.length > 1) {
      seriesId = _id('s');
      series[seriesId] = TaysirSeries(
          id: seriesId, organizationId: preachers[d.preacherId]!.organizationId, requestId: req, preacherId: d.preacherId,
          mosqueId: mosqueId, titleAr: d.titleAr, titleEn: d.titleEn, type: d.type, topic: d.topic, language: d.language,
          audience: d.audience, slot: d.slot, total: dates.length, status: status);
    }
    for (var i = 0; i < dates.length; i++) {
      final id = _id('l');
      lessons[id] = TaysirLesson(
          id: id, organizationId: preachers[d.preacherId]!.organizationId, requestId: req, seriesId: seriesId,
          seq: seriesId == null ? null : i + 1, type: d.type, topic: d.topic, titleAr: d.titleAr, titleEn: d.titleEn,
          descriptionAr: d.descriptionAr, preacherId: d.preacherId, mosqueId: mosqueId, date: dates[i], slot: d.slot,
          exactTime: d.exactTime, language: d.language, interpretation: d.interpretation, audience: d.audience,
          womenSection: d.womenSection, streamed: d.streamed, notifyFollowers: d.notifyFollowers, status: status,
          submittedBy: currentUserId, submittedAt: DateTime.now(), reviewedBy: d.direct ? currentUserId : null,
          reviewedAt: d.direct ? DateTime.now() : null);
    }
    final p = preachers[d.preacherId]!;
    if (d.direct) {
      _log('approve', '${d.titleAr} — ${p.nameAr} (اعتماد مباشر)', '${d.titleEn.isEmpty ? d.titleAr : d.titleEn}, ${p.name('en')} (approved on entry)');
    } else {
      _log('submit', d.titleAr, d.titleEn.isEmpty ? d.titleAr : d.titleEn);
      _notifyCoordinators('inbox', 'طلب جديد بانتظار المراجعة', 'New request to review', '${d.titleAr} — ${p.nameAr}',
          '${d.titleEn.isEmpty ? d.titleAr : d.titleEn}, ${p.name('en')}', '/taysir/console/review');
    }
    return req;
  }

  @override
  Future<int> review(List<String> requestIds, String decision, {String? reason}) async {
    _need(_coord);
    if (decision == 'reject' && (reason == null || reason.trim().length < 3)) {
      throw const TaysirException(TaysirFailure.invalid);
    }
    final status = decision == 'approve' ? 'approved' : 'rejected';
    var n = 0;
    for (final rid in requestIds) {
      final items = lessons.values.where((l) => l.requestId == rid && l.status == 'pending').toList();
      if (items.isEmpty) continue;
      n++;
      for (final l in items) {
        lessons[l.id] = l.copyWith(status: status, reviewedBy: currentUserId, reviewedAt: DateTime.now(),
            rejectionReason: status == 'rejected' ? reason : null);
      }
      for (final s in series.values.where((s) => s.requestId == rid).toList()) {
        series[s.id] = s.copyWith(status: status);
      }
      final l = items.first, p = preachers[l.preacherId]!;
      _log(decision, '${l.titleAr} — ${p.nameAr}', '${l.title('en')}, ${p.name('en')}');
      if (status == 'approved') {
        _notify(p.linkedProfileId, 'check', 'اعتُمد: ${l.titleAr}', 'Approved: ${l.title('en')}',
            'ظهر الدرس للجميع وعلى الخريطة، وأُشعر متابعوك.', 'The lesson is public and on the map, and your followers were notified.',
            '/taysir/me/lessons?tab=approved');
        for (final e in _mine.entries.toList()) {
          if (e.value.isFollowing('preacher', l.preacherId)) {
            _notify(e.key, 'sparkle', 'درس جديد من داعية تتابعه', 'New lesson from a preacher you follow',
                '${p.nameAr}: ${l.titleAr}', '${p.name('en')}: ${l.title('en')}', '/taysir/lessons/${l.id}');
          }
        }
      } else {
        _notify(p.linkedProfileId, 'x', 'لم يُعتمد: ${l.titleAr}', 'Not approved: ${l.title('en')}', 'السبب: $reason',
            'Reason: $reason', '/taysir/me/lessons?tab=rejected');
      }
    }
    return n;
  }

  @override
  Future<int> undoReview(List<String> requestIds) async {
    _need(_coord);
    var n = 0;
    for (final l in lessons.values.toList()) {
      if (requestIds.contains(l.requestId) && (l.status == 'approved' || l.status == 'rejected') && l.reviewedBy == currentUserId) {
        lessons[l.id] = l.copyWith(status: 'pending', clearReview: true, clearRejection: true);
        n++;
      }
    }
    for (final s in series.values.where((s) => requestIds.contains(s.requestId)).toList()) {
      series[s.id] = s.copyWith(status: 'pending');
    }
    if (n > 0) _log('undo', 'تراجع عن قرار', 'Undid a decision');
    return n;
  }

  @override
  Future<void> withdraw(String requestId) async {
    final items = lessons.values.where((l) => l.requestId == requestId && l.status == 'pending').toList();
    if (items.isEmpty) throw const TaysirException(TaysirFailure.invalid);
    _need(_coord || _ownCard(items.first.preacherId));
    for (final l in items) {
      lessons[l.id] = l.copyWith(status: 'withdrawn');
    }
    _log('withdraw', items.first.titleAr, items.first.title('en'));
  }

  @override
  Future<int> cancelLesson(String lessonId, String reason) async {
    final l = lessons[lessonId];
    if (l == null || l.status != 'approved' || l.date.isBefore(_today)) throw const TaysirException(TaysirFailure.invalid);
    _need(_coord || _ownCard(l.preacherId));
    lessons[lessonId] = l.copyWith(status: 'cancelled', cancelReason: reason);
    var n = 0;
    for (final e in _mine.entries.toList()) {
      if (e.value.reminders.containsKey(lessonId)) {
        n++;
        _notify(e.key, 'alert', 'أُلغي موعد: ${l.titleAr}', 'Cancelled: ${l.title('en')}', '${isoDate(l.date)} — $reason',
            '${isoDate(l.date)}: $reason', '/taysir/lessons/$lessonId');
      }
    }
    if (!_coord) {
      _notifyCoordinators('alert', 'ألغى داعية موعدًا', 'A preacher cancelled a session', l.titleAr, l.title('en'),
          '/taysir/lessons/$lessonId');
    }
    _log('cancel', '${l.titleAr} — ${isoDate(l.date)}', '${l.title('en')}, ${isoDate(l.date)}');
    return n;
  }

  @override
  Future<void> editLesson(String lessonId, Map<String, dynamic> patch) async {
    _need(_coord);
    final l = lessons[lessonId]!;
    lessons[lessonId] = l.copyWith(
        titleAr: patch['title_ar'] as String?,
        titleEn: patch['title_en'] as String?,
        mosqueId: patch['mosque_id'] as String?,
        date: patch['lesson_date'] == null ? null : parseIsoDate(patch['lesson_date'] as String),
        slot: patch['slot'] as String?,
        exactTime: patch['exact_time'] as String?,
        clearExact: patch.containsKey('exact_time') && patch['exact_time'] == null);
    _log('edit', l.titleAr, l.title('en'));
  }

  @override
  Future<void> postReport(String lessonId, int attendance, int women, String issue, String notes) async {
    final l = lessons[lessonId]!;
    _need(_coord || _ownCard(l.preacherId));
    if (l.status != 'approved' || l.date.isAfter(_today)) throw const TaysirException(TaysirFailure.invalid);
    reports[lessonId] = TaysirReport(lessonId: lessonId, attendance: attendance, women: women, issue: issue, notes: notes);
    _log('report', l.titleAr, l.title('en'));
  }

  @override
  Future<void> resolveFlag(String flagId) async {
    _need(_coord);
    final i = flags.indexWhere((f) => f.id == flagId);
    final f = flags[i];
    flags[i] = TaysirFlag(
        id: f.id, lessonId: f.lessonId, organizationId: f.organizationId, kind: f.kind, message: f.message,
        reporterId: f.reporterId, status: 'resolved', createdAt: f.createdAt);
    _log('resolve', 'بلاغ على درس', 'Report on a lesson');
  }

  // --------------------------------------------------------------- roster
  @override
  Future<String> upsertPreacher(Map<String, dynamic> p) async {
    _need(_coord);
    final id = p['id'] as String? ?? _id('p');
    final old = preachers[id];
    preachers[id] = TaysirPreacher(
        id: id,
        organizationId: old?.organizationId ?? p['organization_id'] as String? ?? org,
        linkedProfileId: old?.linkedProfileId,
        nameAr: p['name_ar'] as String? ?? old!.nameAr,
        nameEn: p['name_en'] as String? ?? old?.nameEn ?? '',
        titleAr: p['title_ar'] as String? ?? old?.titleAr ?? '',
        titleEn: p['title_en'] as String? ?? old?.titleEn ?? '',
        city: p['city'] as String? ?? old?.city ?? 'khobar',
        affiliation: p['affiliation'] as String? ?? old?.affiliation ?? 'coop',
        languages: (p['languages'] as List?)?.cast<String>() ?? old?.languages ?? const ['ar'],
        listed: p['listed'] as bool? ?? old?.listed ?? true);
    if (p.containsKey('phone')) {
      final phone = (p['phone'] as String? ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
      phone.isEmpty ? phones.remove(id) : phones[id] = phone;
    }
    _log(old == null ? 'addPreacher' : 'editPreacher', preachers[id]!.nameAr, preachers[id]!.name('en'));
    return id;
  }

  @override
  Future<int> importPreachers(String organizationId, List<Map<String, dynamic>> rows) async {
    _need(_coord);
    for (final r in rows) {
      await upsertPreacher({'organization_id': organizationId, 'name_ar': r['name'], 'city': r['city'], 'affiliation': r['affiliation'], 'phone': r['phone']});
    }
    _log('import', 'استيراد ${rows.length} داعية', 'Imported ${rows.length} preachers');
    return rows.length;
  }

  @override
  Future<String?> revealPhone(String preacherId) async {
    _need(_coord);
    _log('phone', preachers[preacherId]!.nameAr, preachers[preacherId]!.name('en'));
    return phones[preacherId];
  }

  @override
  Future<void> setSubmit(String preacherId, bool enabled) async {
    _need(_coord);
    if (preachers[preacherId]?.linkedProfileId == null) throw const TaysirException(TaysirFailure.invalid);
    enabled ? submitPermission.add(preacherId) : submitPermission.remove(preacherId);
    _log(enabled ? 'grantSubmit' : 'revokeSubmit', preachers[preacherId]!.nameAr, preachers[preacherId]!.name('en'));
  }

  @override
  Future<void> unlinkPreacher(String preacherId) async {
    _need(_coord);
    preachers[preacherId] = preachers[preacherId]!.copyWith(clearLink: true);
    submitPermission.remove(preacherId);
    _log('unlink', preachers[preacherId]!.nameAr, preachers[preacherId]!.name('en'));
  }

  @override
  Future<String> createInvite(String preacherId) async {
    _need(_coord);
    if (preachers[preacherId]!.linkedProfileId != null) throw const TaysirException(TaysirFailure.invalid);
    invites.removeWhere((_, v) => v == preacherId);
    final token = List.generate(32, (_) => 'abcdefghijkmnpqrstuvwxyz23456789'[math.Random().nextInt(32)]).join();
    invites[token] = preacherId;
    _log('invite', preachers[preacherId]!.nameAr, preachers[preacherId]!.name('en'));
    return token;
  }

  @override
  Future<TaysirInviteInfo?> inviteInfo(String token) async {
    final pid = invites[token];
    final p = pid == null ? null : preachers[pid];
    if (p == null || p.linkedProfileId != null) return null;
    final o = organizations[p.organizationId]!;
    return TaysirInviteInfo(
        preacherId: p.id, nameAr: p.nameAr, nameEn: p.nameEn, city: p.city, affiliation: p.affiliation,
        languages: p.languages, organizationAr: o.nameAr, organizationEn: o.nameEn);
  }

  @override
  Future<String> claimInvite(String token, List<String> languages) async {
    _signedIn();
    final pid = invites.remove(token);
    if (pid == null || preachers[pid]!.linkedProfileId != null) throw const TaysirException(TaysirFailure.expired);
    preachers[pid] = preachers[pid]!.copyWith(linkedProfileId: currentUserId, languages: languages.isEmpty ? null : languages);
    submitPermission.add(pid);
    _log('claim', preachers[pid]!.nameAr, preachers[pid]!.name('en'));
    _notifyCoordinators('user', 'ربط داعية حسابه', 'A preacher linked their account', preachers[pid]!.nameAr,
        preachers[pid]!.name('en'), '/taysir/console/preachers');
    return pid;
  }

  @override
  Future<void> setCoordinator(String organizationId, String profileId, bool enabled) async {
    _need(_leader);
    _grant(organizationId, profileId, enabled);
  }

  /// One activities.coordinate grant or revocation, with the organization's
  /// team list kept in step (the sample team belongs to the main society).
  void _grant(String organizationId, String profileId, bool enabled) {
    final orgs = coordinatorGrants.putIfAbsent(profileId, () => <String>{});
    enabled ? orgs.add(organizationId) : orgs.remove(organizationId);
    if (orgs.isEmpty) coordinatorGrants.remove(profileId);
    final account = accounts.where((a) => a.id == profileId).firstOrNull;
    final i = team.indexWhere((t) => t.profileId == profileId);
    final ar = account?.nameAr ?? (i >= 0 ? team[i].nameAr : profileId);
    final en = account?.nameEn ?? (i >= 0 ? team[i].nameEn : profileId);
    if (organizationId == org) {
      final t = i >= 0
          ? team[i]
          : TaysirTeamMember(profileId: profileId, role: 'coordinator', nameAr: account?.nameAr ?? '', nameEn: account?.nameEn ?? '');
      final updated = TaysirTeamMember(
          profileId: t.profileId, role: t.role, nameAr: t.nameAr, nameEn: t.nameEn, coordinator: enabled,
          grantedAt: enabled ? DateTime.now() : null, grantedByAr: enabled ? _personaName(persona) : null,
          grantedByEn: enabled ? _personaName(persona) : null);
      if (i < 0) {
        if (enabled) team.add(updated);
      } else if (!enabled && t.role == 'coordinator') {
        team.removeAt(i);
      } else {
        team[i] = updated;
      }
    }
    _log(enabled ? 'grant' : 'revoke', '$ar ← منسق', '$en → coordinator', organizationId: organizationId);
  }

  @override
  Future<List<TaysirCoordinator>> loadCoordinators() async {
    _need(persona == TaysirDemoPersona.admin);
    return [
      for (final e in coordinatorGrants.entries)
        if (e.value.isNotEmpty)
          () {
            final a = accounts.where((a) => a.id == e.key).firstOrNull;
            return TaysirCoordinator(
                profileId: e.key, nameAr: a?.nameAr ?? '', nameEn: a?.nameEn ?? '', email: a?.email ?? '',
                organizationIds: e.value.toList());
          }()
    ];
  }

  @override
  Future<List<TaysirAccount>> searchAccounts(String query) async {
    _need(persona == TaysirDemoPersona.admin);
    final q = query.trim().toLowerCase();
    return [
      for (final a in accounts)
        if (q.isEmpty || a.nameAr.contains(q) || a.nameEn.toLowerCase().contains(q) || a.email.contains(q)) a
    ];
  }

  @override
  Future<int> setCoordinatorOrganizations(String profileId, List<String> organizationIds) async {
    _need(persona == TaysirDemoPersona.admin);
    if (organizationIds.any((o) => !organizations.containsKey(o))) throw const TaysirException(TaysirFailure.invalid);
    final want = organizationIds.toSet(), had = {...?coordinatorGrants[profileId]};
    for (final o in had.difference(want)) {
      _grant(o, profileId, false);
    }
    for (final o in want.difference(had)) {
      _grant(o, profileId, true);
    }
    return had.difference(want).length + want.difference(had).length;
  }

  @override
  Future<void> setOrganizationEnabled(String organizationId, bool enabled) async {
    _need(persona == TaysirDemoPersona.admin);
    organizations[organizationId] = organizations[organizationId]!.copyWith(enabled: enabled);
    final o = organizations[organizationId]!;
    _log(enabled ? 'enable' : 'disable', o.nameAr, o.nameEn, organizationId: organizationId);
  }

  // -------------------------------------------------------------- mosques
  @override
  Future<String> upsertMosque(Map<String, dynamic> m) async {
    _need(_coord);
    final id = m['id'] as String? ?? _id('m');
    final old = mosques[id];
    mosques[id] = TaysirMosque(
        id: id,
        nameAr: m['name_ar'] as String? ?? old!.nameAr,
        nameEn: m['name_en'] as String? ?? old?.nameEn ?? '',
        districtId: m['district_id'] as String? ?? old!.districtId,
        latitude: (m['latitude'] as num?)?.toDouble() ?? old?.latitude,
        longitude: (m['longitude'] as num?)?.toDouble() ?? old?.longitude,
        facilities: (m['facilities'] as List?)?.cast<String>() ?? old?.facilities ?? const [],
        verified: true);
    if (old == null) _log('addMosque', mosques[id]!.nameAr, mosques[id]!.name('en'), organizationId: null);
    return id;
  }

  @override
  Future<void> verifyMosque(String mosqueId) async {
    _need(_coord);
    mosques[mosqueId] = mosques[mosqueId]!.copyWith(verified: true);
    _log('verifyMosque', mosques[mosqueId]!.nameAr, mosques[mosqueId]!.name('en'), organizationId: null);
  }

  @override
  Future<void> rejectMosque(String mosqueId, {String? mergeInto}) async {
    _need(_coord);
    final m = mosques[mosqueId]!;
    if (mergeInto != null) {
      for (final l in lessons.values.where((l) => l.mosqueId == mosqueId).toList()) {
        lessons[l.id] = l.copyWith(mosqueId: mergeInto);
      }
      for (final s in series.values.where((s) => s.mosqueId == mosqueId).toList()) {
        series[s.id] = s.copyWith(mosqueId: mergeInto);
      }
    } else {
      if (lessons.values.any((l) => l.mosqueId == mosqueId && (l.status == 'approved' || l.status == 'cancelled'))) {
        throw const TaysirException(TaysirFailure.conflict);
      }
      lessons.removeWhere((_, l) => l.mosqueId == mosqueId);
    }
    mosques.remove(mosqueId);
    _log(mergeInto == null ? 'rejectMosque' : 'mergeMosque', m.nameAr, m.name('en'), organizationId: null);
  }
}
