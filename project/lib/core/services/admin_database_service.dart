import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/admin/models/broadcaster_application_model.dart';
import '../../features/admin/models/terms_and_conditions_model.dart';
import '../../features/admin/models/viewer_analytics_model.dart';
import '../../features/organization/models/org_audit_log_entry.dart';
import '../../features/organization/models/org_affiliation_request_model.dart';

/// Core Database & Persistence Service for Admin Moderation, Broadcaster Applications,
/// Dynamic Platform Governance, Viewer Analytics, and Organization Audit Logs.
class AdminDatabaseService {
  static const String _kApplicationsKey = 'streamer_admin_applications_v1';
  static const String _kTermsKey = 'streamer_admin_terms_v1';
  static const String _kAnalyticsKey = 'streamer_admin_analytics_v1';
  static const String _kAuditLogsKey = 'streamer_org_audit_logs_v1';
  static const String _kAffiliationRequestsKey = 'streamer_org_affiliations_v1';

  final SharedPreferences? _prefs;
  List<BroadcasterApplicationModel> _cachedApplications = [];
  List<OrgAuditLogEntry> _cachedAuditLogs = [];
  List<OrgAffiliationRequestModel> _cachedAffiliationRequests = [];
  TermsAndConditionsModel? _cachedTerms;
  ViewerAnalyticsModel? _cachedAnalytics;

  AdminDatabaseService([this._prefs]);

  /// Factory constructor to initialize with SharedPreferences
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
    final idx = _cachedApplications.indexWhere((a) => a.id == id);
    if (idx == -1) return null;

    final current = _cachedApplications[idx];
    final updated = current.copyWith(
      status: newStatus,
      adminReviewNotes: reviewNotes ?? current.adminReviewNotes,
      reviewedBy: reviewedBy ?? current.reviewedBy ?? 'Amir Al-Hatemi (Super Admin)',
      reviewedAt: DateTime.now(),
    );

    _cachedApplications[idx] = updated;
    await _saveApplicationsToPrefs();
    return updated;
  }

  Future<bool> deleteApplication(String id) async {
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

  // ==========================================
  // Organization Audit Trail Logging
  // ==========================================

  Future<List<OrgAuditLogEntry>> loadAuditLogs([String? organizationId]) async {
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

  Future<void> recordAuditLog(OrgAuditLogEntry entry) async {
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

  // ==========================================
  // Terms & Conditions Governance Repository
  // ==========================================

  Future<TermsAndConditionsModel> loadTerms() async {
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
    await saveTerms(_cachedTerms!);
    return _cachedTerms!;
  }

  Future<void> saveTerms(TermsAndConditionsModel terms) async {
    _cachedTerms = terms;
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kTermsKey, jsonEncode(terms.toJson()));
    } catch (e) {
      debugPrint('Error saving terms to SharedPreferences: $e');
    }
  }

  // ==========================================
  // Viewers Analytics Repository
  // ==========================================

  Future<ViewerAnalyticsModel> loadAnalytics() async {
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
    await saveAnalytics(_cachedAnalytics!);
    return _cachedAnalytics!;
  }

  Future<void> saveAnalytics(ViewerAnalyticsModel analytics) async {
    _cachedAnalytics = analytics;
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(_kAnalyticsKey, jsonEncode(analytics.toJson()));
    } catch (e) {
      debugPrint('Error saving analytics to SharedPreferences: $e');
    }
  }

  // ==========================================
  // Org $\leftrightarrow$ Streamer Affiliation Requests Repository
  // ==========================================

  Future<List<OrgAffiliationRequestModel>> loadAffiliationRequests({
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
    final existingIdx =
        _cachedAffiliationRequests.indexWhere((r) => r.id == request.id);
    if (existingIdx != -1) {
      _cachedAffiliationRequests[existingIdx] = request;
    } else {
      _cachedAffiliationRequests.insert(0, request);
    }
    await _saveAffiliationRequestsToPrefs();
  }

  Future<OrgAffiliationRequestModel?> updateAffiliationRequestStatus(
    String id,
    AffiliationStatus newStatus,
  ) async {
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
}
