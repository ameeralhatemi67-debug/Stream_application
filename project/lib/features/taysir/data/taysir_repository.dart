import '../domain/taysir_models.dart';

/// Why a Taysir call failed, in terms the UI can explain.
enum TaysirFailure { forbidden, invalid, conflict, expired, unavailable, unknown }

class TaysirException implements Exception {
  const TaysirException(this.failure, [this.detail = '']);
  final TaysirFailure failure;
  final String detail;
  @override
  String toString() => 'TaysirException($failure, $detail)';
}

/// Every Taysir read and write. Writes go through server functions that check
/// the caller (see the migration 20261021142359); the client never decides
/// authority on its own.
abstract class TaysirRepository {
  /// True for the in-memory sample data used when no backend is configured.
  bool get isDemo;

  /// The signed-in account, or null for a guest.
  String? get currentUserId;

  Future<TaysirCatalog> loadCatalog();
  Future<TaysirRoles> loadRoles();
  Future<TaysirMine> loadMine();
  Future<TaysirStaffData> loadStaff(String organizationId);
  Future<List<TaysirOrganization>> loadAdminOrganizations();

  // Viewers
  Future<void> setReminder(String lessonId, String lead, DateTime remindAt);
  Future<void> removeReminder(String lessonId);
  Future<void> setFollow(String kind, String id, bool on);
  Future<void> setAttended(String lessonId, bool on);
  Future<void> savePreferences(TaysirPreferences preferences);
  Future<void> markNotificationsRead([List<String>? ids]);
  Future<void> flag(String lessonId, String kind, String message);

  // Preachers and coordinators
  Future<String> submit(TaysirDraft draft);
  Future<int> review(List<String> requestIds, String decision, {String? reason});
  Future<int> undoReview(List<String> requestIds);
  Future<void> withdraw(String requestId);
  Future<int> cancelLesson(String lessonId, String reason);
  Future<void> editLesson(String lessonId, Map<String, dynamic> patch);
  Future<void> postReport(String lessonId, int attendance, int women, String issue, String notes);
  Future<void> resolveFlag(String flagId);

  // Roster, invitations and team
  Future<String> upsertPreacher(Map<String, dynamic> preacher);
  Future<int> importPreachers(String organizationId, List<Map<String, dynamic>> rows);
  Future<String?> revealPhone(String preacherId);
  Future<void> setSubmit(String preacherId, bool enabled);
  Future<void> unlinkPreacher(String preacherId);
  Future<String> createInvite(String preacherId);
  Future<TaysirInviteInfo?> inviteInfo(String token);
  Future<String> claimInvite(String token, List<String> languages);
  Future<void> setCoordinator(String organizationId, String profileId, bool enabled);
  Future<void> setOrganizationEnabled(String organizationId, bool enabled);

  // Admins: coordinators across organizations
  Future<List<TaysirCoordinator>> loadCoordinators();
  Future<List<TaysirAccount>> searchAccounts(String query);

  /// Sets exactly which organizations [profileId] coordinates: adding,
  /// changing and removing (an empty list) a coordinator. Returns the number
  /// of grants and revocations made.
  Future<int> setCoordinatorOrganizations(String profileId, List<String> organizationIds);

  // Mosque directory
  Future<String> upsertMosque(Map<String, dynamic> mosque);
  Future<void> verifyMosque(String mosqueId);
  Future<void> rejectMosque(String mosqueId, {String? mergeInto});
}
