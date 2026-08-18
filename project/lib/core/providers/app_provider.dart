import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../theme/app_theme.dart';
import '../services/youtube_api_service.dart';
import '../services/google_auth_service.dart';
import '../services/admin_database_service.dart';
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

class AppProvider extends ChangeNotifier {
  List<StreamerModel> _streamers = List.from(mockStreamers);
  List<GhostComment> _chatMessages = [];
  final List<LectureQuestionModel> _questions =
      List.from(LectureQuestionModel.sampleQuestions);
  UserProfileModel _userProfile = UserProfileModel.defaultProfile;
  final YouTubeApiService _youTubeService = YouTubeApiService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  AdminDatabaseService? _adminDbService;

  // Admin Hub, Verification & Governance State
  List<BroadcasterApplicationModel> _applications = [];
  List<OrgAuditLogEntry> _auditLogs = [];
  TermsAndConditionsModel _termsAndConditions =
      TermsAndConditionsModel.createDefault();
  ViewerAnalyticsModel _viewerAnalytics = ViewerAnalyticsModel.createDefault();
  static const Set<String> _superAdminEmails = {
    'polkgvd2@gmail.com',
    'ameeralhatemi67@gmail.com',
    'amir.alhatemi@gmail.com',
  };

  // Onboarding & Authentication State
  bool _hasCompletedOnboarding = false;
  bool _isLoggedInStreamer = false;
  bool _isGuestViewer = false;
  String? _guestViewerName;
  String? _guestViewerAvatar;
  String? _googleUserEmail;
  String? _googleUserName;
  String? _googleUserAvatar;

  // Org $\leftrightarrow$ Streamer Affiliation State
  List<OrgAffiliationRequestModel> _affiliationRequests = [];

  bool _isStreamerModeEnabled =
      false; // Toggle between Streamer and Viewer modes
  bool _isPitchDirectorModeEnabled = false;
  String _selectedCityId = 'khobar';
  final String _activeStreamId = 'stream_live_992';
  String _currentCategoryFilter = 'all';
  String _selectedTagFilter = 'all';
  String _searchQuery = '';
  String _rtmpLaptopIp = '192.168.1.100';
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

  // Notifications (Rule: max 8 items, auto-deleted after 6 hours)
  final List<AppNotificationItem> _notifications = [];

  AppProvider([AdminDatabaseService? adminDbService])
      : _adminDbService = adminDbService {
    _initAdminDatabase();
    // NOTE: Live viewer polling is NOT started in the constructor to keep
    // widget tests clean (no pending timer assertions). The real app starts
    // it via AppProvider.ensureLivePollingActive() from main.dart / app root.
  }

  Future<void> _initAdminDatabase() async {
    _adminDbService ??= await AdminDatabaseService.create();
    _applications = List.from(await _adminDbService!.loadApplications());
    _termsAndConditions = await _adminDbService!.loadTerms();
    _viewerAnalytics = await _adminDbService!.loadAnalytics();
    _auditLogs = List.from(await _adminDbService!.loadAuditLogs());
    _affiliationRequests =
        List.from(await _adminDbService!.loadAffiliationRequests());
    notifyListeners();
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
    final liveStreamers = _streamers.where((s) =>
        s.isCurrentlyLive && s.youtubeVideoId.isNotEmpty).toList();

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
    super.dispose();
  }

  // Admin & Governance Getters
  bool get isAdminUser =>
      _isLoggedInStreamer &&
      _googleUserEmail != null &&
      _superAdminEmails.contains(_googleUserEmail!.trim().toLowerCase());

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
  List<String> get selectedCoSpeakerIds => List.unmodifiable(_selectedCoSpeakerIds);

  void setSelectedBroadcastOrgId(String? orgId) {
    _selectedBroadcastOrgId = orgId;
    if (orgId != null) {
      final venues = getOrganizationVenues(orgId);
      final mainHq = venues.firstWhere(
        (v) => v.isMainHeadquarters,
        orElse: () => venues.isNotEmpty ? venues.first : const OrgVenueBranchModel(venueId: '', nameEn: '', nameAr: '', cityEn: '', cityAr: '', latitude: 0, longitude: 0, seatingCapacity: 0),
      );
      _selectedVenueBranchId = mainHq.venueId.isNotEmpty ? mainHq.venueId : (venues.isNotEmpty ? venues.first.venueId : null);
      final speakers = getOrganizationSpeakers(orgId);
      _selectedCoSpeakerIds = speakers.isNotEmpty ? [speakers.first.speakerId] : [];
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

  List<AppNotificationItem> get notifications {
    _cleanupOldNotifications();
    return List.unmodifiable(_notifications);
  }

  int get unreadNotificationsCount {
    _cleanupOldNotifications();
    return _notifications.where((n) => !n.isRead).length;
  }

  void _cleanupOldNotifications() {
    final now = DateTime.now();
    _notifications.removeWhere((n) => now.difference(n.timestamp).inHours >= 6);
  }

  void addNotification(AppNotificationItem item) {
    _cleanupOldNotifications();
    while (_notifications.length >= 8) {
      _notifications.removeAt(0); // FIFO: remove oldest if 9th arrives
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

  bool deleteStreamer(String streamerId) {
    if (protectedStreamerIds.contains(streamerId)) {
      return false; // Protected original streamer cannot be deleted
    }
    _streamers.removeWhere((s) => s.streamerId == streamerId);
    notifyListeners();
    return true;
  }

  StreamerModel? getStreamerById(String streamerIdOrStreamId) {
    try {
      final clean = streamerIdOrStreamId.trim().replaceAll('@', '').toLowerCase();
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

  Future<void> loginWithGoogle({
    String? email,
    String? name,
    String? avatar,
    bool isNewSignUp = false,
  }) async {
    final result = await _googleAuthService.signIn();
    _hasCompletedOnboarding = true;
    _isLoggedInStreamer = true;
    _isGuestViewer = false;
    _isStreamerModeEnabled = true;
    _googleUserEmail = email ?? result.email ?? 'amir.alhatemi@gmail.com';
    _googleUserName = name ?? result.displayName ?? 'Amir Al-Hatemi';
    _googleUserAvatar =
        avatar ?? result.photoUrl ?? 'assets/images/Amir_Alhatemi/amir_person_pic.jpg';

    _userProfile = _userProfile.copyWith(
      nameEn: _googleUserName,
      nameAr: _googleUserName,
      avatarUrl: _googleUserAvatar,
    );

    if (isNewSignUp) {
      await registerGoogleUser();
    }

    notifyListeners();
  }

  /// Submits a multi-step Broadcaster / Organization verification application
  Future<void> submitBroadcasterApplication(
      BroadcasterApplicationModel application) async {
    _applications.insert(0, application);
    await _adminDbService?.submitApplication(application);

    // Record in immutable governance audit trail
    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_app_${DateTime.now().millisecondsSinceEpoch}',
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
    if (!isAdminUser) {
      _googleUserEmail = application.email;
      _googleUserName = application.applicantNameEn;
      _googleUserAvatar = application.avatarUrl;
    }

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
      id: 'aff_req_${DateTime.now().millisecondsSinceEpoch}',
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
        logId: 'audit_aff_req_${DateTime.now().millisecondsSinceEpoch}',
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

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_spk_add_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.addSpeakerToRoster,
        descriptionEn: 'Added ${speaker.nameEn} to organization speaker roster.',
        descriptionAr: 'تمت إضافة ${speaker.nameAr} إلى قائمة المدربين المعتمدين.',
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

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_spk_rem_${DateTime.now().millisecondsSinceEpoch}',
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
        logId: 'audit_spk_perm_${DateTime.now().millisecondsSinceEpoch}',
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
    await _googleAuthService.signOut();
    _hasCompletedOnboarding = false;
    _isLoggedInStreamer = false;
    _isGuestViewer = false;
    _isStreamerModeEnabled = false;
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

  // Toggle Streamer / Viewer Mode
  void setRoleMode(bool isStreamer) {
    _isStreamerModeEnabled = isStreamer;
    if (isStreamer && !_isLoggedInStreamer) {
      // Automatically associate with Google account when entering streamer mode
      _isLoggedInStreamer = true;
      _googleUserEmail = 'amir.alhatemi@gmail.com';
      _googleUserName = 'Amir Al-Hatemi';
      _googleUserAvatar = 'assets/images/Amir_Alhatemi/amir_person_pic.jpg';
    }
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

  void setBroadcastType(BroadcastType type) {
    _customBroadcastType = type;
    _streamers = _streamers.map((streamer) {
      if (streamer.streamerId == 'prof_alghamdi_01') {
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

    final orgId = _selectedBroadcastOrgId;
    final targetStreamerId = orgId ?? 'prof_alghamdi_01';

    // Synchronize target streamer model with the custom live data
    _streamers = _streamers.map<StreamerModel>((streamer) {
      if (streamer.streamerId == targetStreamerId) {
        OrgVenueBranchModel? activeBranch;
        if (orgId != null && _selectedVenueBranchId != null && streamer.venues.isNotEmpty) {
          activeBranch = streamer.venues.firstWhere(
            (v) => v.venueId == _selectedVenueBranchId,
            orElse: () => streamer.venues.first,
          );
        }

        return streamer.copyWith(
          isCurrentlyLive: _isBroadcastingLive,
          broadcastType: _isBroadcastingLive ? _customBroadcastType : BroadcastType.offline,
          activeStreamId: _isBroadcastingLive ? 'stream_live_992' : null,
          activeViewerCount: _isBroadcastingLive ? 0 : 0,
          titleEn: _customLiveTitle,
          titleAr: _customLiveTitle,
          latitude: activeBranch != null ? activeBranch.latitude : streamer.latitude,
          longitude: activeBranch != null ? activeBranch.longitude : streamer.longitude,
          venueNameEn: activeBranch != null ? activeBranch.nameEn : streamer.venueNameEn,
          venueNameAr: activeBranch != null ? activeBranch.nameAr : streamer.venueNameAr,
          activeLiveVenueId: _isBroadcastingLive ? (_selectedVenueBranchId ?? streamer.activeLiveVenueId) : null,
        );
      }
      return streamer;
    }).toList();

    if (_isBroadcastingLive) {
      // Start polling real viewer count from YouTube
      _startLiveViewerPolling();
      final isAudio = _customBroadcastType == BroadcastType.liveAudio;
      addNotification(
        AppNotificationItem(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          streamerId: targetStreamerId,
          titleEn: isAudio ? '🎙️ Audio Live Stream Started' : '🔴 Live Broadcast Started',
          titleAr: isAudio ? '🎙️ بدأ البث الصوتي المباشر' : '🔴 بدأ البث المباشر',
          bodyEn: '${orgId != null ? 'Dalilk 4 IELTS' : 'Amir Al-Hatemi'} is ${isAudio ? 'streaming live audio' : 'live now'}: $_customLiveTitle',
          bodyAr: '${orgId != null ? 'دليل الآيلتس' : 'أمير الحاتمي'} مباشر الآن (${isAudio ? 'صوتي' : 'مرئي'}): $_customLiveTitle',
          timestamp: DateTime.now(),
          streamId: 'stream_live_992',
          isLiveAlert: true,
        ),
      );

      if (orgId != null) {
        await recordOrgAuditAction(
          OrgAuditLogEntry(
            logId: 'audit_live_${DateTime.now().millisecondsSinceEpoch}',
            organizationId: orgId,
            timestamp: DateTime.now(),
            actorEmail: _googleUserEmail ?? 'admin@platform.com',
            actorName: _googleUserName ?? 'Administrator',
            action: OrgAuditAction.startLiveBroadcast,
            descriptionEn: 'Started live broadcast "$_customLiveTitle" (${isAudio ? 'Audio-Only' : 'Video'}).',
            descriptionAr: 'بدأ بث مباشر "$_customLiveTitle" (${isAudio ? 'صوتي' : 'مرئي'}).',
            metadata: {
              'venue_id': _selectedVenueBranchId,
              'speakers': _selectedCoSpeakerIds,
              'broadcast_type': isAudio ? 'audio' : 'video',
              'youtube_id': _customYouTubeVideoId,
            },
          ),
        );
      }

      if (context != null && context.mounted) {
        triggerSimulatedNotification(context);
      }
    } else {
      if (orgId != null) {
        await recordOrgAuditAction(
          OrgAuditLogEntry(
            logId: 'audit_live_end_${DateTime.now().millisecondsSinceEpoch}',
            organizationId: orgId,
            timestamp: DateTime.now(),
            actorEmail: _googleUserEmail ?? 'admin@platform.com',
            actorName: _googleUserName ?? 'Administrator',
            action: OrgAuditAction.endLiveBroadcast,
            descriptionEn: 'Ended live broadcast session.',
            descriptionAr: 'تم إنهاء جلسة البث المباشر.',
          ),
        );
      }
      // Stop polling if no live streamers remain (Quran 24/7 excluded
      // from this check because it never calls toggleBroadcasterGoLive)
      final anyOtherLive = _streamers.any((s) => s.isCurrentlyLive);
      if (!anyOtherLive) {
        // Still keep polling for the always-on Quran stream if it is live
        final quranStillLive = _streamers.any(
            (s) => s.streamerId == 'quran_4k_05' && s.isCurrentlyLive);
        if (!quranStillLive) _stopLiveViewerPolling();
      }
    }
    notifyListeners();
  }

  static String extractYouTubeId(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'dQw4w9WgXcQ';
    
    // Support youtube.com/live/VIDEO_ID format
    final liveMatch = RegExp(r'youtube\.com\/live\/([a-zA-Z0-9_-]{11})', caseSensitive: false).firstMatch(trimmed);
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

  void setSelectedStreamingQuality(String quality) {
    _selectedStreamingQuality = quality;
    notifyListeners();
  }

  void setStreamingQuality(String quality) {
    _selectedStreamingQuality = quality;
    notifyListeners();
  }

  void triggerSimulatedNotification(BuildContext context) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.accentRed, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.accentRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'notifications.live_alert_title'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'notifications.live_alert_body'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 4),
    );
  }

  // ==========================================
  // Admin & Broadcaster Application Actions
  // ==========================================

  Future<bool> approveBroadcasterApplication(
    String applicationId, {
    String? adminNotes,
  }) async {
    final idx = _applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;

    final app = _applications[idx];
    _adminDbService ??= await AdminDatabaseService.create();
    final updated = await _adminDbService!.updateApplicationStatus(
      applicationId,
      ApplicationStatus.approved,
      reviewNotes: adminNotes,
      reviewedBy: _googleUserName ?? 'Amir Al-Hatemi (Super Admin)',
    );

    if (updated != null) {
      _applications = List.from(await _adminDbService!.loadApplications());
    }

    // Instantiate as a verified live StreamerModel
    final newStreamer = StreamerModel(
      streamerId: 'streamer_${app.id}',
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
      latitude: app.latitude,
      longitude: app.longitude,
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

    addNotification(
      AppNotificationItem(
        id: 'notif_verified_${app.id}',
        streamerId: newStreamer.streamerId,
        titleEn: 'New Broadcaster Approved!',
        titleAr: 'تم اعتماد مذيع جديد بنجاح!',
        bodyEn:
            '${app.applicantNameEn} has been verified and added to the spatial map.',
        bodyAr:
            'تم توثيق ${app.applicantNameAr} وإضافته إلى الخريطة التفاعلية.',
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
    return true;
  }

  Future<bool> rejectBroadcasterApplication(
    String applicationId, {
    required String reason,
  }) async {
    final idx = _applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;

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
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteBroadcasterApplication(String applicationId) async {
    final idx = _applications.indexWhere((a) => a.id == applicationId);
    if (idx == -1) return false;

    _adminDbService ??= await AdminDatabaseService.create();
    final success = await _adminDbService!.deleteApplication(applicationId);
    if (success) {
      _applications.removeAt(idx);
      notifyListeners();
    }
    return success;
  }

  Future<void> updateTermsAndConditions(TermsAndConditionsModel newTerms) async {
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
      return _auditLogs.where((l) => l.organizationId == organizationId).toList();
    }
    return List.unmodifiable(_auditLogs);
  }

  Future<void> recordOrgAuditAction(OrgAuditLogEntry entry) async {
    _adminDbService ??= await AdminDatabaseService.create();
    await _adminDbService!.recordAuditLog(entry);
    _auditLogs.insert(0, entry);
    notifyListeners();
  }

  List<OrgVenueBranchModel> getOrganizationVenues(String orgId) {
    final streamer = getStreamerById(orgId);
    return streamer?.venues ?? const [];
  }

  List<OrgSpeakerModel> getOrganizationSpeakers(String orgId) {
    final streamer = getStreamerById(orgId);
    return streamer?.affiliatedSpeakers ?? const [];
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

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_perm_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.grantBroadcastPermission,
        descriptionEn:
            'Updated broadcast permissions for speaker ${currentSpeaker.nameEn}.',
        descriptionAr:
            'تم تحديث صلاحيات البث للمدرب ${currentSpeaker.nameAr}.',
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
    if (_superAdminEmails.contains(emailLower)) return true;

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

  Future<void> addOrganizationBranch(String orgId, OrgVenueBranchModel branch) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedVenues = List<OrgVenueBranchModel>.from(currentOrg.venues)..add(branch);
    _streamers[idx] = currentOrg.copyWith(venues: updatedVenues);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_branch_add_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.addVenueBranch,
        descriptionEn: 'Added new campus branch: ${branch.nameEn} (${branch.cityEn}).',
        descriptionAr: 'تمت إضافة فرع جديد: ${branch.nameAr} (${branch.cityAr}).',
        metadata: branch.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> updateOrganizationBranch(String orgId, OrgVenueBranchModel branch) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedVenues = currentOrg.venues.map((v) => v.venueId == branch.venueId ? branch : v).toList();
    _streamers[idx] = currentOrg.copyWith(venues: updatedVenues);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_branch_upd_${DateTime.now().millisecondsSinceEpoch}',
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
      orElse: () => const OrgVenueBranchModel(venueId: '', nameEn: '', nameAr: '', cityEn: '', cityAr: '', latitude: 0, longitude: 0, seatingCapacity: 0),
    );
    final updatedVenues = currentOrg.venues.where((v) => v.venueId != venueId).toList();
    _streamers[idx] = currentOrg.copyWith(venues: updatedVenues);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_branch_del_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.removeVenueBranch,
        descriptionEn: 'Removed campus branch: ${removed.nameEn.isNotEmpty ? removed.nameEn : venueId}.',
        descriptionAr: 'تم حذف الفرع: ${removed.nameAr.isNotEmpty ? removed.nameAr : venueId}.',
        metadata: {'venue_id': venueId},
      ),
    );
    notifyListeners();
  }

  Future<void> addOrganizationSpeaker(String orgId, OrgSpeakerModel speaker) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedSpeakers = List<OrgSpeakerModel>.from(currentOrg.affiliatedSpeakers)..add(speaker);
    _streamers[idx] = currentOrg.copyWith(affiliatedSpeakers: updatedSpeakers);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_spk_add_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.addSpeakerToRoster,
        descriptionEn: 'Added instructor to roster: ${speaker.nameEn} (${speaker.roleOrTitleEn}).',
        descriptionAr: 'تمت إضافة مدرب إلى الكادر: ${speaker.nameAr} (${speaker.roleOrTitleAr}).',
        metadata: speaker.toJson(),
      ),
    );
    notifyListeners();
  }

  Future<void> updateOrganizationSpeaker(String orgId, OrgSpeakerModel speaker) async {
    final idx = _streamers.indexWhere((s) => s.streamerId == orgId);
    if (idx == -1) return;

    final currentOrg = _streamers[idx];
    final updatedSpeakers = currentOrg.affiliatedSpeakers.map((s) => s.speakerId == speaker.speakerId ? speaker : s).toList();
    _streamers[idx] = currentOrg.copyWith(affiliatedSpeakers: updatedSpeakers);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_spk_upd_${DateTime.now().millisecondsSinceEpoch}',
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
      orElse: () => const OrgSpeakerModel(speakerId: '', nameEn: '', nameAr: '', roleOrTitleEn: '', roleOrTitleAr: '', avatarUrl: '', bioEn: '', bioAr: ''),
    );
    final updatedSpeakers = currentOrg.affiliatedSpeakers.where((s) => s.speakerId != speakerId).toList();
    _streamers[idx] = currentOrg.copyWith(affiliatedSpeakers: updatedSpeakers);

    await recordOrgAuditAction(
      OrgAuditLogEntry(
        logId: 'audit_spk_del_${DateTime.now().millisecondsSinceEpoch}',
        organizationId: orgId,
        timestamp: DateTime.now(),
        actorEmail: _googleUserEmail ?? 'admin@platform.com',
        actorName: _googleUserName ?? 'Administrator',
        action: OrgAuditAction.removeSpeakerFromRoster,
        descriptionEn: 'Removed instructor from roster: ${removed.nameEn.isNotEmpty ? removed.nameEn : speakerId}.',
        descriptionAr: 'تم حذف المدرب من الكادر: ${removed.nameAr.isNotEmpty ? removed.nameAr : speakerId}.',
        metadata: {'speaker_id': speakerId},
      ),
    );
    notifyListeners();
  }
}
