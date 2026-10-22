import '../domain/lessons_models.dart';

/// Why a Lessons call failed, in terms the UI can explain. [expired] is a
/// preacher link that no longer opens; its detail says why (revoked,
/// not_yet, expired, used). [busy] is a limit (too many requests waiting).
enum LessonsFailure { forbidden, invalid, conflict, expired, busy, unavailable, unknown }

class LessonsException implements Exception {
  const LessonsException(this.failure, [this.detail = '']);
  final LessonsFailure failure;
  final String detail;
  @override
  String toString() => 'LessonsException($failure, $detail)';
}

/// Every Lessons read and write. Writes go through server functions that check
/// the caller (migration 20261022110000): admins manage everything, viewers
/// keep their own reminders and follows, and a preacher acts only through
/// his link. The client never decides authority on its own.
abstract class LessonsRepository {
  /// True for the in-memory sample data used when no backend is configured.
  bool get isDemo;

  /// The signed-in account, or null for a guest.
  String? get currentUserId;

  Future<LessonsCatalog> loadCatalog();
  Future<LessonsRoles> loadRoles();
  Future<LessonsMine> loadMine();

  /// Admins only.
  Future<LessonsAdminData> loadAdmin();

  // Viewers
  Future<void> setReminder(String lessonId, String lead, DateTime remindAt);
  Future<void> removeReminder(String lessonId);
  Future<void> setFollow(String kind, String id, bool on);
  Future<void> setAttended(String lessonId, bool on);
  Future<void> savePreferences(LessonsPreferences preferences);
  Future<void> markNotificationsRead([List<String>? ids]);
  Future<void> flag(String lessonId, String kind, String message);

  // Admins: lessons
  /// Adds a lesson or weekly series, published at once. Returns its request id.
  Future<String> addLessons(LessonDraft draft);

  /// Decides preachers' requests. Approving needs a mosque: [mosqueId] is set
  /// on every session that has none.
  Future<int> review(List<String> requestIds, String decision, {String? reason, String? mosqueId});
  Future<int> undoReview(List<String> requestIds);
  Future<void> withdraw(String requestId);
  Future<int> cancelLesson(String lessonId, String reason);
  Future<void> editLesson(String lessonId, Map<String, dynamic> patch);
  Future<void> postReport(String lessonId, int attendance, int women, String issue, String notes);
  Future<void> resolveFlag(String flagId);

  // Admins: preachers
  Future<String> upsertPreacher(Map<String, dynamic> preacher);

  /// Removes a preacher with all his lessons and links. Returns how many
  /// lessons went with him.
  Future<int> removePreacher(String preacherId);
  Future<int> importPreachers(List<Map<String, dynamic>> rows);
  Future<String?> revealPhone(String preacherId);
  Future<void> decideEdit(String editId, bool approve, {String? reason});

  /// The admin user directory, to link a preacher to his account.
  Future<List<LessonsAccount>> searchAccounts(String query);

  // Admins: preacher links
  Future<NewPreacherKey> createKey(String preacherId, String kind,
      {DateTime? validFrom, DateTime? validUntil, String note = ''});
  Future<List<PreacherKey>> loadKeys(String preacherId);
  Future<void> revokeKey(String keyId);

  // Admins: mosques
  Future<String> upsertMosque(Map<String, dynamic> mosque);

  /// Removes a mosque, or with [mergeInto] moves its sessions to that one.
  Future<void> removeMosque(String mosqueId, {String? mergeInto});

  // A preacher, through his link (no account needed). [device] identifies
  // the phone: a one-time link binds to the first one.
  Future<PreacherLinkView> openLink(String token, String device);
  Future<void> proposeCardEdit(String token, String device, Map<String, dynamic> changes);
  Future<String> requestLesson(String token, String device, LessonRequestDraft draft);
  Future<void> withdrawRequest(String token, String device, String requestId);
}
