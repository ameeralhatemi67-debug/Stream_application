import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/admin/models/broadcaster_application_model.dart';
import '../../features/admin/models/terms_and_conditions_model.dart';
import '../../features/admin/models/viewer_analytics_model.dart';
import '../../features/admin/models/admin_role_assignment_model.dart';
import '../../features/admin/models/chat_report_model.dart';
import '../../features/admin/models/chat_mute_audit_entry.dart';
import '../../features/admin/models/streamer_custom_placeholder_model.dart';
import '../../features/admin/models/banned_user_model.dart';
import '../../features/admin/models/stream_moderator_model.dart';
import '../../features/admin/models/tag_moderation_model.dart';
import '../../features/discovery/models/academic_category_model.dart';
import '../models/device_session_model.dart';
import 'streamer_asset_path.dart';
import '../../features/organization/models/org_audit_log_entry.dart';
import '../../features/organization/models/org_affiliation_request_model.dart';
import '../../features/organization/models/org_broadcaster_permissions.dart';
import '../../features/organization/models/org_venue_branch_model.dart';
import '../../features/organization/models/org_speaker_model.dart';
import '../../features/profile/models/streamer_models.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
bool _looksLikeUuid(String? value) =>
    value != null && _uuidPattern.hasMatch(value);

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
        _cachedApplications =
            rows.map((r) => _applicationFromRow(r, reviewerNames)).toList();
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
            .map((item) => BroadcasterApplicationModel.fromJson(
                item as Map<String, dynamic>))
            .toList();
        return List.unmodifiable(_cachedApplications);
      } catch (e) {
        debugPrint('Error decoding cached applications: $e');
      }
    }

    // No seeded applications: the review queue shows only real submissions
    // (P1.6 dev identity, P2 truthful data). An empty queue is the truthful
    // state for a backend with nothing pending.
    return List.unmodifiable(_cachedApplications);
  }

  /// Uploads binary image bytes to the Supabase Storage 'streamer-assets' bucket
  /// and returns the public CDN URL. Falls back to null if offline.
  Future<String?> uploadStreamerAsset({
    required String fileName,
    required Uint8List fileBytes,
    String contentType = 'image/jpeg',
    String folder = 'applications',
  }) async {
    if (!_useSupabase) return null;
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final path = streamerAssetPath(
        userId: userId,
        folder: folder,
        fileName: fileName,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await _client.storage.from('streamer-assets').uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final publicUrl =
          _client.storage.from('streamer-assets').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('uploadStreamerAsset failed: $e');
      return null;
    }
  }

  Future<void> submitApplication(
      BroadcasterApplicationModel application) async {
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

        final reviewerNames =
            await _resolveDisplayNames([row['reviewed_by'] as String?]);
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

  Future<BroadcasterApplicationModel?> loadMyApplication(
      String profileId) async {
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
    if (_useSupabase) {
      try {
        final cleanId =
            streamerIdOrProfileId.replaceFirst('streamer_', '').trim();
        if (_looksLikeUuid(cleanId)) {
          await _client.from('profiles').update({
            'is_streamer': false,
            'is_verified': false,
          }).eq('id', cleanId);

          await _client.from('broadcaster_applications').update({
            'status': 'rejected',
            'admin_review_notes':
                'Streamer privileges revoked by administration.',
          }).eq('applicant_profile_id', cleanId);

          try {
            await _client
                .from('organizations')
                .delete()
                .eq('owner_profile_id', cleanId);
            await _client.from('organizations').delete().eq('id', cleanId);
          } catch (_) {}
        } else {
          final appRow = await _client
              .from('broadcaster_applications')
              .select('id, applicant_profile_id')
              .or('id.eq.$cleanId,applicant_profile_id.eq.$cleanId')
              .maybeSingle();

          final applicantProfileId = appRow?['applicant_profile_id'] as String?;
          final actualAppId = appRow?['id'] as String? ?? cleanId;

          if (applicantProfileId != null &&
              _looksLikeUuid(applicantProfileId)) {
            await _client.from('profiles').update({
              'is_streamer': false,
              'is_verified': false,
            }).eq('id', applicantProfileId);

            await _client.from('broadcaster_applications').update({
              'status': 'rejected',
              'admin_review_notes':
                  'Streamer privileges revoked by administration.',
            }).eq('id', actualAppId);

            try {
              await _client
                  .from('organizations')
                  .delete()
                  .eq('owner_profile_id', applicantProfileId);
            } catch (_) {}
          }

          try {
            await _client.from('organizations').delete().eq('id', cleanId);
          } catch (_) {}
        }
        return true;
      } catch (e) {
        debugPrint('Supabase revokeStreamer failed: $e');
        return false;
      }
    }

    _cachedApplications.removeWhere((a) =>
        a.id == streamerIdOrProfileId ||
        a.applicantProfileId == streamerIdOrProfileId ||
        'streamer_${a.id}' == streamerIdOrProfileId);
    await _saveApplicationsToPrefs();
    return true;
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

          try {
            await _client
                .from('organizations')
                .delete()
                .eq('owner_profile_id', applicantId);
          } catch (_) {}
        }

        _cachedApplications.removeWhere((a) => a.id == id);
        await _saveApplicationsToPrefs();
        if (applicantId != null) {
          await _broadcastStreamerDeleted(applicantId);
        }
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
  Future<Map<String, String>> _resolveDisplayNames(
      Iterable<String?> ids) async {
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
        _cachedAuditLogs = (rows as List)
            .map((r) => _auditLogFromRow(r as Map<String, dynamic>))
            .toList();
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
          'p_organization_id': _looksLikeUuid(entry.organizationId)
              ? entry.organizationId
              : null,
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
      broadcasterGuidelinesEn:
          row['broadcaster_guidelines_en'] as String? ?? '',
      broadcasterGuidelinesAr:
          row['broadcaster_guidelines_ar'] as String? ?? '',
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
      totalAuditoriumRsvps:
          (row['total_auditorium_rsvps'] as num?)?.toInt() ?? 0,
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
        _cachedAffiliationRequests = await _affiliationsFromRows(
            (rows as List).cast<Map<String, dynamic>>());
        return List.unmodifiable(_cachedAffiliationRequests);
      } catch (e) {
        debugPrint('Supabase loadAffiliationRequests failed, falling back: $e');
      }
    }
    return _loadAffiliationRequestsFallback(
        orgId: orgId, streamerId: streamerId);
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

    if (orgId != null && orgId.isNotEmpty) {
      return List.unmodifiable(
          _cachedAffiliationRequests.where((r) => r.orgId == orgId).toList());
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
        debugPrint(
            'Supabase submitAffiliationRequest failed, falling back: $e');
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
        debugPrint(
            'Supabase updateAffiliationRequestStatus failed, falling back: $e');
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
    final streamerIds =
        rows.map((r) => r['streamer_profile_id'] as String).toSet();

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
        direction:
            AffiliationDirection.values.byName(row['direction'] as String),
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
    final row = await _client
        .from('organizations')
        .insert({
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
        })
        .select('id')
        .single();
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

  /// Fetches all verified broadcasters and organizations from Supabase public views/tables.
  /// Used to populate Discovery feed and Spatial Map on cold-start and sync across devices.
  Future<List<StreamerModel>> loadVerifiedStreamersFromBackend() async {
    if (!_useSupabase) return const [];
    final List<StreamerModel> results = [];

    // 1. Fetch verified individual scholars from streamer_public_profiles
    try {
      final streamerRows = await _client
          .from('streamer_public_profiles')
          .select()
          .order('display_name_en', ascending: true);

      for (final row in streamerRows) {
        final id = row['id'] as String;
        final nameEn =
            (row['display_name_en'] as String?) ?? 'Academic Scholar';
        final nameAr = (row['display_name_ar'] as String?) ?? nameEn;
        // Backend nulls stay empty: a missing field is a missing field, not
        // a borrowed photo, a borrowed channel or an assumed verification
        // (P2 truthful data). The UI renders placeholders for empty values.
        final avatar = (row['avatar_url'] as String?) ?? '';
        final banner = (row['banner_url'] as String?) ?? '';
        final bioEn = (row['bio_en'] as String?) ?? '';
        final bioAr = (row['bio_ar'] as String?) ?? '';
        final titleEn = (row['title_en'] as String?) ?? '';
        final titleAr = (row['title_ar'] as String?) ?? '';
        final categoryId = (row['category_id'] as String?) ?? 'general_edu';
        final tagsList = (row['tags'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            const <String>[];
        final cityEn = (row['city_en'] as String?) ?? '';
        final cityAr = (row['city_ar'] as String?) ?? '';
        final venueEn = (row['venue_name_en'] as String?) ?? '';
        final venueAr = (row['venue_name_ar'] as String?) ?? '';
        // 0/0 means "no venue coordinates"; the map skips those markers
        // rather than dropping a pin on a location nobody gave us.
        final lat = (row['latitude'] as num?)?.toDouble() ?? 0;
        final lng = (row['longitude'] as num?)?.toDouble() ?? 0;
        final ytHandle = (row['youtube_handle'] as String?) ?? '';
        final ytVideoId = (row['youtube_video_id'] as String?) ?? '';
        final isLive = (row['is_currently_live'] as bool?) ?? false;
        final isVerified = (row['is_verified'] as bool?) ?? false;
        final followerCount = (row['follower_count'] as num?)?.toInt() ?? 0;

        results.add(
          StreamerModel(
            streamerId: id,
            fullNameEn: nameEn,
            fullNameAr: nameAr,
            titleEn: titleEn,
            titleAr: titleAr,
            organizationEn: 'Independent Broadcaster',
            organizationAr: 'بث أكاديمي مستقل',
            avatarUrl: avatar,
            bannerUrl: banner,
            bioEn: bioEn,
            bioAr: bioAr,
            isVerified: isVerified,
            followerCount: followerCount,
            categoryId: categoryId,
            tags: tagsList,
            cityEn: cityEn,
            cityAr: cityAr,
            venueNameEn: venueEn,
            venueNameAr: venueAr,
            latitude: lat,
            longitude: lng,
            isCurrentlyLive: isLive,
            broadcastType:
                isLive ? BroadcastType.liveAudio : BroadcastType.offline,
            isOrganization: false,
            youtubeHandle: ytHandle,
            youtubeVideoId: ytVideoId,
            isTemporarilyHiddenFromMap:
                (row['is_temporarily_hidden_from_map'] as bool?) ?? false,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading streamer_public_profiles: $e');
    }

    // 2. Fetch verified organizations from organization_public_profiles
    try {
      final orgRows = await _client
          .from('organization_public_profiles')
          .select()
          .order('name_en', ascending: true);

      for (final row in orgRows) {
        final id = row['id'] as String;
        final nameEn =
            (row['name_en'] as String?) ?? 'Educational Organization';
        final nameAr = (row['name_ar'] as String?) ?? nameEn;
        final avatar = (row['avatar_url'] as String?) ?? '';
        final banner = (row['banner_url'] as String?) ?? '';
        final bioEn = (row['bio_en'] as String?) ?? '';
        final bioAr = (row['bio_ar'] as String?) ?? '';
        final categoryId = (row['category_id'] as String?) ?? 'general_edu';
        final tagsList = (row['tags'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            const <String>[];
        final ytHandle = (row['youtube_handle'] as String?) ?? '';
        final ytVideoId = (row['youtube_video_id'] as String?) ?? '';
        final isLive = (row['is_currently_live'] as bool?) ?? false;
        final isVerified = (row['is_verified'] as bool?) ?? false;
        final followerCount = (row['follower_count'] as num?)?.toInt() ?? 0;

        results.add(
          StreamerModel(
            streamerId: id,
            fullNameEn: nameEn,
            fullNameAr: nameAr,
            titleEn: 'Educational Academy & Venue',
            titleAr: 'مؤسسة تعليمية وقاعة',
            organizationEn: nameEn,
            organizationAr: nameAr,
            avatarUrl: avatar,
            bannerUrl: banner,
            bioEn: bioEn,
            bioAr: bioAr,
            isVerified: isVerified,
            followerCount: followerCount,
            categoryId: categoryId,
            tags: tagsList,
            cityEn: 'Al Khobar',
            cityAr: 'الخبر',
            venueNameEn: nameEn,
            venueNameAr: nameAr,
            latitude: 26.2871,
            longitude: 50.2125,
            isCurrentlyLive: isLive,
            broadcastType:
                isLive ? BroadcastType.liveAudio : BroadcastType.offline,
            isOrganization: true,
            youtubeHandle: ytHandle,
            youtubeVideoId: ytVideoId,
            isTemporarilyHiddenFromMap:
                (row['is_temporarily_hidden_from_map'] as bool?) ?? false,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading organization_public_profiles: $e');
    }

    return results;
  }

  /// Toggles Cluster 4 Task 18's "Hide from Map" flag for a streamer or
  /// organization -- admin-tier only at the RLS layer (profiles_update_admin
  /// / organizations_update_owner_or_admin, both already existing). Which
  /// table to update depends on whether this streamer id is an organization
  /// or an individual profile.
  Future<void> setStreamerHiddenFromMap({
    required String streamerId,
    required bool isOrganization,
    required bool hidden,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final table = isOrganization ? 'organizations' : 'profiles';
    await _client.from(table).update(
        {'is_temporarily_hidden_from_map': hidden}).eq('id', streamerId);
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
  /// here") already holds. [muteDurationHours] null means permanent
  /// (Cluster 4 Task 14's 10 min / 1 hour / permanent options).
  Future<void> muteChatSenderAndResolveReport({
    required String streamId,
    required String senderId,
    required String reportId,
    double? muteDurationHours,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final mutedBy = _client.auth.currentUser?.id;
    if (mutedBy == null) throw Exception('Not signed in.');
    final expiresAt = muteDurationHours == null
        ? null
        : DateTime.now()
            .add(Duration(minutes: (muteDurationHours * 60).round()))
            .toIso8601String();
    try {
      await _client.from('chat_muted_users').insert({
        'stream_id': streamId,
        'muted_profile_id': senderId,
        'muted_by': mutedBy,
        'expires_at': expiresAt,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // 23505 = unique_violation
    }
    await _client.from('chat_reports').delete().eq('id', reportId);
    await recordChatMuteAudit(
      profileId: senderId,
      streamId: streamId,
      reason: 'Viewer report reviewed by moderator',
    );
  }

  /// Appends one row to the append-only mute history (Tasks 13 & 15) --
  /// called alongside every mute action, both from the admin dashboard
  /// above and from LiveChatController's in-stream Quick Mute. Best-effort:
  /// a failure here must never block the mute itself from taking effect.
  Future<void> recordChatMuteAudit({
    required String profileId,
    required String streamId,
    required String reason,
    List<String> lastMessages = const [],
  }) async {
    if (!_useSupabase) return;
    final mutedBy = _client.auth.currentUser?.id;
    if (mutedBy == null) return;
    try {
      await _client.from('chat_mute_audit_log').insert({
        'profile_id': profileId,
        'stream_id': streamId,
        'muted_by': mutedBy,
        'reason': reason,
        'last_messages': lastMessages,
      });
    } catch (e) {
      debugPrint('recordChatMuteAudit failed: $e');
    }
  }

  /// One aggregated entry per muted profile, newest mute first -- the
  /// "Muted Chatters Audit Log" section of the admin Chat Moderation tab.
  Future<List<ChatMuteAuditEntry>> loadMutedChattersAuditLog() async {
    if (!_useSupabase) return const [];
    try {
      final rows = await _client
          .from('chat_mute_audit_log')
          .select()
          .order('created_at', ascending: false);
      if (rows.isEmpty) return const [];

      final profiles = await _resolveProfileSummaries(
        rows.map((r) => r['profile_id'] as String?).toSet(),
      );

      final byProfile = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final id = row['profile_id'] as String;
        (byProfile[id] ??= []).add(row);
      }

      return byProfile.entries.map((entry) {
        final profileId = entry.key;
        final entries = entry.value; // already newest-first
        final latest = entries.first;
        final profile = profiles[profileId];
        return ChatMuteAuditEntry(
          profileId: profileId,
          displayName: profile?['display_name_en'] as String? ??
              profile?['email'] as String? ??
              'Unknown user',
          email: profile?['email'] as String?,
          streamsMutedCount:
              entries.map((r) => r['stream_id'] as String).toSet().length,
          lastReason: latest['reason'] as String? ?? 'Manual moderator action',
          lastMessages:
              List<String>.from(latest['last_messages'] as List? ?? const []),
          lastMutedAt: DateTime.parse(latest['created_at'] as String),
        );
      }).toList()
        ..sort((a, b) => b.lastMutedAt.compareTo(a.lastMutedAt));
    } on PostgrestException catch (e) {
      debugPrint(
          'loadMutedChattersAuditLog PostgrestException: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('loadMutedChattersAuditLog error: $e');
      return const [];
    }
  }

  // ==========================================
  // Academic Categories Taxonomy (Cluster 3 Task 10/11)
  //
  // Real-backend-only, same contract as chat moderation above --
  // academic_categories is a public-read/admin-write table (RLS in
  // 20260830130000) with no SharedPreferences shape; an offline caller falls
  // back to AcademicCategoryModel.defaultPool at the AppProvider layer.
  // ==========================================

  Future<List<AcademicCategoryModel>> loadAcademicCategories() async {
    if (!_useSupabase) return const [];
    try {
      final rows = await _client
          .from('academic_categories')
          .select()
          .order('sort_order');
      return rows.map((r) => AcademicCategoryModel.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminDatabaseService.loadAcademicCategories PostgrestException: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('AdminDatabaseService.loadAcademicCategories error: $e');
      return const [];
    }
  }

  Future<void> saveAcademicCategory(AcademicCategoryModel category) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    try {
      await _client.from('academic_categories').upsert(category.toJson());
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminDatabaseService.saveAcademicCategory PostgrestException: ${e.code} ${e.message}');
      rethrow;
    }
  }

  Future<void> deleteAcademicCategory(String id) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    try {
      await _client.from('academic_categories').delete().eq('id', id);
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminDatabaseService.deleteAcademicCategory PostgrestException: ${e.code} ${e.message}');
      rethrow;
    }
  }

  // ==========================================
  // Tag Moderation (Cluster 3 Task 12)
  //
  // Real-backend-only -- public.tags (RLS in 20260830140000): anyone reads
  // approved rows, any authenticated user may submit a new pending tag,
  // only admin tiers may approve/rename/blacklist/delete.
  // ==========================================

  /// Every tag row, admin-tier only at the RLS layer (a non-admin caller
  /// only ever sees status='approved' rows here, per tags_select_approved_public).
  Future<List<TagModerationModel>> loadAllTags() async {
    if (!_useSupabase) return const [];
    try {
      final rows = await _client
          .from('tags')
          .select()
          .order('created_at', ascending: false);
      return rows.map((r) => TagModerationModel.fromRow(r)).toList();
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminDatabaseService.loadAllTags PostgrestException: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('AdminDatabaseService.loadAllTags error: $e');
      return const [];
    }
  }

  /// Public-safe: only ever returns approved tag names, per RLS.
  Future<List<String>> loadApprovedTagNames() async {
    if (!_useSupabase) return const [];
    try {
      final rows =
          await _client.from('tags').select('name').eq('status', 'approved');
      return rows.map((r) => r['name'] as String).toList();
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminDatabaseService.loadApprovedTagNames PostgrestException: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('AdminDatabaseService.loadApprovedTagNames error: $e');
      return const [];
    }
  }

  /// Submits a brand-new tag as pending review -- idempotent if the tag
  /// already exists in any status (tags_insert_pending_self only allows
  /// status='pending' + created_by=self, so this swallows the unique-
  /// violation rather than erroring on a tag someone already submitted).
  Future<void> submitPendingTag(String name) async {
    if (!_useSupabase) return;
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final createdBy = _client.auth.currentUser?.id;
    try {
      await _client.from('tags').insert({
        'name': normalized,
        'status': 'pending',
        'created_by': createdBy,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> setTagStatus(String name, TagStatus status) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client
        .from('tags')
        .update({'status': status.dbValue}).eq('name', name);
  }

  Future<void> deleteTag(String name) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('tags').delete().eq('name', name);
  }

  /// Merges/renames a tag: creates (or approves) the new name, rewrites the
  /// tag on every broadcaster currently carrying the old name, and removes
  /// the old taxonomy row. Not a single atomic rename because `name` is the
  /// primary key -- this is the same two-step "insert new, delete old"
  /// shape a primary-key rename always needs. Cascading to profiles/
  /// organizations is what makes this an actual merge rather than orphaning
  /// every broadcaster who had the old tag (Cluster 3 Task 12).
  Future<void> mergeRenameTag({
    required String oldName,
    required String newName,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final normalized = newName.trim();
    if (normalized.isEmpty) throw Exception('New tag name cannot be empty.');
    await _client.from('tags').upsert({
      'name': normalized,
      'status': 'approved',
      'created_by': _client.auth.currentUser?.id,
    });
    if (normalized != oldName) {
      await _cascadeTagRename(
          table: 'profiles', oldName: oldName, newName: normalized);
      await _cascadeTagRename(
          table: 'organizations', oldName: oldName, newName: normalized);
      await _client.from('tags').delete().eq('name', oldName);
    }
  }

  Future<void> _cascadeTagRename({
    required String table,
    required String oldName,
    required String newName,
  }) async {
    try {
      final rows = await _client
          .from(table)
          .select('id, tags')
          .contains('tags', [oldName]);
      for (final row in rows) {
        final currentTags = List<String>.from(row['tags'] as List? ?? const []);
        final updatedTags =
            currentTags.map((t) => t == oldName ? newName : t).toSet().toList();
        await _client
            .from(table)
            .update({'tags': updatedTags}).eq('id', row['id'] as String);
      }
    } catch (e) {
      debugPrint('_cascadeTagRename($table) failed: $e');
    }
  }

  /// How many broadcasters (individual profiles + organizations) currently
  /// carry [tagName] -- the usage-count badge next to each approved tag
  /// chip (Cluster 3 Task 12).
  Future<int> countBroadcastersForTag(String tagName) async {
    if (!_useSupabase) return 0;
    try {
      final profileRows = await _client
          .from('profiles')
          .select('id')
          .contains('tags', [tagName]);
      final orgRows = await _client
          .from('organizations')
          .select('id')
          .contains('tags', [tagName]);
      return profileRows.length + orgRows.length;
    } catch (e) {
      debugPrint('countBroadcastersForTag failed: $e');
      return 0;
    }
  }

  /// Every broadcaster currently carrying [tagName], for the "Inspect
  /// Broadcasters" drill-down (Cluster 3 Task 12).
  Future<List<TaggedBroadcasterSummary>> loadBroadcastersForTag(
      String tagName) async {
    if (!_useSupabase) return const [];
    try {
      final profileRows = await _client
          .from('profiles')
          .select('id, display_name_en, display_name_ar, avatar_url')
          .contains('tags', [tagName]);
      final orgRows = await _client
          .from('organizations')
          .select('id, name_en, name_ar, avatar_url')
          .contains('tags', [tagName]);

      final result = <TaggedBroadcasterSummary>[
        ...profileRows.map((r) => TaggedBroadcasterSummary(
              id: r['id'] as String,
              nameEn: r['display_name_en'] as String? ?? 'Unknown',
              nameAr: r['display_name_ar'] as String? ?? 'غير معروف',
              avatarUrl: r['avatar_url'] as String? ?? '',
              isOrganization: false,
            )),
        ...orgRows.map((r) => TaggedBroadcasterSummary(
              id: r['id'] as String,
              nameEn: r['name_en'] as String? ?? 'Unknown Organization',
              nameAr: r['name_ar'] as String? ?? 'منظمة غير معروفة',
              avatarUrl: r['avatar_url'] as String? ?? '',
              isOrganization: true,
            )),
      ];
      return result;
    } catch (e) {
      debugPrint('loadBroadcastersForTag failed: $e');
      return const [];
    }
  }

  // ==========================================
  // Banned Accounts (Cluster 4 Task 16)
  //
  // Real-backend-only -- public.banned_users (RLS in 20260830170000). Row
  // presence = banned; unbanning deletes the row, same pattern as
  // chat_muted_users.
  // ==========================================

  Future<List<BannedUserModel>> loadBannedUsers() async {
    if (!_useSupabase) return const [];
    try {
      final rows = await _client
          .from('banned_users')
          .select()
          .order('banned_at', ascending: false);
      if (rows.isEmpty) return const [];

      final profileIds = rows.map((r) => r['profile_id'] as String).toSet();
      final profiles = await _resolveProfileSummaries(profileIds);

      return rows.map<BannedUserModel>((row) {
        final profile = profiles[row['profile_id'] as String];
        return BannedUserModel(
          id: row['id'] as String,
          profileId: row['profile_id'] as String,
          email: row['email'] as String,
          reason: row['reason'] as String,
          bannedBy: row['banned_by'] as String?,
          bannedAt: DateTime.parse(row['banned_at'] as String),
          expiresAt: row['expires_at'] != null
              ? DateTime.parse(row['expires_at'] as String)
              : null,
          displayName: profile?['display_name_en'] as String?,
          avatarUrl: profile?['avatar_url'] as String?,
        );
      }).toList();
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminDatabaseService.loadBannedUsers PostgrestException: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('AdminDatabaseService.loadBannedUsers error: $e');
      return const [];
    }
  }

  /// Bans a platform account by profile id. Idempotent: re-banning an
  /// already-banned account (unique on profile_id) updates the existing row
  /// instead of erroring, so an admin can tighten a reason/duration without
  /// unbanning first.
  Future<void> banAccountPlatformWide({
    required String profileId,
    required String email,
    required String reason,
    DateTime? expiresAt,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final bannedBy = _client.auth.currentUser?.id;
    if (bannedBy == null) throw Exception('Not signed in.');
    try {
      await _client.from('banned_users').upsert(
        {
          'profile_id': profileId,
          'email': email,
          'reason': reason,
          'banned_by': bannedBy,
          'expires_at': expiresAt?.toIso8601String(),
        },
        onConflict: 'profile_id',
      );
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminDatabaseService.banAccountPlatformWide PostgrestException: ${e.code} ${e.message}');
      rethrow;
    }
  }

  Future<void> unbanAccount(String profileId) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    try {
      await _client.from('banned_users').delete().eq('profile_id', profileId);
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminDatabaseService.unbanAccount PostgrestException: ${e.code} ${e.message}');
      rethrow;
    }
  }

  // ==========================================
  // Stream Moderator Delegation (Cluster 4 Task 15)
  // ==========================================

  Future<List<StreamModeratorModel>> loadStreamModerators() async {
    if (!_useSupabase) return const [];
    try {
      final rows = await _client
          .from('stream_moderators')
          .select()
          .order('granted_at', ascending: false);
      if (rows.isEmpty) return const [];

      final profileIds = <String>{};
      for (final r in rows) {
        profileIds.add(r['profile_id'] as String);
        profileIds.add(r['assigned_by'] as String);
      }
      final profiles = await _resolveProfileSummaries(profileIds);

      return rows.map<StreamModeratorModel>((row) {
        final moderator = profiles[row['profile_id'] as String];
        final assignedBy = profiles[row['assigned_by'] as String];
        return StreamModeratorModel(
          id: row['id'] as String,
          profileId: row['profile_id'] as String,
          assignedBy: row['assigned_by'] as String,
          scope: ModeratorScopeInfo.fromDbValue(row['scope'] as String),
          streamId: row['stream_id'] as String?,
          organizationId: row['organization_id'] as String?,
          grantedAt: DateTime.parse(row['granted_at'] as String),
          moderatorDisplayName: moderator?['display_name_en'] as String? ??
              moderator?['email'] as String? ??
              'Unknown user',
          moderatorEmail: moderator?['email'] as String?,
          assignedByDisplayName: assignedBy?['display_name_en'] as String? ??
              assignedBy?['email'] as String? ??
              'Unknown user',
        );
      }).toList();
    } on PostgrestException catch (e) {
      debugPrint(
          'AdminDatabaseService.loadStreamModerators PostgrestException: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('AdminDatabaseService.loadStreamModerators error: $e');
      return const [];
    }
  }

  Future<void> revokeStreamModeratorById(String id) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('stream_moderators').delete().eq('id', id);
  }

  // ==========================================
  // Chat History Deletion (Cluster 4 Task 17)
  //
  // Self-service only -- relies on chat_messages_delete_self (sender_id =
  // auth.uid()), added alongside chat_messages_update_self in
  // 20260830150000. No admin bypass needed here since a signed-in caller
  // can only ever delete their own rows regardless of what id is passed.
  // ==========================================

  Future<void> deleteAllMyMessages() async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in.');
    await _client.from('chat_messages').delete().eq('sender_id', userId);
  }

  Future<void> deleteMyMessagesForStream(String streamId) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in.');
    await _client
        .from('chat_messages')
        .delete()
        .eq('sender_id', userId)
        .eq('stream_id', streamId);
  }

  /// The distinct stream ids this user has ever sent a message in, for the
  /// "Clear Messages by Broadcast" stream picker.
  Future<List<String>> loadMyMessageStreamIds() async {
    if (!_useSupabase) return const [];
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('chat_messages')
        .select('stream_id')
        .eq('sender_id', userId);
    return rows.map((r) => r['stream_id'] as String).toSet().toList();
  }

  // ==========================================
  // Streamer Custom Stream-State Cards (Cluster 1 Task 4b)
  //
  // Real-backend-only, same contract as the chat moderation section above:
  // streamer_custom_placeholders is an RLS-gated moderation queue with no
  // SharedPreferences shape, and the whole point of the feature is that an
  // upload stays inert until a real admin approves it. With no Supabase the
  // methods report "nothing uploaded", which is exactly the state that makes
  // StreamStatePlaceholderOverlay fall back to the system default.
  // ==========================================

  /// Uploads one card image and records it as a *pending* submission.
  /// Returns the created row, or null when there is no backend to record it
  /// in (widget tests / offline).
  Future<StreamerCustomPlaceholderModel?> submitCustomPlaceholder({
    required StreamPlaceholderType placeholderType,
    required String fileName,
    required Uint8List fileBytes,
    String contentType = 'image/jpeg',
  }) async {
    if (!_useSupabase) return null;
    final streamerId = _client.auth.currentUser?.id;
    if (streamerId == null) {
      throw Exception('Cannot upload a stream card while signed out.');
    }

    final imageUrl = await uploadStreamerAsset(
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
      folder: 'custom_placeholders',
    );
    if (imageUrl == null) return null;

    // status is left to the column default rather than sent explicitly --
    // the insert policy only admits status = 'pending', so this cannot
    // become a self-approval path even if a caller passed something else.
    final row = await _client
        .from('streamer_custom_placeholders')
        .insert({
          'streamer_id': streamerId,
          'placeholder_type': placeholderType.dbValue,
          'image_url': imageUrl,
        })
        .select()
        .single();

    return StreamerCustomPlaceholderModel.fromRow(row);
  }

  /// Every card this signed-in streamer has submitted, newest first, in any
  /// status -- what the editor sheet needs to show Pending/Approved/Rejected.
  Future<List<StreamerCustomPlaceholderModel>>
      loadMyCustomPlaceholders() async {
    if (!_useSupabase) return const [];
    final streamerId = _client.auth.currentUser?.id;
    if (streamerId == null) return const [];
    final rows = await _client
        .from('streamer_custom_placeholders')
        .select()
        .eq('streamer_id', streamerId)
        .order('created_at', ascending: false);
    return rows
        .map<StreamerCustomPlaceholderModel>(
            (r) => StreamerCustomPlaceholderModel.fromRow(r))
        .toList();
  }

  /// The admin review queue: every card still awaiting a decision, with the
  /// submitting streamer's display name resolved for the queue card.
  Future<List<StreamerCustomPlaceholderModel>>
      loadPendingCustomPlaceholders() async {
    if (!_useSupabase) return const [];
    final rows = await _client
        .from('streamer_custom_placeholders')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    if (rows.isEmpty) return const [];

    final profiles = await _resolveProfileSummaries(
      rows.map((r) => r['streamer_id'] as String?).toSet(),
    );

    return rows.map<StreamerCustomPlaceholderModel>((row) {
      final profile = profiles[row['streamer_id'] as String];
      return StreamerCustomPlaceholderModel.fromRow(
        row,
        streamerDisplayName: profile?['display_name_en'] as String? ??
            profile?['email'] as String? ??
            'Unknown streamer',
      );
    }).toList();
  }

  /// Every currently-approved card, newest first -- Task 4b: the review
  /// queue also shows already-approved presets so admins have visibility
  /// into what's live, not just what's still pending.
  Future<List<StreamerCustomPlaceholderModel>>
      loadApprovedCustomPlaceholders() async {
    if (!_useSupabase) return const [];
    final rows = await _client
        .from('streamer_custom_placeholders')
        .select()
        .eq('status', 'approved')
        .order('reviewed_at', ascending: false);
    if (rows.isEmpty) return const [];

    final profiles = await _resolveProfileSummaries(
      rows.map((r) => r['streamer_id'] as String?).toSet(),
    );

    return rows.map<StreamerCustomPlaceholderModel>((row) {
      final profile = profiles[row['streamer_id'] as String];
      return StreamerCustomPlaceholderModel.fromRow(
        row,
        streamerDisplayName: profile?['display_name_en'] as String? ??
            profile?['email'] as String? ??
            'Unknown streamer',
      );
    }).toList();
  }

  /// The approved card for one streamer/type pair, or null when they have
  /// none -- the direct question StreamStatePlaceholderOverlay asks before
  /// falling back to the system default.
  Future<String?> loadApprovedPlaceholderUrl({
    required String streamerId,
    required StreamPlaceholderType placeholderType,
  }) async {
    if (!_useSupabase) return null;
    if (!_looksLikeUuid(streamerId)) return null;
    final rows = await _client
        .from('streamer_custom_placeholders')
        .select('image_url')
        .eq('streamer_id', streamerId)
        .eq('placeholder_type', placeholderType.dbValue)
        .eq('status', 'approved')
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['image_url'] as String?;
  }

  Future<void> approveCustomPlaceholder(String placeholderId) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    await _client.from('streamer_custom_placeholders').update({
      'status': 'approved',
      'rejection_reason': null,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': _client.auth.currentUser?.id,
    }).eq('id', placeholderId);
  }

  /// Rejection always carries a reason -- the DB check constraint rejects a
  /// blank one, so this guard fails fast with a message a UI can show
  /// instead of surfacing a raw constraint violation.
  Future<void> rejectCustomPlaceholder({
    required String placeholderId,
    required String reason,
  }) async {
    if (!_useSupabase) throw Exception('Supabase not available');
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw Exception('A rejection reason is required.');
    }
    await _client.from('streamer_custom_placeholders').update({
      'status': 'rejected',
      'rejection_reason': trimmed,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_by': _client.auth.currentUser?.id,
    }).eq('id', placeholderId);
  }

  /// Fires a one-shot Realtime broadcast so every connected client (mobile,
  /// web, desktop) removes this streamer from local state immediately,
  /// independent of postgres_changes replication timing (issue_log.md:
  /// account deletion not propagating to other devices). Uses the same
  /// topic ('public_streamers_discovery') that AppProvider's long-lived
  /// subscription already listens on.
  Future<void> _broadcastStreamerDeleted(String streamerId) async {
    try {
      final channel = _client.channel('public_streamers_discovery');
      final joined = Completer<void>();
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed &&
            !joined.isCompleted) {
          joined.complete();
        }
      });
      await joined.future.timeout(const Duration(seconds: 3), onTimeout: () {});
      await channel.sendBroadcastMessage(
        event: 'streamer_deleted',
        payload: {'streamerId': streamerId},
      );
      await _client.removeChannel(channel);
    } catch (e) {
      debugPrint('broadcastStreamerDeleted failed: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Multi-Device Session Governance (issue_log.md)
  // ---------------------------------------------------------------------

  /// Registers/refreshes this device's row so other devices signing into
  /// the same account can see it. Silently no-ops if the table isn't
  /// reachable (PGRST205 / offline) -- device-session tracking degrades
  /// gracefully, it never blocks sign-in.
  Future<void> upsertDeviceSession({
    required String userId,
    required DeviceSessionModel session,
  }) async {
    if (!_useSupabase) return;
    try {
      if (!session.isPrimaryBroadcaster) {
        await _client.rpc('release_broadcaster_device', params: {
          'p_device_id': session.deviceId,
        });
      } else {
        await heartbeatDevice(session.deviceId);
      }
    } catch (e) {
      debugPrint('upsertDeviceSession failed: $e');
    }
  }

  /// The other device currently holding broadcaster rights on this
  /// account, if any -- what DeviceSessionConflictDialog is shown for.
  Future<DeviceSessionModel?> findActiveRemoteBroadcasterSession({
    required String userId,
    required String currentDeviceId,
  }) async {
    if (!_useSupabase) return null;
    try {
      final rows = await _client
          .from('device_sessions')
          .select()
          .eq('user_id', userId)
          .eq('is_primary_broadcaster', true)
          .neq('device_id', currentDeviceId)
          .gt(
              'last_active_at',
              DateTime.now()
                  .toUtc()
                  .subtract(const Duration(seconds: 90))
                  .toIso8601String())
          .limit(1);
      if (rows.isEmpty) return null;
      final row = rows.first;
      return DeviceSessionModel(
        deviceId: row['device_id'] as String,
        deviceName: row['device_name'] as String? ?? 'Unknown Device',
        platform: row['platform'] as String? ?? 'unknown',
        lastActiveAt:
            DateTime.tryParse(row['last_active_at'] as String? ?? '') ??
                DateTime.now(),
        isPrimaryBroadcaster: true,
      );
    } catch (e) {
      debugPrint('findActiveRemoteBroadcasterSession failed: $e');
      return null;
    }
  }

  Future<bool> claimDevice(DeviceSessionModel device,
      {bool force = false}) async {
    if (!_useSupabase) return false;
    return await _client.rpc('claim_broadcaster_device', params: {
          'p_device_id': device.deviceId,
          'p_name': device.deviceName,
          'p_platform': device.platform,
          'p_force': force,
        }) ==
        true;
  }

  // -------------------------------------------------------------------------
  // Viewer presence (P3 / 05 D-08). The stream_viewers table is deny-all:
  // these two RPCs are the only way in or out of it.
  // -------------------------------------------------------------------------

  /// Reports this viewer as present on [streamId]. Returns false when the
  /// stream is not live, the caller is its broadcaster, or there is no
  /// backend -- the caller shows no count rather than inventing one.
  Future<bool> viewerHeartbeat({
    required String streamId,
    required String viewerKey,
  }) async {
    if (!_useSupabase || streamId.isEmpty || viewerKey.isEmpty) return false;
    try {
      final result = await _client.rpc('viewer_heartbeat', params: {
        'p_stream_id': streamId,
        'p_viewer_key': viewerKey,
      });
      return result == true;
    } catch (e) {
      debugPrint('viewerHeartbeat failed: $e');
      return false;
    }
  }

  /// Live viewer counts per stream id. A missing entry means "unknown" (no
  /// backend, or the call failed) and must be rendered as such, never as 0.
  Future<Map<String, int>> fetchViewerCounts(List<String> streamIds) async {
    if (!_useSupabase || streamIds.isEmpty) return const {};
    try {
      final rows = await _client.rpc('get_viewer_counts', params: {
        'p_stream_ids': streamIds,
      });
      final counts = <String, int>{};
      for (final row in (rows as List)) {
        final map = row as Map<String, dynamic>;
        final id = map['stream_id'] as String?;
        final count = (map['viewer_count'] as num?)?.toInt();
        if (id != null && count != null) counts[id] = count;
      }
      return counts;
    } catch (e) {
      debugPrint('fetchViewerCounts failed: $e');
      return const {};
    }
  }

  // -------------------------------------------------------------------------
  // Follows & bookmarks (05 D-07). Own-row RLS does the authorization: every
  // statement below is scoped to the signed-in account by policy, so a failure
  // here means "not signed in" or "offline", never "someone else's rows".
  // -------------------------------------------------------------------------

  /// Channel ids the signed-in account follows. Empty when signed out or
  /// unreachable -- the caller keeps whatever local state it had.
  Future<Set<String>> loadFollowedTargetIds() async {
    if (!_useSupabase) return {};
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    try {
      final rows = await _client
          .from('follows')
          .select('target_id')
          .eq('follower_profile_id', uid);
      return (rows as List)
          .map((r) => (r as Map<String, dynamic>)['target_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('loadFollowedTargetIds failed: $e');
      return {};
    }
  }

  /// Returns true when the row reached the backend. False means the caller's
  /// optimistic local change is not persisted (signed out, offline, banned).
  Future<bool> addFollow(String targetId) async {
    if (!_useSupabase) return false;
    final uid = _client.auth.currentUser?.id;
    if (uid == null || targetId.isEmpty) return false;
    try {
      await _client.from('follows').upsert(
        {'follower_profile_id': uid, 'target_id': targetId},
        onConflict: 'follower_profile_id,target_id',
      );
      return true;
    } catch (e) {
      debugPrint('addFollow failed: $e');
      return false;
    }
  }

  Future<bool> removeFollow(String targetId) async {
    if (!_useSupabase) return false;
    final uid = _client.auth.currentUser?.id;
    if (uid == null || targetId.isEmpty) return false;
    try {
      await _client
          .from('follows')
          .delete()
          .eq('follower_profile_id', uid)
          .eq('target_id', targetId);
      return true;
    } catch (e) {
      debugPrint('removeFollow failed: $e');
      return false;
    }
  }

  Future<Set<String>> loadBookmarkedVodIds() async {
    if (!_useSupabase) return {};
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    try {
      final rows =
          await _client.from('bookmarks').select('vod_id').eq('profile_id', uid);
      return (rows as List)
          .map((r) => (r as Map<String, dynamic>)['vod_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('loadBookmarkedVodIds failed: $e');
      return {};
    }
  }

  Future<bool> addBookmark(String vodId, {String streamerId = ''}) async {
    if (!_useSupabase) return false;
    final uid = _client.auth.currentUser?.id;
    if (uid == null || vodId.isEmpty) return false;
    try {
      await _client.from('bookmarks').upsert(
        {'profile_id': uid, 'vod_id': vodId, 'streamer_id': streamerId},
        onConflict: 'profile_id,vod_id',
      );
      return true;
    } catch (e) {
      debugPrint('addBookmark failed: $e');
      return false;
    }
  }

  Future<bool> removeBookmark(String vodId) async {
    if (!_useSupabase) return false;
    final uid = _client.auth.currentUser?.id;
    if (uid == null || vodId.isEmpty) return false;
    try {
      await _client
          .from('bookmarks')
          .delete()
          .eq('profile_id', uid)
          .eq('vod_id', vodId);
      return true;
    } catch (e) {
      debugPrint('removeBookmark failed: $e');
      return false;
    }
  }

  /// Clears live flags whose broadcaster's primary device stopped sending
  /// heartbeats (server-side expiry, see
  /// 20260920130000_live_flag_expiry_and_privilege_guards.sql). Only ever
  /// switches flags off, so it is safe for any signed-in client to call
  /// before reading the feed. Returns how many broadcasts were cleared, or 0
  /// when there is no backend or the call fails.
  Future<int> sweepStaleLiveFlags() async {
    if (!_useSupabase) return 0;
    try {
      final result = await _client.rpc('sweep_stale_live_flags');
      return result is int ? result : 0;
    } catch (e) {
      debugPrint('sweepStaleLiveFlags failed: $e');
      return 0;
    }
  }

  Future<bool> heartbeatDevice(String deviceId) async {
    if (!_useSupabase) return false;
    return await _client
            .rpc('device_heartbeat', params: {'p_device_id': deviceId}) ==
        true;
  }

  Stream<List<DeviceSessionModel>> watchDevices(String userId) => _client
      .from('device_sessions')
      .stream(primaryKey: ['user_id', 'device_id'])
      .eq('user_id', userId)
      .map((rows) => rows.map(DeviceSessionModel.fromJson).toList());

  Future<void> setLiveState(
      {required bool live,
      required String type,
      required String? streamId,
      required String deviceId,
      String? orgId}) async {
    if (!_useSupabase) throw StateError('Backend unavailable');
    await _client.rpc('set_live_state', params: {
      'p_live': live,
      'p_type': type,
      'p_stream_id': streamId,
      'p_device_id': deviceId,
      'p_org_id': orgId,
    });
  }
}
