import 'lessons_dates.dart';

/// Picks the Arabic or English text, falling back to whichever exists.
String pick(String lang, String ar, String en) =>
    lang == 'ar' ? (ar.isNotEmpty ? ar : en) : (en.isNotEmpty ? en : ar);

String _s(Object? v) => v?.toString() ?? '';
List<String> _list(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];
DateTime? _time(Object? v) => v == null ? null : DateTime.parse(v.toString()).toLocal();
double? _num(Object? v) => v == null ? null : (v as num).toDouble();
int _int(Object? v) => (v as num?)?.toInt() ?? 0;

class District {
  const District(
      {required this.id, required this.city, required this.nameAr, required this.nameEn, this.sort = 0});
  final String id, city, nameAr, nameEn;
  final int sort;
  String name(String lang) => pick(lang, nameAr, nameEn);

  factory District.fromJson(Map<String, dynamic> j) => District(
      id: _s(j['id']),
      city: _s(j['city']),
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      sort: _int(j['sort']));
}

class Mosque {
  const Mosque({
    required this.id,
    required this.nameAr,
    this.nameEn = '',
    required this.districtId,
    this.latitude,
    this.longitude,
    this.mapsUrl,
    this.facilities = const [],
    this.verified = true,
  });
  final String id, nameAr, nameEn, districtId;
  final double? latitude, longitude;
  final String? mapsUrl;
  final List<String> facilities;

  /// Public. Admins can hide a mosque without removing it.
  final bool verified;
  String name(String lang) => pick(lang, nameAr, nameEn);
  bool get hasPin => latitude != null && longitude != null;

  /// Directions: the stored Maps link, else the pin.
  Uri? get directions => mapsUrl != null
      ? Uri.parse(mapsUrl!)
      : hasPin
          ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude')
          : null;

  factory Mosque.fromJson(Map<String, dynamic> j) => Mosque(
      id: _s(j['id']),
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      districtId: _s(j['district_id']),
      latitude: _num(j['latitude']),
      longitude: _num(j['longitude']),
      mapsUrl: j['maps_url'] as String?,
      facilities: _list(j['facilities']),
      verified: j['verified'] as bool? ?? false);

  Mosque copyWith({bool? verified, String? nameAr, String? nameEn, String? districtId,
          double? latitude, double? longitude, List<String>? facilities}) =>
      Mosque(
          id: id,
          nameAr: nameAr ?? this.nameAr,
          nameEn: nameEn ?? this.nameEn,
          districtId: districtId ?? this.districtId,
          latitude: latitude ?? this.latitude,
          longitude: longitude ?? this.longitude,
          mapsUrl: mapsUrl,
          facilities: facilities ?? this.facilities,
          verified: verified ?? this.verified);
}

/// A preacher the admins manage: always a person, never an organization.
/// [linkedProfileId] is set when the preacher also has a Hadayah Live
/// account (one who streams); nobody needs an account to be a preacher.
class Preacher {
  const Preacher({
    required this.id,
    this.linkedProfileId,
    required this.nameAr,
    this.nameEn = '',
    this.titleAr = '',
    this.titleEn = '',
    this.bioAr = '',
    this.bioEn = '',
    this.photoUrl,
    this.city = 'khobar',
    this.affiliation = 'coop',
    this.languages = const ['ar'],
    this.listed = true,
  });
  final String id, nameAr, nameEn, titleAr, titleEn, bioAr, bioEn, city, affiliation;
  final String? linkedProfileId, photoUrl;
  final List<String> languages;
  final bool listed;
  String name(String lang) => pick(lang, nameAr, nameEn);
  String title(String lang) => pick(lang, titleAr, titleEn);
  String bio(String lang) => pick(lang, bioAr, bioEn);

  factory Preacher.fromJson(Map<String, dynamic> j) => Preacher(
      id: _s(j['id']),
      linkedProfileId: j['linked_profile_id'] as String?,
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      titleAr: _s(j['title_ar']),
      titleEn: _s(j['title_en']),
      bioAr: _s(j['bio_ar']),
      bioEn: _s(j['bio_en']),
      photoUrl: j['photo_url'] as String?,
      city: j['city'] as String? ?? 'khobar',
      affiliation: j['affiliation'] as String? ?? 'coop',
      languages: _list(j['languages']),
      listed: j['listed'] as bool? ?? true);

  Preacher copyWith({String? linkedProfileId, bool clearLink = false, List<String>? languages,
          String? nameAr, String? nameEn, String? titleAr, String? titleEn, String? bioAr, String? bioEn,
          String? photoUrl, bool clearPhoto = false, String? city, String? affiliation, bool? listed}) =>
      Preacher(
          id: id,
          linkedProfileId: clearLink ? null : (linkedProfileId ?? this.linkedProfileId),
          nameAr: nameAr ?? this.nameAr,
          nameEn: nameEn ?? this.nameEn,
          titleAr: titleAr ?? this.titleAr,
          titleEn: titleEn ?? this.titleEn,
          bioAr: bioAr ?? this.bioAr,
          bioEn: bioEn ?? this.bioEn,
          photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
          city: city ?? this.city,
          affiliation: affiliation ?? this.affiliation,
          languages: languages ?? this.languages,
          listed: listed ?? this.listed);
}

class LessonSeries {
  const LessonSeries({
    required this.id,
    required this.requestId,
    required this.preacherId,
    this.mosqueId = '',
    required this.titleAr,
    this.titleEn = '',
    required this.type,
    required this.topic,
    required this.language,
    required this.audience,
    required this.slot,
    required this.total,
    required this.status,
  });

  /// [mosqueId] is empty while a preacher's request waits for an admin to
  /// choose the mosque.
  final String id, requestId, preacherId, mosqueId, titleAr, titleEn, type, topic, language, audience, slot, status;
  final int total;
  String title(String lang) => pick(lang, titleAr, titleEn);

  factory LessonSeries.fromJson(Map<String, dynamic> j) => LessonSeries(
      id: _s(j['id']),
      requestId: _s(j['request_id']),
      preacherId: _s(j['preacher_id']),
      mosqueId: _s(j['mosque_id']),
      titleAr: _s(j['title_ar']),
      titleEn: _s(j['title_en']),
      type: _s(j['type']),
      topic: _s(j['topic']),
      language: _s(j['language']),
      audience: _s(j['audience']),
      slot: _s(j['slot']),
      total: _int(j['total']),
      status: _s(j['status']));

  LessonSeries copyWith({String? status, String? mosqueId}) => LessonSeries(
      id: id, requestId: requestId, preacherId: preacherId,
      mosqueId: mosqueId ?? this.mosqueId, titleAr: titleAr, titleEn: titleEn, type: type, topic: topic,
      language: language, audience: audience, slot: slot, total: total, status: status ?? this.status);
}

class Lesson {
  const Lesson({
    required this.id,
    required this.requestId,
    this.seriesId,
    this.seq,
    required this.type,
    required this.topic,
    required this.titleAr,
    this.titleEn = '',
    this.descriptionAr = '',
    this.descriptionEn = '',
    required this.preacherId,
    this.mosqueId = '',
    required this.date,
    required this.slot,
    this.exactTime,
    this.language = 'ar',
    this.interpretation,
    this.audience = 'all',
    this.womenSection = false,
    this.streamed = false,
    this.notifyFollowers = true,
    this.status = 'approved',
    this.source = 'admin',
    this.preacherNote = '',
    this.rejectionReason,
    this.cancelReason,
    this.submittedBy,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  /// [mosqueId] is empty only on a preacher's pending request: the admin who
  /// approves it chooses the mosque. [source] is admin (entered by an admin)
  /// or preacher (requested through a preacher link).
  final String id, requestId, type, topic, titleAr, titleEn, descriptionAr, descriptionEn,
      preacherId, mosqueId, slot, language, audience, status, source, preacherNote;
  final String? seriesId, exactTime, interpretation, rejectionReason, cancelReason, submittedBy, reviewedBy;
  final int? seq;
  final DateTime date;
  final DateTime? submittedAt, reviewedAt;
  final bool womenSection, streamed, notifyFollowers;

  String title(String lang) => pick(lang, titleAr, titleEn);
  String description(String lang) => pick(lang, descriptionAr, descriptionEn);
  bool get isPublic => status == 'approved';
  bool get isCancelled => status == 'cancelled';
  bool get hasMosque => mosqueId.isNotEmpty;
  bool get fromPreacher => source == 'preacher';

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
      id: _s(j['id']),
      requestId: _s(j['request_id']),
      seriesId: j['series_id'] as String?,
      seq: (j['seq'] as num?)?.toInt(),
      type: _s(j['type']),
      topic: _s(j['topic']),
      titleAr: _s(j['title_ar']),
      titleEn: _s(j['title_en']),
      descriptionAr: _s(j['description_ar']),
      descriptionEn: _s(j['description_en']),
      preacherId: _s(j['preacher_id']),
      mosqueId: _s(j['mosque_id']),
      date: parseIsoDate(_s(j['lesson_date'])),
      slot: _s(j['slot']),
      exactTime: (j['exact_time'] as String?)?.substring(0, 5),
      language: j['language'] as String? ?? 'ar',
      interpretation: j['interpretation'] as String?,
      audience: j['audience'] as String? ?? 'all',
      womenSection: j['women_section'] as bool? ?? false,
      streamed: j['streamed'] as bool? ?? false,
      notifyFollowers: j['notify_followers'] as bool? ?? true,
      status: j['status'] as String? ?? 'pending',
      source: j['source'] as String? ?? 'admin',
      preacherNote: _s(j['preacher_note']),
      rejectionReason: j['rejection_reason'] as String?,
      cancelReason: j['cancel_reason'] as String?,
      submittedBy: j['submitted_by'] as String?,
      submittedAt: _time(j['submitted_at']),
      reviewedBy: j['reviewed_by'] as String?,
      reviewedAt: _time(j['reviewed_at']));

  Lesson copyWith({
    String? status,
    String? rejectionReason,
    bool clearRejection = false,
    String? cancelReason,
    String? reviewedBy,
    bool clearReview = false,
    DateTime? reviewedAt,
    String? mosqueId,
    String? titleAr,
    String? titleEn,
    String? type,
    String? topic,
    DateTime? date,
    String? slot,
    String? exactTime,
    bool clearExact = false,
  }) =>
      Lesson(
          id: id,
          requestId: requestId,
          seriesId: seriesId,
          seq: seq,
          type: type ?? this.type,
          topic: topic ?? this.topic,
          titleAr: titleAr ?? this.titleAr,
          titleEn: titleEn ?? this.titleEn,
          descriptionAr: descriptionAr,
          descriptionEn: descriptionEn,
          preacherId: preacherId,
          mosqueId: mosqueId ?? this.mosqueId,
          date: date ?? this.date,
          slot: slot ?? this.slot,
          exactTime: clearExact ? null : (exactTime ?? this.exactTime),
          language: language,
          interpretation: interpretation,
          audience: audience,
          womenSection: womenSection,
          streamed: streamed,
          notifyFollowers: notifyFollowers,
          status: status ?? this.status,
          source: source,
          preacherNote: preacherNote,
          rejectionReason: clearRejection ? null : (rejectionReason ?? this.rejectionReason),
          cancelReason: cancelReason ?? this.cancelReason,
          submittedBy: submittedBy,
          submittedAt: submittedAt,
          reviewedBy: clearReview ? null : (reviewedBy ?? this.reviewedBy),
          reviewedAt: clearReview ? null : (reviewedAt ?? this.reviewedAt));
}

class LessonsReport {
  const LessonsReport(
      {required this.lessonId, required this.attendance, this.women = 0, this.issue = 'none', this.notes = ''});
  final String lessonId, issue, notes;
  final int attendance, women;

  factory LessonsReport.fromJson(Map<String, dynamic> j) => LessonsReport(
      lessonId: _s(j['lesson_id']),
      attendance: _int(j['attendance']),
      women: _int(j['women']),
      issue: j['issue'] as String? ?? 'none',
      notes: _s(j['notes']));
}

class LessonsFlag {
  const LessonsFlag({
    required this.id,
    required this.lessonId,
    required this.kind,
    this.message = '',
    this.reporterId,
    this.status = 'open',
    required this.createdAt,
  });
  final String id, lessonId, kind, message, status;
  final String? reporterId;
  final DateTime createdAt;

  factory LessonsFlag.fromJson(Map<String, dynamic> j) => LessonsFlag(
      id: _s(j['id']),
      lessonId: _s(j['lesson_id']),
      kind: _s(j['kind']),
      message: _s(j['message']),
      reporterId: j['reporter_id'] as String?,
      status: j['status'] as String? ?? 'open',
      createdAt: _time(j['created_at']) ?? DateTime.now());

  LessonsFlag resolved() => LessonsFlag(
      id: id, lessonId: lessonId, kind: kind, message: message, reporterId: reporterId, status: 'resolved',
      createdAt: createdAt);
}

class LessonsAuditEntry {
  const LessonsAuditEntry({
    required this.id,
    this.actorId,
    this.preacherId,
    this.actorName = '',
    required this.action,
    this.targetAr = '',
    this.targetEn = '',
    required this.createdAt,
  });
  final String id, action, targetAr, targetEn, actorName;

  /// [preacherId] is set when the action came through a preacher's link
  /// (then there is no [actorId]).
  final String? actorId, preacherId;
  final DateTime createdAt;
  String target(String lang) => pick(lang, targetAr, targetEn);

  factory LessonsAuditEntry.fromJson(Map<String, dynamic> j) => LessonsAuditEntry(
      id: _s(j['id']),
      actorId: j['actor_id'] as String?,
      preacherId: j['preacher_id'] as String?,
      action: _s(j['action']),
      targetAr: _s(j['target_ar']),
      targetEn: _s(j['target_en']),
      createdAt: _time(j['created_at']) ?? DateTime.now());
}

class LessonsNotification {
  const LessonsNotification({
    required this.id,
    this.icon = 'bell',
    required this.titleAr,
    required this.titleEn,
    this.bodyAr = '',
    this.bodyEn = '',
    this.route = '/lessons',
    required this.createdAt,
    this.readAt,
  });
  final String id, icon, titleAr, titleEn, bodyAr, bodyEn, route;
  final DateTime createdAt;
  final DateTime? readAt;
  bool get unread => readAt == null;
  String title(String lang) => pick(lang, titleAr, titleEn);
  String body(String lang) => pick(lang, bodyAr, bodyEn);

  factory LessonsNotification.fromJson(Map<String, dynamic> j) => LessonsNotification(
      id: _s(j['id']),
      icon: j['icon'] as String? ?? 'bell',
      titleAr: _s(j['title_ar']),
      titleEn: _s(j['title_en']),
      bodyAr: _s(j['body_ar']),
      bodyEn: _s(j['body_en']),
      route: j['route'] as String? ?? '/lessons',
      createdAt: _time(j['created_at']) ?? DateTime.now(),
      readAt: _time(j['read_at']));

  LessonsNotification markRead() => LessonsNotification(
      id: id, icon: icon, titleAr: titleAr, titleEn: titleEn, bodyAr: bodyAr, bodyEn: bodyEn,
      route: route, createdAt: createdAt, readAt: DateTime.now());
}

/// A viewer's reminder: which lesson, how early.
class LessonsReminder {
  const LessonsReminder({required this.lessonId, required this.lead, required this.remindAt});
  final String lessonId, lead;
  final DateTime remindAt;

  factory LessonsReminder.fromJson(Map<String, dynamic> j) => LessonsReminder(
      lessonId: _s(j['lesson_id']), lead: _s(j['lead']), remindAt: _time(j['remind_at'])!);
}

class LessonsPreferences {
  const LessonsPreferences({this.defaultLead = 'adhan', this.eveningDigest = true});
  final String defaultLead;
  final bool eveningDigest;
}

/// The signed-in viewer's own data.
class LessonsMine {
  const LessonsMine({
    this.reminders = const {},
    this.follows = const {},
    this.attended = const {},
    this.preferences = const LessonsPreferences(),
    this.notifications = const [],
  });
  final Map<String, LessonsReminder> reminders;

  /// Keys are `kind:id` (preacher, series, mosque).
  final Set<String> follows;
  final Set<String> attended;
  final LessonsPreferences preferences;
  final List<LessonsNotification> notifications;

  bool isFollowing(String kind, String id) => follows.contains('$kind:$id');
  int get unread => notifications.where((n) => n.unread).length;

  LessonsMine copyWith({
    Map<String, LessonsReminder>? reminders,
    Set<String>? follows,
    Set<String>? attended,
    LessonsPreferences? preferences,
    List<LessonsNotification>? notifications,
  }) =>
      LessonsMine(
          reminders: reminders ?? this.reminders,
          follows: follows ?? this.follows,
          attended: attended ?? this.attended,
          preferences: preferences ?? this.preferences,
          notifications: notifications ?? this.notifications);
}

/// What the caller may do, from `lessons_my_roles()`. Only admins (admins,
/// master admins and lessons-only admins) manage preachers and lessons.
class LessonsRoles {
  const LessonsRoles({this.signedIn = false, this.admin = false, this.master = false});
  final bool signedIn, admin, master;

  static const guest = LessonsRoles();

  factory LessonsRoles.fromJson(Map<String, dynamic>? j) => LessonsRoles(
      signedIn: true, admin: j?['admin'] as bool? ?? false, master: j?['master'] as bool? ?? false);
}

/// A preacher as the admins' list shows him.
class LessonsRosterEntry {
  const LessonsRosterEntry({
    required this.preacher,
    this.phoneMask,
    this.activeKeys = 0,
    this.lastSeen,
    this.pendingEdits = 0,
    this.lessons30d = 0,
  });
  final Preacher preacher;
  final String? phoneMask;

  /// Links that still open (not revoked, not ended).
  final int activeKeys;

  /// When the preacher last opened one of his links.
  final DateTime? lastSeen;
  final int pendingEdits, lessons30d;

  factory LessonsRosterEntry.fromJson(Map<String, dynamic> j) => LessonsRosterEntry(
      preacher: Preacher.fromJson(j),
      phoneMask: j['phone_mask'] as String?,
      activeKeys: _int(j['active_keys']),
      lastSeen: _time(j['last_seen']),
      pendingEdits: _int(j['pending_edits']),
      lessons30d: _int(j['lessons_30d']));
}

/// A preacher's link, as admins see it (the key itself is never stored).
/// once: the first phone to open it keeps it, until revoked or [validUntil].
/// window: any phone, from [validFrom] to [validUntil].
class PreacherKey {
  const PreacherKey({
    required this.id,
    required this.kind,
    this.validFrom,
    this.validUntil,
    this.openedAt,
    this.lastUsedAt,
    this.revokedAt,
    this.note = '',
    required this.createdAt,
    this.bound = false,
  });
  final String id, kind, note;
  final DateTime? validFrom, validUntil, openedAt, lastUsedAt, revokedAt;
  final DateTime createdAt;

  /// A one-time link that a phone has opened (and now keeps).
  final bool bound;

  /// revoked, ended, scheduled (a timed link not started), waiting (a
  /// one-time link nobody opened yet) or active.
  String state(DateTime now) {
    if (revokedAt != null) return 'revoked';
    if (validUntil != null && now.isAfter(validUntil!)) return 'ended';
    if (validFrom != null && now.isBefore(validFrom!)) return 'scheduled';
    if (kind == 'once' && !bound) return 'waiting';
    return 'active';
  }

  bool usable(DateTime now) => const {'scheduled', 'waiting', 'active'}.contains(state(now));

  factory PreacherKey.fromJson(Map<String, dynamic> j) => PreacherKey(
      id: _s(j['id']),
      kind: _s(j['kind']),
      validFrom: _time(j['valid_from']),
      validUntil: _time(j['valid_until']),
      openedAt: _time(j['opened_at']),
      lastUsedAt: _time(j['last_used_at']),
      revokedAt: _time(j['revoked_at']),
      note: _s(j['note']),
      createdAt: _time(j['created_at']) ?? DateTime.now(),
      bound: j['bound'] as bool? ?? false);
}

/// A link just created: the only time its secret [token] is known.
class NewPreacherKey {
  const NewPreacherKey({required this.id, required this.token, required this.kind, this.validFrom, this.validUntil});
  final String id, token, kind;
  final DateTime? validFrom, validUntil;

  factory NewPreacherKey.fromJson(Map<String, dynamic> j) => NewPreacherKey(
      id: _s(j['id']),
      token: _s(j['token']),
      kind: _s(j['kind']),
      validFrom: _time(j['valid_from']),
      validUntil: _time(j['valid_until']));
}

/// Card changes a preacher proposed through his link. Nothing changes on
/// his public card until an admin approves.
class PreacherEdit {
  const PreacherEdit({
    required this.id,
    required this.preacherId,
    required this.changes,
    this.status = 'pending',
    this.reason,
    required this.createdAt,
  });
  final String id, preacherId, status;

  /// Field name to new value: name_ar, name_en, title_ar, title_en, bio_ar,
  /// bio_en (strings) and languages (a list).
  final Map<String, dynamic> changes;
  final String? reason;
  final DateTime createdAt;
  bool get pending => status == 'pending';

  factory PreacherEdit.fromJson(Map<String, dynamic> j) => PreacherEdit(
      id: _s(j['id']),
      preacherId: _s(j['preacher_id']),
      changes: Map<String, dynamic>.from((j['payload'] as Map?) ?? const {}),
      status: j['status'] as String? ?? 'pending',
      reason: j['reason'] as String?,
      createdAt: _time(j['created_at']) ?? DateTime.now());
}

/// An account found by an admin's search (the admin user directory), to
/// link a preacher card to the preacher's Hadayah Live account.
class LessonsAccount {
  const LessonsAccount({required this.id, required this.nameAr, required this.nameEn, this.email = ''});
  final String id, nameAr, nameEn, email;
  String name(String lang) {
    final n = pick(lang, nameAr, nameEn);
    return n.isEmpty ? email : n;
  }

  factory LessonsAccount.fromJson(Map<String, dynamic> j) => LessonsAccount(
      id: _s(j['id']), nameAr: _s(j['display_name_ar']), nameEn: _s(j['display_name_en']), email: _s(j['email']));
}

/// A mosque an admin adds while entering a lesson.
class LessonsNewMosque {
  const LessonsNewMosque(
      {required this.nameAr, this.nameEn = '', required this.districtId, this.latitude, this.longitude, this.facilities = const []});
  final String nameAr, nameEn, districtId;
  final double? latitude, longitude;
  final List<String> facilities;

  Map<String, dynamic> toJson() => {
        'name_ar': nameAr,
        'name_en': nameEn,
        'district_id': districtId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'facilities': facilities,
      };
}

/// A lesson or weekly series an admin enters, sent to `lessons_add`. It is
/// published at once.
class LessonDraft {
  const LessonDraft({
    required this.preacherId,
    required this.type,
    required this.topic,
    required this.titleAr,
    this.titleEn = '',
    this.descriptionAr = '',
    this.language = 'ar',
    this.interpretation,
    this.audience = 'all',
    this.womenSection = false,
    this.streamed = false,
    this.notifyFollowers = true,
    required this.slot,
    this.exactTime,
    required this.dates,
    this.mosqueId,
    this.newMosque,
  });
  final String preacherId, type, topic, titleAr, titleEn, descriptionAr, language, audience, slot;
  final String? interpretation, exactTime, mosqueId;
  final bool womenSection, streamed, notifyFollowers;
  final List<DateTime> dates;
  final LessonsNewMosque? newMosque;

  Map<String, dynamic> toJson() => {
        'preacher_id': preacherId,
        'type': type,
        'topic': topic,
        'title_ar': titleAr,
        'title_en': titleEn,
        'description_ar': descriptionAr,
        'language': language,
        if (interpretation != null) 'interpretation': interpretation,
        'audience': audience,
        'women_section': womenSection,
        'streamed': streamed,
        'notify_followers': notifyFollowers,
        'slot': slot,
        if (exactTime != null) 'exact_time': exactTime,
        'dates': dates.map(isoDate).toList(),
        if (mosqueId != null) 'mosque_id': mosqueId,
        if (newMosque != null) 'new_mosque': newMosque!.toJson(),
      };
}

/// A lesson a preacher requests through his link, sent to
/// `lessons_key_request_lesson`. No mosque: the approving admin chooses it.
class LessonRequestDraft {
  const LessonRequestDraft({
    required this.type,
    required this.topic,
    required this.titleAr,
    this.language = 'ar',
    this.audience = 'all',
    required this.slot,
    required this.dates,
    this.note = '',
  });
  final String type, topic, titleAr, language, audience, slot, note;
  final List<DateTime> dates;

  Map<String, dynamic> toJson() => {
        'type': type,
        'topic': topic,
        'title_ar': titleAr,
        'language': language,
        'audience': audience,
        'slot': slot,
        'dates': dates.map(isoDate).toList(),
        'note': note,
      };
}

/// One of the preacher's lessons as his link shows it.
class PreacherLinkLesson {
  const PreacherLinkLesson({
    required this.id,
    required this.requestId,
    this.seriesId,
    this.seq,
    required this.titleAr,
    this.titleEn = '',
    required this.type,
    required this.topic,
    required this.date,
    required this.slot,
    this.exactTime,
    required this.status,
    this.source = 'admin',
    this.preacherNote = '',
    this.rejectionReason,
    this.cancelReason,
    this.mosqueAr = '',
    this.mosqueEn = '',
  });
  final String id, requestId, titleAr, titleEn, type, topic, slot, status, source, preacherNote, mosqueAr, mosqueEn;
  final String? seriesId, exactTime, rejectionReason, cancelReason;
  final int? seq;
  final DateTime date;
  String title(String lang) => pick(lang, titleAr, titleEn);
  String mosque(String lang) => pick(lang, mosqueAr, mosqueEn);

  factory PreacherLinkLesson.fromJson(Map<String, dynamic> j) => PreacherLinkLesson(
      id: _s(j['id']),
      requestId: _s(j['request_id']),
      seriesId: j['series_id'] as String?,
      seq: (j['seq'] as num?)?.toInt(),
      titleAr: _s(j['title_ar']),
      titleEn: _s(j['title_en']),
      type: _s(j['type']),
      topic: _s(j['topic']),
      date: parseIsoDate(_s(j['lesson_date'])),
      slot: _s(j['slot']),
      exactTime: (j['exact_time'] as String?)?.substring(0, 5),
      status: _s(j['status']),
      source: j['source'] as String? ?? 'admin',
      preacherNote: _s(j['preacher_note']),
      rejectionReason: j['rejection_reason'] as String?,
      cancelReason: j['cancel_reason'] as String?,
      mosqueAr: _s(j['mosque_name_ar']),
      mosqueEn: _s(j['mosque_name_en']));
}

/// What a preacher's link opens: his card, when the link ends, a card change
/// still waiting for an admin, and his lessons from the last two months on.
class PreacherLinkView {
  const PreacherLinkView({
    required this.preacher,
    required this.kind,
    this.validUntil,
    this.pendingEdit,
    this.lessons = const [],
  });
  final Preacher preacher;
  final String kind;
  final DateTime? validUntil;
  final Map<String, dynamic>? pendingEdit;
  final List<PreacherLinkLesson> lessons;

  factory PreacherLinkView.fromJson(Map<String, dynamic> j) {
    final key = Map<String, dynamic>.from((j['key'] as Map?) ?? const {});
    return PreacherLinkView(
        preacher: Preacher.fromJson(Map<String, dynamic>.from(j['preacher'] as Map)),
        kind: _s(key['kind']),
        validUntil: _time(key['valid_until']),
        pendingEdit: j['pending_edit'] == null ? null : Map<String, dynamic>.from(j['pending_edit'] as Map),
        lessons: [
          for (final l in (j['lessons'] as List? ?? const [])) PreacherLinkLesson.fromJson(Map<String, dynamic>.from(l as Map))
        ]);
  }
}

/// Everything public (and, for admins, every request).
class LessonsCatalog {
  const LessonsCatalog({
    this.districts = const {},
    this.mosques = const {},
    this.preachers = const {},
    this.series = const {},
    this.lessons = const {},
  });
  final Map<String, District> districts;
  final Map<String, Mosque> mosques;
  final Map<String, Preacher> preachers;
  final Map<String, LessonSeries> series;
  final Map<String, Lesson> lessons;

  LessonsCatalog copyWith({
    Map<String, District>? districts,
    Map<String, Mosque>? mosques,
    Map<String, Preacher>? preachers,
    Map<String, LessonSeries>? series,
    Map<String, Lesson>? lessons,
  }) =>
      LessonsCatalog(
          districts: districts ?? this.districts,
          mosques: mosques ?? this.mosques,
          preachers: preachers ?? this.preachers,
          series: series ?? this.series,
          lessons: lessons ?? this.lessons);
}

/// What only admins see: the preacher list, card changes waiting, viewers'
/// reports, the action log and after-lesson reports.
class LessonsAdminData {
  const LessonsAdminData({
    this.roster = const [],
    this.edits = const [],
    this.flags = const [],
    this.audit = const [],
    this.reports = const {},
  });
  final List<LessonsRosterEntry> roster;
  final List<PreacherEdit> edits;
  final List<LessonsFlag> flags;
  final List<LessonsAuditEntry> audit;
  final Map<String, LessonsReport> reports;
}
