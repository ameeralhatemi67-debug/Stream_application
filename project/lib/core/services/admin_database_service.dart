import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/admin/models/broadcaster_application_model.dart';
import '../../features/admin/models/terms_and_conditions_model.dart';
import '../../features/admin/models/viewer_analytics_model.dart';
import '../../features/admin/models/admin_role_assignment_model.dart';
import '../../features/admin/models/chat_report_model.dart';
import '../../features/organization/models/org_audit_log_entry.dart';
import '../../features/organization/models/org_affiliation_request_model.dart';
import '../../features/organization/models/org_broadcaster_permissions.dart';
import '../../features/organization/models/org_venue_branch_model.dart';
import '../../features/organization/models/org_speaker_model.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
bool _looksLikeUuid(String? value) => value != null && _uuidPattern.hasMatch(value);

/// Core Database & Persistence Service for Admin Moderation, Broadcaster Applications,
/// Dynamic Platform Governance, Viewer Analytics, and Organization Audit Logs.
///
/// Reads/writes Supabase when it's initialized (the real app); falls back to
/// the original SharedPreferences/in-memory implementation otherwise (widget
/// tests, which never call Supabase.initialize(), and as a resilience net if
/// a Supabase call fails at runtime -- e.g. no network, or an org/streamer id
/// that doesn't correspond to a real backend row yet). Every public method
/// signature is unchanged from the SharedPreferences-only version.
class AdminDatabaseService {
  static const String _kApplicationsKey = 'streamer_admin_applications_v1';
  static const String _kTermsKey = 'streamer_admin_terms_v1';
  static const String _kAnalyticsKey = 'streamer_admin_analytics_v1';
  static const String _kAuditLogsKey = 'streamer_org_audit_logs_v1';
  static const String _kAffiliationRequestsKey = 'streamer_org_affiliations_v1';

  final SharedPreferences? _prefs;
  final bool _useSupabase;
  List<BroadcasterApplicationModel> _cachedApplications = [];
  List<OrgAuditLogEntry> _cachedAuditLogs = [];
  List<OrgAffiliationRequestModel> _cachedAffiliationRequests = [];
  TermsAndConditionsModel? _cachedTerms;
  ViewerAnalyticsModel? _cachedAnalytics;

  AdminDatabaseService([this._prefs]) : _useSupabase = _supabaseReady();

  static bool _supabaseReady() {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// Factory constructor to initialize with SharedPreferences (used as the
  /// fallback store when Supabase isn't available).
  static Future<AdminDatabaseService> create() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      final service = AdminDatabaseService(prefs);
      await service._init();
      return service;
    } catch (e) {
      final fallback = AdminDatabaseService(null);
      await fallback._init();
      return fallback;
    }
  }

  Future<void> _init() async {
    await loadApplications();
    await loadTerms();
    await loadAnalytics();
    await loadAuditLogs();
    await loadAffiliationRequests();
  }

  // ==========================================
  // Broadcaster Applications CRUD Repository
  // ==========================================

  Future<List<BroadcasterApplicationModel>> loadApplications() async {
    if (_useSupabase) {
      try {
        final rows = await _client
            .from('broadcaster_applications')
            .select()
            .order('submitted_at', ascending: false);
        final reviewerNames = await _resolveDisplayNames(
          rows.map((r) => r['reviewed_by'] as String?),
        );
        _cachedApplications = rows
            .map((r) => _applicationFromRow(r, reviewerNames))
            .toList();
        return List.unmodifiable(_cachedApplications);
      } catch (e) {
        debugPrint('Supabase loadApplications failed, falling back: $e');
      }
    }
    return _loadApplicationsFallback();
  }

  Future<List<BroadcasterApplicationModel>> _loadApplicationsFallback() async {
    if (_cachedApplications.isNotEmpty) {
      return List.unmodifiable(_cachedApplications);
    }

    final rawJson = _prefs?.getString(_kApplicationsKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson);
        _cachedApplications = decoded
            .map((item) =>
                BroadcasterApplicationModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return List.unmodifiable(_cachedApplications);
      } catch (e) {
        debugPrint('Error decoding cached applications: $e');
      }
    }

    // Seed realistic initial pending applications for immediate testing
    _cachedApplications = _createInitialSeedApplications();
    await _saveApplicationsToPrefs();
    return List.unmodifiable(_cachedApplications);
  }

  Future<void> submitApplication(BroadcasterApplicationModel application) async {
    if (_useSupabase) {
      try {
        final applicantId = _client.auth.currentUser?.id;
        if (applicantId == null) {
          throw Exception('Cannot submit an application while signed out.');
        }
        await _client.from('broadcaster_applications').upsert({
          'id': application.id,
          'applicant_profile_id': applicantId,
          ..._applicationToRow(application),
        });
        final existingIdx =
            _cachedApplications.indexWhere((a) => a.id == application.id);
        if (existingIdx != -1) {
          _cachedApplications[existingIdx] = application;
        } else {
          _cachedApplications.insert(0, application);
        }
        return;
      } catch (e) {
        debugPrint('Supabase submitApplication failed, falling back: $e');
      }
    }

    final existingIdx =
        _cachedApplications.indexWhere((a) => a.id == application.id);
    if (existingIdx != -1) {
      _cachedApplications[existingIdx] = application;
    } else {
      _cachedApplications.insert(0, application);
    }
    await _saveApplicationsToPrefs();
  }

  Future<BroadcasterApplicationModel?> updateApplicationStatus(
    String id,
    ApplicationStatus newStatus, {
    String? reviewNotes,
    String? reviewedBy,
  }) async {
    if (_useSupabase) {
      try {
        final reviewerId = _client.auth.currentUser?.id;
        final row = await _client
            .from('broadcaster_applications')
            .update({
              'status': newStatus.name,
              'admin_review_notes': reviewNotes,
              'reviewed_by': reviewerId,
              'reviewed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .select()
            .single();

        if (newStatus == ApplicationStatus.rejected) {
          final applicantId = row['applicant_profile_id'] as String?;
          if (applicantId != null && _looksLikeUuid(applicantId)) {
            await _client.from('profiles').update({
              'is_streamer': false,
              'is_verified': false,
            }).eq('id', applicantId);
          }
        }

        final reviewerNames = await _resolveDisplayNames([row['reviewed_by'] as String?]);
        final updated = _applicationFromRow(row, reviewerNames);
        final idx = _cachedApplications.indexWhere((a) => a.id == id);
        if (idx != -1) {
          _cachedApplications[idx] = updated;
        }
        await _saveApplicationsToPrefs();
        return updated;
      } catch (e) {
        debugPrint('Supabase updateApplicationStatus failed, falling back: $e');
      }
    }

    final idx = _cachedApplications.indexWhere((a) => a.id == id);
    if (idx == -1) return null;

    final existing = _cachedApplications[idx];
    final updated = existing.copyWith(
      status: newStatus,
      adminReviewNotes: reviewNotes,
      reviewedBy: reviewedBy ?? 'Admin',
      reviewedAt: DateTime.now(),
    );
    _cachedApplications[idx] = updated;
    await _saveApplicationsToPrefs();
    return updated;
  }

  Future<BroadcasterApplicationModel?> loadMyApplication(String profileId) async {
    if (!_useSupabase || !_looksLikeUuid(profileId)) return null;
    try {
      final rows = await _client
          .from('broadcaster_applications')
          .select()
          .eq('applicant_profile_id', profileId)
          .order('submitted_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      final reviewerNames = await _resolveDisplayNames(
        rows.map((r) => r['reviewed_by'] as String?),
      );
      return _applicationFromRow(rows.first, reviewerNames);
    } catch (e) {
      debugPrint('loadMyApplication failed: $e');
      return null;
    }
  }

  Future<bool> checkIsProfileStreamer(String profileId) async {
    if (!_useSupabase || !_looksLikeUuid(profileId)) return false;
    try {
      final row = await _client
          .from('profiles')
          .select('is_streamer')
          .eq('id', profileId)
          .maybeSingle();
      return row?['is_streamer'] == true;
    } catch (e) {
      debugPrint('checkIsProfileStreamer failed: $e');
      return false;
    }
  }

  Future<bool> revokeStreamer(String streamerIdOrProfileId) async {
    if (!_useSupabase) return false;
    try {
      final cleanId = streamerIdOrProfileId.replaceFirst('streamer_', '');
      if (_looksLikeUuid(cleanId)) {
        await _client.from('profiles').update({
          'is_streamer': false,
          'is_verified': false,
        }).eq('id', cleanId);

        await _client.from('broadcaster_applications').update({
          'status': 'rejected',
          'admin_review_notes': 'Streamer privileges revoked by administration.',
        }).eq('applicant_profile_id', cleanId);
      }
      return true;
    } catch (e) {
      debugPrint('Supabase revokeStreamer failed: $e');
      return false;
    }
  }

  Future<bool> deleteApplication(String id) async {
    if (_useSupabase) {
      try {
        final row = await _client
            .from('broadcaster_applications')
            .select('applicant_profile_id')
            .eq('id', id)
            .maybeSingle();
        final applicantId = row?['applicant_profile_id'] as String?;

        await _client.from('broadcaster_applications').delete().eq('id', id);

        if (applicantId != null && _looksLikeUuid(applicantId)) {
          await _client.from('profiles').update({
            'is_streamer': false,
            'is_verified': false,
          }).eq('id', applicantId);
        }

        _cachedApplications.removeWhere((a) => a.id == id);
        await _saveApplicationsToPrefs();
        return true;
      } catch (e) {
        debugPrint('Supabase deleteApplication failed, falling back: $e');
      }
    }

    final idx = _cachedApplications.indexWhere((a) => a.id == id);
    if (idx == -1) return false;

    _cachedApplications.removeAt(idx);
    await _saveApplicationsToPrefs();
    return true;
  }

  Future<void> _saveApplicationsToPrefs() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final jsonList = _cachedApplications.map((a) => a.toJson()).toList();
      await prefs.setString(_kApplicationsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving applications to SharedPreferences: $e');
    }
  }

  Map<String, dynamic> _applicationToRow(BroadcasterApplicationModel a) => {
        'account_type': a.accountType.name,
        'applicant_name_en': a.applicantNameEn,
        'applicant_name_ar': a.applicantNameAr,
        'email': a.email,
        'phone': a.phone,
        'academic_title_en': a.academicTitleEn,
        'academic_title_ar': a.academicTitleAr,
        'institution_en': a.institutionEn,
        'institution_ar': a.institutionAr,
        'category_id': a.categoryId,
        'tags': a.tags,
        'organization_type': a.organizationType,
        'venue_name_en': a.venueNameEn,
        'venue_name_ar': a.venueNameAr,
        'latitude': a.latitude,
        'longitude': a.longitude,
        'seating_capacity': a.seatingCapacity,
        'official_website_url': a.officialWebsiteUrl,
        'youtube_channel_url': a.youtubeChannelUrl,
        'youtube_handle': a.youtubeHandle,
        'bio_en': a.bioEn,
        'bio_ar': a.bioAr,
        'avatar_url': a.avatarUrl,
        'banner_url': a.bannerUrl,
        'status': a.status.name,
        'admin_review_notes': a.adminReviewNotes,
        'submitted_at': a.submittedAt.toIso8601String(),
      };

  BroadcasterApplicationModel _applicationFromRow(
    Map<String, dynamic> row,
    Map<String, String> reviewerNames,
  ) {
    return BroadcasterApplicationModel(
      id: row['id'] as String,
      applicantProfileId: row['applicant_profile_id'] as String?,
      accountType:
          ApplicationAccountType.values.byName(row['account_type'] as String),
      applicantNameEn: row['applicant_name_en'] as String? ?? '',
      applicantNameAr: row['applicant_name_ar'] as String? ?? '',
      email: row['email'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      academicTitleEn: row['academic_title_en'] as String?,
      academicTitleAr: row['academic_title_ar'] as String?,
      institutionEn: row['institution_en'] as String?,
      institutionAr: row['institution_ar'] as String?,
      categoryId: row['category_id'] as String? ?? 'computer_science',
      tags: List<String>.from(row['tags'] as List? ?? const []),
      organizationType: row['organization_type'] as String?,
      venueNameEn: row['venue_name_en'] as String? ?? '',
      venueNameAr: row['venue_name_ar'] as String? ?? '',
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
      seatingCapacity: (row['seating_capacity'] as num?)?.toInt() ?? 0,
      officialWebsiteUrl: row['official_website_url'] as String?,
      youtubeChannelUrl: row['youtube_channel_url'] as String? ?? '',
      youtubeHandle: row['youtube_handle'] as String? ?? '',
      bioEn: row['bio_en'] as String? ?? '',
      bioAr: row['bio_ar'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String? ?? '',
      bannerUrl: row['banner_url'] as String? ?? '',
      status: ApplicationStatus.values.byName(row['status'] as String),
      adminReviewNotes: row['admin_review_notes'] as String?,
      reviewedBy: reviewerNames[row['reviewed_by'] as String?],
      submittedAt: DateTime.parse(row['submitted_at'] as String),
      reviewedAt: row['reviewed_at'] != null
          ? DateTime.parse(row['reviewed_at'] as String)
          : null,
    );
  }

  /// Batch-resolves profile ids to a display string ("Name" or the email if
  /// no display name is set), used for reviewed_by (a uuid FK server-side,
  /// but a display string in BroadcasterApplicationModel).
  Future<Map<String, String>> _resolveDisplayNames(Iterable<String?> ids) async {
    final uniqueIds = ids.whereType<String>().toSet();
    if (uniqueIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, display_name_en, email')
          .inFilter('id', uniqueIds.toList());
      return {
        for (final r in (rows as List))
          (r as Map<String, dynamic>)['id'] as String:
              ((r['display_name_en'] as String?)?.trim().isNotEmpty ?? false)
                  ? r['display_name_en'] as String
                  : (r['email'] as String? ?? 'Admin'),
      };
    } catch (e) {
      debugPrint('Failed to resolve reviewer display names: $e');
      return {};
    }
  }

  // ==========================================
  // Organization Audit Trail Logging
  // ==========================================

  Future<List<OrgAuditLogEntry>> loadAuditLogs([String? organizationId]) async {
    if (_useSupabase) {
      try {
        var query = _client.from('audit_logs').select();
        if (_looksLikeUuid(organizationId)) {
          query = query.eq('organization_id', organizationId as Object);
        }
        final rows = await query.order('created_at', ascending: false);
        _cachedAuditLogs =
            (rows as List).map((r) => _auditLogFromRow(r as Map<String, dynamic>)).toList();
        return List.unmodifiable(_cachedAuditLogs);
      } catch (e) {
        debugPrint('Supabase loadAuditLogs failed, falling back: $e');
      }
    }
    return _loadAuditLogsFallback(organizationId);
  }

  Future<List<OrgAuditLogEntry>> _loadAuditLogsFallback(
      [String? organizationId]) async {
    if (_cachedAuditLogs.isEmpty) {
      final rawJson = _prefs?.getString(_kAuditLogsKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(rawJson);
          _cachedAuditLogs = decoded
              .map((item) =>
                  OrgAuditLogEntry.fromJson(item as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('Error decoding cached audit logs: $e');
        }
      }
    }

    if (_cachedAuditLogs.isEmpty) {
      _cachedAuditLogs = _createInitialSeedAuditLogs();
      await _saveAuditLogsToPrefs();
    }

    if (organizationId != null && organizationId.isNotEmpty) {
      return List.unmodifiable(_cachedAuditLogs
          .where((l) => l.organizationId == organizationId)
          .toList());
    }
    return List.unmodifiable(_cachedAuditLogs);
  }

  /// Writes via the log_audit_event() RPC (audit_logs has no direct INSERT
  /// policy -- see supabase/migrations' RLS -- writes are system-derived only,
  /// with the actor's identity taken server-side from auth.uid()).
  Future<void> recordAuditLog(OrgAuditLogEntry entry) async {
    if (_useSupabase) {
      try {
        await _client.rpc('log_audit_event', params: {
          'p_organization_id':
              _looksLikeUuid(entry.organizationId) ? entry.organizationId : null,
          'p_action': entry.action.name,
          'p_description_en': entry.descriptionEn,
          'p_description_ar': entry.descriptionAr,
          'p_metadata': entry.metadata,
        });
        _cachedAuditLogs.insert(0, entry);
        return;
      } catch (e) {
        debugPrint('Supabase recordAuditLog failed, falling back: $e');
      }
    }
    _cachedAuditLogs.insert(0, entry);
    await _saveAuditLogsToPrefs();
  }

  Future<void> _saveAuditLogsToPrefs() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final jsonList = _cachedAuditLogs.map((l) => l.toJson()).toList();
      await prefs.setString(_kAuditLogsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving audit logs to SharedPreferences: $e');
    }
  }

  OrgAuditLogEntry _auditLogFromRow(Map<String, dynamic> row) {
    return OrgAuditLogEntry(
      logId: row['id'] as String,
      organizationId: row['organization_id'] as String? ?? '',
      timestamp: DateTime.parse(row['created_at'] as String),
      actorEmail: row['actor_email'] as String? ?? 'unknown',
      actorName: row['actor_name'] as String? ?? 'Unknown',
      action: OrgAuditAction.values.firstWhere(
        (e) => e.name == row['action'] as String,
        orElse: () => OrgAuditAction.updateOrganizationProfile,
      ),
      descriptionEn: row['description_en'] as String? ?? '',
      descriptionAr: row['description_ar'] as String? ?? '',
      metadata: (row['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  // ==========================================
  // Terms & Conditions Governance Repository
  // ==========================================

  Future<TermsAndConditionsModel> loadTerms() async {
    if (_useSupabase) {
      try {
        final row = await _client
            .from('terms_and_conditions')
            .select()
            .eq('is_active', true)
            .maybeSingle();
        if (row != null) {
          _cachedTerms = _termsFromRow(row);
          return _cachedTerms!;
        }
        final defaults = TermsAndConditionsModel.createDefault();
        await saveTerms(defaults);
        return defaults;
      } catch (e) {
        debugPrint('Supabase loadTerms failed, falling back: $e');
      }
    }
    return _loadTermsFallback();
  }

  Future<TermsAndConditionsModel> _loadTermsFallback() async {
    if (_cachedTerms != null) return _cachedTerms!;

    final rawJson = _prefs?.getString(_kTermsKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        _cachedTerms = TermsAndConditionsModel.fromJson(decoded);
        return _cachedTerms!;
      } catch (e) {
        debugPrint('Error decoding cached terms: $e');
      }
    }

    _cachedTerms = TermsAndConditionsModel.createDefault();
    await _saveTermsToPrefs(_cachedTerms!);
    return _cachedTerms!;
  }

  Future<void> saveTerms(TermsAndConditionsModel terms) async {
    if (_useSupabase) {
      try {
        // Only one row may have is_active = true (enforced by a partial
        // unique index) -- deactivate any other active version first.
        await _client
            .from('terms_and_conditions')
            .update({'is_active': false})
            .eq('is_active', true)
            .neq('version', terms.version);
        await _client.from('terms_and_conditions').upsert({
          ..._termsToRow(terms),
          'is_active': true,
        });
        _cachedTerms = terms;
        return;
      } catch (e) {
        debugPrint('Supabase saveTerms failed, falling back: $e');
      }
    }
    _cachedTerms = terms;
    await _saveTermsToPrefs(terms);
  }

  Future<void> _saveTermsToPrefs(TermsAndConditionsModel terms) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kTermsKey, jsonEncode(terms.toJson()));
    } catch (e) {
      debugPrint('Error saving terms to SharedPreferences: $e');
    }
  }

  Map<String, dynamic> _termsToRow(TermsAndConditionsModel t) => {
        'version': t.version,
        'last_updated': t.lastUpdated.toIso8601String(),
        'terms_of_service_en': t.termsOfServiceEn,
        'terms_of_service_ar': t.termsOfServiceAr,
        'broadcaster_guidelines_en': t.broadcasterGuidelinesEn,
        'broadcaster_guidelines_ar': t.broadcasterGuidelinesAr,
        'privacy_policy_en': t.privacyPolicyEn,
        'privacy_policy_ar': t.privacyPolicyAr,
      };

  TermsAndConditionsModel _termsFromRow(Map<String, dynamic> row) {
    return TermsAndConditionsModel(
      version: row['version'] as String,
      lastUpdated: DateTime.parse(row['last_updated'] as String),
      termsOfServiceEn: row['terms_of_service_en'] as String? ?? '',
      termsOfServiceAr: row['terms_of_service_ar'] as String? ?? '',
      broadcasterGuidelinesEn: row['broadcaster_guidelines_en'] as String? ?? '',
      broadcasterGuidelinesAr: row['broadcaster_guidelines_ar'] as String? ?? '',
      privacyPolicyEn: row['privacy_policy_en'] as String? ?? '',
      privacyPolicyAr: row['privacy_policy_ar'] as String? ?? '',
    );
  }

  // ==========================================
  // Viewers Analytics Repository (platform_analytics, singleton row)
  // ==========================================

  Future<ViewerAnalyticsModel> loadAnalytics() async {
    if (_useSupabase) {
      try {
        final row = await _client
            .from('platform_analytics')
            .select()
            .eq('id', true)
            .maybeSingle();
        if (row != null) {
          _cachedAnalytics = _analyticsFromRow(row);
          return _cachedAnalytics!;
        }
        final defaults = ViewerAnalyticsModel.createDefault();
        await saveAnalytics(defaults);
        return defaults;
      } catch (e) {
        debugPrint('Supabase loadAnalytics failed, falling back: $e');
      }
    }
    return _loadAnalyticsFallback();
  }

  Future<ViewerAnalyticsModel> _loadAnalyticsFallback() async {
    if (_cachedAnalytics != null) return _cachedAnalytics!;

    final rawJson = _prefs?.getString(_kAnalyticsKey);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
        _cachedAnalytics = ViewerAnalyticsModel.fromJson(decoded);
        return _cachedAnalytics!;
      } catch (e) {
        debugPrint('Error decoding cached analytics: $e');
      }
    }

    _cachedAnalytics = ViewerAnalyticsModel.createDefault();
    await _saveAnalyticsToPrefs(_cachedAnalytics!);
    return _cachedAnalytics!;
  }

  Future<void> saveAnalytics(ViewerAnalyticsModel analytics) async {
    if (_useSupabase) {
      try {
        await _client.from('platform_analytics').upsert({
          'id': true,
          ..._analyticsToRow(analytics),
        });
        _cachedAnalytics = analytics;
        return;
      } catch (e) {
        debugPrint('Supabase saveAnalytics failed, falling back: $e');
      }
    }
    _cachedAnalytics = analytics;
    await _saveAnalyticsToPrefs(analytics);
  }

  Future<void> _saveAnalyticsToPrefs(ViewerAnalyticsModel analytics) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kAnalyticsKey, jsonEncode(analytics.toJson()));
    } catch (e) {
      debugPrint('Error saving analytics to SharedPreferences: $e');
    }
  }

  Map<String, dynamic> _analyticsToRow(ViewerAnalyticsModel a) => {
        'total_guest_sessions': a.totalGuestSessions,
        'total_registered_google_users': a.totalRegisteredGoogleUsers,
        'total_lecture_bookmarks': a.totalLectureBookmarks,
        'total_auditorium_rsvps': a.totalAuditoriumRsvps,
        'total_broadcast_hours': a.totalBroadcastHours,
        'active_viewers_live': a.activeViewersLive,
        'last_refreshed': a.lastRefreshed.toIso8601String(),
      };

  ViewerAnalyticsModel _analyticsFromRow(Map<String, dynamic> row) {
    return ViewerAnalyticsModel(
      totalGuestSessions: (row['total_guest_sessions'] as num?)?.toInt() ?? 0,
      totalRegisteredGoogleUsers:
          (row['total_registered_google_users'] as num?)?.toInt() ?? 0,
      totalLectureBookmarks:
          (row['total_lecture_bookmarks'] as num?)?.toInt() ?? 0,
      totalAuditoriumRsvps: (row['total_auditorium_rsvps'] as num?)?.toInt() ?? 0,
      totalBroadcastHours:
          (row['total_broadcast_hours'] as num?)?.toDouble() ?? 0,
      activeViewersLive: (row['active_viewers_live'] as num?)?.toInt() ?? 0,
      lastRefreshed: DateTime.parse(row['last_refreshed'] as String),
    );
  }

  // ==========================================
  // Org $\leftrightarrow$ Streamer Affiliation Requests Repository
  // ==========================================

  Future<List<OrgAffiliationRequestModel>> loadAffiliationRequests({
    String? orgId,
    String? streamerId,
  }) async {
    if (_useSupabase) {
      try {
        var query = _client.from('affiliation_requests').select();
        if (_looksLikeUuid(orgId)) {
          query = query.eq('organization_id', orgId as Object);
        }
        if (_looksLikeUuid(streamerId)) {
          query = query.eq('streamer_profile_id', streamerId as Object);
        }
        final rows = await query.order('created_at', ascending: false);
        _cachedAffiliationRequests =
            await _affiliationsFromRows((rows as List).cast<Map<String, dynamic>>());
        return List.unmodifiable(_cachedAffiliationRequests);
      } catch (e) {
        debugPrint('Supabase loadAffiliationRequests failed, falling back: $e');
      }
    }
    return _loadAffiliationRequestsFallback(orgId: orgId, streamerId: streamerId);
  }

  Future<List<OrgAffiliationRequestModel>> _loadAffiliationRequestsFallback({
    String? orgId,
    String? streamerId,
  }) async {
    if (_cachedAffiliationRequests.isEmpty) {
      final rawJson = _prefs?.getString(_kAffiliationRequestsKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(rawJson);
          _cachedAffiliationRequests = decoded
              .map((item) => OrgAffiliationRequestModel.fromJson(
                  item as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('Error decoding cached affiliation requests: $e');
        }
      }
    }

    if (_cachedAffiliationRequests.isEmpty) {
      _cachedAffiliationRequests = _createInitialSeedAffiliations();
      await _saveAffiliationRequestsToPrefs();
    }

    if (orgId != null && orgId.isNotEmpty) {
      return List.unmodifiable(_cachedAffiliationRequests
          .where((r) => r.orgId == orgId)
          .toList());
    }

    if (streamerId != null && streamerId.isNotEmpty) {
      return List.unmodifiable(_cachedAffiliationRequests
          .where((r) => r.streamerId == streamerId)
          .toList());
    }

    return List.unmodifiable(_cachedAffiliationRequests);
  }

  Future<void> submitAffiliationRequest(
      OrgAffiliationRequestModel request) async {
    if (_useSupabase) {
      try {
        await _client.from('affiliation_requests').upsert({
          'id': request.id,
          'organization_id': request.orgId,
          'streamer_profile_id': request.streamerId,
          'direction': request.direction.name,
          'status': request.status.name,
          'proposed_role_en': request.proposedRoleEn,
          'proposed_role_ar': request.proposedRoleAr,
          'note': request.note,
          'permissions': request.permissions.toJson(),
          'created_at': request.createdAt.toIso8601String(),
          'resolved_at': request.resolvedAt?.toIso8601String(),
        });
        _upsertCachedAffiliation(request);
        return;
      } catch (e) {
        debugPrint('Supabase submitAffiliationRequest failed, falling back: $e');
      }
    }
    _upsertCachedAffiliation(request);
    await _saveAffiliationRequestsToPrefs();
  }

  void _upsertCachedAffiliation(OrgAffiliationRequestModel request) {
    final existingIdx =
        _cachedAffiliationRequests.indexWhere((r) => r.id == request.id);
    if (existingIdx != -1) {
      _cachedAffiliationRequests[existingIdx] = request;
    } else {
      _cachedAffiliationRequests.insert(0, request);
    }
  }

  Future<OrgAffiliationRequestModel?> updateAffiliationRequestStatus(
    String id,
    AffiliationStatus newStatus,
  ) async {
    if (_useSupabase) {
      try {
        final row = await _client
            .from('affiliation_requests')
            .update({
              'status': newStatus.name,
              'resolved_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .select()
            .single();
        final updated = (await _affiliationsFromRows([row])).first;
        _upsertCachedAffiliation(updated);
        return updated;
      } catch (e) {
        debugPrint('Supabase updateAffiliationRequestStatus failed, falling back: $e');
      }
    }

    final idx = _cachedAffiliationRequests.indexWhere((r) => r.id == id);
    if (idx == -1) return null;

    final current = _cachedAffiliationRequests[idx];
    final updated = current.copyWith(
      status: newStatus,
      resolvedAt: DateTime.now(),
    );

    _cachedAffiliationRequests[idx] = updated;
    await _saveAffiliationRequestsToPrefs();
    return updated;
  }

  Future<void> _saveAffiliationRequestsToPrefs() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final jsonList =
          _cachedAffiliationRequests.map((r) => r.toJson()).toList();
      await prefs.setString(_kAffiliationRequestsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving affiliation requests to SharedPreferences: $e');
    }
  }

  /// affiliation_requests doesn't store the org/streamer display fields
  /// OrgAffiliationRequestModel carries (they're denormalized convenience
  /// fields for the UI) -- batch-resolve them from organizations/profiles.
  Future<List<OrgAffiliationRequestModel>> _affiliationsFromRows(
      List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];

    final orgIds = rows.map((r) => r['organization_id'] as String).toSet();
    final streamerIds = rows.map((r) => r['streamer_profile_id'] as String).toSet();

    Map<String, Map<String, dynamic>> orgs = {};
    Map<String, Map<String, dynamic>> streamers = {};
    try {
      final orgRows = await _client
          .from('organizations')
          .select('id, name_en, name_ar, avatar_url')
          .inFilter('id', orgIds.toList());
      orgs = {
        for (final r in (orgRows as List))
          (r as Map<String, dynamic>)['id'] as String: r,
      };
      final profileRows = await _client
          .from('profiles')
          .select('id, display_name_en, avatar_url, email')
          .inFilter('id', streamerIds.toList());
      streamers = {
        for (final r in (profileRows as List))
          (r as Map<String, dynamic>)['id'] as String: r,
      };
    } catch (e) {
      debugPrint('Failed to resolve affiliation request display fields: $e');
    }

    return rows.map((row) {
      final org = orgs[row['organization_id']];
      final streamer = streamers[row['streamer_profile_id']];
      return OrgAffiliationRequestModel(
        id: row['id'] as String,
        orgId: row['organization_id'] as String,
        orgNameEn: org?['name_en'] as String? ?? '',
        orgNameAr: org?['name_ar'] as String? ?? '',
        orgAvatarUrl: org?['avatar_url'] as String? ?? '',
        streamerId: row['streamer_profile_id'] as String,
        streamerNameEn: streamer?['display_name_en'] as String? ?? '',
        streamerNameAr: streamer?['display_name_en'] as String? ?? '',
        streamerAvatarUrl: streamer?['avatar_url'] as String? ?? '',
        streamerEmail: streamer?['email'] as String? ?? '',
        proposedRoleEn: row['proposed_role_en'] as String?,
        proposedRoleAr: row['proposed_role_ar'] as String?,
        note: row['note'] as String? ?? '',
        direction: AffiliationDirection.values.byName(row['direction'] as String),
        status: AffiliationStatus.values.byName(row['status'] as String),
        permissions: row['permissions'] != null
            ? OrgBroadcasterPermissions.fromJson(
                row['permissions'] as Map<String, dynamic>)
            : const OrgBroadcasterPermissions(),
        createdAt: DateTime.parse(row['created_at'] as String),
        resolvedAt: row['resolved_at'] != null
            ? DateTime.parse(row['resolved_at'] as String)
            : null,
      );
    }).toList();
  }

  List<OrgAffiliationRequestModel> _createInitialSeedAffiliations() {
    return [
      OrgAffiliationRequestModel(
        id: 'aff_req_001',
        orgId: 'org_dalilk_04',
        orgNameEn: 'Dalilk 4 IELTS Academy',
        orgNameAr: 'أكاديمية دليل الآيلتس',
        orgAvatarUrl: 'assets/images/Dalilak/OrgMainProfile.jpg',
        streamerId: 'prof_alghamdi_01',
        streamerNameEn: 'Amir Al-Hatemi',
        streamerNameAr: 'أمير الحاتمي',
        streamerAvatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        streamerEmail: 'amir.alhatemi@gmail.com',
        proposedRoleEn: 'AI & Educational Technology Guest Lecturer',
        proposedRoleAr: 'محاضر زائر في الذكاء الاصطناعي والتقنيات التعليمية',
        note: 'Honored to collaborate on IELTS technology seminars and digital speaking workshops.',
        direction: AffiliationDirection.streamerToOrg,
        status: AffiliationStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];
  }

  // ==========================================
  // Initial Seed Applications & Audit Logs
  // ==========================================

  List<BroadcasterApplicationModel> _createInitialSeedApplications() {
    return [
      BroadcasterApplicationModel(
        id: 'app_kfupm_ai_01',
        accountType: ApplicationAccountType.organizationVenue,
        applicantNameEn: 'KFUPM AI & Robotics Research Center',
        applicantNameAr: 'مركز بحوث الذكاء الاصطناعي والروبوتات بجامعة الملك فهد',
        email: 'ai.center@kfupm.edu.sa',
        phone: '+966 13 860 0000',
        academicTitleEn: 'Research Institution & Venue',
        academicTitleAr: 'مؤسسة بحثية وقاعة فعاليات',
        institutionEn: 'King Fahd University of Petroleum & Minerals',
        institutionAr: 'جامعة الملك فهد للبترول والمعادن',
        categoryId: 'cs_tech',
        tags: const ['#AI', '#Robotics', '#KFUPM', '#Academic'],
        organizationType: 'University Research Center & Auditorium',
        venueNameEn: 'KFUPM Building 24 Grand Auditorium',
        venueNameAr: 'جامعة الملك فهد - مدرج مبنى 24 الرئيسي',
        latitude: 26.3050,
        longitude: 50.1450,
        seatingCapacity: 450,
        officialWebsiteUrl: 'https://kfupm.edu.sa/ai-center',
        youtubeChannelUrl: 'https://youtube.com/@kfupm_ai_center',
        youtubeHandle: 'kfupm_ai_center',
        bioEn:
            'Leading academic hub for advanced artificial intelligence, machine learning seminars, and autonomous systems research in the Eastern Province.',
        bioAr:
            'المركز الأكاديمي الرائد لأبحاث الذكاء الاصطناعي، والتعلم الآلي، والندوات العلمية للأنظمة الذكية في المنطقة الشرقية.',
        avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        bannerUrl: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      BroadcasterApplicationModel(
        id: 'app_dr_tariq_02',
        accountType: ApplicationAccountType.individualScholar,
        applicantNameEn: 'Dr. Tariq Al-Mansoor',
        applicantNameAr: 'د. طارق المنصور',
        email: 'tariq.mansoor@iau.edu.sa',
        phone: '+966 50 123 4567',
        academicTitleEn: 'Associate Professor of Clinical Medicine',
        academicTitleAr: 'أستاذ مشارك في الطب الباطني والجراحة',
        institutionEn: 'Imam Abdulrahman Bin Faisal University',
        institutionAr: 'جامعة الإمام عبدالرحمن بن فيصل',
        categoryId: 'medical_health',
        tags: const ['#Medicine', '#Cardiology', '#HealthScience'],
        venueNameEn: 'King Fahd Hospital University Auditorium',
        venueNameAr: 'مستشفى الملك فهد الجامعي - القاعة الكبرى',
        latitude: 26.4207,
        longitude: 50.0888,
        youtubeChannelUrl: 'https://youtube.com/@dr_tariq_medicine',
        youtubeHandle: 'dr_tariq_medicine',
        bioEn:
            'Consultant and academic lecturer specializing in internal medicine, public health informatics, and clinical medical conferences.',
        bioAr:
            'استشاري ومحاضر أكاديمي متخصص في الطب الباطني، ونظم المعلوماتية الصحية، والمؤتمرات الطبية السريرية.',
        avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        bannerUrl: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  List<OrgAuditLogEntry> _createInitialSeedAuditLogs() {
    return [
      OrgAuditLogEntry(
        logId: 'audit_dalilk_001',
        organizationId: 'org_dalilk_04',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        actorEmail: 'amir.alhatemi@gmail.com',
        actorName: 'Amir Al-Hatemi (Super Admin)',
        action: OrgAuditAction.createOrganization,
        descriptionEn: 'Verified and approved Dalilk 4 IELTS academic organization workspace.',
        descriptionAr: 'تم اعتماد وتوثيق مساحة عمل أكاديمية دليل الآيلتس التعليمية.',
        metadata: const {
          'org_id': 'org_dalilk_04',
          'youtube_handle': 'dalilk4ielts',
        },
      ),
      OrgAuditLogEntry(
        logId: 'audit_dalilk_002',
        organizationId: 'org_dalilk_04',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        actorEmail: 'abdulrahman@dalilk.com',
        actorName: 'Abdulrahman Hejazi (Owner)',
        action: OrgAuditAction.addSpeakerToRoster,
        descriptionEn: 'Added Dr. Sarah Al-Dosari to Dalilk 4 IELTS speaker roster with broadcast permissions.',
        descriptionAr: 'تمت إضافة د. سارة الدوسري إلى قائمة مدربي دليل الآيلتس مع صلاحيات البث المباشر.',
        metadata: const {
          'speaker_id': 'spk_sarah',
          'role': 'Senior IELTS Speaking & Writing Specialist',
        },
      ),
      OrgAuditLogEntry(
        logId: 'audit_dalilk_003',
        organizationId: 'org_dalilk_04',
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
        actorEmail: 'abdulrahman@dalilk.com',
        actorName: 'Abdulrahman Hejazi (Owner)',
        action: OrgAuditAction.addVenueBranch,
        descriptionEn: 'Added Dhahran Tech Innovation Hall and Dammam Executive Training Suite campus branches.',
        descriptionAr: 'تمت إضافة فرعي قاعة الابتكار بالظهران وجناح التدريب التنفيذي بالدمام.',
        metadata: const {
          'branches': ['dalilk_branch_dhahran', 'dalilk_branch_dammam'],
        },
      ),
    ];
  }

  // ==========================================
  // Organization Venues & Speakers Repository (Checkpoint 3 Phase 2)
  //
  // No SharedPreferences fallback here -- unlike the domains above, this
  // data never had a persistence layer before (it lived purely in the mock
  // _streamers list). Callers (AppProvider) keep mutating that mock list
  // as their own fallback and treat these as best-effort write-throughs:
  // every method throws on failure (Supabase unavailable, or an orgId that
  // isn't a real organizations.id yet) instead of silently no-op'ing, so
  // the caller's existing try/catch decides what "fallback" means for it.
  // ==========================================

  Future<List<OrgVenueBranchModel>> loadOrgVenues(String orgId) async {
    if (!_useSupabase || !_looksLikeUuid(orgId)) return const [];
    final rows = await _client
        .from('org_venues')
        .select()
        .eq('organization_id', orgId)
        .order('created_at');
    return rows.map(_venueFromRow).toList();
  }

  Future<List<OrgSpeakerModel>> loadOrgSpeakers(String orgId) async {
    if (!_useSupabase || !_looksLikeUuid(orgId)) return const [];
    final rows = await _client
        .from('org_speakers')
        .select()
        .eq('organization_id', orgId)
        .order('created_at');
    return rows.map(_speakerFromRow).toList();
  }

  Future<void> upsertOrgVenue(String orgId, OrgVenueBranchModel venue) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('org_venues').upsert({
      'id': venue.venueId,
      'organization_id': orgId,
      ..._venueToRow(venue),
    });
  }

  Future<void> deleteOrgVenue(String venueId) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('org_venues').delete().eq('id', venueId);
  }

  Future<void> upsertOrgSpeaker(String orgId, OrgSpeakerModel speaker) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('org_speakers').upsert({
      'id': speaker.speakerId,
      'organization_id': orgId,
      ..._speakerToRow(speaker),
    });
  }

  Future<void> deleteOrgSpeaker(String speakerId) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('org_speakers').delete().eq('id', speakerId);
  }

  Map<String, dynamic> _venueToRow(OrgVenueBranchModel v) => {
        'name_en': v.nameEn,
        'name_ar': v.nameAr,
        'city_en': v.cityEn,
        'city_ar': v.cityAr,
        'latitude': v.latitude,
        'longitude': v.longitude,
        'seating_capacity': v.seatingCapacity,
        'is_main_headquarters': v.isMainHeadquarters,
        'room_number_or_hall': v.roomNumberOrHall,
        'available_facilities': v.availableFacilities,
        'address_en': v.addressEn,
        'address_ar': v.addressAr,
      };

  OrgVenueBranchModel _venueFromRow(Map<String, dynamic> row) =>
      OrgVenueBranchModel(
        venueId: row['id'] as String,
        nameEn: row['name_en'] as String,
        nameAr: row['name_ar'] as String,
        cityEn: row['city_en'] as String,
        cityAr: row['city_ar'] as String,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        seatingCapacity: (row['seating_capacity'] as num?)?.toInt() ?? 100,
        isMainHeadquarters: row['is_main_headquarters'] as bool? ?? false,
        roomNumberOrHall: row['room_number_or_hall'] as String?,
        availableFacilities:
            List<String>.from(row['available_facilities'] as List? ?? const []),
        addressEn: row['address_en'] as String?,
        addressAr: row['address_ar'] as String?,
      );

  Map<String, dynamic> _speakerToRow(OrgSpeakerModel s) => {
        'name_en': s.nameEn,
        'name_ar': s.nameAr,
        'role_or_title_en': s.roleOrTitleEn,
        'role_or_title_ar': s.roleOrTitleAr,
        'avatar_url': s.avatarUrl,
        'bio_en': s.bioEn,
        'bio_ar': s.bioAr,
        'is_permanent_staff': s.isPermanentStaff,
        'linked_email': s.linkedEmail,
        'youtube_handle': s.youtubeHandle,
        'permissions': s.permissions.toJson(),
      };

  OrgSpeakerModel _speakerFromRow(Map<String, dynamic> row) => OrgSpeakerModel(
        speakerId: row['id'] as String,
        nameEn: row['name_en'] as String,
        nameAr: row['name_ar'] as String,
        roleOrTitleEn: row['role_or_title_en'] as String,
        roleOrTitleAr: row['role_or_title_ar'] as String,
        avatarUrl: row['avatar_url'] as String? ?? '',
        bioEn: row['bio_en'] as String? ?? '',
        bioAr: row['bio_ar'] as String? ?? '',
        isPermanentStaff: row['is_permanent_staff'] as bool? ?? true,
        linkedEmail: row['linked_email'] as String?,
        youtubeHandle: row['youtube_handle'] as String?,
        permissions: row['permissions'] != null
            ? OrgBroadcasterPermissions.fromJson(
                row['permissions'] as Map<String, dynamic>)
            : const OrgBroadcasterPermissions(),
      );

  // ==========================================
  // Permitted Admin org scoping (v0.8 Checkpoint 3 Phase 1)
  // ==========================================

  /// organization_id(s) the signed-in user is org_owner/org_co_owner for --
  /// RLS (user_roles_select_own_or_admin) already lets any signed-in user
  /// read their own rows, no admin tier required, so this is a plain filtered
  /// select rather than a SECURITY DEFINER RPC.
  Future<List<String>> loadPermittedAdminOrgIds() async {
    if (!_useSupabase) return const [];
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('user_roles')
        .select('organization_id')
        .eq('profile_id', userId)
        .inFilter('role', ['org_owner', 'org_co_owner']);
    return rows
        .map((r) => r['organization_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
  }

  /// Core organizations row for orgId, for seeding a StreamerModel when the
  /// org isn't already in AppProvider's in-memory _streamers list (true for
  /// any real org on a fresh session -- _streamers only gets a real org
  /// appended at the moment its application is approved, in that same
  /// session; nothing bulk-loads every real organization on app start).
  Future<Map<String, dynamic>?> loadOrganizationProfile(String orgId) async {
    if (!_useSupabase || !_looksLikeUuid(orgId)) return null;
    return await _client
        .from('organizations')
        .select()
        .eq('id', orgId)
        .maybeSingle();
  }

  // ==========================================
  // Real organization/profile creation on application approval
  // (Checkpoint 3 Phase 2)
  // ==========================================

  /// Creates a real organizations row for an approved org-type application,
  /// owned by the applicant. Returns the new organization's real id.
  Future<String> createOrganizationFromApplication(
    BroadcasterApplicationModel app,
    String ownerProfileId,
  ) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final row = await _client.from('organizations').insert({
      'owner_profile_id': ownerProfileId,
      'name_en': app.applicantNameEn,
      'name_ar': app.applicantNameAr,
      'avatar_url': app.avatarUrl,
      'banner_url': app.bannerUrl,
      'bio_en': app.bioEn,
      'bio_ar': app.bioAr,
      'category_id': app.categoryId,
      'tags': app.tags,
      'official_website_url': app.officialWebsiteUrl,
      'youtube_handle': app.youtubeHandle,
      'is_verified': true,
    }).select('id').single();
    return row['id'] as String;
  }

  /// Marks the applicant's own profile as a verified individual streamer.
  Future<void> markProfileAsStreamer(
    String profileId,
    BroadcasterApplicationModel app,
  ) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('profiles').update({
      'is_streamer': true,
      'is_verified': true,
      'title_en': app.academicTitleEn,
      'title_ar': app.academicTitleAr,
      'category_id': app.categoryId,
      'tags': app.tags,
      'venue_name_en': app.venueNameEn,
      'venue_name_ar': app.venueNameAr,
      'latitude': app.latitude,
      'longitude': app.longitude,
      'youtube_handle': app.youtubeHandle,
      'bio_en': app.bioEn,
      'bio_ar': app.bioAr,
      'avatar_url': app.avatarUrl,
      'banner_url': app.bannerUrl,
    }).eq('id', profileId);
  }

  // ==========================================
  // Role & Permission Management (v0.8 Checkpoint 2 Phase 3)
  //
  // user_roles/user_permissions are real-backend-only, same as
  // org_venues/org_speakers above -- no SharedPreferences fallback. This
  // screen's entire purpose is administering the real RLS-backed source of
  // truth from Checkpoint 1; a fake local fallback that let you "promote"
  // someone without touching Supabase would be actively misleading rather
  // than a graceful degradation. Every method here returns empty/no-ops (or
  // throws for writes) when Supabase isn't available, same contract as
  // loadOrgVenues/upsertOrgVenue.
  // ==========================================

  /// All user_roles rows (any tier), joined with display info. Master Admin
  /// only in practice -- the UI that calls this gates on isMasterAdmin -- but
  /// RLS already allows any admin-tier account to SELECT every row.
  Future<List<AdminRoleAssignmentModel>> loadAdminRoleAssignments() async {
    if (!_useSupabase) return const [];
    final rows = await _client
        .from('user_roles')
        .select()
        .order('granted_at', ascending: false);
    final profiles = await _resolveProfileSummaries(
      rows.map((r) => r['profile_id'] as String?),
    );
    return rows.map((row) {
      final profile = profiles[row['profile_id'] as String];
      return AdminRoleAssignmentModel(
        profileId: row['profile_id'] as String,
        role: row['role'] as String,
        organizationId: row['organization_id'] as String?,
        grantedBy: row['granted_by'] as String?,
        grantedAt: DateTime.parse(row['granted_at'] as String),
        displayName: profile?['display_name_en'] as String? ??
            profile?['email'] as String? ??
            'Unknown user',
        email: profile?['email'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
      );
    }).toList();
  }

  /// All granted capability checkboxes, keyed by profile_id -> set of
  /// permission_key. organization_id-scoped grants are included by key only
  /// (this screen manages platform-wide grants; org-scoped grants are
  /// Checkpoint 3's org-scoped surface).
  Future<Map<String, Set<String>>> loadUserPermissionsByProfile() async {
    if (!_useSupabase) return const {};
    final rows = await _client.from('user_permissions').select();
    final result = <String, Set<String>>{};
    for (final row in rows) {
      final profileId = row['profile_id'] as String;
      (result[profileId] ??= {}).add(row['permission_key'] as String);
    }
    return result;
  }

  /// Looks up a profile by exact email for the "grant a role" search field.
  Future<Map<String, dynamic>?> findProfileByEmail(String email) async {
    if (!_useSupabase) return null;
    return await _client
        .from('profiles')
        .select('id, email, display_name_en, avatar_url')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
  }

  Future<Map<String, Map<String, dynamic>>> _resolveProfileSummaries(
    Iterable<String?> ids,
  ) async {
    final uniqueIds = ids.whereType<String>().toSet();
    if (uniqueIds.isEmpty) return {};
    final rows = await _client
        .from('profiles')
        .select('id, display_name_en, email, avatar_url')
        .inFilter('id', uniqueIds.toList());
    return {
      for (final row in rows) row['id'] as String: row,
    };
  }

  /// Grants profileId the given platform-wide role (master_admin/admin) or
  /// org-scoped role (org_owner/org_co_owner, requires organizationId).
  /// granted_by is always the caller's own id -- RLS's with-check requires
  /// granted_by = auth.uid() (see 20260827090000) -- so this resolves it
  /// from the live session rather than trusting a caller-supplied value.
  Future<void> grantUserRole({
    required String profileId,
    required String role,
    String? organizationId,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final grantedBy = _client.auth.currentUser?.id;
    if (grantedBy == null) throw Exception('Not signed in.');
    await _client.from('user_roles').upsert(
      {
        'profile_id': profileId,
        'role': role,
        'organization_id': organizationId,
        'granted_by': grantedBy,
      },
      onConflict: 'profile_id,role,organization_id',
    );
  }

  Future<void> revokeUserRole({
    required String profileId,
    required String role,
    String? organizationId,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    if (organizationId != null) {
      await _client
          .from('user_roles')
          .delete()
          .eq('profile_id', profileId)
          .eq('role', role)
          .eq('organization_id', organizationId);
    } else {
      await _client
          .from('user_roles')
          .delete()
          .eq('profile_id', profileId)
          .eq('role', role)
          .isFilter('organization_id', null);
    }
  }

  /// Toggles one platform-wide capability checkbox for profileId. Master
  /// Admin only at the RLS layer (20260827100000).
  Future<void> setUserPermission({
    required String profileId,
    required String capability,
    required bool granted,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    if (granted) {
      final grantedBy = _client.auth.currentUser?.id;
      if (grantedBy == null) throw Exception('Not signed in.');
      await _client.from('user_permissions').upsert(
        {
          'profile_id': profileId,
          'permission_key': capability,
          'organization_id': null,
          'granted_by': grantedBy,
        },
        onConflict: 'profile_id,permission_key,organization_id',
      );
    } else {
      await _client
          .from('user_permissions')
          .delete()
          .eq('profile_id', profileId)
          .eq('permission_key', capability)
          .isFilter('organization_id', null);
    }
  }

  // ==========================================
  // Chat Moderation Dashboard (v0.8 Checkpoint 4 Phase 1)
  //
  // Real-backend-only, same contract as the org/role management sections
  // above -- chat_reports/chat_messages/chat_muted_users are v0.6 tables
  // with no SharedPreferences shape, and this dashboard's whole point is
  // acting on the real RLS-backed moderation queue.
  // ==========================================

  /// Every open chat_reports row, joined with the reported message's body
  /// and both parties' display info. Admin-tier only at the RLS layer
  /// (chat_reports_select_admin, 20260824090000) -- a non-admin caller
  /// would just get an empty list back, not an error.
  Future<List<ChatReportModel>> loadChatReports() async {
    if (!_useSupabase) return const [];
    final reportRows = await _client
        .from('chat_reports')
        .select()
        .order('created_at', ascending: false);
    if (reportRows.isEmpty) return const [];

    final messageIds =
        reportRows.map((r) => r['message_id'] as String).toSet().toList();
    final messageRows = await _client
        .from('chat_messages')
        .select('id, body')
        .inFilter('id', messageIds);
    final bodiesById = {
      for (final m in messageRows) m['id'] as String: m['body'] as String,
    };

    final profileIds = <String?>{};
    for (final r in reportRows) {
      profileIds.add(r['reporter_id'] as String?);
      profileIds.add(r['reported_sender_id'] as String?);
    }
    final profiles = await _resolveProfileSummaries(profileIds);

    return reportRows.map((row) {
      final reporter = profiles[row['reporter_id'] as String];
      final reported = profiles[row['reported_sender_id'] as String];
      return ChatReportModel(
        id: row['id'] as String,
        messageId: row['message_id'] as String,
        streamId: row['stream_id'] as String,
        reportedSenderId: row['reported_sender_id'] as String,
        reporterId: row['reporter_id'] as String,
        reason: row['reason'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        messageBody:
            bodiesById[row['message_id'] as String] ?? '(message unavailable)',
        reporterDisplayName: reporter?['display_name_en'] as String? ??
            reporter?['email'] as String? ??
            'Unknown user',
        reporterEmail: reporter?['email'] as String?,
        reportedDisplayName: reported?['display_name_en'] as String? ??
            reported?['email'] as String? ??
            'Unknown user',
        reportedEmail: reported?['email'] as String?,
      );
    }).toList();
  }

  /// Dismisses a report with no other action -- just removes it from the
  /// queue (chat_reports_delete_admin, 20260827120000).
  Future<void> dismissChatReport(String reportId) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('chat_reports').delete().eq('id', reportId);
  }

  /// Deletes the reported message (propagates to every viewer's live chat
  /// via the chat_messages postgres_changes DELETE event -- see
  /// LiveChatController._handleDelete, no separate broadcast needed) and
  /// resolves this report. The FK cascade on chat_reports.message_id
  /// already removes every report referencing this message, including this
  /// one -- the explicit delete-by-id below is just so a caller doesn't
  /// need to know that detail, and is a no-op if the cascade beat it to it.
  Future<void> deleteChatMessageAndResolveReport({
    required String messageId,
    required String reportId,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('chat_messages').delete().eq('id', messageId);
    await _client.from('chat_reports').delete().eq('id', reportId);
  }

  /// Mutes/bans the reported sender from this one stream's chat (server-
  /// enforced via chat_muted_users + the chat_messages insert policy that
  /// rejects muted senders, not just a client-side gate) and resolves this
  /// report. A duplicate mute (sender already muted on this stream) is
  /// swallowed as a success -- the desired end state ("sender can't post
  /// here") already holds.
  Future<void> muteChatSenderAndResolveReport({
    required String streamId,
    required String senderId,
    required String reportId,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final mutedBy = _client.auth.currentUser?.id;
    if (mutedBy == null) throw Exception('Not signed in.');
    try {
      await _client.from('chat_muted_users').insert({
        'stream_id': streamId,
        'muted_profile_id': senderId,
        'muted_by': mutedBy,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // 23505 = unique_violation
    }
    await _client.from('chat_reports').delete().eq('id', reportId);
  }
}
