import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_toast_overlay.dart';
import '../services/notifications/notification_models.dart';
import '../services/notifications/watch_session_tracker.dart';
import '../services/youtube_api_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/admin_database_service.dart';
import '../utils/id_generator.dart';
import '../../features/organization/models/org_speaker_model.dart';
import '../../features/organization/models/org_venue_branch_model.dart';
import '../../features/organization/models/org_broadcaster_permissions.dart';
import '../../features/organization/models/org_audit_log_entry.dart';
import '../../features/organization/models/org_affiliation_request_model.dart';
import '../../features/profile/models/streamer_models.dart';
import '../../features/profile/models/vod_models.dart';
import '../../features/profile/models/user_account_model.dart';
import '../../features/live_stream/models/ghost_comments.dart';
import '../../features/live_stream/models/qa_question_model.dart';
import '../../features/admin/models/broadcaster_application_model.dart';
import '../../features/admin/models/terms_and_conditions_model.dart';
import '../../features/admin/models/viewer_analytics_model.dart';
import '../../features/admin/models/admin_role_assignment_model.dart';
import '../../features/admin/models/chat_report_model.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
bool _looksLikeUuid(String? value) =>
    value != null && _uuidPattern.hasMatch(value);

class AppProvider extends ChangeNotifier {
  List<StreamerModel> _streamers = List.from(mockStreamers);
  List<GhostComment> _chatMessages = [];
  final List<LectureQuestionModel> _questions =
      List.from(LectureQuestionModel.sampleQuestions);
  UserProfileModel _userProfile = UserProfileModel.defaultProfile;
  final YouTubeApiService _youTubeService = YouTubeApiService();
  final SupabaseAuthService _authService = SupabaseAuthService();
  AdminDatabaseService? _adminDbService;

  // Admin Hub, Verification & Governance State
  List<BroadcasterApplicationModel> _applications = [];
  List<OrgAuditLogEntry> _auditLogs = [];
  TermsAndConditionsModel _termsAndConditions =
      TermsAndConditionsModel.createDefault();
  ViewerAnalyticsModel _viewerAnalytics = ViewerAnalyticsModel.createDefault();

  // Onboarding & Authentication State
  bool _hasCompletedOnboarding = false;
  bool _isLoggedInStreamer = false;
  bool _isGuestViewer = false;
  String? _guestViewerName;
  String? _guestViewerAvatar;
  String? _googleUserEmail;
  String? _googleUserName;
  String? _googleUserAvatar;
  // Admin status now comes from the user_roles table (via the is_admin_tier()
  // RPC) instead of a hardcoded email allowlist -- see _refreshAdminRoleFromBackend.
  bool _isAdminFromRoles = false;
  // Distinguishes master_admin from plain admin within is_admin_tier() (via
  // the is_master_admin() RPC -- see v0.8 Checkpoint 1 Phase 1). Used to gate
  // master_admin-only surfaces (e.g. Checkpoint 2's role/permission
  // management tab) on top of the existing isAdminUser check.
  bool _isMasterAdminFromRoles = false;
  // organization_id(s) this user is org_owner/org_co_owner for -- the
  // roadmap's "Permitted Admin" tier (see ADR-007). Disjoint from
  // isAdminUser: a Permitted Admin is not admin-tier, so AdminHubScreen's
  // guard still excludes them -- they get the org-scoped surface in
  // OrgAdminScreen instead (v0.8 Checkpoint 3 Phase 1).
  List<String> _permittedAdminOrgIds = [];
  StreamSubscription<AuthState>? _authStateSub;

  // Org $\leftrightarrow$ Streamer Affiliation State
  List<OrgAffiliationRequestModel> _affiliationRequests = [];

  // Real (Supabase-backed) org venues/speakers cache, keyed by orgId.
  // See ensureOrgDataLoaded/getOrganizationVenues/getOrganizationSpeakers.
  final Map<String, List<OrgVenueBranchModel>> _realOrgVenues = {};
  final Map<String, List<OrgSpeakerModel>> _realOrgSpeakers = {};
  final Set<String> _orgDataLoaded = {};

  // Role & Permission Management (v0.8 Checkpoint 2 Phase 3) -- Master Admin
  // only, see ensureRoleManagementDataLoaded/roleAssignments.
  List<AdminRoleAssignmentModel> _roleAssignments = [];
  Map<String, Set<String>> _userPermissionsByProfile = {};
  bool _roleManagementLoaded = false;

  // Chat Moderation Dashboard (v0.8 Checkpoint 4 Phase 1) -- Admin tier,
  // see ensureChatReportsLoaded/chatReports.
  List<ChatReportModel> _chatReports = [];
  bool _chatReportsLoaded = false;

  bool _isStreamerModeEnabled =
      false; // Toggle between Streamer and Viewer modes
  bool _isPitchDirectorModeEnabled = false;
  String _selectedCityId = 'khobar';
  final String _activeStreamId = 'stream_live_992';
  String _currentCategoryFilter = 'all';
  String _selectedTagFilter = 'all';
  String _searchQuery = '';
  String _rtmpLaptopIp = '192.168.1.100';
  // Phone-to-YouTube broadcast target (v0.7 Checkpoint 2 Phase 2) -- the
  // ingest URL + stream key a streamer pastes from YouTube Studio's "Go
  // Live" > Stream tab so this phone's own camera/mic can publish there,
  // distinct from _customYouTubeLiveUrl above (which is the viewer-facing
  // watch link/video ID, not an RTMP ingest target).
  String _phoneBroadcastRtmpUrl = 'rtmp://a.rtmp.youtube.com/live2';
  String _phoneBroadcastStreamKey = '';
  int _streamReloadCount = 0;
  String _selectedStreamingQuality = 'Auto (1080p)';

  // YouTube Caches
  final Map<String, List<VodModel>> _streamerVods = {};
  final Map<String, List<PlaylistModel>> _streamerPlaylists = {};
  final Set<String> _syncedYouTubeStreamers = {};

  // Live Viewer Polling
  Timer? _liveViewerTimer;
  static const Duration _liveViewerPollInterval = Duration(seconds: 60);

  // Floating Mini-Player State
  bool _isMiniPlayerActive = false;
  bool _isMiniPlayerPlaying = true;
  String _miniPlayerVideoId = 'dQw4w9WgXcQ';
  String _miniPlayerTitle = 'Advanced Artificial Intelligence Lecture';
  String _miniPlayerStreamerName = 'Amir Al-Hatemi';
  String? _miniPlayerStreamId;

  // Streamer Custom YouTube Broadcast Studio State
  String _customYouTubeLiveUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  String _customYouTubeVideoId = 'dQw4w9WgXcQ';
  String _customLiveTitle =
      'Building Autonomous Agent Systems & Cloud Streaming';
  String _customLiveCategory = 'computer_science';
  String _customLiveVenue = 'KFUPM Auditorium 21, Dhahran / Al Khobar';
  String _customSlidesUrl = 'https://kfupm.edu.sa/cs/slides/lecture_01.pdf';
  BroadcastType _customBroadcastType = BroadcastType.liveVideo;
  bool _isBroadcastingLive = false;

  // Streamer Organization Broadcast Selection State
  String? _selectedBroadcastOrgId;
  String? _selectedVenueBranchId;
  List<String> _selectedCoSpeakerIds = [];

  // Bookmarks, Reminders & RSVP Attendance
  final Set<String> _followedStreamerIds = {};
  final Set<String> _reminderStreamerIds = {};
  final Set<String> _bookmarkedLectureIds = {'vod_ai_01', 'vod_cs_02'};
  final Map<String, bool> _inPersonRsvpMap = {};
  final Map<String, int> _venueAvailableSeats = {
    'stream_live_992': 34,
    'stream_live_dr_alshammari_02': 18,
    'stream_live_prof_alotaibi_03': 0,
  };

  // Enhanced Notifications & Anti-Spam Throttling Preferences
  final List<AppNotificationModel> _enhancedNotifications = [];
  NotificationPreferencesModel _notificationPreferences =
      const NotificationPreferencesModel();

  // Legacy Notifications (For backward compatibility)
  final List<AppNotificationItem> _notifications = [];

  AppProvider([AdminDatabaseService? adminDbService])
      : _adminDbService = adminDbService {
    _initAdminDatabase();
    _initAuthListener();
    // NOTE: Live viewer polling is NOT started in the constructor to keep
    // widget tests clean (no pending timer assertions). The real app starts
    // it via AppProvider.ensureLivePollingActive() from main.dart / app root.
  }

  /// Picks up any session Supabase already restored on cold start, then
  /// listens for further auth changes (sign-in completing after the OAuth
  /// redirect, token refresh, sign-out). Swallows the "Supabase not
  /// initialized" assertion so widget/unit tests that construct AppProvider
  /// without calling Supabase.initialize() keep working unaffected.
  void _initAuthListener() {
    try {
      final existingSession = _authService.currentSession;
      if (existingSession != null) {
        _applySessionUser(existingSession.user, isFreshSignIn: true);
      }
      _authStateSub = _authService.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session == null) {
          _clearAuthState();
          return;
        }
        final isFreshSignIn = data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.initialSession;
        _applySessionUser(session.user, isFreshSignIn: isFreshSignIn);
      });
    } catch (e) {
      debugPrint(
          'Supabase auth listener not attached (Supabase not initialized?): $e');
    }
  }

  /// Populates auth/display state from a live Supabase session. On a fresh
  /// sign-in, also provisions the profiles row (if missing) and refreshes
  /// admin status from user_roles via the is_admin_tier() RPC.
  Future<void> _applySessionUser(User user,
      {required bool isFreshSignIn}) async {
    _hasCompletedOnboarding = true;
    _isLoggedInStreamer = true;
    _isGuestViewer = false;
    _isStreamerModeEnabled = _isAdminFromRoles || _isApprovedStreamer;
    _googleUserEmail = user.email;

    final meta = user.userMetadata ?? const <String, dynamic>{};
    _googleUserName =
        (meta['full_name'] ?? meta['name'])?.toString() ?? user.email;
    _googleUserAvatar = (meta['avatar_url'] ?? meta['picture'])?.toString();

    _userProfile = _userProfile.copyWith(
      nameEn: _googleUserName,
      nameAr: _googleUserName,
      avatarUrl: _googleUserAvatar,
    );

    notifyListeners();

    _subscribeToUserStatusChanges(user.id);

    if (isFreshSignIn) {
      await _ensureProfileRow(user);
    }
    await _refreshAdminRoleFromBackend();
    await _refreshPermittedAdminOrgsFromBackend();
    await refreshMyApplicationAndStreamerStatus();
    if (_isAdminFromRoles) {
      await refreshAdminData();
    }
    notifyListeners();
  }

  /// Creates this user's profiles row on their very first sign-in. Existing
  /// users already have one (RLS lets them read/insert only their own row).
  Future<void> _ensureProfileRow(User user) async {
    try {
      final client = Supabase.instance.client;
      final existing = await client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        final meta = user.userMetadata ?? const <String, dynamic>{};
        final displayName = (meta['full_name'] ?? meta['name'])?.toString();
        await client.from('profiles').insert({
          'id': user.id,
          'email': user.email,
          'display_name_en': displayName,
          'display_name_ar': displayName,
          'avatar_url': (meta['avatar_url'] ?? meta['picture'])?.toString(),
        });
        await registerGoogleUser();
      }
    } catch (e) {
      debugPrint('Profile provisioning failed: $e');
    }
  }

  /// Source of truth for admin status: the user_roles table, via the
  /// is_admin_tier() SECURITY DEFINER RPC (see supabase/migrations). Replaces
  /// the hardcoded _superAdminEmails allowlist removed in this refactor.
  /// Also resolves is_master_admin() so the UI can tell master_admin and
  /// plain admin apart (both pass isAdminUser; only the former passes
  /// isMasterAdmin -- see ADR-007).
  Future<void> _refreshAdminRoleFromBackend() async {
    try {
      final results = await Future.wait([
        Supabase.instance.client.rpc('is_admin_tier'),
        Supabase.instance.client.rpc('is_master_admin'),
      ]);
      _isAdminFromRoles = results[0] == true;
      _isMasterAdminFromRoles = results[1] == true;
    } catch (e) {
      debugPrint('Admin role check failed: $e');
      _isAdminFromRoles = false;
      _isMasterAdminFromRoles = false;
    }
  }

  /// organization_id(s) this user is org_owner/org_co_owner for, via a
  /// direct user_roles select (RLS already lets any signed-in user read
  /// their own rows -- no admin tier needed, unlike is_admin_tier()).
  Future<void> _refreshPermittedAdminOrgsFromBackend() async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      _permittedAdminOrgIds = await _adminDbService!.loadPermittedAdminOrgIds();
    } catch (e) {
      debugPrint('Permitted admin org lookup failed: $e');
      _permittedAdminOrgIds = [];
    }
  }

  bool _isApprovedStreamer = false;
  bool get isApprovedStreamer =>
      _isApprovedStreamer ||
      _isAdminFromRoles ||
      _permittedAdminOrgIds.isNotEmpty;

  BroadcasterApplicationModel? _myApplication;
  BroadcasterApplicationModel? get myApplication => _myApplication;

  Future<void> refreshMyApplicationAndStreamerStatus() async {
    final user = _authService.currentSession?.user;
    if (user == null) return;
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      final isStreamer = await _adminDbService!.checkIsProfileStreamer(user.id);
      final myApp = await _adminDbService!.loadMyApplication(user.id);

      final previousApp = _myApplication;
      _myApplication = myApp;

      if (myApp == null) {
        _applications.removeWhere((a) =>
            a.applicantProfileId == user.id ||
            (user.email != null &&
                a.email.toLowerCase() == user.email!.toLowerCase()));
      }

      if (isStreamer ||
          myApp?.status == ApplicationStatus.approved ||
          _isAdminFromRoles ||
          _permittedAdminOrgIds.isNotEmpty) {
        _isApprovedStreamer = true;
        _isStreamerModeEnabled = true;

        if (previousApp != null &&
            previousApp.status == ApplicationStatus.pending &&
            myApp?.status == ApplicationStatus.approved) {
          addEnhancedNotification(
            AppNotificationModel(
              id: 'notif_app_approved_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.streamerApplicationApproved,
              streamerId: user.id,
              streamerName: _googleUserName ?? 'Broadcaster',
              titleEn: '🎉 Broadcaster Application Approved!',
              titleAr: '🎉 تم قبول طلب توثيق البث!',
              bodyEn:
                  'Congratulations! Your broadcaster application was approved by the administration. Streamer Studio is now unlocked!',
              bodyAr:
                  'تهانينا! تمت الموافقة على طلب التوثيق من قبل الإدارة. تم تفعيل استوديو البث المباشر لحسابك!',
              timestamp: DateTime.now(),
            ),
          );
        }
      } else {
        _isApprovedStreamer = false;
        _isStreamerModeEnabled = false;

        if (previousApp != null && myApp == null) {
          addEnhancedNotification(
            AppNotificationModel(
              id: 'notif_app_removed_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.systemAlert,
              streamerId: user.id,
              streamerName: _googleUserName ?? 'User',
              titleEn: 'ℹ️ Application Status Update',
              titleAr: 'ℹ️ تحديث حالة الطلب',
              bodyEn:
                  'Your broadcaster application was removed. You can submit a new application anytime.',
              bodyAr:
                  'تم إزالة طلب التوثيق الخاص بك. يمكنك تقديم طلب جديد في أي وقت.',
              timestamp: DateTime.now(),
            ),
          );
        } else if (previousApp != null &&
            previousApp.status != ApplicationStatus.rejected &&
            myApp?.status == ApplicationStatus.rejected) {
          final reason =
              myApp?.adminReviewNotes ?? 'Incomplete application requirements.';
          addEnhancedNotification(
            AppNotificationModel(
              id: 'notif_app_rejected_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.streamerApplicationRejected,
              streamerId: user.id,
              streamerName: _googleUserName ?? 'User',
              titleEn: '📋 Broadcaster Application Status Update',
              titleAr: '📋 تحديث بخصوص طلب التوثيق الأكاديمي',
              bodyEn:
                  'We could not approve your application at this time: "$reason". You are welcome to re-apply!',
              bodyAr:
                  'تعذر قبول الطلب حالياً للملاحظات التالية: «$reason». يسعدنا تقديمك مجدداً بعد التعديل!',
              timestamp: DateTime.now(),
            ),
          );
        }
      }
      _syncCurrentUserStreamerProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshMyApplicationAndStreamerStatus failed: $e');
    }
  }

  RealtimeChannel? _userStatusChannel;

  void _subscribeToUserStatusChanges(String userId) {
    _unsubscribeFromUserStatusChanges();
    try {
      if (!Supabase.instance.isInitialized) return;
      final client = Supabase.instance.client;
      _userStatusChannel = client
          .channel('user_status:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'broadcaster_applications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'applicant_profile_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('Realtime: user application changed ($payload)');
              refreshMyApplicationAndStreamerStatus();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('Realtime: user profile changed ($payload)');
              refreshMyApplicationAndStreamerStatus();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime user status channel subscription failed: $e');
    }
  }

  void _unsubscribeFromUserStatusChanges() {
    if (_userStatusChannel != null) {
      try {
        if (Supabase.instance.isInitialized) {
          Supabase.instance.client.removeChannel(_userStatusChannel!);
        }
      } catch (_) {}
      _userStatusChannel = null;
    }
  }

  RealtimeChannel? _publicStreamersChannel;

  /// Global Realtime subscription that listens for new verified streamers/organizations
  /// across the platform so all devices (Phone 2, etc.) update their Discovery & Map in real time.
  void _subscribeToPublicStreamerChanges() {
    _unsubscribeFromPublicStreamerChanges();
    try {
      if (!Supabase.instance.isInitialized) return;
      final client = Supabase.instance.client;
      _publicStreamersChannel = client
          .channel('public_streamers_discovery')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            callback: (payload) {
              debugPrint('Realtime: public profile changed ($payload)');
              loadVerifiedStreamersFromBackend();
              if (_isAdminFromRoles) {
                refreshAdminData();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'organizations',
            callback: (payload) {
              debugPrint('Realtime: organization changed ($payload)');
              loadVerifiedStreamersFromBackend();
              if (_isAdminFromRoles) {
                refreshAdminData();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'broadcaster_applications',
            callback: (payload) {
              debugPrint(
                  'Realtime: broadcaster application status changed ($payload)');
              loadVerifiedStreamersFromBackend();
              refreshAdminData();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime public streamer subscription failed: $e');
    }
  }

  void _unsubscribeFromPublicStreamerChanges() {
    if (_publicStreamersChannel != null) {
      try {
        if (Supabase.instance.isInitialized) {
          Supabase.instance.client.removeChannel(_publicStreamersChannel!);
        }
      } catch (_) {}
      _publicStreamersChannel = null;
    }
  }

  /// Fetches verified broadcasters and organizations from Supabase backend
  /// and merges them into _streamers so all devices see new verified streamers.
  Future<void> loadVerifiedStreamersFromBackend() async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      final backendStreamers =
          await _adminDbService!.loadVerifiedStreamersFromBackend();

      final backendIds = backendStreamers.map((s) => s.streamerId).toSet();
      final currentUserId = _authService.currentSession?.user.id;

      // Remove any previously-loaded backend streamer that is no longer verified in DB
      _streamers.removeWhere((s) =>
          !protectedStreamerIds.contains(s.streamerId) &&
          (currentUserId == null ||
              (s.streamerId != currentUserId &&
                  s.streamerId != 'streamer_$currentUserId')) &&
          _looksLikeUuid(s.streamerId.replaceFirst('streamer_', '')) &&
          !backendIds.contains(s.streamerId));

      for (final bs in backendStreamers) {
        final idx = _streamers.indexWhere((s) => s.streamerId == bs.streamerId);
        if (idx != -1) {
          _streamers[idx] = bs;
        } else {
          _streamers.add(bs);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('loadVerifiedStreamersFromBackend failed: $e');
    }
  }

  StreamerModel _createStreamerModelForUser({
    required String userId,
    BroadcasterApplicationModel? app,
  }) {
    final nameEn = (app != null && app.applicantNameEn.trim().isNotEmpty)
        ? app.applicantNameEn.trim()
        : (_googleUserName ?? _userProfile.nameEn);
    final nameAr = (app != null && app.applicantNameAr.trim().isNotEmpty)
        ? app.applicantNameAr.trim()
        : (_googleUserName ?? _userProfile.nameAr);

    final titleEn = (app != null &&
            app.academicTitleEn != null &&
            app.academicTitleEn!.trim().isNotEmpty)
        ? app.academicTitleEn!.trim()
        : ((app?.isOrganization == true)
            ? 'Educational Institution & Venue'
            : 'Lecturer & Academic Researcher');
    final titleAr = (app != null &&
            app.academicTitleAr != null &&
            app.academicTitleAr!.trim().isNotEmpty)
        ? app.academicTitleAr!.trim()
        : ((app?.isOrganization == true)
            ? 'مؤسسة تعليمية وقاعة'
            : 'محاضر وباحث أكاديمي');

    final orgEn = (app != null &&
            app.institutionEn != null &&
            app.institutionEn!.trim().isNotEmpty)
        ? app.institutionEn!.trim()
        : ((app?.isOrganization == true)
            ? nameEn
            : 'Independent Academic Broadcaster');
    final orgAr = (app != null &&
            app.institutionAr != null &&
            app.institutionAr!.trim().isNotEmpty)
        ? app.institutionAr!.trim()
        : ((app?.isOrganization == true) ? nameAr : 'بث أكاديمي مستقل');

    final avatar = (app != null && app.avatarUrl.trim().isNotEmpty)
        ? app.avatarUrl.trim()
        : (_googleUserAvatar ?? _userProfile.avatarUrl);

    final banner = (app != null && app.bannerUrl.trim().isNotEmpty)
        ? app.bannerUrl.trim()
        : 'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4';

    final bioEn = (app != null && app.bioEn.trim().isNotEmpty)
        ? app.bioEn.trim()
        : 'Verified academic lecturer and live broadcaster on Streamer App.';
    final bioAr = (app != null && app.bioAr.trim().isNotEmpty)
        ? app.bioAr.trim()
        : 'محاضر أكاديمي معتمد ومذيع مباشر على منصة البث التفاعلي.';

    final categoryId = (app != null && app.categoryId.trim().isNotEmpty)
        ? app.categoryId.trim()
        : 'computer_science';

    final tags = (app != null && app.tags.isNotEmpty)
        ? app.tags
        : const ['#Live', '#Academic', '#Education'];

    final venueEn = (app != null && app.venueNameEn.trim().isNotEmpty)
        ? app.venueNameEn.trim()
        : 'Al Khobar Innovation Hall';
    final venueAr = (app != null && app.venueNameAr.trim().isNotEmpty)
        ? app.venueNameAr.trim()
        : 'قاعة الابتكار بالخبر';

    final lat = (app != null && app.latitude != 0.0) ? app.latitude : 26.2871;
    final lng = (app != null && app.longitude != 0.0) ? app.longitude : 50.2125;

    final ytHandle = (app != null && app.youtubeHandle.trim().isNotEmpty)
        ? app.youtubeHandle.trim()
        : 'ahmedamercaller';

    return StreamerModel(
      streamerId: userId,
      fullNameEn: nameEn,
      fullNameAr: nameAr,
      titleEn: titleEn,
      titleAr: titleAr,
      organizationEn: orgEn,
      organizationAr: orgAr,
      avatarUrl: avatar,
      bannerUrl: banner,
      bioEn: bioEn,
      bioAr: bioAr,
      isVerified: true,
      followerCount: 0,
      categoryId: categoryId,
      tags: tags,
      cityEn: 'Al Khobar',
      cityAr: 'الخبر',
      venueNameEn: venueEn,
      venueNameAr: venueAr,
      latitude: lat,
      longitude: lng,
      isCurrentlyLive: _isBroadcastingLive,
      broadcastType:
          _isBroadcastingLive ? _customBroadcastType : BroadcastType.offline,
      isOrganization: app?.isOrganization ?? false,
      youtubeHandle: ytHandle,
      youtubeVideoId: 'dQw4w9WgXcQ',
    );
  }

  void _syncCurrentUserStreamerProfile() {
    final userId = _authService.currentSession?.user.id;
    if (userId == null) return;

    if (isApprovedStreamer && _isStreamerModeEnabled) {
      final userStreamer = _createStreamerModelForUser(
        userId: userId,
        app: _myApplication,
      );
      final idx = _streamers.indexWhere((s) =>
          s.streamerId == userId ||
          s.streamerId == 'streamer_$userId' ||
          (userStreamer.streamerId.isNotEmpty &&
              s.streamerId == userStreamer.streamerId));
      if (idx != -1) {
        _streamers[idx] = userStreamer;
      } else {
        _streamers.add(userStreamer);
      }
    } else {
      _streamers.removeWhere((s) =>
          s.streamerId == userId ||
          s.streamerId == 'streamer_$userId' ||
          (!protectedStreamerIds.contains(s.streamerId) &&
              _myApplication != null &&
              s.streamerId == 'streamer_${_myApplication!.id}'));
    }
  }

  void _clearAuthState() {
    _unsubscribeFromUserStatusChanges();
    final userId = _authService.currentSession?.user.id;
    if (userId != null) {
      _streamers.removeWhere(
          (s) => s.streamerId == userId || s.streamerId == 'streamer_$userId');
    }
    _isLoggedInStreamer = false;
    _isStreamerModeEnabled = false;
    _isApprovedStreamer = false;
    _myApplication = null;
    _googleUserEmail = null;
    _googleUserName = null;
    _googleUserAvatar = null;
    _isAdminFromRoles = false;
    _isMasterAdminFromRoles = false;
    _permittedAdminOrgIds = [];
    notifyListeners();
  }

  /// Test-only: simulates a signed-in session without a real Supabase round
  /// trip. Production code paths never call this -- real auth state comes
  /// exclusively from _applySessionUser/_refreshAdminRoleFromBackend above.
  @visibleForTesting
  void debugSetSignedInForTests({
    required String email,
    String? name,
    bool isAdmin = false,
    bool isMasterAdmin = false,
    bool isStreamer = true,
    List<String> permittedAdminOrgIds = const [],
  }) {
    _hasCompletedOnboarding = true;
    _isLoggedInStreamer = true;
    _isGuestViewer = false;
    _isApprovedStreamer = isStreamer || isAdmin || isMasterAdmin;
    _isStreamerModeEnabled = isStreamer || isAdmin || isMasterAdmin;
    _googleUserEmail = email;
    _googleUserName = name ?? email;
    _isAdminFromRoles = isAdmin || isMasterAdmin;
    _isMasterAdminFromRoles = isMasterAdmin;
    _permittedAdminOrgIds = permittedAdminOrgIds;
    notifyListeners();
  }

  Future<void> _initAdminDatabase() async {
    _subscribeToPublicStreamerChanges();
    await loadVerifiedStreamersFromBackend();
    await refreshAdminData();
  }

  /// Reloads all admin-tier data (applications, audit logs, analytics, affiliation requests)
  /// from the Supabase backend.
  Future<void> refreshAdminData() async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      _applications = List.from(await _adminDbService!.loadApplications());
      _termsAndConditions = await _adminDbService!.loadTerms();
      _viewerAnalytics = await _adminDbService!.loadAnalytics();
      _auditLogs = List.from(await _adminDbService!.loadAuditLogs());
      _affiliationRequests =
          List.from(await _adminDbService!.loadAffiliationRequests());
      await loadVerifiedStreamersFromBackend();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshAdminData failed: $e');
    }
  }

  /// Starts or restarts the 60-second polling loop that reads real
  /// `concurrentViewers` from the YouTube Data API for every currently-live
  /// streamer that has a known `youtubeVideoId`.
  void _startLiveViewerPolling() {
    if (_liveViewerTimer?.isActive == true) return; // already running
    _liveViewerTimer?.cancel();
    // Fire once immediately, then repeat every 60 s
    _pollLiveViewers();
    _liveViewerTimer = Timer.periodic(_liveViewerPollInterval, (_) {
      _pollLiveViewers();
    });
  }

  /// Public entry-point called by the real app root (e.g. main.dart or
  /// MaterialApp's builder) after the provider tree is fully wired up.
  /// Must NOT be called from widget tests.
  void ensureLivePollingActive() {
    _startLiveViewerPolling();
  }

  /// Stops the polling loop (called when all broadcasts end).
  void _stopLiveViewerPolling() {
    _liveViewerTimer?.cancel();
    _liveViewerTimer = null;
  }

  /// Fetches real concurrent viewer counts for all currently-live streamers
  /// and updates their `activeViewerCount` if the value changed.
  Future<void> _pollLiveViewers() async {
    final liveStreamers = _streamers
        .where((s) => s.isCurrentlyLive && s.youtubeVideoId.isNotEmpty)
        .toList();

    if (liveStreamers.isEmpty) return;

    bool changed = false;
    for (final streamer in liveStreamers) {
      final count = await _youTubeService.fetchLiveConcurrentViewers(
        streamer.youtubeVideoId,
      );
      if (count != null && count != streamer.activeViewerCount) {
        _streamers = _streamers.map((s) {
          if (s.streamerId == streamer.streamerId) {
            return s.copyWith(activeViewerCount: count);
          }
          return s;
        }).toList();
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _stopLiveViewerPolling();
    _authStateSub?.cancel();
    _unsubscribeFromUserStatusChanges();
    _unsubscribeFromPublicStreamerChanges();
    super.dispose();
  }

  // Admin & Governance Getters
  bool get isAdminUser => _isLoggedInStreamer && _isAdminFromRoles;
  bool get isMasterAdmin => _isLoggedInStreamer && _isMasterAdminFromRoles;
  List<String> get permittedAdminOrgIds =>
      _isLoggedInStreamer ? List.unmodifiable(_permittedAdminOrgIds) : const [];
  bool get isPermittedAdmin => permittedAdminOrgIds.isNotEmpty;

  List<BroadcasterApplicationModel> get applications =>
      List.unmodifiable(_applications);
  List<BroadcasterApplicationModel> get pendingApplications =>
      _applications.where((a) => a.isPending).toList();
  List<BroadcasterApplicationModel> get approvedApplications =>
      _applications.where((a) => a.isApproved).toList();
  List<BroadcasterApplicationModel> get rejectedApplications =>
      _applications.where((a) => a.isRejected).toList();
  int get pendingApplicationsCount =>
      _applications.where((a) => a.isPending).length;

  TermsAndConditionsModel get termsAndConditions => _termsAndConditions;
  ViewerAnalyticsModel get viewerAnalytics => _viewerAnalytics;

  // General Getters
  List<StreamerModel> get streamers => List.unmodifiable(_streamers);
  List<StreamerModel> get liveStreamers =>
      _streamers.where((s) => s.isCurrentlyLive).toList();
  UserProfileModel get userProfile => _userProfile;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get isLoggedInStreamer => _isLoggedInStreamer;
  bool get isGuestViewer => _isGuestViewer;
  String? get guestViewerName => _guestViewerName;
  String? get guestViewerAvatar => _guestViewerAvatar;
  String? get googleUserEmail => _googleUserEmail;
  String? get currentUserEmail => _googleUserEmail;
  String? get currentUserId => _authService.currentSession?.user.id;
  String? get currentUserSessionId => _authService.currentSession?.user.id;
  String? get googleUserName => _googleUserName;
  String? get googleUserAvatar => _googleUserAvatar;

  // Affiliation Getters
  List<OrgAffiliationRequestModel> get affiliationRequests =>
      List.unmodifiable(_affiliationRequests);
  List<OrgAffiliationRequestModel> get pendingAffiliationRequests =>
      _affiliationRequests.where((r) => r.isPending).toList();

  List<OrgAffiliationRequestModel> getMyOrgAffiliations(String streamerId) {
    return _affiliationRequests
        .where((r) => r.streamerId == streamerId)
        .toList();
  }

  bool get isStreamerModeEnabled => _isStreamerModeEnabled;
  bool get isPitchDirectorModeEnabled => _isPitchDirectorModeEnabled;
  String get selectedCityId => _selectedCityId;
  String? get activeStreamId => _activeStreamId;
  String get currentCategoryFilter => _currentCategoryFilter;
  String get selectedTagFilter => _selectedTagFilter;
  String get searchQuery => _searchQuery;
  String get rtmpLaptopIp => _rtmpLaptopIp;
  String get phoneBroadcastRtmpUrl => _phoneBroadcastRtmpUrl;
  String get phoneBroadcastStreamKey => _phoneBroadcastStreamKey;
  String get phoneBroadcastFullUrl => _phoneBroadcastStreamKey.isEmpty
      ? _phoneBroadcastRtmpUrl
      : '$_phoneBroadcastRtmpUrl/$_phoneBroadcastStreamKey';
  int get streamReloadCount => _streamReloadCount;
  String get rtmpStreamUrl => 'http://$_rtmpLaptopIp:8888/live/demo/';
  String get selectedStreamingQuality => _selectedStreamingQuality;

  // Mini Player Getters
  bool get isMiniPlayerActive => _isMiniPlayerActive;
  bool get isMiniPlayerPlaying => _isMiniPlayerPlaying;
  String get miniPlayerVideoId => _miniPlayerVideoId;
  String get miniPlayerTitle => _miniPlayerTitle;
  String get miniPlayerStreamerName => _miniPlayerStreamerName;
  String? get miniPlayerStreamId => _miniPlayerStreamId;

  // Streamer Custom Broadcast Studio Getters
  String get customYouTubeLiveUrl => _customYouTubeLiveUrl;
  String get customYouTubeVideoId => _customYouTubeVideoId;
  String get customLiveTitle => _customLiveTitle;
  String get customLiveCategory => _customLiveCategory;
  String get customLiveVenue => _customLiveVenue;
  String get customSlidesUrl => _customSlidesUrl;
  BroadcastType get customBroadcastType => _customBroadcastType;
  bool get isBroadcastingLive => _isBroadcastingLive;
  String? get selectedBroadcastOrgId => _selectedBroadcastOrgId;
  String? get selectedVenueBranchId => _selectedVenueBranchId;
  List<String> get selectedCoSpeakerIds =>
      List.unmodifiable(_selectedCoSpeakerIds);

  void setSelectedBroadcastOrgId(String? orgId) {
    _selectedBroadcastOrgId = orgId;
    if (orgId != null) {
      final venues = getOrganizationVenues(orgId);
      final mainHq = venues.firstWhere(
        (v) => v.isMainHeadquarters,
        orElse: () => venues.isNotEmpty
            ? venues.first
            : const OrgVenueBranchModel(
                venueId: '',
                nameEn: '',
                nameAr: '',
                cityEn: '',
                cityAr: '',
                latitude: 0,
                longitude: 0,
                seatingCapacity: 0),
      );
      _selectedVenueBranchId = mainHq.venueId.isNotEmpty
          ? mainHq.venueId
          : (venues.isNotEmpty ? venues.first.venueId : null);
      final speakers = getOrganizationSpeakers(orgId);
      _selectedCoSpeakerIds =
          speakers.isNotEmpty ? [speakers.first.speakerId] : [];
    } else {
      _selectedVenueBranchId = null;
      _selectedCoSpeakerIds = [];
    }
    notifyListeners();
  }

  void setSelectedVenueBranchId(String? branchId) {
    _selectedVenueBranchId = branchId;
    notifyListeners();
  }

  void toggleCoSpeaker(String speakerId) {
    if (_selectedCoSpeakerIds.contains(speakerId)) {
      _selectedCoSpeakerIds.remove(speakerId);
    } else {
      _selectedCoSpeakerIds.add(speakerId);
    }
    notifyListeners();
  }

  void setSelectedCoSpeakers(List<String> speakerIds) {
    _selectedCoSpeakerIds = List.from(speakerIds);
    notifyListeners();
  }

  // Q&A & Notifications Getters
  List<LectureQuestionModel> get questions => List.unmodifiable(_questions);

  NotificationPreferencesModel get notificationPreferences =>
      _notificationPreferences;

  List<AppNotificationModel> get enhancedNotifications {
    _cleanupOldNotifications();
    return List.unmodifiable(_enhancedNotifications);
  }

  List<AppNotificationItem> get notifications {
    _cleanupOldNotifications();
    return List.unmodifiable(_notifications);
  }

  int get unreadNotificationsCount {
    _cleanupOldNotifications();
    return _enhancedNotifications.where((n) => !n.isRead).length +
        _notifications.where((n) => !n.isRead).length;
  }

  void _cleanupOldNotifications() {
    final now = DateTime.now();
    _notifications.removeWhere((n) => now.difference(n.timestamp).inHours >= 6);
    _enhancedNotifications
        .removeWhere((n) => now.difference(n.timestamp).inHours >= 12);
  }

  void updateNotificationPreferences(NotificationPreferencesModel preferences) {
    _notificationPreferences = preferences;
    notifyListeners();
  }

  void setNotificationRateLimit(int maxPer10Min) {
    _notificationPreferences =
        _notificationPreferences.copyWith(maxPer10Min: maxPer10Min);
    notifyListeners();
  }

  void toggleMuteEntity(String entityId) {
    final currentMuted =
        Set<String>.from(_notificationPreferences.mutedEntityIds);
    if (currentMuted.contains(entityId)) {
      currentMuted.remove(entityId);
    } else {
      currentMuted.add(entityId);
    }
    _notificationPreferences =
        _notificationPreferences.copyWith(mutedEntityIds: currentMuted);
    notifyListeners();
  }

  bool isEntityMuted(String entityId) =>
      _notificationPreferences.isEntityMuted(entityId);

  void markNotificationAsRead(String id) {
    final enhIdx = _enhancedNotifications.indexWhere((n) => n.id == id);
    if (enhIdx != -1) {
      _enhancedNotifications[enhIdx] =
          _enhancedNotifications[enhIdx].copyWith(isRead: true);
    }
    final legIdx = _notifications.indexWhere((n) => n.id == id);
    if (legIdx != -1) {
      _notifications[legIdx].isRead = true;
    }
    notifyListeners();
  }

  void markAllNotificationsAsRead() {
    for (int i = 0; i < _enhancedNotifications.length; i++) {
      _enhancedNotifications[i] =
          _enhancedNotifications[i].copyWith(isRead: true);
    }
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void deleteNotification(String id) {
    _enhancedNotifications.removeWhere((n) => n.id == id);
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Dispatches an enhanced notification with 10-minute rate-limiting,
  /// quiet hours checks, and interactive toast overlay display.
  bool addEnhancedNotification(AppNotificationModel item,
      {BuildContext? context}) {
    _cleanupOldNotifications();

    // 1. Mute check
    if (item.streamerId.isNotEmpty && isEntityMuted(item.streamerId)) {
      return false;
    }

    // 2. Category / Type toggle check
    if (!_notificationPreferences.isTypeEnabled(item.type)) {
      return false;
    }

    // 3. 10-Minute Rolling Rate Limiter
    final now = DateTime.now();
    final recentNotificationsCount = _enhancedNotifications
        .where((n) => now.difference(n.timestamp).inMinutes <= 10)
        .length;

    if (recentNotificationsCount >= _notificationPreferences.maxPer10Min) {
      // Throttle notification when rate limit is exceeded
      return false;
    }

    // FIFO retention for up to 30 notifications in history
    while (_enhancedNotifications.length >= 30) {
      _enhancedNotifications.removeAt(0);
    }
    _enhancedNotifications.insert(0, item);

    // Sync legacy representation
    addNotification(
      AppNotificationItem(
        id: item.id,
        streamerId: item.streamerId,
        titleEn: item.titleEn,
        titleAr: item.titleAr,
        bodyEn: item.bodyEn,
        bodyAr: item.bodyAr,
        timestamp: item.timestamp,
        streamId: item.streamId,
        isLiveAlert: item.isLiveAlert,
      ),
    );

    // Display interactive dismissible overlay if context is provided
    if (context != null && context.mounted) {
      final isAr =
          EasyLocalization.of(context)?.currentLocale?.languageCode == 'ar';
      InteractiveToastOverlay.show(
        context,
        title: item.getLocalizedTitle(isAr ? 'ar' : 'en'),
        message: item.getLocalizedBody(isAr ? 'ar' : 'en'),
        icon: item.isLiveAlert
            ? Icons.sensors_rounded
            : (item.type == NotificationType.watchMilestoneOneHour
                ? Icons.workspace_premium_rounded
                : Icons.notifications_active_rounded),
        accentColor:
            item.isLiveAlert ? AppTheme.accentRed : AppTheme.accentBlue,
        actionLabel: item.streamId != null ? (isAr ? 'مشاهدة' : 'Watch') : null,
      );
    }

    notifyListeners();
    return true;
  }

  void addNotification(AppNotificationItem item) {
    _cleanupOldNotifications();
    while (_notifications.length >= 15) {
      _notifications.removeAt(0);
    }
    _notifications.add(item);
    notifyListeners();
  }

  static const Set<String> protectedStreamerIds = {
    'prof_alghamdi_01',
    'prof_otaibi_02',
    'prof_dossary_03',
    'prof_mansoor_04',
    'prof_zahrani_05',
  };

  bool isProtectedStreamer(String streamerId) =>
      protectedStreamerIds.contains(streamerId);

  void addStreamer(StreamerModel newStreamer) {
    _streamers.add(newStreamer);
    notifyListeners();
  }

  void updateStreamer(StreamerModel updatedStreamer) {
    final idx = _streamers
        .indexWhere((s) => s.streamerId == updatedStreamer.streamerId);
    if (idx != -1) {
      _streamers[idx] = updatedStreamer;
      notifyListeners();
    }
  }

  Future<bool> deleteStreamer(String streamerId) async {
    if (protectedStreamerIds.contains(streamerId)) {
      return false; // Protected original streamer cannot be deleted
    }
    _streamers.removeWhere((s) =>
        s.streamerId == streamerId || s.streamerId == 'streamer_$streamerId');
    _adminDbService ??= await AdminDatabaseService.create();
    final success = await _adminDbService!.revokeStreamer(streamerId);

    // If revoking self, downgrade state
    final currentUserId = _authService.currentSession?.user.id;
    if (currentUserId != null &&
        (streamerId == currentUserId ||
            streamerId == 'streamer_$currentUserId')) {
      _isApprovedStreamer = false;
      _isStreamerModeEnabled = false;
      await refreshMyApplicationAndStreamerStatus();
    }

    await loadVerifiedStreamersFromBackend();
    if (_isAdminFromRoles) {
      await refreshAdminData();
    }
    notifyListeners();
    return success;
  }

  StreamerModel? getStreamerById(String streamerIdOrStreamId) {
    try {
      final clean =
          streamerIdOrStreamId.trim().replaceAll('@', '').toLowerCase();
      return _streamers.firstWhere((s) =>
          s.streamerId == streamerIdOrStreamId ||
          s.activeStreamId == streamerIdOrStreamId ||
          s.youtubeHandle.toLowerCase().replaceAll('@', '') == clean ||
          s.youtubeVideoId == streamerIdOrStreamId);
    } catch (_) {
      return null;
    }
  }

  bool isYouTubeLiveSynced(String streamerId) {
    return _syncedYouTubeStreamers.contains(streamerId);
  }

  List<VodModel> getVodsForStreamer(String streamerId) {
    if (_streamerVods.containsKey(streamerId)) {
      return _streamerVods[streamerId]!;
    }
    return MockVodArchivePool.sampleVods
        .where((v) => v.streamerId == streamerId)
        .toList();
  }

  List<PlaylistModel> getPlaylistsForStreamer(String streamerId) {
    if (_streamerPlaylists.containsKey(streamerId)) {
      return _streamerPlaylists[streamerId]!;
    }
    return MockVodArchivePool.samplePlaylists
        .where((p) => p.streamerId == streamerId)
        .toList();
  }

  Future<void> loadYouTubeChannelData({
    required String streamerId,
    String handle = 'ahmedamercaller',
  }) async {
    try {
      final vods = await _youTubeService.fetchChannelVideos(
        streamerId: streamerId,
        handle: handle,
      );
      if (vods.isNotEmpty) {
        if (streamerId != 'org_dalilk_04') {
          _streamerVods[streamerId] = vods;
        }
      }
      final channelDetails = await _youTubeService.fetchChannelDetails(handle);
      final channelId =
          channelDetails['channelId'] ?? 'UCah56qawts736uNxZA3inLQ';
      final playlists = await _youTubeService.fetchChannelPlaylists(
        streamerId: streamerId,
        channelId: channelId,
      );
      if (playlists.isNotEmpty) {
        if (streamerId != 'org_dalilk_04') {
          _streamerPlaylists[streamerId] = playlists;
        }
      }
      _syncedYouTubeStreamers.add(streamerId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading YouTube data for $streamerId: $e');
    }
  }

  Future<List<VodModel>> fetchPlaylistVideos({
    required String streamerId,
    required String playlistId,
  }) async {
    try {
      return await _youTubeService.fetchPlaylistItems(
        streamerId: streamerId,
        playlistId: playlistId,
      );
    } catch (e) {
      debugPrint('Error fetching playlist videos: $e');
      return [];
    }
  }

  // User Profile Methods
  void updateUserProfile(UserProfileModel newProfile) {
    _userProfile = newProfile;
    notifyListeners();
  }

  // ==========================================
  // Onboarding & Authentication Methods
  // ==========================================

  /// Records a new guest viewer session in Admin telemetry
  Future<void> recordGuestSession() async {
    _viewerAnalytics = ViewerAnalyticsModel(
      totalGuestSessions: _viewerAnalytics.totalGuestSessions + 1,
      totalRegisteredGoogleUsers: _viewerAnalytics.totalRegisteredGoogleUsers,
      totalLectureBookmarks: _viewerAnalytics.totalLectureBookmarks,
      totalAuditoriumRsvps: _viewerAnalytics.totalAuditoriumRsvps,
      totalBroadcastHours: _viewerAnalytics.totalBroadcastHours,
      activeViewersLive: _viewerAnalytics.activeViewersLive,
      lastRefreshed: DateTime.now(),
    );
    await _adminDbService?.saveAnalytics(_viewerAnalytics);
  }

  /// Increments registered Google user count in Admin telemetry
  Future<void> registerGoogleUser() async {
    _viewerAnalytics = ViewerAnalyticsModel(
      totalGuestSessions: _viewerAnalytics.totalGuestSessions,
      totalRegisteredGoogleUsers:
          _viewerAnalytics.totalRegisteredGoogleUsers + 1,
      totalLectureBookmarks: _viewerAnalytics.totalLectureBookmarks,
      totalAuditoriumRsvps: _viewerAnalytics.totalAuditoriumRsvps,
      totalBroadcastHours: _viewerAnalytics.totalBroadcastHours,
      activeViewersLive: _viewerAnalytics.activeViewersLive,
      lastRefreshed: DateTime.now(),
    );
    await _adminDbService?.saveAnalytics(_viewerAnalytics);
  }

  /// Configures a guest viewer with friendly display name & avatar
  Future<void> setupGuestViewer({
    required String name,
    String? avatarUrl,
  }) async {
    _hasCompletedOnboarding = true;
    _isGuestViewer = true;
    _isLoggedInStreamer = false;
    _isStreamerModeEnabled = false;
    _guestViewerName = name.trim();
    _guestViewerAvatar = avatarUrl;

    _userProfile = _userProfile.copyWith(
      nameEn: _guestViewerName,
      nameAr: _guestViewerName,
      avatarUrl: avatarUrl ?? 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
    );

    await recordGuestSession();
    notifyListeners();
  }

  void selectViewerMode() {
    _hasCompletedOnboarding = true;
    _isStreamerModeEnabled = false;
    _isLoggedInStreamer = false;
    recordGuestSession();
    notifyListeners();
  }

  /// Launches the Google OAuth web flow. Returns once the browser opens --
  /// a failed/cancelled sign-in surfaces as a thrown exception (never a
  /// fabricated session). Actual auth state is populated by the
  /// onAuthStateChange listener (see _initAuthListener) once the OAuth
  /// redirect completes.
  Future<void> loginWithGoogle() => _authService.signInWithGoogle();

  /// Uploads binary media (avatar/banner) to Supabase Storage 'streamer-assets' bucket
  Future<String?> uploadStreamerMediaAsset({
    required String fileName,
    required Uint8List fileBytes,
    String contentType = 'image/jpeg',
  }) async {
    _adminDbService ??= await AdminDatabaseService.create();
    return _adminDbService!.uploadStreamerAsset(
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
  }

  /// Submits a multi-step Broadcaster / Organization verification application
  Future<void> submitBroadcasterApplication(
      BroadcasterApplicationModel application) async {
    _adminDbService ??= await AdminDatabaseService.create();
    _applications.insert(0, application);
    await _adminDbService!.submitApplication(application);
    _applications = List.from(await _adminDbService!.loadApplications());

    // Record in immutable governance audit trail
    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: application.isOrganization
            ? application.id
            : (application.institutionEn ?? 'Independent'),
        timestamp: DateTime.now(),
        actorEmail: application.email,
        actorName: application.applicantNameEn,
        action: OrgAuditAction.applyBroadcaster,
        descriptionEn:
            'Submitted broadcaster verification application (${application.isOrganization ? 'Organization' : 'Individual'}).',
        descriptionAr:
            'تم تقديم طلب توثيق مذيع (${application.isOrganization ? 'منظمة' : 'فردي'}).',
        metadata: {
          'category': application.categoryId,
          'youtube_handle': application.youtubeHandle,
          'city': application.venueNameEn,
        },
      ),
    );

    _hasCompletedOnboarding = true;

    _userProfile = _userProfile.copyWith(
      nameEn: application.applicantNameEn,
      nameAr: application.applicantNameAr,
      titleEn: application.academicTitleEn ?? 'Broadcaster Applicant',
      titleAr: application.academicTitleAr ?? 'مقدم طلب توثيق',
      bioEn: application.bioEn,
      bioAr: application.bioAr,
      avatarUrl: application.avatarUrl,
      bannerUrl: application.bannerUrl,
      youtubeChannelUrl: application.youtubeChannelUrl,
    );

    await registerGoogleUser();
    notifyListeners();
  }

  // ==========================================
  // Org $\leftrightarrow$ Streamer Affiliation Protocol Methods
  // ==========================================

  /// Submits a request for an individual streamer to join an organization
  Future<void> submitOrgAffiliationRequest({
    required String orgId,
    required String note,
    String? proposedRoleEn,
    String? proposedRoleAr,
  }) async {
    final targetOrg = _streamers.firstWhere(
      (s) => s.streamerId == orgId,
      orElse: () => _streamers.first,
    );

    final req = OrgAffiliationRequestModel(
      id: newId(),
      orgId: orgId,
      orgNameEn: targetOrg.fullNameEn,
      orgNameAr: targetOrg.fullNameAr,
      orgAvatarUrl: targetOrg.avatarUrl,
      streamerId: _userProfile.id,
      streamerNameEn: _userProfile.nameEn,
      streamerNameAr: _userProfile.nameAr,
      streamerAvatarUrl: _userProfile.avatarUrl,
      streamerEmail: _googleUserEmail ?? 'broadcaster@platform.com',
      proposedRoleEn: proposedRoleEn ?? 'Guest Instructor',
      proposedRoleAr: proposedRoleAr ?? 'محاضر زائر',
      note: note.trim(),
      direction: AffiliationDirection.streamerToOrg,
      status: AffiliationStatus.pending,
      createdAt: DateTime.now(),
    );

    _affiliationRequests.insert(0, req);
    await _adminDbService?.submitAffiliationRequest(req);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'broadcaster@platform.com',
        actorName: _userProfile.nameEn,
        action: OrgAuditAction.addSpeakerToRoster,
        descriptionEn:
            '${_userProfile.nameEn} submitted an affiliation request to join ${targetOrg.fullNameEn}.',
        descriptionAr:
            'قدم ${_userProfile.nameAr} طلب انضمام إلى ${targetOrg.fullNameAr}.',
        metadata: {
          'org_id': orgId,
          'proposed_role': proposedRoleEn ?? 'Guest Instructor',
        },
      ),
    );

    notifyListeners();
  }

  /// Accepts an incoming affiliation request and adds speaker to Org roster
  Future<void> acceptOrgAffiliationRequest(String requestId) async {
    final idx = _affiliationRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;

    final req = _affiliationRequests[idx];
    final updated = await _adminDbService?.updateAffiliationRequestStatus(
      requestId,
      AffiliationStatus.accepted,
    );

    if (updated != null) {
      _affiliationRequests[idx] = updated;

      // Add to the Org's active roster
      final speaker = OrgSpeakerModel(
        speakerId: 'spk_${req.streamerId}',
        nameEn: req.streamerNameEn,
        nameAr: req.streamerNameAr,
        roleOrTitleEn: req.proposedRoleEn ?? 'Affiliated Instructor',
        roleOrTitleAr: req.proposedRoleAr ?? 'مدرب معتمد',
        avatarUrl: req.streamerAvatarUrl,
        bioEn: req.note,
        bioAr: req.note,
        isPermanentStaff: false,
        linkedEmail: req.streamerEmail,
        permissions: const OrgBroadcasterPermissions(
          canGoLiveVideo: true,
          canGoAudioOnly: true,
          canChangeLocation: false,
          canEditDescription: true,
          canEditStreamTime: false,
          canAddExternalLinks: true,
        ),
      );

      await orgAddSpeaker(req.orgId, speaker);
    }
    notifyListeners();
  }

  /// Declines an incoming affiliation request
  Future<void> declineOrgAffiliationRequest(String requestId) async {
    final idx = _affiliationRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;

    final updated = await _adminDbService?.updateAffiliationRequestStatus(
      requestId,
      AffiliationStatus.declined,
    );
    if (updated != null) {
      _affiliationRequests[idx] = updated;
    }
    notifyListeners();
  }

  /// Adds a speaker to an Organization's roster
  Future<void> orgAddSpeaker(String orgId, OrgSpeakerModel speaker) async {
    _streamers = _streamers.map((s) {
      if (s.streamerId == orgId) {
        final existing = List<OrgSpeakerModel>.from(s.affiliatedSpeakers);
        if (!existing.any((spk) => spk.speakerId == speaker.speakerId)) {
          existing.add(speaker);
        }
        return s.copyWith(affiliatedSpeakers: existing);
      }
      return s;
    }).toList();
    await _writeThroughOrgSpeaker(orgId, speaker);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.addSpeakerToRoster,
        descriptionEn:
            'Added ${speaker.nameEn} to organization speaker roster.',
        descriptionAr:
            'تمت إضافة ${speaker.nameAr} إلى قائمة المدربين المعتمدين.',
        metadata: {
          'speaker_id': speaker.speakerId,
          'role': speaker.roleOrTitleEn,
        },
      ),
    );

    notifyListeners();
  }

  /// Removes a speaker from an Organization's roster
  Future<void> orgRemoveSpeaker(String orgId, String speakerId) async {
    _streamers = _streamers.map((s) {
      if (s.streamerId == orgId) {
        final existing = List<OrgSpeakerModel>.from(s.affiliatedSpeakers)
          ..removeWhere((spk) => spk.speakerId == speakerId);
        return s.copyWith(affiliatedSpeakers: existing);
      }
      return s;
    }).toList();
    await _writeThroughDeleteOrgSpeaker(orgId, speakerId);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.updatePermissions,
        descriptionEn: 'Removed speaker $speakerId from organization roster.',
        descriptionAr: 'تم حذف المدرب $speakerId من قائمة المدربين.',
        metadata: {'speaker_id': speakerId},
      ),
    );

    notifyListeners();
  }

  /// Updates permissions for an affiliated speaker in an Organization
  Future<void> orgUpdateSpeakerPermissions(
    String orgId,
    String speakerId,
    OrgBroadcasterPermissions permissions,
  ) async {
    _streamers = _streamers.map((s) {
      if (s.streamerId == orgId) {
        final updatedSpeakers = s.affiliatedSpeakers.map((spk) {
          if (spk.speakerId == speakerId) {
            return spk.copyWith(permissions: permissions);
          }
          return spk;
        }).toList();
        return s.copyWith(affiliatedSpeakers: updatedSpeakers);
      }
      return s;
    }).toList();

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.updatePermissions,
        descriptionEn: 'Updated broadcast permissions for speaker $speakerId.',
        descriptionAr: 'تم تحديث صلاحيات البث للمدرب $speakerId.',
        metadata: permissions.toJson(),
      ),
    );

    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('Supabase sign-out failed (Supabase not initialized?): $e');
    }
    _hasCompletedOnboarding = false;
    _isLoggedInStreamer = false;
    _isGuestViewer = false;
    _isStreamerModeEnabled = false;
    _isAdminFromRoles = false;
    _isMasterAdminFromRoles = false;
    _permittedAdminOrgIds = [];
    _googleUserEmail = null;
    _googleUserName = null;
    _googleUserAvatar = null;
    _guestViewerName = null;
    _guestViewerAvatar = null;
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    await logout();
  }

  Future<void> signOut() async {
    await logout();
  }

  /// Self-service account & data deletion (v0.9 Checkpoint 2 Phase 1) --
  /// Apple/Google store-submission requirement. Calls the security-definer
  /// `delete_own_account()` RPC (20260829000000_account_deletion_cascades.sql),
  /// which deletes the caller's own auth.users row; that cascades to
  /// profiles and everything hanging off it (broadcaster_applications,
  /// chat_messages, user_roles, user_permissions, owned organizations via
  /// the before-delete trigger). Local client state is cleared the same way
  /// signOut() clears it, since the session is no longer valid either way.
  Future<bool> deleteOwnAccount() async {
    try {
      await Supabase.instance.client.rpc('delete_own_account');
    } catch (e) {
      debugPrint('Account deletion failed: $e');
      return false;
    }
    await logout();
    return true;
  }

  // Toggle Streamer / Viewer Mode
  void setRoleMode(bool isStreamer) {
    // Enabling Streamer Mode requires an already-authenticated session that is
    // an approved broadcaster or admin -- role changes go through the real backend.
    if (isStreamer && !isApprovedStreamer) return;
    _isStreamerModeEnabled = isStreamer;
    notifyListeners();
  }

  void toggleStreamerMode() {
    setRoleMode(!_isStreamerModeEnabled);
  }

  // Mini Player Controls
  void launchMiniPlayer({
    required String videoId,
    required String title,
    required String streamerName,
    String? streamId,
  }) {
    _isMiniPlayerActive = true;
    _isMiniPlayerPlaying = true;
    _miniPlayerVideoId = videoId;
    _miniPlayerTitle = title;
    _miniPlayerStreamerName = streamerName;
    _miniPlayerStreamId = streamId;
    notifyListeners();
  }

  void closeMiniPlayer() {
    _isMiniPlayerActive = false;
    notifyListeners();
  }

  void toggleMiniPlayerPlayPause() {
    _isMiniPlayerPlaying = !_isMiniPlayerPlaying;
    notifyListeners();
  }

  // Streamer Go Live Studio Methods
  void setCustomStreamerYouTubeUrl(String url) {
    _customYouTubeLiveUrl = url.trim();
    _customYouTubeVideoId = extractYouTubeId(url);
    _streamers = _streamers.map((s) {
      if (s.streamerId == 'prof_alghamdi_01') {
        return s.copyWith(youtubeVideoId: _customYouTubeVideoId);
      }
      return s;
    }).toList();
    notifyListeners();
  }

  // Amir Al-Hatemi's YouTube channel (prof_alghamdi_01 only). Auto-detect is
  // intentionally scoped to this single account/channel and must not be
  // reused for any other streamer in the app.
  static const String amirYouTubeChannelId = 'UCdPq2Mayw6k-WuvBMKNj44A';

  bool _isDetectingAmirLiveVideo = false;
  String? _amirAutoDetectError;

  bool get isDetectingAmirLiveVideo => _isDetectingAmirLiveVideo;
  String? get amirAutoDetectError => _amirAutoDetectError;

  /// Auto-detects Amir Al-Hatemi's currently-live YouTube broadcast and
  /// applies it as the active YouTube Live target. Only ever looks up
  /// [amirYouTubeChannelId] — this must not be generalized to other
  /// streamer accounts.
  Future<bool> autoDetectAmirLiveVideo() async {
    _isDetectingAmirLiveVideo = true;
    _amirAutoDetectError = null;
    notifyListeners();

    try {
      final videoId =
          await _youTubeService.fetchLiveVideoId(amirYouTubeChannelId);

      if (videoId == null) {
        _amirAutoDetectError =
            'No active live stream found on Amir Al-Hatemi\'s channel. '
            'Make sure OBS is streaming and you\'ve clicked "Go Live" in YouTube Studio.';
        return false;
      }

      _customYouTubeVideoId = videoId;
      _customYouTubeLiveUrl = 'https://www.youtube.com/watch?v=$videoId';
      _streamers = _streamers.map((s) {
        if (s.streamerId == 'prof_alghamdi_01') {
          return s.copyWith(
            youtubeVideoId: videoId,
            isCurrentlyLive: true,
            activeStreamId: 'stream_live_992',
          );
        }
        return s;
      }).toList();
      return true;
    } finally {
      _isDetectingAmirLiveVideo = false;
      notifyListeners();
    }
  }

  // Custom Live Stream Configurations
  void setCustomBroadcastDetails({
    required String title,
    required String category,
    required String venue,
    required String slidesUrl,
  }) {
    _customLiveTitle = title;
    _customLiveCategory = category;
    _customLiveVenue = venue;
    _customSlidesUrl = slidesUrl;
    notifyListeners();
  }

  void updateCustomLiveBroadcast({
    required String title,
    required String category,
    required String venue,
    required String slidesUrl,
  }) =>
      setCustomBroadcastDetails(
        title: title,
        category: category,
        venue: venue,
        slidesUrl: slidesUrl,
      );

  void setBroadcastType(BroadcastType type) {
    _customBroadcastType = type;
    final currentUserId = _authService.currentSession?.user.id;
    _streamers = _streamers.map((streamer) {
      if (streamer.streamerId == 'prof_alghamdi_01' ||
          (currentUserId != null && streamer.streamerId == currentUserId)) {
        return streamer.copyWith(
          broadcastType: streamer.isCurrentlyLive ? type : type,
        );
      }
      return streamer;
    }).toList();
    notifyListeners();
  }

  Future<void> toggleBroadcasterGoLive([BuildContext? context]) async {
    _isBroadcastingLive = !_isBroadcastingLive;

    final currentUserId = _authService.currentSession?.user.id;
    final orgId = _selectedBroadcastOrgId;
    final targetStreamerId = orgId ?? currentUserId ?? 'prof_alghamdi_01';

    // Synchronize target streamer model with the custom live data
    _streamers = _streamers.map<StreamerModel>((streamer) {
      if (streamer.streamerId == targetStreamerId) {
        OrgVenueBranchModel? activeBranch;
        if (orgId != null &&
            _selectedVenueBranchId != null &&
            streamer.venues.isNotEmpty) {
          activeBranch = streamer.venues.firstWhere(
            (v) => v.venueId == _selectedVenueBranchId,
            orElse: () => streamer.venues.first,
          );
        }

        return streamer.copyWith(
          isCurrentlyLive: _isBroadcastingLive,
          broadcastType: _isBroadcastingLive
              ? _customBroadcastType
              : BroadcastType.offline,
          activeStreamId: _isBroadcastingLive ? 'stream_live_992' : null,
          activeViewerCount: _isBroadcastingLive ? 0 : 0,
          titleEn: _customLiveTitle,
          titleAr: _customLiveTitle,
          latitude:
              activeBranch != null ? activeBranch.latitude : streamer.latitude,
          longitude: activeBranch != null
              ? activeBranch.longitude
              : streamer.longitude,
          venueNameEn:
              activeBranch != null ? activeBranch.nameEn : streamer.venueNameEn,
          venueNameAr:
              activeBranch != null ? activeBranch.nameAr : streamer.venueNameAr,
          activeLiveVenueId: _isBroadcastingLive
              ? (_selectedVenueBranchId ?? streamer.activeLiveVenueId)
              : null,
        );
      }
      return streamer;
    }).toList();

    if (_isBroadcastingLive) {
      // Start polling real viewer count from YouTube
      _startLiveViewerPolling();
      final isAudio = _customBroadcastType == BroadcastType.liveAudio;
      final streamerNameEn =
          orgId != null ? 'Dalilk 4 IELTS' : 'Amir Al-Hatemi';
      final streamerNameAr = orgId != null ? 'دليل الآيلتس' : 'أمير الحاتمي';

      addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_live_${DateTime.now().millisecondsSinceEpoch}',
          type: isAudio
              ? NotificationType.streamerLiveAudio
              : NotificationType.streamerLiveVideo,
          streamerId: targetStreamerId,
          streamerName: streamerNameEn,
          titleEn: isAudio
              ? '🎙️ Live Audio Stage Started'
              : '🔴 Live Broadcast Started',
          titleAr:
              isAudio ? '🎙️ مساحة صوتية مباشرة' : '🔴 بدأ البث المباشر الآن',
          bodyEn: isAudio
              ? 'Live Audio Stage with $streamerNameEn: "$_customLiveTitle" .. Join in!'
              : '🔴 $streamerNameEn is live now: "$_customLiveTitle" .. Join and interact!',
          bodyAr: isAudio
              ? '🎙️ مساحة صوتية مباشرة مع $streamerNameAr: «$_customLiveTitle».. استمع وشارك برأيك'
              : '🔴 $streamerNameAr بدأ بثاً مباشراً الآن: «$_customLiveTitle».. حيّاك شاركنا وتفاعل!',
          timestamp: DateTime.now(),
          streamId: 'stream_live_992',
        ),
        context: context,
      );

      if (orgId != null) {
        await recordOrgAuditAction(
          OrgAuditLogEntry(
            logId: newId(),
            organizationId: orgId,
            timestamp: DateTime.now(),
            actorEmail: _googleUserEmail ?? 'admin@platform.com',
            actorName: _googleUserName ?? 'Administrator',
            action: OrgAuditAction.startLiveBroadcast,
            descriptionEn:
                'Started live broadcast "$_customLiveTitle" (${isAudio ? 'Audio-Only' : 'Video'}).',
            descriptionAr:
                'بدأ بث مباشر "$_customLiveTitle" (${isAudio ? 'صوتي' : 'مرئي'}).',
            metadata: {
              'venue_id': _selectedVenueBranchId,
              'speakers': _selectedCoSpeakerIds,
              'broadcast_type': isAudio ? 'audio' : 'video',
              'youtube_id': _customYouTubeVideoId,
            },
          ),
        );
      }
    } else {
      // 🌟 Check and push 1-Hour Watch Milestone Notification if user watched >= 60 min
      WatchSessionTracker.onStreamEnded(
        'stream_live_992',
        onMilestoneReached: (spkId, spkName, duration) {
          addEnhancedNotification(
            AppNotificationModel(
              id: 'notif_milestone_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.watchMilestoneOneHour,
              streamerId: spkId.isNotEmpty ? spkId : targetStreamerId,
              streamerName: spkName,
              titleEn: '🌟 Thank you for watching!',
              titleAr: '🌟 شكراً لوقتك الثمين!',
              bodyEn:
                  'We loved having you for over an hour in $spkName\'s broadcast. We hope it was valuable and inspiring!',
              bodyAr:
                  'سعدنا بحضورك ومتابعتك لأكثر من ساعة في بث $spkName. نتمنى لك دوام الفائدة والتوفيق!',
              timestamp: DateTime.now(),
            ),
            context: context,
          );
        },
      );

      if (orgId != null) {
        await recordOrgAuditAction(
          OrgAuditLogEntry(
            logId: newId(),
            organizationId: orgId,
            timestamp: DateTime.now(),
            actorEmail: _googleUserEmail ?? 'admin@platform.com',
            actorName: _googleUserName ?? 'Administrator',
            action: OrgAuditAction.endLiveBroadcast,
            descriptionEn: 'Ended live broadcast session.',
            descriptionAr: 'تم إنهاء جلسة البث المباشر.',
          ),
        );

        addEnhancedNotification(
          AppNotificationModel(
            id: 'notif_org_end_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.orgStreamerLiveStatus,
            streamerId: orgId,
            streamerName: 'Dalilk 4 IELTS',
            titleEn: '📡 Stream Session Concluded',
            titleAr: '📡 انتهت جلسة البث المباشر',
            bodyEn:
                'Faculty member concluded their live session at Dalilk Auditorium.',
            bodyAr: 'أنهى عضو الكادر جلسته التدريبية المباشرة في مدرج دليلك.',
            timestamp: DateTime.now(),
          ),
          context: context != null && context.mounted ? context : null,
        );
      }
      // Stop polling if no live streamers remain (Quran 24/7 excluded
      // from this check because it never calls toggleBroadcasterGoLive)
      final anyOtherLive = _streamers.any((s) => s.isCurrentlyLive);
      if (!anyOtherLive) {
        // Still keep polling for the always-on Quran stream if it is live
        final quranStillLive = _streamers
            .any((s) => s.streamerId == 'quran_4k_05' && s.isCurrentlyLive);
        if (!quranStillLive) _stopLiveViewerPolling();
      }
    }
    notifyListeners();
  }

  static String extractYouTubeId(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'dQw4w9WgXcQ';

    // Support youtube.com/live/VIDEO_ID format
    final liveMatch =
        RegExp(r'youtube\.com\/live\/([a-zA-Z0-9_-]{11})', caseSensitive: false)
            .firstMatch(trimmed);
    if (liveMatch != null) return liveMatch.group(1)!;

    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|live)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return trimmed.length == 11 ? trimmed : 'dQw4w9WgXcQ';
  }

  // Q&A Interaction Methods
  void submitQuestion(
      {required String text,
      required String authorName,
      String? authorAvatar}) {
    if (text.trim().isEmpty) return;
    final newQ = LectureQuestionModel(
      id: 'q_${DateTime.now().millisecondsSinceEpoch}',
      authorName: authorName.isNotEmpty ? authorName : _userProfile.nameEn,
      authorAvatar: authorAvatar ?? _userProfile.avatarUrl,
      questionText: text.trim(),
      timestamp: DateTime.now(),
      upvotes: 1,
      hasUpvoted: true,
    );
    _questions.insert(0, newQ);
    notifyListeners();
  }

  void toggleUpvoteQuestion(String questionId) {
    final idx = _questions.indexWhere((q) => q.id == questionId);
    if (idx != -1) {
      final q = _questions[idx];
      if (q.hasUpvoted) {
        q.upvotes = (q.upvotes - 1).clamp(0, 9999);
        q.hasUpvoted = false;
      } else {
        q.upvotes += 1;
        q.hasUpvoted = true;
      }
      notifyListeners();
    }
  }

  void markQuestionAnswered(String questionId) {
    final idx = _questions.indexWhere((q) => q.id == questionId);
    if (idx != -1) {
      _questions[idx].isAnsweredLive = true;
      notifyListeners();
    }
  }

  // RSVP / Physical Attendance
  bool isAttendingInPerson(String lectureId) =>
      _inPersonRsvpMap[lectureId] ?? false;
  int getAvailableSeats(String lectureId) =>
      _venueAvailableSeats[lectureId] ?? 25;

  void toggleInPersonAttendance(String lectureId) {
    final current = _inPersonRsvpMap[lectureId] ?? false;
    _inPersonRsvpMap[lectureId] = !current;
    final seats = _venueAvailableSeats[lectureId] ?? 25;
    if (!current) {
      _venueAvailableSeats[lectureId] = (seats - 1).clamp(0, 500);
    } else {
      _venueAvailableSeats[lectureId] = seats + 1;
    }
    notifyListeners();
  }

  // Bookmarks
  bool isBookmarked(String id) => _bookmarkedLectureIds.contains(id);
  void toggleBookmark(String id) {
    if (_bookmarkedLectureIds.contains(id)) {
      _bookmarkedLectureIds.remove(id);
    } else {
      _bookmarkedLectureIds.add(id);
    }
    notifyListeners();
  }

  // Notifications
  void markAllNotificationsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  // Chat & Stream Methods
  void forceReloadStream() {
    _streamReloadCount++;
    notifyListeners();
  }

  List<GhostComment> get chatMessages => List.unmodifiable(_chatMessages);

  void addChatMessage(GhostComment comment) {
    _chatMessages.insert(0, comment);
    notifyListeners();
  }

  void clearChatMessages() {
    _chatMessages.clear();
    notifyListeners();
  }

  void seedGhostChatIfNeeded({String streamId = 'stream_live_992'}) {
    if (_chatMessages.isEmpty) {
      _chatMessages = List.from(GhostCommentPool.rawComments.take(10));
      notifyListeners();
    }
  }

  Set<String> get followedStreamerIds => Set.unmodifiable(_followedStreamerIds);
  Set<String> get reminderStreamerIds => Set.unmodifiable(_reminderStreamerIds);

  List<StreamerModel> get filteredStreamers {
    return _streamers.where((s) {
      final matchesCategory = _currentCategoryFilter == 'all' ||
          s.categoryId == _currentCategoryFilter ||
          (_currentCategoryFilter == 'computer_science' &&
              (s.categoryId == 'cs_tech' ||
                  s.categoryId == 'computer_science')) ||
          (_currentCategoryFilter == 'cs_tech' &&
              (s.categoryId == 'cs_tech' ||
                  s.categoryId == 'computer_science')) ||
          (_currentCategoryFilter == 'islamic_studies' &&
              (s.categoryId == 'islamic_studies' ||
                  s.categoryId == 'sharia')) ||
          (_currentCategoryFilter == 'medicine' &&
              (s.categoryId == 'medicine' || s.categoryId == 'health')) ||
          (_currentCategoryFilter == 'engineering' &&
              (s.categoryId == 'engineering' || s.categoryId == 'innovation'));

      final matchesTag = _selectedTagFilter == 'all' ||
          s.tags.contains(_selectedTagFilter) ||
          s.tags
              .any((t) => t.toLowerCase() == _selectedTagFilter.toLowerCase());

      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          s.fullNameEn.toLowerCase().contains(query) ||
          s.fullNameAr.contains(query) ||
          s.organizationEn.toLowerCase().contains(query) ||
          s.organizationAr.contains(query) ||
          s.titleEn.toLowerCase().contains(query) ||
          s.titleAr.contains(query) ||
          s.tags.any((t) => t.toLowerCase().contains(query));

      return matchesCategory && matchesTag && matchesSearch;
    }).toList();
  }

  bool isFollowing(String streamerId) =>
      _followedStreamerIds.contains(streamerId);
  void toggleFollow(String streamerId) {
    if (_followedStreamerIds.contains(streamerId)) {
      _followedStreamerIds.remove(streamerId);
    } else {
      _followedStreamerIds.add(streamerId);
    }
    notifyListeners();
  }

  bool hasReminder(String streamerId) =>
      _reminderStreamerIds.contains(streamerId);
  bool isReminderSet(String streamerId) =>
      _reminderStreamerIds.contains(streamerId);
  void toggleReminder(String streamerId) {
    if (_reminderStreamerIds.contains(streamerId)) {
      _reminderStreamerIds.remove(streamerId);
    } else {
      _reminderStreamerIds.add(streamerId);
    }
    notifyListeners();
  }

  StreamerModel? get activeStreamer {
    try {
      return _streamers.firstWhere((s) => s.isCurrentlyLive);
    } catch (_) {
      return _streamers.isNotEmpty ? _streamers.first : null;
    }
  }

  void activatePitchDirectorMode() {
    setPitchDirectorMode(true);
  }

  void togglePitchDirectorMode() {
    setPitchDirectorMode(!_isPitchDirectorModeEnabled);
  }

  void setPitchDirectorMode(bool enabled) {
    _isPitchDirectorModeEnabled = enabled;
    _isBroadcastingLive = enabled;
    _streamers = _streamers.map((s) {
      if (s.streamerId == 'prof_alghamdi_01') {
        return s.copyWith(
          isCurrentlyLive: enabled,
          broadcastType: enabled ? _customBroadcastType : BroadcastType.offline,
          activeStreamId: enabled ? 'stream_live_992' : null,
          activeViewerCount: enabled ? 0 : 0,
        );
      }
      return s;
    }).toList();
    notifyListeners();
  }

  void togglePitchDirector() {
    setPitchDirectorMode(!_isPitchDirectorModeEnabled);
  }

  void setCityFilter(String cityId) {
    _selectedCityId = cityId;
    notifyListeners();
  }

  void setCategoryFilter(String categoryId) {
    _currentCategoryFilter = categoryId;
    notifyListeners();
  }

  void setSelectedTagFilter(String tag) {
    _selectedTagFilter = tag;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void updateRtmpLaptopIp(String newIp) {
    _rtmpLaptopIp = newIp.trim();
    notifyListeners();
  }

  void updatePhoneBroadcastTarget({
    required String rtmpUrl,
    required String streamKey,
  }) {
    _phoneBroadcastRtmpUrl = rtmpUrl.trim();
    _phoneBroadcastStreamKey = streamKey.trim();
    notifyListeners();
  }

  void setSelectedStreamingQuality(String quality) {
    _selectedStreamingQuality = quality;
    notifyListeners();
  }

  void setStreamingQuality(String quality) {
    _selectedStreamingQuality = quality;
    notifyListeners();
  }

  void triggerSimulatedNotification(BuildContext context) {
    addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_sim_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.streamerLiveVideo,
        streamerId: 'prof_alghamdi_01',
        streamerName: 'Amir Al-Hatemi',
        titleEn: '🔴 Live Broadcast Started',
        titleAr: '🔴 بدأ البث المباشر الآن',
        bodyEn: '🔴 Amir Al-Hatemi is live now: "$customLiveTitle" .. Join in!',
        bodyAr:
            '🔴 أمير الحاتمي بدأ بثاً مباشراً الآن: «$customLiveTitle».. حيّاك شاركنا وتفاعل!',
        timestamp: DateTime.now(),
        streamId: 'stream_live_992',
      ),
      context: context,
    );
  }

  // ==========================================
  // Admin & Broadcaster Application Actions
  // ==========================================

  Future<bool> approveBroadcasterApplication(
    String applicationId, {
    String? adminNotes,
    BuildContext? context,
    Function(int stage, String stageDescription)? onProgress,
  }) async {
    final idx = _applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;

    final app = _applications[idx];
    _adminDbService ??= await AdminDatabaseService.create();

    // Stage 1: Update Application Status and Backend Profile
    onProgress?.call(
        1, 'Updating application status & granting broadcaster credentials...');
    final updated = await _adminDbService!.updateApplicationStatus(
      applicationId,
      ApplicationStatus.approved,
      reviewNotes: adminNotes,
      reviewedBy: _googleUserName ?? 'Amir Al-Hatemi (Super Admin)',
    );

    if (updated != null) {
      _applications = List.from(await _adminDbService!.loadApplications());
    }

    final applicantProfileId =
        updated?.applicantProfileId ?? app.applicantProfileId;
    String? realOrgId;
    if (applicantProfileId != null) {
      try {
        _adminDbService ??= await AdminDatabaseService.create();
        if (app.isOrganization) {
          realOrgId = await _adminDbService!
              .createOrganizationFromApplication(app, applicantProfileId);
        } else {
          await _adminDbService!.markProfileAsStreamer(applicantProfileId, app);
        }
      } catch (e) {
        debugPrint('Real org/profile creation on approval failed: $e');
      }
    }

    // Stage 2: Create StreamerModel & Inject into Discovery Feed
    onProgress?.call(
        2, 'Creating Broadcaster card & integrating into Discovery Feed...');
    final newStreamer = StreamerModel(
      streamerId: realOrgId ?? applicantProfileId ?? 'streamer_${app.id}',
      fullNameEn: app.applicantNameEn,
      fullNameAr: app.applicantNameAr,
      titleEn: app.academicTitleEn ??
          (app.isOrganization ? 'Educational Institution' : 'Academic Scholar'),
      titleAr: app.academicTitleAr ??
          (app.isOrganization ? 'مؤسسة تعليمية وقاعة' : 'محاضر وباحث أكاديمي'),
      organizationEn: app.institutionEn ?? app.applicantNameEn,
      organizationAr: app.institutionAr ?? app.applicantNameAr,
      avatarUrl: app.avatarUrl,
      bannerUrl: app.bannerUrl,
      bioEn: app.bioEn,
      bioAr: app.bioAr,
      isVerified: true,
      followerCount: 0,
      categoryId: app.categoryId,
      tags: app.tags,
      cityEn: 'Al Khobar',
      cityAr: 'الخبر',
      venueNameEn: app.venueNameEn,
      venueNameAr: app.venueNameAr,
      latitude: app.latitude != 0.0 ? app.latitude : 26.2871,
      longitude: app.longitude != 0.0 ? app.longitude : 50.2125,
      isCurrentlyLive: false,
      broadcastType: BroadcastType.offline,
      isOrganization: app.isOrganization,
      youtubeHandle: app.youtubeHandle,
      youtubeVideoId: 'dQw4w9WgXcQ',
    );

    final streamerIdx =
        _streamers.indexWhere((s) => s.streamerId == newStreamer.streamerId);
    if (streamerIdx != -1) {
      _streamers[streamerIdx] = newStreamer;
    } else {
      _streamers.add(newStreamer);
    }
    notifyListeners();

    // Stage 3: Background YouTube Channel Video & Playlist Sync
    onProgress?.call(
        3, 'Resolving YouTube channel uploads & video archives...');
    try {
      final cleanHandle = app.youtubeHandle.replaceFirst('@', '').trim();
      if (cleanHandle.isNotEmpty) {
        final uploads = await _youTubeService.fetchChannelVideos(
          streamerId: newStreamer.streamerId,
          handle: cleanHandle,
          maxResults: 10,
        );
        if (uploads.isNotEmpty) {
          final latestVideoId = uploads.first.youtubeVideoId;
          final sIdx = _streamers
              .indexWhere((s) => s.streamerId == newStreamer.streamerId);
          if (sIdx != -1) {
            _streamers[sIdx] =
                _streamers[sIdx].copyWith(youtubeVideoId: latestVideoId);
          }
        }
      }
    } catch (e) {
      debugPrint('Background YouTube bootstrap failed gracefully: $e');
    }

    // Stage 4: Plot on Spatial Map & Send Realtime Notification
    onProgress?.call(4,
        'Plotting venue location on Spatial Map & dispatching notification...');
    addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_verified_${app.id}',
        type: NotificationType.streamerApplicationApproved,
        streamerId: newStreamer.streamerId,
        streamerName: app.applicantNameEn,
        titleEn: '🎉 Broadcaster Application Approved!',
        titleAr: '🎉 أهلاً بك في نخبة المذيعين!',
        bodyEn:
            'Congratulations ${app.applicantNameEn}! Your broadcaster application has been approved and verified on the map.',
        bodyAr:
            'تهانينا ${app.applicantNameAr}! تم اعتماد طلبك بنجاح. أصبحت قناتك وموقعك موثقين على الخريطة التفاعلية.',
        timestamp: DateTime.now(),
        actionUrl: '/profile/${newStreamer.streamerId}',
      ),
      context: context != null && context.mounted ? context : null,
    );

    // Stage 5: Finalization
    onProgress?.call(5, 'Verification pipeline completed successfully!');
    notifyListeners();
    return true;
  }

  Future<bool> rejectBroadcasterApplication(
    String applicationId, {
    required String reason,
    BuildContext? context,
  }) async {
    final idx = _applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;

    final app = _applications[idx];
    _adminDbService ??= await AdminDatabaseService.create();
    final reviewer = (isAdminUser && _googleUserName != null)
        ? '$_googleUserName (Super Admin)'
        : 'Amir Al-Hatemi (Super Admin)';
    final updated = await _adminDbService!.updateApplicationStatus(
      applicationId,
      ApplicationStatus.rejected,
      reviewNotes: reason,
      reviewedBy: reviewer,
    );

    if (updated != null) {
      _applications = List.from(await _adminDbService!.loadApplications());

      addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_rejected_${applicationId}_${DateTime.now().millisecondsSinceEpoch}',
          type: NotificationType.streamerApplicationRejected,
          streamerId: applicationId,
          streamerName: app.applicantNameEn,
          titleEn: '📋 Broadcaster Application Status Update',
          titleAr: '📋 تحديث بخصوص طلب التوثيق الأكاديمي',
          bodyEn:
              'Thank you for applying. We could not approve the application at this time: "$reason". You are welcome to re-apply anytime!',
          bodyAr:
              'نشكر اهتمامك بالانضمام لمنصتنا. بعد المراجعة الدقيقة، تعذر قبول الطلب حالياً للملاحظات التالية: «$reason». يسعدنا تقديمك مجدداً بعد التعديل!',
          timestamp: DateTime.now(),
        ),
        context: context != null && context.mounted ? context : null,
      );

      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteBroadcasterApplication(String applicationId) async {
    final idx = _applications.indexWhere((a) => a.id == applicationId);
    _adminDbService ??= await AdminDatabaseService.create();
    final success = await _adminDbService!.deleteApplication(applicationId);
    if (success) {
      if (idx != -1) _applications.removeAt(idx);
      _streamers.removeWhere((s) =>
          s.streamerId == applicationId ||
          s.streamerId == 'streamer_$applicationId');
      await loadVerifiedStreamersFromBackend();
      notifyListeners();
    }
    return success;
  }

  /// Batch approve for the verification queue's multi-select (v0.8
  /// Checkpoint 2 Phase 2). Deliberately loops the existing single-item
  /// approveBroadcasterApplication rather than a bulk SQL update, so every
  /// approval still gets its real org/streamer-profile creation and
  /// notification side effects, not just a status flip.
  Future<({int succeeded, int failed})> bulkApproveBroadcasterApplications(
    List<String> applicationIds, {
    String? adminNotes,
    BuildContext? context,
  }) async {
    int succeeded = 0;
    int failed = 0;
    for (final id in applicationIds) {
      final success = await approveBroadcasterApplication(
        id,
        adminNotes: adminNotes,
        context: context,
      );
      if (success) {
        succeeded++;
      } else {
        failed++;
      }
    }
    return (succeeded: succeeded, failed: failed);
  }

  /// Batch reject counterpart to [bulkApproveBroadcasterApplications] --
  /// same reasoning: loops rejectBroadcasterApplication per id so every
  /// applicant still gets their real rejection notification.
  Future<({int succeeded, int failed})> bulkRejectBroadcasterApplications(
    List<String> applicationIds, {
    required String reason,
    BuildContext? context,
  }) async {
    int succeeded = 0;
    int failed = 0;
    for (final id in applicationIds) {
      final success = await rejectBroadcasterApplication(
        id,
        reason: reason,
        context: context,
      );
      if (success) {
        succeeded++;
      } else {
        failed++;
      }
    }
    return (succeeded: succeeded, failed: failed);
  }

  Future<void> updateTermsAndConditions(
      TermsAndConditionsModel newTerms) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.saveTerms(newTerms);
    _termsAndConditions = newTerms;
    notifyListeners();
  }

  Future<void> updateViewerAnalytics(ViewerAnalyticsModel newAnalytics) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.saveAnalytics(newAnalytics);
    _viewerAnalytics = newAnalytics;
    notifyListeners();
  }

  // ==========================================
  // Organizations & Audit Logs Methods
  // ==========================================

  List<OrgAuditLogEntry> get auditLogs => List.unmodifiable(_auditLogs);

  List<OrgAuditLogEntry> getOrganizationAuditLogs([String? organizationId]) {
    if (organizationId != null && organizationId.isNotEmpty) {
      return _auditLogs
          .where((l) => l.organizationId == organizationId)
          .toList();
    }
    return List.unmodifiable(_auditLogs);
  }

  Future<void> recordOrgAuditAction(OrgAuditLogEntry entry) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.recordAuditLog(entry);
    _auditLogs.insert(0, entry);
    notifyListeners();
  }

  /// Prefetches an organization's real venues/speakers from Supabase, for
  /// orgIds that have a real backend row (Checkpoint 3 Phase 2). No-ops for
  /// the mock demo orgs, which have no backend row and keep being served
  /// straight from _streamers. Safe to call repeatedly; call it from a
  /// screen's initState (e.g. OrgManagementView) before reading
  /// getOrganizationVenues/getOrganizationSpeakers.
  Future<void> ensureOrgDataLoaded(String orgId) async {
    if (_orgDataLoaded.contains(orgId)) return;
    _orgDataLoaded.add(orgId);
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      // _streamers only gets a real org appended at the moment its
      // application is approved, in that same session (see
      // approveBroadcasterApplication) -- nothing bulk-loads every real
      // organization on app start, so a Permitted Admin returning on a
      // fresh session would otherwise hit "Organization not found" for
      // their own real org even though RLS would let them manage it (v0.8
      // Checkpoint 3 Phase 1). Seed it from the real backend if missing.
      if (getStreamerById(orgId) == null) {
        final orgRow = await _adminDbService!.loadOrganizationProfile(orgId);
        if (orgRow != null) {
          _streamers.add(_streamerFromOrganizationRow(orgRow));
        }
      }
      final venues = await _adminDbService!.loadOrgVenues(orgId);
      final speakers = await _adminDbService!.loadOrgSpeakers(orgId);
      if (venues.isNotEmpty) _realOrgVenues[orgId] = venues;
      if (speakers.isNotEmpty) _realOrgSpeakers[orgId] = speakers;
      notifyListeners();
    } catch (e) {
      debugPrint('ensureOrgDataLoaded($orgId) failed: $e');
    }
  }

  StreamerModel _streamerFromOrganizationRow(Map<String, dynamic> row) {
    final nameEn = row['name_en'] as String? ?? 'Organization';
    final nameAr = row['name_ar'] as String? ?? nameEn;
    return StreamerModel(
      streamerId: row['id'] as String,
      fullNameEn: nameEn,
      fullNameAr: nameAr,
      titleEn: 'Educational Institution',
      titleAr: 'مؤسسة تعليمية وقاعة',
      organizationEn: nameEn,
      organizationAr: nameAr,
      avatarUrl: row['avatar_url'] as String? ?? '',
      bannerUrl: row['banner_url'] as String? ?? '',
      bioEn: row['bio_en'] as String? ?? '',
      bioAr: row['bio_ar'] as String? ?? '',
      isVerified: row['is_verified'] as bool? ?? false,
      followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
      categoryId: row['category_id'] as String? ?? 'general',
      tags: List<String>.from(row['tags'] as List? ?? const []),
      cityEn: '',
      cityAr: '',
      venueNameEn: '',
      venueNameAr: '',
      latitude: 0,
      longitude: 0,
      isCurrentlyLive: row['is_currently_live'] as bool? ?? false,
      isOrganization: true,
      youtubeHandle: row['youtube_handle'] as String? ?? '',
    );
  }

  List<OrgVenueBranchModel> getOrganizationVenues(String orgId) {
    final real = _realOrgVenues[orgId];
    if (real != null) return real;
    final streamer = getStreamerById(orgId);
    return streamer?.venues ?? const [];
  }

  List<OrgSpeakerModel> getOrganizationSpeakers(String orgId) {
    final real = _realOrgSpeakers[orgId];
    if (real != null) return real;
    final streamer = getStreamerById(orgId);
    return streamer?.affiliatedSpeakers ?? const [];
  }

  // ==========================================
  // Role & Permission Management (v0.8 Checkpoint 2 Phase 3)
  // ==========================================

  List<AdminRoleAssignmentModel> get roleAssignments =>
      List.unmodifiable(_roleAssignments);

  Set<String> permissionsForProfile(String profileId) =>
      _userPermissionsByProfile[profileId] ?? const {};

  /// Loads every user_roles/user_permissions row for the Role & Permission
  /// Management tab. Call from that tab's initState; safe to call
  /// repeatedly (only hits the backend once per app session, same caching
  /// shape as ensureOrgDataLoaded).
  Future<void> ensureRoleManagementDataLoaded() async {
    if (_roleManagementLoaded) return;
    _roleManagementLoaded = true;
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      final assignments = await _adminDbService!.loadAdminRoleAssignments();
      final permissions = await _adminDbService!.loadUserPermissionsByProfile();
      _roleAssignments = assignments;
      _userPermissionsByProfile = permissions;
      notifyListeners();
    } catch (e) {
      debugPrint('ensureRoleManagementDataLoaded failed: $e');
    }
  }

  Future<void> _refreshRoleManagementData() async {
    _adminDbService ??= await AdminDatabaseService.create();
    _roleAssignments = await _adminDbService!.loadAdminRoleAssignments();
    _userPermissionsByProfile =
        await _adminDbService!.loadUserPermissionsByProfile();
    notifyListeners();
  }

  /// Looks up a profile by exact email, for the "grant a role" search field.
  Future<Map<String, dynamic>?> findProfileByEmail(String email) async {
    _adminDbService ??= await AdminDatabaseService.create();
    return _adminDbService!.findProfileByEmail(email);
  }

  /// Grants a platform-wide role (master_admin/admin). Throws on failure --
  /// the Master-Admin-only UI that calls this shows the error directly
  /// rather than silently no-op'ing, since a failed grant should be obvious.
  Future<void> grantAdminRole({
    required String profileId,
    required String role,
  }) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.grantUserRole(profileId: profileId, role: role);
    await _refreshRoleManagementData();
  }

  Future<void> revokeAdminRole({
    required String profileId,
    required String role,
    String? organizationId,
  }) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.revokeUserRole(
      profileId: profileId,
      role: role,
      organizationId: organizationId,
    );
    await _refreshRoleManagementData();
  }

  Future<void> setUserPermission({
    required String profileId,
    required String capability,
    required bool granted,
  }) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.setUserPermission(
      profileId: profileId,
      capability: capability,
      granted: granted,
    );
    await _refreshRoleManagementData();
  }

  // ==========================================
  // Chat Moderation Dashboard (v0.8 Checkpoint 4 Phase 1)
  // ==========================================

  List<ChatReportModel> get chatReports => List.unmodifiable(_chatReports);

  /// Loads the open chat_reports queue. Call from the moderation tab's
  /// initState; safe to call repeatedly (only hits the backend once per app
  /// session, same caching shape as ensureRoleManagementDataLoaded).
  Future<void> ensureChatReportsLoaded() async {
    if (_chatReportsLoaded) return;
    _chatReportsLoaded = true;
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      _chatReports = await _adminDbService!.loadChatReports();
      notifyListeners();
    } catch (e) {
      debugPrint('ensureChatReportsLoaded failed: $e');
    }
  }

  Future<void> _refreshChatReports() async {
    _adminDbService ??= await AdminDatabaseService.create();
    _chatReports = await _adminDbService!.loadChatReports();
    notifyListeners();
  }

  Future<void> dismissChatReport(String reportId) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.dismissChatReport(reportId);
    await _refreshChatReports();
  }

  /// Deletes the reported message -- propagates to every viewer's live chat
  /// via chat_messages' postgres_changes DELETE event, the same mechanism
  /// LiveChatController.deleteMessage uses; no separate broadcast needed
  /// since Realtime replicates the DELETE to every subscribed client
  /// regardless of which client issued it.
  Future<void> deleteChatMessageAndResolveReport(ChatReportModel report) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.deleteChatMessageAndResolveReport(
      messageId: report.messageId,
      reportId: report.id,
    );
    await _refreshChatReports();
  }

  Future<void> muteChatSenderAndResolveReport(ChatReportModel report) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.muteChatSenderAndResolveReport(
      streamId: report.streamId,
      senderId: report.reportedSenderId,
      reportId: report.id,
    );
    await _refreshChatReports();
  }

  /// Best-effort Supabase write-through for org venue/speaker mutations --
  /// no-ops (with a debug log) for orgIds without a real backend row, since
  /// _streamers is always updated separately by the caller regardless.
  Future<void> _writeThroughOrgSpeaker(
      String orgId, OrgSpeakerModel speaker) async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      await _adminDbService!.upsertOrgSpeaker(orgId, speaker);
      final cached = _realOrgSpeakers[orgId];
      if (cached != null) {
        final list = List<OrgSpeakerModel>.from(cached);
        final idx = list.indexWhere((s) => s.speakerId == speaker.speakerId);
        if (idx != -1) {
          list[idx] = speaker;
        } else {
          list.add(speaker);
        }
        _realOrgSpeakers[orgId] = list;
      }
    } catch (e) {
      debugPrint('Supabase org speaker write-through failed: $e');
    }
  }

  Future<void> _writeThroughOrgVenue(
      String orgId, OrgVenueBranchModel venue) async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      await _adminDbService!.upsertOrgVenue(orgId, venue);
      final cached = _realOrgVenues[orgId];
      if (cached != null) {
        final list = List<OrgVenueBranchModel>.from(cached);
        final idx = list.indexWhere((v) => v.venueId == venue.venueId);
        if (idx != -1) {
          list[idx] = venue;
        } else {
          list.add(venue);
        }
        _realOrgVenues[orgId] = list;
      }
    } catch (e) {
      debugPrint('Supabase org venue write-through failed: $e');
    }
  }

  Future<void> _writeThroughDeleteOrgSpeaker(
      String orgId, String speakerId) async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      await _adminDbService!.deleteOrgSpeaker(speakerId);
      _realOrgSpeakers[orgId]?.removeWhere((s) => s.speakerId == speakerId);
    } catch (e) {
      debugPrint('Supabase org speaker delete write-through failed: $e');
    }
  }

  Future<void> _writeThroughDeleteOrgVenue(String orgId, String venueId) async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      await _adminDbService!.deleteOrgVenue(venueId);
      _realOrgVenues[orgId]?.removeWhere((v) => v.venueId == venueId);
    } catch (e) {
      debugPrint('Supabase org venue delete write-through failed: $e');
    }
  }

  Future<void> updateSpeakerPermissions(
    String orgId,
    String speakerId,
    OrgBroadcasterPermissions newPermissions,
  ) async {
    final streamerIdx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (streamerIdx == -1) return;

    final currentOrg = _streamers[streamerIdx];
    final speakerIdx = currentOrg.affiliatedSpeakers
        .indexWhere((s) => s.speakerId == speakerId);
    if (speakerIdx == -1) return;

    final updatedSpeakers =
        List<OrgSpeakerModel>.from(currentOrg.affiliatedSpeakers);
    final currentSpeaker = updatedSpeakers[speakerIdx];
    updatedSpeakers[speakerIdx] =
        currentSpeaker.copyWith(permissions: newPermissions);

    _streamers[streamerIdx] =
        currentOrg.copyWith(affiliatedSpeakers: updatedSpeakers);
    await _writeThroughOrgSpeaker(orgId, updatedSpeakers[speakerIdx]);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.grantBroadcastPermission,
        descriptionEn:
            'Updated broadcast permissions for speaker ${currentSpeaker.nameEn}.',
        descriptionAr: 'تم تحديث صلاحيات البث للمدرب ${currentSpeaker.nameAr}.',
        metadata: {
          'speaker_id': speakerId,
          'permissions': newPermissions.toJson(),
        },
      ),
    );

    notifyListeners();
  }

  bool canUserBroadcastForOrg(String orgId, String? userEmail) {
    if (userEmail == null || userEmail.isEmpty) return false;
    final emailLower = userEmail.trim().toLowerCase();

    // Super Admin can broadcast for any org
    if (emailLower == _googleUserEmail?.trim().toLowerCase() && isAdminUser) {
      return true;
    }

    final streamer = getStreamerById(orgId);
    if (streamer == null || !streamer.isOrganization) return false;

    // Check if user is an affiliated speaker with canGoLiveVideo or canGoAudioOnly
    final speaker = streamer.affiliatedSpeakers.firstWhere(
      (s) => (s.linkedEmail?.trim().toLowerCase() == emailLower),
      orElse: () => const OrgSpeakerModel(
        speakerId: '',
        nameEn: '',
        nameAr: '',
        roleOrTitleEn: '',
        roleOrTitleAr: '',
        avatarUrl: '',
        bioEn: '',
        bioAr: '',
        isPermanentStaff: false,
        permissions: OrgBroadcasterPermissions(
          canGoLiveVideo: false,
          canGoAudioOnly: false,
        ),
      ),
    );

    if (speaker.speakerId.isNotEmpty) {
      return speaker.permissions.canGoLiveVideo ||
          speaker.permissions.canGoAudioOnly;
    }

    return false;
  }

  Future<void> addOrganizationBranch(
      String orgId, OrgVenueBranchModel branch) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedVenues = List<OrgVenueBranchModel>.from(currentOrg.venues)
      ..add(branch);
    _streamers[idx] = currentOrg.copyWith(venues: updatedVenues);
    await _writeThroughOrgVenue(orgId, branch);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.addVenueBranch,
        descriptionEn:
            'Added new campus branch: ${branch.nameEn} (${branch.cityEn}).',
        descriptionAr:
            'تمت إضافة فرع جديد: ${branch.nameAr} (${branch.cityAr}).',
        metadata: branch.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> updateOrganizationBranch(
      String orgId, OrgVenueBranchModel branch) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedVenues = currentOrg.venues
        .map((v) => v.venueId == branch.venueId ? branch : v)
        .toList();
    _streamers[idx] = currentOrg.copyWith(venues: updatedVenues);
    await _writeThroughOrgVenue(orgId, branch);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.updateVenueBranch,
        descriptionEn: 'Updated campus branch: ${branch.nameEn}.',
        descriptionAr: 'تم تحديث بيانات الفرع: ${branch.nameAr}.',
        metadata: branch.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> deleteOrganizationBranch(String orgId, String venueId) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final removed = currentOrg.venues.firstWhere(
      (v) => v.venueId == venueId,
      orElse: () => const OrgVenueBranchModel(
          venueId: '',
          nameEn: '',
          nameAr: '',
          cityEn: '',
          cityAr: '',
          latitude: 0,
          longitude: 0,
          seatingCapacity: 0),
    );
    final updatedVenues =
        currentOrg.venues.where((v) => v.venueId != venueId).toList();
    _streamers[idx] = currentOrg.copyWith(venues: updatedVenues);
    await _writeThroughDeleteOrgVenue(orgId, venueId);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.removeVenueBranch,
        descriptionEn:
            'Removed campus branch: ${removed.nameEn.isNotEmpty ? removed.nameEn : venueId}.',
        descriptionAr:
            'تم حذف الفرع: ${removed.nameAr.isNotEmpty ? removed.nameAr : venueId}.',
        metadata: {'venue_id': venueId},
      ),
    );
    notifyListeners();
  }

  Future<void> addOrganizationSpeaker(
      String orgId, OrgSpeakerModel speaker) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedSpeakers =
        List<OrgSpeakerModel>.from(currentOrg.affiliatedSpeakers)..add(speaker);
    _streamers[idx] = currentOrg.copyWith(affiliatedSpeakers: updatedSpeakers);
    await _writeThroughOrgSpeaker(orgId, speaker);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.addSpeakerToRoster,
        descriptionEn:
            'Added instructor to roster: ${speaker.nameEn} (${speaker.roleOrTitleEn}).',
        descriptionAr:
            'تمت إضافة مدرب إلى الكادر: ${speaker.nameAr} (${speaker.roleOrTitleAr}).',
        metadata: speaker.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> updateOrganizationSpeaker(
      String orgId, OrgSpeakerModel speaker) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedSpeakers = currentOrg.affiliatedSpeakers
        .map((s) => s.speakerId == speaker.speakerId ? speaker : s)
        .toList();
    _streamers[idx] = currentOrg.copyWith(affiliatedSpeakers: updatedSpeakers);
    await _writeThroughOrgSpeaker(orgId, speaker);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.updateSpeakerDetails,
        descriptionEn: 'Updated instructor details: ${speaker.nameEn}.',
        descriptionAr: 'تم تحديث بيانات المدرب: ${speaker.nameAr}.',
        metadata: speaker.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> deleteOrganizationSpeaker(String orgId, String speakerId) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final removed = currentOrg.affiliatedSpeakers.firstWhere(
      (s) => s.speakerId == speakerId,
      orElse: () => const OrgSpeakerModel(
          speakerId: '',
          nameEn: '',
          nameAr: '',
          roleOrTitleEn: '',
          roleOrTitleAr: '',
          avatarUrl: '',
          bioEn: '',
          bioAr: ''),
    );
    final updatedSpeakers = currentOrg.affiliatedSpeakers
        .where((s) => s.speakerId != speakerId)
        .toList();
    _streamers[idx] = currentOrg.copyWith(affiliatedSpeakers: updatedSpeakers);
    await _writeThroughDeleteOrgSpeaker(orgId, speakerId);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: newId(),
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.removeSpeakerFromRoster,
        descriptionEn:
            'Removed instructor from roster: ${removed.nameEn.isNotEmpty ? removed.nameEn : speakerId}.',
        descriptionAr:
            'تم حذف المدرب من الكادر: ${removed.nameAr.isNotEmpty ? removed.nameAr : speakerId}.',
        metadata: {'speaker_id': speakerId},
      ),
    );
    notifyListeners();
  }

  // =========================================================================
  // 🔔 14 Humanized Notification Event Dispatchers (Saudi Arabic & English)
  // =========================================================================

  /// Trigger 6: Org Invite to Join Live as Guest Speaker
  bool notifyOrgGuestInvite({
    required String orgNameEn,
    required String orgNameAr,
    required String streamTitle,
    BuildContext? context,
  }) {
    return addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_guest_inv_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.orgLiveGuestInvite,
        streamerName: orgNameEn,
        titleEn: '🎤 Live Guest Speaker Invitation',
        titleAr: '🎤 دعوة للمشاركة كمتحدث ضيف',
        bodyEn:
            '$orgNameEn invited you as a guest speaker on their live broadcast: "$streamTitle". Tap to join the stage!',
        bodyAr:
            'تدعوك $orgNameAr للمشاركة كمتحدث ضيف في البث المباشر: «$streamTitle». اضغط للانضمام للمسرح والتفاعل!',
        timestamp: DateTime.now(),
        streamId: 'stream_live_992',
      ),
      context: context,
    );
  }

  /// Trigger 7: Org Invites Streamer to Join Roster
  bool notifyOrgAffiliationInvite({
    required String orgNameEn,
    required String orgNameAr,
    BuildContext? context,
  }) {
    return addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_aff_inv_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.orgAffiliationInvite,
        streamerName: orgNameEn,
        titleEn: '🏛️ Faculty Affiliation Invitation',
        titleAr: '🏛️ دعوة انضمام للكادر التعليمي',
        bodyEn:
            '$orgNameEn sent you an official invitation to join their accredited faculty roster.',
        bodyAr:
            'وجّهت لك $orgNameAr دعوة رسمية للانضمام إلى كادرها التعليمي ومدرجاتها المعتمدة.',
        timestamp: DateTime.now(),
        actionUrl: '/settings',
      ),
      context: context,
    );
  }

  /// Trigger 8: Streamer Removed from Org Roster
  bool notifyStreamerRemovedFromOrg({
    required String orgNameEn,
    required String orgNameAr,
    BuildContext? context,
  }) {
    return addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_aff_rem_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.streamerRemovedFromOrg,
        streamerName: orgNameEn,
        titleEn: 'ℹ️ Organization Affiliation Updated',
        titleAr: 'ℹ️ تحديث الارتباط الأكاديمي',
        bodyEn:
            'Your affiliation with $orgNameEn has concluded. Your independent channel and verified profile remain fully active.',
        bodyAr:
            'نفيدك بتحديث كادر $orgNameAr وانتهاء الارتباط مع مدرجات الجهة. حسابك ومحتواك مستقل ومستمر بالكامل.',
        timestamp: DateTime.now(),
      ),
      context: context,
    );
  }

  /// Trigger 9: Admin Note to Streamer
  bool notifyAdminNoteToStreamer({
    required String noteEn,
    required String noteAr,
    BuildContext? context,
  }) {
    return addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_adm_str_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.adminNoteToStreamer,
        titleEn: '📩 Administrative Note from Streamer Team',
        titleAr: '📩 رسالة إدارية من فريق المنصة',
        bodyEn: 'Administrative guidance regarding your channel: "$noteEn"',
        bodyAr: 'توجيه إداري بخصوص قناتك وبثوثك: «$noteAr»',
        timestamp: DateTime.now(),
      ),
      context: context,
    );
  }

  /// Trigger 10: Admin Card Edit Request to Streamer
  bool notifyAdminCardEditRequestStreamer({
    required String fieldsEn,
    required String fieldsAr,
    BuildContext? context,
  }) {
    return addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_adm_card_str_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.adminCardEditRequestStreamer,
        titleEn: '✏️ Profile Card Update Requested',
        titleAr: '✏️ مطلوب مراجعة بيانات البطاقة التعريفية',
        bodyEn:
            'Please update your profile details ($fieldsEn) to match verification standards.',
        bodyAr:
            'يرجى تحديث بعض بيانات بطاقتك ($fieldsAr) لتتوافق مع معايير التوثيق الأكاديمي المعتمدة.',
        timestamp: DateTime.now(),
        actionUrl: '/settings',
      ),
      context: context,
    );
  }

  /// Trigger 11: Admin Note to Organization
  bool notifyAdminNoteToOrg({
    required String orgNameEn,
    required String orgNameAr,
    required String noteEn,
    required String noteAr,
    BuildContext? context,
  }) {
    return addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_adm_org_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.adminNoteToOrg,
        streamerName: orgNameEn,
        titleEn: '📩 Administrative Message for $orgNameEn',
        titleAr: '📩 رسالة إدارية موجهة لـ $orgNameAr',
        bodyEn: 'Message from platform administration: "$noteEn"',
        bodyAr: 'رسالة إدارية موجهة لإدارة المنظمة: «$noteAr»',
        timestamp: DateTime.now(),
      ),
      context: context,
    );
  }

  /// Trigger 12: Admin Card Edit Request to Organization
  bool notifyAdminCardEditRequestOrg({
    required String orgNameEn,
    required String orgNameAr,
    required String branchNameEn,
    required String branchNameAr,
    BuildContext? context,
  }) {
    return addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_adm_card_org_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.adminCardEditRequestOrg,
        streamerName: orgNameEn,
        titleEn: '✏️ Campus Branch Details Review',
        titleAr: '✏️ إشعار تنظيمي لتحديث بيانات المدرج',
        bodyEn:
            'Please review and update location specifications for branch "$branchNameEn".',
        bodyAr:
            'مطلوب مراجعة وتحديث بيانات فرع أو مدرج «$branchNameAr» المعتمد لدى $orgNameAr.',
        timestamp: DateTime.now(),
        actionUrl: '/settings',
      ),
      context: context,
    );
  }

  /// Trigger 14: Followed Streamer New VOD Upload
  bool notifyNewVodUpload({
    required String streamerId,
    required String streamerNameEn,
    required String streamerNameAr,
    required String vodTitleEn,
    required String vodTitleAr,
    required String videoId,
    BuildContext? context,
  }) {
    return addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_vod_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.newVodUpload,
        streamerId: streamerId,
        streamerName: streamerNameEn,
        titleEn: '🎬 New Lecture Added by $streamerNameEn',
        titleAr: '🎬 محاضرة جديدة أضافها $streamerNameAr',
        bodyEn: 'New lecture: "$vodTitleEn" is now available to watch!',
        bodyAr: 'فيديو ومحاضرة جديدة: «$vodTitleAr».. شاهدها الآن واستفد!',
        timestamp: DateTime.now(),
        actionUrl: '/profile/$streamerId',
        metadata: {'video_id': videoId},
      ),
      context: context,
    );
  }
}
