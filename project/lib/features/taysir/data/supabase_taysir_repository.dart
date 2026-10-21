import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/taysir_dates.dart';
import '../domain/taysir_models.dart';
import 'taysir_repository.dart';

/// Taysir on our Supabase project (migration 20261021142359).
class SupabaseTaysirRepository implements TaysirRepository {
  SupabaseTaysirRepository([SupabaseClient? client]) : _injected = client;
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
      throw TaysirException(
          switch (e.code) {
            '42501' => TaysirFailure.forbidden,
            '22023' || '23514' || '22P02' => TaysirFailure.invalid,
            '23505' || '23503' => TaysirFailure.conflict,
            '55000' => TaysirFailure.expired,
            '42P01' || 'PGRST202' || 'PGRST205' => TaysirFailure.unavailable,
            _ => TaysirFailure.unknown,
          },
          e.message);
    } on AuthException catch (e) {
      throw TaysirException(TaysirFailure.forbidden, e.message);
    } catch (e) {
      if (e is TaysirException) rethrow;
      throw TaysirException(TaysirFailure.unavailable, '$e');
    }
  }

  List<Map<String, dynamic>> _rows(Object? data) =>
      (data as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();

  Future<Object?> _rpc(String fn, [Map<String, dynamic>? params]) =>
      _guard(() => _db.rpc(fn, params: params));

  @override
  Future<TaysirCatalog> loadCatalog() => _guard(() async {
        final since = isoDate(addDays(taysirToday(), -120));
        final results = await Future.wait<Object?>([
          _db.from('taysir_districts').select().order('sort'),
          _db.rpc('taysir_public_organizations'),
          _db.from('taysir_mosques').select(),
          _db.from('taysir_preachers').select(),
          _db.from('taysir_series').select(),
          _db.from('taysir_lessons').select().or('lesson_date.gte.$since,status.eq.pending'),
        ]);
        return TaysirCatalog(
          districts: {for (final r in _rows(results[0])) r['id'] as String: TaysirDistrict.fromJson(r)},
          organizations: {
            for (final r in _rows(results[1])) r['organization_id'] as String: TaysirOrganization.fromJson(r)
          },
          mosques: {for (final r in _rows(results[2])) r['id'] as String: TaysirMosque.fromJson(r)},
          preachers: {for (final r in _rows(results[3])) r['id'] as String: TaysirPreacher.fromJson(r)},
          series: {for (final r in _rows(results[4])) r['id'] as String: TaysirSeries.fromJson(r)},
          lessons: {for (final r in _rows(results[5])) r['id'] as String: TaysirLesson.fromJson(r)},
        );
      });

  @override
  Future<TaysirRoles> loadRoles() async {
    if (currentUserId == null) return TaysirRoles.guest;
    final r = await _rpc('taysir_my_roles');
    return TaysirRoles.fromJson(r == null ? null : Map<String, dynamic>.from(r as Map));
  }

  @override
  Future<TaysirMine> loadMine() async {
    if (currentUserId == null) return const TaysirMine();
    return _guard(() async {
      final r = await Future.wait<Object?>([
        _db.from('taysir_reminders').select(),
        _db.from('taysir_follows').select(),
        _db.from('taysir_attendance').select('lesson_id'),
        _db.from('taysir_preferences').select().maybeSingle(),
        _db.from('taysir_notifications').select().order('created_at', ascending: false).limit(100),
      ]);
      final prefs = r[3] as Map<String, dynamic>?;
      return TaysirMine(
        reminders: {for (final x in _rows(r[0])) x['lesson_id'] as String: TaysirReminder.fromJson(x)},
        follows: {for (final x in _rows(r[1])) '${x['kind']}:${x['target_id']}'},
        attended: {for (final x in _rows(r[2])) x['lesson_id'] as String},
        preferences: prefs == null
            ? const TaysirPreferences()
            : TaysirPreferences(
                defaultLead: prefs['default_lead'] as String? ?? 'adhan',
                eveningDigest: prefs['evening_digest'] as bool? ?? true),
        notifications: [for (final x in _rows(r[4])) TaysirNotification.fromJson(x)],
      );
    });
  }

  @override
  Future<TaysirStaffData> loadStaff(String organizationId) => _guard(() async {
        final r = await Future.wait<Object?>([
          _db.rpc('taysir_roster', params: {'p_org': organizationId}),
          _db.rpc('taysir_team', params: {'p_org': organizationId}),
          _db.from('taysir_flags').select().eq('organization_id', organizationId).order('created_at', ascending: false),
          _db.from('taysir_audit').select().eq('organization_id', organizationId).order('created_at', ascending: false).limit(300),
          _db.from('taysir_lesson_reports').select(),
        ]);
        return TaysirStaffData(
          roster: [for (final x in _rows(r[0])) TaysirRosterEntry.fromJson(x)],
          team: [for (final x in _rows(r[1])) TaysirTeamMember.fromJson(x)],
          flags: [for (final x in _rows(r[2])) TaysirFlag.fromJson(x)],
          audit: [for (final x in _rows(r[3])) TaysirAuditEntry.fromJson(x)],
          reports: {for (final x in _rows(r[4])) x['lesson_id'] as String: TaysirReport.fromJson(x)},
        );
      });

  @override
  Future<List<TaysirOrganization>> loadAdminOrganizations() async =>
      [for (final r in _rows(await _rpc('taysir_admin_organizations'))) TaysirOrganization.fromJson(r)];

  @override
  Future<void> setReminder(String lessonId, String lead, DateTime remindAt) => _guard(() => _db
      .from('taysir_reminders')
      .upsert({'profile_id': currentUserId, 'lesson_id': lessonId, 'lead': lead, 'remind_at': remindAt.toUtc().toIso8601String()}));

  @override
  Future<void> removeReminder(String lessonId) =>
      _guard(() => _db.from('taysir_reminders').delete().eq('lesson_id', lessonId));

  @override
  Future<void> setFollow(String kind, String id, bool on) => _guard(() => on
      ? _db.from('taysir_follows').upsert({'profile_id': currentUserId, 'kind': kind, 'target_id': id})
      : _db.from('taysir_follows').delete().eq('kind', kind).eq('target_id', id));

  @override
  Future<void> setAttended(String lessonId, bool on) => _guard(() => on
      ? _db.from('taysir_attendance').upsert({'profile_id': currentUserId, 'lesson_id': lessonId})
      : _db.from('taysir_attendance').delete().eq('lesson_id', lessonId));

  @override
  Future<void> savePreferences(TaysirPreferences p) => _guard(() => _db.from('taysir_preferences').upsert({
        'profile_id': currentUserId,
        'default_lead': p.defaultLead,
        'evening_digest': p.eveningDigest,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }));

  @override
  Future<void> markNotificationsRead([List<String>? ids]) =>
      _rpc('taysir_mark_notifications_read', {'p_ids': ids});

  @override
  Future<void> flag(String lessonId, String kind, String message) =>
      _rpc('taysir_flag', {'p_lesson': lessonId, 'p_kind': kind, 'p_message': message});

  @override
  Future<String> submit(TaysirDraft draft) async =>
      (await _rpc('taysir_submit', {'p': draft.toJson()})) as String;

  @override
  Future<int> review(List<String> requestIds, String decision, {String? reason}) async =>
      (await _rpc('taysir_review', {'p_requests': requestIds, 'p_decision': decision, 'p_reason': reason})) as int;

  @override
  Future<int> undoReview(List<String> requestIds) async =>
      (await _rpc('taysir_undo_review', {'p_requests': requestIds})) as int;

  @override
  Future<void> withdraw(String requestId) => _rpc('taysir_withdraw', {'p_request': requestId});

  @override
  Future<int> cancelLesson(String lessonId, String reason) async =>
      (await _rpc('taysir_cancel_lesson', {'p_lesson': lessonId, 'p_reason': reason})) as int;

  @override
  Future<void> editLesson(String lessonId, Map<String, dynamic> patch) =>
      _rpc('taysir_edit_lesson', {'p_lesson': lessonId, 'p': patch});

  @override
  Future<void> postReport(String lessonId, int attendance, int women, String issue, String notes) =>
      _rpc('taysir_post_report', {
        'p_lesson': lessonId,
        'p_attendance': attendance,
        'p_women': women,
        'p_issue': issue,
        'p_notes': notes,
      });

  @override
  Future<void> resolveFlag(String flagId) => _rpc('taysir_resolve_flag', {'p_flag': flagId});

  @override
  Future<String> upsertPreacher(Map<String, dynamic> preacher) async =>
      (await _rpc('taysir_upsert_preacher', {'p': preacher})) as String;

  @override
  Future<int> importPreachers(String organizationId, List<Map<String, dynamic>> rows) async =>
      (await _rpc('taysir_import_preachers', {'p_org': organizationId, 'p_rows': rows})) as int;

  @override
  Future<String?> revealPhone(String preacherId) async =>
      (await _rpc('taysir_reveal_phone', {'p_preacher': preacherId})) as String?;

  @override
  Future<void> setSubmit(String preacherId, bool enabled) =>
      _rpc('taysir_set_submit', {'p_preacher': preacherId, 'p_enabled': enabled});

  @override
  Future<void> unlinkPreacher(String preacherId) =>
      _rpc('taysir_unlink_preacher', {'p_preacher': preacherId});

  @override
  Future<String> createInvite(String preacherId) async {
    final r = await _rpc('taysir_create_invite', {'p_preacher': preacherId});
    return (r as Map)['token'] as String;
  }

  @override
  Future<TaysirInviteInfo?> inviteInfo(String token) async {
    final r = await _rpc('taysir_invite_info', {'p_token': token});
    return r == null ? null : TaysirInviteInfo.fromJson(Map<String, dynamic>.from(r as Map));
  }

  @override
  Future<String> claimInvite(String token, List<String> languages) async =>
      (await _rpc('taysir_claim_invite', {'p_token': token, 'p_languages': languages})) as String;

  @override
  Future<void> setCoordinator(String organizationId, String profileId, bool enabled) =>
      _rpc('taysir_set_coordinator', {'p_org': organizationId, 'p_profile': profileId, 'p_enabled': enabled});

  @override
  Future<void> setOrganizationEnabled(String organizationId, bool enabled) =>
      _rpc('taysir_set_org_enabled', {'p_org': organizationId, 'p_enabled': enabled});

  @override
  Future<List<TaysirCoordinator>> loadCoordinators() async =>
      [for (final r in _rows(await _rpc('taysir_admin_coordinators'))) TaysirCoordinator.fromJson(r)];

  /// The admin user directory (admin tier only on the server).
  @override
  Future<List<TaysirAccount>> searchAccounts(String query) async => [
        for (final r in _rows(await _rpc('admin_user_directory', {'p_query': query.trim(), 'p_offset': 0})))
          if (r['is_banned'] != true) TaysirAccount.fromJson(r)
      ];

  @override
  Future<int> setCoordinatorOrganizations(String profileId, List<String> organizationIds) async =>
      (await _rpc('taysir_set_coordinator_orgs', {'p_profile': profileId, 'p_orgs': organizationIds})) as int;

  @override
  Future<String> upsertMosque(Map<String, dynamic> mosque) async =>
      (await _rpc('taysir_upsert_mosque', {'p': mosque})) as String;

  @override
  Future<void> verifyMosque(String mosqueId) => _rpc('taysir_verify_mosque', {'p_mosque': mosqueId});

  @override
  Future<void> rejectMosque(String mosqueId, {String? mergeInto}) =>
      _rpc('taysir_reject_mosque', {'p_mosque': mosqueId, 'p_merge_into': mergeInto});
}
