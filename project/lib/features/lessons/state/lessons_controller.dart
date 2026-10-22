import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/demo_lessons_repository.dart';
import '../data/lessons_repository.dart';
import '../domain/lessons_dates.dart';
import '../domain/lessons_models.dart';
import '../domain/lessons_rules.dart';

/// Lessons's client state: the public catalogue, the signed-in account's own
/// data and roles, and (for coordinators) one organization's staff view.
///
/// A standalone controller, not part of AppProvider (see CLAUDE.md: feature
/// state lives with its feature). Every write goes to the repository and is
/// followed by a reload, so the screens always show what the server holds.
class LessonsController extends ChangeNotifier {
  LessonsController(this.repository);

  final LessonsRepository repository;

  LessonsCatalog catalog = const LessonsCatalog();
  LessonsMine mine = const LessonsMine();
  LessonsRoles roles = LessonsRoles.guest;
  LessonsStaffData staff = const LessonsStaffData();

  /// Admins: every organization (Lessons on or off) and every coordinator.
  List<LessonsOrganization> adminOrganizations = const [];
  List<LessonsCoordinator> coordinators = const [];
  String? staffOrganizationId;

  bool loading = false;
  bool loaded = false;
  LessonsFailure? failure;
  String? _userId;
  bool _disposed = false;
  Future<void>? _inFlight;

  bool get isDemo => repository.isDemo;
  bool get signedIn => repository.currentUserId != null;
  DateTime get today => lessonsToday();

  // ------------------------------------------------------------- loading
  /// Loads once; later calls reuse the result until [refresh].
  Future<void> ensureLoaded() => loaded ? Future.value() : refresh();

  Future<void> refresh() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    loading = true;
    // Loads start while widgets build (a page's first build, the provider's
    // account update), so listeners hear about it after that frame.
    scheduleMicrotask(_notify);
    try {
      final r = await Future.wait<Object>([repository.loadCatalog(), repository.loadRoles(), repository.loadMine()]);
      catalog = r[0] as LessonsCatalog;
      roles = r[1] as LessonsRoles;
      mine = r[2] as LessonsMine;
      _userId = repository.currentUserId;
      failure = null;
      loaded = true;
      if (roles.admin) {
        final r = await Future.wait<Object>([repository.loadAdminOrganizations(), repository.loadCoordinators()]);
        adminOrganizations = r[0] as List<LessonsOrganization>;
        coordinators = r[1] as List<LessonsCoordinator>;
      } else {
        adminOrganizations = const [];
        coordinators = const [];
      }
      // Coordinators get their organization's staff data (open reports,
      // roster) without opening the console first; the Me tab counts it.
      if (roles.isCoordinator) staffOrganizationId ??= consoleOrganizations.firstOrNull;
      if (staffOrganizationId != null && roles.coordinates(staffOrganizationId!)) {
        staff = await repository.loadStaff(staffOrganizationId!);
      }
    } on LessonsException catch (e) {
      failure = e.failure;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Sign-in, sign-out and account switches change what the server shows.
  void onAccountChanged(String? userId) {
    if (!loaded || userId == _userId) return;
    staff = const LessonsStaffData();
    staffOrganizationId = null;
    unawaited(refresh());
  }

  /// Opens the console on [organizationId] (or the first one coordinated).
  Future<void> openConsole([String? organizationId]) async {
    await ensureLoaded();
    final org = organizationId ?? consoleOrganizations.firstOrNull;
    if (org == null) return;
    staffOrganizationId = org;
    try {
      staff = await repository.loadStaff(org);
    } on LessonsException catch (e) {
      failure = e.failure;
    }
    _notify();
  }

  /// Sample data only: view the programme as another role.
  void setDemoPersona(LessonsDemoPersona persona) {
    final repo = repository;
    if (repo is! DemoLessonsRepository) return;
    repo.persona = persona;
    staff = const LessonsStaffData();
    staffOrganizationId = null;
    unawaited(refresh());
  }

  LessonsDemoPersona? get demoPersona =>
      repository is DemoLessonsRepository ? (repository as DemoLessonsRepository).persona : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Runs a write, then reloads. Errors reach the caller as [LessonsException].
  Future<T> _write<T>(Future<T> Function() call) async {
    final result = await call();
    await refresh();
    return result;
  }

  // ----------------------------------------------------------- selectors
  Mosque? mosque(String id) => catalog.mosques[id];
  Preacher? preacher(String id) => catalog.preachers[id];
  District? district(String? id) => catalog.districts[id];
  LessonSeries? seriesOf(String? id) => id == null ? null : catalog.series[id];
  Lesson? lesson(String id) => catalog.lessons[id];
  String cityOfMosque(String mosqueId) => cityOf(catalog.mosques[mosqueId], catalog.districts);

  /// What the public calendar shows: approved sessions, and cancelled ones
  /// (kept visible, marked cancelled).
  Iterable<Lesson> get publicLessons =>
      catalog.lessons.values.where((l) => (l.isPublic || l.isCancelled) && _ready(l));

  bool _ready(Lesson l) =>
      catalog.mosques.containsKey(l.mosqueId) && catalog.preachers.containsKey(l.preacherId);

  List<Lesson> get upcoming =>
      publicLessons.where((l) => l.isPublic && !l.date.isBefore(today)).toList()..sort(compareLessons);

  List<Lesson> upcomingWhere(bool Function(Lesson) test) => upcoming.where(test).toList();

  List<Lesson> pastWhere(bool Function(Lesson) test) =>
      publicLessons.where((l) => l.isPublic && l.date.isBefore(today) && test(l)).toList()
        ..sort((a, b) => compareLessons(b, a));

  List<Lesson> sessionsOf(String seriesId) =>
      publicLessons.where((l) => l.seriesId == seriesId).toList()..sort(compareLessons);

  List<LessonSeries> get approvedSeries => catalog.series.values.where((s) => s.status == 'approved').toList();

  List<Preacher> get listedPreachers =>
      catalog.preachers.values.where((p) => p.listed).toList()..sort((a, b) => a.nameAr.compareTo(b.nameAr));

  List<Mosque> get verifiedMosques => catalog.mosques.values.where((m) => m.verified).toList();

  double startHours(Lesson l) => lessonStartHours(l, catalog);
  bool isLiveNow(Lesson l) {
    if (!l.streamed || !l.isPublic || !sameDay(l.date, today)) return false;
    final start = startHours(l), now = lessonsNowHours();
    return now >= start && now <= start + 1.25;
  }

  // Roles
  /// Organizations the console can open. Admins see all of them, including
  /// ones without Lessons yet (that is where a master admin switches it on).
  List<String> get consoleOrganizations {
    if (roles.admin) {
      return adminOrganizations.isNotEmpty
          ? [for (final o in adminOrganizations) o.id]
          : catalog.organizations.keys.toList();
    }
    return roles.coordinate.toList();
  }

  LessonsOrganization? organization(String id) =>
      catalog.organizations[id] ?? adminOrganizations.where((o) => o.id == id).firstOrNull;

  String? get ownPreacherId => roles.ownPreacherId;
  bool get canSubmitOwn => roles.isPreacher;
  bool get canCoordinate => roles.isCoordinator;
  bool coordinates(String organizationId) => roles.coordinates(organizationId);

  /// Pending requests the caller may review.
  List<LessonRequest> get pendingRequests =>
      requestsOf(catalog.lessons.values.where((l) => roles.coordinates(l.organizationId)));

  /// The caller's own preacher requests (pending, rejected and withdrawn).
  List<LessonRequest> myRequests() {
    final pid = ownPreacherId;
    if (pid == null) return const [];
    return requestsOf(catalog.lessons.values.where((l) => l.preacherId == pid),
        statuses: const {'pending', 'rejected', 'withdrawn'});
  }

  List<Lesson> myLessons({required bool upcomingOnly}) {
    final pid = ownPreacherId;
    if (pid == null) return const [];
    final list = catalog.lessons.values
        .where((l) => l.preacherId == pid && (l.isPublic || l.isCancelled))
        .where((l) => upcomingOnly ? !l.date.isBefore(today) : l.date.isBefore(today) && l.isPublic)
        .toList();
    list.sort(upcomingOnly ? compareLessons : (a, b) => compareLessons(b, a));
    return list;
  }

  List<Lesson> clashes(Lesson l) => clashesOfLesson(l, catalog.lessons.values);

  // --------------------------------------------------------- viewer data
  bool hasReminder(String lessonId) => mine.reminders.containsKey(lessonId);
  String? reminderLead(String lessonId) => mine.reminders[lessonId]?.lead;
  bool isFollowing(String kind, String id) => mine.isFollowing(kind, id);
  bool attended(String lessonId) => mine.attended.contains(lessonId);

  Future<void> setReminder(Lesson l, String? lead) => _write(() => lead == null
      ? repository.removeReminder(l.id)
      : repository.setReminder(l.id, lead, reminderInstant(l, lead, catalog)));

  Future<void> toggleFollow(String kind, String id) =>
      _write(() => repository.setFollow(kind, id, !isFollowing(kind, id)));

  Future<void> toggleAttended(String lessonId) =>
      _write(() => repository.setAttended(lessonId, !attended(lessonId)));

  Future<void> savePreferences(LessonsPreferences p) => _write(() => repository.savePreferences(p));

  Future<void> markRead([List<String>? ids]) => _write(() => repository.markNotificationsRead(ids));

  Future<void> flag(String lessonId, String kind, String message) =>
      _write(() => repository.flag(lessonId, kind, message));

  // ---------------------------------------------------- preacher / staff
  Future<String> submit(LessonDraft d) => _write(() => repository.submit(d));
  Future<int> review(List<String> ids, String decision, {String? reason}) =>
      _write(() => repository.review(ids, decision, reason: reason));
  Future<int> undoReview(List<String> ids) => _write(() => repository.undoReview(ids));
  Future<void> withdraw(String requestId) => _write(() => repository.withdraw(requestId));
  Future<int> cancelLesson(String id, String reason) => _write(() => repository.cancelLesson(id, reason));
  Future<void> editLesson(String id, Map<String, dynamic> patch) => _write(() => repository.editLesson(id, patch));
  Future<void> postReport(String id, int attendance, int women, String issue, String notes) =>
      _write(() => repository.postReport(id, attendance, women, issue, notes));
  Future<void> resolveFlag(String id) => _write(() => repository.resolveFlag(id));
  Future<String> upsertPreacher(Map<String, dynamic> p) => _write(() => repository.upsertPreacher(p));
  Future<int> importPreachers(String org, List<Map<String, dynamic>> rows) =>
      _write(() => repository.importPreachers(org, rows));
  Future<String?> revealPhone(String preacherId) => _write(() => repository.revealPhone(preacherId));
  Future<void> setSubmit(String preacherId, bool on) => _write(() => repository.setSubmit(preacherId, on));
  Future<void> unlinkPreacher(String preacherId) => _write(() => repository.unlinkPreacher(preacherId));
  Future<String> createInvite(String preacherId) => _write(() => repository.createInvite(preacherId));
  Future<LessonsInviteInfo?> inviteInfo(String token) => repository.inviteInfo(token);
  Future<String> claimInvite(String token, List<String> languages) =>
      _write(() => repository.claimInvite(token, languages));
  Future<void> setCoordinator(String org, String profileId, bool on) =>
      _write(() => repository.setCoordinator(org, profileId, on));
  Future<void> setOrganizationEnabled(String org, bool on) =>
      _write(() => repository.setOrganizationEnabled(org, on));
  Future<List<LessonsAccount>> searchAccounts(String query) => repository.searchAccounts(query);
  Future<int> setCoordinatorOrganizations(String profileId, List<String> organizationIds) =>
      _write(() => repository.setCoordinatorOrganizations(profileId, organizationIds));
  Future<String> upsertMosque(Map<String, dynamic> m) => _write(() => repository.upsertMosque(m));
  Future<void> verifyMosque(String id) => _write(() => repository.verifyMosque(id));
  Future<void> rejectMosque(String id, {String? mergeInto}) =>
      _write(() => repository.rejectMosque(id, mergeInto: mergeInto));
}
