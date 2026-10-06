import '../services/youtube_channel_reference.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_toast_overlay.dart';
import '../services/notifications/notification_models.dart';
import '../services/youtube_api_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/admin_database_service.dart';
import '../services/organization_broadcast_service.dart';
import '../../features/organization/models/org_membership.dart';
import '../../features/organization/models/channel_connection.dart';
import '../../features/organization/models/org_event.dart';
import '../../features/organization/models/org_event_text.dart';
import '../../features/organization/models/org_invitation.dart';
import '../../features/live_stream/models/broadcast_session.dart';
import '../services/upcoming_schedule_service.dart';
import '../services/reminder_push_service.dart';
import '../services/connectivity_service.dart';
import '../services/public_catalog_cache.dart';
import '../utils/id_generator.dart';
import '../../features/map/models/map_models.dart';
import '../../features/map/models/map_tricity_domain.dart';
import '../../features/organization/models/org_speaker_model.dart';
import '../../features/organization/models/org_venue_branch_model.dart';
import '../../features/organization/models/org_broadcaster_permissions.dart';
import '../../features/organization/models/org_audit_log_entry.dart';
import '../../features/organization/models/org_affiliation_request_model.dart';
import '../../features/profile/models/streamer_models.dart';
import '../../features/profile/models/upcoming_schedule.dart';
import '../../features/profile/models/vod_models.dart';
import '../../features/profile/models/user_account_model.dart';
import '../../features/live_stream/models/qa_question_model.dart';
import '../../features/live_stream/models/stream_privacy_models.dart';
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
import '../../features/discovery/models/bookmark_entry.dart';
import '../models/device_session_model.dart';
import 'app_flags.dart';
import '../config/feature_flags.dart';
import '../../features/live_stream/services/stream_decay_engine.dart';
import '../../features/live_stream/services/chat_block_list.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, visibleForTesting;

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
bool _looksLikeUuid(String? value) =>
    value != null && _uuidPattern.hasMatch(value);

class AppProvider extends ChangeNotifier {
  // Directory results are screen-scoped, not cached across account changes.
  Future<List<Map<String, dynamic>>> searchAdminUsers(
      String query, int offset) async {
    if (!isAdminUser) throw StateError('Not permitted');
    _adminDbService ??= await AdminDatabaseService.create();
    return _adminDbService!.searchAdminUsers(query, offset);
  }

  Future<Map<String, dynamic>> loadAdminUserDetail(String id) async {
    if (!isAdminUser) throw StateError('Not permitted');
    _adminDbService ??= await AdminDatabaseService.create();
    return _adminDbService!.loadAdminUserDetail(id);
  }

  Future<void> updateAdminAccount(
      String id, String action, String reason) async {
    if (!isAdminUser) throw StateError('Not permitted');
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.updateAdminAccount(id, action, reason);
    if (action == 'delete_account') purgeDeletedAccountFromCaches(id);
    await _refreshBannedUsers();
    await refreshAdminData();
    if (action == 'delete_account' ||
        action == 'force_end' ||
        action == 'remove_from_feed') {
      await loadVerifiedStreamersFromBackend();
    }
  }

  /// Hides a live broadcast from app discovery or lists it again. Not access
  /// control: the broadcast, its viewers and its links are unaffected.
  Future<void> setStreamDiscovery(
      String profileId, bool hidden, String reason) async {
    if (!isAdminUser) throw StateError('Not permitted');
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.setStreamDiscovery(profileId, hidden, reason);
    await refreshAdminData();
  }

  /// Drops every client-side trace of an account the server has just
  /// deleted (P6), so no screen keeps offering a follow, a mini-player, a
  /// report or a role row for a profile that no longer exists. Called only
  /// after the server confirmed the deletion; the backend reload that follows
  /// is what other lists rely on, and this covers the time until it lands or
  /// the case where it fails.
  void purgeDeletedAccountFromCaches(String profileId) {
    bool matches(String id) => id == profileId || id == 'streamer_$profileId';
    final removedVideoIds = {
      for (final s in _streamers)
        if (matches(s.streamerId)) ...[
          if (s.youtubeVideoId.isNotEmpty) s.youtubeVideoId,
          if (s.activeStreamId?.isNotEmpty == true) s.activeStreamId!,
        ],
    };
    _streamers.removeWhere((s) => matches(s.streamerId));
    _lastLoadedPublicStreamers?.removeWhere((s) => matches(s.streamerId));
    _cachedMapMarkers.removeWhere((m) => matches(m.streamerId));
    _followedStreamerIds.removeWhere(matches);
    _reminderStreamerIds.removeWhere(matches);
    _chatReports.removeWhere(
        (r) => r.reportedSenderId == profileId || r.reporterId == profileId);
    _roleAssignments.removeWhere((r) => r.profileId == profileId);
    _streamModerators.removeWhere((m) => m.profileId == profileId);
    _bannedUsers.removeWhere((b) => b.profileId == profileId);
    if (_isMiniPlayerActive && removedVideoIds.contains(_miniPlayerVideoId)) {
      _isMiniPlayerActive = false;
    }
    ChatBlockList.instance.forget(profileId);
    notifyListeners();
    unawaited(_persistMapMarkerCache());
    unawaited(_persistPublicCatalogIfReady());
  }

  // Starts empty: the catalog comes from the backend
  // (loadVerifiedStreamersFromBackend). Sample broadcasters used to be
  // compiled in and merged with real data, so an offline or empty backend
  // still showed five fictional channels (P2 truthful data).
  List<StreamerModel> _streamers = [];
  final PublicCatalogCache _publicCatalogCache = PublicCatalogCache();
  List<StreamerModel>? _lastLoadedPublicStreamers;
  bool _publicCategoriesLoaded = false;
  Future<void>? _publicCatalogLoad;
  int _publicCatalogLoadEpoch = -1;
  int _catalogEpoch = 0;
  bool _disposed = false;
  bool _isUsingCachedCatalog = false;
  DateTime? _publicCatalogUpdatedAt;
  int _successfulCatalogRevision = 0;

  bool get isUsingCachedCatalog => _isUsingCachedCatalog;

  /// A successful backend read or restored catalog can authoritatively
  /// remove cached map pins. A marker-only cache cannot do that.
  bool get hasPublicCatalogSnapshot =>
      _lastLoadedPublicStreamers != null || _publicCatalogUpdatedAt != null;
  bool get isLoadingPublicCatalog =>
      _publicCatalogLoad != null && _publicCatalogLoadEpoch == _catalogEpoch;
  DateTime? get publicCatalogUpdatedAt => _publicCatalogUpdatedAt;
  int get successfulCatalogRevision => _successfulCatalogRevision;

  // --- UI-08: Spatial Map offline experience -------------------------------
  // Device network reachability, not proof any given request will succeed --
  // see ConnectivityService's own doc comment. Defaults to true so a widget
  // test that never calls ensureConnectivityMonitoringActive() (matching the
  // ensureLivePollingActive() pattern -- see that method's doc) renders the
  // normal online map, not a false offline state.
  NetworkStatus _networkStatus = NetworkStatus.online;
  ConnectivityService? _connectivityService;
  StreamSubscription<NetworkStatus>? _connectivitySub;
  int _connectivityGeneration = 0;
  // v2 contains only verified, map-visible pins. Do not trust the older
  // marker-only cache: it could contain a hidden or unverified channel.
  static const String _mapCacheKey = 'spatial_map_marker_cache_v2';
  static const String _mapCacheUpdatedAtKey =
      'spatial_map_marker_cache_updated_at_v2';
  List<MapMarkerModel> _cachedMapMarkers = [];
  DateTime? _mapCacheUpdatedAt;

  NetworkStatus get networkStatus => _networkStatus;
  bool get isOnline => _networkStatus == NetworkStatus.online;
  List<MapMarkerModel> get cachedMapMarkers =>
      List.unmodifiable(_cachedMapMarkers);
  DateTime? get mapCacheUpdatedAt => _mapCacheUpdatedAt;
  // Audience Q&A has no backend and no screen wired to it (05 D-03). The list
  // starts empty instead of being pre-filled with invented questions
  // attributed to named people; the sample set lives in test fixtures.
  final List<LectureQuestionModel> _questions = [];
  UserProfileModel _userProfile = UserProfileModel.defaultProfile;
  final YouTubeApiService _youTubeService;
  final SupabaseAuthService _authService;
  AdminDatabaseService? _adminDbService;

  // Admin Hub, Verification & Governance State
  List<BroadcasterApplicationModel> _applications = [];
  List<Map<String, dynamic>> _applicationReviewEvents = [];
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
  bool _adminRoleLoading = false;
  bool get adminRoleLoading => _adminRoleLoading;
  // Distinguishes master_admin from plain admin within is_admin_tier() (via
  // the is_master_admin() RPC -- see v0.8 Checkpoint 1 Phase 1). Used to gate
  // master_admin-only surfaces (e.g. Checkpoint 2's role/permission
  // management tab) on top of the existing isAdminUser check.
  bool _isMasterAdminFromRoles = false;
  // organization_id(s) this user is org_owner/org_co_owner for -- the
  // roadmap's "Permitted Admin"tier (see ADR-007). Disjoint from
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

  // Muted Chatters Audit Log (Cluster 4 Tasks 13 & 15) -- see
  // ensureMutedChattersAuditLoaded/mutedChattersAuditLog.
  List<ChatMuteAuditEntry> _mutedChattersAuditLog = [];
  bool _mutedChattersAuditLoaded = false;

  // Academic Categories Taxonomy (Cluster 3 Task 10/11) -- see
  // ensureAcademicCategoriesLoaded/academicCategories. Empty list falls back
  // to AcademicCategoryModel.defaultPool via the getter, covering both
  // "not loaded yet"and "Supabase unreachable".
  List<AcademicCategoryModel> _academicCategories = [];
  Future<void>? _categoriesLoad;
  int _categoryRequestGeneration = 0;

  // Tag Moderation (Cluster 3 Task 12) -- see ensureTagsLoaded/approvedTags.
  List<String> _approvedTags = [];
  List<TagModerationModel> _allTagsForModeration = [];
  bool _tagsLoaded = false;

  // Banned Accounts (Cluster 4 Task 16) -- see isCurrentUserBanned/bannedUsers.
  bool _isCurrentUserBanned = false;
  String? _currentUserBanReason;
  List<BannedUserModel> _bannedUsers = [];
  bool _bannedUsersLoaded = false;

  // Stream Moderator Delegation (Cluster 4 Task 15) -- see
  // ensureStreamModeratorsLoaded/streamModerators.
  List<StreamModeratorModel> _streamModerators = [];
  bool _streamModeratorsLoaded = false;

  // Streamer Custom Stream-State Cards (Cluster 1 Task 4b). Three separate
  // slices, because they answer three different questions:
  //  * _pendingCustomPlaceholders -- the admin review queue;
  //  * _myCustomPlaceholders -- what the signed-in streamer has submitted,
  //    in any status, for the editor sheet's Pending/Rejected chips;
  //  * _approvedPlaceholderUrls -- the playback-time lookup, keyed
  //    'streamerId::placeholder_type', holding only approved artwork.
  List<StreamerCustomPlaceholderModel> _pendingCustomPlaceholders = [];
  List<StreamerCustomPlaceholderModel> _myCustomPlaceholders = [];
  List<StreamerCustomPlaceholderModel> _approvedCustomPlaceholders = [];
  final Map<String, String> _approvedPlaceholderUrls = {};
  bool _customPlaceholdersLoaded = false;
  // Content-hash -> image URL cache of previously-approved artwork (Task
  // 4b). Populated whenever a submission is approved; consulted on every
  // new submission so re-using an already-vetted image never re-enters the
  // admin review queue. Persisted so the fast-track survives app restarts.
  final Map<String, String> _approvedPlaceholderHashCache = {};
  static const String _kApprovedPlaceholderHashCachePrefsKey =
      'approved_placeholder_hash_cache_v1';
  bool _approvedPlaceholderHashCacheLoaded = false;

  // Streamer Silence / Mic Mute (Cluster 1 Task 1) -- set by the broadcaster
  // side (PhoneBroadcastScreen, from RtmpPublishEngine.isMicSilent), read by
  // the viewer side to decide whether to show the "Streamer Microphone
  // Muted"badge.
  bool _isStreamerMicMuted = false;

  bool _isStreamerModeEnabled =
      false; // Toggle between Streamer and Viewer modes
  bool _isPitchDirectorModeEnabled = false;
  String _selectedCityId = 'khobar';
  final String _activeStreamId = 'stream_live_992';
  String _currentCategoryFilter = 'all';
  String _selectedTagFilter = 'all';
  String _searchQuery = '';
  // Phone-to-YouTube broadcast target (v0.7 Checkpoint 2 Phase 2) -- the
  // ingest URL + stream key a streamer pastes from YouTube Studio's "Go
  // Live" > Stream tab so this phone's own camera/mic can publish there,
  // distinct from _customYouTubeLiveUrl above (which is the viewer-facing
  // watch link/video ID, not an RTMP ingest target).
  String _phoneBroadcastRtmpUrl = '';
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
  // Empty until a real stream is minimized into the mini-player: it used to
  // start holding an unrelated YouTube video, an invented lecture title and a
  // real person's name (P2 truthful data).
  String _miniPlayerVideoId = '';
  String _miniPlayerTitle = '';
  String _miniPlayerStreamerName = '';
  String? _miniPlayerStreamId;
  bool _isMiniPlayerAudioOnly = false;

  // Streamer Custom YouTube Broadcast Studio State
  // The studio starts empty; the broadcaster supplies the stream URL and
  // title. These used to default to an unrelated video and an invented
  // lecture title, which then travelled into go-live state.
  String _customYouTubeLiveUrl = '';
  String _customYouTubeVideoId = '';
  String _customLiveTitle = '';
  String _customLiveCategory = 'computer_science';
  String _customLiveVenue = 'KFUPM Auditorium 21, Dhahran / Al Khobar';
  String _customSlidesUrl = 'https://kfupm.edu.sa/cs/slides/lecture_01.pdf';
  // v0.9 Broadcaster Studio bottom sheet -- viewer-facing description text
  // and an optional custom backdrop image path shown while the streamer is
  // broadcasting Audio-Only (falls back to the default live audio
  // visualizer when null/empty).
  String _customLiveDescription = '';
  String? _customAudioOnlyPosterPath;
  BroadcastType _customBroadcastType = BroadcastType.liveVideo;
  bool _isBroadcastingLive = false;

  // Private & Restricted Streaming (client-simulated -- see
  // stream_privacy_models.dart; no Supabase table backs this, matching the
  // rest of the live-streaming subsystem, which is likewise simulated
  // end-to-end -- see YouTubeLiveService's own class doc).
  StreamVisibility _streamVisibility = StreamVisibility.public;
  List<String> _streamWhitelistHandles = [];
  bool _requireKnockApproval = true;
  final List<StreamKnockRequest> _pendingKnockRequests = [];
  final List<StreamAttendee> _admittedAttendees = [];
  static const List<String> _demoKnockNamePool = [
    'Khalid Al-Dossary',
    'Sarah Al-Qahtani',
    'Omar Al-Harbi',
    'Fatimah Al-Zahrani',
  ];

  // Streamer Organization Broadcast Selection State
  String? _selectedBroadcastOrgId;
  String? _selectedVenueBranchId;
  List<String> _selectedCoSpeakerIds = [];

  // Bookmarks, Reminders & RSVP Attendance
  final Set<String> _followedStreamerIds = {};
  final Set<String> _reminderStreamerIds = {};
  final Set<String> _cardReminderIds = {};
  int _reminderLeadMinutes = 15;
  final Map<String, List<UpcomingSchedule>> _upcomingByStreamer = {};
  final Map<String, String> _upcomingErrors = {};
  final Set<String> _loadingUpcoming = {};
  final UpcomingScheduleService _upcomingService;
  late final ReminderPushService _reminderPush =
      ReminderPushService(_upcomingService);
  ReminderPushStatus _reminderPushStatus = ReminderPushStatus.unavailable;
  // Starts empty and is filled from the backend for a signed-in account
  // (05 D-07). It used to ship with two sample recordings already saved.
  final Map<String, BookmarkEntry> _bookmarks = {};
  final Set<String> _pendingBookmarks = {};
  bool _loadingBookmarks = false;
  bool _bookmarkLoadFailed = false;
  int _bookmarkRevision = 0;
  // RSVP / venue seating is local-only and hidden in the UI behind
  // kVenueRsvpEnabled (05 D-03): no table records an attendance. The seat map
  // used to ship with counts for three sample streams.
  final Map<String, bool> _inPersonRsvpMap = {};
  final Map<String, int> _venueAvailableSeats = {};

  // Enhanced Notifications & Anti-Spam Throttling Preferences
  final List<AppNotificationModel> _enhancedNotifications = [];
  NotificationPreferencesModel _notificationPreferences =
      const NotificationPreferencesModel();

  // Legacy Notifications (For backward compatibility)
  final List<AppNotificationItem> _notifications = [];

  AppProvider([AdminDatabaseService? adminDbService])
      : this.withServices(adminDbService: adminDbService);

  AppProvider.withServices(
      {AdminDatabaseService? adminDbService,
      SupabaseAuthService? authService,
      ConnectivityService? connectivityService,
      YouTubeApiService? youTubeService,
      UpcomingScheduleService? upcomingService,
      OrganizationBroadcastService? organizationBroadcastService})
      : _organizationBroadcastService = organizationBroadcastService ?? OrganizationBroadcastService(),
        _upcomingService = upcomingService ?? UpcomingScheduleService(),
        _youTubeService = youTubeService ?? YouTubeApiService(),
        _adminDbService = adminDbService,
        _authService = authService ?? SupabaseAuthService(),
        _connectivityService = connectivityService {
    _initAdminDatabase();
    _initAuthListener();
    // NOTE: Live viewer polling is NOT started in the constructor to keep
    // widget tests clean (no pending timer assertions). The real app starts
    // it via AppProvider.ensureLivePollingActive() from main.dart / app root.
    // Connectivity *monitoring* (the stream subscription) follows the same
    // rule -- see ensureConnectivityMonitoringActive(). Loading whatever
    // offline map cache is already on disk is a one-shot read, not a
    // subscription, so it's safe to kick off here: it's what lets the map
    // show cached venues immediately if the app opens with no network at
    // all, before main.dart gets a chance to call anything.
    _loadMapMarkerCacheFromDisk();
    restorePublicCatalogFromDisk();
  }

  /// Picks up any session Supabase already restored on cold start, then
  /// listens for further auth changes (sign-in completing after the OAuth
  /// redirect, token refresh, sign-out). Swallows the "Supabase not
  /// initialized"assertion so widget/unit tests that construct AppProvider
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
          unawaited(_reminderPush.signOut());
          _clearAuthState();
          return;
        }
        final isFreshSignIn = data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.initialSession;
        if (data.event == AuthChangeEvent.signedIn) {
          unawaited(_markOAuthAttempt(false));
        }
        _applySessionUser(session.user, isFreshSignIn: isFreshSignIn);
      }, onError: (Object error, StackTrace _) {
        // A refused OAuth redirect (for example a new Google account while
        // sign-ups are paused) arrives here as an AuthException. It used to
        // be dropped, so the app silently stayed on whatever account was
        // already signed in (owner retest 2026-09-25, Test 8).
        unawaited(_handleAuthRedirectError(error));
      });
    } catch (e) {
      debugPrint(
          'Supabase auth listener not attached (Supabase not initialized?): $e');
    }
  }

  String? _authRefusalKey;
  String? _authRefusalSignedInAs;
  int _authRefusalGeneration = 0;

  /// Why the last Google sign-in was refused, as a translation key, or null.
  String? get authRefusalKey => _authRefusalKey;

  /// The account that is still signed in after the refusal, if any, so the
  /// user is never left to assume the refused account signed in.
  String? get authRefusalSignedInAs => _authRefusalSignedInAs;
  int get authRefusalGeneration => _authRefusalGeneration;

  static const _oauthAttemptKey = 'oauth_sign_in_attempt_at';
  static const _oauthAttemptWindow = Duration(minutes: 5);

  /// Remembers that this client opened Google sign-in, so only an error that
  /// answers that attempt is shown as a refusal. Stored, because on web the
  /// OAuth redirect reloads the page.
  Future<void> _markOAuthAttempt(bool pending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pending) {
        await prefs.setString(
            _oauthAttemptKey, DateTime.now().toUtc().toIso8601String());
      } else {
        await prefs.remove(_oauthAttemptKey);
      }
    } catch (_) {}
  }

  Future<bool> _consumeOAuthAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = DateTime.tryParse(prefs.getString(_oauthAttemptKey) ?? '');
      await prefs.remove(_oauthAttemptKey);
      return at != null &&
          DateTime.now().toUtc().difference(at) < _oauthAttemptWindow;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleAuthRedirectError(Object error) async {
    if (error is! AuthException) {
      debugPrint('Auth redirect error: ${error.runtimeType}');
      return;
    }
    // Token refresh failures and expired sessions travel on the same stream.
    // They are not sign-in refusals and must never be shown as one (P6S
    // wave 3 critic: a signed-in broadcaster on a flaky network would have
    // been told "No new account was created").
    if (error is AuthRetryableFetchException ||
        error is AuthSessionMissingException ||
        error.code == 'session_expired' ||
        error.code == 'refresh_token_not_found' ||
        error.code == 'refresh_token_already_used') {
      debugPrint('Auth session error: ${error.runtimeType}');
      return;
    }
    if (!await _consumeOAuthAttempt()) {
      debugPrint('Auth error without a sign-in attempt: ${error.runtimeType}');
      return;
    }
    bool? registrationsOpen;
    try {
      await AppFlags.instance.refresh();
      if (AppFlags.instance.isKnown(AppFlagKey.registrationsOpen)) {
        registrationsOpen = AppFlags.instance.registrationsOpen;
      }
    } catch (_) {}
    applyAuthRefusal(error, registrationsOpen: registrationsOpen);
  }

  /// GoTrue reports a refused account creation as a generic database error,
  /// so the platform switch decides which explanation is true. Nothing here
  /// signs anyone in or out.
  @visibleForTesting
  void applyAuthRefusal(Object error, {required bool? registrationsOpen}) {
    _authRefusalKey = registrationsOpen == false
        ? 'auth_refusal.signups_paused'
        : 'auth_refusal.generic';
    _authRefusalSignedInAs = _authService.currentSession?.user.email;
    _authRefusalGeneration++;
    notifyListeners();
  }

  /// Populates auth/display state from a live Supabase session. On a fresh
  /// sign-in, also provisions the profiles row (if missing) and refreshes
  /// admin status from user_roles via the is_admin_tier() RPC.
  Future<void> _applySessionUser(User user,
      {required bool isFreshSignIn}) async {
    // Token refresh/duplicate initialSession must not reclaim a displaced
    // device or override an explicit viewer choice.
    if (_hydratingUserId == user.id ||
        (_sessionUserId == user.id && !_authHydrating)) {
      return;
    }
    _clearAuthState();
    final generation = _authGeneration;
    _sessionUserId = user.id;
    _hydratingUserId = user.id;
    _authHydrating = true;
    _adminRoleLoading = true;
    _hasCompletedOnboarding = true;
    _isLoggedInStreamer = true;
    _isGuestViewer = false;
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

    try {
      if (isFreshSignIn) {
        await _ensureProfileRow(user);
      }
      final prefs = await SharedPreferences.getInstance();
      if (_authGeneration != generation) return;
      _pendingOrganizationInvitation = prefs.getString('pending_org_invitation');
      _hasCompletedRoleSelection =
          prefs.getBool('has_completed_role_selection_${user.id}') ?? false;
      await _flushPendingConsentIfAny(user.id);
      if (_authGeneration != generation) return;
      await _refreshAdminRoleFromBackend();
      if (_authGeneration != generation) return;
      await _refreshPermittedAdminOrgsFromBackend();
      if (_authGeneration != generation) return;
      await _refreshCurrentUserBanStatus();
      if (_authGeneration != generation) return;
      await loadViewerLibrary();
      if (_authGeneration != generation) return;
      try {
        await refreshScheduleReminders();
        unawaited(syncReminderPush(requestPermission: false, language: 'en'));
      } catch (e) {
        // An older backend may not have the new migration yet. Sign-in must
        // remain usable while Upcoming Live reports its own unavailable state.
        debugPrint('Schedule reminders unavailable: $e');
      }
      if (_authGeneration != generation) return;
      await refreshMyApplicationAndStreamerStatus();
      if (_authGeneration != generation) return;
      _isStreamerModeEnabled = isApprovedStreamer;
      if (_isAdminFromRoles) {
        await refreshAdminData();
      }
      // Multi-device broadcaster collision check -- only meaningful once we
      // know this account is actually an approved streamer (see
      // initDeviceSession doc). Fires on every session application, not just
      // a fresh sign-in, so a resumed session (e.g. a cold web reload) still
      // re-checks for a conflict from another device.
      if (_authGeneration != generation) return;
      if (isApprovedStreamer) await initDeviceSession();
      if (_authGeneration != generation) return;
    } catch (_) {
      // Keep failed hydration unprivileged; another auth event can retry.
      if (_authGeneration == generation) _sessionUserId = null;
    } finally {
      if (_authGeneration == generation) {
        _hydratingUserId = null;
        _authHydrating = false;
        _adminRoleLoading = false;
        notifyListeners();
      }
    }
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

  // ---------------------------------------------------------------------
  // PDPL Consent Tracking (v0.9 Checkpoint 3 Phase 1) -- see ConsentDialog
  // (lib/core/widgets/consent_dialog.dart) and
  // 20260829000100_pdpl_consent_tracking.sql. Bumping kConsentVersion is
  // how a future policy update would require re-consent, though today
  // nothing re-checks it for an already-signed-in user returning on a new
  // session -- this gate only covers the WelcomeScreen entry point
  // ("before any personal data is gathered"), not a forced re-consent flow
  // for existing accounts.
  // ---------------------------------------------------------------------
  static const String kConsentVersion = 'v1.0';
  static const String _kPendingConsentVersionPrefKey =
      'pending_consent_version';
  static const String _kPendingConsentAcceptedAtPrefKey =
      'pending_consent_accepted_at';

  String? _consentVersion;
  DateTime? _consentAcceptedAt;

  String? get consentVersion => _consentVersion;
  DateTime? get consentAcceptedAt => _consentAcceptedAt;
  bool get hasAcceptedCurrentConsent => _consentVersion == kConsentVersion;

  /// Records explicit consent from ConsentDialog, for both the Google
  /// sign-in and guest flows. Consent is captured on WelcomeScreen before
  /// OAuth has necessarily completed, so if there's no session yet this
  /// stashes it in SharedPreferences instead of writing straight to
  /// profiles -- required because Supabase's web OAuth redirect reloads the
  /// page and wipes in-memory state; _flushPendingConsentIfAny() picks it
  /// up once the session exists. A guest viewer never gets a profiles row
  /// at all, so their consent stays local-only, which is consistent with
  /// the rest of their session being local-only too.
  Future<void> recordConsent() async {
    _consentVersion = kConsentVersion;
    _consentAcceptedAt = DateTime.now();
    notifyListeners();

    final userId = _authService.currentSession?.user.id;
    if (userId != null) {
      await _persistConsent(userId, _consentVersion!, _consentAcceptedAt!);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingConsentVersionPrefKey, _consentVersion!);
      await prefs.setString(_kPendingConsentAcceptedAtPrefKey,
          _consentAcceptedAt!.toIso8601String());
    } catch (e) {
      debugPrint('Failed to stash pending consent: $e');
    }
  }

  Future<void> _persistConsent(
      String userId, String version, DateTime acceptedAt) async {
    try {
      await Supabase.instance.client.from('profiles').update({
        'consent_version': version,
        'consent_accepted_at': acceptedAt.toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Failed to persist consent: $e');
    }
  }

  Future<void> _flushPendingConsentIfAny(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingVersion = prefs.getString(_kPendingConsentVersionPrefKey);
      final pendingAcceptedAtRaw =
          prefs.getString(_kPendingConsentAcceptedAtPrefKey);
      if (pendingVersion == null || pendingAcceptedAtRaw == null) return;

      final acceptedAt = DateTime.parse(pendingAcceptedAtRaw);
      await _persistConsent(userId, pendingVersion, acceptedAt);
      _consentVersion = pendingVersion;
      _consentAcceptedAt = acceptedAt;
      await prefs.remove(_kPendingConsentVersionPrefKey);
      await prefs.remove(_kPendingConsentAcceptedAtPrefKey);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to flush pending consent: $e');
    }
  }

  /// Source of truth for admin status: the user_roles table, via the
  /// is_admin_tier() SECURITY DEFINER RPC (see supabase/migrations). Replaces
  /// the hardcoded _superAdminEmails allowlist removed in this refactor.
  /// Also resolves is_master_admin() so the UI can tell master_admin and
  /// plain admin apart (both pass isAdminUser; only the former passes
  /// isMasterAdmin -- see ADR-007).
  Future<void> _refreshAdminRoleFromBackend() async {
    final generation = _authGeneration;
    try {
      final results = await Future.wait([
        Supabase.instance.client.rpc('is_admin_tier'),
        Supabase.instance.client.rpc('is_master_admin'),
      ]);
      if (_authGeneration != generation) return;
      _isAdminFromRoles = results[0] == true;
      _isMasterAdminFromRoles = results[1] == true;
    } catch (e) {
      if (_authGeneration != generation) return;
      debugPrint('Admin role check failed: $e');
      _isAdminFromRoles = false;
      _isMasterAdminFromRoles = false;
    }
  }

  /// organization_id(s) this user is org_owner/org_co_owner for, via a
  /// direct user_roles select (RLS already lets any signed-in user read
  /// their own rows -- no admin tier needed, unlike is_admin_tier()).
  Future<void> _refreshPermittedAdminOrgsFromBackend() async {
    final generation = _authGeneration;
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      final ids = await _adminDbService!.loadPermittedAdminOrgIds();
      if (_authGeneration != generation) return;
      _permittedAdminOrgIds = ids;
      await refreshOrgMemberships();
      await Future.wait([refreshOrganizationInvitations(), refreshOrganizationEvents()])
          .catchError((Object e) {
        debugPrint('Organization inbox refresh failed: $e');
        return const <void>[];
      });
    } catch (e) {
      if (_authGeneration != generation) return;
      debugPrint('Permitted admin org lookup failed: $e');
      _permittedAdminOrgIds = [];
    }
  }

  bool _isApprovedStreamer = false;
  bool get isApprovedStreamer => _isApprovedStreamer;
  bool _personalBroadcastApproved = false;
  bool _organizationBroadcastApproved = false;
  bool get personalBroadcastApproved => _personalBroadcastApproved;
  bool get organizationBroadcastApproved => _organizationBroadcastApproved;
  final OrganizationBroadcastService _organizationBroadcastService;
  List<OrgMembership> _orgMemberships = [];
  List<OrgMembership> get orgMemberships => _orgMemberships;
  List<ChannelConnection> _channelConnections = [];
  List<ChannelConnection> get channelConnections => _channelConnections;

  Future<void> refreshChannelConnections() async {
    final generation = _authGeneration;
    final rows = await _organizationBroadcastService.connections();
    if (generation != _authGeneration) return;
    _channelConnections = List.unmodifiable(rows);
    notifyListeners();
  }
  Future<Uri> connectYouTubeChannel({String? organizationId}) =>
      _organizationBroadcastService.connectChannel(organizationId:organizationId);

  /// The page stack where Google consent started, so the return link can
  /// rebuild it (Google's return replaces the navigation history). Stored,
  /// because on web the consent redirect reloads the page. [studio] reopens the
  /// broadcast studio on top; otherwise the connections page is reopened.
  static const _channelConsentReturnKey = 'channel_consent_return';
  Future<void> rememberChannelConsentReturn(List<String> stack, {required bool studio}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_channelConsentReturnKey, jsonEncode({
        'at': DateTime.now().toUtc().toIso8601String(), 'stack': stack, 'studio': studio}));
    } catch (_) {}
  }
  Future<({List<String> stack, bool studio})?> takeChannelConsentReturn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_channelConsentReturnKey);
      await prefs.remove(_channelConsentReturnKey);
      if (stored == null) return null;
      final data = jsonDecode(stored) as Map<String, dynamic>;
      final at = DateTime.tryParse(data['at'] as String? ?? '');
      final stack = (data['stack'] as List?)?.whereType<String>().toList() ?? const <String>[];
      // Only in-app paths; never another origin or a stale attempt.
      if (at == null || stack.isEmpty || stack.length > 10 ||
          stack.any((l) => !l.startsWith('/') || l.startsWith('//')) ||
          DateTime.now().toUtc().difference(at) > const Duration(minutes: 30)) { return null; }
      return (stack: stack, studio: data['studio'] == true);
    } catch (_) {
      return null;
    }
  }
  Future<void> disconnectYouTubeChannel(String id) async {
    await _organizationBroadcastService.disconnectChannel(id);
    await refreshChannelConnections();
  }

  List<BroadcastSession> _broadcastSessions = [];
  List<BroadcastSession> get broadcastSessions => _broadcastSessions;
  final Map<String, BroadcastSession> _roomSessions = {};
  final Map<String,int> _roomRevisions = {};
  int roomRevision(String id) => successfulCatalogRevision + (_roomRevisions[id]??0);
  BroadcastSession? roomSession(String id) => _roomSessions[id] ?? _broadcastSessions.where((s)=>s.id==id).firstOrNull;
  List<BroadcastSession> roomChoices(String id) => _broadcastSessions.where((s)=>!s.hidden && s.live && (s.organizationId==id || s.presenterId==id)).toList();
  BroadcastSession? _publishingSession;
  ChannelConnection? _publishingDestination;
  BroadcastSession? get publishingSession => _publishingSession;
  Future<List<BroadcastSession>> organizationSessions({String? organizationId, bool mine=false}) =>
      _organizationBroadcastService.sessions(organizationId:organizationId,mine:mine);
  Future<void> refreshBroadcastRoom(String id) async {
    final generation=_authGeneration;
    final session=await _organizationBroadcastService.session(id);
    if(generation!=_authGeneration) return;
    if(session==null) { _roomSessions.remove(id); } else { _roomSessions[id]=session; }
    _roomRevisions[id]=(_roomRevisions[id]??0)+1;
    notifyListeners();
  }
  Future<void> answerBroadcastAssignment(BroadcastSession session,bool accept) =>
      _organizationBroadcastService.answerAssignment(session,accept);
  Future<String> saveOrganizationSchedule({required String orgId,String? scheduleId,required String presenterId,
      required String kind,required String localTime,required List<int> weekdays,DateTime? once,
      required String titleEn,required String titleAr,required String type,int duration=60,String? venueId}) =>
      _organizationBroadcastService.saveSchedule(orgId:orgId,scheduleId:scheduleId,presenterId:presenterId,kind:kind,
        localTime:localTime,weekdays:weekdays,once:once,titleEn:titleEn,titleAr:titleAr,type:type,duration:duration,venueId:venueId);
  Future<void> editOrganizationOccurrence(BroadcastSession session,{required String presenterId,required DateTime start,
      required DateTime end,required String type,String? venueId}) => _organizationBroadcastService.editOccurrence(session,
        presenterId:presenterId,start:start,end:end,type:type,venueId:venueId);
  Future<void> cancelOrganizationSchedule(String id) => _organizationBroadcastService.cancelSchedule(id);
  Future<String> createPersonalBroadcast(String title,String type) => _organizationBroadcastService.createPersonal(title,type);
  Future<BroadcastSession?> loadBroadcastSession(String id) => _organizationBroadcastService.session(id);

  void _clearPublishingState() {
    _clearOwnLiveProjection();
    _publishingSession=null; _publishingDestination=null;
    _phoneBroadcastRtmpUrl=''; _phoneBroadcastStreamKey='';
    _liveSessionId=null; _liveWatchId=null; _lastReportedIngest=null;
    _selectedBroadcastOrgId=null; _selectedVenueBranchId=null;
    _broadcastSenderMode='unspecified';
  }

  Future<Map<String,dynamic>> prepareBroadcast(String id,String sender,ChannelConnection destination) async {
    final generation=_deviceGeneration, authGeneration=_authGeneration;
    final device=_currentDeviceSession;
    if(device?.isPrimaryBroadcaster!=true) throw StateError('Primary device required');
    bool current()=>!_disposed && generation==_deviceGeneration && authGeneration==_authGeneration &&
      _currentDeviceSession?.isPrimaryBroadcaster==true;
    try {
      final result=await _organizationBroadcastService.control(id,device!.deviceId,sender,'prepare',destination:destination);
      if(!current()) throw StateError('Device changed');
      final session=BroadcastSession.fromRow(Map<String,dynamic>.from(result['session'] as Map));
      if(session.channelConnectionId!=destination.id) throw StateError('Destination changed');
      _publishingSession=session; _publishingDestination=destination;
      _liveSessionId=session.id; _liveWatchId=session.watchId;
      _selectedBroadcastOrgId=session.organizationId; _selectedVenueBranchId=session.venueId;
      _broadcastSenderMode=sender;
      _customLiveTitle=session.titleEn.isEmpty?session.titleAr:session.titleEn;
      _customBroadcastType=session.broadcastType=='liveAudio'?BroadcastType.liveAudio:BroadcastType.liveVideo;
      _customYouTubeVideoId=session.watchId??'';
      _customYouTubeLiveUrl=session.watchId==null?'':'https://www.youtube.com/watch?v=${session.watchId}';
      _phoneBroadcastRtmpUrl=result['ingest_url'] as String;
      _phoneBroadcastStreamKey=result['ingest_key'] as String;
      _isBroadcastingLive=session.live; _broadcastSessionError=null;
      notifyListeners(); return result;
    } catch (_) {
      final partial=await loadBroadcastSession(id).catchError((_)=>null);
      if(current() && partial!=null) {
        _publishingSession=partial; _publishingDestination=destination;
        _liveSessionId=partial.id; _broadcastSenderMode=partial.senderMode;
        _phoneBroadcastRtmpUrl=''; _phoneBroadcastStreamKey='';
        notifyListeners();
      }
      rethrow;
    }
  }
  Future<void> endOrganizationSession(BroadcastSession session) async {
    if(_publishingSession?.id==session.id) {
      await setBroadcasterLive(false);
      if(_publishingSession!=null) throw StateError('Termination not confirmed');
    } else {
      await _organizationBroadcastService.control(session.id,_currentDeviceSession?.deviceId??'management',
        session.senderMode=='phone_direct'?'phone_direct':'obs_laptop','end');
      await loadVerifiedStreamersFromBackend();
    }
  }
  StreamerModel? _sessionProjection(BroadcastSession session) {
    final base=_streamers.where((s)=>s.streamerId==(session.organizationId??session.presenterId)).firstOrNull;
    if(base==null) return null;
    final venue=base.venues.where((v)=>v.venueId==session.venueId).firstOrNull;
    return base.copyWith(streamerId:session.id,contentOwnerId:session.organizationId??session.presenterId,
      titleEn:session.titleEn,titleAr:session.titleAr.isEmpty?session.titleEn:session.titleAr,
      isCurrentlyLive:session.live,isHiddenLiveSession:false,broadcastType:session.broadcastType=='liveAudio'?BroadcastType.liveAudio:BroadcastType.liveVideo,
      clearLiveState:true,youtubeVideoId:session.live || session.replayStatus=='available'?session.watchId??'':'',fallbackYoutubeVideoIds:const [],activeViewerCount:0,
      latitude:venue?.latitude,longitude:venue?.longitude,venueNameEn:venue?.nameEn,venueNameAr:venue?.nameAr,
    ).copyWith(activeStreamId:session.live?session.watchId:null,liveSessionId:session.live?session.id:null);
  }
  StreamerModel? getRoomStreamer(String id) {
    if(_roomRevisions.containsKey(id) && !_roomSessions.containsKey(id)) return null;
    final exact=_roomSessions[id]??_broadcastSessions.where((s)=>s.id==id).firstOrNull;
    if(exact!=null) return _sessionProjection(exact);
    final candidates=_broadcastSessions.where((s)=>s.live&&(s.organizationId==id||s.presenterId==id||s.watchId==id)).toList();
    if(candidates.length==1) return _sessionProjection(candidates.single);
    if(candidates.length>1) return null;
    return getStreamerById(id);
  }

  Future<void> refreshOrgMemberships() async {
    final generation = _authGeneration;
    final rows = await _organizationBroadcastService.memberships();
    if (generation != _authGeneration) return;
    _orgMemberships = List.unmodifiable(rows);
    notifyListeners();
  }

  Future<List<OrgMembership>> organizationMembers(String orgId) =>
      _organizationBroadcastService.memberships(organizationId: orgId);

  Future<Map<String, dynamic>> inviteOrganizationMember(String orgId,
      String email, String role, Map<String, bool> permissions) =>
      _organizationBroadcastService.invite(orgId, email, role, permissions);

  Future<void> setOrganizationMember(String orgId, String profileId,
      String role, String status, Map<String, bool> permissions) async {
    await _organizationBroadcastService.setMember(
        orgId, profileId, role, status, permissions);
    await refreshOrgMemberships();
  }

  Future<void> answerOrganizationInvite(String id, bool accept, {String? token}) async {
    await _organizationBroadcastService.answerInvite(id, accept, token: token);
    await refreshOrgMemberships();
  }

  Future<void> transferOrganizationOwner(String orgId, {String? toProfileId}) async {
    await _organizationBroadcastService.transferOwner(orgId, toProfileId: toProfileId);
    await refreshOrgMemberships();
  }

  Future<void> cancelOrganizationTransfer(String orgId) async {
    await _organizationBroadcastService.cancelTransfer(orgId);
    await refreshOrgMemberships();
  }

  List<OrgInvitation> _myOrgInvitations = [];
  List<OrgInvitation> get myOrganizationInvitations => _myOrgInvitations;
  Future<void> refreshOrganizationInvitations() async {
    final generation = _authGeneration;
    final rows = await _organizationBroadcastService.myInvitations();
    if (generation != _authGeneration) return;
    _myOrgInvitations = List.unmodifiable(rows);
    notifyListeners();
  }
  Future<List<OrgInvitation>> organizationInvitations(String orgId) =>
      _organizationBroadcastService.invitations(orgId);
  Future<void> revokeOrganizationInvite(String id) =>
      _organizationBroadcastService.revokeInvite(id);

  // Durable organization events (server rows). The notification center shows
  // each unread one once; reading it there marks the server row read.
  List<OrgEvent> _orgEvents = [];
  List<OrgEvent> get organizationEvents => _orgEvents;
  final Set<String> _announcedOrgEvents = {};
  bool _orgEventsLoading = false;
  Future<void> refreshOrganizationEvents() async {
    if (_orgEventsLoading || !_isLoggedInStreamer) return;
    final generation = _authGeneration;
    _orgEventsLoading = true;
    try {
      final rows = await _organizationBroadcastService.events();
      if (generation != _authGeneration) return;
      _orgEvents = List.unmodifiable(rows);
      for (final event in rows.reversed) {
        if (event.read || !_announcedOrgEvents.add(event.id)) continue;
        final en = orgEventText(event, 'en'), ar = orgEventText(event, 'ar');
        addEnhancedNotification(AppNotificationModel(
          id: 'org:${event.id}',
          type: switch (event.kind) {
            'show_live' => NotificationType.orgStreamerLiveStatus,
            'membership_changed' => NotificationType.streamerRemovedFromOrg,
            'assignment' || 'assignment_changed' || 'assignment_cancelled' ||
            'assignment_answered' || 'assignment_reminder' || 'show_ending' =>
              NotificationType.orgLiveGuestInvite,
            _ => NotificationType.orgAffiliationInvite,
          },
          streamerId: event.organizationId ?? '',
          streamerName: event.organizationName('en'),
          titleEn: en.title, titleAr: ar.title, bodyEn: en.body, bodyAr: ar.body,
          timestamp: event.createdAt.toLocal(),
          streamId: event.liveAlert ? event.sessionId : null,
          actionUrl: event.route,
        ));
      }
      notifyListeners();
    } finally {
      _orgEventsLoading = false;
    }
  }
  Future<void> markOrganizationEventsRead([List<String>? ids]) async {
    await _organizationBroadcastService.markEventsRead(ids);
    final now = DateTime.now();
    _orgEvents = List.unmodifiable(_orgEvents.map((e) => e.read || (ids != null && !ids.contains(e.id))
        ? e
        : OrgEvent(id: e.id, kind: e.kind, createdAt: e.createdAt, organizationId: e.organizationId,
            sessionId: e.sessionId, invitationId: e.invitationId, payload: e.payload, readAt: now)));
    notifyListeners();
  }
  void _markOrgEventReadQuietly(List<String>? ids) {
    if (!_isLoggedInStreamer) return;
    unawaited(markOrganizationEventsRead(ids).catchError(
        (Object e) => debugPrint('Organization event read sync failed: $e')));
  }

  /// Master Admin pilot controls. The server enforces the role.
  Future<List<({String id, String nameEn, String nameAr, bool pilot})>> organizationPilotStatus() =>
      _organizationBroadcastService.pilotStatus();
  Future<void> setOrganizationPilot(String orgId, bool enabled) async {
    await _organizationBroadcastService.setPilot(orgId, enabled);
    await refreshOrgMemberships();
  }

  BroadcasterApplicationModel? _myApplication;
  BroadcasterApplicationModel? get myApplication => _myApplication;

  // ---------------------------------------------------------------------
  // Multi-Device Session Management (issue_log.md QF-06)
  // ---------------------------------------------------------------------
  DeviceSessionModel? _currentDeviceSession;
  StreamSubscription<List<DeviceSessionModel>>? _deviceSubscription;
  Timer? _deviceHeartbeatTimer;
  bool _deviceHeartbeatBusy = false;
  int _deviceGeneration = 0;
  bool _liveStateBusy = false;
  Completer<void>? _liveStateCompletion;
  bool get broadcastOperationBusy => _liveStateBusy;
  // Bumped whenever this device asserts or withdraws LIVE, so a status read
  // that started before the assertion cannot be mistaken for a remote end.
  int _liveAssertionEpoch = 0;
  String? _remoteBroadcastEndReason;
  int _remoteBroadcastEndGeneration = 0;
  // The server session and exact watch ID this device went live with. The
  // studio's URL field can change while live; these cannot.
  String? _liveSessionId;
  String? _liveWatchId;
  String _broadcastSenderMode = 'unspecified';
  (String, bool)? _lastReportedIngest;

  /// Which sender the next broadcast uses: `phone_direct` (this phone's
  /// camera), `obs_laptop` (OBS Studio on a computer) or `external_phone`
  /// (another phone app). Recorded on the server session so the modes are
  /// never confused with one another.
  void setBroadcastSenderMode(String mode) {
    const allowed = {'phone_direct', 'obs_laptop'};
    if (_publishingSession?.frozen == true) return;
    _broadcastSenderMode = allowed.contains(mode) ? mode : 'unspecified';
  }

  String get broadcastSenderMode => _broadcastSenderMode;
  String? get liveSessionId => _liveSessionId;

  /// Whether this broadcast has a server session to report ingest to.
  bool get hasLiveBroadcastSession => _liveSessionId != null;

  /// Why the server ended this device's broadcast, when it was not this
  /// device's own action: `admin_end`, `admin_remove`, `stale_expired`,
  /// `replaced` or `ended`. Device transfer, revocation and bans keep their
  /// own paths. Cleared when a new broadcast starts.
  String? get remoteBroadcastEndReason => _remoteBroadcastEndReason;
  int get remoteBroadcastEndGeneration => _remoteBroadcastEndGeneration;
  String? _broadcastSessionError;
  String? get broadcastSessionError => _broadcastSessionError;
  DeviceSessionModel? get currentDeviceSession => _currentDeviceSession;
  DeviceSessionModel? _remoteBroadcasterSession;
  DeviceSessionModel? get remoteBroadcasterSession => _remoteBroadcasterSession;
  bool _hasCompletedRoleSelection = false;
  bool get hasCompletedRoleSelection => _hasCompletedRoleSelection;
  String? _sessionUserId;
  int _authGeneration = 0;
  String? _hydratingUserId;
  bool _authHydrating = false;
  bool get authHydrating => _authHydrating;
  bool _viewerDeviceChoice = false;

  /// Fingerprints this device, then checks the backend for another device
  /// on this same account currently holding broadcaster rights. If one is
  /// found, this device registers as non-primary and
  /// `remoteBroadcasterSession` is populated so the UI can show
  /// DeviceSessionConflictDialog; otherwise this device claims primary
  /// broadcaster status. Only meaningful for approved streamers -- callers
  /// should gate on `isApprovedStreamer` (see `_applySessionUser`).
  Future<void> initDeviceSession() async {
    final generation = ++_deviceGeneration;
    _deviceHeartbeatTimer?.cancel();
    _heartbeatFailingSince = null;
    await _deviceSubscription?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _deviceGeneration) return;
      var deviceId = prefs.getString('local_device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = newId();
        await prefs.setString('local_device_id', deviceId);
      }
      final platform =
          kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
      final deviceName = '$platform Device';

      final userId = _authService.currentSession?.user.id;
      // A viewer choice (or a displacement) on this install survives app
      // restarts and token refreshes; only an explicit broadcaster-mode or
      // transfer action clears it.
      if (userId != null && prefs.getBool(_viewerChoiceKey(userId)) == true) {
        _viewerDeviceChoice = true;
      }
      if (_viewerDeviceChoice) _isStreamerModeEnabled = false;

      _currentDeviceSession = DeviceSessionModel(
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        lastActiveAt: DateTime.now(),
        isPrimaryBroadcaster: false,
      );
      _remoteBroadcasterSession = null;

      if (userId != null) {
        _adminDbService ??= await AdminDatabaseService.create();
        var claimed = false;
        if (!_viewerDeviceChoice) {
          try {
            final result =
                await _adminDbService!.claimDeviceState(_currentDeviceSession!);
            if (generation != _deviceGeneration) return;
            claimed = result.claimed;
            _remoteBroadcasterSession = claimed ? null : result.primary;
          } catch (e) {
            if (generation != _deviceGeneration) return;
            // Unknown ownership stays non-primary; the studio explains it and
            // broadcaster mode or app resume retries.
            debugPrint('Broadcaster device claim failed: $e');
            _broadcastSessionError = 'broadcast_state_failed';
          }
        }
        _currentDeviceSession =
            _currentDeviceSession!.copyWith(isPrimaryBroadcaster: claimed);
        if (claimed) _broadcastSessionError = null;
        _deviceSubscription =
            _adminDbService!.watchDevices(userId).listen((sessions) {
          if (generation == _deviceGeneration) applyDeviceSessions(sessions);
        }, onError: (Object error) {
          // A Realtime channel error is not a server ownership answer. Ask the
          // server instead of demoting a device that may still be primary.
          if (generation == _deviceGeneration) unawaited(_heartbeatDevice());
        });
        _deviceHeartbeatTimer = Timer.periodic(
            const Duration(seconds: 20), (_) => _heartbeatDevice());
      }
      notifyListeners();
    } catch (e) {
      debugPrint('initDeviceSession failed: $e');
    }
  }

  static String _viewerChoiceKey(String userId) =>
      'broadcaster_viewer_device_$userId';

  Future<void> _persistViewerChoice(bool viewer) async {
    final userId = _sessionUserId ?? _authService.currentSession?.user.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (viewer) {
        await prefs.setBool(_viewerChoiceKey(userId), true);
      } else {
        await prefs.remove(_viewerChoiceKey(userId));
      }
    } catch (e) {
      debugPrint('Viewer device choice not persisted: $e');
    }
  }

  void setRemoteBroadcasterSession(DeviceSessionModel remote) {
    _remoteBroadcasterSession = remote;
    notifyListeners();
  }

  Future<void> transferBroadcasterToCurrentDevice() async {
    final device = _currentDeviceSession;
    final generation = _deviceGeneration;
    if (device == null || _adminDbService == null) return;
    try {
      final result =
          await _adminDbService!.claimDeviceState(device, force: true);
      if (generation != _deviceGeneration) return;
      if (!result.claimed) {
        _broadcastSessionError = 'broadcast_state_failed';
        notifyListeners();
        return;
      }
      _currentDeviceSession = device.copyWith(isPrimaryBroadcaster: true);
      _remoteBroadcasterSession = null;
      _broadcastSessionError = null;
      _heartbeatFailingSince = null;
      _viewerDeviceChoice = false;
      _isStreamerModeEnabled = true;
      unawaited(_persistViewerChoice(false));
      notifyListeners();
      // The claim just cleared the previous device's broadcast. Read the
      // catalog now instead of waiting for a Realtime event this device may
      // never receive (owner retest 2026-09-25: the receiving phone kept a
      // stale LIVE until restart).
      unawaited(loadVerifiedStreamersFromBackend());
    } catch (_) {
      if (generation != _deviceGeneration) return;
      _broadcastSessionError = 'broadcast_state_failed';
      notifyListeners();
    }
  }

  /// Asks the server whether this device still holds the primary role. Only
  /// a definite "no" demotes it. Network errors demote only after the server
  /// itself would have treated the device as silent (90 s), so a brief
  /// connection drop does not end a broadcast the server still accepts.
  Future<void> _heartbeatDevice() async {
    final device = _currentDeviceSession;
    final generation = _deviceGeneration;
    if (_deviceHeartbeatBusy ||
        device == null ||
        !device.isPrimaryBroadcaster ||
        _adminDbService == null) {
      return;
    }
    _deviceHeartbeatBusy = true;
    try {
      final primary = await _adminDbService!.heartbeatDevice(device.deviceId);
      if (generation != _deviceGeneration) return;
      _heartbeatFailingSince = null;
      if (!primary) {
        _loseBroadcastDevice();
      } else if (_publishingSession?.active == true || _isBroadcastingLive) {
        // Realtime can miss an admin End; the heartbeat bounds that to 20 s.
        await _checkRemoteBroadcastEnd();
      }
    } catch (_) {
      if (generation != _deviceGeneration) return;
      final since = _heartbeatFailingSince ??= DateTime.now();
      if (DateTime.now().difference(since) >= _deviceSilenceLimit) {
        _loseBroadcastDevice();
      }
    } finally {
      _deviceHeartbeatBusy = false;
    }
  }

  DateTime? _heartbeatFailingSince;
  static const Duration _deviceSilenceLimit = Duration(seconds: 90);

  @visibleForTesting
  void applyDeviceSessions(List<DeviceSessionModel> sessions) {
    final device = _currentDeviceSession;
    if (device == null) return;
    final primary = sessions.where((s) => s.isPrimaryBroadcaster).firstOrNull;
    final wasPrimary = device.isPrimaryBroadcaster;
    final previousRemote = _remoteBroadcasterSession;
    if (primary?.deviceId != _lastSeenPrimaryDeviceId) {
      _lastSeenPrimaryDeviceId = primary?.deviceId;
      // Ownership moved, so the account's public live state may have changed
      // with it. Re-read rather than trust whatever this device last saw.
      unawaited(loadVerifiedStreamersFromBackend());
    }
    if (primary?.deviceId == device.deviceId) {
      // Promotion only follows this device's own claim; a viewer choice is
      // never overridden by a row it did not write.
      if (!_viewerDeviceChoice) {
        _currentDeviceSession = device.copyWith(isPrimaryBroadcaster: true);
      }
      _remoteBroadcasterSession = null;
    } else {
      _remoteBroadcasterSession = _viewerDeviceChoice ? null : primary;
      if (device.isPrimaryBroadcaster || _isBroadcastingLive) {
        _loseBroadcastDevice();
        return;
      }
    }
    // The 20 s heartbeat rewrites last_active_at, which echoes back here via
    // Realtime. Only notify when something a screen can show actually changed
    // (audit RT-04); otherwise every approved broadcaster rebuilt the app and
    // re-ran the router redirect every 20 s.
    final nowPrimary = _currentDeviceSession?.isPrimaryBroadcaster ?? false;
    if (nowPrimary == wasPrimary &&
        previousRemote?.deviceId == _remoteBroadcasterSession?.deviceId) {
      return;
    }
    notifyListeners();
  }

  String? _lastSeenPrimaryDeviceId;

  void _loseBroadcastDevice() {
    _deviceGeneration++;
    _clearPublishingState();
    _remoteBroadcasterSession = null;
    if (_currentDeviceSession == null) return;
    if (_isBroadcastingLive) _clearOwnLiveProjection();
    _liveSessionId = null;
    _liveWatchId = null;
    final changed = _currentDeviceSession!.isPrimaryBroadcaster ||
        _isBroadcastingLive ||
        _broadcastSessionError != 'broadcast_session_lost';
    _currentDeviceSession =
        _currentDeviceSession!.copyWith(isPrimaryBroadcaster: false);
    _broadcastSessionError = 'broadcast_session_lost';
    _isBroadcastingLive = false;
    _isStreamerModeEnabled = false;
    _viewerDeviceChoice = true;
    _heartbeatFailingSince = null;
    // A displaced device must not reclaim on restart or reconnect.
    unawaited(_persistViewerChoice(true));
    _stopLiveViewerPolling();
    if (changed) notifyListeners();
    unawaited(loadVerifiedStreamersFromBackend());
  }

  /// This device showed its own channel as live (setBroadcasterLive writes
  /// that into the catalog copy). Once the broadcast is over, that copy must
  /// not outlive it; the next catalog read replaces it with the server's.
  void _clearOwnLiveProjection() {
    final ownId = primaryOwnedStreamerId;
    if (ownId == null) return;
    _streamers = _streamers
        .map((s) => (s.streamerId == ownId || s.streamerId == _publishingSession?.id) && s.isLiveForRoom
            ? s.copyWith(
                isCurrentlyLive: false,
                broadcastType: BroadcastType.offline,
                activeViewerCount: 0,
                clearLiveState: true)
            : s)
        .toList();
  }

  /// Asks the server whether this device's broadcast is still live. Only a
  /// definite answer that was read after this device's last LIVE assertion
  /// counts; a failed read changes nothing (the next heartbeat retries).
  Future<void> _checkRemoteBroadcastEnd() async {
    final epoch = _liveAssertionEpoch;
    final generation = _deviceGeneration;
    final expected = _liveWatchId ?? _customYouTubeVideoId;
    final expectedSession = _liveSessionId;
    if ((!_isBroadcastingLive && _publishingSession?.active != true) || _liveStateBusy || _adminDbService == null) {
      return;
    }
    final Map<String, dynamic> status;
    try {
      status = await _adminDbService!.loadMyBroadcastStatus();
    } catch (e) {
      debugPrint('Broadcast status check failed: $e');
      return;
    }
    if (epoch != _liveAssertionEpoch ||
        generation != _deviceGeneration ||
        (!_isBroadcastingLive && _publishingSession?.active != true) ||
        _liveStateBusy) {
      return;
    }
    final sameSession = expectedSession == null ||
        status['session_id'] == null ||
        status['session_id'] == expectedSession;
    if (_publishingSession?.state == 'preparing' && status['state']=='preparing' && sameSession) return;
    if (status['live'] == true &&
        status['stream_id'] == expected &&
        sameSession) {
      return;
    }
    final lastEnded = status['last_ended'];
    final reason = status['live'] == true
        ? 'replaced'
        : (lastEnded is Map ? lastEnded['reason'] as String? : null) ?? 'ended';
    if (reason == 'device_transfer') {
      _loseBroadcastDevice();
      return;
    }
    if (reason == 'approval_revoked' || reason == 'ban') {
      // Their own refresh paths explain these; just stop claiming LIVE.
      _endBroadcastRemotely(reason);
      return;
    }
    _endBroadcastRemotely(reason);
  }

  /// The server ended this device's broadcast (an admin End, an expired
  /// heartbeat, another broadcast replacing it). Unlike a device transfer
  /// this keeps the device's primary role, broadcaster mode and approval;
  /// the phone screen stops its encoder and the user may start again.
  void _endBroadcastRemotely(String reason) {
    _clearPublishingState();
    _isBroadcastingLive = false;
    _liveSessionId = null;
    _liveWatchId = null;
    _remoteBroadcastEndReason = reason;
    _remoteBroadcastEndGeneration++;
    _clearOwnLiveProjection();
    _stopLiveViewerPolling();
    notifyListeners();
    unawaited(loadVerifiedStreamersFromBackend());
  }

  /// The sending phone reports its encoder connection for its own session.
  /// Returns false when the server says this session may no longer send
  /// (ended by an admin, a transfer or expiry): the caller must stop its
  /// encoder and must not start a new broadcast on its own. Unknown failures
  /// return true; the heartbeat decides those.
  Future<bool> reportBroadcastIngest({required bool sending}) async {
    final session = _liveSessionId;
    final device = _currentDeviceSession;
    if (session == null || device == null || _adminDbService == null) {
      return true;
    }
    // Only a change is reported. The encoder notifies on every bitrate
    // sample (about once a second); re-sending an unchanged state would be
    // one database write per second per broadcaster.
    if (_lastReportedIngest == (session, sending)) return true;
    try {
      await _adminDbService!.reportBroadcastIngest(
          sessionId: session, deviceId: device.deviceId, sending: sending);
      if (_liveSessionId == session) _lastReportedIngest = (session, sending);
      return true;
    } on PostgrestException catch (e) {
      if (_liveSessionId != session) return false;
      if (e.code == '55000') {
        await _checkRemoteBroadcastEnd();
        if (_liveSessionId == session) _endBroadcastRemotely('ended');
        return false;
      }
      if (e.code == '42501') {
        await _heartbeatDevice();
        return _liveSessionId == session &&
            _currentDeviceSession?.isPrimaryBroadcaster == true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Recovery may only resume this exact server session on this device. A
  /// failed read is uncertainty, never permission. Unlike ordinary ingest
  /// reporting this deliberately bypasses the dedup cache.
  Future<bool?> authorizeBroadcastRecovery() async {
    final session = _liveSessionId;
    final device = _currentDeviceSession;
    final generation = _deviceGeneration;
    final epoch = _liveAssertionEpoch;
    final watch = _liveWatchId;
    bool current() =>
        !_disposed &&
        _isBroadcastingLive &&
        session != null &&
        _liveSessionId == session &&
        generation == _deviceGeneration &&
        epoch == _liveAssertionEpoch &&
        _currentDeviceSession?.deviceId == device?.deviceId &&
        _currentDeviceSession?.isPrimaryBroadcaster == true;
    if (!current() ||
        _adminDbService == null ||
        _authService.currentSession == null) {
      return false;
    }
    try {
      final status = await _adminDbService!.loadMyBroadcastStatus();
      if (!current()) return false;
      if (status['live'] != true ||
          status['session_id'] != session ||
          status['stream_id'] != watch ||
          status['device_id'] != device?.deviceId) {
        _endBroadcastRemotely('ended');
        return false;
      }
      final permitted = await _adminDbService!.canBroadcast(
          orgId: _selectedBroadcastOrgId, type: _customBroadcastType.name);
      if (!current()) return false;
      if (!permitted) {
        _endBroadcastRemotely('approval_revoked');
        return false;
      }
      // This RPC locks and verifies the exact session/device against End,
      // transfer and moderation. It does not start or recreate a session.
      await _adminDbService!.reportBroadcastIngest(
          sessionId: session!, deviceId: device!.deviceId, sending: false);
      return current();
    } on PostgrestException catch (e) {
      if (!current()) return false;
      if (e.code == '42501' || e.code == '55000') {
        _endBroadcastRemotely('ended');
        return false;
      }
      return null;
    } catch (_) {
      return current() ? null : false;
    }
  }

  @visibleForTesting
  void endBroadcastRemotelyForTesting(String reason) =>
      _endBroadcastRemotely(reason);

  @visibleForTesting
  void setBroadcastingLiveForTesting(bool live) {
    _isBroadcastingLive = live;
    notifyListeners();
  }

  Future<void> signOutOtherDevices() async {
    await _authService.signOutOthers();
    if (_currentDeviceSession != null && _isApprovedStreamer) {
      await transferBroadcasterToCurrentDevice();
    }
  }

  void continueAsViewerOnCurrentDevice() {
    _viewerDeviceChoice = true;
    _isBroadcastingLive = false;
    _remoteBroadcasterSession = null;
    if (_currentDeviceSession != null) {
      _currentDeviceSession =
          _currentDeviceSession!.copyWith(isPrimaryBroadcaster: false);
    }
    _isStreamerModeEnabled = false;
    unawaited(_persistViewerChoice(true));
    notifyListeners();

    final userId = _authService.currentSession?.user.id;
    final device = _currentDeviceSession;
    if (userId != null && device != null) {
      _adminDbService?.upsertDeviceSession(userId: userId, session: device);
    }
  }

  /// Called when the app returns to the foreground. Android may freeze a
  /// backgrounded app and a browser may pause a hidden tab, so Realtime
  /// events and timers can be missed. Re-check the server-owned state now:
  /// ban status, approval, and whether this device is still primary.
  Future<void> onAppResumed() async {
    if (_sessionUserId == null || _authHydrating) return;
    await _refreshCurrentUserBanStatus();
    await refreshMyApplicationAndStreamerStatus();
    final device = _currentDeviceSession;
    if (device == null) return;
    if (device.isPrimaryBroadcaster) {
      await _heartbeatDevice();
      await loadVerifiedStreamersFromBackend();
    } else if (isApprovedStreamer &&
        !_viewerDeviceChoice &&
        _remoteBroadcasterSession == null) {
      await initDeviceSession();
    }
  }

  void selectViewerRole() {
    _hasCompletedRoleSelection = true;
    _isStreamerModeEnabled = false;
    unawaited(_persistRoleSelection());
    notifyListeners();
  }

  void selectBroadcasterRole() {
    _hasCompletedRoleSelection = true;
    unawaited(_persistRoleSelection());
    notifyListeners();
  }

  Future<void> _persistRoleSelection() async {
    final userId = _sessionUserId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_role_selection_$userId', true);
  }

  /// Returns the single primary streamer ID owned by this user account, if any.
  String? get primaryOwnedStreamerId {
    if (_selectedBroadcastOrgId != null &&
        _selectedBroadcastOrgId!.isNotEmpty) {
      return _selectedBroadcastOrgId;
    }
    if (_myApplication != null) {
      return _myApplication!.applicantProfileId ?? _myApplication!.id;
    }
    return _authService.currentSession?.user.id;
  }

  /// Checks if the given streamerId represents the currently signed-in user's single channel.
  bool isOwnStreamerProfile(String streamerId) {
    if (streamerId.isEmpty) return false;
    final primaryId = primaryOwnedStreamerId;
    if (primaryId != null && streamerId == primaryId) {
      return true;
    }
    if (_myApplication != null &&
        _myApplication!.youtubeHandle.replaceAll('@', '').toLowerCase() ==
            streamerId.toLowerCase()) {
      return true;
    }
    return false;
  }

  /// Detects whether multiple streamer cards in the feed belong to this user
  List<StreamerModel> detectDuplicateChannels() {
    // Ownership is decided only by isOwnStreamerProfile (selected org, the
    // caller's approved application, or the authenticated user id) -- never
    // by a hardcoded id, a display name or a developer email (P1.6).
    final duplicates = _streamers
        .where((s) => isOwnStreamerProfile(s.streamerId))
        .toSet()
        .toList();

    if (duplicates.length > 1) {
      return duplicates;
    }
    return [];
  }

  /// Removes the unselected duplicate channel from feed and keeps the chosen one
  void resolveDuplicateChannels({required String keptStreamerId}) {
    _streamers.removeWhere((s) =>
        s.streamerId != keptStreamerId && isOwnStreamerProfile(s.streamerId));
    notifyListeners();
  }

  @visibleForTesting
  void setBroadcasterStatusForTesting({
    bool isLoggedIn = true,
    bool isApproved = true,
  }) {
    _isLoggedInStreamer = isLoggedIn;
    _isApprovedStreamer = isApproved;
    _isStreamerModeEnabled = isApproved;
    notifyListeners();
  }

  /// Seeds a streamer's recordings/playlists the way a real backend load
  /// would. Tests use it instead of the sample archive that used to be
  /// compiled into lib/ (P2 truthful data).
  @visibleForTesting
  void setStreamerMediaForTests(
    String streamerId, {
    List<VodModel>? vods,
    List<PlaylistModel>? playlists,
  }) {
    if (vods != null) _streamerVods[streamerId] = vods;
    if (playlists != null) _streamerPlaylists[streamerId] = playlists;
    notifyListeners();
  }

  @visibleForTesting
  void addStreamerForTests(StreamerModel streamer) {
    _streamers.add(streamer);
    notifyListeners();
  }

  bool isPermittedAdminFor(String streamerId) {
    if (streamerId.isEmpty) return false;
    if (_isAdminFromRoles || _isMasterAdminFromRoles) return true;
    return _permittedAdminOrgIds.contains(streamerId);
  }

  String get currentUserHandle {
    final fromApp = _approvedChannelHandle;
    if (fromApp.isNotEmpty) {
      return fromApp.replaceFirst('@', '');
    }
    final email = _googleUserEmail ?? _userProfile.id;
    return email.split('@').first.toLowerCase();
  }

  /// The channel id this account broadcasts as, or null when the account owns
  /// no channel. Never falls back to a sample/demo id (P1.6): callers must
  /// handle null instead of acting on someone else's channel.
  String? get currentUserStreamerId => primaryOwnedStreamerId;

  // ---------------------------------------------------------------------
  // Stream Decay Engine (issue_log.md QF-11)
  // ---------------------------------------------------------------------
  late final StreamDecayEngine _streamDecayEngine = StreamDecayEngine(
    onStreamDecayed: () {
      debugPrint('[AppProvider] Broadcast decayed due to inactivity.');
      if (_isBroadcastingLive) {
        toggleBroadcasterGoLive();
      }
    },
  );
  StreamDecayEngine get streamDecayEngine => _streamDecayEngine;

  void recordStreamHeartbeat() {
    _streamDecayEngine.recordHeartbeat();
  }

  // ---------------------------------------------------------------------
  // Private & Restricted Streaming (client-simulated)
  // ---------------------------------------------------------------------

  StreamVisibility get streamVisibility => _streamVisibility;
  bool get isActiveStreamPrivate =>
      kPrivateStreamingEnabled &&
      _isBroadcastingLive &&
      _streamVisibility == StreamVisibility.private;
  List<String> get streamWhitelistHandles =>
      List.unmodifiable(_streamWhitelistHandles);
  bool get requireKnockApproval => _requireKnockApproval;
  List<StreamKnockRequest> get pendingKnockRequests =>
      List.unmodifiable(_pendingKnockRequests);
  List<StreamAttendee> get admittedAttendees =>
      List.unmodifiable(_admittedAttendees);

  /// Persists the Public/Private access choice + whitelist + knock-gate
  /// toggle from the Broadcaster Studio sheet's access section. Purely
  /// in-memory simulation, mirroring setCustomBroadcastMeta's pattern.
  void configureStreamPrivacy({
    required StreamVisibility visibility,
    List<String>? whitelistHandles,
    bool? requireKnockApproval,
  }) {
    _streamVisibility =
        kPrivateStreamingEnabled ? visibility : StreamVisibility.public;
    if (whitelistHandles != null) {
      _streamWhitelistHandles = List.of(whitelistHandles);
    }
    if (requireKnockApproval != null) {
      _requireKnockApproval = requireKnockApproval;
    }
    notifyListeners();
  }

  void addStreamWhitelistHandle(String handle) {
    final normalized = handle.trim();
    if (normalized.isEmpty || _streamWhitelistHandles.contains(normalized)) {
      return;
    }
    _streamWhitelistHandles = [..._streamWhitelistHandles, normalized];
    notifyListeners();
  }

  void removeStreamWhitelistHandle(String handle) {
    _streamWhitelistHandles =
        _streamWhitelistHandles.where((h) => h != handle).toList();
    notifyListeners();
  }

  /// Fake, non-cryptographic invite token -- there is no real deep-link
  /// backend to resolve this against in this simulated app.
  String generatePrivateInviteLink() {
    if (!kPrivateStreamingEnabled) return '';
    final token = newId().substring(0, 8);
    final streamId = _activeStreamIdForCurrentUser();
    if (streamId == null) return '';
    return 'https://streamer.app/join/$streamId?t=$token';
  }

  String? _activeStreamIdForCurrentUser() {
    final targetStreamerId = primaryOwnedStreamerId;
    if (targetStreamerId == null) return null;
    for (final streamer in _streamers) {
      if (streamer.streamerId == targetStreamerId) {
        return streamer.activeStreamId;
      }
    }
    return null;
  }

  /// Demo-only trigger synthesizing a knock from a canned name pool --
  /// there's no second device/session in this simulated app, so incoming
  /// knocks need an on-demand trigger to be demonstrable/testable at all
  /// (mirrors admin_hub_screen.dart's "Simulate Live Push Notification"
  /// pattern for the same class of problem).
  void simulateIncomingKnock() {
    if (!kDebugMode || !kPrivateStreamingEnabled) return;
    final name = _demoKnockNamePool[
        _pendingKnockRequests.length % _demoKnockNamePool.length];
    _pendingKnockRequests.add(StreamKnockRequest(
      id: newId(),
      displayName: name,
      requestedAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void admitKnockRequest(String requestId) {
    final index = _pendingKnockRequests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    final req = _pendingKnockRequests.removeAt(index);
    _admittedAttendees
        .add(StreamAttendee(id: req.id, displayName: req.displayName));
    notifyListeners();
  }

  void denyKnockRequest(String requestId) {
    _pendingKnockRequests.removeWhere((r) => r.id == requestId);
    notifyListeners();
  }

  void admitAllKnockRequests() {
    _admittedAttendees.addAll(_pendingKnockRequests.map(
      (r) => StreamAttendee(id: r.id, displayName: r.displayName),
    ));
    _pendingKnockRequests.clear();
    notifyListeners();
  }

  /// Director-panel "search/add @username"action -- admits a viewer
  /// directly, distinct from addStreamWhitelistHandle (which only affects
  /// future streams'pre-approval, not the current live attendee list).
  void admitAttendeeByHandle(String handle) {
    final normalized = handle.trim();
    if (normalized.isEmpty) return;
    if (_admittedAttendees.any((a) => a.id == normalized)) return;
    _admittedAttendees.add(StreamAttendee(
      id: normalized,
      displayName: normalized,
      isVip: _streamWhitelistHandles.contains(normalized),
    ));
    notifyListeners();
  }

  void kickAttendee(String attendeeId) {
    _admittedAttendees.removeWhere((a) => a.id == attendeeId);
    notifyListeners();
  }

  String get _localViewerIdentity => _googleUserEmail ?? _userProfile.id;

  /// This viewer's own relationship to the currently-active private stream.
  ViewerAccessState get localViewerAccessState {
    if (!isActiveStreamPrivate) return ViewerAccessState.notApplicable;
    final me = _localViewerIdentity;
    if (_streamWhitelistHandles.contains(me) ||
        _streamWhitelistHandles.contains('@$me')) {
      return ViewerAccessState.vipPreApproved;
    }
    if (_admittedAttendees.any((a) => a.id == me)) {
      return ViewerAccessState.admitted;
    }
    if (_pendingKnockRequests.any((r) => r.id == me)) {
      return ViewerAccessState.knocking;
    }
    return ViewerAccessState.denied;
  }

  void requestToJoinActiveStream() {
    final me = _localViewerIdentity;
    if (_pendingKnockRequests.any((r) => r.id == me)) return;
    final name = _googleUserName ?? _userProfile.nameEn;
    _pendingKnockRequests.add(StreamKnockRequest(
      id: me,
      displayName: name,
      requestedAt: DateTime.now(),
    ));
    notifyListeners();
  }

  Future<void> refreshMyApplicationAndStreamerStatus() async {
    final generation = _authGeneration;
    final user = _authService.currentSession?.user;
    if (user == null) return;
    final wasApproved = isApprovedStreamer;
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      var isStreamer = await _adminDbService!.checkIsProfileStreamer(user.id);
      final myApp = await _adminDbService!.loadMyApplication(user.id);
      final profile = await _adminDbService!.loadOwnProfile(user.id);
      if (_authGeneration != generation) return;
      if (profile != null) {
        _personalBroadcastApproved = profile['personal_broadcast_approved'] == true;
        _organizationBroadcastApproved = profile['organization_broadcast_approved'] == true;
        _userProfile = UserProfileModel.defaultProfile.copyWith(
          nameEn: profile['display_name_en'] as String? ?? _googleUserName,
          nameAr: profile['display_name_ar'] as String? ?? _googleUserName,
          avatarUrl: profile['avatar_url'] as String? ?? _googleUserAvatar,
          bannerUrl: profile['banner_url'] as String? ?? '',
          bioEn: profile['bio_en'] as String? ?? '',
          bioAr: profile['bio_ar'] as String? ?? '',
          titleEn: profile['title_en'] as String? ?? '',
          titleAr: profile['title_ar'] as String? ?? '',
          youtubeChannelUrl: profile['youtube_handle'] as String? ?? '',
          isVerifiedScholar: profile['is_verified'] == true,
        );
        // The row says not live while this device thinks it is. That may be
        // an admin End, an expiry, or simply a read that raced this device's
        // own start; ask the server which, instead of assuming the device
        // was displaced (owner retest 2026-09-25, Test 6 Issue A).
        if (_isBroadcastingLive && profile['is_currently_live'] != true) {
          unawaited(_checkRemoteBroadcastEnd());
        }
      }

      // checkIsProfileStreamer reports a failed read as "not a streamer". A
      // revocation is only applied when the profile row itself shows it.
      if (!isStreamer &&
          _isApprovedStreamer &&
          profile != null &&
          profile['is_streamer'] == true &&
          profile['is_verified'] == true) {
        isStreamer = true;
      }

      final previousApp = _myApplication;
      _myApplication = myApp;

      if (myApp == null) {
        _applications.removeWhere((a) =>
            a.applicantProfileId == user.id ||
            (user.email != null &&
                a.email.toLowerCase() == user.email!.toLowerCase()));
      }

      if (_authGeneration != generation) return;
      if (isStreamer) {
        _isApprovedStreamer = true;

        if (previousApp != null &&
            previousApp.status == ApplicationStatus.pending &&
            myApp?.status == ApplicationStatus.approved) {
          addEnhancedNotification(
            AppNotificationModel(
              id: 'notif_app_approved_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.streamerApplicationApproved,
              streamerId: user.id,
              streamerName: _googleUserName ?? 'Broadcaster',
              titleEn: 'Broadcaster Application Approved!',
              titleAr: 'تم قبول طلب توثيق البث!',
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
    _personalBroadcastApproved = false;
    _organizationBroadcastApproved = false;
        _isStreamerModeEnabled = false;

        if (previousApp != null && myApp == null) {
          addEnhancedNotification(
            AppNotificationModel(
              id: 'notif_app_removed_${DateTime.now().millisecondsSinceEpoch}',
              type: NotificationType.systemAlert,
              streamerId: user.id,
              streamerName: _googleUserName ?? 'User',
              titleEn: 'Application Status Update',
              titleAr: 'تحديث حالة الطلب',
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
              titleEn: 'Broadcaster Application Status Update',
              titleAr: 'تحديث بخصوص طلب التوثيق الأكاديمي',
              bodyEn:
                  'We could not approve your application at this time: "$reason". You are welcome to re-apply!',
              bodyAr:
                  'تعذر قبول الطلب حالياً للملاحظات التالية: «$reason». يسعدنا تقديمك مجدداً بعد التعديل!',
              timestamp: DateTime.now(),
            ),
          );
        }
      }
      // Hydration applies its own mode and device claim; afterwards an
      // approval or revocation takes effect immediately instead of after a
      // restart.
      if (!_authHydrating && _authGeneration == generation) {
        if (!wasApproved && isApprovedStreamer) {
          _isStreamerModeEnabled = !_viewerDeviceChoice;
          unawaited(initDeviceSession());
        } else if (wasApproved && !isApprovedStreamer) {
          _revokeLocalBroadcastState();
        }
      }
      await loadVerifiedStreamersFromBackend();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshMyApplicationAndStreamerStatus failed: $e');
    }
  }

  /// Broadcaster approval was withdrawn by the server. Stop claiming LIVE,
  /// drop the device claim (the server has already demoted it) and leave
  /// broadcaster mode; the phone screen listens and releases camera/mic.
  void _revokeLocalBroadcastState() {
    _clearPublishingState();
    _deviceGeneration++;
    _deviceHeartbeatTimer?.cancel();
    _deviceSubscription?.cancel();
    _deviceSubscription = null;
    if (_currentDeviceSession != null) {
      _currentDeviceSession =
          _currentDeviceSession!.copyWith(isPrimaryBroadcaster: false);
    }
    _remoteBroadcasterSession = null;
    _isBroadcastingLive = false;
    _liveSessionId = null;
    _liveWatchId = null;
    _isStreamerModeEnabled = false;
    _liveStateBusy = false;
    _broadcastSessionError = 'broadcast_approval_required';
    _stopLiveViewerPolling();
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
              // Never print profile payloads containing account data.
              refreshMyApplicationAndStreamerStatus();
            },
          )
          // A ban arrives as an INSERT/UPDATE on the account's own row.
          // Filtered DELETE events are not delivered by Realtime, so an unban
          // is picked up by the polling in _refreshCurrentUserBanStatus.
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'banned_users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: userId,
            ),
            callback: (_) => _refreshCurrentUserBanStatus(),
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

  /// Realtime events on profiles/organizations/applications arrive in bursts
  /// (one edit can touch several rows); each used to trigger a full catalog
  /// read and, for admins, five admin reads (audit NET-10). Coalesce them.
  Timer? _realtimeRefreshTimer;
  bool _realtimeNeedsAdminRefresh = false;

  void _scheduleRealtimeRefresh({required bool admin}) {
    _realtimeNeedsAdminRefresh = _realtimeNeedsAdminRefresh || admin;
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(const Duration(seconds: 1), () {
      final withAdmin = _realtimeNeedsAdminRefresh;
      _realtimeNeedsAdminRefresh = false;
      if (_disposed) return;
      if (withAdmin) {
        refreshAdminData(); // also reloads the public catalog
      } else {
        loadVerifiedStreamersFromBackend();
      }
    });
  }

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
              _scheduleRealtimeRefresh(admin: _isAdminFromRoles);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'organizations',
            callback: (payload) {
              _scheduleRealtimeRefresh(admin: _isAdminFromRoles);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'broadcaster_applications',
            callback: (payload) {
              _scheduleRealtimeRefresh(admin: true);
            },
          )
          // Explicit low-latency signal for admin-triggered deletions, in
          // addition to the postgres_changes listeners above -- a broadcast
          // event doesn't depend on replica identity / column-level change
          // detection, so it arrives even for edge cases those might miss
          // (issue_log.md: "when I delete an account as an admin, I can see
          // the change ... in my web test, but not in my phone").
          .onBroadcast(
            event: 'streamer_deleted',
            callback: (payload) {
              final deletedId = payload['streamerId'] as String?;
              if (deletedId != null) {
                debugPrint('Realtime: streamer_deleted broadcast ($deletedId)');
                _streamers.removeWhere((s) =>
                    s.streamerId == deletedId ||
                    s.streamerId == 'streamer_$deletedId');
                notifyListeners();
              }
              loadVerifiedStreamersFromBackend();
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
  /// Last time this client asked the backend to expire stale live flags.
  /// A broadcaster whose phone dies stops sending heartbeats, so the flag has
  /// to be cleared server-side; every client that reads the feed nudges that
  /// sweep at most once a minute.
  DateTime? _lastLiveFlagSweepAt;
  Future<void>? _catalogFollowUp;
  DateTime? _lastCatalogSuccessAt;

  /// Re-reads the public catalog when the last successful read is older than
  /// [maxAge]. Live state of other broadcasters never reaches a non-admin
  /// client over Realtime (profiles RLS lets an account read only its own
  /// row), so screens that show LIVE must keep it fresh themselves.
  Future<void> refreshCatalogIfOlderThan(Duration maxAge) {
    final last = _lastCatalogSuccessAt;
    if (last != null && DateTime.now().difference(last) < maxAge) {
      return Future<void>.value();
    }
    return loadVerifiedStreamersFromBackend();
  }

  static const Duration _liveFlagSweepInterval = Duration(seconds: 60);

  Future<void> loadVerifiedStreamersFromBackend() {
    if (_disposed || !isOnline) return Future<void>.value();
    final active = _publicCatalogLoad;
    if (active != null && _publicCatalogLoadEpoch == _catalogEpoch) {
      // A load is already running, but it may have read the catalog before
      // the change that triggered this call (a Realtime event arriving
      // mid-request). Queue exactly one more read after it, so the newest
      // request is always answered by data read after it was made.
      return _catalogFollowUp ??= active.then((_) {
        _catalogFollowUp = null;
        return loadVerifiedStreamersFromBackend();
      });
    }
    final epoch = _catalogEpoch;
    final request = _fetchVerifiedStreamers(epoch);
    _publicCatalogLoad = request;
    _publicCatalogLoadEpoch = epoch;
    notifyListeners();
    request.whenComplete(() {
      if (identical(_publicCatalogLoad, request)) {
        _publicCatalogLoad = null;
        if (!_disposed) notifyListeners();
      }
    });
    return request;
  }

  Future<void> _fetchVerifiedStreamers(int epoch) async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      final now = DateTime.now();
      if (_lastLiveFlagSweepAt == null ||
          now.difference(_lastLiveFlagSweepAt!) >= _liveFlagSweepInterval) {
        _lastLiveFlagSweepAt = now;
        // Cleanup is optional for reading public truth, so it runs beside the
        // read instead of in front of it (it used to delay every catalog load
        // by up to 2 s once a minute, audit NET-04). Its effect shows in the
        // next poll; a pg_cron job (supabase/cron/sweep_stale_live_flags.sql)
        // is the durable replacement for this client call.
        unawaited(_adminDbService!.sweepStaleLiveFlags());
      }
      // The broadcast-session read is independent of the profile reads, so it
      // runs beside them (audit NET-04).
      final sessionsRead = _organizationBroadcastService
          .sessions()
          .timeout(const Duration(seconds: 5))
        ..ignore();
      final backendStreamers = await _adminDbService!
          .loadVerifiedStreamersFromBackend(requireSuccess: true)
          .timeout(const Duration(seconds: 5));
      final sessions = await sessionsRead;
      if (_disposed || epoch != _catalogEpoch || !isOnline) return;
      _broadcastSessions=List.unmodifiable(sessions);
      _lastLoadedPublicStreamers = List.of(backendStreamers);

      final backendIds = backendStreamers.map((s) => s.streamerId).toSet();
      // Remove any previously-loaded backend streamer that is no longer verified in DB
      _streamers.removeWhere((s) =>
          _looksLikeUuid(s.streamerId.replaceFirst('streamer_', '')) &&
          !backendIds.contains(s.streamerId));

      for (final bs in backendStreamers) {
        final displayStreamer = isOnline
            ? bs
            : bs.copyWith(
                isCurrentlyLive: false,
                broadcastType: BroadcastType.offline,
                activeViewerCount: 0,
                clearLiveState: true,
              );
        final idx = _streamers.indexWhere((s) => s.streamerId == bs.streamerId);
        if (idx != -1) {
          _streamers[idx] = displayStreamer;
        } else {
          _streamers.add(displayStreamer);
        }
      }
      final canonicalOwners=sessions.where((s)=>s.live).map((s)=>s.organizationId??s.presenterId).toSet();
      final presenters=sessions.where((s)=>s.live).map((s)=>s.presenterId).toSet();
      _streamers=_streamers.where((s)=>s.contentOwnerId==null).map((s)=>canonicalOwners.contains(s.streamerId)||presenters.contains(s.streamerId)
        ?s.copyWith(isCurrentlyLive:false,broadcastType:BroadcastType.offline,clearLiveState:true):s).toList();
      _streamers.addAll(sessions.where((s)=>s.live && !s.hidden).map(_sessionProjection).whereType<StreamerModel>());
      _isUsingCachedCatalog = false;
      _successfulCatalogRevision++;
      _lastCatalogSuccessAt = DateTime.now();
      _closeMiniPlayerIfBroadcastEnded();
      notifyListeners();
      unawaited(_persistPublicCatalogIfReady());
      // UI-08: refresh the offline fallback snapshot every time a backend
      // load actually succeeds.
      unawaited(_persistMapMarkerCache());
    } catch (e) {
      debugPrint('loadVerifiedStreamersFromBackend failed: $e');
    }
  }

  void _clearAuthState() {
    _authGeneration++;
    _sessionUserId = null;
    _hydratingUserId = null;
    _authHydrating = false;
    _hasCompletedRoleSelection = false;
    _viewerDeviceChoice = false;
    _selectedBroadcastOrgId = null;
    _selectedVenueBranchId = null;
    _selectedCoSpeakerIds = [];
    _userProfile = UserProfileModel.defaultProfile;
    _adminRoleLoading = false;
    _deviceGeneration++;
    _deviceHeartbeatTimer?.cancel();
    _deviceSubscription?.cancel();
    _currentDeviceSession = null;
    _remoteBroadcasterSession = null;
    _isBroadcastingLive = false;
    _liveSessionId = null;
    _liveWatchId = null;
    _broadcastSenderMode = 'unspecified';
    _remoteBroadcastEndReason = null;
    _unsubscribeFromUserStatusChanges();
    _broadcastSessionError = null;
    _liveStateBusy = false;
    _phoneBroadcastStreamKey = '';
    _customYouTubeLiveUrl = '';
    _customYouTubeVideoId = '';
    _customLiveTitle = '';
    _customLiveDescription = '';
    _customLiveVenue = '';
    _customSlidesUrl = '';
    _stopLiveViewerPolling();
    _isLoggedInStreamer = false;
    _isStreamerModeEnabled = false;
    _isApprovedStreamer = false;
    _personalBroadcastApproved = false;
    _organizationBroadcastApproved = false;
    _orgMemberships = [];
    _myOrgInvitations = [];
    _orgEvents = [];
    _announcedOrgEvents.clear();
    _notifications.removeWhere((n) => n.id.startsWith('org:'));
    _enhancedNotifications.removeWhere((n) => n.id.startsWith('org:'));
    _channelConnections = [];
    _broadcastSessions=[];_roomSessions.clear();_roomRevisions.clear();_clearPublishingState();
    _myApplication = null;
    _debugUserId = null;
    _googleUserEmail = null;
    _googleUserName = null;
    _googleUserAvatar = null;
    _isAdminFromRoles = false;
    _isMasterAdminFromRoles = false;
    _permittedAdminOrgIds = [];
    _isCurrentUserBanned = false;
    _currentUserBanReason = null;
    _syncBanPolling();
    // The signed-in account's library goes with the session (05 D-07); the
    // next account must not inherit its follows and saved recordings.
    _followedStreamerIds.clear();
    _bookmarks.clear();
    _pendingBookmarks.clear();
    _loadingBookmarks = false;
    _bookmarkLoadFailed = false;
    _bookmarkRevision++;
    _reminderStreamerIds.clear();
    _cardReminderIds.clear();
    _reminderLeadMinutes = 15;
    _reminderPushStatus = ReminderPushStatus.unavailable;
    _notifications.removeWhere((n) => n.id.startsWith('upcoming:'));
    _upcomingByStreamer.clear();
    _upcomingErrors.clear();
    _loadingUpcoming.clear();
    notifyListeners();
  }

  /// Test-only: simulates a signed-in session without a real Supabase round
  /// trip. Production code paths never call this -- real auth state comes
  /// exclusively from _applySessionUser/_refreshAdminRoleFromBackend above.
  @visibleForTesting

  /// [ownedStreamerId] attaches an approved broadcaster application for that
  /// channel, which is one of the three real ownership sources
  /// (see [primaryOwnedStreamerId]). Tests must use it instead of relying on a
  /// particular email: no email grants ownership of a channel (P1.6).
  void debugSetSignedInForTests({
    required String email,
    String? name,
    bool isAdmin = false,
    bool isMasterAdmin = false,
    bool isStreamer = true,
    List<String> permittedAdminOrgIds = const [],
    String? ownedStreamerId,
    String ownedYoutubeHandle = '',
    bool personalBroadcastApproved = false,
    bool organizationBroadcastApproved = false,
    String? userId,
  }) {
    _debugUserId = userId;
    _personalBroadcastApproved = personalBroadcastApproved;
    _organizationBroadcastApproved = organizationBroadcastApproved;
    _hasCompletedOnboarding = true;
    _isLoggedInStreamer = true;
    _isGuestViewer = false;
    _isApprovedStreamer = isStreamer;
    _hasCompletedRoleSelection = true;
    _isStreamerModeEnabled = isStreamer;
    _googleUserEmail = email;
    _googleUserName = name ?? email;
    _isAdminFromRoles = isAdmin || isMasterAdmin;
    _isMasterAdminFromRoles = isMasterAdmin;
    _permittedAdminOrgIds = permittedAdminOrgIds;
    _myApplication = ownedStreamerId == null
        ? null
        : BroadcasterApplicationModel(
            id: ownedStreamerId,
            applicantProfileId: ownedStreamerId,
            accountType: ApplicationAccountType.individualScholar,
            applicantNameEn: name ?? email,
            applicantNameAr: name ?? email,
            email: email,
            phone: '',
            categoryId: '',
            venueNameEn: '',
            venueNameAr: '',
            latitude: 0,
            longitude: 0,
            youtubeChannelUrl: '',
            youtubeHandle: ownedYoutubeHandle,
            bioEn: '',
            bioAr: '',
            avatarUrl: '',
            bannerUrl: '',
            status: ApplicationStatus.approved,
            submittedAt: DateTime.now(),
          );
    notifyListeners();
  }

  Future<void> _initAdminDatabase() async {
    _subscribeToPublicStreamerChanges();
    _subscribeToAcademicCategoryChanges();
    // These four reads are independent, so they run together instead of as a
    // chain of round-trips that held the feed chips behind the admin loads
    // (audit NET-05). Categories/approved-tags are public data (Cluster 3
    // Tasks 10/12) -- loaded for every viewer, including guests.
    await Future.wait<void>([
      loadVerifiedStreamersFromBackend(),
      refreshAdminData(includePublicCatalog: false),
      ensureAcademicCategoriesLoaded(),
      ensureTagsLoaded(),
    ]);
  }

  RealtimeChannel? _academicCategoriesChannel;

  /// Task 11: without this, an admin's category add/edit/delete only ever
  /// reached the admin's own device -- every other signed-in client kept
  /// its one-shot cached list until restart (testing_check_list.md: "the
  /// rest of the users must get the live update").
  void _subscribeToAcademicCategoryChanges() {
    _unsubscribeFromAcademicCategoryChanges();
    try {
      if (!Supabase.instance.isInitialized) return;
      _academicCategoriesChannel = Supabase.instance.client
          .channel('academic_categories_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'academic_categories',
            callback: (payload) {
              _refreshAcademicCategories();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime academic_categories subscription failed: $e');
    }
  }

  void _unsubscribeFromAcademicCategoryChanges() {
    if (_academicCategoriesChannel != null) {
      try {
        if (Supabase.instance.isInitialized) {
          Supabase.instance.client.removeChannel(_academicCategoriesChannel!);
        }
      } catch (_) {}
      _academicCategoriesChannel = null;
    }
  }

  /// Reloads all admin-tier data (applications, audit logs, analytics, affiliation requests)
  /// from the Supabase backend.
  Future<void> refreshAdminData({bool includePublicCatalog = true}) async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      final db = _adminDbService!;
      // Five independent reads, issued together (audit NET-05).
      final (applications, _, terms, analytics, auditLogs, affiliations) = await (
        db.loadApplications(),
        _refreshApplicationReviewEvents(),
        db.loadTerms(),
        db.loadAnalytics(),
        db.loadAuditLogs(),
        db.loadAffiliationRequests(),
      ).wait;
      _applications = List.from(applications);
      _termsAndConditions = terms;
      _viewerAnalytics = analytics;
      _auditLogs = List.from(auditLogs);
      _affiliationRequests = List.from(affiliations);
      if (includePublicCatalog) await loadVerifiedStreamersFromBackend();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshAdminData failed: $e');
    }
  }

  /// Polls YouTube's concurrent-viewer figure for the broadcaster's OWN stream,
  /// and only while their studio is open ([startStudioViewerPolling] /
  /// [stopStudioViewerPolling]). It used to run in every client for every live
  /// stream, which spent the shared YouTube quota for a number only the studio
  /// shows (audit NET-01).
  String? _studioPollStreamerId;

  void startStudioViewerPolling(String streamerId) {
    if (streamerId.isEmpty) return;
    if (_liveViewerTimer?.isActive == true &&
        _studioPollStreamerId == streamerId) {
      return;
    }
    _liveViewerTimer?.cancel();
    _studioPollStreamerId = streamerId;
    _pollLiveViewers();
    _liveViewerTimer = Timer.periodic(_liveViewerPollInterval, (_) {
      _pollLiveViewers();
    });
  }

  void stopStudioViewerPolling() => _stopLiveViewerPolling();

  /// Kept for the app root and splash screen. Global YouTube polling was
  /// removed (audit NET-01); the studio starts its own scoped poll through
  /// [startStudioViewerPolling]. Intentionally does nothing.
  void ensureLivePollingActive() {}

  /// Public entry-point (main.dart / app root only, same rule as
  /// [ensureLivePollingActive]) that starts live connectivity monitoring for
  /// the Spatial Map's offline experience (UI-08). Checks the current status
  /// immediately, then subscribes so [isOnline] and the cached-marker
  /// fallback stay live; recovering from offline automatically retries the
  /// backend streamer load ("Retry and recover when connectivity returns").
  void ensureConnectivityMonitoringActive() {
    _connectivityService ??= ConnectivityService();
    _connectivitySub?.cancel();
    final generation = ++_connectivityGeneration;
    var eventRevision = 0;
    _connectivitySub = _connectivityService!.onStatusChange.listen((status) {
      eventRevision++;
      if (generation == _connectivityGeneration) _applyConnectivity(status);
    });
    // After subscribing, so a status change that lands while the initial
    // probe is still in flight is not overwritten by its staler answer.
    final initialCheck = _connectivityService!.checkNow();
    final probeRevision = _connectivityService!.revision;
    initialCheck.then((status) {
      if (generation == _connectivityGeneration &&
          eventRevision == 0 &&
          probeRevision == _connectivityService!.revision) {
        _applyConnectivity(status);
      }
    });
  }

  /// The app root calls this when Flutter hides or resumes the app.
  void setConnectivityForeground(bool foreground) {
    _connectivityService?.setForeground(foreground);
  }

  void _applyConnectivity(NetworkStatus status) {
    if (_disposed) return;
    final wasUnavailable = !isOnline;
    if (_networkStatus == status) return;
    _catalogEpoch++;
    _categoryRequestGeneration++;
    _categoriesLoad = null;
    _networkStatus = status;
    if (status != NetworkStatus.online) {
      _isUsingCachedCatalog = true;
      _streamers = _streamers
          .map((s) => s.copyWith(
                isCurrentlyLive: false,
                broadcastType: BroadcastType.offline,
                activeViewerCount: 0,
                clearLiveState: true,
              ))
          .toList();
    }
    notifyListeners();
    if (wasUnavailable && isOnline) {
      loadVerifiedStreamersFromBackend();
    }
  }

  /// Re-probes connectivity on demand and returns the fresh state.
  ///
  /// The Spatial Map's offline banner needs this, not just another backend
  /// fetch: `connectivity_plus` only emits on *change*, so an app that cold
  /// started offline (or that missed an event) would otherwise stay pinned to
  /// `isOnline == false` forever no matter how many times the user tapped
  /// Retry -- the banner's own escape hatch could not actually escape.
  Future<bool> refreshConnectivityNow() async {
    _connectivityService ??= ConnectivityService();
    final check = _connectivityService!.checkNow();
    final revision = _connectivityService!.revision;
    final status = await check;
    if (revision == _connectivityService!.revision) _applyConnectivity(status);
    return isOnline;
  }

  /// Test-only hook: lets widget tests simulate an offline/online transition
  /// without touching the real `connectivity_plus` platform channel.
  @visibleForTesting
  void debugSetOnlineForTests(bool online) {
    _applyConnectivity(online ? NetworkStatus.online : NetworkStatus.offline);
  }

  Future<void> _loadMapMarkerCacheFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_mapCacheKey);
      final updatedAtRaw = prefs.getString(_mapCacheUpdatedAtKey);
      if (raw == null || raw.isEmpty) return;
      if (_isUsingCachedCatalog) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      _cachedMapMarkers = decoded
          .map((e) => MapMarkerModel.fromCachedJson(e as Map<String, dynamic>))
          .toList();
      _mapCacheUpdatedAt =
          updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null;
      notifyListeners();
    } catch (e) {
      debugPrint('_loadMapMarkerCacheFromDisk failed: $e');
    }
  }

  Future<void> restorePublicCatalogFromDisk() async {
    final snapshot = await _publicCatalogCache.load();
    if (snapshot == null || _lastLoadedPublicStreamers != null) return;
    _streamers = List.of(snapshot.streamers);
    _academicCategories = List.of(snapshot.categories);
    _isUsingCachedCatalog = true;
    _publicCatalogUpdatedAt = snapshot.updatedAt;
    _cachedMapMarkers = snapshot.streamers
        .where((s) =>
            (s.latitude != 0 || s.longitude != 0) &&
            s.isVerified &&
            !s.isTemporarilyHiddenFromMap)
        .map((s) => MapMarkerModel.fromCachedJson(
            MapMarkerModel.fromStreamer(s).toJson()))
        .toList();
    _mapCacheUpdatedAt = snapshot.updatedAt;
    notifyListeners();
  }

  Future<void> _persistPublicCatalogIfReady() async {
    final streamers = _lastLoadedPublicStreamers;
    if (streamers == null || !_publicCategoriesLoaded) return;
    final now = DateTime.now();
    try {
      await _publicCatalogCache.save(streamers, _academicCategories,
          updatedAt: now);
      _publicCatalogUpdatedAt = now;
    } catch (e) {
      debugPrint('_persistPublicCatalogIfReady failed: $e');
    }
  }

  /// Persists the current streamer catalog's map-relevant fields as the
  /// offline fallback snapshot. Called after every successful backend
  /// refresh (loadVerifiedStreamersFromBackend) -- a successful refresh is
  /// itself proof the device was online a moment ago, so this is the natural
  /// "last known good" point to snapshot, without coupling it to the
  /// separate connectivity-monitoring subscription.
  String? _lastMapMarkerJson;

  Future<void> _persistMapMarkerCache() async {
    try {
      final markers = _streamers
          .where((s) =>
              (s.latitude != 0 || s.longitude != 0) &&
              s.isVerified &&
              !s.isTemporarilyHiddenFromMap)
          .map(MapMarkerModel.fromStreamer)
          .toList();
      final now = DateTime.now();
      // Skip the disk write and the marker re-instantiation when nothing
      // changed since the last snapshot (audit CA-01); refresh the stored
      // timestamp at most every five minutes.
      final encoded = jsonEncode(markers.map((m) => m.toJson()).toList());
      final lastWrite = _mapCacheUpdatedAt;
      if (encoded == _lastMapMarkerJson &&
          lastWrite != null &&
          now.difference(lastWrite) < PublicCatalogCache.refreshInterval) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mapCacheKey, encoded);
      _lastMapMarkerJson = encoded;
      await prefs.setString(_mapCacheUpdatedAtKey, now.toIso8601String());
      _cachedMapMarkers = markers
          .map((m) => MapMarkerModel.fromCachedJson(m.toJson()))
          .toList();
      _mapCacheUpdatedAt = now;
    } catch (e) {
      debugPrint('_persistMapMarkerCache failed: $e');
    }
  }

  /// Stops the polling loop (called when all broadcasts end).
  void _stopLiveViewerPolling() {
    _liveViewerTimer?.cancel();
    _liveViewerTimer = null;
    _studioPollStreamerId = null;
  }

  // Platform viewer presence per stream id (P3 / 05 D-08). Absent means
  // "unknown", which the UI renders as "—" -- never as 0.
  final Map<String, int> _platformViewerCounts = {};
  DateTime? _lastViewerCountFetch;
  static const Duration _viewerCountPollInterval = Duration(seconds: 30);

  /// Live viewers counted by this platform for [streamId], or null when it is
  /// not known. This is presence on our own streams; it is never YouTube's
  /// concurrent-viewer figure, which belongs to the broadcaster studio and is
  /// labelled there as YouTube's.
  int? platformViewerCount(String streamId) =>
      streamId.isEmpty ? null : _platformViewerCounts[streamId];

  /// Refreshes counts for the streams currently on screen. Throttled to one
  /// round trip per 30 s however many cards ask.
  Future<void> refreshViewerCountsFor(List<String> streamIds) async {
    final ids = streamIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;
    final now = DateTime.now();
    if (_lastViewerCountFetch != null &&
        now.difference(_lastViewerCountFetch!) < _viewerCountPollInterval) {
      return;
    }
    _lastViewerCountFetch = now;
    _adminDbService ??= await AdminDatabaseService.create();
    final counts = await _adminDbService!.fetchViewerCounts(ids);
    if (counts.isEmpty) return;
    _platformViewerCounts.addAll(counts);
    notifyListeners();
  }

  /// Fetches YouTube's own concurrent-viewer figure for live streams. It is
  /// kept apart from platform presence (P3): it counts people watching on
  /// YouTube, which is a different audience from the one in this app, and is
  /// only shown in the broadcaster studio, labelled as YouTube's.
  Future<void> _pollLiveViewers() async {
    final liveStreamers = _streamers
        .where((s) =>
            s.streamerId == _studioPollStreamerId &&
            s.isCurrentlyLive &&
            s.youtubeVideoId.isNotEmpty)
        .toList();

    if (liveStreamers.isEmpty) return;

    bool changed = false;
    for (final streamer in liveStreamers) {
      final count = await _youTubeService.fetchLiveConcurrentViewers(
        streamer.youtubeVideoId,
      );
      if (count != null &&
          count != _youTubeConcurrentByStreamer[streamer.streamerId]) {
        _youTubeConcurrentByStreamer[streamer.streamerId] = count;
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  /// YouTube's concurrent-viewer count for a streamer's live broadcast, or
  /// null when unknown. Studio-only and always labelled as YouTube's.
  int? youTubeConcurrentViewers(String streamerId) =>
      _youTubeConcurrentByStreamer[streamerId];

  final Map<String, int> _youTubeConcurrentByStreamer = {};

  @override
  void dispose() {
    _disposed = true;
    _catalogEpoch++;
    _categoryRequestGeneration++;
    _connectivityGeneration++;
    _deviceGeneration++;
    _deviceHeartbeatTimer?.cancel();
    _deviceSubscription?.cancel();
    _banPollTimer?.cancel();
    _currentDeviceSession = null;
    _stopLiveViewerPolling();
    _authStateSub?.cancel();
    _unsubscribeFromUserStatusChanges();
    _unsubscribeFromPublicStreamerChanges();
    _unsubscribeFromAcademicCategoryChanges();
    _unsubscribeFromChatReportChanges();
    _connectivitySub?.cancel();
    _connectivityService?.dispose();
    _realtimeRefreshTimer?.cancel();
    _reminderPush.dispose();
    super.dispose();
  }

  // Admin & Governance Getters
  bool get isAdminUser => _isLoggedInStreamer && _isAdminFromRoles;
  bool get isMasterAdmin => _isLoggedInStreamer && _isMasterAdminFromRoles;
  List<String> get permittedAdminOrgIds =>
      _isLoggedInStreamer ? List.unmodifiable({
        ..._permittedAdminOrgIds,
        ..._orgMemberships.where((m) => m.active && m.role != OrgRole.broadcaster)
            .map((m) => m.organizationId),
      }) : const [];
  bool get isPermittedAdmin => permittedAdminOrgIds.isNotEmpty;

  List<BroadcasterApplicationModel> get applications =>
      List.unmodifiable(_applications);
  List<Map<String, dynamic>> get applicationReviewEvents =>
      List.unmodifiable(_applicationReviewEvents);
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
  String? get currentUserId => _authService.currentSession?.user.id ?? _debugUserId;
  // Only debugSetSignedInForTests sets this; a real session always wins.
  String? _debugUserId;
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
  String get phoneBroadcastRtmpUrl => _phoneBroadcastRtmpUrl;
  String get phoneBroadcastStreamKey => _phoneBroadcastStreamKey;
  String get phoneBroadcastFullUrl => _phoneBroadcastStreamKey.isEmpty
      ? _phoneBroadcastRtmpUrl
      : '$_phoneBroadcastRtmpUrl/$_phoneBroadcastStreamKey';
  int get streamReloadCount => _streamReloadCount;
  String get selectedStreamingQuality => _selectedStreamingQuality;

  // Mini Player Getters
  bool get isMiniPlayerActive => _isMiniPlayerActive;
  bool get isMiniPlayerPlaying => _isMiniPlayerPlaying;
  String get miniPlayerVideoId => _miniPlayerVideoId;
  String get miniPlayerTitle => _miniPlayerTitle;
  String get miniPlayerStreamerName => _miniPlayerStreamerName;
  String? get miniPlayerStreamId => _miniPlayerStreamId;
  bool get isMiniPlayerAudioOnly => _isMiniPlayerAudioOnly;

  // Streamer Custom Broadcast Studio Getters
  String get customYouTubeLiveUrl => _customYouTubeLiveUrl;
  String get customYouTubeVideoId => _customYouTubeVideoId;
  String get customLiveTitle => _customLiveTitle;
  String get customLiveCategory => _customLiveCategory;
  String get customLiveVenue => _customLiveVenue;
  String get customSlidesUrl => _customSlidesUrl;
  String get customLiveDescription => _customLiveDescription;
  String? get customAudioOnlyPosterPath => _customAudioOnlyPosterPath;
  BroadcastType get customBroadcastType => _customBroadcastType;
  bool get isBroadcastingLive => _isBroadcastingLive;
  String? get selectedBroadcastOrgId => _selectedBroadcastOrgId;
  String? get selectedVenueBranchId => _selectedVenueBranchId;
  List<String> get selectedCoSpeakerIds =>
      List.unmodifiable(_selectedCoSpeakerIds);

  void setSelectedBroadcastOrgId(String? orgId) {
    if (_publishingSession?.frozen == true) return;
    if (orgId != null && !_orgMemberships.any((m)=>m.organizationId==orgId && m.active)) return;
    _selectedBroadcastOrgId = orgId;
    _selectedVenueBranchId = null;
    _selectedCoSpeakerIds = [];
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
    // Push delivery is decided on the server; mirror the switches it uses.
    if (currentUserId != null) {
      unawaited(_organizationBroadcastService.savePushPreferences(
        live: preferences.liveVideoEnabled || preferences.liveAudioEnabled,
        organization: preferences.orgInvitesEnabled,
      ).catchError((Object e) => debugPrint('Push preference sync failed: $e')));
    }
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
    if (id.startsWith('org:')) _markOrgEventReadQuietly([id.substring(4)]);
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
    if (_orgEvents.any((e) => !e.read)) _markOrgEventReadQuietly(null);
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
        accentColor: item.isLiveAlert ? AppTheme.danger : AppTheme.primary,
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

  /// No channel is undeletable any more. This used to name the five sample
  /// broadcasters that shipped inside lib/ so an admin could not remove them;
  /// the samples are gone (P2), and a real channel's deletion is authorized by
  /// RLS on the backend, not by an id list in the client.
  bool isProtectedStreamer(String streamerId) => false;

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

  /// Admin: withdraw a channel's broadcaster approval (P6-R09). The server
  /// action is authorized, atomic and audited; local state changes only
  /// after it succeeds. This is not account deletion (User Directory).
  Future<bool> revokeBroadcasterApproval(String streamerId,
      {required String reason}) async {
    final isOrganization = getStreamerById(streamerId)?.isOrganization ?? false;
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      await _adminDbService!.revokeBroadcasterApproval(
          streamerId: streamerId,
          isOrganization: isOrganization,
          reason: reason);
    } catch (e) {
      debugPrint('revokeBroadcasterApproval failed: $e');
      return false;
    }
    if (!isOrganization) {
      _streamers.removeWhere((s) =>
          s.streamerId == streamerId || s.streamerId == 'streamer_$streamerId');
    }

    final currentUserId = _authService.currentSession?.user.id;
    if (currentUserId != null &&
        (streamerId == currentUserId ||
            streamerId == 'streamer_$currentUserId')) {
      await refreshMyApplicationAndStreamerStatus();
    }

    await loadVerifiedStreamersFromBackend();
    if (_isAdminFromRoles) {
      await refreshAdminData();
    }
    notifyListeners();
    return true;
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

  /// Recordings this streamer actually has. An empty list means "nothing
  /// recorded yet"and the UI shows an empty state -- it used to fall back to
  /// a compiled-in sample archive (P2 truthful data).
  List<VodModel> getVodsForStreamer(String streamerId) =>
      _streamerVods[streamerId] ?? const [];

  List<PlaylistModel> getPlaylistsForStreamer(String streamerId) =>
      _streamerPlaylists[streamerId] ?? const [];

  Future<void> loadYouTubeChannelData({
    required String streamerId,
    required String handle,
  }) async {
    _streamerVods.remove(streamerId);
    _streamerPlaylists.remove(streamerId);
    _syncedYouTubeStreamers.remove(streamerId);
    if (handle.trim().isEmpty) {
      notifyListeners();
      return;
    }
    try {
      final details = await _youTubeService.fetchChannelDetails(handle);
      final channelId = details['channelId'];
      if (channelId == null || channelId.isEmpty) {
        notifyListeners();
        return;
      }
      final vods = await _youTubeService.fetchChannelVideos(
          streamerId: streamerId, handle: handle);
      final playlists = await _youTubeService.fetchChannelPlaylists(
          streamerId: streamerId, channelId: channelId);
      // A response for an old handle must never overwrite a newly linked one.
      if (getStreamerById(streamerId)?.youtubeHandle != handle) return;
      _streamerVods[streamerId] = vods;
      _streamerPlaylists[streamerId] = playlists;
      _syncedYouTubeStreamers.add(streamerId);
      notifyListeners();
    } catch (_) {
      notifyListeners();
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
      avatarUrl: avatarUrl ?? 'assets/images/avatars/neutral_1.png',
    );

    await recordGuestSession();
    notifyListeners();
  }

  /// Updates a viewer's own display name/avatar -- distinct from
  /// submitBroadcasterApplication, which is the broadcaster onboarding
  /// flow. Settings' "Edit Profile"action must route here for non-verified
  /// viewers rather than opening BroadcasterApplicationSheet (issue_log.md:
  /// "clicking 'Edit account Profile'as a non verified streamer should not
  /// be an option, as it opened the streamer onboarding").
  Future<void> updateViewerProfile({
    String? nameEn,
    String? nameAr,
    String? avatarUrl,
    String? bannerUrl,
  }) async {
    _userProfile = _userProfile.copyWith(
      nameEn: nameEn,
      nameAr: nameAr,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
    );
    if (_isGuestViewer) {
      if (nameEn != null) _guestViewerName = nameEn;
      if (avatarUrl != null) _guestViewerAvatar = avatarUrl;
    }
    notifyListeners();

    final userId = _authService.currentSession?.user.id;
    if (userId == null) return;
    try {
      final updates = <String, dynamic>{};
      if (nameEn != null) updates['display_name_en'] = nameEn;
      if (nameAr != null) updates['display_name_ar'] = nameAr;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bannerUrl != null) updates['banner_url'] = bannerUrl;
      if (updates.isEmpty) return;
      await Supabase.instance.client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
    } catch (e) {
      debugPrint('updateViewerProfile failed: $e');
    }
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
  Future<void> loginWithGoogle() async {
    await _markOAuthAttempt(true);
    try {
      await _authService.signInWithGoogle();
    } catch (_) {
      await _markOAuthAttempt(false);
      rethrow;
    }
  }

  String? _pendingOrganizationInvitation;
  String? get pendingOrganizationInvitation => _pendingOrganizationInvitation;
  Future<void> rememberOrganizationInvitation(String? destination) async {
    if (destination != null && !destination.startsWith('/org-invite/')) {
      throw ArgumentError('Invalid invitation destination');
    }
    final prefs = await SharedPreferences.getInstance();
    if (destination == null) { await prefs.remove('pending_org_invitation'); }
    else { await prefs.setString('pending_org_invitation', destination); }
    _pendingOrganizationInvitation = destination;
    notifyListeners();
  }

  /// Uploads binary media (avatar/banner) to Supabase Storage 'streamer-assets'bucket
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

  Future<void> validateChannelConfiguration(String url, String handle) async {
    final error = YouTubeChannelReference.pairError(url, handle);
    if (error != null) throw FormatException(error);
    final a = YouTubeChannelReference.parse(url, requireUrl: true)!;
    final b = YouTubeChannelReference.parse(handle)!;
    if (a.sameAs(b)) return;
    final ids = await Future.wait(
        [_resolveChannelId(a.stored), _resolveChannelId(b.stored)]);
    if (ids.any((id) => id == null)) {
      throw const FormatException('live.channel_lookup_required');
    }
    if (ids[0] != ids[1]) throw const FormatException('live.channel_mismatch');
  }

  Future<bool> saveBroadcasterProfile(
      BroadcasterApplicationModel application) async {
    if (!isApprovedStreamer || _myApplication == null) {
      throw StateError('Approved profile required');
    }
    if ((application.latitude != _myApplication!.latitude ||
            application.longitude != _myApplication!.longitude ||
            application.cityId != _myApplication!.cityId ||
            application.venueNameEn != _myApplication!.venueNameEn ||
            application.venueNameAr != _myApplication!.venueNameAr) &&
        !isInTricityMapDomain(application.latitude, application.longitude)) {
      throw const FormatException('map.location_outside_supported');
    }
    // Unchanged legacy channel values must not force a new lookup or review.
    if (application.youtubeChannelUrl.trim() !=
            _myApplication!.youtubeChannelUrl.trim() ||
        application.youtubeHandle.trim() !=
            _myApplication!.youtubeHandle.trim()) {
      await validateChannelConfiguration(
          application.youtubeChannelUrl, application.youtubeHandle);
    }
    _adminDbService ??= await AdminDatabaseService.create();
    final generation = _authGeneration;
    final saved = await _adminDbService!.saveBroadcasterProfile(application);
    if (_authGeneration != generation) {
      throw StateError('Account changed during save');
    }
    _myApplication = saved;
    await refreshMyApplicationAndStreamerStatus();
    await loadVerifiedStreamersFromBackend();
    notifyListeners();
    return saved.isPending;
  }

  /// Submits a multi-step Broadcaster / Organization verification application
  Future<void> submitBroadcasterApplication(
      BroadcasterApplicationModel application) async {
    if (!isInTricityMapDomain(application.latitude, application.longitude)) {
      throw const FormatException('map.location_outside_supported');
    }
    if (!application.organizationOnly) {
      await validateChannelConfiguration(application.youtubeChannelUrl, application.youtubeHandle);
      final channel = YouTubeChannelReference.parse(application.youtubeChannelUrl, requireUrl: true)!;
      application = application.copyWith(youtubeChannelUrl: channel.url, youtubeHandle: channel.stored);
    }
    _adminDbService ??= await AdminDatabaseService.create();
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
      orElse: () => throw StateError('Organization unavailable'),
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

    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.submitAffiliationRequest(req);
    _affiliationRequests = List.from(await _adminDbService!.loadAffiliationRequests());

    notifyListeners();
  }

  Future<void> acceptOrgAffiliationRequest(String requestId) =>
      _answerAffiliation(requestId, AffiliationStatus.accepted);

  Future<void> declineOrgAffiliationRequest(String requestId) =>
      _answerAffiliation(requestId, AffiliationStatus.declined);

  Future<void> _answerAffiliation(String id, AffiliationStatus status) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.updateAffiliationRequestStatus(id, status);
    _affiliationRequests = List.from(await _adminDbService!.loadAffiliationRequests());
    await refreshOrgMemberships();
    notifyListeners();
  }

  /// Adds a speaker to an Organization's roster
  Future<void> orgAddSpeaker(String orgId, OrgSpeakerModel speaker) async {
    await _writeThroughOrgSpeaker(orgId, speaker);
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
    await _writeThroughDeleteOrgSpeaker(orgId, speakerId);
    _streamers = _streamers.map((s) {
      if (s.streamerId == orgId) {
        final existing = List<OrgSpeakerModel>.from(s.affiliatedSpeakers)
          ..removeWhere((spk) => spk.speakerId == speakerId);
        return s.copyWith(affiliatedSpeakers: existing);
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
        descriptionEn: 'Removed speaker $speakerId from organization roster.',
        descriptionAr: 'تم حذف المدرب $speakerId من قائمة المدربين.',
        metadata: {'speaker_id': speakerId},
      ),
    );

    notifyListeners();
  }

  Future<void> orgUpdateSpeakerPermissions(String orgId, String speakerId,
      OrgBroadcasterPermissions permissions) =>
      updateSpeakerPermissions(orgId, speakerId, permissions);

  Future<void> logout() async {
    final device = _currentDeviceSession;
    // An explicit sign-out ends this install's viewer choice; the next
    // sign-in asks the server again.
    await _persistViewerChoice(false);
    if (device != null) {
      await _adminDbService?.upsertDeviceSession(
          userId: _authService.currentSession?.user.id ?? '',
          session: device.copyWith(isPrimaryBroadcaster: false));
    }
    try {
      await _reminderPush.signOut();
    } catch (e) {
      debugPrint('Reminder token invalidation failed: $e');
    }
    _clearAuthState();
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

  /// PDPL data-portability export (v0.9 Checkpoint 3 Phase 2) -- a basic
  /// export of the requesting user's own stored data: their profile,
  /// broadcaster/organization applications, and live chat messages they
  /// sent. profiles_select_own and broadcaster_applications_select_own
  /// (row_level_security.sql) scope the first two to the caller's own rows;
  /// chat_messages is filtered client-side by sender_id since its RLS is
  /// public-read (chat_messages_select_public). Each section fails
  /// independently so one failed query doesn't blank out the whole export.
  Future<Map<String, dynamic>> exportMyData() async {
    final userId = _authService.currentSession?.user.id;
    final result = <String, dynamic>{
      'exported_at': DateTime.now().toIso8601String(),
    };
    if (userId == null) {
      result['error'] = 'Not signed in.';
      return result;
    }

    final client = Supabase.instance.client;

    try {
      result['profile'] =
          await client.from('profiles').select().eq('id', userId).maybeSingle();
    } catch (e) {
      debugPrint('Data export: profile fetch failed: $e');
      result['profile'] = null;
    }

    try {
      result['broadcaster_applications'] = await client
          .from('broadcaster_applications')
          .select()
          .eq('applicant_profile_id', userId);
    } catch (e) {
      debugPrint('Data export: applications fetch failed: $e');
      result['broadcaster_applications'] = [];
    }

    try {
      result['chat_messages'] =
          await client.from('chat_messages').select().eq('sender_id', userId);
    } catch (e) {
      debugPrint('Data export: chat messages fetch failed: $e');
      result['chat_messages'] = [];
    }

    return result;
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
    // Turning broadcaster mode on is the explicit way back from a viewer
    // choice or a displacement: ask the server again. Another active primary
    // is reported as a conflict, never taken over silently.
    if (isStreamer &&
        (_viewerDeviceChoice ||
            _currentDeviceSession?.isPrimaryBroadcaster != true)) {
      _viewerDeviceChoice = false;
      if (_broadcastSessionError == 'broadcast_session_lost') {
        _broadcastSessionError = null;
      }
      unawaited(_persistViewerChoice(false));
      unawaited(initDeviceSession());
    }
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
    bool isAudioOnly = false,
  }) {
    _isMiniPlayerActive = true;
    _isMiniPlayerPlaying = true;
    _miniPlayerVideoId = videoId;
    _miniPlayerTitle = title;
    _miniPlayerStreamerName = streamerName;
    _miniPlayerStreamId = streamId;
    _isMiniPlayerAudioOnly = isAudioOnly;
    final source = streamId == null ? null : getStreamerById(streamId);
    _miniPlayerIsLive =
        source != null && source.isLiveForRoom && source.liveWatchId == videoId;
    notifyListeners();
  }

  bool _miniPlayerIsLive = false;
  int _miniPlayerEndedGeneration = 0;

  /// Bumped when the mini-player closed because its broadcast ended, so the
  /// app can say why it disappeared.
  int get miniPlayerEndedGeneration => _miniPlayerEndedGeneration;

  /// Alias kept for the Cluster 1 Task 6 call site naming; identical
  /// behaviour to [launchMiniPlayer].
  void openMiniPlayer({
    required String videoId,
    required String title,
    required String streamerName,
    String? streamId,
    bool isAudioOnly = false,
  }) =>
      launchMiniPlayer(
        videoId: videoId,
        title: title,
        streamerName: streamerName,
        streamId: streamId,
        isAudioOnly: isAudioOnly,
      );

  /// A mini-player opened from a live room belongs to that broadcast. Once a
  /// fresh catalog says it ended (or became a different broadcast), the card
  /// closes instead of advertising a live stream that is over.
  void _closeMiniPlayerIfBroadcastEnded() {
    final streamId = _miniPlayerStreamId;
    if (!_isMiniPlayerActive || !_miniPlayerIsLive || streamId == null) return;
    final s = getStreamerById(streamId);
    if (s == null || !s.isLiveForRoom || s.liveWatchId != _miniPlayerVideoId) {
      _isMiniPlayerActive = false;
      _miniPlayerEndedGeneration++;
    }
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
    final ownId = primaryOwnedStreamerId;
    _streamers = _streamers.map((s) {
      if (ownId != null && s.streamerId == ownId) {
        return s.copyWith(youtubeVideoId: _customYouTubeVideoId);
      }
      return s;
    }).toList();
    notifyListeners();
  }

  /// The YouTube handle of the channel this broadcast goes out on: the
  /// selected organization's, or the broadcaster's approved application's.
  /// Empty when the account has none on record.
  String get _approvedChannelHandle {
    if (!isApprovedStreamer) return '';
    if (_userProfile.youtubeChannelUrl.trim().isNotEmpty) {
      return _userProfile.youtubeChannelUrl.trim();
    }
    return _myApplication?.isApproved == true
        ? _myApplication!.youtubeHandle.trim()
        : '';
  }

  String get _broadcastChannelHandle {
    final orgId = _selectedBroadcastOrgId;
    if (orgId != null) {
      return getStreamerById(orgId)?.youtubeHandle.trim() ?? '';
    }
    return _approvedChannelHandle;
  }

  Future<String?> _resolveChannelId(String handle) async {
    if (handle.isEmpty) return null;
    // A channel URL (/channel/UC...) or a whole bare channel ID needs no
    // lookup. Anchored: a handle such as @UCLA_... is not a channel ID.
    final direct = RegExp(
            r'^(?:(?:https?://)?(?:www\.|m\.)?youtube\.com/)?(?:channel/)?(UC[A-Za-z0-9_-]{22})/?$')
        .firstMatch(handle.trim());
    if (direct != null) return direct.group(1);
    final details = await _youTubeService.fetchChannelDetails(handle);
    final id = details['channelId'];
    if (id == null || id.isEmpty) return null;
    return id;
  }

  /// Checks a watch link with YouTube's public Data API before the app lists
  /// it: that the video exists, is a live or scheduled broadcast (not a
  /// finished one or a regular upload) and, when the account's channel is on
  /// record, that it belongs to that channel. This is not channel
  /// authorization and cannot see the stream key or the encoder; it catches
  /// the wrong-link mistakes that put an unrelated video in front of viewers.
  Future<WatchLinkCheck> verifyWatchLink(String videoId) async {
    final status = await _youTubeService.fetchWatchStatus(videoId);
    switch (status.state) {
      case YouTubeWatchState.unavailable:
        return const WatchLinkCheck(WatchLinkVerdict.unverified);
      case YouTubeWatchState.notFound:
        return const WatchLinkCheck(WatchLinkVerdict.notFound);
      case YouTubeWatchState.ended:
        return const WatchLinkCheck(WatchLinkVerdict.ended);
      case YouTubeWatchState.notLive:
        return const WatchLinkCheck(WatchLinkVerdict.notLive);
      case YouTubeWatchState.live:
      case YouTubeWatchState.upcoming:
        final start = status.scheduledStart;
        if (status.state == YouTubeWatchState.upcoming &&
            start != null &&
            start.difference(DateTime.now()) > const Duration(hours: 1)) {
          return const WatchLinkCheck(WatchLinkVerdict.scheduledLater);
        }
        final onRecord = _broadcastChannelHandle;
        if (onRecord.isEmpty) {
          return const WatchLinkCheck(WatchLinkVerdict.live);
        }
        final app = _myApplication;
        if (app?.isApproved == true && app!.youtubeChannelUrl.isNotEmpty) {
          try {
            await validateChannelConfiguration(
                app.youtubeChannelUrl, app.youtubeHandle);
          } on FormatException catch (e) {
            return WatchLinkCheck(WatchLinkVerdict.unverified,
                channelConfigurationErrorKey: e.message);
          }
        }
        final expected = await _resolveChannelId(onRecord);
        if (expected != null &&
            status.channelId != null &&
            status.channelId != expected) {
          return const WatchLinkCheck(WatchLinkVerdict.wrongChannel);
        }
        return WatchLinkCheck(
          status.state == YouTubeWatchState.live
              ? WatchLinkVerdict.live
              : WatchLinkVerdict.upcoming,
          channelVerified: expected != null && status.channelId == expected,
          channelOnRecord: onRecord.isNotEmpty,
        );
    }
  }

  bool _isFindingMyLiveBroadcast = false;
  String? _findMyLiveBroadcastErrorKey;
  DateTime? _lastFindMyLiveBroadcastAt;

  /// One channel search costs 100 of the app key's shared daily quota; this
  /// keeps repeated taps from draining it for everyone.
  static const Duration findMyLiveBroadcastCooldown = Duration(seconds: 30);

  bool get isFindingMyLiveBroadcast => _isFindingMyLiveBroadcast;
  String? get findMyLiveBroadcastErrorKey => _findMyLiveBroadcastErrorKey;

  /// Looks up the live broadcast on THIS account's own channel (the approved
  /// application's or selected organization's YouTube handle) and fills in
  /// the watch link. It never marks anything live. It used to search one
  /// fixed channel for every account and mark the caller's card live with a
  /// made-up stream id. Costs one YouTube search (100 quota units).
  Future<bool> findMyLiveBroadcast() async {
    final last = _lastFindMyLiveBroadcastAt;
    if (last != null &&
        DateTime.now().difference(last) < findMyLiveBroadcastCooldown) {
      _findMyLiveBroadcastErrorKey = 'live_studio.find_live_wait';
      notifyListeners();
      return false;
    }
    _isFindingMyLiveBroadcast = true;
    _findMyLiveBroadcastErrorKey = null;
    notifyListeners();
    try {
      final handle = _broadcastChannelHandle;
      if (handle.isEmpty) {
        _findMyLiveBroadcastErrorKey = 'live_studio.find_live_no_channel';
        return false;
      }
      final channelId = await _resolveChannelId(handle);
      if (channelId == null) {
        _findMyLiveBroadcastErrorKey = 'live_studio.find_live_unavailable';
        return false;
      }
      _lastFindMyLiveBroadcastAt = DateTime.now();
      final String? videoId;
      try {
        videoId = await _youTubeService.fetchLiveVideoId(channelId);
      } on YouTubeLookupUnavailable {
        _findMyLiveBroadcastErrorKey = 'live_studio.find_live_unavailable';
        return false;
      }
      if (videoId == null) {
        _findMyLiveBroadcastErrorKey = 'live_studio.find_live_none';
        return false;
      }
      _customYouTubeVideoId = videoId;
      _customYouTubeLiveUrl = 'https://www.youtube.com/watch?v=$videoId';
      return true;
    } finally {
      _isFindingMyLiveBroadcast = false;
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

  /// Persists Title/Description/Category from the Broadcaster Studio bottom
  /// sheet (v0.9) -- deliberately separate from setCustomBroadcastDetails
  /// above, which also requires venue/slidesUrl the studio sheet doesn't
  /// collect.
  void setCustomBroadcastMeta({
    required String title,
    required String description,
    required String category,
  }) {
    _customLiveTitle = title;
    _customLiveDescription = description;
    _customLiveCategory = category;
    notifyListeners();
  }

  void setCustomAudioOnlyPosterPath(String? path) {
    _customAudioOnlyPosterPath = (path == null || path.isEmpty) ? null : path;
    notifyListeners();
  }

  void setBroadcastType(BroadcastType type) {
    _customBroadcastType = type;
    final ownId = primaryOwnedStreamerId;
    _streamers = _streamers.map((streamer) {
      if (ownId != null && streamer.streamerId == ownId) {
        return streamer.copyWith(
          broadcastType: streamer.isCurrentlyLive ? type : type,
        );
      }
      return streamer;
    }).toList();
    notifyListeners();
  }

  /// Account and device preconditions for starting a broadcast from the
  /// studio, as an i18n key, or null when the server may be asked. The
  /// server re-checks both in set_live_state; this only lets the studio
  /// explain a refusal before anything starts.
  String? get broadcastPreflightErrorKey {
    if (_authService.currentSession == null || !isApprovedStreamer) {
      return 'broadcast_approval_required';
    }
    if (_currentDeviceSession?.isPrimaryBroadcaster != true) {
      return 'broadcast_primary_required';
    }
    return null;
  }

  Future<bool> checkBroadcastPermission() async {
    final session=_publishingSession, destination=_publishingDestination;
    if (_currentDeviceSession?.isPrimaryBroadcaster!=true) {
      _broadcastSessionError='broadcast_primary_required';notifyListeners();return false;
    }
    if(session==null || destination==null || _broadcastSenderMode!='phone_direct') {
      _broadcastSessionError='organization_v1.assignment_required';notifyListeners();return false;
    }
    try {
      await prepareBroadcast(session.id,'phone_direct',destination);
      final uri=Uri.tryParse(phoneBroadcastFullUrl);
      return uri?.scheme=='rtmps' && RegExp(r'^(?:[a-z0-9-]+\.)*rtmps?\.youtube\.com$').hasMatch(uri?.host??'') && _phoneBroadcastStreamKey.isNotEmpty;
    } catch(error) {
      _broadcastSessionError=OrganizationBroadcastService.errorKey(error);notifyListeners();return false;
    }
  }

  Future<void> toggleBroadcasterGoLive([BuildContext? context]) =>
      setBroadcasterLive(!_isBroadcastingLive, context);

  Future<void> setBroadcasterLive(bool live, [BuildContext? context]) async {
    final generation=_deviceGeneration, authGeneration=_authGeneration;
    bool current()=>!_disposed && generation==_deviceGeneration && authGeneration==_authGeneration;
    while(_liveStateBusy) {
      await _liveStateCompletion?.future;
      if(!current()) return;
    }
    final device=_currentDeviceSession, session=_publishingSession;
    if(session==null || (live && device?.isPrimaryBroadcaster!=true)) {
      _broadcastSessionError=session==null?'organization_v1.assignment_required':'broadcast_primary_required';notifyListeners();return;
    }
    _liveStateBusy=true; _liveAssertionEpoch++;
    final completion=Completer<void>(); _liveStateCompletion=completion;
    _broadcastSessionError=null; notifyListeners();
    try {
      if(live) {
        final deadline=DateTime.now().add(const Duration(seconds:65));
        while(current() && DateTime.now().isBefore(deadline)) {
          try {
            await _organizationBroadcastService.control(session.id,device!.deviceId,_broadcastSenderMode,'start',destination:_publishingDestination);
          } on FunctionException catch(error) {
            if(!OrganizationBroadcastService.waitingForEncoder(error)) rethrow;
          }
          if(!current() || _currentDeviceSession?.isPrimaryBroadcaster!=true || _publishingSession?.id!=session.id) return;
          final observed=await loadBroadcastSession(session.id);
          if(!current()) return;
          if(observed==null || !['preparing','live'].contains(observed.state)) throw StateError('Session ended');
          _publishingSession=observed;
          if(observed.live) {
            _isBroadcastingLive=true; _liveWatchId=observed.watchId;
            _remoteBroadcastEndReason=null; break;
          }
          await Future<void>.delayed(const Duration(seconds:3));
        }
        if(!_isBroadcastingLive) throw StateError('Provider confirmation pending');
      } else {
        // Remove credentials immediately; retain the session until termination is confirmed.
        _phoneBroadcastStreamKey=''; _phoneBroadcastRtmpUrl='';
        await _organizationBroadcastService.control(session.id,device?.deviceId??'management',
          session.senderMode=='phone_direct'?'phone_direct':'obs_laptop','end');
        if(!current()) return;
        final observed=await loadBroadcastSession(session.id);
        if(!current()) return;
        if(observed==null || observed.active) throw StateError('Termination pending');
        _isBroadcastingLive=false; _clearPublishingState();
      }
      await loadVerifiedStreamersFromBackend();
    } catch (error) {
      if(!current()) return;
      final observed=await loadBroadcastSession(session.id).catchError((_)=>null);
      if(!current()) return;
      if(observed!=null) {
        _publishingSession=observed;
        _isBroadcastingLive=observed.live;
        if(!observed.active) _clearPublishingState();
      }
      _broadcastSessionError=observed?.terminationPending==true
        ?'organization_v1.termination_pending':OrganizationBroadcastService.errorKey(error);
    } finally {
      completion.complete();
      if(identical(_liveStateCompletion,completion)) {
        _liveStateBusy=false; _liveStateCompletion=null; _liveAssertionEpoch++;
      }
      if(!_disposed) notifyListeners();
    }
  }

  /// Returns the 11-character YouTube id in [url], or an empty string when
  /// there is none. It used to fall back to a hardcoded video id, so a typo in
  /// the studio silently pointed the broadcast at someone else's video.
  static String extractYouTubeId(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';

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
    return trimmed.length == 11 ? trimmed : '';
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

  /// Seats left at the venue. 0 while no venue capacity is known -- the UI
  /// that would show it is hidden behind kVenueRsvpEnabled.
  int getAvailableSeats(String lectureId) =>
      _venueAvailableSeats[lectureId] ?? 0;

  void toggleInPersonAttendance(String lectureId) {
    final current = _inPersonRsvpMap[lectureId] ?? false;
    _inPersonRsvpMap[lectureId] = !current;
    final seats = _venueAvailableSeats[lectureId] ?? 0;
    if (!current) {
      _venueAvailableSeats[lectureId] = (seats - 1).clamp(0, 500);
    } else {
      _venueAvailableSeats[lectureId] = seats + 1;
    }
    notifyListeners();
  }

  bool isBookmarked(String id) =>
      _bookmarks.containsKey(BookmarkEntry.recordingKey(id));
  bool isUpcomingBookmarked(String id) =>
      _bookmarks.containsKey(BookmarkEntry.upcomingKey(id));
  bool isBookmarkPending(String id) =>
      _pendingBookmarks.contains(BookmarkEntry.recordingKey(id));
  bool get isLoadingBookmarks => _loadingBookmarks;
  bool get bookmarkLoadFailed => _bookmarkLoadFailed;
  List<BookmarkEntry> get bookmarks => List.unmodifiable(
      _bookmarks.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Future<void> toggleVodBookmark(VodModel vod) =>
      _toggleBookmark(BookmarkEntry.recording(vod));
  Future<void> toggleUpcomingBookmark(UpcomingSchedule schedule) =>
      _toggleBookmark(BookmarkEntry.upcoming(schedule));
  Future<void> removeSavedBookmark(BookmarkEntry entry) async {
    if (_bookmarks.containsKey(entry.id)) await _toggleBookmark(entry);
  }

  Future<void> _toggleBookmark(BookmarkEntry entry) async {
    if (_disposed || entry.id.isEmpty || _pendingBookmarks.contains(entry.id)) return;
    final generation = _authGeneration;
    final userId = _authService.currentSession?.user.id;
    final previous = _bookmarks[entry.id];
    _bookmarkRevision++;
    _pendingBookmarks.add(entry.id);
    if (previous == null) {
      _bookmarks[entry.id] = entry;
    } else {
      _bookmarks.remove(entry.id);
    }
    notifyListeners();
    bool current() => !_disposed && _authGeneration == generation &&
        _authService.currentSession?.user.id == userId;
    try {
      if (userId != null) {
        _adminDbService ??= await AdminDatabaseService.create();
        if (!current()) return;
        if (previous == null) {
          await _adminDbService!.addBookmark(entry);
        } else {
          await _adminDbService!.removeBookmark(entry.id);
        }
      }
    } catch (_) {
      if (current()) {
        if (previous == null) {
          _bookmarks.remove(entry.id);
        } else {
          _bookmarks[entry.id] = previous;
        }
        _bookmarkRevision++;
        rethrow;
      }
    } finally {
      if (current()) {
        _pendingBookmarks.remove(entry.id);
        notifyListeners();
      }
    }
  }

  /// Preserves saved content on errors and ignores a response superseded by
  /// a local save/removal, account switch, or disposal.
  Future<void> loadBookmarks() async {
    if (_disposed || _loadingBookmarks || _authService.currentSession == null) return;
    final generation = _authGeneration;
    final revision = _bookmarkRevision;
    final userId = _authService.currentSession?.user.id;
    _loadingBookmarks = true;
    _bookmarkLoadFailed = false;
    notifyListeners();
    bool current() => !_disposed && _authGeneration == generation &&
        _authService.currentSession?.user.id == userId;
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      if (!current()) return;
      final entries = await _adminDbService!.loadBookmarks();
      final resolved = {for (final entry in entries) entry.id: entry};
      final oldRecordings = entries.where((e) =>
          e.kind == BookmarkKind.recording && e.vod == null).toList();
      if (oldRecordings.isNotEmpty) {
        try {
          final videos = await _youTubeService.fetchSavedVideos(
              oldRecordings.map((e) => e.id).toList());
          for (final entry in oldRecordings) {
            final vod = videos[entry.id];
            if (vod != null) {
              resolved[entry.id] = entry.resolved(
                  vod: vod.copyWith(streamerId: entry.streamerId));
            }
          }
        } catch (_) { if (current()) _bookmarkLoadFailed = true; }
      }
      // Announcements are independent of live rooms. Refresh their public
      // facts so a removed/changed schedule never promises a stale start.
      for (final streamerId in entries.where((e) => e.kind == BookmarkKind.upcoming)
          .map((e) => e.streamerId).toSet()) {
        try {
          final schedules = await _upcomingService.load(streamerId);
          for (final entry in entries.where((e) =>
              e.kind == BookmarkKind.upcoming && e.streamerId == streamerId)) {
            final matches = schedules.where((s) =>
                BookmarkEntry.upcomingKey(s.id) == entry.id);
            resolved[entry.id] = entry.resolved(
                schedule: matches.firstOrNull, scheduleUnavailable: matches.isEmpty);
          }
        } catch (_) { if (current()) _bookmarkLoadFailed = true; }
      }
      if (current() && revision == _bookmarkRevision && _pendingBookmarks.isEmpty) {
        _bookmarks..clear()..addAll(resolved);
      }
    } catch (_) {
      if (current()) _bookmarkLoadFailed = true;
    } finally {
      if (current()) {
        _loadingBookmarks = false;
        notifyListeners();
      }
    }
  }

  /// Loads the signed-in account's follows and bookmarks. A guest keeps
  /// whatever it collected locally; signing out clears both (_clearAuthState).
  Future<void> loadViewerLibrary() async {
    final generation = _authGeneration;
    final userId = _authService.currentSession?.user.id;
    if (userId == null) return;
    _adminDbService ??= await AdminDatabaseService.create();
    final follows = await _adminDbService!.loadFollowedTargetIds();
    if (_authGeneration != generation) return;
    _followedStreamerIds
      ..clear()
      ..addAll(follows);
    notifyListeners();
    await loadBookmarks();
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

      // Private stream filtering (issue_log.md QF-12): if streamer's active broadcast is private,
      // it is visible to the broadcaster, whitelisted handles, or admitted attendees.
      if (s.isCurrentlyLive &&
          currentUserStreamerId != null &&
          s.streamerId == currentUserStreamerId &&
          _streamVisibility == StreamVisibility.private) {
        final currentHandle = currentUserHandle;
        final isBroadcaster = isOwnStreamerProfile(s.streamerId);
        final isWhitelisted = _streamWhitelistHandles.contains(currentHandle) ||
            _streamWhitelistHandles.contains('@$currentHandle');
        final isAdmitted = _admittedAttendees.any((a) =>
            a.displayName.toLowerCase() == currentHandle.toLowerCase() ||
            a.displayName.toLowerCase() == '@${currentHandle.toLowerCase()}' ||
            a.id == currentHandle);
        if (!isBroadcaster && !isWhitelisted && !isAdmitted) {
          return false;
        }
      }

      // Cluster 4 Task 18: a temporarily-hidden streamer never appears in
      // this filtered list (Discovery feed or Spatial Map), regardless of
      // category/tag/search match -- their profile stays reachable by
      // direct link (BroadcasterProfileScreen doesn't read this getter).
      return matchesCategory &&
          matchesTag &&
          matchesSearch &&
          !s.isTemporarilyHiddenFromMap;
    }).toList();
  }

  bool isFollowing(String streamerId) =>
      _followedStreamerIds.contains(streamerId);

  /// Persisted per account for signed-in viewers, local-only for guests
  /// (05 D-07). Optimistic locally, then written through.
  Future<void> toggleFollow(String streamerId) async {
    if (streamerId.isEmpty) return;
    final wasFollowing = _followedStreamerIds.contains(streamerId);
    if (wasFollowing) {
      _followedStreamerIds.remove(streamerId);
    } else {
      _followedStreamerIds.add(streamerId);
    }
    notifyListeners();
    if (_authService.currentSession == null) return;
    _adminDbService ??= await AdminDatabaseService.create();
    if (wasFollowing) {
      await _adminDbService!.removeFollow(streamerId);
    } else {
      await _adminDbService!.addFollow(streamerId);
    }
  }

  bool hasReminder(String streamerId) =>
      _reminderStreamerIds.contains(streamerId);
  bool isReminderSet(String streamerId) =>
      _reminderStreamerIds.contains(streamerId);
  bool hasCardReminder(String scheduleId) =>
      _cardReminderIds.contains(scheduleId);
  int get reminderLeadMinutes => _reminderLeadMinutes;
  ReminderPushStatus get reminderPushStatus => _reminderPushStatus;

  void attachReminderPush({required Future<void> Function(String) onOpen,
      Future<void> Function(String route)? onOpenRoute}) {
    _reminderPush.attach(onMessage: (data) {
      if (data['type'] == 'org_event') {
        if (_isLoggedInStreamer && data['viewer_id'] == currentUserId) {
          unawaited(refreshOrganizationEvents().catchError(
              (Object e) => debugPrint('Organization event refresh failed: $e')));
        }
        return;
      }
      if (data['type'] != 'upcoming_reminder') return;
      if (!_isLoggedInStreamer || data['viewer_id'] != currentUserId) return;
      final streamerId = data['streamer_id']?.toString() ?? '';
      final scheduleId = data['schedule_id']?.toString() ?? '';
      if (!_uuidPattern.hasMatch(streamerId) ||
          !_uuidPattern.hasMatch(scheduleId)) {
        return;
      }
      addNotification(AppNotificationItem(
        id: 'upcoming:$scheduleId:${data['occurrence_at']}',
        streamerId: streamerId,
        titleEn: data['title_en']?.toString() ?? '',
        titleAr: data['title_ar']?.toString() ?? '',
        bodyEn: data['body_en']?.toString() ?? '',
        bodyAr: data['body_ar']?.toString() ?? '',
        timestamp: DateTime.now(),
      ));
    }, onOpen: (data) {
      if (data['type'] == 'org_event') {
        final route = organizationEventRoute(data);
        if (route != null && onOpenRoute != null) unawaited(onOpenRoute(route));
        return;
      }
      final id = data['streamer_id']?.toString() ?? '';
      if (_uuidPattern.hasMatch(id)) unawaited(onOpen(id));
    });
  }

  /// The in-app route for an organization push, from validated identifiers
  /// only; the push body itself is never used as a navigation target.
  static String? organizationEventRoute(Map<String, dynamic> data) {
    String? id(String key) {
      final value = data[key]?.toString() ?? '';
      return _uuidPattern.hasMatch(value) ? value : null;
    }
    final kind = data['kind']?.toString() ?? '';
    final eventId = id('event_id');
    if (eventId == null || !OrgEvent.kinds.contains(kind)) return null;
    return OrgEvent(id: eventId, kind: kind, createdAt: DateTime.now(),
        organizationId: id('organization_id'), sessionId: id('session_id'),
        invitationId: id('invitation_id')).route;
  }

  Future<void> syncReminderPush(
      {required bool requestPermission, required String language}) async {
    if (currentUserId == null) return;
    final generation = _authGeneration;
    try {
      final status = await _reminderPush.sync(
          requestPermission: requestPermission, language: language);
      if (generation != _authGeneration) return;
      _reminderPushStatus = status;
    } catch (e) {
      if (generation != _authGeneration) return;
      debugPrint('Reminder push sync failed: $e');
      _reminderPushStatus = ReminderPushStatus.unavailable;
    }
    notifyListeners();
  }

  List<UpcomingSchedule>? upcomingSchedulesFor(String streamerId) =>
      _upcomingByStreamer[streamerId];
  String? upcomingScheduleErrorFor(String streamerId) =>
      _upcomingErrors[streamerId];
  bool isLoadingUpcomingFor(String streamerId) =>
      _loadingUpcoming.contains(streamerId);

  Future<void> loadUpcomingSchedules(String streamerId) async {
    if (_loadingUpcoming.contains(streamerId)) return;
    final generation = _authGeneration;
    _loadingUpcoming.add(streamerId);
    _upcomingErrors.remove(streamerId);
    notifyListeners();
    try {
      final rows = await _upcomingService.load(streamerId);
      if (generation == _authGeneration) _upcomingByStreamer[streamerId] = rows;
    } catch (e) {
      if (generation == _authGeneration) {
        _upcomingErrors[streamerId] = e.toString();
      }
    } finally {
      if (generation == _authGeneration) {
        _loadingUpcoming.remove(streamerId);
        notifyListeners();
      }
    }
  }

  Future<void> saveUpcomingSchedule(UpcomingSchedule schedule) async {
    if (!isApprovedStreamer || !isOwnStreamerProfile(schedule.streamerId)) {
      throw StateError('Approved channel owner required');
    }
    final generation = _authGeneration;
    await _upcomingService.save(schedule);
    if (generation != _authGeneration) return;
    await loadUpcomingSchedules(schedule.streamerId);
  }

  Future<void> deleteUpcomingSchedule(UpcomingSchedule schedule) async {
    if (!isApprovedStreamer || !isOwnStreamerProfile(schedule.streamerId)) {
      throw StateError('Approved channel owner required');
    }
    final generation = _authGeneration;
    await _upcomingService.delete(schedule.id);
    if (generation != _authGeneration) return;
    _cardReminderIds.remove(schedule.id);
    await loadUpcomingSchedules(schedule.streamerId);
  }

  Future<void> refreshScheduleReminders() async {
    final generation = _authGeneration;
    final state = await _upcomingService.loadReminders();
    if (generation != _authGeneration) return;
    _reminderStreamerIds
      ..clear()
      ..addAll(state.channels);
    _cardReminderIds
      ..clear()
      ..addAll(state.cards);
    _reminderLeadMinutes = state.leadMinutes;
    notifyListeners();
  }

  Future<void> toggleReminder(String streamerId,
      {String language = 'en'}) async {
    if (!isLoggedInStreamer) throw StateError('Sign in to set reminders');
    final generation = _authGeneration;
    final enabled = !_reminderStreamerIds.contains(streamerId);
    await _upcomingService.setChannelReminder(streamerId, enabled);
    if (generation != _authGeneration) return;
    if (enabled) {
      _reminderStreamerIds.add(streamerId);
    } else {
      _reminderStreamerIds.remove(streamerId);
    }
    notifyListeners();
    if (enabled) {
      await syncReminderPush(requestPermission: true, language: language);
    }
  }

  Future<void> toggleCardReminder(String scheduleId,
      {String language = 'en'}) async {
    if (!isLoggedInStreamer) throw StateError('Sign in to set reminders');
    final generation = _authGeneration;
    final enabled = !_cardReminderIds.contains(scheduleId);
    await _upcomingService.setCardReminder(scheduleId, enabled);
    if (generation != _authGeneration) return;
    if (enabled) {
      _cardReminderIds.add(scheduleId);
    } else {
      _cardReminderIds.remove(scheduleId);
    }
    notifyListeners();
    if (enabled) {
      await syncReminderPush(requestPermission: true, language: language);
    }
  }

  Future<void> setReminderLeadMinutes(int minutes) async {
    final generation = _authGeneration;
    await _upcomingService.setLeadMinutes(minutes);
    if (generation != _authGeneration) return;
    _reminderLeadMinutes = minutes;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetUpcomingSchedules(
      String streamerId, List<UpcomingSchedule> rows) {
    _upcomingByStreamer[streamerId] = rows;
    _upcomingErrors.remove(streamerId);
    notifyListeners();
  }

  @visibleForTesting
  void debugSetChannelReminderForTests(String streamerId) {
    _reminderStreamerIds.add(streamerId);
    notifyListeners();
  }

  StreamerModel? get activeStreamer {
    try {
      return _streamers.firstWhere((s) => s.isCurrentlyLive);
    } catch (_) {
      return _streamers.isNotEmpty ? _streamers.first : null;
    }
  }

  /// Resolves the logged-in broadcaster's actual streamer profile (prioritizing
  /// their own owned streamer ID / user profile over any sample stream).
  StreamerModel get currentBroadcasterStreamer {
    final currentId = currentUserId ?? _userProfile.id;
    final matched = _streamers.where((s) =>
        s.streamerId == currentId ||
        s.streamerId == 'streamer_$currentId' ||
        (primaryOwnedStreamerId != null &&
            s.streamerId == primaryOwnedStreamerId) ||
        s.streamerId == _userProfile.id);
    if (matched.isNotEmpty) return matched.first;

    return StreamerModel(
      streamerId: currentId,
      fullNameEn: _googleUserName ?? _userProfile.nameEn,
      fullNameAr: _googleUserName ?? _userProfile.nameAr,
      titleEn:
          _customLiveTitle.isNotEmpty ? _customLiveTitle : 'Live Broadcast',
      titleAr: _customLiveTitle.isNotEmpty ? _customLiveTitle : 'بث مباشر',
      organizationEn: _userProfile.nameEn,
      organizationAr: _userProfile.nameAr,
      avatarUrl: _googleUserAvatar ?? _userProfile.avatarUrl,
      bannerUrl: _userProfile.bannerUrl,
      bioEn: _userProfile.bioEn,
      bioAr: _userProfile.bioAr,
      // Synthesized for a broadcaster with no backend row yet: it must not
      // invent verification, a following, or a venue in a city the account
      // never named (P2 truthful data). Real values arrive with the profile.
      isVerified: false,
      followerCount: 0,
      categoryId:
          _currentCategoryFilter == 'all' ? 'cat_cs' : _currentCategoryFilter,
      cityEn: '',
      cityAr: '',
      venueNameEn: '',
      venueNameAr: '',
      latitude: 0,
      longitude: 0,
      isCurrentlyLive: _isBroadcastingLive,
      broadcastType:
          _isBroadcastingLive ? _customBroadcastType : BroadcastType.offline,
      activeViewerCount: _isBroadcastingLive ? 0 : 0,
    );
  }

  void activatePitchDirectorMode() {
    setPitchDirectorMode(true);
  }

  void togglePitchDirectorMode() {
    setPitchDirectorMode(!_isPitchDirectorModeEnabled);
  }

  void setPitchDirectorMode(bool enabled) {
    if (!kDebugMode) return;
    _isPitchDirectorModeEnabled = enabled;
    _isBroadcastingLive = enabled;
    final ownId = primaryOwnedStreamerId;
    _streamers = _streamers.map((s) {
      if (ownId != null && s.streamerId == ownId) {
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

  void setSelectedStreamingQuality(String quality) {
    _selectedStreamingQuality = quality;
    notifyListeners();
  }

  void setStreamingQuality(String quality) {
    _selectedStreamingQuality = quality;
    notifyListeners();
  }

  /// Debug-only tool (the admin "Testing tools"tab is gated by kDebugMode):
  /// pushes one notification through the real pipeline so its rendering can be
  /// checked. It announces the signed-in account's own channel -- it used to
  /// name a hardcoded developer identity (P1.6/P2).
  void triggerSimulatedNotification(BuildContext context) {
    if (!kDebugMode) return;
    final ownId = primaryOwnedStreamerId;
    if (ownId == null) return;
    final name = _googleUserName ?? _userProfile.nameEn;
    addEnhancedNotification(
      AppNotificationModel(
        id: 'notif_sim_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.streamerLiveVideo,
        streamerId: ownId,
        streamerName: name,
        titleEn: 'Live Broadcast Started',
        titleAr: 'بدأ البث المباشر الآن',
        bodyEn: '$name is live now: "$customLiveTitle" .. Join in!',
        bodyAr:
            '$name بدأ بثاً مباشراً الآن: «$customLiveTitle».. حيّاك شاركنا وتفاعل!',
        timestamp: DateTime.now(),
        streamId: _activeStreamIdForCurrentUser(),
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
      expectedStatus: app.status,
      reviewNotes: adminNotes,
      reviewedBy: _googleUserName ?? 'Administrator',
    );

    if (updated == null) return false;
    _applications = List.from(await _adminDbService!.loadApplications());
    await _refreshApplicationReviewEvents();

    if (updated.revisionOf != null) {
      // The database published the revision in the same review transaction.
      await loadVerifiedStreamersFromBackend();
      notifyListeners();
      return true;
    }

    final applicantProfileId =
        updated.applicantProfileId ?? app.applicantProfileId;
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
    final existingStreamer = _streamers
        .where((s) =>
            s.streamerId ==
            (realOrgId ?? applicantProfileId ?? 'streamer_${app.id}'))
        .firstOrNull;
    final applicationCity = app.city;
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
      cityEn: applicationCity?.nameEn ?? existingStreamer?.cityEn ?? '',
      cityAr: applicationCity?.nameAr ?? existingStreamer?.cityAr ?? '',
      venueNameEn: app.venueNameEn,
      venueNameAr: app.venueNameAr,
      // 0,0 is the application's "no pinned location"; keep it rather than
      // inventing a venue point. The map and directions treat it as absent.
      latitude: app.latitude,
      longitude: app.longitude,
      isCurrentlyLive: false,
      broadcastType: BroadcastType.offline,
      isOrganization: app.isOrganization,
      youtubeHandle: app.youtubeHandle,
      youtubeVideoId: existingStreamer?.youtubeVideoId ?? '',
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
        titleEn: 'Broadcaster Application Approved!',
        titleAr: 'أهلاً بك في نخبة المذيعين!',
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
    final reviewer = _googleUserName ?? 'Administrator';
    final updated = await _adminDbService!.updateApplicationStatus(
      applicationId,
      ApplicationStatus.rejected,
      expectedStatus: app.status,
      reviewNotes: reason,
      reviewedBy: reviewer,
    );

    if (updated != null) {
      _applications = List.from(await _adminDbService!.loadApplications());
      await _refreshApplicationReviewEvents();
      if (app.status == ApplicationStatus.approved) {
        await loadVerifiedStreamersFromBackend();
      }

      addEnhancedNotification(
        AppNotificationModel(
          id: 'notif_rejected_${applicationId}_${DateTime.now().millisecondsSinceEpoch}',
          type: NotificationType.streamerApplicationRejected,
          streamerId: applicationId,
          streamerName: app.applicantNameEn,
          titleEn: app.revisionOf == null
              ? 'Broadcaster Application Status Update'
              : 'Profile Edit Review',
          titleAr: app.revisionOf == null
              ? 'تحديث بخصوص طلب التوثيق الأكاديمي'
              : 'مراجعة تعديل الملف الشخصي',
          bodyEn: app.revisionOf == null
              ? 'Your broadcaster application was rejected: "$reason".'
              : 'Your proposed profile edit was rejected: "$reason". Your approved profile remains active.',
          bodyAr: app.revisionOf == null
              ? 'تم رفض طلب التوثيق: «$reason».'
              : 'تم رفض تعديل ملفك الشخصي المقترح: «$reason». يبقى ملفك المعتمد نشطاً.',
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
      await _refreshApplicationReviewEvents();
      notifyListeners();
    }
    return success;
  }

  Future<void> reverseApprovedApplication(String eventId, String reason) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.reverseApprovedApplication(eventId, reason);
    _applications = List.from(await _adminDbService!.loadApplications());
    await _refreshApplicationReviewEvents();
    await loadVerifiedStreamersFromBackend();
    notifyListeners();
  }

  Future<bool> approveRejectedApplication(String applicationId,
      {String? adminNotes}) async {
    _adminDbService ??= await AdminDatabaseService.create();
    final restored =
        await _adminDbService!.restoreApplicationToQueue(applicationId);
    _applications = [
      ..._applications.where((a) => a.id != applicationId),
      restored,
    ];
    return approveBroadcasterApplication(applicationId, adminNotes: adminNotes);
  }

  Future<void> _refreshApplicationReviewEvents() async {
    try {
      _applicationReviewEvents =
          List.from(await _adminDbService!.loadApplicationReviewEvents());
    } catch (e) {
      debugPrint('Application review history unavailable: $e');
    }
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
      // fresh session would otherwise hit "Organization not found"for
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
      cityEn:
          BroadcasterApplicationModel.cityNames[row['city_id']]?.nameEn ?? '',
      cityAr:
          BroadcasterApplicationModel.cityNames[row['city_id']]?.nameAr ?? '',
      venueNameEn: row['venue_name_en'] as String? ?? '',
      venueNameAr: row['venue_name_ar'] as String? ?? '',
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0,
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

  /// Looks up a profile by exact email, for the "grant a role"search field.
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
    _subscribeToChatReportChanges();
  }

  RealtimeChannel? _chatReportsChannel;

  /// P6.3: a viewer reporting a message has to reach an open moderation queue
  /// without the admin reloading the tab. chat_reports is on the realtime
  /// publication since 20260921130000, and its SELECT policy is admin-tier
  /// only, so a non-admin subscriber receives nothing even though every client
  /// could technically open this channel -- Realtime applies RLS per
  /// subscriber. That is the enforcement; this is only delivery.
  void _subscribeToChatReportChanges() {
    _unsubscribeFromChatReportChanges();
    try {
      if (!Supabase.instance.isInitialized) return;
      _chatReportsChannel = Supabase.instance.client
          .channel('chat_reports_queue')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_reports',
            callback: (payload) {
              debugPrint('Realtime: chat_reports changed');
              _refreshChatReports();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime chat_reports subscription failed: $e');
    }
  }

  void _unsubscribeFromChatReportChanges() {
    if (_chatReportsChannel != null) {
      try {
        if (Supabase.instance.isInitialized) {
          Supabase.instance.client.removeChannel(_chatReportsChannel!);
        }
      } catch (_) {}
      _chatReportsChannel = null;
    }
  }

  Future<void> refreshChatReports() async {
    await ensureChatReportsLoaded();
    await _refreshChatReports();
  }

  Future<void> _refreshChatReports() async {
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      _chatReports = await _adminDbService!.loadChatReports();
      notifyListeners();
    } catch (e) {
      // A realtime-triggered refresh must never surface as an unhandled error
      // in a channel callback; the queue keeps whatever it last loaded.
      debugPrint('_refreshChatReports failed: $e');
    }
  }

  Future<void> dismissChatReport(String reportId) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.dismissChatReport(reportId);
    await _refreshChatReports();
  }

  /// Admin-only: append-only history of every mute action, grouped by
  /// profile (Cluster 4 Tasks 13 & 15's "Muted Chatters Audit Log").
  List<ChatMuteAuditEntry> get mutedChattersAuditLog =>
      List.unmodifiable(_mutedChattersAuditLog);

  Future<void> ensureMutedChattersAuditLoaded() async {
    if (_mutedChattersAuditLoaded) return;
    _mutedChattersAuditLoaded = true;
    await refreshMutedChattersAuditLog();
  }

  Future<void> refreshMutedChattersAuditLog() async {
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      _mutedChattersAuditLog =
          await _adminDbService!.loadMutedChattersAuditLog();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshMutedChattersAuditLog failed: $e');
    }
  }

  /// Deletes the reported message -- propagates to every viewer's live chat
  /// via chat_messages'postgres_changes DELETE event, the same mechanism
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

  /// [muteDurationHours] null means permanent (Cluster 4 Task 14's 10 min /
  /// 1 hour / permanent mute-duration picker in the moderation queue).
  Future<void> muteChatSenderAndResolveReport(
    ChatReportModel report, {
    double? muteDurationHours,
  }) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.muteChatSenderAndResolveReport(
      streamId: report.streamId,
      senderId: report.reportedSenderId,
      reportId: report.id,
      muteDurationHours: muteDurationHours,
    );
    await _refreshChatReports();
    if (_mutedChattersAuditLoaded) {
      await refreshMutedChattersAuditLog();
    }
  }

  /// Bans the reported sender platform-wide (Cluster 4 Task 14's "Ban
  /// Platform-Wide"queue action) and resolves this report. Needs the
  /// sender's email, which chat_reports doesn't carry directly -- resolved
  /// via reportedEmail on the joined ChatReportModel row.
  Future<void> banChatSenderAndResolveReport(
    ChatReportModel report, {
    required String reason,
    DateTime? expiresAt,
  }) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.banAccountPlatformWide(
      profileId: report.reportedSenderId,
      email: report.reportedEmail ?? report.reportedDisplayName,
      reason: reason,
      expiresAt: expiresAt,
    );
    await _adminDbService!.dismissChatReport(report.id);
    await _refreshChatReports();
  }

  // ==========================================
  // Academic Categories Taxonomy (Cluster 3 Task 10/11)
  // ==========================================

  List<AcademicCategoryModel> get academicCategories =>
      _isUsingCachedCatalog || _publicCategoriesLoaded
          ? List.unmodifiable(_academicCategories)
          : AcademicCategoryModel.defaultPool;

  String? get selectedCategoryId =>
      _currentCategoryFilter == 'all' ? null : _currentCategoryFilter;

  /// Loads the live category list. Call from Discovery/Map/Admin
  /// initState; safe to call repeatedly (only hits the backend once per app
  /// session, same caching shape as ensureChatReportsLoaded). Falls back to
  /// AcademicCategoryModel.defaultPool (via the getter above) when empty --
  /// covers both "not loaded yet"and "Supabase unreachable".
  Future<void> ensureAcademicCategoriesLoaded() {
    if (!isOnline) return Future<void>.value();
    if (_publicCategoriesLoaded) return Future<void>.value();
    final active = _categoriesLoad;
    if (active != null) return active;
    final request = _refreshAcademicCategories();
    _categoriesLoad = request;
    request.whenComplete(() {
      if (identical(_categoriesLoad, request)) _categoriesLoad = null;
    });
    return request;
  }

  Future<void> _refreshAcademicCategories() async {
    final generation = ++_categoryRequestGeneration;
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      final categories =
          await _adminDbService!.loadAcademicCategories(requireSuccess: true);
      if (_disposed || generation != _categoryRequestGeneration || !isOnline) {
        return;
      }
      _academicCategories = categories;
      _publicCategoriesLoaded = true;
      unawaited(_persistPublicCatalogIfReady());
      notifyListeners();
    } catch (e) {
      debugPrint('_refreshAcademicCategories failed: $e');
    }
  }

  Future<void> saveAcademicCategory(AcademicCategoryModel category) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.saveAcademicCategory(category);
    await _refreshAcademicCategories();
  }

  Future<void> deleteAcademicCategory(String id) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.deleteAcademicCategory(id);
    await _refreshAcademicCategories();
  }

  // ==========================================
  // Tag Moderation (Cluster 3 Task 12)
  // ==========================================

  /// Public-safe: approved tag names only, for discovery filters and the
  /// application form's autocomplete.
  List<String> get approvedTags => List.unmodifiable(_approvedTags);

  /// Admin-only: every tag row regardless of status, for the Tag
  /// Moderation Manager.
  List<TagModerationModel> get allTagsForModeration =>
      List.unmodifiable(_allTagsForModeration);

  Future<void> ensureTagsLoaded() async {
    if (_tagsLoaded) return;
    _tagsLoaded = true;
    await _refreshTags();
  }

  Future<void> _refreshTags() async {
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      _approvedTags = await _adminDbService!.loadApprovedTagNames();
      if (isAdminUser) {
        final tags = await _adminDbService!.loadAllTags();
        // Usage counts (Task 12) only matter for approved/assignable tags --
        // skip the query for pending/blacklisted rows nobody can be tagged
        // with yet.
        final counts = await Future.wait(tags.map((t) =>
            t.status == TagStatus.approved
                ? _adminDbService!.countBroadcastersForTag(t.name)
                : Future.value(0)));
        _allTagsForModeration = [
          for (var i = 0; i < tags.length; i++)
            tags[i].copyWith(usageCount: counts[i]),
        ];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('_refreshTags failed: $e');
    }
  }

  /// "Inspect Broadcasters"drill-down data for one tag (Task 12).
  Future<List<TaggedBroadcasterSummary>> loadBroadcastersForTag(
      String tagName) async {
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      return await _adminDbService!.loadBroadcastersForTag(tagName);
    } catch (e) {
      debugPrint('loadBroadcastersForTag failed: $e');
      return const [];
    }
  }

  /// Submits a new tag from the streamer application form as pending review
  /// (Task 12) -- a no-op if it already exists in any status.
  Future<void> submitPendingTag(String tag) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.submitPendingTag(tag);
  }

  Future<void> approveTag(String name) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.setTagStatus(name, TagStatus.approved);
    await _refreshTags();
  }

  Future<void> blacklistTag(String name) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.setTagStatus(name, TagStatus.blacklisted);
    await _refreshTags();
  }

  Future<void> mergeRenameTag({
    required String oldName,
    required String newName,
  }) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.mergeRenameTag(oldName: oldName, newName: newName);
    await _refreshTags();
  }

  // ==========================================
  // Banned Accounts (Cluster 4 Task 16)
  // ==========================================

  bool get isCurrentUserBanned => _isCurrentUserBanned;
  String? get currentUserBanReason => _currentUserBanReason;

  List<BannedUserModel> get bannedUsers => List.unmodifiable(_bannedUsers);

  Future<void> _refreshCurrentUserBanStatus() async {
    final generation = _authGeneration;
    try {
      if (!Supabase.instance.isInitialized) return;
      final userId = _authService.currentSession?.user.id;
      if (userId == null) {
        _isCurrentUserBanned = false;
        _currentUserBanReason = null;
        return;
      }
      final row = await Supabase.instance.client
          .from('banned_users')
          .select('reason, expires_at')
          .eq('profile_id', userId)
          .maybeSingle();
      if (_authGeneration != generation) return;
      final expiresAtRaw = row?['expires_at'] as String?;
      final expiresAt =
          expiresAtRaw != null ? DateTime.parse(expiresAtRaw) : null;
      final isBanned = row != null &&
          (expiresAt == null || expiresAt.isAfter(DateTime.now()));
      _isCurrentUserBanned = isBanned;
      _currentUserBanReason = isBanned ? row['reason'] as String? : null;
      _syncBanPolling();
      notifyListeners();
    } catch (e) {
      debugPrint('_refreshCurrentUserBanStatus failed: $e');
    }
  }

  Timer? _banPollTimer;

  /// While this account is banned, re-read its ban row so an unban restores
  /// access without a restart.
  void _syncBanPolling() {
    if (_isCurrentUserBanned && !_disposed) {
      _banPollTimer ??= Timer.periodic(
          const Duration(seconds: 20), (_) => _refreshCurrentUserBanStatus());
    } else {
      _banPollTimer?.cancel();
      _banPollTimer = null;
    }
  }

  Future<void> ensureBannedUsersLoaded() async {
    if (_bannedUsersLoaded) return;
    _bannedUsersLoaded = true;
    await _refreshBannedUsers();
  }

  Future<void> _refreshBannedUsers() async {
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      _bannedUsers = await _adminDbService!.loadBannedUsers();
      notifyListeners();
    } catch (e) {
      debugPrint('_refreshBannedUsers failed: $e');
    }
  }

  Future<void> banAccountByEmail({
    required String email,
    required String reason,
    DateTime? expiresAt,
  }) async {
    _adminDbService ??= await AdminDatabaseService.create();
    final profile = await _adminDbService!.findProfileByEmail(email);
    if (profile == null) {
      throw Exception('No account found for "$email".');
    }
    await _adminDbService!.banAccountPlatformWide(
      profileId: profile['id'] as String,
      email: email,
      reason: reason,
      expiresAt: expiresAt,
    );
    await _refreshBannedUsers();
  }

  Future<void> unbanAccount(String profileId) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.unbanAccount(profileId);
    await _refreshBannedUsers();
  }

  // ==========================================
  // Stream Moderator Delegation (Cluster 4 Task 15)
  // ==========================================

  List<StreamModeratorModel> get streamModerators =>
      List.unmodifiable(_streamModerators);

  Future<void> ensureStreamModeratorsLoaded() async {
    if (_streamModeratorsLoaded) return;
    _streamModeratorsLoaded = true;
    await _refreshStreamModerators();
  }

  Future<void> _refreshStreamModerators() async {
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      _streamModerators = await _adminDbService!.loadStreamModerators();
      notifyListeners();
    } catch (e) {
      debugPrint('_refreshStreamModerators failed: $e');
    }
  }

  Future<void> revokeStreamModeratorById(String id) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.revokeStreamModeratorById(id);
    await _refreshStreamModerators();
  }

  // ==========================================
  // Chat History Deletion (Cluster 4 Task 17)
  // ==========================================

  Future<bool> deleteAllMyMessages() async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      await _adminDbService!.deleteAllMyMessages();
      return true;
    } catch (e) {
      debugPrint('deleteAllMyMessages failed: $e');
      return false;
    }
  }

  Future<bool> deleteMyMessagesForStream(String streamId) async {
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      await _adminDbService!.deleteMyMessagesForStream(streamId);
      return true;
    } catch (e) {
      debugPrint('deleteMyMessagesForStream failed: $e');
      return false;
    }
  }

  Future<List<String>> loadMyMessageStreamIds() async {
    _adminDbService ??= await AdminDatabaseService.create();
    return _adminDbService!.loadMyMessageStreamIds();
  }

  // ==========================================
  // Temporary Map Visibility (Cluster 4 Task 18)
  // ==========================================

  /// Admin: hide or show a channel on the map through the audited server
  /// action. A refused or failed call changes nothing locally and returns
  /// false -- the toggle must not report a change the server did not make.
  Future<bool> setStreamerHiddenFromMap({
    required String streamerId,
    required bool hidden,
    required String reason,
  }) async {
    final streamer = getStreamerById(streamerId);
    if (streamer == null) return false;
    try {
      _adminDbService ??= await AdminDatabaseService.create();
      await _adminDbService!.setStreamerHiddenFromMap(
        streamerId: streamerId,
        isOrganization: streamer.isOrganization,
        hidden: hidden,
        reason: reason,
      );
    } catch (e) {
      debugPrint('setStreamerHiddenFromMap refused: $e');
      return false;
    }
    _streamers = _streamers.map((s) {
      return s.streamerId == streamerId
          ? s.copyWith(isTemporarilyHiddenFromMap: hidden)
          : s;
    }).toList();
    notifyListeners();
    return true;
  }

  // ==========================================
  // Streamer Silence / Mic Mute (Cluster 1 Task 1)
  // ==========================================

  bool get isStreamerMicMuted => _isStreamerMicMuted;

  /// Called from the broadcaster side whenever RtmpPublishEngine.isMicSilent
  /// changes -- either an explicit mute or sustained silence. Viewers read
  /// [isStreamerMicMuted] to decide whether to show the badge, so this is
  /// the seam a future Realtime stream-metadata channel plugs into without
  /// touching either the engine or the player overlay.
  void setStreamerMicMuted(bool muted) {
    if (_isStreamerMicMuted == muted) return;
    _isStreamerMicMuted = muted;
    notifyListeners();
  }

  // ==========================================
  // Streamer Custom Stream-State Cards (Cluster 1 Task 4b)
  // ==========================================

  List<StreamerCustomPlaceholderModel> get pendingCustomPlaceholders =>
      List.unmodifiable(_pendingCustomPlaceholders);

  List<StreamerCustomPlaceholderModel> get myCustomPlaceholders =>
      List.unmodifiable(_myCustomPlaceholders);

  List<StreamerCustomPlaceholderModel> get approvedCustomPlaceholders =>
      List.unmodifiable(_approvedCustomPlaceholders);

  /// The most recent submission of [type] by the signed-in streamer, or null
  /// if they have never uploaded one. Drives the editor sheet's per-slot
  /// preview and status chip.
  StreamerCustomPlaceholderModel? myPlaceholderFor(StreamPlaceholderType type) {
    for (final p in _myCustomPlaceholders) {
      if (p.placeholderType == type) return p;
    }
    return null;
  }

  static String _placeholderCacheKey(
          String streamerId, StreamPlaceholderType type) =>
      '$streamerId::${type.dbValue}';

  /// The approved custom card for a streamer/state pair, or null -- in which
  /// case StreamStatePlaceholderOverlay renders the default system
  /// placeholder. Reads the local cache only; call
  /// [ensureApprovedPlaceholderLoaded] to populate it.
  String? approvedPlaceholderImageUrl(
    String streamerId,
    StreamPlaceholderType type,
  ) =>
      _approvedPlaceholderUrls[_placeholderCacheKey(streamerId, type)];

  /// Keys already looked up (hit or miss) and when a failed lookup may be
  /// retried. The old code cached hits only, so a streamer with no artwork
  /// issued a new query on every rebuild of the live room (audit NET-07).
  final Set<String> _placeholderLookupsDone = {};
  final Map<String, DateTime> _placeholderRetryAfter = {};

  /// Fetches (once per streamer/type per session) the approved card for a
  /// stream about to render a placeholder. A miss is remembered, so a streamer
  /// with no artwork does not re-query on every state change; a failed lookup
  /// is retried at most once a minute.
  Future<void> ensureApprovedPlaceholderLoaded(
    String streamerId,
    StreamPlaceholderType type,
  ) async {
    final key = _placeholderCacheKey(streamerId, type);
    if (_approvedPlaceholderUrls.containsKey(key)) return;
    final retryAfter = _placeholderRetryAfter[key];
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) return;
    if (!_placeholderLookupsDone.add(key)) return;
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      final url = await _adminDbService!.loadApprovedPlaceholderUrl(
        streamerId: streamerId,
        placeholderType: type,
      );
      _placeholderRetryAfter.remove(key);
      if (url == null || url.isEmpty) return;
      _approvedPlaceholderUrls[key] = url;
      notifyListeners();
    } catch (e) {
      _placeholderLookupsDone.remove(key);
      _placeholderRetryAfter[key] =
          DateTime.now().add(const Duration(minutes: 1));
      debugPrint('ensureApprovedPlaceholderLoaded failed: $e');
    }
  }

  /// Loads the admin review queue plus this streamer's own submissions.
  /// Safe to call repeatedly (same one-shot caching shape as
  /// ensureChatReportsLoaded).
  Future<void> ensureCustomPlaceholdersLoaded() async {
    if (_customPlaceholdersLoaded) return;
    _customPlaceholdersLoaded = true;
    await refreshCustomPlaceholders();
  }

  Future<void> refreshCustomPlaceholders() async {
    _adminDbService ??= await AdminDatabaseService.create();
    try {
      _pendingCustomPlaceholders =
          await _adminDbService!.loadPendingCustomPlaceholders();
      _myCustomPlaceholders = await _adminDbService!.loadMyCustomPlaceholders();
      _approvedCustomPlaceholders =
          await _adminDbService!.loadApprovedCustomPlaceholders();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshCustomPlaceholders failed: $e');
    }
  }

  /// Cheap non-cryptographic content hash (FNV-1a, 32-bit) -- only used to
  /// detect "this is the same image bytes as before", not for security, so
  /// no external crypto dependency is pulled in for it.
  static String _hashPlaceholderBytes(Uint8List bytes) {
    const int fnvOffsetBasis = 0x811c9dc5;
    const int fnvPrime = 0x01000193;
    int hash = fnvOffsetBasis;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  Future<void> _ensureApprovedPlaceholderHashCacheLoaded() async {
    if (_approvedPlaceholderHashCacheLoaded) return;
    _approvedPlaceholderHashCacheLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kApprovedPlaceholderHashCachePrefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _approvedPlaceholderHashCache.addAll(
          decoded.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      }
    } catch (e) {
      debugPrint('Loading approved placeholder hash cache failed: $e');
    }
  }

  Future<void> _rememberApprovedPlaceholderHash(
      String hash, String imageUrl) async {
    _approvedPlaceholderHashCache[hash] = imageUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kApprovedPlaceholderHashCachePrefsKey,
          jsonEncode(_approvedPlaceholderHashCache));
    } catch (e) {
      debugPrint('Persisting approved placeholder hash cache failed: $e');
    }
  }

  /// Streamer-side upload. Returns the created (or reused) submission, or
  /// null when there is no backend to record it in -- the caller shows the
  /// "upload failed"toast in that case rather than pretending it queued.
  ///
  /// Task 4b: if these exact image bytes were already approved before (for
  /// this streamer, any slot), the upload is skipped entirely and the prior
  /// approved record is reused -- no new 'pending'row is created, so
  /// there's nothing for an admin to re-review. This is deliberately a
  /// client-side skip rather than trying to have a streamer's own upload
  /// insert as 'approved' -- the RLS insert policy only ever admits
  /// status='pending'by design (see submitCustomPlaceholder's own comment
  /// in AdminDatabaseService), so an already-vetted image is recognized by
  /// never re-entering the queue at all instead of bypassing that policy.
  Future<StreamerCustomPlaceholderModel?> submitCustomPlaceholder({
    required StreamPlaceholderType placeholderType,
    required String fileName,
    required Uint8List fileBytes,
    String contentType = 'image/jpeg',
  }) async {
    // A placeholder card belongs to a channel; without a resolved channel the
    // submission fails closed rather than being filed under a sample id (P1.6).
    final ownerStreamerId = currentUserStreamerId;
    if (ownerStreamerId == null || ownerStreamerId.isEmpty) return null;
    await _ensureApprovedPlaceholderHashCacheLoaded();
    final hash = _hashPlaceholderBytes(fileBytes);
    final cachedUrl = _approvedPlaceholderHashCache[hash];
    if (cachedUrl != null) {
      final existingApproved = _myCustomPlaceholders.firstWhere(
        (p) =>
            p.imageUrl == cachedUrl &&
            p.status == StreamPlaceholderStatus.approved,
        orElse: () => StreamerCustomPlaceholderModel(
          id: 'cached_${_placeholderCacheKey(ownerStreamerId, placeholderType)}',
          streamerId: ownerStreamerId,
          placeholderType: placeholderType,
          imageUrl: cachedUrl,
          status: StreamPlaceholderStatus.approved,
          createdAt: DateTime.now(),
        ),
      );
      _myCustomPlaceholders = [
        existingApproved,
        ..._myCustomPlaceholders
            .where((p) => p.placeholderType != placeholderType),
      ];
      _approvedPlaceholderUrls[_placeholderCacheKey(
          existingApproved.streamerId, placeholderType)] = cachedUrl;
      notifyListeners();
      return existingApproved;
    }

    _adminDbService ??= await AdminDatabaseService.create();
    final created = await _adminDbService!.submitCustomPlaceholder(
      placeholderType: placeholderType,
      fileName: fileName,
      fileBytes: fileBytes,
      contentType: contentType,
    );
    if (created != null) {
      _pendingPlaceholderHashById[created.id] = hash;
      _myCustomPlaceholders = [
        created,
        ..._myCustomPlaceholders
            .where((p) => p.placeholderType != placeholderType),
      ];
      notifyListeners();
    }
    return created;
  }

  // In-memory only (not persisted): links a still-pending submission's id
  // to the content hash computed at upload time, so approveCustomPlaceholder
  // can promote that hash into the persistent approved-hash cache. If the
  // app restarts before an admin reviews it, the link is lost and the item
  // simply goes through normal review -- a safe default, not a correctness
  // issue.
  final Map<String, String> _pendingPlaceholderHashById = {};

  Future<void> approveCustomPlaceholder(
      StreamerCustomPlaceholderModel placeholder) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.approveCustomPlaceholder(placeholder.id);
    // The approved artwork becomes live immediately, so refresh the playback
    // cache entry rather than leaving a stale "no custom card"miss behind.
    _approvedPlaceholderUrls[_placeholderCacheKey(
            placeholder.streamerId, placeholder.placeholderType)] =
        placeholder.imageUrl;

    final hash = _pendingPlaceholderHashById.remove(placeholder.id);
    if (hash != null) {
      await _rememberApprovedPlaceholderHash(hash, placeholder.imageUrl);
    }

    await refreshCustomPlaceholders();
  }

  /// Rejection is the only path that notifies the streamer, and it always
  /// carries the admin's reason -- Trigger 10's card-edit-request
  /// notification is what tells them what to fix.
  Future<void> rejectCustomPlaceholder(
    StreamerCustomPlaceholderModel placeholder, {
    required String reason,
    BuildContext? context,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw Exception('A rejection reason is required.');
    }
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.rejectCustomPlaceholder(
      placeholderId: placeholder.id,
      reason: trimmed,
    );
    _approvedPlaceholderUrls.remove(_placeholderCacheKey(
        placeholder.streamerId, placeholder.placeholderType));
    // The notification itself is unconditional -- a rejection the streamer
    // never hears about is the failure mode this pipeline exists to avoid.
    // Only the optional in-app toast overlay needs a still-mounted context.
    notifyAdminCardEditRequestStreamer(
      fieldsEn: trimmed,
      fieldsAr: trimmed,
      context: (context != null && context.mounted) ? context : null,
    );
    await refreshCustomPlaceholders();
  }

  Future<void> _writeThroughOrgSpeaker(String orgId, OrgSpeakerModel speaker) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.upsertOrgSpeaker(orgId, speaker);
    _realOrgSpeakers.remove(orgId);
  }

  Future<void> _writeThroughOrgVenue(String orgId, OrgVenueBranchModel venue) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.upsertOrgVenue(orgId, venue);
    _realOrgVenues.remove(orgId);
  }

  Future<void> _writeThroughDeleteOrgSpeaker(String orgId, String speakerId) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.deleteOrgSpeaker(speakerId);
    _realOrgSpeakers.remove(orgId);
  }

  Future<void> _writeThroughDeleteOrgVenue(String orgId, String venueId) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.deleteOrgVenue(venueId);
    _realOrgVenues.remove(orgId);
  }

  Future<void> updateSpeakerPermissions(String orgId, String speakerId,
      OrgBroadcasterPermissions permissions) async {
    final speaker = getStreamerById(orgId)?.affiliatedSpeakers
        .where((s) => s.speakerId == speakerId).firstOrNull;
    final profileId = speaker?.linkedProfileId;
    if (profileId == null) throw StateError('Accept a membership invitation first');
    final members = await organizationMembers(orgId);
    final member = members.where((m) => m.profileId == profileId).firstOrNull;
    if (member == null) throw StateError('Membership unavailable');
    await setOrganizationMember(orgId, profileId, member.roleValue,
        member.statusValue, permissions.toJson().cast<String, bool>());
  }

  bool canUserBroadcastForOrg(String orgId, String? userEmail) =>
      _organizationBroadcastApproved && userEmail != null &&
      userEmail.toLowerCase() == _googleUserEmail?.toLowerCase() &&
      _orgMemberships.any((m) => m.organizationId == orgId && m.active &&
          (m.permissions.canGoLiveVideo || m.permissions.canGoAudioOnly));

  Future<void> addOrganizationBranch(
      String orgId, OrgVenueBranchModel branch) async {
    await _writeThroughOrgVenue(orgId, branch);
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedVenues = List<OrgVenueBranchModel>.from(currentOrg.venues)
      ..add(branch);
    _streamers[idx] = currentOrg.copyWith(venues: updatedVenues);

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
    await _writeThroughOrgVenue(orgId, branch);
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedVenues = currentOrg.venues
        .map((v) => v.venueId == branch.venueId ? branch : v)
        .toList();
    _streamers[idx] = currentOrg.copyWith(venues: updatedVenues);

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
    await _writeThroughDeleteOrgVenue(orgId, venueId);
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
    await _writeThroughOrgSpeaker(orgId, speaker);
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedSpeakers =
        List<OrgSpeakerModel>.from(currentOrg.affiliatedSpeakers)..add(speaker);
    _streamers[idx] = currentOrg.copyWith(affiliatedSpeakers: updatedSpeakers);

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
    await _writeThroughOrgSpeaker(orgId, speaker);
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedSpeakers = currentOrg.affiliatedSpeakers
        .map((s) => s.speakerId == speaker.speakerId ? speaker : s)
        .toList();
    _streamers[idx] = currentOrg.copyWith(affiliatedSpeakers: updatedSpeakers);

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
    await _writeThroughDeleteOrgSpeaker(orgId, speakerId);
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
  //  14 Humanized Notification Event Dispatchers (Saudi Arabic & English)
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
        titleEn: 'Live Guest Speaker Invitation',
        titleAr: 'دعوة للمشاركة كمتحدث ضيف',
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
        titleEn: 'Faculty Affiliation Invitation',
        titleAr: 'دعوة انضمام للكادر التعليمي',
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
        titleEn: 'Organization Affiliation Updated',
        titleAr: 'تحديث الارتباط الأكاديمي',
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
        titleEn: 'Administrative Note from Streamer Team',
        titleAr: 'رسالة إدارية من فريق المنصة',
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
        titleEn: 'Profile Card Update Requested',
        titleAr: 'مطلوب مراجعة بيانات البطاقة التعريفية',
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
        titleEn: 'Administrative Message for $orgNameEn',
        titleAr: 'رسالة إدارية موجهة لـ $orgNameAr',
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
        titleEn: 'Campus Branch Details Review',
        titleAr: 'إشعار تنظيمي لتحديث بيانات المدرج',
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
        titleEn: 'New Lecture Added by $streamerNameEn',
        titleAr: 'محاضرة جديدة أضافها $streamerNameAr',
        bodyEn: 'New lecture: "$vodTitleEn"is now available to watch!',
        bodyAr: 'فيديو ومحاضرة جديدة: «$vodTitleAr».. شاهدها الآن واستفد!',
        timestamp: DateTime.now(),
        actionUrl: '/profile/$streamerId',
        metadata: {'video_id': videoId},
      ),
      context: context,
    );
  }
}

/// What the studio learned about a watch link before listing it.
enum WatchLinkVerdict {
  live,
  upcoming,
  ended,
  notLive,
  notFound,
  wrongChannel,

  /// Upcoming, but scheduled more than an hour from now.
  scheduledLater,

  /// YouTube could not be asked (no API key, quota, network).
  unverified,
}

class WatchLinkCheck {
  const WatchLinkCheck(this.verdict,
      {this.channelVerified = false,
      this.channelOnRecord = false,
      this.channelConfigurationErrorKey});
  final String? channelConfigurationErrorKey;
  final WatchLinkVerdict verdict;

  /// A channel handle is on record for this account (whether or not it
  /// could be resolved just now).
  final bool channelOnRecord;

  /// What the studio must tell the broadcaster about an allowed link that
  /// was not fully checked, or null when it was.
  String? get noteKey {
    if (verdict == WatchLinkVerdict.unverified) {
      return 'live_studio.watch_check_unverified_note';
    }
    if (!channelUnconfirmed) return null;
    return channelOnRecord
        ? 'live_studio.watch_check_channel_lookup_failed_note'
        : 'live_studio.watch_check_channel_unconfirmed_note';
  }

  /// The link was confirmed to belong to this account's channel on record.
  final bool channelVerified;

  /// Allowed, but the channel could not be compared with one on record (no
  /// handle, or it did not resolve). The studio says so instead of implying
  /// the link was matched to this account.
  bool get channelUnconfirmed =>
      (verdict == WatchLinkVerdict.live ||
          verdict == WatchLinkVerdict.upcoming) &&
      !channelVerified;

  /// Demo and release both fail closed. This is client validation only,
  /// not a server ownership guarantee or proof of viewer playback.
  bool get allowsStart =>
      channelVerified &&
      (verdict == WatchLinkVerdict.live ||
          verdict == WatchLinkVerdict.upcoming);

  /// Explanation for a refused link, or null when it may be used.
  String? get errorKey =>
      channelConfigurationErrorKey ??
      switch (verdict) {
        WatchLinkVerdict.notFound => 'live_studio.watch_check_not_found',
        WatchLinkVerdict.ended => 'live_studio.watch_check_ended',
        WatchLinkVerdict.notLive => 'live_studio.watch_check_not_live',
        WatchLinkVerdict.wrongChannel =>
          'live_studio.watch_check_wrong_channel',
        WatchLinkVerdict.scheduledLater =>
          'live_studio.watch_check_scheduled_later',
        WatchLinkVerdict.unverified => 'live_studio.watch_check_unavailable',
        WatchLinkVerdict.live ||
        WatchLinkVerdict.upcoming =>
          channelVerified ? null : 'live_studio.watch_check_channel_required',
      };
}
