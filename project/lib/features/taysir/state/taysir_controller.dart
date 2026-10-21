import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/demo_taysir_repository.dart';
import '../data/taysir_repository.dart';
import '../domain/taysir_dates.dart';
import '../domain/taysir_models.dart';
import '../domain/taysir_rules.dart';

/// Taysir's client state: the public catalogue, the signed-in account's own
/// data and roles, and (for coordinators) one organization's staff view.
///
/// A standalone controller, not part of AppProvider (see CLAUDE.md: feature
/// state lives with its feature). Every write goes to the repository and is
/// followed by a reload, so the screens always show what the server holds.
class TaysirController extends ChangeNotifier {
  TaysirController(this.repository);

  final TaysirRepository repository;

  TaysirCatalog catalog = const TaysirCatalog();
  TaysirMine mine = const TaysirMine();
  TaysirRoles roles = TaysirRoles.guest;
  TaysirStaffData staff = const TaysirStaffData();
  List<TaysirOrganization> adminOrganizations = const [];
  String? staffOrganizationId;

  bool loading = false;
  bool loaded = false;
  TaysirFailure? failure;
  String? _userId;
  bool _disposed = false;
  Future<void>? _inFlight;

  bool get isDemo => repository.isDemo;
  bool get signedIn => repository.currentUserId != null;
  DateTime get today => taysirToday();

  // ------------------------------------------------------------- loading
  /// Loads once; later calls reuse the result until [refresh].
  Future<void> ensureLoaded() => loaded ? Future.value() : refresh();

  Future<void> refresh() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    loading = true;
    _notify();
    try {
      final r = await Future.wait<Object>([repository.loadCatalog(), repository.loadRoles(), repository.loadMine()]);
      catalog = r[0] as TaysirCatalog;
      roles = r[1] as TaysirRoles;
      mine = r[2] as TaysirMine;
      _userId = repository.currentUserId;
      failure = null;
      loaded = true;
      if (staffOrganizationId != null && roles.coordinates(staffOrganizationId!)) {
        staff = await repository.loadStaff(staffOrganizationId!);
      }
      if (roles.master) adminOrganizations = await repository.loadAdminOrganizations();
    } on TaysirException catch (e) {
      failure = e.failure;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Sign-in, sign-out and account switches change what the server shows.
  void onAccountChanged(String? userId) {
    if (!loaded || userId == _userId) return;
    staff = const TaysirStaffData();
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
      if (roles.master) adminOrganizations = await repository.loadAdminOrganizations();
    } on TaysirException catch (e) {
      failure = e.failure;
    }
    _notify();
  }

  /// Sample data only: view the programme as another role.
  void setDemoPersona(TaysirDemoPersona persona) {
    final repo = repository;
    if (repo is! DemoTaysirRepository) return;
    repo.persona = persona;
    staff = const TaysirStaffData();
    staffOrganizationId = null;
    unawaited(refresh());
  }

  TaysirDemoPersona? get demoPersona =>
      repository is DemoTaysirRepository ? (repository as DemoTaysirRepository).persona : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Runs a write, then reloads. Errors reach the caller as [TaysirException].
  Future<T> _write<T>(Future<T> Function() call) async {
    final result = await call();
    await refresh();
    return result;
  }

  // ----------------------------------------------------------- selectors
  TaysirMosque? mosque(String id) => catalog.mosques[id];
  TaysirPreacher? preacher(String id) => catalog.preachers[id];
  TaysirDistrict? district(String? id) => catalog.districts[id];
  TaysirSeries? seriesOf(String? id) => id == null ? null : catalog.series[id];
  TaysirLesson? lesson(String id) => catalog.lessons[id];
  String cityOfMosque(String mosqueId) => cityOf(catalog.mosques[mosqueId], catalog.districts);

  /// What the public calendar shows: approved sessions, and cancelled ones
  /// (kept visible, marked cancelled).
  Iterable<TaysirLesson> get publicLessons =>
      catalog.lessons.values.where((l) => (l.isPublic || l.isCancelled) && _ready(l));

  bool _ready(TaysirLesson l) =>
      catalog.mosques.containsKey(l.mosqueId) && catalog.preachers.containsKey(l.preacherId);

  List<TaysirLesson> get upcoming =>
      publicLessons.where((l) => l.isPublic && !l.date.isBefore(today)).toList()..sort(compareLessons);

  List<TaysirLesson> upcomingWhere(bool Function(TaysirLesson) test) => upcoming.where(test).toList();

  List<TaysirLesson> pastWhere(bool Function(TaysirLesson) test) =>
      publicLessons.where((l) => l.isPublic && l.date.isBefore(today) && test(l)).toList()
        ..sort((a, b) => compareLessons(b, a));

  List<TaysirLesson> sessionsOf(String seriesId) =>
      publicLessons.where((l) => l.seriesId == seriesId).toList()..sort(compareLessons);

  List<TaysirSeries> get approvedSeries => catalog.series.values.where((s) => s.status == 'approved').toList();

  List<TaysirPreacher> get listedPreachers =>
      catalog.preachers.values.where((p) => p.listed).toList()..sort((a, b) => a.nameAr.compareTo(b.nameAr));

  List<TaysirMosque> get verifiedMosques => catalog.mosques.values.where((m) => m.verified).toList();

  double startHours(TaysirLesson l) => lessonStartHours(l, catalog);
  bool isLiveNow(TaysirLesson l) {
    if (!l.streamed || !l.isPublic || !sameDay(l.date, today)) return false;
    final start = startHours(l), now = taysirNowHours();
    return now >= start && now <= start + 1.25;
  }

  // Roles
  List<String> get consoleOrganizations {
    if (roles.admin) {
      return catalog.organizations.keys.toList();
    }
    return roles.coordinate.toList();
  }

  String? get ownPreacherId => roles.ownPreacherId;
  bool get canSubmitOwn => roles.isPreacher;
  bool get canCoordinate => roles.isCoordinator;
  bool coordinates(String organizationId) => roles.coordinates(organizationId);

  /// Pending requests the caller may review.
  List<TaysirRequest> get pendingRequests =>
      requestsOf(catalog.lessons.values.where((l) => roles.coordinates(l.organizationId)));

  /// The caller's own preacher requests (pending, rejected and withdrawn).
  List<TaysirRequest> myRequests() {
    final pid = ownPreacherId;
    if (pid == null) return const [];
    return requestsOf(catalog.lessons.values.where((l) => l.preacherId == pid),
        statuses: const {'pending', 'rejected', 'withdrawn'});
  }

  List<TaysirLesson> myLessons({required bool upcomingOnly}) {
    final pid = ownPreacherId;
    if (pid == null) return const [];
    final list = catalog.lessons.values
        .where((l) => l.preacherId == pid && (l.isPublic || l.isCancelled))
        .where((l) => upcomingOnly ? !l.date.isBefore(today) : l.date.isBefore(today) && l.isPublic)
        .toList();
    list.sort(upcomingOnly ? compareLessons : (a, b) => compareLessons(b, a));
    return list;
  }

  List<TaysirLesson> clashes(TaysirLesson l) => clashesOfLesson(l, catalog.lessons.values);

  // --------------------------------------------------------- viewer data
  bool hasReminder(String lessonId) => mine.reminders.containsKey(lessonId);
  String? reminderLead(String lessonId) => mine.reminders[lessonId]?.lead;
  bool isFollowing(String kind, String id) => mine.isFollowing(kind, id);
  bool attended(String lessonId) => mine.attended.contains(lessonId);

  Future<void> setReminder(TaysirLesson l, String? lead) => _write(() => lead == null
      ? repository.removeReminder(l.id)
      : repository.setReminder(l.id, lead, reminderInstant(l, lead, catalog)));

  Future<void> toggleFollow(String kind, String id) =>
      _write(() => repository.setFollow(kind, id, !isFollowing(kind, id)));

  Future<void> toggleAttended(String lessonId) =>
      _write(() => repository.setAttended(lessonId, !attended(lessonId)));

  Future<void> savePreferences(TaysirPreferences p) => _write(() => repository.savePreferences(p));

  Future<void> markRead([List<String>? ids]) => _write(() => repository.markNotificationsRead(ids));

  Future<void> flag(String lessonId, String kind, String message) =>
      _write(() => repository.flag(lessonId, kind, message));

  // ---------------------------------------------------- preacher / staff
  Future<String> submit(TaysirDraft d) => _write(() => repository.submit(d));
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
  Future<TaysirInviteInfo?> inviteInfo(String token) => repository.inviteInfo(token);
  Future<String> claimInvite(String token, List<String> languages) =>
      _write(() => repository.claimInvite(token, languages));
  Future<void> setCoordinator(String org, String profileId, bool on) =>
      _write(() => repository.setCoordinator(org, profileId, on));
  Future<void> setOrganizationEnabled(String org, bool on) =>
      _write(() => repository.setOrganizationEnabled(org, on));
  Future<String> upsertMosque(Map<String, dynamic> m) => _write(() => repository.upsertMosque(m));
  Future<void> verifyMosque(String id) => _write(() => repository.verifyMosque(id));
  Future<void> rejectMosque(String id, {String? mergeInto}) =>
      _write(() => repository.rejectMosque(id, mergeInto: mergeInto));
}
