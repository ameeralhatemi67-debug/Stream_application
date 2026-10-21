import 'taysir_dates.dart';

/// Picks the Arabic or English text, falling back to whichever exists.
String pick(String lang, String ar, String en) =>
    lang == 'ar' ? (ar.isNotEmpty ? ar : en) : (en.isNotEmpty ? en : ar);

String _s(Object? v) => v?.toString() ?? '';
List<String> _list(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];
DateTime? _time(Object? v) => v == null ? null : DateTime.parse(v.toString()).toLocal();
double? _num(Object? v) => v == null ? null : (v as num).toDouble();

class TaysirDistrict {
  const TaysirDistrict(
      {required this.id, required this.city, required this.nameAr, required this.nameEn, this.sort = 0});
  final String id, city, nameAr, nameEn;
  final int sort;
  String name(String lang) => pick(lang, nameAr, nameEn);

  factory TaysirDistrict.fromJson(Map<String, dynamic> j) => TaysirDistrict(
      id: _s(j['id']),
      city: _s(j['city']),
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      sort: (j['sort'] as num?)?.toInt() ?? 0);
}

class TaysirOrganization {
  const TaysirOrganization(
      {required this.id, required this.nameAr, required this.nameEn, this.enabled = true, this.verified = false, this.avatarUrl});
  final String id, nameAr, nameEn;
  final bool enabled, verified;
  final String? avatarUrl;
  String name(String lang) => pick(lang, nameAr, nameEn);

  factory TaysirOrganization.fromJson(Map<String, dynamic> j) => TaysirOrganization(
      id: _s(j['organization_id'] ?? j['id']),
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      enabled: j['enabled'] as bool? ?? true,
      verified: j['is_verified'] as bool? ?? false,
      avatarUrl: j['avatar_url'] as String?);

  TaysirOrganization copyWith({bool? enabled}) => TaysirOrganization(
      id: id, nameAr: nameAr, nameEn: nameEn, enabled: enabled ?? this.enabled, verified: verified, avatarUrl: avatarUrl);
}

class TaysirMosque {
  const TaysirMosque({
    required this.id,
    required this.nameAr,
    this.nameEn = '',
    required this.districtId,
    this.latitude,
    this.longitude,
    this.mapsUrl,
    this.facilities = const [],
    this.verified = true,
    this.suggestedBy,
  });
  final String id, nameAr, nameEn, districtId;
  final double? latitude, longitude;
  final String? mapsUrl, suggestedBy;
  final List<String> facilities;
  final bool verified;
  String name(String lang) => pick(lang, nameAr, nameEn);
  bool get hasPin => latitude != null && longitude != null;

  /// Directions: the stored Maps link, else the pin.
  Uri? get directions => mapsUrl != null
      ? Uri.parse(mapsUrl!)
      : hasPin
          ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude')
          : null;

  factory TaysirMosque.fromJson(Map<String, dynamic> j) => TaysirMosque(
      id: _s(j['id']),
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      districtId: _s(j['district_id']),
      latitude: _num(j['latitude']),
      longitude: _num(j['longitude']),
      mapsUrl: j['maps_url'] as String?,
      facilities: _list(j['facilities']),
      verified: j['verified'] as bool? ?? false,
      suggestedBy: j['suggested_by'] as String?);

  TaysirMosque copyWith({bool? verified, String? nameAr, String? nameEn, String? districtId,
          double? latitude, double? longitude, List<String>? facilities}) =>
      TaysirMosque(
          id: id,
          nameAr: nameAr ?? this.nameAr,
          nameEn: nameEn ?? this.nameEn,
          districtId: districtId ?? this.districtId,
          latitude: latitude ?? this.latitude,
          longitude: longitude ?? this.longitude,
          mapsUrl: mapsUrl,
          facilities: facilities ?? this.facilities,
          verified: verified ?? this.verified,
          suggestedBy: suggestedBy);
}

class TaysirPreacher {
  const TaysirPreacher({
    required this.id,
    required this.organizationId,
    this.linkedProfileId,
    required this.nameAr,
    this.nameEn = '',
    this.titleAr = '',
    this.titleEn = '',
    this.bioAr = '',
    this.bioEn = '',
    this.city = 'khobar',
    this.affiliation = 'coop',
    this.languages = const ['ar'],
    this.listed = true,
  });
  final String id, organizationId, nameAr, nameEn, titleAr, titleEn, bioAr, bioEn, city, affiliation;
  final String? linkedProfileId;
  final List<String> languages;
  final bool listed;
  String name(String lang) => pick(lang, nameAr, nameEn);
  String title(String lang) => pick(lang, titleAr, titleEn);
  String bio(String lang) => pick(lang, bioAr, bioEn);

  factory TaysirPreacher.fromJson(Map<String, dynamic> j) => TaysirPreacher(
      id: _s(j['id']),
      organizationId: _s(j['organization_id']),
      linkedProfileId: j['linked_profile_id'] as String?,
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      titleAr: _s(j['title_ar']),
      titleEn: _s(j['title_en']),
      bioAr: _s(j['bio_ar']),
      bioEn: _s(j['bio_en']),
      city: j['city'] as String? ?? 'khobar',
      affiliation: j['affiliation'] as String? ?? 'coop',
      languages: _list(j['languages']),
      listed: j['listed'] as bool? ?? true);

  TaysirPreacher copyWith({String? linkedProfileId, bool clearLink = false, List<String>? languages,
          String? nameAr, String? nameEn, String? titleAr, String? titleEn, String? city,
          String? affiliation, bool? listed}) =>
      TaysirPreacher(
          id: id,
          organizationId: organizationId,
          linkedProfileId: clearLink ? null : (linkedProfileId ?? this.linkedProfileId),
          nameAr: nameAr ?? this.nameAr,
          nameEn: nameEn ?? this.nameEn,
          titleAr: titleAr ?? this.titleAr,
          titleEn: titleEn ?? this.titleEn,
          bioAr: bioAr,
          bioEn: bioEn,
          city: city ?? this.city,
          affiliation: affiliation ?? this.affiliation,
          languages: languages ?? this.languages,
          listed: listed ?? this.listed);
}

class TaysirSeries {
  const TaysirSeries({
    required this.id,
    required this.organizationId,
    required this.requestId,
    required this.preacherId,
    required this.mosqueId,
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
  final String id, organizationId, requestId, preacherId, mosqueId, titleAr, titleEn, type, topic, language, audience, slot, status;
  final int total;
  String title(String lang) => pick(lang, titleAr, titleEn);

  factory TaysirSeries.fromJson(Map<String, dynamic> j) => TaysirSeries(
      id: _s(j['id']),
      organizationId: _s(j['organization_id']),
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
      total: (j['total'] as num).toInt(),
      status: _s(j['status']));

  TaysirSeries copyWith({String? status, String? mosqueId}) => TaysirSeries(
      id: id, organizationId: organizationId, requestId: requestId, preacherId: preacherId,
      mosqueId: mosqueId ?? this.mosqueId, titleAr: titleAr, titleEn: titleEn, type: type, topic: topic,
      language: language, audience: audience, slot: slot, total: total, status: status ?? this.status);
}

class TaysirLesson {
  const TaysirLesson({
    required this.id,
    required this.organizationId,
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
    required this.mosqueId,
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
    this.rejectionReason,
    this.cancelReason,
    this.submittedBy,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
  });
  final String id, organizationId, requestId, type, topic, titleAr, titleEn, descriptionAr, descriptionEn,
      preacherId, mosqueId, slot, language, audience, status;
  final String? seriesId, exactTime, interpretation, rejectionReason, cancelReason, submittedBy, reviewedBy;
  final int? seq;
  final DateTime date;
  final DateTime? submittedAt, reviewedAt;
  final bool womenSection, streamed, notifyFollowers;

  String title(String lang) => pick(lang, titleAr, titleEn);
  String description(String lang) => pick(lang, descriptionAr, descriptionEn);
  bool get isPublic => status == 'approved';
  bool get isCancelled => status == 'cancelled';

  factory TaysirLesson.fromJson(Map<String, dynamic> j) => TaysirLesson(
      id: _s(j['id']),
      organizationId: _s(j['organization_id']),
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
      rejectionReason: j['rejection_reason'] as String?,
      cancelReason: j['cancel_reason'] as String?,
      submittedBy: j['submitted_by'] as String?,
      submittedAt: _time(j['submitted_at']),
      reviewedBy: j['reviewed_by'] as String?,
      reviewedAt: _time(j['reviewed_at']));

  TaysirLesson copyWith({
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
    DateTime? date,
    String? slot,
    String? exactTime,
    bool clearExact = false,
  }) =>
      TaysirLesson(
          id: id,
          organizationId: organizationId,
          requestId: requestId,
          seriesId: seriesId,
          seq: seq,
          type: type,
          topic: topic,
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
          rejectionReason: clearRejection ? null : (rejectionReason ?? this.rejectionReason),
          cancelReason: cancelReason ?? this.cancelReason,
          submittedBy: submittedBy,
          submittedAt: submittedAt,
          reviewedBy: clearReview ? null : (reviewedBy ?? this.reviewedBy),
          reviewedAt: clearReview ? null : (reviewedAt ?? this.reviewedAt));
}

class TaysirReport {
  const TaysirReport(
      {required this.lessonId, required this.attendance, this.women = 0, this.issue = 'none', this.notes = ''});
  final String lessonId, issue, notes;
  final int attendance, women;

  factory TaysirReport.fromJson(Map<String, dynamic> j) => TaysirReport(
      lessonId: _s(j['lesson_id']),
      attendance: (j['attendance'] as num).toInt(),
      women: (j['women'] as num?)?.toInt() ?? 0,
      issue: j['issue'] as String? ?? 'none',
      notes: _s(j['notes']));
}

class TaysirFlag {
  const TaysirFlag({
    required this.id,
    required this.lessonId,
    required this.organizationId,
    required this.kind,
    this.message = '',
    this.reporterId,
    this.status = 'open',
    required this.createdAt,
  });
  final String id, lessonId, organizationId, kind, message, status;
  final String? reporterId;
  final DateTime createdAt;

  factory TaysirFlag.fromJson(Map<String, dynamic> j) => TaysirFlag(
      id: _s(j['id']),
      lessonId: _s(j['lesson_id']),
      organizationId: _s(j['organization_id']),
      kind: _s(j['kind']),
      message: _s(j['message']),
      reporterId: j['reporter_id'] as String?,
      status: j['status'] as String? ?? 'open',
      createdAt: _time(j['created_at']) ?? DateTime.now());
}

class TaysirAuditEntry {
  const TaysirAuditEntry({
    required this.id,
    this.organizationId,
    this.actorId,
    this.actorName = '',
    required this.action,
    this.targetAr = '',
    this.targetEn = '',
    required this.createdAt,
  });
  final String id, action, targetAr, targetEn, actorName;
  final String? organizationId, actorId;
  final DateTime createdAt;
  String target(String lang) => pick(lang, targetAr, targetEn);

  factory TaysirAuditEntry.fromJson(Map<String, dynamic> j) => TaysirAuditEntry(
      id: _s(j['id']),
      organizationId: j['organization_id'] as String?,
      actorId: j['actor_id'] as String?,
      action: _s(j['action']),
      targetAr: _s(j['target_ar']),
      targetEn: _s(j['target_en']),
      createdAt: _time(j['created_at']) ?? DateTime.now());
}

class TaysirNotification {
  const TaysirNotification({
    required this.id,
    this.icon = 'bell',
    required this.titleAr,
    required this.titleEn,
    this.bodyAr = '',
    this.bodyEn = '',
    this.route = '/taysir',
    required this.createdAt,
    this.readAt,
  });
  final String id, icon, titleAr, titleEn, bodyAr, bodyEn, route;
  final DateTime createdAt;
  final DateTime? readAt;
  bool get unread => readAt == null;
  String title(String lang) => pick(lang, titleAr, titleEn);
  String body(String lang) => pick(lang, bodyAr, bodyEn);

  factory TaysirNotification.fromJson(Map<String, dynamic> j) => TaysirNotification(
      id: _s(j['id']),
      icon: j['icon'] as String? ?? 'bell',
      titleAr: _s(j['title_ar']),
      titleEn: _s(j['title_en']),
      bodyAr: _s(j['body_ar']),
      bodyEn: _s(j['body_en']),
      route: j['route'] as String? ?? '/taysir',
      createdAt: _time(j['created_at']) ?? DateTime.now(),
      readAt: _time(j['read_at']));

  TaysirNotification markRead() => TaysirNotification(
      id: id, icon: icon, titleAr: titleAr, titleEn: titleEn, bodyAr: bodyAr, bodyEn: bodyEn,
      route: route, createdAt: createdAt, readAt: DateTime.now());
}

/// A viewer's reminder: which lesson, how early.
class TaysirReminder {
  const TaysirReminder({required this.lessonId, required this.lead, required this.remindAt});
  final String lessonId, lead;
  final DateTime remindAt;

  factory TaysirReminder.fromJson(Map<String, dynamic> j) => TaysirReminder(
      lessonId: _s(j['lesson_id']), lead: _s(j['lead']), remindAt: _time(j['remind_at'])!);
}

class TaysirPreferences {
  const TaysirPreferences({this.defaultLead = 'adhan', this.eveningDigest = true});
  final String defaultLead;
  final bool eveningDigest;
}

/// The signed-in viewer's own data.
class TaysirMine {
  const TaysirMine({
    this.reminders = const {},
    this.follows = const {},
    this.attended = const {},
    this.preferences = const TaysirPreferences(),
    this.notifications = const [],
  });
  final Map<String, TaysirReminder> reminders;

  /// Keys are `kind:id` (preacher, series, mosque).
  final Set<String> follows;
  final Set<String> attended;
  final TaysirPreferences preferences;
  final List<TaysirNotification> notifications;

  bool isFollowing(String kind, String id) => follows.contains('$kind:$id');
  int get unread => notifications.where((n) => n.unread).length;

  TaysirMine copyWith({
    Map<String, TaysirReminder>? reminders,
    Set<String>? follows,
    Set<String>? attended,
    TaysirPreferences? preferences,
    List<TaysirNotification>? notifications,
  }) =>
      TaysirMine(
          reminders: reminders ?? this.reminders,
          follows: follows ?? this.follows,
          attended: attended ?? this.attended,
          preferences: preferences ?? this.preferences,
          notifications: notifications ?? this.notifications);
}

/// What the caller may do, from `taysir_my_roles()`.
class TaysirRoles {
  const TaysirRoles({
    this.signedIn = false,
    this.admin = false,
    this.master = false,
    this.coordinate = const {},
    this.lead = const {},
    this.preacherCards = const [],
  });
  final bool signedIn, admin, master;

  /// Organizations the caller coordinates (admins: every enabled one).
  final Set<String> coordinate;

  /// Organizations the caller leads (owner/co-owner): may grant coordinator.
  final Set<String> lead;
  final List<({String preacherId, String organizationId, bool canSubmit})> preacherCards;

  bool get isCoordinator => admin || coordinate.isNotEmpty;
  bool get isPreacher => preacherCards.any((c) => c.canSubmit);
  bool get canGrant => admin || lead.isNotEmpty;
  bool coordinates(String orgId) => admin || coordinate.contains(orgId);
  String? get ownPreacherId =>
      preacherCards.where((c) => c.canSubmit).map((c) => c.preacherId).firstOrNull;

  static const guest = TaysirRoles();

  factory TaysirRoles.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const TaysirRoles(signedIn: true);
    return TaysirRoles(
      signedIn: true,
      admin: j['admin'] as bool? ?? false,
      master: j['master'] as bool? ?? false,
      coordinate: _list(j['coordinate']).toSet(),
      lead: _list(j['lead']).toSet(),
      preacherCards: [
        for (final c in (j['preacher'] as List? ?? const []))
          (
            preacherId: _s((c as Map)['preacher_id']),
            organizationId: _s(c['organization_id']),
            canSubmit: c['can_submit'] as bool? ?? false
          )
      ],
    );
  }
}

class TaysirRosterEntry {
  const TaysirRosterEntry({
    required this.preacher,
    this.phoneMask,
    this.account = 'none',
    this.canSubmit = false,
    this.lessons30d = 0,
  });
  final TaysirPreacher preacher;
  final String? phoneMask;

  /// linked, invited or none.
  final String account;
  final bool canSubmit;
  final int lessons30d;

  factory TaysirRosterEntry.fromJson(Map<String, dynamic> j) => TaysirRosterEntry(
      preacher: TaysirPreacher.fromJson(j),
      phoneMask: j['phone_mask'] as String?,
      account: j['account'] as String? ?? 'none',
      canSubmit: j['can_submit'] as bool? ?? false,
      lessons30d: (j['lessons_30d'] as num?)?.toInt() ?? 0);
}

class TaysirTeamMember {
  const TaysirTeamMember({
    required this.profileId,
    required this.role,
    required this.nameAr,
    required this.nameEn,
    this.coordinator = false,
    this.grantedAt,
    this.grantedByAr,
    this.grantedByEn,
  });
  final String profileId, role, nameAr, nameEn;
  final bool coordinator;
  final DateTime? grantedAt;
  final String? grantedByAr, grantedByEn;
  String name(String lang) => pick(lang, nameAr, nameEn);

  factory TaysirTeamMember.fromJson(Map<String, dynamic> j) => TaysirTeamMember(
      profileId: _s(j['profile_id']),
      role: _s(j['role']),
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      coordinator: j['coordinator'] as bool? ?? false,
      grantedAt: _time(j['granted_at']),
      grantedByAr: j['granted_by_name_ar'] as String?,
      grantedByEn: j['granted_by_name_en'] as String?);
}

class TaysirInviteInfo {
  const TaysirInviteInfo({
    required this.preacherId,
    required this.nameAr,
    required this.nameEn,
    required this.city,
    required this.affiliation,
    required this.languages,
    required this.organizationAr,
    required this.organizationEn,
  });
  final String preacherId, nameAr, nameEn, city, affiliation, organizationAr, organizationEn;
  final List<String> languages;
  String name(String lang) => pick(lang, nameAr, nameEn);
  String organization(String lang) => pick(lang, organizationAr, organizationEn);

  factory TaysirInviteInfo.fromJson(Map<String, dynamic> j) => TaysirInviteInfo(
      preacherId: _s(j['preacher_id']),
      nameAr: _s(j['name_ar']),
      nameEn: _s(j['name_en']),
      city: _s(j['city']),
      affiliation: _s(j['affiliation']),
      languages: _list(j['languages']),
      organizationAr: _s(j['organization_name_ar']),
      organizationEn: _s(j['organization_name_en']));
}

/// A new mosque a preacher suggests inside a request.
class TaysirNewMosque {
  const TaysirNewMosque(
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

/// The submit wizard's result, sent to `taysir_submit`.
class TaysirDraft {
  const TaysirDraft({
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
    this.replaces,
    this.direct = false,
  });
  final String preacherId, type, topic, titleAr, titleEn, descriptionAr, language, audience, slot;
  final String? interpretation, exactTime, mosqueId, replaces;
  final bool womenSection, streamed, notifyFollowers, direct;
  final List<DateTime> dates;
  final TaysirNewMosque? newMosque;

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
        if (replaces != null) 'replaces': replaces,
        'direct': direct,
      };
}

/// Everything public (and, for staff, their organizations' requests).
class TaysirCatalog {
  const TaysirCatalog({
    this.districts = const {},
    this.organizations = const {},
    this.mosques = const {},
    this.preachers = const {},
    this.series = const {},
    this.lessons = const {},
  });
  final Map<String, TaysirDistrict> districts;
  final Map<String, TaysirOrganization> organizations;
  final Map<String, TaysirMosque> mosques;
  final Map<String, TaysirPreacher> preachers;
  final Map<String, TaysirSeries> series;
  final Map<String, TaysirLesson> lessons;

  TaysirCatalog copyWith({
    Map<String, TaysirDistrict>? districts,
    Map<String, TaysirOrganization>? organizations,
    Map<String, TaysirMosque>? mosques,
    Map<String, TaysirPreacher>? preachers,
    Map<String, TaysirSeries>? series,
    Map<String, TaysirLesson>? lessons,
  }) =>
      TaysirCatalog(
          districts: districts ?? this.districts,
          organizations: organizations ?? this.organizations,
          mosques: mosques ?? this.mosques,
          preachers: preachers ?? this.preachers,
          series: series ?? this.series,
          lessons: lessons ?? this.lessons);
}

/// A coordinator's view of one organization.
class TaysirStaffData {
  const TaysirStaffData({
    this.roster = const [],
    this.team = const [],
    this.flags = const [],
    this.audit = const [],
    this.reports = const {},
  });
  final List<TaysirRosterEntry> roster;
  final List<TaysirTeamMember> team;
  final List<TaysirFlag> flags;
  final List<TaysirAuditEntry> audit;
  final Map<String, TaysirReport> reports;
}
