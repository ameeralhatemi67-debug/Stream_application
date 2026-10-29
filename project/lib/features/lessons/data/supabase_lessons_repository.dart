import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/streamer_asset_path.dart';
import '../domain/lessons_dates.dart';
import '../domain/lessons_models.dart';
import 'lessons_repository.dart';

/// Lessons on our Supabase project (migrations 20261022125222, 20261029120000).
class SupabaseLessonsRepository implements LessonsRepository {
  SupabaseLessonsRepository([SupabaseClient? client]) : _injected = client;
  final SupabaseClient? _injected;
  SupabaseClient get _db => _injected ?? Supabase.instance.client;

  @override
  bool get isDemo => false;

  @override
  String? get currentUserId => _db.auth.currentUser?.id;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      // A preacher link that no longer opens carries its reason as the hint.
      if (e.code == '28000') throw LessonsException(LessonsFailure.expired, e.hint ?? 'revoked');
      throw LessonsException(
          switch (e.code) {
            '42501' => LessonsFailure.forbidden,
            '22023' || '23514' || '22P02' => LessonsFailure.invalid,
            '23505' || '23503' => LessonsFailure.conflict,
            '54000' => LessonsFailure.busy,
            '42P01' || '42883' || 'PGRST202' || 'PGRST205' => LessonsFailure.unavailable,
            _ => LessonsFailure.unknown,
          },
          // A hint names the case for the UI (no_email, pending, ...).
          (e.hint ?? '').isNotEmpty ? e.hint! : e.message);
    } on AuthException catch (e) {
      throw LessonsException(LessonsFailure.forbidden, e.message);
    } catch (e) {
      if (e is LessonsException) rethrow;
      throw LessonsException(LessonsFailure.unavailable, '$e');
    }
  }

  List<Map<String, dynamic>> _rows(Object? data) =>
      (data as List? ?? const []).map((r) => Map<String, dynamic>.from(r as Map)).toList();

  Future<Object?> _rpc(String fn, [Map<String, dynamic>? params]) =>
      _guard(() => _db.rpc(fn, params: params));

  String? _instant(DateTime? t) => t?.toUtc().toIso8601String();

  @override
  Future<LessonsCatalog> loadCatalog() => _guard(() async {
        final since = isoDate(addDays(lessonsToday(), -120));
        final results = await Future.wait<Object?>([
          _db.from('mosque_districts').select().order('sort'),
          _db.from('mosques').select(),
          _db.from('preachers').select(),
          _db.from('lesson_series').select(),
          _db.from('lessons').select().or('lesson_date.gte.$since,status.eq.pending'),
        ]);
        return LessonsCatalog(
          districts: {for (final r in _rows(results[0])) r['id'] as String: District.fromJson(r)},
          mosques: {for (final r in _rows(results[1])) r['id'] as String: Mosque.fromJson(r)},
          preachers: {for (final r in _rows(results[2])) r['id'] as String: Preacher.fromJson(r)},
          series: {for (final r in _rows(results[3])) r['id'] as String: LessonSeries.fromJson(r)},
          lessons: {for (final r in _rows(results[4])) r['id'] as String: Lesson.fromJson(r)},
        );
      });

  @override
  Future<LessonsRoles> loadRoles() async {
    if (currentUserId == null) return LessonsRoles.guest;
    final r = await _rpc('lessons_my_roles');
    return LessonsRoles.fromJson(r == null ? null : Map<String, dynamic>.from(r as Map));
  }

  @override
  Future<LessonsMine> loadMine() async {
    if (currentUserId == null) return const LessonsMine();
    return _guard(() async {
      final r = await Future.wait<Object?>([
        _db.from('lesson_reminders').select(),
        _db.from('lesson_follows').select(),
        _db.from('lesson_attendance').select('lesson_id'),
        _db.from('lesson_preferences').select().maybeSingle(),
        _db.from('lesson_notifications').select().order('created_at', ascending: false).limit(100),
      ]);
      final prefs = r[3] as Map<String, dynamic>?;
      return LessonsMine(
        reminders: {for (final x in _rows(r[0])) x['lesson_id'] as String: LessonsReminder.fromJson(x)},
        follows: {for (final x in _rows(r[1])) '${x['kind']}:${x['target_id']}'},
        attended: {for (final x in _rows(r[2])) x['lesson_id'] as String},
        preferences: prefs == null
            ? const LessonsPreferences()
            : LessonsPreferences(
                defaultLead: prefs['default_lead'] as String? ?? 'adhan',
                eveningDigest: prefs['evening_digest'] as bool? ?? true),
        notifications: [for (final x in _rows(r[4])) LessonsNotification.fromJson(x)],
      );
    });
  }

  @override
  Future<LessonsAdminData> loadAdmin() => _guard(() async {
        final r = await Future.wait<Object?>([
          _db.rpc('lessons_roster'),
          _db.from('preacher_edits').select().eq('status', 'pending').order('created_at'),
          _db.from('lesson_flags').select().order('created_at', ascending: false).limit(200),
          _db.from('lesson_audit').select().order('created_at', ascending: false).limit(300),
          _db.from('lesson_reports').select(),
          _db.from('preacher_applications').select().order('created_at', ascending: false).limit(200),
        ]);
        return LessonsAdminData(
          roster: [for (final x in _rows(r[0])) LessonsRosterEntry.fromJson(x)],
          edits: [for (final x in _rows(r[1])) PreacherEdit.fromJson(x)],
          flags: [for (final x in _rows(r[2])) LessonsFlag.fromJson(x)],
          audit: [for (final x in _rows(r[3])) LessonsAuditEntry.fromJson(x)],
          reports: {for (final x in _rows(r[4])) x['lesson_id'] as String: LessonsReport.fromJson(x)},
          applications: [for (final x in _rows(r[5])) PreacherApplication.fromJson(x)],
        );
      });

  // --------------------------------------------------------------- viewers
  @override
  Future<void> setReminder(String lessonId, String lead, DateTime remindAt) => _guard(() => _db
      .from('lesson_reminders')
      .upsert({'profile_id': currentUserId, 'lesson_id': lessonId, 'lead': lead, 'remind_at': _instant(remindAt)}));

  @override
  Future<void> removeReminder(String lessonId) =>
      _guard(() => _db.from('lesson_reminders').delete().eq('lesson_id', lessonId));

  @override
  Future<void> setFollow(String kind, String id, bool on) => _guard(() => on
      ? _db.from('lesson_follows').upsert({'profile_id': currentUserId, 'kind': kind, 'target_id': id})
      : _db.from('lesson_follows').delete().eq('kind', kind).eq('target_id', id));

  @override
  Future<void> setAttended(String lessonId, bool on) => _guard(() => on
      ? _db.from('lesson_attendance').upsert({'profile_id': currentUserId, 'lesson_id': lessonId})
      : _db.from('lesson_attendance').delete().eq('lesson_id', lessonId));

  @override
  Future<void> savePreferences(LessonsPreferences p) => _guard(() => _db.from('lesson_preferences').upsert({
        'profile_id': currentUserId,
        'default_lead': p.defaultLead,
        'evening_digest': p.eveningDigest,
        'updated_at': _instant(DateTime.now()),
      }));

  @override
  Future<void> markNotificationsRead([List<String>? ids]) =>
      _rpc('lessons_mark_notifications_read', {'p_ids': ids});

  @override
  Future<void> flag(String lessonId, String kind, String message) =>
      _rpc('lessons_flag', {'p_lesson': lessonId, 'p_kind': kind, 'p_message': message});

  // --------------------------------------------------------- admin lessons
  @override
  Future<String> addLessons(LessonDraft draft) async =>
      (await _rpc('lessons_add', {'p': draft.toJson()})) as String;

  @override
  Future<int> review(List<String> requestIds, String decision, {String? reason, String? mosqueId}) async =>
      (await _rpc('lessons_review', {
        'p_requests': requestIds,
        'p_decision': decision,
        'p_reason': reason,
        'p_mosque': mosqueId,
      })) as int;

  @override
  Future<int> undoReview(List<String> requestIds) async =>
      (await _rpc('lessons_undo_review', {'p_requests': requestIds})) as int;

  @override
  Future<void> withdraw(String requestId) => _rpc('lessons_withdraw', {'p_request': requestId});

  @override
  Future<int> cancelLesson(String lessonId, String reason) async =>
      (await _rpc('lessons_cancel_lesson', {'p_lesson': lessonId, 'p_reason': reason})) as int;

  @override
  Future<void> editLesson(String lessonId, Map<String, dynamic> patch) =>
      _rpc('lessons_edit_lesson', {'p_lesson': lessonId, 'p': patch});

  @override
  Future<void> postReport(String lessonId, int attendance, int women, String issue, String notes) =>
      _rpc('lessons_post_report', {
        'p_lesson': lessonId,
        'p_attendance': attendance,
        'p_women': women,
        'p_issue': issue,
        'p_notes': notes,
      });

  @override
  Future<void> resolveFlag(String flagId) => _rpc('lessons_resolve_flag', {'p_flag': flagId});

  // ------------------------------------------------------- admin preachers
  @override
  Future<String> upsertPreacher(Map<String, dynamic> preacher) async =>
      (await _rpc('lessons_upsert_preacher', {'p': preacher})) as String;

  @override
  Future<int> removePreacher(String preacherId) async =>
      (await _rpc('lessons_remove_preacher', {'p_preacher': preacherId})) as int;

  @override
  Future<int> importPreachers(List<Map<String, dynamic>> rows) async =>
      (await _rpc('lessons_import_preachers', {'p_rows': rows})) as int;

  @override
  Future<String?> revealPhone(String preacherId) async =>
      (await _rpc('lessons_reveal_phone', {'p_preacher': preacherId})) as String?;

  @override
  Future<String?> revealEmail(String preacherId) async =>
      (await _rpc('lessons_reveal_email', {'p_preacher': preacherId})) as String?;

  /// Admins: preacher-photos/preachers/. Applicants: their own
  /// streamer-assets folder, which account deletion cleans.
  @override
  Future<String> uploadPhoto(Uint8List bytes, {bool application = false}) => _guard(() async {
        final (type, ext) = _imageType(bytes);
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final String bucket, path;
        if (application) {
          final uid = currentUserId;
          if (uid == null) throw const LessonsException(LessonsFailure.forbidden);
          bucket = 'streamer-assets';
          path = streamerAssetPath(userId: uid, folder: 'preacher', fileName: 'photo.$ext', timestamp: stamp);
        } else {
          final r = math.Random.secure();
          bucket = 'preacher-photos';
          path = 'preachers/${stamp}_${List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join()}.$ext';
        }
        await _db.storage.from(bucket).uploadBinary(path, bytes,
            // A path never changes, so browsers and the CDN may keep it a year.
            fileOptions: FileOptions(contentType: type, upsert: false, cacheControl: '31536000'));
        return _db.storage.from(bucket).getPublicUrl(path);
      });

  static (String, String) _imageType(Uint8List b) {
    if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return ('image/png', 'png');
    if (b.length > 12 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return ('image/webp', 'webp');
    return ('image/jpeg', 'jpg');
  }

  @override
  Future<void> decideEdit(String editId, bool approve, {String? reason}) =>
      _rpc('lessons_decide_edit', {'p_edit': editId, 'p_approve': approve, 'p_reason': reason});

  /// The admin user directory (admin tier only on the server).
  @override
  Future<List<LessonsAccount>> searchAccounts(String query) async => [
        for (final r in _rows(await _rpc('admin_user_directory', {'p_query': query.trim(), 'p_offset': 0})))
          if (r['is_banned'] != true) LessonsAccount.fromJson(r)
      ];

  // ---------------------------------------------------- admin applications
  @override
  Future<String?> decideApplication(String applicationId, bool approve,
          {String? reason, String? mosqueId, String? affiliation}) async =>
      (await _rpc('lessons_decide_application', {
        'p_application': applicationId,
        'p_approve': approve,
        'p_reason': reason,
        'p': {
          if (mosqueId != null) 'mosque_id': mosqueId,
          if (affiliation != null) 'affiliation': affiliation,
        },
      })) as String?;

  @override
  Future<void> undoApplication(String applicationId) =>
      _rpc('lessons_undo_application', {'p_application': applicationId});

  // ---------------------------------------------------------- admin emails
  @override
  Future<List<PreacherEmailEntry>> loadEmails({String? preacherId}) async => [
        for (final r in _rows(await _rpc('lessons_email_log', {'p_preacher': preacherId}))) PreacherEmailEntry.fromJson(r)
      ];

  @override
  Future<void> retryEmail(String emailId) => _rpc('lessons_retry_email', {'p_email': emailId});

  // ----------------------------------------------------------- admin links
  @override
  Future<NewPreacherKey> createKey(String preacherId, String kind,
          {DateTime? validFrom, DateTime? validUntil, String note = '', bool email = false}) async =>
      NewPreacherKey.fromJson(Map<String, dynamic>.from((await _rpc('lessons_create_key', {
        'p_preacher': preacherId,
        'p_kind': kind,
        'p_valid_from': _instant(validFrom),
        'p_valid_until': _instant(validUntil),
        'p_note': note,
        // Sent only when asked, so the function as it was before
        // 20261029120000 still matches the call.
        if (email) 'p_email': true,
      })) as Map));

  @override
  Future<List<PreacherKey>> loadKeys(String preacherId) async =>
      [for (final r in _rows(await _rpc('lessons_preacher_keys', {'p_preacher': preacherId}))) PreacherKey.fromJson(r)];

  @override
  Future<void> revokeKey(String keyId) => _rpc('lessons_revoke_key', {'p_key': keyId});

  // --------------------------------------------------------- admin mosques
  @override
  Future<String> upsertMosque(Map<String, dynamic> mosque) async =>
      (await _rpc('lessons_upsert_mosque', {'p': mosque})) as String;

  @override
  Future<void> removeMosque(String mosqueId, {String? mergeInto}) =>
      _rpc('lessons_remove_mosque', {'p_mosque': mosqueId, 'p_merge_into': mergeInto});

  // -------------------------------------------------------- preacher links
  @override
  Future<PreacherLinkView> openLink(String token, String device) async => PreacherLinkView.fromJson(
      Map<String, dynamic>.from((await _rpc('lessons_key_open', {'p_key': token, 'p_device': device})) as Map));

  @override
  Future<void> proposeCardEdit(String token, String device, Map<String, dynamic> changes) =>
      _rpc('lessons_key_update_profile', {'p_key': token, 'p_device': device, 'p': changes});

  @override
  Future<String> requestLesson(String token, String device, LessonRequestDraft draft) async =>
      (await _rpc('lessons_key_request_lesson', {'p_key': token, 'p_device': device, 'p': draft.toJson()})) as String;

  @override
  Future<void> withdrawRequest(String token, String device, String requestId) =>
      _rpc('lessons_key_withdraw', {'p_key': token, 'p_device': device, 'p_request': requestId});

  // ------------------------------------------------------------- applying
  @override
  Future<String> apply(PreacherApplicationDraft draft) async => (await _rpc('lessons_apply', {'p': draft.toJson()})) as String;

  @override
  Future<void> withdrawApplication() => _rpc('lessons_withdraw_application');

  // ------------------------------------------------- preacher by account
  @override
  Future<PreacherLinkView> openMyPage() async =>
      PreacherLinkView.fromJson(Map<String, dynamic>.from((await _rpc('lessons_me_page')) as Map));

  @override
  Future<void> proposeMyCardEdit(Map<String, dynamic> changes) => _rpc('lessons_me_update_profile', {'p': changes});

  @override
  Future<String> requestMyLesson(LessonRequestDraft draft) async =>
      (await _rpc('lessons_me_request_lesson', {'p': draft.toJson()})) as String;

  @override
  Future<void> withdrawMyRequest(String requestId) => _rpc('lessons_me_withdraw', {'p_request': requestId});
}
